--!strict
-- Multi-place universe registry. Fill in PlaceIds after creating each place in the
-- same Roblox experience (Creator Dashboard -> Places). 0 = not built yet.
-- Travel between places is through the DNA wormhole helix (never call it "the zipper").

local PlaceRegistry = {}

PlaceRegistry.Places = {
	hub = { name = "GERTECH Workshop Hub", placeId = 0 },
	mining = { name = "Mining (Dig Dog / Aster-Ores)", placeId = 0 },
	forge = { name = "Forge Floor", placeId = 0 },
	assembly = { name = "Assembly Bay", placeId = 0 },
	hangar = { name = "Hangar", placeId = 0 },
	expeditions = { name = "Expeditions", placeId = 0 },
}

PlaceRegistry.HELIX_DESTINATIONS = { "mining", "forge", "assembly", "hangar", "expeditions" }

return PlaceRegistry
