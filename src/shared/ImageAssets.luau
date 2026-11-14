--!strict
-- Image asset slots for the PROVISIONAL look pass (Ryan's shared references, 2026-11-14).
-- Not canon. Roblox can only show images that were uploaded to Roblox, so every slot
-- starts EMPTY and the game falls back to procedural geometry (DecorGeometry) until an
-- asset id is pasted here. Upload steps: README.md > "Reference images and asset ids".
--
-- assetId: the numeric id from the Asset Manager / Creator Dashboard (digits only).
-- Upload the IMAGE asset; if Roblox hands back a Decal id, use the Image id it wraps.

local ImageAssets = {}

export type Slot = { file: string, title: string, usedFor: string, assetId: string }
export type Sheet = Slot & {
	cols: number,
	rows: number,
	frames: number,
	frameW: number,
	frameH: number,
	fps: number,
}

-- The 14 reference images (downscaled copies in assets/refs; originals are the PNGs Ryan
-- shared, on the box at /workspace/gertech_shared_refs/visual_2026-11-14/).
ImageAssets.REFS = {
	REF_01 = {
		file = "assets/refs/GERTECH_REF_01_fractal_vortex_spheres.jpg",
		title = "Fractal vortex spheres",
		usedFor = "Gallery poster (south wall). Procedural: FractalCascade sphere clusters (west wall).",
		assetId = "",
	},
	REF_02 = {
		file = "assets/refs/GERTECH_REF_02_platonic_frames_crystal_sphere_vortex.jpg",
		title = "Platonic frames in a crystal sphere, vortex",
		usedFor = "Gallery poster. Procedural: MerkabaSphere (star tetrahedron in crystal sphere).",
		assetId = "",
	},
	REF_03 = {
		file = "assets/refs/GERTECH_REF_03_gold_cube_torus_sphere.jpg",
		title = "Gold cube, torus, sphere",
		usedFor = "Gallery poster. Procedural: GoldCubeSphere, WormholeTorus.",
		assetId = "",
	},
	REF_04 = {
		file = "assets/refs/GERTECH_REF_04_polyhedra_column_helix_vortex.jpg",
		title = "Polyhedra column, helix, vortex",
		usedFor = "Gallery poster. Procedural: HelixProgression column inside the DNA wormhole helix.",
		assetId = "",
	},
	REF_05 = {
		file = "assets/refs/GERTECH_REF_05_gold_rings_icosahedron_stack.jpg",
		title = "Gold rings, icosahedron stack",
		usedFor = "Gallery poster. Procedural: GoldRingStack.",
		assetId = "",
	},
	REF_06 = {
		file = "assets/refs/GERTECH_REF_06_voronoi_gold_silver_vortex.jpg",
		title = "Voronoi gold/silver vortex",
		usedFor = "Gallery poster. Procedural: FoamLattice floor inlay around the helix.",
		assetId = "",
	},
	REF_07 = {
		file = "assets/refs/GERTECH_REF_07_torus_vortex_sphere_tree.jpg",
		title = "Torus vortex, sphere tree",
		usedFor = "Gallery poster. Procedural: SphereTree under a torus vortex.",
		assetId = "",
	},
	REF_08 = {
		file = "assets/refs/GERTECH_REF_08_foam_lattice_golden_spiral.jpg",
		title = "Foam lattice, golden spiral",
		usedFor = "Gallery poster. Procedural: FoamLattice spiral arms, GoldenSpiralChain.",
		assetId = "",
	},
	REF_09 = {
		file = "assets/refs/GERTECH_REF_09_gold_polyhedra_spiral_chain.jpg",
		title = "Gold polyhedra spiral chain",
		usedFor = "Gallery poster. Procedural: GoldenSpiralChain over the lattice.",
		assetId = "",
	},
	REF_10 = {
		file = "assets/refs/GERTECH_REF_10_modular_crystal_block_sheet.jpg",
		title = "Modular Crystal Block sheet",
		usedFor = "Gallery poster. Procedural: ModularCrystalBlock, ChamberFrame styling.",
		assetId = "",
	},
	REF_11 = {
		file = "assets/refs/GERTECH_REF_11_elemental_platonic_crystals.jpg",
		title = "Five elemental Platonic crystals",
		usedFor = "Gallery poster. Procedural: five ElementalCrystal pedestals.",
		assetId = "",
	},
	REF_12 = {
		file = "assets/refs/GERTECH_REF_12_crystal_to_android_growth_30.jpg",
		title = "Crystal seed to winged android growth (30 frames)",
		usedFor = "Gallery poster. Flipbook: see SHEETS.REF_12. Procedural: CrystalSeed on the quantum table.",
		assetId = "",
	},
	REF_13 = {
		file = "assets/refs/GERTECH_REF_13_helix_platonic_progression_30.jpg",
		title = "Helix to Platonic frames progression (30 frames)",
		usedFor = "Gallery poster. Flipbook: see SHEETS.REF_13. Procedural: HoloHelixFrame on the quantum table.",
		assetId = "",
	},
	REF_14 = {
		file = "assets/refs/GERTECH_REF_14_nebula_triangle_module.jpg",
		title = "Nebula triangle module, gold corners",
		usedFor = "Gallery poster + Texture on the triangle module face. Procedural: NebulaTriangleModule.",
		assetId = "",
	},
} :: { [string]: Slot }

ImageAssets.ORDER = {
	"REF_01",
	"REF_02",
	"REF_03",
	"REF_04",
	"REF_05",
	"REF_06",
	"REF_07",
	"REF_08",
	"REF_09",
	"REF_10",
	"REF_11",
	"REF_12",
	"REF_13",
	"REF_14",
}

-- Flipbook sprite sheets generated from REF_12 / REF_13 (tools/make_assets.py): 6 x 5 frames
-- of 168 x 168 px in a 1008 x 840 image, played with ImageRectOffset / ImageRectSize.
ImageAssets.SHEETS = {
	REF_12 = {
		file = "assets/sheets/REF_12_growth_sheet_6x5.jpg",
		title = "Crystal seed to winged android growth",
		usedFor = "Quantum table holo screen (flipbook). Fallback: procedural CrystalSeed.",
		assetId = "",
		cols = 6,
		rows = 5,
		frames = 30,
		frameW = 168,
		frameH = 168,
		fps = 6,
	},
	REF_13 = {
		file = "assets/sheets/REF_13_helix_sheet_6x5.jpg",
		title = "Helix to Platonic frames progression",
		usedFor = "Quantum table top (flipbook on the holo grid). Fallback: procedural HoloHelixFrame.",
		assetId = "",
		cols = 6,
		rows = 5,
		frames = 30,
		frameW = 168,
		frameH = 168,
		fps = 6,
	},
} :: { [string]: Sheet }

-- Space skybox faces (generated star dust, assets/sky). All six are needed; otherwise the
-- Sky keeps no textures and the procedural StarDust + night star count are used.
ImageAssets.SKY = {
	SkyboxBk = {
		file = "assets/sky/space_bk.png",
		title = "Sky back",
		usedFor = "Sky.SkyboxBk",
		assetId = "",
	},
	SkyboxDn = {
		file = "assets/sky/space_dn.png",
		title = "Sky down",
		usedFor = "Sky.SkyboxDn",
		assetId = "",
	},
	SkyboxFt = {
		file = "assets/sky/space_ft.png",
		title = "Sky front",
		usedFor = "Sky.SkyboxFt",
		assetId = "",
	},
	SkyboxLf = {
		file = "assets/sky/space_lf.png",
		title = "Sky left",
		usedFor = "Sky.SkyboxLf",
		assetId = "",
	},
	SkyboxRt = {
		file = "assets/sky/space_rt.png",
		title = "Sky right",
		usedFor = "Sky.SkyboxRt",
		assetId = "",
	},
	SkyboxUp = { file = "assets/sky/space_up.png", title = "Sky up", usedFor = "Sky.SkyboxUp", assetId = "" },
} :: { [string]: Slot }

-- "rbxassetid://<id>" for a filled slot, nil for an empty or malformed one.
function ImageAssets.uri(slot: { assetId: string }?): string?
	if slot and type(slot.assetId) == "string" and string.match(slot.assetId, "^%d+$") then
		return "rbxassetid://" .. slot.assetId
	end
	return nil
end

function ImageAssets.ref(key: string): string?
	return ImageAssets.uri(ImageAssets.REFS[key])
end

-- Sky faces only when all six are filled.
function ImageAssets.sky(): { [string]: string }?
	local out = {}
	for face, slot in ImageAssets.SKY do
		local u = ImageAssets.uri(slot)
		if not u then
			return nil
		end
		out[face] = u
	end
	return out
end

-- Every slot that still needs an upload (for docs / startup log).
function ImageAssets.missing(): { string }
	local out = {}
	for _, key in ImageAssets.ORDER do
		if not ImageAssets.ref(key) then
			table.insert(out, key)
		end
	end
	for key, slot in ImageAssets.SHEETS do
		if not ImageAssets.uri(slot) then
			table.insert(out, key .. "_sheet")
		end
	end
	if not ImageAssets.sky() then
		table.insert(out, "SKY (6 faces)")
	end
	table.sort(out)
	return out
end

return ImageAssets
