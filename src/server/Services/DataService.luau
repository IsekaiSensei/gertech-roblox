--!strict
-- Per-player persistent progression with session locking via UpdateAsync.
-- Shared materials do NOT live here: they live in WorkshopInventoryService (one key per
-- workshop), mirroring Godot's single WorldSeed inventory authority.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local ProgressionDefs = require(Shared.ProgressionDefs)
local RecipeDefs = require(Shared.RecipeDefs)
local Remotes = require(Shared.Remotes)
local StoreUtil = require(script.Parent.StoreUtil)

local DATA_VERSION = 1

export type Profile = {
	version: number,
	xp: number,
	level: number,
	unlockedRecipes: { string },
	stats: { rowsForged: number, gathered: number, socketsPlaced: number },
	sessionLock: { jobId: string, time: number }?,
}

local DataService = {}

local store: any = nil
local profiles: { [Player]: Profile } = {}
local dirty: { [Player]: boolean } = {}
local loadedCallbacks: { (Player, Profile) -> () } = {}

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

local function jobId(): string
	return game.JobId ~= "" and game.JobId or "studio"
end

local function defaultProfile(): Profile
	return {
		version = DATA_VERSION,
		xp = 0,
		level = 1,
		unlockedRecipes = {},
		stats = { rowsForged = 0, gathered = 0, socketsPlaced = 0 },
		sessionLock = nil,
	}
end

local function reconcile(data: any): Profile
	local p = defaultProfile()
	if type(data) ~= "table" then
		return p
	end
	p.xp = math.max(0, tonumber(data.xp) or 0)
	p.level = ProgressionDefs.levelForXp(p.xp)
	if type(data.unlockedRecipes) == "table" then
		for _, id in data.unlockedRecipes do
			if RecipeDefs.get(id) then
				table.insert(p.unlockedRecipes, id)
			end
		end
	end
	if type(data.stats) == "table" then
		for k in p.stats do
			p.stats[k] = math.max(0, tonumber(data.stats[k]) or 0)
		end
	end
	return p
end

-- Unlock every recipe whose level gate is met (never removes an unlock).
local function refreshUnlocks(p: Profile)
	local have = {}
	for _, id in p.unlockedRecipes do
		have[id] = true
	end
	for _, id in RecipeDefs.ORDER do
		local r = RecipeDefs.get(id)
		if r and not have[id] and p.level >= r.unlockLevel then
			table.insert(p.unlockedRecipes, id)
		end
	end
end

local function pushProgression(player: Player)
	local p = profiles[player]
	if not p then
		return
	end
	Remotes.event("ProgressionUpdated"):FireClient(player, {
		xp = p.xp,
		level = p.level,
		nextLevelXp = ProgressionDefs.xpForLevel(p.level + 1),
		levelXp = ProgressionDefs.xpForLevel(p.level),
		unlockedRecipes = p.unlockedRecipes,
		stats = p.stats,
	})
end
DataService.pushProgression = pushProgression

local function serialize(p: Profile): any
	return {
		version = DATA_VERSION,
		xp = p.xp,
		level = p.level,
		unlockedRecipes = table.clone(p.unlockedRecipes),
		stats = table.clone(p.stats),
	}
end

-- Acquire the session lock and load. Returns nil if the player left or the load failed.
local function loadProfile(player: Player): Profile?
	local key = keyFor(player)
	local tries = 0
	while player.Parent do
		tries += 1
		local blocked = false
		local loaded: any = nil
		local forceSteal = tries > 6 -- after ~30s assume the other server crashed
		local ok, err = StoreUtil.retry("Load " .. key, function()
			store:UpdateAsync(key, function(old: any)
				blocked = false
				if type(old) == "table" and type(old.sessionLock) == "table" then
					local lock = old.sessionLock
					local fresh = (os.time() - (tonumber(lock.time) or 0)) < Config.SESSION_LOCK_STALE_SECONDS
					if lock.jobId ~= jobId() and fresh and not forceSteal then
						blocked = true
						return nil -- cancel the write; someone else holds the session
					end
				end
				local data = if type(old) == "table" then old else serialize(defaultProfile())
				data.sessionLock = { jobId = jobId(), time = os.time() }
				loaded = data
				return data
			end)
		end)
		if not ok then
			warn("[GERTECH] profile load failed for", player.Name, err)
			return nil
		end
		if not blocked and loaded then
			local p = reconcile(loaded)
			p.sessionLock = { jobId = jobId(), time = os.time() }
			return p
		end
		task.wait(5)
	end
	return nil
end

local function saveProfile(player: Player, release: boolean): boolean
	local p = profiles[player]
	if not p then
		return false
	end
	local key = keyFor(player)
	local payload = serialize(p)
	local ok = StoreUtil.retry("Save " .. key, function()
		store:UpdateAsync(key, function(old: any)
			-- Never overwrite a session another server has taken over.
			if
				type(old) == "table"
				and type(old.sessionLock) == "table"
				and old.sessionLock.jobId ~= jobId()
			then
				return nil
			end
			payload.sessionLock = if release then nil else { jobId = jobId(), time = os.time() }
			return payload
		end)
	end)
	if ok then
		dirty[player] = nil
	end
	return ok
end

function DataService.get(player: Player): Profile?
	return profiles[player]
end

function DataService.onProfileLoaded(cb: (Player, Profile) -> ())
	table.insert(loadedCallbacks, cb)
end

function DataService.hasRecipe(player: Player, recipeId: string): boolean
	local p = profiles[player]
	if not p then
		return false
	end
	return table.find(p.unlockedRecipes, recipeId) ~= nil
end

function DataService.addXp(player: Player, amount: number)
	local p = profiles[player]
	if not p or amount <= 0 then
		return
	end
	local before = p.level
	p.xp += math.floor(amount)
	p.level = ProgressionDefs.levelForXp(p.xp)
	refreshUnlocks(p)
	dirty[player] = true
	if p.level > before then
		Remotes.event("Notify")
			:FireClient(player, "Level " .. p.level .. "! New TETRAFORGE recipes may be unlocked.", "good")
	end
	pushProgression(player)
end

function DataService.addStat(player: Player, stat: string, amount: number)
	local p = profiles[player]
	if not p or (p.stats :: any)[stat] == nil then
		return
	end
	(p.stats :: any)[stat] += amount
	dirty[player] = true
end

local function onPlayerAdded(player: Player)
	local p = loadProfile(player)
	if not p then
		if player.Parent then
			player:Kick("GERTECH could not load your save. Please rejoin in a minute.")
		end
		return
	end
	if not player.Parent then
		-- Left during load: release the lock we just took.
		profiles[player] = p
		saveProfile(player, true)
		profiles[player] = nil
		return
	end
	refreshUnlocks(p)
	profiles[player] = p
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local lv = Instance.new("IntValue")
	lv.Name = "Level"
	lv.Value = p.level
	lv.Parent = ls
	ls.Parent = player
	for _, cb in loadedCallbacks do
		task.spawn(cb, player, p)
	end
	pushProgression(player)
end

local function onPlayerRemoving(player: Player)
	if profiles[player] then
		saveProfile(player, true)
		profiles[player] = nil
		dirty[player] = nil
	end
end

function DataService.saveAll(release: boolean)
	local threads = {}
	for player in profiles do
		table.insert(
			threads,
			task.spawn(function()
				saveProfile(player, release)
			end)
		)
	end
	local deadline = os.clock() + 25
	while os.clock() < deadline do
		local running = false
		for _, t in threads do
			if coroutine.status(t) ~= "dead" then
				running = true
				break
			end
		end
		if not running then
			break
		end
		task.wait(0.2)
	end
end

function DataService.start()
	store = StoreUtil.getStore(Config.DATASTORE_PLAYERS)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, pl in Players:GetPlayers() do
		task.spawn(onPlayerAdded, pl)
	end
	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_SECONDS)
			for player in profiles do
				-- Always refresh the lock timestamp; write data if dirty.
				task.spawn(saveProfile, player, false)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for player, p in profiles do
				local ls = player:FindFirstChild("leaderstats")
				local lv = ls and ls:FindFirstChild("Level")
				if lv and lv:IsA("IntValue") then
					lv.Value = p.level
				end
			end
		end
	end)
end

return DataService
