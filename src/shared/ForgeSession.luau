--!strict
-- One TETRAFORGE run: a faithful port of Godot theme_foundry/forge_foundry.gd game logic
-- (state, spawn, move, rotate with kicks, hold, soft/hard drop, gravity with heat, lock,
-- line clears -> outputs, scoring, end conditions, result dictionary).
-- Engine-free: the server owns an instance; the RNG is injected (Random on Roblox).
-- Rendering, input devices and inventory are NOT here (same independence rule as Godot).

local ForgeFeed = require(script.Parent.ForgeFeed)
local ForgeRules = require(script.Parent.ForgeRules)
local TetrominoGrid = require(script.Parent.TetrominoGrid)

local ForgeSession = {}
ForgeSession.__index = ForgeSession

export type Config = {
	inputs: { [string]: number }?, -- Godot: fixed budget (ore / salvage / pure_component)
	feed: ForgeFeed.Feed?, -- Roblox: live feed (whole shared stock via a reserved hopper)
	enableAlloy: boolean,
	targetLines: number?,
	gravitySeconds: number?,
}

export type Result = {
	win: boolean,
	score: number,
	materialsConsumed: { [string]: number },
	materialsProduced: { [string]: number },
	forgeHeat: number,
	stats: { lines: number, tetrises: number, holdUsed: boolean, pieces: number, seconds: number },
	station: string,
	reason: string,
}

local function new(config: Config, rng: ForgeRules.Rng)
	local self = {
		grid = TetrominoGrid.new(),
		rng = rng,
		inputBudget = table.clone(config.inputs or {}),
		feed = (config.feed or ForgeFeed.static(config.inputs or {})) :: any,
		pendingMaterials = nil :: { string }?, -- chosen piece cells waiting for the hopper
		waitingFeed = false,
		alloyEnabled = config.enableAlloy,
		targetLines = math.max(1, config.targetLines or ForgeRules.TARGET_LINES),
		gravitySeconds = config.gravitySeconds or ForgeRules.GRAVITY_SECONDS,
		activeShape = "",
		activeX = ForgeRules.SPAWN_X,
		activeY = 0,
		activeRotation = 0,
		activeMaterials = {} :: { string },
		nextShape = "",
		heldShape = "",
		canHold = true,
		holdUsed = false,
		materialSpent = { ore = 0, salvage = 0, pure_component = 0 } :: { [string]: number },
		materialProduced = { packed_block = 0, stabilized_frame = 0, forged_blank = 0, scrap = 0 } :: { [string]: number },
		linesCleared = 0,
		tetrises = 0,
		piecesLocked = 0,
		score = 0,
		heat = ForgeRules.HEAT_START,
		gravityTimer = 0,
		elapsed = 0,
		softDrop = false,
		running = false,
		paused = false,
		finished = false,
		status = "FEED STOCK ACCEPTED",
		result = nil :: Result?,
		lastClear = 0, -- rows cleared by the most recent lock (for UI / tests)
		version = 0, -- bumps on every visible change (replication)
	}
	return setmetatable(self, ForgeSession)
end
ForgeSession.new = new

export type Session = typeof(new(({} :: any) :: Config, ({} :: any) :: ForgeRules.Rng))

local function touch(self: Session)
	self.version += 1
end

local function randomShape(self: Session): string
	return ForgeRules.PIECE_NAMES[self.rng:NextInteger(1, #ForgeRules.PIECE_NAMES)]
end

local endRun: (Session, string) -> ()

local function remainingFeed(self: Session): { [string]: number }
	local left = {}
	for _, k in ForgeRules.FEED_MATERIALS do
		left[k] = self.feed:remaining(k, self.materialSpent[k] or 0)
	end
	return left
end

local function obtainable(self: Session, materials: { string }): boolean
	for k, n in ForgeFeed.counts(materials) do
		if self.feed:remaining(k, self.materialSpent[k] or 0) < n then
			return false
		end
	end
	return true
end

-- CANON spawn order: choose materials, take the next shape, roll a new next shape.
-- ADAPTED: if the chosen cells are not in the hopper yet, the spawn waits (no RNG is drawn
-- again) until the host tops the hopper up. A static (Godot) feed never waits.
local function spawnPiece(self: Session)
	local pending = self.pendingMaterials
	local mats: { string }
	if pending and obtainable(self, pending) then
		mats = pending
	else
		-- (re)choose; a pending choice is dropped if others spent the shared stock meanwhile
		mats = ForgeRules.chooseMaterials(remainingFeed(self), {}, self.alloyEnabled, self.rng)
		if #mats == 0 then
			self.pendingMaterials, self.waitingFeed = nil, false
			self.activeMaterials = {}
			endRun(self, "INPUT HOPPERS EMPTY")
			return
		end
	end
	if not self.feed:covers(mats, self.materialSpent) then
		self.pendingMaterials, self.waitingFeed = mats, true
		self.activeShape, self.activeMaterials = "", {}
		self.status = "FEED HOPPER REFILLING"
		return
	end
	self.pendingMaterials, self.waitingFeed = nil, false
	self.activeMaterials = mats
	self.activeShape = self.nextShape
	self.nextShape = randomShape(self)
	self.activeX, self.activeY = ForgeRules.SPAWN_X, ForgeRules.SPAWN_Y
	self.activeRotation = 0
	self.canHold = true
	if not self.grid:fits(self.activeShape, self.activeRotation, self.activeX, self.activeY) then
		endRun(self, "FORGE CHAMBER FULL")
	end
end

function ForgeSession.start(self: Session)
	self.running = true
	self.paused = false
	self.activeShape = ""
	self.nextShape = randomShape(self)
	spawnPiece(self)
	touch(self)
end

local function canAct(self: Session): boolean
	return self.running and not self.paused and not self.finished and not self.waitingFeed
end

local function move(self: Session, dx: number, dy: number): boolean
	local cx, cy = self.activeX + dx, self.activeY + dy
	if self.grid:fits(self.activeShape, self.activeRotation, cx, cy) then
		self.activeX, self.activeY = cx, cy
		return true
	end
	return false
end

local function lockPiece(self: Session)
	if self.finished then
		return
	end
	for _, m in self.activeMaterials do
		self.materialSpent[m] = (self.materialSpent[m] or 0) + 1
	end
	local outcome = self.grid:lock(
		self.activeShape,
		self.activeRotation,
		self.activeX,
		self.activeY,
		self.activeMaterials
	)
	self.piecesLocked += 1
	self.heat = math.min(1, self.heat + ForgeRules.HEAT_PER_LOCK)
	local rows = outcome.clearedRows
	self.lastClear = #rows
	if #rows > 0 then
		self.linesCleared += #rows
		self.score += ForgeRules.scoreForClear(#rows)
		self.heat = math.min(1, self.heat + #rows * ForgeRules.HEAT_PER_ROW)
		if #rows == 4 then
			self.tetrises += 1
		end
		for _, tally in rows do
			for k, n in ForgeRules.rowOutputs(tally) do
				self.materialProduced[k] = (self.materialProduced[k] or 0) + n
			end
		end
		self.status = string.format("%d COMPLETE ROWS CRYSTALLIZED / OUTPUT EJECTED", #rows)
	else
		self.status = self.activeShape .. " BATCH PACKED INTO FORGE"
	end
	if outcome.overflow then
		endRun(self, "MATERIAL OVERFLOW")
	elseif self.linesCleared >= self.targetLines then
		endRun(self, "OUTPUT QUOTA MET")
	else
		spawnPiece(self)
	end
	touch(self)
end

function endRun(self: Session, reason: string)
	if self.finished then
		return
	end
	self.finished = true
	self.running = false
	self.status = reason
	-- CANON: any uncrystallized locked cells become scrap; completed rows left the grid.
	self.materialProduced.scrap = ForgeRules.scrapFor(self.grid:remainingCells())
	self.result = {
		win = self.linesCleared >= self.targetLines,
		score = self.score,
		materialsConsumed = table.clone(self.materialSpent),
		materialsProduced = table.clone(self.materialProduced),
		forgeHeat = math.round(self.heat * 100) / 100,
		stats = {
			lines = self.linesCleared,
			tetrises = self.tetrises,
			holdUsed = self.holdUsed,
			pieces = self.piecesLocked,
			seconds = math.round(self.elapsed * 10) / 10,
		},
		station = "tetris_forge_foundry",
		reason = reason,
	}
	touch(self)
end

---------------------------------------------------------------- inputs (Godot key handlers)

function ForgeSession.moveLeft(self: Session): boolean
	if not canAct(self) then
		return false
	end
	local ok = move(self, -1, 0)
	if ok then
		touch(self)
	end
	return ok
end

function ForgeSession.moveRight(self: Session): boolean
	if not canAct(self) then
		return false
	end
	local ok = move(self, 1, 0)
	if ok then
		touch(self)
	end
	return ok
end

-- CANON: try kicks 0, -1, +1, -2, +2
function ForgeSession.rotate(self: Session): boolean
	if not canAct(self) then
		return false
	end
	for _, offset in ForgeRules.ROTATION_KICKS do
		local cx = self.activeX + offset
		if self.grid:fits(self.activeShape, self.activeRotation + 1, cx, self.activeY) then
			self.activeRotation += 1
			self.activeX = cx
			touch(self)
			return true
		end
	end
	return false
end

function ForgeSession.setSoftDrop(self: Session, on: boolean)
	self.softDrop = on
end

function ForgeSession.hardDrop(self: Session)
	if not canAct(self) then
		return
	end
	local falling = true
	while falling do
		falling = move(self, 0, 1)
	end
	lockPiece(self)
end

-- CANON: _hold_piece (keeps the active piece's materials; once per spawned piece)
function ForgeSession.hold(self: Session)
	if not canAct(self) or not self.canHold then
		return
	end
	self.holdUsed = true
	self.canHold = false
	if self.heldShape == "" then
		self.heldShape = self.activeShape
		self.activeShape = self.nextShape
		self.nextShape = randomShape(self)
	else
		self.activeShape, self.heldShape = self.heldShape, self.activeShape
	end
	self.activeRotation = 0
	self.activeX, self.activeY = ForgeRules.SPAWN_X, ForgeRules.SPAWN_Y
	if not self.grid:fits(self.activeShape, self.activeRotation, self.activeX, self.activeY) then
		endRun(self, "FORGE CHAMBER FULL")
	end
	touch(self)
end

function ForgeSession.pause(self: Session)
	if self.running and not self.finished then
		self.paused = true
		touch(self)
	end
end

function ForgeSession.resume(self: Session)
	if self.paused then
		self.paused = false
		touch(self)
	end
end

-- Godot Esc = "RETURN TO THE LOFT"; the host also ends runs for leave/shutdown.
function ForgeSession.finish(self: Session, reason: string)
	endRun(self, reason)
end

-- CANON: _process gravity tick. Returns true if anything visible changed.
function ForgeSession.update(self: Session, dt: number): boolean
	if not self.running or self.paused or self.finished then
		return false
	end
	local before = self.version
	self.elapsed += dt
	if self.waitingFeed then
		spawnPiece(self)
		if not self.waitingFeed then
			self.gravityTimer = 0
			touch(self)
		end
		return self.version ~= before
	end
	self.gravityTimer += dt
	local interval = ForgeRules.gravityInterval(self.gravitySeconds, self.heat, self.softDrop)
	if self.gravityTimer >= interval then
		self.gravityTimer = 0
		if move(self, 0, 1) then
			touch(self)
		else
			lockPiece(self)
		end
	end
	return self.version ~= before
end

function ForgeSession.activeCells(self: Session): { TetrominoGrid.Point }
	if self.finished or self.activeShape == "" then
		return {}
	end
	return TetrominoGrid.occupied(self.activeShape, self.activeRotation, self.activeX, self.activeY)
end

-- Static (Godot) feed only: unspent part of the fixed budget, including the active,
-- not-yet-locked piece. A hopper feed computes its own refund (ForgeFeed.hopper:refund).
function ForgeSession.refund(self: Session): { [string]: number }
	local out = {}
	for _, k in ForgeRules.FEED_MATERIALS do
		out[k] = math.max(0, (self.inputBudget[k] or 0) - (self.materialSpent[k] or 0))
	end
	return out
end

-- Full instance type (fields + methods) for hosts; declared after every method exists.
export type Instance = Session & typeof(ForgeSession)

return ForgeSession
