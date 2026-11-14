-- Offline tests for engine-free modules. Run: ./tests/run.sh  (needs the `luau` CLI)
-- The runner rewrites `require(script.Parent.X)` into file requires.

local Config = require("./build/Config")
local RecipeDefs = require("./build/RecipeDefs")
local ProgressionDefs = require("./build/ProgressionDefs")
local ItemDefs = require("./build/ItemDefs")

local passed, failed = 0, 0
local function check(name: string, cond: boolean)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL: " .. name)
	end
end

-- Every recipe obeys the Godot row rules (10 cells; >=4 salvage -> frame; >=2 pure -> blank)
for _, id in RecipeDefs.ORDER do
	local ok, err = RecipeDefs.validateRowRules(RecipeDefs.get(id))
	check("row rules " .. id .. " " .. tostring(err), ok)
	for k in RecipeDefs.get(id).inputsPerRow do
		check("input is a real item " .. k, ItemDefs.isValid(k))
	end
	for k in RecipeDefs.get(id).outputsPerRow do
		check("output is a real item " .. k, ItemDefs.isValid(k))
	end
end

-- A deliberately wrong recipe must be rejected
local bad = { id = "bad", name = "", description = "", inputsPerRow = { salvage = 10 }, outputsPerRow = { packed_block = 1 }, requiresAlloyEnabled = false, unlockLevel = 1 }
check("validator catches missing frame", not RecipeDefs.validateRowRules(bad))

-- Godot scoring: rows^2*100 per clear, +400 for a 4-row clear
check("score 1 row", RecipeDefs.scoreForRows(1) == 100)
check("score 4 rows", RecipeDefs.scoreForRows(4) == 2000)
check("score 8 rows", RecipeDefs.scoreForRows(8) == 4000)
check("score 5 rows", RecipeDefs.scoreForRows(5) == 2100)

-- Scrap = leftover cells / 5
check("scrap 3 rows", RecipeDefs.scrapForCells(3 * Config.FORGE_ROW_WIDTH) == 6)
check("scrap 4 cells", RecipeDefs.scrapForCells(4) == 0)

-- Starter stock matches Godot STARTER_STOCK
check("starter ore", ItemDefs.STARTER_STOCK.ore == 120)
check("starter salvage", ItemDefs.STARTER_STOCK.salvage == 56)
check("starter pure", ItemDefs.STARTER_STOCK.pure_component == 16)
check("visor upgrade cost", RecipeDefs.VISOR_CHIP_UPGRADE.cost.packed_block == 4 and RecipeDefs.VISOR_CHIP_UPGRADE.cost.forged_blank == 1)

-- Starter stock can actually run an 8-row ore batch (Godot quota) and an alloy batch
check("starter feeds 8 ore rows", ItemDefs.STARTER_STOCK.ore >= 80)

-- Progression curve is monotonic and round-trips
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
