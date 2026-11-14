--!strict
-- TETRAFORGE rules: faithful constants and formulas from Godot
-- theme_foundry/forge_foundry.gd + workshop/inventory.gd get_foundry_config().
-- Engine-free (no Roblox APIs).

local ForgeRules = {}

ForgeRules.STATION_NAME = "TETRAFORGE"

-- CANON
ForgeRules.PIECE_NAMES = { "I", "O", "T", "L", "J", "S", "Z" }
ForgeRules.FEED_MATERIALS = { "ore", "salvage", "pure_component" }
ForgeRules.BASE_MATERIALS = { "ore", "salvage" } -- pieces are drawn from these
ForgeRules.CELLS_PER_PIECE = 4
ForgeRules.ALLOY_ENABLE_THRESHOLD = 4 -- enable_alloy = pure_component >= 4
ForgeRules.ALLOY_CHANCE = 0.32
ForgeRules.TARGET_LINES = 8
ForgeRules.GRAVITY_SECONDS = 0.62
ForgeRules.MIN_GRAVITY_INTERVAL = 0.09
ForgeRules.HEAT_GRAVITY_FACTOR = 0.34
ForgeRules.SOFT_DROP_FACTOR = 0.11
ForgeRules.HEAT_START = 0.19
ForgeRules.HEAT_PER_LOCK = 0.018
ForgeRules.HEAT_PER_ROW = 0.07
ForgeRules.SPAWN_X = 4
ForgeRules.SPAWN_Y = 1
ForgeRules.ROTATION_KICKS = { 0, -1, 1, -2, 2 }
ForgeRules.SCRAP_DIVISOR = 5
ForgeRules.STABILIZED_FRAME_SALVAGE = 4 -- row with >= 4 salvage cells
ForgeRules.FORGED_BLANK_PURE = 2 -- row with >= 2 pure_component cells

-- ADAPTED: Godot hands the whole workshop stock to the single-player foundry. In a shared
-- multiplayer workshop the session reserves at most this much, so one run cannot freeze
-- everyone else's stock. Caps equal the Godot starter stock (a full Godot run budget).
ForgeRules.RESERVATION_CAP = { ore = 120, salvage = 56, pure_component = 16 }

-- Replication codes (board string)
ForgeRules.CODES = { ore = "o", salvage = "s", pure_component = "p" }
ForgeRules.DECODE = { o = "ore", s = "salvage", p = "pure_component" }

-- CANON: score += rows^2 * 100 per lock, +400 for a four-row clear
function ForgeRules.scoreForClear(rows: number): number
	if rows <= 0 then
		return 0
	end
	return rows * rows * 100 + (if rows == 4 then 400 else 0)
end

-- CANON: per cleared row tally -> outputs
function ForgeRules.rowOutputs(tally: { [string]: number }): { [string]: number }
	local out = { packed_block = 1 }
	if (tally.salvage or 0) >= ForgeRules.STABILIZED_FRAME_SALVAGE then
		out.stabilized_frame = 1
	end
	if (tally.pure_component or 0) >= ForgeRules.FORGED_BLANK_PURE then
		out.forged_blank = 1
	end
	return out
end

-- CANON: uncrystallized locked cells / 5 -> scrap (integer division)
function ForgeRules.scrapFor(cells: number): number
	return math.floor(cells / ForgeRules.SCRAP_DIVISOR)
end

-- CANON: interval = max(0.09, gravity * (1 - min(heat,1) * 0.34)); soft drop * 0.11
function ForgeRules.gravityInterval(gravitySeconds: number, heat: number, softDrop: boolean): number
	local interval = math.max(
		ForgeRules.MIN_GRAVITY_INTERVAL,
		gravitySeconds * (1 - math.min(heat, 1) * ForgeRules.HEAT_GRAVITY_FACTOR)
	)
	if softDrop then
		interval *= ForgeRules.SOFT_DROP_FACTOR
	end
	return interval
end

export type Rng = {
	NextInteger: (self: any, min: number, max: number) -> number,
	NextNumber: (self: any) -> number,
}

-- CANON: _choose_materials(). Returns {} when the hoppers cannot supply a piece.
function ForgeRules.chooseMaterials(
	budget: { [string]: number },
	spent: { [string]: number },
	alloyEnabled: boolean,
	rng: Rng
): { string }
	local choices = {}
	for _, kind in ForgeRules.BASE_MATERIALS do
		if (budget[kind] or 0) - (spent[kind] or 0) >= 4 then
			table.insert(choices, kind)
		end
	end
	if #choices == 0 then
		return {}
	end
	local material = choices[rng:NextInteger(1, #choices)]
	local result = { material, material, material, material }
	local pureLeft = (budget.pure_component or 0) - (spent.pure_component or 0)
	local baseLeft = (budget[material] or 0) - (spent[material] or 0)
	if alloyEnabled and pureLeft >= 2 and baseLeft >= 2 and rng:NextNumber() < ForgeRules.ALLOY_CHANCE then
		result = { material, "pure_component", material, "pure_component" }
	end
	return result
end

return ForgeRules
