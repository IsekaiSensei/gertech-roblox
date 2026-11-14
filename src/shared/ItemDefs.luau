--!strict
-- Item definitions. CANON: every key and starter amount below is copied from the Godot
-- source of truth: worldseed/world_seed.gd STARTER_STOCK (GERTECH_Aqua_Workshop, Nov 2026).
-- Display names/descriptions are Roblox UI text written for this port.

export type ItemDef = {
	id: string,
	name: string,
	category: string, -- "raw" | "product" | "byproduct" | "reserved"
	description: string,
	color: Color3,
}

local ItemDefs = {}

local defs: { [string]: ItemDef } = {
	ore = {
		id = "ore",
		name = "Ore",
		category = "raw",
		description = "Base forge feed stock. Godot dock: DIG DOG (ORE + SOIL).",
		color = Color3.fromHex("dfa55e"), -- forge_foundry.gd COLORS.ore
	},
	salvage = {
		id = "salvage",
		name = "Salvage",
		category = "raw",
		description = "Recovered stock. Rows with 4+ salvage also yield a stabilized frame. Godot dock: ASTEROIDS.",
		color = Color3.fromHex("6dc6df"), -- forge_foundry.gd COLORS.salvage
	},
	pure_component = {
		id = "pure_component",
		name = "Pure Component",
		category = "raw",
		description = "Enables alloy batches when the workshop holds 4 or more. Godot dock: BREAKOUT (REFINED PARTS).",
		color = Color3.fromHex("f4e4b2"), -- forge_foundry.gd COLORS.pure_component
	},
	soil = {
		id = "soil",
		name = "Soil",
		category = "raw",
		description = "Dig Dog intake by-product. Nothing consumes it yet (same as Godot).",
		color = Color3.fromRGB(110, 84, 60),
	},
	food = {
		id = "food",
		name = "Food",
		category = "reserved",
		description = "Reserved key (Mouse Maze dock). Unused in Godot too.",
		color = Color3.fromRGB(150, 200, 90),
	},
	labor_token = {
		id = "labor_token",
		name = "Labor Token",
		category = "reserved",
		description = "Reserved key. Unused in Godot too.",
		color = Color3.fromRGB(200, 200, 200),
	},
	packed_block = {
		id = "packed_block",
		name = "Packed Block",
		category = "product",
		description = "One per crystallized forge row. Places into lattice sockets; feeds the stock exchange.",
		color = Color3.fromRGB(120, 180, 255),
	},
	stabilized_frame = {
		id = "stabilized_frame",
		name = "Stabilized Frame",
		category = "product",
		description = "Extra output from a salvage-rich row (4+ salvage cells).",
		color = Color3.fromRGB(90, 220, 200),
	},
	forged_blank = {
		id = "forged_blank",
		name = "Forged Blank",
		category = "product",
		description = "Extra output from an alloy row (2+ pure component cells).",
		color = Color3.fromRGB(255, 210, 120),
	},
	alloy = {
		id = "alloy",
		name = "Alloy",
		category = "reserved",
		description = "Reserved key. Nothing produces it yet (same as Godot).",
		color = Color3.fromRGB(200, 170, 255),
	},
	scrap = {
		id = "scrap",
		name = "Scrap",
		category = "byproduct",
		description = "Uncrystallized chamber material: leftover cells / 5 (Godot rule).",
		color = Color3.fromRGB(120, 120, 120),
	},
	defense_tech = {
		id = "defense_tech",
		name = "Defense Tech",
		category = "reserved",
		description = "Reserved key (Space Invaders dock). Unused in Godot too.",
		color = Color3.fromRGB(255, 90, 90),
	},
}

-- Display order for UI
ItemDefs.ORDER = {
	"ore",
	"salvage",
	"pure_component",
	"soil",
	"packed_block",
	"stabilized_frame",
	"forged_blank",
	"scrap",
	"alloy",
	"food",
	"labor_token",
	"defense_tech",
}

-- CANON: world_seed.gd STARTER_STOCK
ItemDefs.STARTER_STOCK = {
	ore = 120,
	salvage = 56,
	pure_component = 16,
	soil = 0,
	food = 0,
	labor_token = 0,
	packed_block = 0,
	stabilized_frame = 0,
	forged_blank = 0,
	alloy = 0,
	scrap = 0,
	defense_tech = 0,
}

-- CANON: world_seed.gd default equipment
ItemDefs.STARTER_EQUIPMENT = {
	visor_chip_capacity = 1,
}

ItemDefs.Defs = defs

function ItemDefs.get(id: string): ItemDef?
	return defs[id]
end

function ItemDefs.isValid(id: any): boolean
	return type(id) == "string" and defs[id] ~= nil
end

return ItemDefs
