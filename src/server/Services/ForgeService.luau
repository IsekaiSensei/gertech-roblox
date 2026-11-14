--!strict
-- TETRAFORGE station: server-authoritative falling-block forge (port of Godot's Tetris
-- Forge Foundry). The server owns the board, the piece RNG and the gravity tick
-- (ForgeSession). Clients only send input intents and render snapshots.
--
-- Material safety
--   start   : feed is reserved from the shared workshop stock atomically (reserveFeed),
--             recorded in the workshop record together with the deduction.
--   end     : unspent feed is refunded and products are granted in ONE atomic write that
--             also deletes the reservation (settleReservation). Leave and shutdown end the run
--             first, then settle the same way.
--   crash   : the reservation stops heart-beating and any server refunds it in full.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local ForgeRules = require(Shared.ForgeRules)
local ForgeSession = require(Shared.ForgeSession)
local ItemDefs = require(Shared.ItemDefs)
local ProgressionDefs = require(Shared.ProgressionDefs)
local Remotes = require(Shared.Remotes)
local TetrominoGrid = require(Shared.TetrominoGrid)
local DataService = require(script.Parent.DataService)
local Inventory = require(script.Parent.WorkshopInventoryService)
local RateLimiter = require(script.Parent.RateLimiter)

type Live = {
	id: string,
	player: Player,
	sim: ForgeSession.Session,
	budget: { [string]: number },
	pausedAt: number?,
	sentVersion: number,
	sentAt: number,
	settling: boolean,
}

local ForgeService = {}

local sessions: { [Player]: Live } = {}
local watchers: { [Player]: boolean } = {}
local starting: { [Player]: boolean } = {}
local inputLimiter = RateLimiter.new(Config.FORGE_INPUT_BURST, Config.FORGE_INPUT_PER_SECOND)
local actionLimiter = RateLimiter.new(3, 0.5)

local consolePart: BasePart? = nil
local chamberCells: { { BasePart } } = {}
local chamberLabel: TextLabel? = nil
local mirrorVersion = -1
local mirrorAt = 0

local INTENTS = {
	left = true,
	right = true,
	rotate = true,
	soft_on = true,
	soft_off = true,
	hard = true,
	hold = true,
	pause = true,
	resume = true,
	["end"] = true,
}

local MATERIAL_COLORS: { [string]: Color3 } = {
	o = (ItemDefs.get("ore") :: ItemDefs.ItemDef).color,
	s = (ItemDefs.get("salvage") :: ItemDefs.ItemDef).color,
	p = (ItemDefs.get("pure_component") :: ItemDefs.ItemDef).color,
}

local function notify(player: Player, text: string, kind: string?)
	Remotes.event("Notify"):FireClient(player, text, kind or "info")
end

local function rootOf(player: Player): BasePart?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function distanceToConsole(player: Player): number
	local root = rootOf(player)
	if not root or not consolePart then
		return math.huge
	end
	return (root.Position - (consolePart :: BasePart).Position).Magnitude
end

local function activeSession(): Live?
	for _, s in sessions do
		return s
	end
	return nil
end

local function sessionCount(): number
	local n = 0
	for _ in sessions do
		n += 1
	end
	return n
end

local function snapshot(s: Live): any
	local sim = s.sim
	local cells = {}
	for _, p in sim:activeCells() do
		table.insert(cells, p.x)
		table.insert(cells, p.y)
	end
	local codes = {}
	for _, m in sim.activeMaterials do
		table.insert(codes, ForgeRules.CODES[m] or "?")
	end
	return {
		sessionId = s.id,
		operatorId = s.player.UserId,
		operatorName = s.player.DisplayName,
		board = sim.grid:encode(ForgeRules.CODES),
		piece = if #cells > 0
			then {
				shape = sim.activeShape,
				x = sim.activeX,
				y = sim.activeY,
				r = sim.activeRotation,
				m = table.concat(codes),
				cells = cells,
			}
			else nil,
		nextShape = sim.nextShape,
		heldShape = sim.heldShape,
		canHold = sim.canHold,
		score = sim.score,
		lines = sim.linesCleared,
		target = sim.targetLines,
		heat = sim.heat,
		budget = s.budget,
		spent = sim.materialSpent,
		produced = sim.materialProduced,
		status = sim.status,
		paused = sim.paused,
		finished = sim.finished,
		interval = ForgeRules.gravityInterval(sim.gravitySeconds, sim.heat, sim.softDrop),
		serverTime = workspace:GetServerTimeNow(),
	}
end

local function broadcast(s: Live)
	local snap = snapshot(s)
	s.sentVersion = s.sim.version
	s.sentAt = os.clock()
	if s.player.Parent then
		Remotes.event("ForgeBoard"):FireClient(s.player, snap, "operator")
	end
	for w in watchers do
		if w ~= s.player and w.Parent then
			Remotes.event("ForgeBoard"):FireClient(w, snap, "watcher")
		end
	end
end

-- In-world chamber mirror so everyone in the hub can watch the forge.
local function renderMirror(s: Live?)
	if #chamberCells == 0 then
		return
	end
	local board = if s then s.sim.grid:encode(ForgeRules.CODES) else string.rep(".", 200)
	local active: { [number]: string } = {}
	if s then
		for i, p in s.sim:activeCells() do
			if p.y >= 0 then
				active[p.y * TetrominoGrid.WIDTH + p.x] = ForgeRules.CODES[s.sim.activeMaterials[i]] or "?"
			end
		end
	end
	for y = 0, TetrominoGrid.HEIGHT - 1 do
		for x = 0, TetrominoGrid.WIDTH - 1 do
			local idx = y * TetrominoGrid.WIDTH + x
			local code = active[idx] or string.sub(board, idx + 1, idx + 1)
			local part = chamberCells[y + 1][x + 1]
			if code == "." then
				part.Transparency = 0.92
				part.Color = Color3.fromRGB(30, 50, 70)
			else
				part.Transparency = if active[idx] then 0 else 0.15
				part.Color = MATERIAL_COLORS[code] or Color3.new(1, 1, 1)
			end
		end
	end
	if chamberLabel then
		chamberLabel.Text = if s
			then string.format(
				"TETRAFORGE · %s · score %d · rows %d/%d",
				s.player.DisplayName,
				s.sim.score,
				s.sim.linesCleared,
				s.sim.targetLines
			)
			else "TETRAFORGE · idle — operate at the console"
	end
	if consolePart then
		consolePart.Color = if s then Color3.fromRGB(255, 140, 60) else Color3.fromRGB(60, 200, 255)
	end
end

local function produceSummary(produced: { [string]: number }): string
	local parts = {}
	for _, k in ItemDefs.ORDER do
		local n = produced[k]
		if n and n > 0 then
			table.insert(parts, n .. " " .. (ItemDefs.get(k) :: ItemDefs.ItemDef).name)
		end
	end
	return if #parts > 0 then table.concat(parts, ", ") else "nothing"
end

-- Refund + products in one atomic write. Retries while the store is unavailable.
local function settle(s: Live, blocking: boolean)
	if s.settling then
		return
	end
	s.settling = true
	local sim = s.sim
	if not sim.finished then
		sim:finish("RETURN TO THE LOFT")
	end
	broadcast(s) -- final board to operator + watchers
	local result = sim.result :: ForgeSession.Result
	local refund = sim:refund()
	local produced = {}
	for k, n in result.materialsProduced do
		if n > 0 then
			produced[k] = n
		end
	end
	local details = {
		session = s.id,
		operator = s.player.UserId,
		reason = result.reason,
		score = result.score,
		consumed = result.materialsConsumed,
		produced = produced,
		refunded = refund,
		stats = result.stats,
	}
	local function run()
		local ok, reason = false, nil
		for attempt = 1, 12 do
			ok, reason = Inventory.settleReservation(s.id, refund, produced, details)
			if ok or reason ~= "store" then
				break
			end
			task.wait(math.min(2 * attempt, 10))
		end
		if s.player.Parent then
			if ok then
				if result.score > 0 then
					DataService.addXp(s.player, result.score * ProgressionDefs.XP_PER_SCORE)
				end
				DataService.addStat(s.player, "rowsForged", result.stats.lines)
				notify(
					s.player,
					string.format(
						"%s — score %d. Output: %s.",
						result.reason,
						result.score,
						produceSummary(produced)
					),
					"good"
				)
			elseif reason == "store" then
				notify(
					s.player,
					"Workshop storage is down; your feed stays reserved and will be refunded automatically.",
					"bad"
				)
			else
				notify(
					s.player,
					"This run's feed was already refunded to the workshop, so it produced nothing.",
					"bad"
				)
			end
		end
		if sessions[s.player] == s then
			sessions[s.player] = nil
		end
		mirrorVersion = -1
	end
	if blocking then
		run()
	else
		task.spawn(run)
	end
end

local function startSession(player: Player)
	if not actionLimiter:allow(player) then
		return
	end
	if not DataService.get(player) then
		return notify(player, "Your save is still loading.", "bad")
	end
	if sessions[player] or starting[player] then
		return notify(player, "You already have a TETRAFORGE run.", "bad")
	end
	if sessionCount() >= Config.FORGE_MAX_SESSIONS_PER_STATION then
		return notify(player, "The TETRAFORGE chamber is in use. You can watch.", "bad")
	end
	if distanceToConsole(player) > Config.STATION_MAX_DISTANCE then
		return notify(player, "Stand at the TETRAFORGE operator console.", "bad")
	end
	starting[player] = true
	local id = HttpService:GenerateGUID(false)
	local ok, budgetOrReason =
		Inventory.reserveFeed(id, player.UserId, ForgeRules.RESERVATION_CAP, ForgeRules.BASE_MATERIALS)
	starting[player] = nil
	if not ok then
		return notify(player, tostring(budgetOrReason), "bad")
	end
	local budget = budgetOrReason :: { [string]: number }
	if not player.Parent or sessionCount() >= Config.FORGE_MAX_SESSIONS_PER_STATION then
		-- Lost a race or left while reserving: give everything straight back.
		Inventory.settleReservation(id, budget, {}, { session = id, reason = "CANCELLED BEFORE START" })
		return
	end
	local sim = ForgeSession.new({
		inputs = budget,
		-- CANON: enable_alloy = pure_component >= 4 (of the stock handed to the run)
		enableAlloy = (budget.pure_component or 0) >= ForgeRules.ALLOY_ENABLE_THRESHOLD,
		targetLines = ForgeRules.TARGET_LINES,
		gravitySeconds = ForgeRules.GRAVITY_SECONDS,
	}, Random.new() :: any)
	local s: Live = {
		id = id,
		player = player,
		sim = sim,
		budget = budget,
		pausedAt = nil,
		sentVersion = -1,
		sentAt = 0,
		settling = false,
	}
	sessions[player] = s
	watchers[player] = nil
	sim:start()
	broadcast(s)
	notify(
		player,
		string.format(
			"Feed stock accepted: %d ore, %d salvage, %d pure reserved from the workshop.",
			budget.ore or 0,
			budget.salvage or 0,
			budget.pure_component or 0
		),
		"info"
	)
	if sim.finished then
		settle(s, false)
	end
end

local function onInput(player: Player, intent: any)
	local s = sessions[player]
	if not s or s.settling or type(intent) ~= "string" or not INTENTS[intent] then
		return
	end
	if not inputLimiter:allow(player) then
		return
	end
	local sim = s.sim
	if intent == "left" then
		sim:moveLeft()
	elseif intent == "right" then
		sim:moveRight()
	elseif intent == "rotate" then
		sim:rotate()
	elseif intent == "soft_on" then
		sim:setSoftDrop(true)
	elseif intent == "soft_off" then
		sim:setSoftDrop(false)
	elseif intent == "hard" then
		sim:hardDrop()
	elseif intent == "hold" then
		sim:hold()
	elseif intent == "pause" then
		sim:pause()
		s.pausedAt = os.clock()
	elseif intent == "resume" then
		sim:resume()
		s.pausedAt = nil
	elseif intent == "end" then
		sim:finish("RETURN TO THE LOFT") -- Godot: Esc
	end
	if sim.finished then
		settle(s, false)
	elseif sim.version ~= s.sentVersion and os.clock() - s.sentAt >= Config.FORGE_SNAPSHOT_MIN_INTERVAL then
		broadcast(s)
	end
end

local function onWatch(player: Player, on: any)
	if not actionLimiter:allow(player) then
		return
	end
	if on == true and distanceToConsole(player) <= Config.FORGE_WATCH_DISTANCE and not sessions[player] then
		watchers[player] = true
		local s = activeSession()
		if s then
			Remotes.event("ForgeBoard"):FireClient(player, snapshot(s), "watcher")
		end
	else
		watchers[player] = nil
	end
end

local distanceTimer = 0
local function step(dt: number)
	distanceTimer += dt
	local checkDistance = distanceTimer >= 1
	if checkDistance then
		distanceTimer = 0
		for w in watchers do
			if not w.Parent or distanceToConsole(w) > Config.FORGE_WATCH_DISTANCE then
				watchers[w] = nil
			end
		end
	end
	for player, s in sessions do
		if s.settling then
			continue
		end
		local sim = s.sim
		if sim.paused and s.pausedAt and os.clock() - s.pausedAt > Config.FORGE_PAUSE_MAX_SECONDS then
			sim:resume()
			s.pausedAt = nil
		end
		if checkDistance and distanceToConsole(player) > Config.FORGE_OPERATOR_MAX_DISTANCE then
			sim:finish("OPERATOR LEFT THE CONSOLE")
		end
		sim:update(dt)
		if sim.finished then
			settle(s, false)
		elseif
			sim.version ~= s.sentVersion and os.clock() - s.sentAt >= Config.FORGE_SNAPSHOT_MIN_INTERVAL
		then
			broadcast(s)
		end
	end
	local s = activeSession()
	local v = if s then s.sim.version else -2
	if v ~= mirrorVersion and os.clock() - mirrorAt >= 0.1 then
		mirrorVersion = v
		mirrorAt = os.clock()
		renderMirror(if s and not s.settling then s else nil)
	end
end

function ForgeService.bindStation(
	console: BasePart,
	prompt: ProximityPrompt,
	cells: { { BasePart } },
	label: TextLabel?
)
	consolePart = console
	chamberCells = cells
	chamberLabel = label
	prompt.Triggered:Connect(function(player)
		if not DataService.get(player) then
			return
		end
		local mine = sessions[player]
		local current = activeSession()
		local mode = if mine then "operator" elseif current then "watch" else "idle"
		if mode == "watch" then
			watchers[player] = true
		end
		Remotes.event("OpenForge"):FireClient(player, {
			mode = mode,
			caps = ForgeRules.RESERVATION_CAP,
			operatorName = if current then current.player.DisplayName else nil,
		})
		if mine then
			broadcast(mine)
		elseif current then
			Remotes.event("ForgeBoard"):FireClient(player, snapshot(current), "watcher")
		end
	end)
	renderMirror(nil)
end

function ForgeService.start()
	Remotes.event("ForgeStart").OnServerEvent:Connect(startSession)
	Remotes.event("ForgeInput").OnServerEvent:Connect(onInput)
	Remotes.event("ForgeWatch").OnServerEvent:Connect(onWatch)
	RunService.Heartbeat:Connect(step)
	Players.PlayerRemoving:Connect(function(player)
		watchers[player] = nil
		local s = sessions[player]
		if s and not s.settling then
			s.sim:finish("OPERATOR LEFT")
			settle(s, false)
		end
		inputLimiter:forget(player)
		actionLimiter:forget(player)
	end)
end

-- BindToClose: end every run and settle synchronously (in parallel).
function ForgeService.abortAll()
	local threads = {}
	for _, s in sessions do
		if not s.settling then
			s.sim:finish("SERVER SHUTDOWN")
			table.insert(threads, task.spawn(settle, s, true))
		end
	end
	local deadline = os.clock() + 20
	while os.clock() < deadline do
		local busy = false
		for _, t in threads do
			if coroutine.status(t) ~= "dead" then
				busy = true
			end
		end
		if not busy then
			break
		end
		task.wait(0.1)
	end
end

return ForgeService
