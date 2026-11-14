--!strict
-- SHARED workshop inventory: the single material authority for every player in a workshop,
-- across every server. Mirrors Godot's WorldSeed.inventory ("Single authority").
--
-- Concurrency model
--   * One DataStore key per workshop id.
--   * Additions (gathering, forge output) accumulate in `pending` and are committed in
--     batches by flush(); a crash loses at most WORKSHOP_FLUSH_SECONDS of gathering.
--   * Consumption is atomic: the check-and-subtract happens INSIDE UpdateAsync against the
--     freshest stored value, so two servers can never spend the same ore twice.
--   * After each commit the server publishes on MessagingService; other servers re-read.
--   * Inside one server, transactions are serialized with a small mutex.

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local ItemDefs = require(Shared.ItemDefs)
local Remotes = require(Shared.Remotes)
local StoreUtil = require(script.Parent.StoreUtil)

local DATA_VERSION = 1
local LATTICE_SOCKETS = 12 -- PLACEHOLDER count; Godot grows a 36-vertex lattice
local MAX_LOG = 50

export type WorkshopData = {
	schema: number,
	revision: number,
	inventory: { [string]: number },
	equipment: { [string]: number },
	lattice: { string }, -- module type per socket; "core" at 1, "empty" when free
	foundryRuns: number,
	log: { any },
	-- TETRAFORGE feed reserved by live sessions: refunded/converted on settle, or fully
	-- refunded by any server once the owning server stops heart-beating (crash safety).
	reservations: { [string]: Reservation },
}

export type Reservation = { budget: { [string]: number }, jobId: string, owner: number, t: number }

local Service = {}

local store: any = nil
local workshopId = Config.DEFAULT_WORKSHOP_ID
local confirmed: WorkshopData
local pending: { [string]: number } = {}
local busy = false
local localReservations: { [string]: boolean } = {}
local RESERVATION_STALE_SECONDS = Config.RESERVATION_STALE_SECONDS
local changedCallbacks: { () -> () } = {}

local function defaultData(): WorkshopData
	local lattice = table.create(LATTICE_SOCKETS, "empty")
	lattice[1] = "core"
	return {
		schema = DATA_VERSION,
		revision = 0,
		inventory = table.clone(ItemDefs.STARTER_STOCK),
		equipment = table.clone(ItemDefs.STARTER_EQUIPMENT),
		lattice = lattice,
		foundryRuns = 0,
		log = {},
		reservations = {},
	}
end

local function reconcile(raw: any): WorkshopData
	local d = defaultData()
	if type(raw) ~= "table" then
		return d
	end
	d.revision = tonumber(raw.revision) or 0
	if type(raw.inventory) == "table" then
		for k in d.inventory do
			local v = tonumber(raw.inventory[k])
			if v then
				d.inventory[k] = math.max(0, math.floor(v))
			end
		end
	end
	if type(raw.equipment) == "table" then
		for k, v in raw.equipment do
			if type(k) == "string" and tonumber(v) then
				d.equipment[k] = math.max(0, math.floor(tonumber(v) :: number))
			end
		end
	end
	if type(raw.lattice) == "table" then
		for i = 1, LATTICE_SOCKETS do
			local m = raw.lattice[i]
			if type(m) == "string" then
				d.lattice[i] = m
			end
		end
		d.lattice[1] = "core"
	end
	d.foundryRuns = tonumber(raw.foundryRuns) or 0
	if type(raw.reservations) == "table" then
		for id, r in raw.reservations do
			if type(id) == "string" and type(r) == "table" and type(r.budget) == "table" then
				local budget = {}
				for k, n in r.budget do
					if ItemDefs.isValid(k) and tonumber(n) then
						budget[k] = math.max(0, math.floor(tonumber(n) :: number))
					end
				end
				d.reservations[id] = {
					budget = budget,
					jobId = tostring(r.jobId),
					owner = tonumber(r.owner) or 0,
					t = tonumber(r.t) or 0,
				}
			end
		end
	end
	if type(raw.log) == "table" then
		d.log = table.clone(raw.log)
	end
	return d
end

local function lock()
	while busy do
		task.wait()
	end
	busy = true
end

local function unlock()
	busy = false
end

-- Local view = last confirmed stored state + uncommitted additions
function Service.view(): WorkshopData
	local v = table.clone(confirmed)
	v.inventory = table.clone(confirmed.inventory)
	for k, n in pending do
		v.inventory[k] = (v.inventory[k] or 0) + n
	end
	return v
end

function Service.amount(item: string): number
	return math.max(0, (confirmed.inventory[item] or 0) + (pending[item] or 0))
end

function Service.canConsume(cost: { [string]: number }): boolean
	for k, n in cost do
		if not ItemDefs.isValid(k) or n < 0 or Service.amount(k) < n then
			return false
		end
	end
	return true
end

function Service.workshopId(): string
	return workshopId
end

local function broadcastToClients()
	local v = Service.view()
	local payload = {
		workshopId = workshopId,
		inventory = v.inventory,
		equipment = v.equipment,
		lattice = v.lattice,
		foundryRuns = v.foundryRuns,
	}
	Remotes.event("InventoryUpdated"):FireAllClients(payload)
	for _, cb in changedCallbacks do
		task.spawn(cb)
	end
end
Service.broadcastToClients = broadcastToClients

function Service.onChanged(cb: () -> ())
	table.insert(changedCallbacks, cb)
end

function Service.snapshotFor(_player: Player)
	local v = Service.view()
	return {
		workshopId = workshopId,
		inventory = v.inventory,
		equipment = v.equipment,
		lattice = v.lattice,
		foundryRuns = v.foundryRuns,
	}
end

local function publish()
	task.spawn(function()
		pcall(function()
			MessagingService:PublishAsync(Config.MESSAGING_TOPIC, {
				workshopId = workshopId,
				revision = confirmed.revision,
				jobId = game.JobId,
			})
		end)
	end)
end

local function appendLog(d: WorkshopData, kind: string, actor: string, details: any)
	table.insert(d.log, { t = os.time(), kind = kind, actor = actor, details = details })
	while #d.log > MAX_LOG do
		table.remove(d.log, 1)
	end
end

--[[
	Generic atomic transaction. `mutate(data)` runs inside UpdateAsync on the freshest stored
	copy (with this server's pending additions already applied). Return true to commit the
	mutation, false to reject it (pending additions are still committed).
	Returns (committed: boolean, reason: string?)
]]
function Service.transact(label: string, mutate: ((WorkshopData) -> (boolean, string?))?): (boolean, string?)
	lock()
	local applying = pending
	pending = {}
	local accepted = false
	local reason: string? = nil
	local result: WorkshopData? = nil
	local ok, err = StoreUtil.retry("Workshop " .. label, function()
		store:UpdateAsync(workshopId, function(old: any)
			local d = reconcile(old)
			for k, n in applying do
				d.inventory[k] = math.max(0, (d.inventory[k] or 0) + n)
			end
			-- Heartbeat our live reservations; refund abandoned ones from crashed servers.
			local now = os.time()
			for id, r in d.reservations do
				if localReservations[id] then
					r.t = now
				elseif now - r.t > RESERVATION_STALE_SECONDS then
					for k, n in r.budget do
						d.inventory[k] = (d.inventory[k] or 0) + n
					end
					d.reservations[id] = nil
					table.insert(d.log, {
						t = now,
						kind = "reservation_expired",
						actor = "workshop",
						details = { session = id, refunded = r.budget },
					})
				end
			end
			accepted, reason = true, nil
			if mutate then
				accepted, reason = mutate(d)
			end
			-- Safety net: inventory can never go negative.
			for k, n in d.inventory do
				if n < 0 then
					accepted, reason = false, "negative " .. k
					d = reconcile(old)
					for k2, n2 in applying do
						d.inventory[k2] = math.max(0, (d.inventory[k2] or 0) + n2)
					end
					break
				end
			end
			d.revision += 1
			result = d
			return d
		end)
	end)
	if not ok or not result then
		-- Store unavailable: put additions back so nothing gathered is lost.
		for k, n in applying do
			pending[k] = (pending[k] or 0) + n
		end
		unlock()
		warn("[GERTECH] workshop transaction failed:", err)
		return false, "Workshop storage is busy. Try again."
	end
	confirmed = result :: WorkshopData
	unlock()
	publish()
	broadcastToClients()
	if accepted then
		return true, nil
	end
	return false, reason
end

-- Atomic spend (+ optional immediate produce). Godot: WorldSeed.apply_material_receipt.
function Service.consume(
	cost: { [string]: number },
	produce: { [string]: number }?,
	actor: string,
	kind: string
): (boolean, string?)
	for k, n in cost do
		if not ItemDefs.isValid(k) or type(n) ~= "number" or n < 0 or n ~= math.floor(n) then
			return false, "bad cost"
		end
	end
	return Service.transact(kind, function(d)
		for k, n in cost do
			if (d.inventory[k] or 0) < n then
				return false, "Not enough " .. (ItemDefs.get(k) :: any).name
			end
		end
		for k, n in cost do
			d.inventory[k] -= n
		end
		if produce then
			for k, n in produce do
				d.inventory[k] = (d.inventory[k] or 0) + n
			end
		end
		appendLog(d, kind, actor, { consumed = cost, produced = produce })
		return true, nil
	end)
end

-- Non-atomic add (gathering / forge output). Committed on the next flush.
function Service.add(items: { [string]: number }, _actor: string)
	for k, n in items do
		if ItemDefs.isValid(k) and type(n) == "number" and n > 0 then
			pending[k] = (pending[k] or 0) + math.floor(n)
		end
	end
	broadcastToClients()
end

--[[
	Atomically reserve TETRAFORGE feed for a session. Takes min(stock, cap) of each feed
	material out of the shared stock and records the reservation in the same write.
	Returns (ok, budget | reason).
]]
function Service.reserveFeed(
	sessionId: string,
	owner: number,
	caps: { [string]: number },
	baseMaterials: { string }
): (boolean, any)
	local budget: { [string]: number } = {}
	localReservations[sessionId] = true -- heartbeat it from the very first write
	local ok, reason = Service.transact("forge_reserve", function(d)
		budget = {}
		for k, cap in caps do
			budget[k] = math.min(d.inventory[k] or 0, cap)
		end
		local feedable = false
		for _, k in baseMaterials do
			if (budget[k] or 0) >= 4 then
				feedable = true
			end
		end
		if not feedable then
			return false, "TETRAFORGE hoppers empty: needs at least 4 Ore or 4 Salvage in the workshop."
		end
		for k, n in budget do
			d.inventory[k] -= n
		end
		d.reservations[sessionId] = { budget = budget, jobId = game.JobId, owner = owner, t = os.time() }
		return true, nil
	end)
	if not ok then
		localReservations[sessionId] = nil
		return false, reason
	end
	return true, budget
end

--[[
	Settle a reservation: return the unspent feed plus the run's products in ONE write and
	delete the reservation. If the reservation is gone (another server already refunded it
	as abandoned), nothing is granted, so materials are never duplicated.
	Returns (ok, reason). ok=false with reason "store" means retry later.
]]
function Service.settleReservation(
	sessionId: string,
	refund: { [string]: number },
	produced: { [string]: number },
	details: any
): (boolean, string?)
	local missing = false
	local ok, reason = Service.transact("forge_receipt", function(d)
		missing = false
		if d.reservations[sessionId] == nil then
			missing = true
			return false, "reservation already refunded"
		end
		for k, n in refund do
			d.inventory[k] = (d.inventory[k] or 0) + n
		end
		for k, n in produced do
			d.inventory[k] = (d.inventory[k] or 0) + n
		end
		d.reservations[sessionId] = nil
		d.foundryRuns += 1
		table.insert(
			d.log,
			{ t = os.time(), kind = "minigame_receipt", actor = "tetraforge", details = details }
		)
		while #d.log > MAX_LOG do
			table.remove(d.log, 1)
		end
		return true, nil
	end)
	if ok or missing then
		localReservations[sessionId] = nil
		return ok, reason
	end
	return false, "store"
end

function Service.flush(): boolean
	local hasPending = next(pending) ~= nil
	if not hasPending then
		return true
	end
	local ok = Service.transact("flush", nil)
	return ok
end

local function refreshFromStore()
	local ok, raw = StoreUtil.retry("Workshop read", function()
		return store:GetAsync(workshopId)
	end)
	if ok then
		local d = reconcile(raw)
		if d.revision >= confirmed.revision then
			confirmed = d
			broadcastToClients()
		end
	end
end

function Service.start()
	store = StoreUtil.getStore(Config.DATASTORE_WORKSHOPS)
	-- Workshop id: private servers / reserved servers can pass their own via TeleportData later.
	confirmed = defaultData()
	-- First read creates the key with STARTER_STOCK if it does not exist.
	Service.transact("init", nil)

	if not StoreUtil.usingMock then
		task.spawn(function()
			local ok, err = pcall(function()
				MessagingService:SubscribeAsync(Config.MESSAGING_TOPIC, function(message)
					local data = message.Data
					if type(data) ~= "table" or data.workshopId ~= workshopId or data.jobId == game.JobId then
						return
					end
					if (tonumber(data.revision) or 0) > confirmed.revision then
						refreshFromStore()
					end
				end)
			end)
			if not ok then
				warn("[GERTECH] MessagingService subscribe failed:", err)
			end
		end)
	end

	task.spawn(function()
		while true do
			task.wait(Config.WORKSHOP_FLUSH_SECONDS)
			if next(pending) ~= nil or next(localReservations) ~= nil then
				Service.transact("heartbeat", nil)
			elseif #Players:GetPlayers() > 0 then
				refreshFromStore() -- fallback sync in case a message was dropped
			end
		end
	end)
end

function Service.setWorkshopId(id: string)
	workshopId = id
end

return Service
