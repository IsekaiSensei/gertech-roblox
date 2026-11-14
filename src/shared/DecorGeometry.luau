--!strict
-- PROVISIONAL LOOK PASS (2026-11-14). Not canon: Godot stays the source of truth for logic,
-- this only dresses the hub toward Ryan's shared reference images GERTECH_REF_01..14
-- (assets/refs). Engine-free: it returns plain primitive specs (balls, rods, blocks,
-- discs, wedges) that the server turns into Parts (VisualStyle), so the geometry can be
-- tested and previewed offline. Nothing here is collidable or interactive.

local DecorGeometry = {}

export type Vec = { x: number, y: number, z: number }

export type Prim = {
	kind: string, -- "ball" | "rod" | "block" | "disc" | "wedge"
	group: string,
	name: string,
	style: string, -- palette key resolved by the server (VisualStyle.STYLES)
	p: Vec?, -- center (ball / block / disc / wedge)
	a: Vec?, -- rod start
	b: Vec?, -- rod end
	d: number?, -- ball / disc diameter
	h: number?, -- disc thickness
	w: number?, -- rod thickness
	size: Vec?, -- block / wedge size
	rot: Vec?, -- block / wedge / disc rotation in degrees (applied X, then Y, then Z)
	fx: string?, -- optional effect key: "light" | "embers" | "frost" | "sparks" | "swirl" | "stars" | "nebula"
	ref: string?, -- which reference image this piece answers (REF_01..REF_14)
}

export type Group = { pivot: Vec, spin: number?, highlight: string?, ref: string? }

export type Decor = { prims: { Prim }, groups: { [string]: Group } }

local function v(x: number, y: number, z: number): Vec
	return { x = x, y = y, z = z }
end
DecorGeometry.v = v

local function add(a: Vec, b: Vec): Vec
	return v(a.x + b.x, a.y + b.y, a.z + b.z)
end

local function scale(a: Vec, s: number): Vec
	return v(a.x * s, a.y * s, a.z * s)
end

local function dist(a: Vec, b: Vec): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
end
DecorGeometry.dist = dist

local function rotY(a: Vec, deg: number): Vec
	local r = math.rad(deg)
	local c, s = math.cos(r), math.sin(r)
	return v(a.x * c + a.z * s, a.y, -a.x * s + a.z * c)
end

local function rotX(a: Vec, deg: number): Vec
	local r = math.rad(deg)
	local c, s = math.cos(r), math.sin(r)
	return v(a.x, a.y * c - a.z * s, a.y * s + a.z * c)
end

-- Deterministic RNG (no engine Random) so the preview and the server build the same scene.
local function lcg(seed: number)
	local state = seed
	return function(): number
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

local PHI = (1 + math.sqrt(5)) / 2
DecorGeometry.PHI = PHI

---------------------------------------------------------------- hub layout anchors
-- Positions copied from HubBuilder (keep in sync if the hub layout moves).
DecorGeometry.LAYOUT = {
	helix = v(0, 0, -50), -- DNA wormhole helix base center (strands y 2..22, radius 5)
	chamber = v(62, 11, 0), -- TETRAFORGE chamber center (10.5 x 20.5 x 2, faces +/-X)
	quantumTable = v(-55, 3.5, 5),
	lattice = v(0, 0, 5),
	roofY = 25,
	hubHalf = v(85, 0, 65),
}

-- Gameplay spots decor must never crowd (vertical cylinders: x, z, radius, up to height).
DecorGeometry.KEEP_CLEAR = {
	{ name = "spawn", x = 0, z = 45, r = 7, top = 12 },
	{ name = "forge console", x = 46, z = 0, r = 5, top = 10 },
	{ name = "stock exchange", x = 50, z = 28, r = 5, top = 10 },
	{ name = "lattice sockets", x = 0, z = 5, r = 9, top = 12 },
	{ name = "helix pads", x = 0, z = -36, r = 6, top = 6 },
	{ name = "quantum table", x = -55, z = 5, r = 8, top = 3 },
	{ name = "resource docks", x = -45, z = 42, r = 22, top = 10 },
}

---------------------------------------------------------------- platonic solids
-- Unit circumradius vertices; edges = vertex pairs at the minimum distance.
local function normalize(list: { Vec }): { Vec }
	local out = {}
	for _, p in list do
		local m = math.sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
		table.insert(out, scale(p, 1 / m))
	end
	return out
end

local function vertsOf(solid: string): { Vec }
	if solid == "tetra" then
		return normalize({ v(1, 1, 1), v(1, -1, -1), v(-1, 1, -1), v(-1, -1, 1) })
	elseif solid == "cube" then
		local out = {}
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					table.insert(out, v(x, y, z))
				end
			end
		end
		return normalize(out)
	elseif solid == "octa" then
		return { v(1, 0, 0), v(-1, 0, 0), v(0, 1, 0), v(0, -1, 0), v(0, 0, 1), v(0, 0, -1) }
	elseif solid == "icosa" then
		local out = {}
		for _, a in { -1, 1 } do
			for _, b in { -PHI, PHI } do
				table.insert(out, v(0, a, b))
				table.insert(out, v(a, b, 0))
				table.insert(out, v(b, 0, a))
			end
		end
		return normalize(out)
	elseif solid == "dodeca" then
		local out = {}
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					table.insert(out, v(x, y, z))
				end
			end
		end
		local ip = 1 / PHI
		for _, a in { -ip, ip } do
			for _, b in { -PHI, PHI } do
				table.insert(out, v(0, a, b))
				table.insert(out, v(a, b, 0))
				table.insert(out, v(b, 0, a))
			end
		end
		return normalize(out)
	elseif solid == "merkaba" then -- star tetrahedron (REF_02): two interlocked tetrahedra
		return normalize({
			v(1, 1, 1),
			v(1, -1, -1),
			v(-1, 1, -1),
			v(-1, -1, 1),
			v(-1, -1, -1),
			v(-1, 1, 1),
			v(1, -1, 1),
			v(1, 1, -1),
		})
	end
	error("unknown solid " .. solid)
end

-- Returns vertices and edge index pairs.
function DecorGeometry.platonic(solid: string): ({ Vec }, { { number } })
	local verts = vertsOf(solid)
	local edges = {}
	if solid == "merkaba" then
		for _, base in { 0, 4 } do
			for i = 1, 4 do
				for j = i + 1, 4 do
					table.insert(edges, { base + i, base + j })
				end
			end
		end
		return verts, edges
	end
	local minD = math.huge
	for i = 1, #verts do
		for j = i + 1, #verts do
			minD = math.min(minD, dist(verts[i], verts[j]))
		end
	end
	for i = 1, #verts do
		for j = i + 1, #verts do
			if dist(verts[i], verts[j]) < minD * 1.01 then
				table.insert(edges, { i, j })
			end
		end
	end
	return verts, edges
end

---------------------------------------------------------------- builders
local Builder = {}
Builder.__index = Builder

local function newBuilder()
	return setmetatable({ prims = {} :: { Prim }, groups = {} :: { [string]: Group } }, Builder)
end

type B = typeof(newBuilder())

local function push(self: B, prim: Prim)
	table.insert(self.prims, prim)
end

local function group(self: B, name: string, pivot: Vec, ref: string?, spin: number?, highlight: string?)
	self.groups[name] = { pivot = pivot, spin = spin, highlight = highlight, ref = ref }
end

local function ball(self: B, g: string, name: string, p: Vec, d: number, style: string, fx: string?)
	push(self, { kind = "ball", group = g, name = name, p = p, d = d, style = style, fx = fx })
end

local function rod(self: B, g: string, name: string, a: Vec, b: Vec, w: number, style: string)
	push(self, { kind = "rod", group = g, name = name, a = a, b = b, w = w, style = style })
end

local function block(
	self: B,
	g: string,
	name: string,
	p: Vec,
	size: Vec,
	style: string,
	rot: Vec?,
	fx: string?
)
	push(
		self,
		{ kind = "block", group = g, name = name, p = p, size = size, style = style, rot = rot, fx = fx }
	)
end

local function disc(self: B, g: string, name: string, p: Vec, d: number, h: number, style: string, rot: Vec?)
	push(self, { kind = "disc", group = g, name = name, p = p, d = d, h = h, style = style, rot = rot })
end

-- Gold (or any style) wire frame of a Platonic solid built from rods (+ optional vertex balls).
local function frame(
	self: B,
	g: string,
	solid: string,
	center: Vec,
	radius: number,
	style: string,
	w: number,
	yaw: number?,
	pitch: number?,
	jointStyle: string?
)
	local verts, edges = DecorGeometry.platonic(solid)
	local placed = {}
	for i, p in verts do
		local q = rotY(rotX(p, pitch or 0), yaw or 0)
		placed[i] = add(center, scale(q, radius))
	end
	for _, e in edges do
		rod(self, g, solid .. "Edge", placed[e[1]], placed[e[2]], w, style)
	end
	if jointStyle then
		for _, p in placed do
			ball(self, g, solid .. "Joint", p, w * 2.2, jointStyle)
		end
	end
end
DecorGeometry.frame = frame

-- Torus approximated by `segs` rod segments (horizontal ring, optionally tilted about X).
local function torus(
	self: B,
	g: string,
	center: Vec,
	R: number,
	tube: number,
	segs: number,
	style: string,
	tiltX: number?
)
	local pts = {}
	for i = 0, segs do
		local a = i / segs * math.pi * 2
		pts[i] = add(center, rotX(v(math.cos(a) * R, 0, math.sin(a) * R), tiltX or 0))
	end
	for i = 0, segs - 1 do
		rod(self, g, "TorusSegment", pts[i], pts[i + 1], tube, style)
	end
end

-- REF_02 / REF_03 / REF_13: gold Platonic frame inside a crystal sphere with a glowing core.
local function crystalSphere(
	self: B,
	g: string,
	center: Vec,
	R: number,
	solid: string,
	ref: string,
	shell: string?
)
	group(self, g, center, ref, 1.5)
	ball(self, g, "CrystalShell", center, R * 2, shell or "crystal")
	ball(self, g, "Shimmer", center, R * 1.96, "forcefield")
	frame(self, g, solid, center, R * 0.82, "gold", math.max(0.12, R * 0.035), 18, 12, "chrome")
	ball(self, g, "Core", center, R * 0.28, "cyanNeon", "light")
end

-- REF_01 / REF_07: fractal cluster of gold / silver / teal spheres.
local SPHERE_STYLES = { "gold", "chrome", "teal" }
local function sphereCluster(self: B, g: string, center: Vec, r: number, depth: number, rnd: () -> number)
	ball(self, g, "ClusterSphere", center, r * 2, SPHERE_STYLES[1 + math.floor(rnd() * 3) % 3])
	if depth <= 0 then
		return
	end
	local n = if depth >= 2 then 6 else 4
	for i = 1, n do
		local theta = (i / n) * math.pi * 2 + rnd() * 0.6
		local phi = math.acos(2 * rnd() - 1)
		local dir = v(math.sin(phi) * math.cos(theta), math.cos(phi), math.sin(phi) * math.sin(theta))
		local cr = r * 0.42
		sphereCluster(self, g, add(center, scale(dir, r + cr * 0.75)), cr, depth - 1, rnd)
	end
end

---------------------------------------------------------------- scene pieces
-- Black-space star dust seen through the roof (REF shared look). Far, tiny Neon specks.
local function starfield(self: B, count: number)
	group(self, "StarDust", v(0, 120, 0), "shared")
	local rnd = lcg(1414)
	local styles = { "star", "star", "star", "starGold", "starTeal" }
	for _ = 1, count do
		local theta = rnd() * math.pi * 2
		local phi = rnd() * math.pi * 0.42 -- upper dome only
		local R = 150 + rnd() * 140
		local p = v(
			math.sin(phi) * math.cos(theta) * R,
			45 + math.cos(phi) * R * 0.75,
			math.sin(phi) * math.sin(theta) * R
		)
		ball(
			self,
			"StarDust",
			"Star",
			p,
			0.35 + rnd() * 0.9,
			styles[1 + math.floor(rnd() * #styles) % #styles]
		)
	end
end

-- DNA wormhole helix upgrade (REF_02 / REF_03 / REF_04 / REF_07 / REF_13): a torus of
-- distortion around the existing helix, plus the Platonic progression up its axis.
local function wormholeHelix(self: B)
	local c = DecorGeometry.LAYOUT.helix
	local mid = add(c, v(0, 12, 0))
	group(self, "WormholeTorus", mid, "REF_03", 0.6)
	torus(self, "WormholeTorus", mid, 8.5, 2.6, 28, "forcefield")
	torus(self, "WormholeTorus", mid, 8.5, 1.4, 28, "crystal")
	torus(self, "WormholeTorus", mid, 8.5, 0.35, 28, "gold", 0)
	torus(self, "WormholeTorus", mid, 10.4, 0.25, 32, "chrome", 8)
	ball(self, "WormholeTorus", "VortexEye", mid, 1.2, "cyanNeon", "swirl")
	-- REF_04 / REF_13: tetra -> cube -> octa -> dodeca -> icosa up the helix axis
	group(self, "HelixProgression", mid, "REF_13", 2)
	local order = { "tetra", "cube", "octa", "dodeca", "icosa" }
	for i, solid in order do
		local y = 4 + (i - 1) * 4
		frame(
			self,
			"HelixProgression",
			solid,
			add(c, v(0, y, 0)),
			if solid == "dodeca" then 2.1 else 1.7,
			"gold",
			0.14,
			i * 23,
			10
		)
	end
	-- REF_06 / REF_08: Voronoi-style (jittered hex) foam lattice inlaid in the floor around
	-- the helix, gold on one golden-spiral arm and silver on the other, cyan seams.
	group(self, "FoamLattice", c, "REF_06")
	local rnd = lcg(608)
	local cell = 2.6
	local cornersCache: { [string]: Vec } = {}
	local function corner(ix: number, iz: number, k: number): Vec
		-- shared hex corners so neighbouring cells meet; jitter keyed by the corner position
		local cx = ix * cell * 1.5
		local cz = iz * cell * math.sqrt(3) + (ix % 2) * cell * math.sqrt(3) / 2
		local a = math.rad(60 * k)
		local px, pz = cx + math.cos(a) * cell, cz + math.sin(a) * cell
		local key = string.format("%.1f:%.1f", px, pz)
		local hit = cornersCache[key]
		if hit then
			return hit
		end
		local jit = v(px + (rnd() - 0.5) * 0.9, 0.06, pz + (rnd() - 0.5) * 0.9)
		cornersCache[key] = jit
		return jit
	end
	local edgesDone: { [string]: boolean } = {}
	for ix = -8, 8 do
		for iz = -5, 5 do
			local cx = ix * cell * 1.5
			local cz = iz * cell * math.sqrt(3) + (ix % 2) * cell * math.sqrt(3) / 2
			local r = math.sqrt(cx * cx + cz * cz)
			local wz = c.z + cz
			if r > 9.5 and r < 19 and wz > -63 then
				local theta = math.atan2(cz, cx)
				local arm = math.sin(2 * (theta - math.log(r) / (math.log(PHI) / (math.pi / 2))))
				disc(
					self,
					"FoamLattice",
					"FoamTile",
					v(c.x + cx, 0.04, wz),
					cell * 1.55,
					0.08,
					if arm > 0 then "gold" else "silver"
				)
				for k = 0, 5 do
					local p1, p2 = corner(ix, iz, k), corner(ix, iz, (k + 1) % 6)
					local key = if p1.x < p2.x
						then string.format("%.2f,%.2f|%.2f,%.2f", p1.x, p1.z, p2.x, p2.z)
						else string.format("%.2f,%.2f|%.2f,%.2f", p2.x, p2.z, p1.x, p1.z)
					if not edgesDone[key] then
						edgesDone[key] = true
						rod(
							self,
							"FoamLattice",
							"FoamSeam",
							add(v(c.x, 0, c.z), p1),
							add(v(c.x, 0, c.z), p2),
							0.12,
							"cyanNeon"
						)
					end
				end
			end
		end
	end
end

-- REF_09 / REF_08: golden-spiral chain of gold polyhedra with cyan seams, hung over the lattice.
local function goldenSpiral(self: B)
	local c = add(DecorGeometry.LAYOUT.lattice, v(0, 19.5, 0))
	group(self, "GoldenSpiralChain", c, "REF_09", 0.8)
	local b = math.log(PHI) / (math.pi / 2) -- golden spiral: r grows by PHI every quarter turn
	local n = 30
	local prev: Vec? = nil
	for i = 0, n - 1 do
		local theta = i * 0.42
		local r = 0.55 * math.exp(b * theta)
		if r > 14 then
			break
		end
		local p = add(c, v(math.cos(theta) * r, -i * 0.04, math.sin(theta) * r))
		local s = math.max(0.35, r * 0.34)
		ball(self, "GoldenSpiralChain", "Polyhedron", p, s, "goldFoil")
		block(
			self,
			"GoldenSpiralChain",
			"Facets",
			p,
			v(s * 0.78, s * 0.78, s * 0.78),
			"gold",
			v(45, 35 + i * 11, 0)
		)
		if prev then
			rod(self, "GoldenSpiralChain", "Seam", prev, p, math.max(0.08, s * 0.12), "cyanNeon")
		end
		prev = p
	end
end

-- REF_11: five elemental Platonic crystals on chrome pedestals (colors from the image only).
local function elementalCrystals(self: B)
	local items = {
		{ solid = "tetra", style = "fireNeon", glass = "fireGlass", fx = "embers" },
		{ solid = "cube", style = "frostNeon", glass = "frostGlass", fx = "frost" },
		{ solid = "octa", style = "stormNeon", glass = "stormGlass", fx = "sparks" },
		{ solid = "dodeca", style = "solarNeon", glass = "solarGlass", fx = "swirl" },
		{ solid = "icosa", style = "cosmicNeon", glass = "cosmicGlass", fx = "stars" },
	}
	for i, it in items do
		local base = v(-44 + (i - 1) * 6, 0, -24)
		local g = "ElementalCrystal_" .. it.solid
		local top = add(base, v(0, 4.6, 0))
		group(self, g, top, "REF_11", 3)
		disc(self, g, "Pedestal", add(base, v(0, 1.3, 0)), 2.4, 2.6, "chrome")
		disc(self, g, "PedestalRing", add(base, v(0, 2.65, 0)), 2.6, 0.12, "cyanNeon")
		frame(self, g, it.solid, top, 1.5, it.style, 0.13, i * 17, 20)
		ball(self, g, "CrystalBody", top, 2.2, it.glass, it.fx)
	end
end

-- REF_05: stack of gold and chrome rings around an icosahedron, cyan energy core.
local function ringStack(self: B)
	local c = v(76, 0, -16)
	group(self, "GoldRingStack", add(c, v(0, 9, 0)), "REF_05", 1)
	disc(self, "GoldRingStack", "Base", add(c, v(0, 0.3, 0)), 7, 0.6, "chrome")
	type Ring = { y: number, R: number, style: string, tilt: number }
	local rings: { Ring } = {
		{ y = 2.5, R = 2.2, style = "chrome", tilt = 0 },
		{ y = 5.5, R = 3.2, style = "gold", tilt = 0 },
		{ y = 9, R = 4.6, style = "gold", tilt = 90 },
		{ y = 12.5, R = 3, style = "chrome", tilt = 0 },
		{ y = 15, R = 2, style = "gold", tilt = 0 },
	}
	for _, r in rings do
		torus(self, "GoldRingStack", add(c, v(0, r.y, 0)), r.R, 0.45, 22, r.style, r.tilt)
	end
	frame(self, "GoldRingStack", "icosa", add(c, v(0, 9, 0)), 2.6, "gold", 0.16, 10, 20, "chrome")
	ball(self, "GoldRingStack", "Core", add(c, v(0, 9, 0)), 1.1, "cyanNeon", "light")
	rod(self, "GoldRingStack", "Spine", add(c, v(0, 0.6, 0)), add(c, v(0, 17, 0)), 0.18, "cyanNeon")
end

-- REF_01: diagonal cascade of fractal sphere clusters out of a small vortex (west wall).
-- REF_07: sphere "tree" under a torus vortex (east corner).
local function fractalClusters(self: B)
	local rnd = lcg(107)
	group(self, "FractalCascade", v(-76, 8, -20), "REF_01")
	torus(self, "FractalCascade", v(-77, 17, -30), 3.2, 0.5, 18, "forcefield", 70)
	for i = 0, 3 do
		sphereCluster(
			self,
			"FractalCascade",
			v(-77 + i * 0.6, 14 - i * 3.6, -27 + i * 3.4),
			1.6 - i * 0.12,
			2,
			rnd
		)
	end
	group(self, "SphereTree", v(76, 8, -40), "REF_07")
	torus(self, "SphereTree", v(76, 19, -40), 4.2, 0.9, 22, "forcefield")
	torus(self, "SphereTree", v(76, 19, -40), 3.4, 0.25, 22, "gold")
	local layer = 0
	for y = 16, 2, -2.8 do
		local count = 1 + layer * 2
		local spread = 0.9 + layer * 1.1
		for k = 1, count do
			local a = k / count * math.pi * 2 + layer
			local rr = if count == 1 then 0 else spread
			local d = 1.6 - layer * 0.08 + rnd() * 0.5
			ball(
				self,
				"SphereTree",
				"TreeSphere",
				v(76 + math.cos(a) * rr, y, -40 + math.sin(a) * rr),
				d,
				SPHERE_STYLES[1 + (k + layer) % 3]
			)
		end
		layer += 1
	end
end

-- REF_10: Modular Crystal Block (crystal glass cube, gold superconductor edges, corner
-- connectors with cyan eyes, DNA-like energy channel inside) + REF_14 nebula triangle.
local function crystalBlockAndTriangle(self: B)
	local c = v(72, 4.5, 44)
	local s = 6
	group(self, "ModularCrystalBlock", c, "REF_10", nil, "cyanNeon")
	block(self, "ModularCrystalBlock", "CrystalGlass", c, v(s, s, s), "nebulaGlass", nil, "nebula")
	frame(self, "ModularCrystalBlock", "cube", c, s * math.sqrt(3) / 2, "gold", 0.32)
	local verts = DecorGeometry.platonic("cube")
	for _, p in verts do
		local q = add(c, scale(p, s * math.sqrt(3) / 2))
		block(self, "ModularCrystalBlock", "CornerConnector", q, v(0.9, 0.9, 0.9), "gold")
		ball(self, "ModularCrystalBlock", "ConnectorEye", q, 0.5, "cyanNeon")
	end
	for i = 0, 15 do
		local t = i / 15
		local a = t * math.pi * 3
		local y = c.y - s * 0.4 + t * s * 0.8
		ball(
			self,
			"ModularCrystalBlock",
			"EnergyChannelA",
			v(c.x + math.cos(a) * 0.9, y, c.z + math.sin(a) * 0.9),
			0.32,
			"cyanNeon"
		)
		ball(
			self,
			"ModularCrystalBlock",
			"EnergyChannelB",
			v(c.x - math.cos(a) * 0.9, y, c.z - math.sin(a) * 0.9),
			0.32,
			"cyanNeon"
		)
	end
	disc(self, "ModularCrystalBlock", "Plinth", v(c.x, 0.5, c.z), s * 1.5, 1, "chrome")

	-- REF_14: upright equilateral triangle module, cyan glowing edges, gold corner clamps.
	local tc = v(62, 4.2, 50)
	local side = 6
	local h = side * math.sqrt(3) / 2
	group(self, "NebulaTriangleModule", tc, "REF_14", nil, "cyanNeon")
	local top = add(tc, v(0, h * 2 / 3, 0))
	local left = add(tc, v(0, -h / 3, -side / 2))
	local right = add(tc, v(0, -h / 3, side / 2))
	-- nebula face: two right wedges meeting on the vertical center line (faces +/-X)
	push(self, {
		kind = "wedge",
		group = "NebulaTriangleModule",
		name = "NebulaFaceL",
		p = add(tc, v(0, h / 6, -side / 4)),
		size = v(0.3, h, side / 2),
		style = "nebulaPurple",
		fx = "nebula",
	})
	push(self, {
		kind = "wedge",
		group = "NebulaTriangleModule",
		name = "NebulaFaceR",
		p = add(tc, v(0, h / 6, side / 4)),
		size = v(0.3, h, side / 2),
		rot = v(0, 180, 0),
		style = "nebulaPurple",
	})
	rod(self, "NebulaTriangleModule", "GlowEdge", top, left, 0.35, "cyanNeon")
	rod(self, "NebulaTriangleModule", "GlowEdge", left, right, 0.35, "cyanNeon")
	rod(self, "NebulaTriangleModule", "GlowEdge", right, top, 0.35, "cyanNeon")
	for _, p in { top, left, right } do
		block(self, "NebulaTriangleModule", "GoldCorner", p, v(0.8, 0.9, 0.9), "gold")
	end
	disc(self, "NebulaTriangleModule", "Stand", v(tc.x, 0.25, tc.z), 3, 0.5, "chrome")
	rod(
		self,
		"NebulaTriangleModule",
		"StandPost",
		v(tc.x, 0.5, tc.z),
		add(tc, v(0, -h / 3, 0)),
		0.25,
		"chrome"
	)
end

-- REF_03 gold cube in a golden sphere with chrome + gold tori, and REF_02 star tetrahedron
-- (merkaba) in a crystal sphere with a torus vortex.
local function featureSpheres(self: B)
	local c3 = v(76, 7, 16)
	crystalSphere(self, "GoldCubeSphere", c3, 4, "cube", "REF_03", "crystalGold")
	torus(self, "GoldCubeSphere", c3, 2.2, 0.45, 20, "chrome")
	torus(self, "GoldCubeSphere", c3, 1.1, 0.35, 16, "gold")
	disc(self, "GoldCubeSphere", "Plinth", v(c3.x, 0.6, c3.z), 4, 1.2, "chrome")
	local c2 = v(-76, 7, 8)
	crystalSphere(self, "MerkabaSphere", c2, 4, "merkaba", "REF_02")
	torus(self, "MerkabaSphere", c2, 1.6, 0.4, 18, "crystal", 20)
	disc(self, "MerkabaSphere", "Plinth", v(c2.x, 0.6, c2.z), 4, 1.2, "chrome")
end

-- TETRAFORGE chamber: cyan Neon edges and gold corner connectors (REF_10 language).
local function chamberFrame(self: B)
	local c = DecorGeometry.LAYOUT.chamber
	group(self, "ChamberFrame", c, "REF_10", nil, "cyanNeon")
	-- chamber is rotated -90 deg about Y: its 10.5 width runs along world Z, depth along X
	local hx, hy, hz = 1.15, 10.4, 5.4
	local corners = {}
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				table.insert(corners, v(c.x + sx * hx, c.y + sy * hy, c.z + sz * hz))
			end
		end
	end
	for i = 1, #corners do
		for j = i + 1, #corners do
			local a, b = corners[i], corners[j]
			local diff = (if a.x ~= b.x then 1 else 0)
				+ (if a.y ~= b.y then 1 else 0)
				+ (if a.z ~= b.z then 1 else 0)
			if diff == 1 then
				rod(self, "ChamberFrame", "NeonEdge", a, b, 0.22, "cyanNeon")
			end
		end
	end
	for _, p in corners do
		block(self, "ChamberFrame", "GoldConnector", p, v(0.7, 0.7, 0.7), "gold")
	end
end

-- Quantum table: procedural stand-ins for the REF_12 / REF_13 flipbooks (used when the
-- sprite sheets are not uploaded): a crystal seed cluster and a small helix-in-frame model.
local function quantumTable(self: B)
	local q = DecorGeometry.LAYOUT.quantumTable
	local seed = add(q, v(4.2, 0.9, -2))
	group(self, "CrystalSeed", seed, "REF_12", 1)
	local rnd = lcg(1212)
	for i = 1, 9 do
		local a = i / 9 * 360
		local len = 0.6 + rnd() * 0.9
		block(
			self,
			"CrystalSeed",
			"Shard",
			add(seed, v(math.cos(math.rad(a)) * 0.25, len / 2, math.sin(math.rad(a)) * 0.25)),
			v(0.22, len, 0.22),
			"crystal",
			v(18 * math.cos(math.rad(a)), a, 18 * math.sin(math.rad(a)))
		)
	end
	ball(self, "CrystalSeed", "SeedCore", add(seed, v(0, 0.35, 0)), 0.3, "cyanNeon", "light")
	local holo = add(q, v(-3.5, 1.9, 1.6))
	group(self, "HoloHelixFrame", holo, "REF_13", 4)
	frame(self, "HoloHelixFrame", "dodeca", holo, 0.9, "gold", 0.05, 0, 0)
	for i = 0, 9 do
		local t = i / 9
		local a = t * math.pi * 2
		ball(
			self,
			"HoloHelixFrame",
			"HelixBead",
			add(holo, v(math.cos(a) * 0.3, -0.7 + t * 1.4, math.sin(a) * 0.3)),
			0.12,
			"cyanNeon"
		)
		ball(
			self,
			"HoloHelixFrame",
			"HelixBead",
			add(holo, v(-math.cos(a) * 0.3, -0.7 + t * 1.4, -math.sin(a) * 0.3)),
			0.12,
			"cyanNeon"
		)
	end
end

---------------------------------------------------------------- entry point
DecorGeometry.PART_BUDGET = 1700 -- decor parts; the hub itself is ~600

function DecorGeometry.build(): Decor
	local self = newBuilder()
	starfield(self, 260)
	wormholeHelix(self)
	goldenSpiral(self)
	elementalCrystals(self)
	ringStack(self)
	fractalClusters(self)
	crystalBlockAndTriangle(self)
	featureSpheres(self)
	chamberFrame(self)
	quantumTable(self)
	return { prims = self.prims, groups = self.groups }
end

return DecorGeometry
