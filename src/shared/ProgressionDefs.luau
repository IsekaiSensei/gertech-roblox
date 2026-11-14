--!strict
-- PLACEHOLDER progression. The Godot build has no XP or levels; its only progression is
-- workshop equipment (visor chip capacity) and WorldSeed lattice placement.
-- This curve exists so recipe unlocks have something to hang on. Swap freely.

local ProgressionDefs = {}

ProgressionDefs.MAX_LEVEL = 30
ProgressionDefs.XP_PER_SCORE = 0.1 -- forge XP = canon score * this
ProgressionDefs.XP_PER_GATHER = 2
ProgressionDefs.XP_PER_SOCKET = 5

function ProgressionDefs.xpForLevel(level: number): number
	-- total XP needed to reach `level`
	if level <= 1 then
		return 0
	end
	return math.floor(100 * (level - 1) ^ 1.5)
end

function ProgressionDefs.levelForXp(xp: number): number
	local level = 1
	while level < ProgressionDefs.MAX_LEVEL and xp >= ProgressionDefs.xpForLevel(level + 1) do
		level += 1
	end
	return level
end

return ProgressionDefs
