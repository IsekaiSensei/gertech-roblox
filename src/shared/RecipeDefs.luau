--!strict
-- TETRAFORGE recipes (the Tetris / Forge Foundry from the Godot build).
--
-- CANON (Godot theme_foundry/forge_foundry.gd + core/tetris/tetromino_grid.gd):
--   * The chamber is 10 cells wide. Every locked tetromino uses 4 material units.
--   * Feed stock: ore, salvage, pure_component. Alloy pieces mix pure_component into base
--     material and are only enabled when the workshop holds >= 4 pure_component.
--   * Each cleared row -> 1 packed_block.
--     Row with >= 4 salvage cells -> +1 stabilized_frame.
--     Row with >= 2 pure_component cells -> +1 forged_blank.
--   * Uncrystallized cells left in the chamber at run end -> floor(cells / 5) scrap.
--   * Output quota per run: 8 rows. Score: rows^2 * 100 per clear, +400 bonus for 4 rows.
--
-- ADAPTATION (Roblox v0.1): the live Tetris run is not ported yet. Each recipe below is
-- one "row composition" that satisfies the Godot row rules exactly; the player picks a
-- composition and a row count (1..8) and the server runs a craft timer.
--
-- PLACEHOLDER: unlockLevel, secondsPerRow and XP. Godot has no levels or XP. Swap freely.

export type Recipe = {
	id: string,
	name: string,
	description: string,
	inputsPerRow: { [string]: number },
	outputsPerRow: { [string]: number },
	requiresAlloyEnabled: boolean,
	unlockLevel: number, -- PLACEHOLDER
}

local Config = require(script.Parent.Config)

local RecipeDefs = {}

RecipeDefs.STATION_NAME = "TETRAFORGE"
RecipeDefs.ALLOY_ENABLE_THRESHOLD = 4 -- CANON: enable_alloy = pure_component >= 4
RecipeDefs.SCRAP_DIVISOR = 5 -- CANON: scrap = remaining_cells / 5

local recipes: { [string]: Recipe } = {
	ore_row = {
		id = "ore_row",
		name = "Ore Row",
		description = "10 ore cells crystallize into a packed block.",
		inputsPerRow = { ore = 10 },
		outputsPerRow = { packed_block = 1 },
		requiresAlloyEnabled = false,
		unlockLevel = 1,
	},
	salvage_row = {
		id = "salvage_row",
		name = "Salvage Row",
		description = "A salvage-rich row (4+ salvage) also yields a stabilized frame.",
		inputsPerRow = { ore = 6, salvage = 4 },
		outputsPerRow = { packed_block = 1, stabilized_frame = 1 },
		requiresAlloyEnabled = false,
		unlockLevel = 1,
	},
	alloy_row = {
		id = "alloy_row",
		name = "Alloy Row",
		description = "An alloy row (2+ pure component) also yields a forged blank.",
		inputsPerRow = { ore = 8, pure_component = 2 },
		outputsPerRow = { packed_block = 1, forged_blank = 1 },
		requiresAlloyEnabled = true,
		unlockLevel = 2,
	},
	salvage_alloy_row = {
		id = "salvage_alloy_row",
		name = "Salvage Alloy Row",
		description = "4+ salvage and 2+ pure component in one row: block, frame and blank.",
		inputsPerRow = { salvage = 8, pure_component = 2 },
		outputsPerRow = { packed_block = 1, stabilized_frame = 1, forged_blank = 1 },
		requiresAlloyEnabled = true,
		unlockLevel = 3,
	},
}

RecipeDefs.ORDER = { "ore_row", "salvage_row", "alloy_row", "salvage_alloy_row" }
RecipeDefs.Recipes = recipes

-- CANON: workshop/inventory.gd make_mouse_visor_chip_upgrade()
RecipeDefs.VISOR_CHIP_UPGRADE = {
	id = "visor_chip_upgrade",
	name = "Mouse Visor Chip Capacity +1",
	cost = { packed_block = 4, forged_blank = 1 } :: { [string]: number },
	equipmentKey = "visor_chip_capacity",
}

function RecipeDefs.get(id: any): Recipe?
	if type(id) ~= "string" then
		return nil
	end
	return recipes[id]
end

function RecipeDefs.scaled(map: { [string]: number }, rows: number): { [string]: number }
	local out = {}
	for k, v in map do
		out[k] = v * rows
	end
	return out
end

-- Every recipe must match the Godot row rules. Used by tests and a startup assert.
function RecipeDefs.validateRowRules(recipe: Recipe): (boolean, string?)
	local cells = 0
	for _, n in recipe.inputsPerRow do
		cells += n
	end
	if cells ~= Config.FORGE_ROW_WIDTH then
		return false, recipe.id .. ": row must be exactly " .. Config.FORGE_ROW_WIDTH .. " cells"
	end
	local salvage = recipe.inputsPerRow.salvage or 0
	local pure = recipe.inputsPerRow.pure_component or 0
	local expected: { [string]: number } = { packed_block = 1 }
	if salvage >= 4 then
		expected.stabilized_frame = 1
	end
	if pure >= 2 then
		expected.forged_blank = 1
	end
	for k, v in expected do
		if recipe.outputsPerRow[k] ~= v then
			return false, recipe.id .. ": output " .. k .. " does not follow Godot row rule"
		end
	end
	for k in recipe.outputsPerRow do
		if expected[k] == nil then
			return false, recipe.id .. ": unexpected output " .. k
		end
	end
	if (pure > 0) ~= recipe.requiresAlloyEnabled then
		return false, recipe.id .. ": alloy flag mismatch"
	end
	return true, nil
end

-- CANON scoring, assuming rows clear in groups of up to 4 (the best case in Godot).
function RecipeDefs.scoreForRows(rows: number): number
	local score = 0
	local remaining = rows
	while remaining > 0 do
		local group = math.min(4, remaining)
		score += group * group * 100
		if group == 4 then
			score += 400
		end
		remaining -= group
	end
	return score
end

-- CANON: uncrystallized cells / 5 -> scrap. Used when a run is aborted mid-way.
function RecipeDefs.scrapForCells(cells: number): number
	return math.floor(cells / RecipeDefs.SCRAP_DIVISOR)
end

return RecipeDefs
