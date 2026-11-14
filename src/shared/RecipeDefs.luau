--!strict
-- Non-forge recipes. TETRAFORGE is now the real falling-block game (see ForgeRules /
-- ForgeSession / TetrominoGrid), so it has no recipe list.

local RecipeDefs = {}

-- CANON: workshop/inventory.gd make_mouse_visor_chip_upgrade()
RecipeDefs.VISOR_CHIP_UPGRADE = {
	id = "visor_chip_upgrade",
	name = "Mouse Visor Chip Capacity +1",
	cost = { packed_block = 4, forged_blank = 1 } :: { [string]: number },
	equipmentKey = "visor_chip_capacity",
}

return RecipeDefs
