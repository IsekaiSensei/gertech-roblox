-- Offline tests for engine-free modules (TETRAFORGE board, rules, session; data defs).
-- Run: bash tests/run.sh  (needs the `luau` CLI). The runner rewrites script.Parent requires.

local DecorGeometry = require("./build/DecorGeometry")
local ForgeFeed = require("./build/ForgeFeed")
local ImageAssets = require("./build/ImageAssets")
local ForgeRules = require("./build/ForgeRules")
local ForgeSession = require("./build/ForgeSession")
local ItemDefs = require("./build/ItemDefs")
local ProgressionDefs = require("./build/ProgressionDefs")
local RecipeDefs = require("./build/RecipeDefs")
local TetrominoGrid = require("./build/TetrominoGrid")

local passed, failed = 0, 0
local function check(name: string, cond: boolean)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL: " .. name)
	end
end

-- Deterministic stand-in for Roblox Random (same method names)
local function lcg(seed: number)
	local state = seed
	local rng = {}
	local function nextRaw(): number
		state = (state * 1103515245 + 12345) % 2147483648
		return state
	end
	function rng:NextInteger(min: number, max: number): number
		return min + nextRaw() % (max - min + 1)
	end
	function rng:NextNumber(): number
		return nextRaw() / 2147483648
	end
	return rng
end

local function samePoints(a, b): boolean
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i].x ~= b[i].x or a[i].y ~= b[i].y then
			return false
		end
	end
	return true
end

---------------------------------------------------------------- TetrominoGrid (Godot parity)
local g = TetrominoGrid.new()
check("grid 10x20", TetrominoGrid.WIDTH == 10 and TetrominoGrid.HEIGHT == 20)
check("empty grid", g:remainingCells() == 0)
local shapeCount = 0
for name, cells in TetrominoGrid.SHAPES do
	shapeCount += 1
	check("shape " .. name .. " has 4 cells", #cells == 4)
end
check("7 pieces", shapeCount == 7 and #ForgeRules.PIECE_NAMES == 7)

-- rotation: (x, y) -> (-y, x); O never rotates; posmod for negative turns
check(
	"T rot1",
	samePoints(
		TetrominoGrid.rotated("T", 1),
		{ { x = 0, y = -1 }, { x = 0, y = 0 }, { x = 0, y = 1 }, { x = -1, y = 0 } }
	)
)
check("O fixed", samePoints(TetrominoGrid.rotated("O", 3), TetrominoGrid.SHAPES.O))
check("I rot4 = rot0", samePoints(TetrominoGrid.rotated("I", 4), TetrominoGrid.rotated("I", 0)))
check("T rot-1 = rot3", samePoints(TetrominoGrid.rotated("T", -1), TetrominoGrid.rotated("T", 3)))

-- fits
check("I fits at spawn", g:fits("I", 0, 4, 1))
check("I blocked by left wall", not g:fits("I", 0, 0, 1))
check("I blocked by right wall", not g:fits("I", 0, 8, 1))
check("floor blocks", not g:fits("O", 0, 4, 19))
check("above top allowed", g:fits("O", 0, 4, -1))

-- single line clear with tally + shift
local g1 = TetrominoGrid.new()
for x = 0, 5 do
	g1:set(x, 19, "ore")
end
g1:set(0, 18, "pure_component") -- marker above
local out1 = g1:lock("I", 0, 7, 19, { "salvage", "salvage", "salvage", "salvage" })
check("one row cleared", #out1.clearedRows == 1 and not out1.overflow)
check("tally ore 6 salvage 4", out1.clearedRows[1].ore == 6 and out1.clearedRows[1].salvage == 4)
check("rows shifted down", g1:at(0, 19) == "pure_component" and g1:at(0, 18) == "")
check("remaining after clear", g1:remainingCells() == 1)
local ro = ForgeRules.rowOutputs(out1.clearedRows[1])
check("row -> block + frame", ro.packed_block == 1 and ro.stabilized_frame == 1 and ro.forged_blank == nil)
check("row with 2 pure -> blank", ForgeRules.rowOutputs({ ore = 8, pure_component = 2 }).forged_blank == 1)
check(
	"row with 3 salvage -> no frame",
	ForgeRules.rowOutputs({ ore = 7, salvage = 3 }).stabilized_frame == nil
)

-- four-row clear (vertical I in the last column)
local g4 = TetrominoGrid.new()
for y = 16, 19 do
	for x = 0, 8 do
		g4:set(x, y, "ore")
	end
end
local out4 = g4:lock("I", 1, 9, 17, { "ore", "ore", "ore", "ore" })
check("four rows cleared", #out4.clearedRows == 4)
check("board empty after tetris", g4:remainingCells() == 0)

-- overflow
local go = TetrominoGrid.new()
check("overflow flagged", go:lock("O", 0, 4, -1, { "ore", "ore", "ore", "ore" }).overflow)

-- encode
check("encode length", #g1:encode(ForgeRules.CODES) == 200)

---------------------------------------------------------------- ForgeRules (Godot formulas)
check("score 1", ForgeRules.scoreForClear(1) == 100)
check("score 2", ForgeRules.scoreForClear(2) == 400)
check("score 3", ForgeRules.scoreForClear(3) == 900)
check("score 4 (+400)", ForgeRules.scoreForClear(4) == 2000)
check("score 0", ForgeRules.scoreForClear(0) == 0)
check("scrap 9 -> 1", ForgeRules.scrapFor(9) == 1)
check("scrap 4 -> 0", ForgeRules.scrapFor(4) == 0)
check(
	"gravity at start heat",
	math.abs(ForgeRules.gravityInterval(0.62, 0.19, false) - 0.62 * (1 - 0.19 * 0.34)) < 1e-9
)
check("gravity floor 0.09", ForgeRules.gravityInterval(0.1, 1, false) == 0.09)
check("soft drop x0.11", math.abs(ForgeRules.gravityInterval(0.62, 0, true) - 0.62 * 0.11) < 1e-9)
check("8-row quota", ForgeRules.TARGET_LINES == 8)

-- chooseMaterials
local rngLow = {
	NextInteger = function(_, min: number, _max: number)
		return min
	end,
	NextNumber = function()
		return 0.1
	end,
}
local rngHigh = {
	NextInteger = function(_, min: number, _max: number)
		return min
	end,
	NextNumber = function()
		return 0.9
	end,
}
local spent0 = { ore = 0, salvage = 0, pure_component = 0 }
check(
	"empty hoppers",
	#ForgeRules.chooseMaterials({ ore = 3, salvage = 3, pure_component = 16 }, spent0, true, rngLow) == 0
)
local m1 = ForgeRules.chooseMaterials({ ore = 8, salvage = 0, pure_component = 0 }, spent0, false, rngLow)
check("plain ore piece", m1[1] == "ore" and m1[2] == "ore" and m1[3] == "ore" and m1[4] == "ore")
local m2 = ForgeRules.chooseMaterials({ ore = 8, salvage = 0, pure_component = 4 }, spent0, true, rngLow)
check(
	"alloy piece pattern",
	m2[1] == "ore" and m2[2] == "pure_component" and m2[3] == "ore" and m2[4] == "pure_component"
)
check(
	"no alloy when roll high",
	ForgeRules.chooseMaterials({ ore = 8, pure_component = 4 }, spent0, true, rngHigh)[2] == "ore"
)
check(
	"no alloy when disabled",
	ForgeRules.chooseMaterials({ ore = 8, pure_component = 4 }, spent0, false, rngLow)[2] == "ore"
)
check(
	"no alloy when pure < 2",
	ForgeRules.chooseMaterials({ ore = 8, pure_component = 1 }, spent0, true, rngLow)[2] == "ore"
)
check(
	"spent counts against budget",
	#ForgeRules.chooseMaterials({ ore = 8 }, { ore = 5, salvage = 0, pure_component = 0 }, false, rngLow) == 0
)

---------------------------------------------------------------- ForgeSession
local function newSession(budget, seed)
	return ForgeSession.new({ inputs = budget, enableAlloy = (budget.pure_component or 0) >= 4 }, lcg(seed))
end

-- spawn + gravity tick
local s1 = newSession({ ore = 120, salvage = 56, pure_component = 16 }, 7)
s1:start()
check("spawned at (4,1)", s1.activeX == 4 and s1.activeY == 1 and s1.activeShape ~= "" and s1.nextShape ~= "")
local interval = ForgeRules.gravityInterval(0.62, s1.heat, false)
s1:update(interval * 0.5)
check("no fall before interval", s1.activeY == 1)
s1:update(interval * 0.6)
check("falls one row after interval", s1.activeY == 2)

-- hold: once per piece, keeps materials
local mats = table.clone(s1.activeMaterials)
local shapeBefore, nextBefore = s1.activeShape, s1.nextShape
s1:hold()
check("hold stores shape", s1.heldShape == shapeBefore and s1.activeShape == nextBefore)
check("hold keeps materials", s1.activeMaterials[1] == mats[1] and s1.activeMaterials[2] == mats[2])
check("hold resets to spawn", s1.activeX == 4 and s1.activeY == 1 and s1.activeRotation == 0)
local heldAfter = s1.heldShape
s1:hold()
check("second hold ignored", s1.heldShape == heldAfter and not s1.canHold)

-- pause blocks gravity and inputs
s1:pause()
local y0 = s1.activeY
s1:update(5)
check("paused: no gravity", s1.activeY == y0)
check("paused: no move", not s1:moveLeft())
s1:resume()

-- tiny budget -> hoppers empty after one piece
local s2 = newSession({ ore = 4, salvage = 0, pure_component = 0 }, 3)
s2:start()
s2:hardDrop()
check("hoppers empty end", s2.finished and s2.status == "INPUT HOPPERS EMPTY")
check("tiny: spent 4 ore", s2.materialSpent.ore == 4)
check("tiny: refund 0", s2:refund().ore == 0)
check("tiny: scrap = 4/5 = 0", s2.result.materialsProduced.scrap == 0)

-- manual finish refunds the active piece's (unlocked) materials
local s3 = newSession({ ore = 40, salvage = 0, pure_component = 0 }, 5)
s3:start()
s3:finish("RETURN TO THE LOFT")
check("finish reason", s3.result.reason == "RETURN TO THE LOFT")
check("unlocked piece fully refunded", s3:refund().ore == 40 and s3.result.materialsConsumed.ore == 0)

-- Randomized full runs: invariants + scoring parity with the Godot formula
local runs, quota = 0, 0
for seed = 1, 200 do
	local budget = { ore = 120, salvage = 56, pure_component = 16 }
	local s = newSession(budget, seed)
	local driver = lcg(seed * 7919)
	s:start()
	local expectedScore, lockedPieces, guard = 0, 0, 0
	while not s.finished and guard < 2000 do
		guard += 1
		local act = driver:NextInteger(1, 10)
		if act <= 2 then
			s:moveLeft()
		elseif act <= 4 then
			s:moveRight()
		elseif act == 5 then
			s:rotate()
		elseif act == 6 then
			s:hold()
		else
			local before = s.piecesLocked
			s:hardDrop()
			if s.piecesLocked > before then
				lockedPieces += 1
				expectedScore += ForgeRules.scoreForClear(s.lastClear)
			end
		end
		s:update(0.05)
		if s.piecesLocked > lockedPieces then
			-- a gravity lock happened inside update
			lockedPieces = s.piecesLocked
			expectedScore += ForgeRules.scoreForClear(s.lastClear)
		end
	end
	runs += 1
	local r = s.result
	local spentTotal = 0
	for _, k in ForgeRules.FEED_MATERIALS do
		spentTotal += r.materialsConsumed[k]
		check("spent <= budget " .. seed .. k, r.materialsConsumed[k] <= budget[k])
		check("refund + spent = budget " .. seed .. k, s:refund()[k] + r.materialsConsumed[k] == budget[k])
	end
	check("finished " .. seed, s.finished and r ~= nil)
	check("4 cells per locked piece " .. seed, spentTotal == r.stats.pieces * 4)
	check("packed blocks = rows " .. seed, r.materialsProduced.packed_block == r.stats.lines)
	check(
		"frames/blanks <= rows " .. seed,
		r.materialsProduced.stabilized_frame <= r.stats.lines
			and r.materialsProduced.forged_blank <= r.stats.lines
	)
	check(
		"scrap = remaining/5 " .. seed,
		r.materialsProduced.scrap == math.floor(s.grid:remainingCells() / 5)
	)
	local onBoard = r.stats.lines * 10 + s.grid:remainingCells()
	if r.reason == "MATERIAL OVERFLOW" then
		check("overflow cells left the chamber " .. seed, spentTotal > onBoard)
	else
		check("cells conserved " .. seed, spentTotal == onBoard)
	end
	check("score parity " .. seed, r.score == expectedScore)
	check("lines never exceed quota + 3 " .. seed, r.stats.lines <= 8 + 3)
	if r.reason == "OUTPUT QUOTA MET" then
		quota += 1
		check("win flag " .. seed, r.win)
	end
end
check("ran 200 sessions", runs == 200)

-- Scripted quota run: two four-row clears end the run at the 8-row cap (Godot quota)
local sq = newSession({ ore = 120, salvage = 56, pure_component = 16 }, 11)
sq:start()
for round = 1, 2 do
	for y = 16, 19 do
		for x = 0, 8 do
			sq.grid:set(x, y, "salvage")
		end
	end
	sq.activeShape, sq.activeRotation, sq.activeX, sq.activeY = "I", 1, 9, 1
	sq.activeMaterials = { "salvage", "salvage", "salvage", "salvage" }
	sq:hardDrop()
	check("scripted clear " .. round, sq.lastClear == 4)
end
check("quota met", sq.finished and sq.result.reason == "OUTPUT QUOTA MET" and sq.result.win)
check("quota score 2 x 2000", sq.result.score == 4000)
check(
	"quota outputs: 8 blocks + 8 frames",
	sq.result.materialsProduced.packed_block == 8 and sq.result.materialsProduced.stabilized_frame == 8
)
check("tetris count", sq.result.stats.tetrises == 2)
print(string.format("  (randomized runs: %d, quota met in %d)", runs, quota))

---------------------------------------------------------------- whole-stock hopper feed
-- Fake shared workshop: `stock` is the unreserved shared stock; reserve/topUp move material
-- into the session's hopper atomically (as WorkshopInventoryService does).
local function fakeWorkshop(stock)
	local w = { stock = table.clone(stock) }
	function w.amount(k)
		return w.stock[k] or 0
	end
	function w.take(want)
		local granted = {}
		for k, n in want do
			local t = math.min(w.stock[k] or 0, n)
			w.stock[k] -= t
			granted[k] = t
		end
		return granted
	end
	return w
end

local function hopperSession(stock, seed, instant)
	local w = fakeWorkshop(stock)
	local initial = w.take(ForgeRules.HOPPER_TARGET)
	local feed = ForgeFeed.hopper(initial, w.amount)
	local sim = ForgeSession.new({
		feed = feed,
		enableAlloy = feed:remaining("pure_component", 0) >= ForgeRules.ALLOY_ENABLE_THRESHOLD,
	}, lcg(seed))
	local function service()
		-- what ForgeService.maybeTopUp does, with an instantly-landing atomic write
		local want = feed:wants(sim.materialSpent, if sim.waitingFeed then sim.pendingMaterials else nil)
		if want and instant then
			feed:credit(w.take(want))
		end
	end
	return sim, feed, w, service
end

-- Parity: with the same RNG, inputs and total stock, a hopper-fed run plays exactly like
-- Godot's whole-stock budget (same pieces, materials, board, score, outputs).
local parityRuns = 0
for seed = 1, 60 do
	local stock = { ore = 300 + seed * 3, salvage = 140 + seed, pure_component = 40 + seed % 7 }
	local godot = newSession(stock, seed)
	local sim, feed, w, service = hopperSession(stock, seed, true)
	local d1, d2 = lcg(seed * 31), lcg(seed * 31)
	godot:start()
	sim:start()
	service()
	local guard, inSync = 0, true
	while not godot.finished and guard < 3000 do
		guard += 1
		for _, pair in { { godot, d1 }, { sim, d2 } } do
			local s, d = pair[1], pair[2]
			local act = d:NextInteger(1, 10)
			if act <= 2 then
				s:moveLeft()
			elseif act <= 4 then
				s:moveRight()
			elseif act == 5 then
				s:rotate()
			elseif act == 6 then
				s:hold()
			else
				s:hardDrop()
			end
			s:update(0.05)
		end
		service()
		check("never waits with an instant hopper " .. seed, not sim.waitingFeed)
		if sim.activeShape ~= godot.activeShape or sim.score ~= godot.score then
			inSync = false
		end
		-- conservation: shared + hopper(unspent) + spent == initial stock, per kind
		for _, k in ForgeRules.FEED_MATERIALS do
			local spent = sim.materialSpent[k]
			if w.stock[k] + feed:left(k, spent) + spent ~= stock[k] then
				inSync = false
				check("conservation " .. seed .. k, false)
			end
			if w.stock[k] < 0 or feed:left(k, spent) < 0 then
				check("never negative " .. seed .. k, false)
			end
		end
	end
	parityRuns += 1
	check("parity in sync " .. seed, inSync and sim.finished == godot.finished)
	check("parity board " .. seed, sim.grid:encode(ForgeRules.CODES) == godot.grid:encode(ForgeRules.CODES))
	check("parity reason " .. seed, sim.result.reason == godot.result.reason)
	check("parity score " .. seed, sim.result.score == godot.result.score)
	for k, n in godot.result.materialsProduced do
		check("parity output " .. seed .. k, sim.result.materialsProduced[k] == n)
	end
	-- settlement: hopper refund goes back, spent is gone, nothing duplicated
	local refund = feed:refund(sim.result.materialsConsumed)
	for _, k in ForgeRules.FEED_MATERIALS do
		check(
			"settle restores unspent " .. seed .. k,
			w.stock[k] + refund[k] == stock[k] - sim.result.materialsConsumed[k]
		)
		check(
			"hopper never above target+piece " .. seed .. k,
			feed:left(k, sim.materialSpent[k]) <= ForgeRules.HOPPER_TARGET[k] + 4
		)
	end
end
check("ran parity runs", parityRuns == 60)

-- Whole stock: with a huge shared stock and the quota disabled, a run keeps drawing far past
-- the old 120/56/16 cap and the hopper never holds more than its target.
do
	local stock = { ore = 2000, salvage = 2000, pure_component = 400 }
	local w = fakeWorkshop(stock)
	local feed = ForgeFeed.hopper(w.take(ForgeRules.HOPPER_TARGET), w.amount)
	local sim = ForgeSession.new({ feed = feed, enableAlloy = true, targetLines = 100000 }, lcg(99))
	sim:start()
	local maxHeld, guard = 0, 0
	while not sim.finished and guard < 20000 do
		guard += 1
		-- clear the chamber so the run does not top out: we only test feed flow here
		for y = 0, 19 do
			for x = 0, 9 do
				sim.grid:set(x, y, "")
			end
		end
		sim:hardDrop()
		sim:update(0.05)
		local want = feed:wants(sim.materialSpent, if sim.waitingFeed then sim.pendingMaterials else nil)
		if want then
			feed:credit(w.take(want))
		end
		local held = 0
		for _, k in ForgeRules.FEED_MATERIALS do
			held += feed:left(k, sim.materialSpent[k])
		end
		maxHeld = math.max(maxHeld, held)
	end
	local spent = sim.materialSpent
	check("whole stock: hoppers empty at the end", sim.status == "INPUT HOPPERS EMPTY")
	check("whole stock: spent far beyond the old cap", spent.ore + spent.salvage > 3000)
	check(
		"whole stock: base stock exhausted (<4 left of each)",
		w.stock.ore + feed:left("ore", spent.ore) < 4
			and w.stock.salvage + feed:left("salvage", spent.salvage) < 4
	)
	check(
		"whole stock: hopper never above target total",
		maxHeld
			<= ForgeRules.HOPPER_TARGET.ore
				+ ForgeRules.HOPPER_TARGET.salvage
				+ ForgeRules.HOPPER_TARGET.pure_component
	)
	for _, k in ForgeRules.FEED_MATERIALS do
		check("whole stock: conserved " .. k, w.stock[k] + feed:left(k, spent[k]) + spent[k] == stock[k])
	end
end

-- Slow top-up: a piece whose cells are not in the hopper waits (no lock, no RNG drawn,
-- no input accepted) and spawns when the top-up lands.
do
	local w = fakeWorkshop({ ore = 100, salvage = 0, pure_component = 0 })
	local feed = ForgeFeed.hopper(w.take({ ore = 4 }), w.amount)
	local sim = ForgeSession.new({ feed = feed, enableAlloy = false }, lcg(5))
	sim:start()
	check("first piece spawned from hopper", sim.activeShape ~= "" and not sim.waitingFeed)
	sim:hardDrop()
	check("next piece waits for feed", sim.waitingFeed and sim.status == "FEED HOPPER REFILLING")
	check("waiting: no active cells", #sim:activeCells() == 0)
	check("waiting: inputs ignored", not sim:moveLeft())
	local nextShape = sim.nextShape
	sim:update(1)
	sim:update(1)
	check("waiting persists without top-up", sim.waitingFeed and sim.piecesLocked == 1)
	local want = feed:wants(sim.materialSpent, sim.pendingMaterials)
	check("wants a top-up", want ~= nil and (want.ore or 0) >= 4)
	feed:credit(w.take(want :: any))
	sim:update(0.01)
	check("spawns after top-up", not sim.waitingFeed and sim.activeShape == nextShape)
	-- another player drains the shared stock: the run ends cleanly, nothing lost
	w.stock.ore = 0
	local guard = 0
	while not sim.finished and guard < 200 do
		guard += 1
		sim:hardDrop()
		sim:update(0.05)
	end
	check("drained stock ends run", sim.finished and sim.result.reason == "INPUT HOPPERS EMPTY")
	local refund = feed:refund(sim.result.materialsConsumed)
	check(
		"drained: spent + refund = hopper total",
		sim.result.materialsConsumed.ore + refund.ore == feed.reserved.ore
	)
end

---------------------------------------------------------------- provisional look pass (decor)
do
	local expect = {
		tetra = { 4, 6 },
		cube = { 8, 12 },
		octa = { 6, 12 },
		dodeca = { 20, 30 },
		icosa = { 12, 30 },
		merkaba = { 8, 12 },
	}
	for solid, ve in expect do
		local verts, edges = DecorGeometry.platonic(solid)
		check("platonic verts " .. solid, #verts == ve[1])
		check("platonic edges " .. solid, #edges == ve[2])
		local len = DecorGeometry.dist(verts[edges[1][1]], verts[edges[1][2]])
		local same = true
		for _, e in edges do
			if math.abs(DecorGeometry.dist(verts[e[1]], verts[e[2]]) - len) > 1e-6 then
				same = false
			end
		end
		check("platonic equal edges " .. solid, same)
		for _, p in verts do
			check(
				"unit circumradius " .. solid,
				math.abs(math.sqrt(p.x * p.x + p.y * p.y + p.z * p.z) - 1) < 1e-9
			)
		end
	end
	local scene = DecorGeometry.build()
	check("decor within part budget", #scene.prims <= DecorGeometry.PART_BUDGET)
	local half = DecorGeometry.LAYOUT.hubHalf
	local roof = DecorGeometry.LAYOUT.roofY
	local refsSeen = {}
	local function points(p)
		if p.kind == "rod" then
			return { p.a, p.b }
		end
		return { p.p }
	end
	for _, p in scene.prims do
		check("decor group declared " .. p.group, scene.groups[p.group] ~= nil)
		local g = scene.groups[p.group]
		if g and g.ref then
			refsSeen[g.ref] = true
		end
		for _, q in points(p) do
			if p.group == "StarDust" then
				check("stars outside the hub", q.y > roof + 20)
			else
				check(
					"decor inside the hub " .. p.group,
					math.abs(q.x) < half.x - 1 and math.abs(q.z) < half.z - 1 and q.y >= 0 and q.y < roof
				)
				-- floor inlays (y < 0.2) may run under gameplay spots; nothing else may crowd them
				if q.y > 0.2 then
					for _, k in DecorGeometry.KEEP_CLEAR do
						local dxz = math.sqrt((q.x - k.x) ^ 2 + (q.z - k.z) ^ 2)
						if dxz < k.r and q.y < k.top then
							check("decor keeps " .. k.name .. " clear (" .. p.group .. ")", false)
						end
					end
				end
			end
		end
	end
	for n = 1, 14 do
		local key = string.format("REF_%02d", n)
		local covered = refsSeen[key] == true
		if not covered then
			-- some refs are represented by pieces that answer several images
			covered = key == "REF_08" or key == "REF_04"
		end
		check("procedural stand-in for " .. key, covered)
	end
	-- image slots: all empty by default -> procedural fallback, URIs only for digit ids
	check("14 reference slots", #ImageAssets.ORDER == 14)
	for _, key in ImageAssets.ORDER do
		local slot = ImageAssets.REFS[key]
		check("slot exists " .. key, slot ~= nil and slot.file ~= "")
		check("slot empty by default " .. key, ImageAssets.ref(key) == nil)
	end
	check("sky needs all six faces", ImageAssets.sky() == nil)
	check("uri accepts digits", ImageAssets.uri({ assetId = "123456" }) == "rbxassetid://123456")
	check("uri rejects junk", ImageAssets.uri({ assetId = "rbxassetid://1" }) == nil)
	local sheet = ImageAssets.SHEETS.REF_12
	check("sheet geometry", sheet.cols * sheet.rows == sheet.frames and sheet.cols * sheet.frameW <= 1024)
	check("missing lists everything when empty", #ImageAssets.missing() == 14 + 2 + 1)
end

---------------------------------------------------------------- data defs
check("starter ore", ItemDefs.STARTER_STOCK.ore == 120)
check("starter salvage", ItemDefs.STARTER_STOCK.salvage == 56)
check("starter pure", ItemDefs.STARTER_STOCK.pure_component == 16)
check(
	"hopper target covers at least one piece of each kind",
	ForgeRules.HOPPER_TARGET.ore >= 4
		and ForgeRules.HOPPER_TARGET.salvage >= 4
		and ForgeRules.HOPPER_TARGET.pure_component >= 2
		and ForgeRules.HOPPER_LOW.ore < ForgeRules.HOPPER_TARGET.ore
)
check(
	"visor upgrade cost",
	RecipeDefs.VISOR_CHIP_UPGRADE.cost.packed_block == 4
		and RecipeDefs.VISOR_CHIP_UPGRADE.cost.forged_blank == 1
)
for k in ForgeRules.CODES do
	check("code item valid " .. k, ItemDefs.isValid(k))
end
local prev = -1
for lvl = 1, ProgressionDefs.MAX_LEVEL do
	local xp = ProgressionDefs.xpForLevel(lvl)
	check("monotonic " .. lvl, xp > prev)
	check("roundtrip " .. lvl, ProgressionDefs.levelForXp(xp) == lvl)
	prev = xp
end

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	error("tests failed")
end
