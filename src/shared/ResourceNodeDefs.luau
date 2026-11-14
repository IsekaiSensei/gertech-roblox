--!strict
-- Starter resource nodes. CANON: which material each source gives comes from the Godot
-- intake docks (scripts/workshop.gd): DIG DOG = ORE + SOIL, ASTEROIDS = SALVAGE + ROCK,
-- BREAKOUT = REFINED PARTS (mapped to pure_component here; see docs/DESIGN_MAPPING.md).
-- PLACEHOLDER: yields, charges, regen and hold times. In Godot these docks are scenery;
-- their minigames are not implemented, so these hold-to-gather nodes stand in for them.

export type NodeDef = {
	id: string,
	name: string,
	dock: string,
	yield: { [string]: number },
	charges: number,
	regenSeconds: number,
	holdSeconds: number,
	color: Color3,
	count: number,
}

local defs: { [string]: NodeDef } = {
	dig_dog_seam = {
		id = "dig_dog_seam",
		name = "Dig Dog Ore Seam",
		dock = "DIG DOG",
		yield = { ore = 4, soil = 1 },
		charges = 5,
		regenSeconds = 20,
		holdSeconds = 1,
		color = Color3.fromHex("dfa55e"),
		count = 4,
	},
	asteroid_salvage = {
		id = "asteroid_salvage",
		name = "Asteroid Salvage Rock",
		dock = "ASTEROIDS",
		yield = { salvage = 3 },
		charges = 4,
		regenSeconds = 25,
		holdSeconds = 1.25,
		color = Color3.fromHex("6dc6df"),
		count = 3,
	},
	breakout_parts = {
		id = "breakout_parts",
		name = "Breakout Refined Parts Bin",
		dock = "BREAKOUT",
		yield = { pure_component = 1 },
		charges = 3,
		regenSeconds = 40,
		holdSeconds = 1.5,
		color = Color3.fromHex("f4e4b2"),
		count = 2,
	},
}

return {
	Defs = defs,
	ORDER = { "dig_dog_seam", "asteroid_salvage", "breakout_parts" },
}
