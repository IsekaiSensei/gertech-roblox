--!strict
-- TETRAFORGE station server logic (timer-based adaptation of Godot's Tetris Forge Foundry).
-- Flow: ProximityPrompt -> client UI -> StartCraft(recipeId, rows) -> server validates
-- everything -> atomic spend from the SHARED inventory -> server timer -> outputs to the
-- SHARED inventory -> XP to the operator.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local ItemDefs = require(Shared.ItemDefs)
local ProgressionDefs = require(Shared.ProgressionDefs)
local RecipeDefs = require(Shared.RecipeDefs)
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)
local Inventory = require(script.Parent.WorkshopInventoryService)
local RateLimiter = require(script.Parent.RateLimiter)

type Job = {
	recipeId: string,
	rows: number,
	startedAt: number,
	duration: number,
	cancelled: boolean,
	finished: boolean,
}

local ForgeService = {}

local jobs: { [Player]: Job } = {}
local limiter = RateLimiter.new(4, 0.5)
local consolePart: BasePart? = nil

local function notify(player: Player, text: string, kind: string?)
	Remotes.event("Notify"):FireClient(player, text, kind or "info")
end

local function activeJobCount(): number
	local n = 0
	for _, j in jobs do
		if not j.finished then
			n += 1
		end
	end
	return n
end

local function nearConsole(player: Player): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not consolePart or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - consolePart.Position).Magnitude <= Config.STATION_MAX_DISTANCE
end

local function pushState(player: Player)
	local j = jobs[player]
	if j and not j.finished then
		Remotes.event("ForgeState"):FireClient(player, {
			active = true,
			recipeId = j.recipeId,
			rows = j.rows,
			startedAt = j.startedAt,
			duration = j.duration,
		})
	else
		Remotes.event("ForgeState"):FireClient(player, { active = false })
	end
end

local function updateConsoleVisual()
	if not consolePart then
		return
	end
	local busy = activeJobCount() > 0
	consolePart.Color = if busy then Color3.fromRGB(255, 140, 60) else Color3.fromRGB(60, 200, 255)
	local light = consolePart:FindFirstChildOfClass("PointLight")
	if light then
		light.Brightness = if busy then 4 else 1.5
		light.Color = consolePart.Color
	end
end

-- Finish (or abort) a job. Completed rows crystallize; uncrystallized cells -> scrap (canon).
local function settle(player: Player, job: Job, completedRows: number)
	if job.finished then
		return
	end
	job.finished = true
	local recipe = RecipeDefs.get(job.recipeId) :: RecipeDefs.Recipe
	local produced = RecipeDefs.scaled(recipe.outputsPerRow, completedRows)
	local leftoverCells = (job.rows - completedRows) * Config.FORGE_ROW_WIDTH
	local scrap = RecipeDefs.scrapForCells(leftoverCells)
	if scrap > 0 then
		produced.scrap = (produced.scrap or 0) + scrap
	end
	local score = RecipeDefs.scoreForRows(completedRows)
	-- Atomic receipt: outputs + run counter + event log entry (Godot: apply_material_receipt).
	Inventory.transact("forge_receipt", function(d)
		for k, n in produced do
			d.inventory[k] = (d.inventory[k] or 0) + n
		end
		d.foundryRuns += 1
		table.insert(d.log, {
			t = os.time(),
			kind = "minigame_receipt",
			actor = "tetraforge:" .. player.UserId,
			details = { produced = produced, rows = completedRows, score = score },
		})
		while #d.log > 50 do
			table.remove(d.log, 1)
		end
		return true, nil
	end)
	if player.Parent then
		if completedRows > 0 then
			DataService.addXp(player, score * ProgressionDefs.XP_PER_SCORE)
			DataService.addStat(player, "rowsForged", completedRows)
		end
		local parts = {}
		for k, n in produced do
			if n > 0 then
				table.insert(parts, n .. " " .. (ItemDefs.get(k) :: any).name)
			end
		end
		notify(
			player,
			if #parts > 0
				then "TETRAFORGE output: " .. table.concat(parts, ", ")
				else "TETRAFORGE run ended with no output.",
			"good"
		)
	end
	jobs[player] = nil
	updateConsoleVisual()
	if player.Parent then
		pushState(player)
	end
end

local function startCraft(player: Player, recipeId: any, rows: any)
	if not limiter:allow(player) then
		return
	end
	-- Type and range validation: never trust the client.
	if type(recipeId) ~= "string" or type(rows) ~= "number" then
		return
	end
	if rows ~= rows or rows ~= math.floor(rows) or rows < 1 or rows > Config.FORGE_MAX_ROWS_PER_RUN then
		return notify(player, "Rows must be 1 to " .. Config.FORGE_MAX_ROWS_PER_RUN .. ".", "bad")
	end
	local recipe = RecipeDefs.get(recipeId)
	if not recipe then
		return
	end
	if not DataService.get(player) then
		return notify(player, "Your save is still loading.", "bad")
	end
	if not DataService.hasRecipe(player, recipe.id) then
		return notify(player, recipe.name .. " unlocks at level " .. recipe.unlockLevel .. ".", "bad")
	end
	if not nearConsole(player) then
		return notify(player, "Stand at the TETRAFORGE operator console.", "bad")
	end
	if jobs[player] then
		return notify(player, "You already have a TETRAFORGE run in progress.", "bad")
	end
	if activeJobCount() >= Config.FORGE_MAX_CONCURRENT_JOBS then
		return notify(player, "All TETRAFORGE chambers are busy.", "bad")
	end
	-- CANON: alloy pieces only when the workshop holds >= 4 pure components.
	if
		recipe.requiresAlloyEnabled
		and Inventory.amount("pure_component") < RecipeDefs.ALLOY_ENABLE_THRESHOLD
	then
		return notify(player, "Alloy needs at least 4 Pure Components in the workshop.", "bad")
	end
	local cost = RecipeDefs.scaled(recipe.inputsPerRow, rows)
	-- Reserve the slot before yielding on the DataStore so double-clicks cannot double-spend.
	local job: Job = {
		recipeId = recipe.id,
		rows = rows,
		startedAt = workspace:GetServerTimeNow(),
		duration = rows * Config.FORGE_SECONDS_PER_ROW,
		cancelled = false,
		finished = false,
	}
	jobs[player] = job
	local ok, reason = Inventory.consume(cost, nil, "tetraforge:" .. player.UserId, "forge_feed")
	if not ok then
		jobs[player] = nil
		return notify(player, reason or "Not enough feed stock.", "bad")
	end
	job.startedAt = workspace:GetServerTimeNow()
	updateConsoleVisual()
	pushState(player)
	notify(player, "Feed stock accepted. Forging " .. rows .. " x " .. recipe.name .. ".", "info")
	task.spawn(function()
		local deadline = job.startedAt + job.duration
		while not job.finished and not job.cancelled and workspace:GetServerTimeNow() < deadline do
			task.wait(0.25)
		end
		if job.finished then
			return
		end
		if job.cancelled then
			local elapsed = workspace:GetServerTimeNow() - job.startedAt
			settle(player, job, math.clamp(math.floor(elapsed / Config.FORGE_SECONDS_PER_ROW), 0, job.rows))
		else
			settle(player, job, job.rows)
		end
	end)
end

local function cancelCraft(player: Player)
	if not limiter:allow(player) then
		return
	end
	local j = jobs[player]
	if j and not j.finished then
		j.cancelled = true
	end
end

function ForgeService.bindConsole(console: BasePart, prompt: ProximityPrompt)
	consolePart = console
	prompt.Triggered:Connect(function(player)
		if not DataService.get(player) then
			return
		end
		Remotes.event("OpenForge"):FireClient(player)
		pushState(player)
	end)
	updateConsoleVisual()
end

function ForgeService.start()
	Remotes.event("StartCraft").OnServerEvent:Connect(startCraft)
	Remotes.event("CancelCraft").OnServerEvent:Connect(cancelCraft)
	Players.PlayerRemoving:Connect(function(player)
		-- Leaving mid-run aborts it: finished rows are kept, the rest becomes scrap.
		local j = jobs[player]
		if j and not j.finished then
			j.cancelled = true
		end
		limiter:forget(player)
	end)
end

-- Called from BindToClose: settle every running job as an abort.
function ForgeService.abortAll()
	for player, j in jobs do
		if not j.finished then
			local elapsed = workspace:GetServerTimeNow() - j.startedAt
			settle(player, j, math.clamp(math.floor(elapsed / Config.FORGE_SECONDS_PER_ROW), 0, j.rows))
		end
	end
end

return ForgeService
