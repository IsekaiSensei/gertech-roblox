--!strict
-- Procedurally builds the GERTECH workshop hub from Parts so the game runs in a blank
-- Baseplate. Set dressing follows Ryan's lore: parts are GROWN and ASSEMBLED here (coral
-- growth vats, resin printer, 3D printer, arc welder, lathe, machine-shop tools), the
-- workbench is the QUANTUM TABLE (tabletop virtual-avatar rig piloting a micronized
-- android), and the transfer portal is the DNA WORMHOLE HELIX.
-- Everything is primitive geometry: swap in real models later by replacing the builders.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local PlaceRegistry = require(Shared.PlaceRegistry)
local ResourceNodeDefs = require(Shared.ResourceNodeDefs)

local HubBuilder = {}

export type HubRefs = {
	forgeConsole: BasePart,
	forgePrompt: ProximityPrompt,
	exchange: BasePart,
	exchangePrompt: ProximityPrompt,
	sockets: { { part: BasePart, prompt: ProximityPrompt } },
	nodes: { { part: BasePart, prompt: ProximityPrompt, nodeType: string } },
	helixPads: { { prompt: ProximityPrompt, destination: string } },
	inspectables: { { prompt: ProximityPrompt, text: string } },
	stationParts: { [string]: BasePart },
}

local root: Model

local function part(props: { [string]: any }): BasePart
	local p: Part = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent or root
	return p
end

local function group(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = root
	return m
end

local function label(adornee: BasePart, text: string, offsetY: number, color: Color3?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(260, 46)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 90
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.TextColor3 = color or Color3.fromRGB(230, 245, 255)
	t.TextStrokeTransparency = 0.4
	t.Text = text
	t.Parent = gui
	gui.Parent = adornee
end

local function prompt(parentPart: BasePart, action: string, object: string, hold: number?): ProximityPrompt
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = object
	pp.HoldDuration = hold or 0
	pp.MaxActivationDistance = 10
	pp.RequiresLineOfSight = false
	pp.Parent = parentPart
	return pp
end

local function light(p: BasePart, color: Color3, brightness: number, range: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Parent = p
	return l
end

local function sparks(p: BasePart, color: Color3, rate: number)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Rate = rate
	e.Lifetime = NumberRange.new(0.2, 0.6)
	e.Speed = NumberRange.new(6, 14)
	e.SpreadAngle = Vector2.new(60, 60)
	e.Size = NumberSequence.new(0.15, 0)
	e.Parent = p
end

local function bubbles(p: BasePart)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(200, 240, 255))
	e.Transparency = NumberSequence.new(0.4, 1)
	e.Rate = 6
	e.Lifetime = NumberRange.new(2, 3)
	e.Speed = NumberRange.new(2, 4)
	e.EmissionDirection = Enum.NormalId.Top
	e.Size = NumberSequence.new(0.25, 0.4)
	e.Parent = p
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local function buildShell()
	local shell = group("Shell")
	part({
		Name = "Floor",
		Size = Vector3.new(170, 2, 130),
		CFrame = at(0, -1, 0),
		Color = Color3.fromRGB(38, 46, 56),
		Material = Enum.Material.DiamondPlate,
		Parent = shell,
	})
	local wallColor = Color3.fromRGB(28, 40, 54)
	part({
		Name = "WallN",
		Size = Vector3.new(170, 26, 2),
		CFrame = at(0, 12, -65),
		Color = wallColor,
		Material = Enum.Material.Metal,
		Parent = shell,
	})
	part({
		Name = "WallS",
		Size = Vector3.new(170, 26, 2),
		CFrame = at(0, 12, 65),
		Color = wallColor,
		Material = Enum.Material.Metal,
		Parent = shell,
	})
	part({
		Name = "WallE",
		Size = Vector3.new(2, 26, 130),
		CFrame = at(85, 12, 0),
		Color = wallColor,
		Material = Enum.Material.Metal,
		Parent = shell,
	})
	part({
		Name = "WallW",
		Size = Vector3.new(2, 26, 130),
		CFrame = at(-85, 12, 0),
		Color = wallColor,
		Material = Enum.Material.Metal,
		Parent = shell,
	})
	-- Undersea observation glass roof
	part({
		Name = "SeaGlassRoof",
		Size = Vector3.new(170, 1, 130),
		CFrame = at(0, 25, 0),
		Color = Color3.fromRGB(40, 120, 170),
		Material = Enum.Material.Glass,
		Transparency = 0.55,
		Parent = shell,
	})
	-- Ceiling trusses
	for x = -75, 75, 25 do
		part({
			Name = "Truss",
			Size = Vector3.new(1.5, 1.5, 128),
			CFrame = at(x, 23.5, 0),
			Color = Color3.fromRGB(90, 100, 110),
			Material = Enum.Material.Metal,
			Parent = shell,
		})
	end
	-- Gold superconductor lines along the floor (visual only, as in Godot)
	for _, z in { -10, 10 } do
		local rail = part({
			Name = "GoldLine",
			Size = Vector3.new(150, 0.2, 0.6),
			CFrame = at(0, 0.1, z),
			Color = Color3.fromRGB(255, 200, 70),
			Material = Enum.Material.Neon,
			Parent = shell,
		})
		rail.CanCollide = false
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = at(0, 0.5, 45)
	spawn.Color = Color3.fromRGB(60, 200, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Neutral = true
	spawn.Parent = shell
	local sign = part({
		Name = "Sign",
		Size = Vector3.new(40, 6, 1),
		CFrame = at(0, 18, -63.5),
		Color = Color3.fromRGB(10, 20, 30),
		Parent = shell,
	})
	label(sign, "GERTECH — AQUA WORKSHOP", 0, Color3.fromRGB(120, 220, 255))
end

local function buildTetraforge(refs: HubRefs)
	local g = group("TETRAFORGE")
	local base = part({
		Name = "Plinth",
		Size = Vector3.new(26, 1, 18),
		CFrame = at(55, 0.5, 0),
		Color = Color3.fromRGB(50, 50, 55),
		Material = Enum.Material.Metal,
		Parent = g,
	})
	-- 10 x 20 forge chamber (scaled), glass front with a few packed rows
	local chamber = part({
		Name = "Chamber",
		Size = Vector3.new(10.5, 20.5, 2),
		CFrame = at(62, 11, 0) * CFrame.Angles(0, math.rad(-90), 0),
		Color = Color3.fromRGB(30, 40, 60),
		Material = Enum.Material.Glass,
		Transparency = 0.4,
		Parent = g,
	})
	local colors = { Color3.fromHex("dfa55e"), Color3.fromHex("6dc6df"), Color3.fromHex("f4e4b2") }
	for row = 0, 3 do
		for col = 0, 9 do
			if not (row == 3 and col > 5) then
				local c = part({
					Name = "Cell",
					Size = Vector3.new(0.95, 0.95, 0.95),
					CFrame = chamber.CFrame * CFrame.new(col - 4.5, row - 9.5, 0),
					Color = colors[(row + col) % 3 + 1],
					Material = Enum.Material.Neon,
					Parent = g,
				})
				c.CanCollide = false
			end
		end
	end
	-- Feed hoppers: ore / salvage / pure
	local hopperNames = { "ORE", "SALVAGE", "PURE" }
	for i, name in hopperNames do
		local h = part({
			Name = "Hopper_" .. name,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(6, 4, 4),
			CFrame = at(50, 6, -8 + (i - 1) * 8) * CFrame.Angles(0, 0, math.rad(90)),
			Color = colors[i],
			Material = Enum.Material.Metal,
			Parent = g,
		})
		label(h, name .. " HOPPER", 4)
	end
	local crucible = part({
		Name = "Crucible",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, 7, 7),
		CFrame = at(56, 3, 7) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 110, 40),
		Material = Enum.Material.Neon,
		Parent = g,
	})
	light(crucible, Color3.fromRGB(255, 120, 50), 3, 18)
	local console = part({
		Name = "OperatorConsole",
		Size = Vector3.new(4, 3.5, 6),
		CFrame = at(46, 1.75, 0),
		Color = Color3.fromRGB(60, 200, 255),
		Material = Enum.Material.Neon,
		Parent = g,
	})
	light(console, Color3.fromRGB(60, 200, 255), 1.5, 12)
	label(base, "TETRAFORGE", 14, Color3.fromRGB(255, 180, 90))
	label(console, "Operator Console", 3)
	refs.forgeConsole = console
	refs.forgePrompt = prompt(console, "Operate", "TETRAFORGE")
	refs.stationParts.tetraforge = console
	-- Output conveyor
	part({
		Name = "Conveyor",
		Size = Vector3.new(4, 1, 20),
		CFrame = at(55, 1, -20),
		Color = Color3.fromRGB(30, 30, 30),
		Material = Enum.Material.Rubber,
		Parent = g,
	})

	-- Stock exchange (visor chip upgrade)
	local ex = part({
		Name = "StockExchange",
		Size = Vector3.new(6, 4, 4),
		CFrame = at(50, 2, 28),
		Color = Color3.fromRGB(255, 210, 120),
		Material = Enum.Material.Metal,
		Parent = g,
	})
	label(ex, "Stock Exchange", 4)
	refs.exchange = ex
	refs.exchangePrompt = prompt(ex, "Trade", "Stock Exchange")
end

local function buildHelix(refs: HubRefs)
	local g = group("DNAWormholeHelix")
	local center = Vector3.new(0, 0, -50)
	part({
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 18, 18),
		CFrame = CFrame.new(center + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(40, 40, 70),
		Material = Enum.Material.Metal,
		Parent = g,
	})
	local steps = 40
	for i = 0, steps do
		local t = i / steps
		local y = 2 + t * 20
		local a = t * math.pi * 4
		local p1 = center + Vector3.new(math.cos(a) * 5, y, math.sin(a) * 5)
		local p2 = center + Vector3.new(math.cos(a + math.pi) * 5, y, math.sin(a + math.pi) * 5)
		local s1 = part({
			Name = "StrandA",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.2, 1.2, 1.2),
			CFrame = CFrame.new(p1),
			Color = Color3.fromRGB(120, 90, 255),
			Material = Enum.Material.Neon,
			Parent = g,
		})
		local s2 = part({
			Name = "StrandB",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.2, 1.2, 1.2),
			CFrame = CFrame.new(p2),
			Color = Color3.fromRGB(80, 220, 255),
			Material = Enum.Material.Neon,
			Parent = g,
		})
		s1.CanCollide, s2.CanCollide = false, false
		if i % 3 == 0 then
			local mid = (p1 + p2) / 2
			local rung = part({
				Name = "BasePair",
				Size = Vector3.new(0.3, 0.3, (p1 - p2).Magnitude),
				CFrame = CFrame.lookAt(mid, p2),
				Color = Color3.fromRGB(230, 230, 255),
				Material = Enum.Material.Neon,
				Transparency = 0.3,
				Parent = g,
			})
			rung.CanCollide = false
		end
	end
	local core = part({
		Name = "Aperture",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3, 3),
		CFrame = CFrame.new(center + Vector3.new(0, 12, 0)),
		Color = Color3.fromRGB(180, 140, 255),
		Material = Enum.Material.ForceField,
		Parent = g,
	})
	core.CanCollide = false
	light(core, Color3.fromRGB(150, 120, 255), 4, 30)
	label(core, "DNA WORMHOLE HELIX", 13, Color3.fromRGB(200, 170, 255))
	-- One destination pad per future place
	for i, key in PlaceRegistry.HELIX_DESTINATIONS do
		local angle = math.rad(-60 + (i - 1) * 30)
		local pos = center + Vector3.new(math.sin(angle) * 14, 0.3, math.cos(angle) * 14)
		local pad = part({
			Name = "Pad_" .. key,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, 5, 5),
			CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(110, 80, 220),
			Material = Enum.Material.Neon,
			Parent = g,
		})
		local dest = PlaceRegistry.Places[key]
		label(pad, dest.name, 3)
		table.insert(refs.helixPads, { prompt = prompt(pad, "Transfer", dest.name, 0.75), destination = key })
	end
end

local function buildLattice(refs: HubRefs)
	local g = group("LatticeFrame")
	local center = Vector3.new(0, 0, 5)
	part({
		Name = "Pedestal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 16, 16),
		CFrame = CFrame.new(center + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(45, 55, 70),
		Material = Enum.Material.Metal,
		Parent = g,
	})
	for i = 1, 12 do
		local a = (i - 1) / 12 * math.pi * 2
		local pos = center + Vector3.new(math.cos(a) * 6, 4 + (i % 2) * 1.5, math.sin(a) * 6)
		local sock = part({
			Name = "Socket_" .. i,
			Size = Vector3.new(1.6, 1.6, 1.6),
			CFrame = CFrame.new(pos),
			Color = Color3.fromRGB(80, 90, 110),
			Material = Enum.Material.Glass,
			Transparency = 0.6,
			Parent = g,
		})
		local pp = prompt(sock, "Place Packed Block", "Lattice Socket " .. i)
		pp.MaxActivationDistance = 8
		table.insert(refs.sockets, { part = sock, prompt = pp })
		-- gold joint to the next socket
		local nextA = i / 12 * math.pi * 2
		local nextPos = center
			+ Vector3.new(math.cos(nextA) * 6, 4 + ((i + 1) % 2) * 1.5, math.sin(nextA) * 6)
		local mid = (pos + nextPos) / 2
		local joint = part({
			Name = "GoldJoint",
			Size = Vector3.new(0.2, 0.2, (pos - nextPos).Magnitude),
			CFrame = CFrame.lookAt(mid, nextPos),
			Color = Color3.fromRGB(255, 200, 70),
			Material = Enum.Material.Neon,
			Parent = g,
		})
		joint.CanCollide = false
	end
	label(refs.sockets[1].part, "WorldSeed Lattice (core)", 4)
end

local function buildStations(refs: HubRefs)
	local g = group("GrowthAndAssembly")
	-- Coral growth vats
	for i = 0, 2 do
		local x = -70 + i * 9
		local vat = part({
			Name = "CoralVat",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(12, 7, 7),
			CFrame = at(x, 6, -45) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(60, 160, 200),
			Material = Enum.Material.Glass,
			Transparency = 0.5,
			Parent = g,
		})
		vat.CanCollide = true
		for b = 1, 6 do
			local coral = part({
				Name = "CoralBranch",
				Size = Vector3.new(0.5, 2 + b % 3, 0.5),
				CFrame = at(x + math.sin(b) * 1.8, 2 + b, -45 + math.cos(b) * 1.8)
					* CFrame.Angles(math.rad(b * 20), 0, math.rad(b * 35)),
				Color = Color3.fromRGB(255, 120 + b * 15, 150),
				Material = Enum.Material.Neon,
				Parent = g,
			})
			coral.CanCollide = false
		end
		bubbles(vat)
		light(vat, Color3.fromRGB(255, 140, 180), 1, 10)
		if i == 1 then
			label(vat, "Coral Growth Vats", 8)
			refs.stationParts.coral_vat = vat
			table.insert(refs.inspectables, {
				prompt = prompt(vat, "Inspect", "Coral Growth Vat"),
				text = "Colonies are bred for the skeletal parts they leave behind: harvest, sort, assemble. You don't build the parts; you pick the ones nature grows.",
			})
		end
	end
	-- Resin printer
	local resin = part({
		Name = "ResinPrinter",
		Size = Vector3.new(5, 7, 5),
		CFrame = at(-38, 3.5, -50),
		Color = Color3.fromRGB(240, 120, 40),
		Material = Enum.Material.Glass,
		Transparency = 0.25,
		Parent = g,
	})
	part({
		Name = "ResinVat",
		Size = Vector3.new(4.5, 1, 4.5),
		CFrame = at(-38, 1, -50),
		Color = Color3.fromRGB(255, 200, 60),
		Material = Enum.Material.Neon,
		Parent = g,
	})
	label(resin, "Resin Printer", 5)
	refs.stationParts.resin_printer = resin
	table.insert(refs.inspectables, {
		prompt = prompt(resin, "Inspect", "Resin Printer"),
		text = "Resin printer: fine-detail housings and molds for grown parts.",
	})
	-- 3D printer (FDM)
	local fdm = part({
		Name = "Printer3D",
		Size = Vector3.new(6, 6, 6),
		CFrame = at(-26, 3, -50),
		Color = Color3.fromRGB(70, 70, 80),
		Material = Enum.Material.Metal,
		Parent = g,
	})
	local head = part({
		Name = "PrintHead",
		Size = Vector3.new(1, 1, 1),
		CFrame = at(-26, 5, -50),
		Color = Color3.fromRGB(255, 80, 80),
		Material = Enum.Material.Neon,
		Parent = g,
	})
	head.CanCollide = false
	label(fdm, "3D Printer", 5)
	refs.stationParts.printer = fdm
	table.insert(refs.inspectables, {
		prompt = prompt(fdm, "Inspect", "3D Printer"),
		text = "3D printer: printed parts show layer lines next to grown parts.",
	})
	-- Arc welder
	local welder = part({
		Name = "ArcWelder",
		Size = Vector3.new(3, 4, 3),
		CFrame = at(22, 2, -55),
		Color = Color3.fromRGB(40, 90, 200),
		Material = Enum.Material.Metal,
		Parent = g,
	})
	local torch = part({
		Name = "Torch",
		Size = Vector3.new(0.4, 0.4, 0.4),
		CFrame = at(25, 3.5, -53),
		Color = Color3.fromRGB(180, 220, 255),
		Material = Enum.Material.Neon,
		Parent = g,
	})
	sparks(torch, Color3.fromRGB(200, 230, 255), 25)
	light(torch, Color3.fromRGB(170, 210, 255), 3, 14)
	label(welder, "Arc Welder", 4)
	refs.stationParts.arc_welder = welder
	table.insert(refs.inspectables, {
		prompt = prompt(welder, "Inspect", "Arc Welder"),
		text = "Arc welder: joins frames once grown parts are sorted.",
	})
	-- Lathe
	local lathe = part({
		Name = "Lathe",
		Size = Vector3.new(10, 3, 3),
		CFrame = at(36, 3, -55),
		Color = Color3.fromRGB(90, 110, 90),
		Material = Enum.Material.Metal,
		Parent = g,
	})
	part({
		Name = "LatheBed",
		Size = Vector3.new(10, 2, 3),
		CFrame = at(36, 1, -55),
		Color = Color3.fromRGB(60, 60, 60),
		Material = Enum.Material.Metal,
		Parent = g,
	})
	part({
		Name = "Chuck",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 2.5, 2.5),
		CFrame = at(31.5, 4.8, -55),
		Color = Color3.fromRGB(180, 180, 180),
		Material = Enum.Material.Metal,
		Parent = g,
	})
	label(lathe, "Lathe", 4)
	refs.stationParts.lathe = lathe
	table.insert(
		refs.inspectables,
		{ prompt = prompt(lathe, "Inspect", "Lathe"), text = "Lathe: turns axles and pins to fit." }
	)
	-- Machine-shop tools: drill press, bench grinder, tool wall
	local drill = part({
		Name = "DrillPress",
		Size = Vector3.new(2, 8, 2),
		CFrame = at(50, 4, -58),
		Color = Color3.fromRGB(150, 60, 60),
		Material = Enum.Material.Metal,
		Parent = g,
	})
	label(drill, "Drill Press", 5)
	local grinder = part({
		Name = "BenchGrinder",
		Size = Vector3.new(4, 3, 2),
		CFrame = at(58, 3, -58),
		Color = Color3.fromRGB(100, 100, 110),
		Material = Enum.Material.Metal,
		Parent = g,
	})
	sparks(grinder, Color3.fromRGB(255, 180, 80), 8)
	label(grinder, "Bench Grinder", 3)
	local toolWall = part({
		Name = "ToolWall",
		Size = Vector3.new(20, 10, 0.5),
		CFrame = at(70, 7, -63.5),
		Color = Color3.fromRGB(60, 70, 60),
		Material = Enum.Material.WoodPlanks,
		Parent = g,
	})
	for i = 0, 9 do
		part({
			Name = "Tool",
			Size = Vector3.new(0.4, 2 + (i % 3), 0.3),
			CFrame = at(62 + i * 1.7, 7, -63),
			Color = Color3.fromRGB(190, 190, 200),
			Material = Enum.Material.Metal,
			Parent = g,
		})
	end
	label(toolWall, "Machine Shop", 6)

	-- Quantum table
	local qt = group("QuantumTable")
	local top = part({
		Name = "TableTop",
		Size = Vector3.new(14, 0.6, 8),
		CFrame = at(-55, 3.5, 5),
		Color = Color3.fromRGB(20, 25, 35),
		Material = Enum.Material.Glass,
		Parent = qt,
	})
	for _, o in { Vector3.new(-6, 0, -3), Vector3.new(6, 0, -3), Vector3.new(-6, 0, 3), Vector3.new(6, 0, 3) } do
		part({
			Name = "Leg",
			Size = Vector3.new(0.6, 3.2, 0.6),
			CFrame = at(-55 + o.X, 1.6, 5 + o.Z),
			Color = Color3.fromRGB(80, 80, 90),
			Material = Enum.Material.Metal,
			Parent = qt,
		})
	end
	local holo = part({
		Name = "HoloGrid",
		Size = Vector3.new(12, 0.1, 6.5),
		CFrame = at(-55, 3.85, 5),
		Color = Color3.fromRGB(60, 220, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.6,
		Parent = qt,
	})
	holo.CanCollide = false
	-- Micronized android (tiny figure on the table) and its virtual avatar projection
	local android = part({
		Name = "MicronizedAndroid",
		Size = Vector3.new(0.4, 0.9, 0.3),
		CFrame = at(-53, 4.4, 5),
		Color = Color3.fromRGB(220, 220, 230),
		Material = Enum.Material.Metal,
		Parent = qt,
	})
	android.CanCollide = false
	local avatar = part({
		Name = "VirtualAvatar",
		Size = Vector3.new(1.5, 3.5, 1),
		CFrame = at(-57, 6.2, 5),
		Color = Color3.fromRGB(80, 200, 255),
		Material = Enum.Material.ForceField,
		Parent = qt,
	})
	avatar.CanCollide = false
	light(holo, Color3.fromRGB(60, 220, 255), 1.5, 12)
	label(top, "Quantum Table", 5, Color3.fromRGB(120, 230, 255))
	refs.stationParts.quantum_table = top
	table.insert(refs.inspectables, {
		prompt = prompt(top, "Pilot", "Quantum Table"),
		text = "Quantum table: your tabletop virtual avatar pilots a micronized android through the workshop's smallest spaces. (Piloting mode planned.)",
	})
end

local function buildResourceDocks(refs: HubRefs)
	local g = group("IntakeDocks")
	local origins = {
		dig_dog_seam = Vector3.new(-65, 0, 30),
		asteroid_salvage = Vector3.new(-45, 0, 48),
		breakout_parts = Vector3.new(-25, 0, 55),
	}
	for _, id in ResourceNodeDefs.ORDER do
		local def = ResourceNodeDefs.Defs[id]
		local o = origins[id]
		local dockSign = part({
			Name = "Dock_" .. def.dock,
			Size = Vector3.new(8, 0.4, 8),
			CFrame = CFrame.new(o + Vector3.new(0, 0.2, 0)),
			Color = Color3.fromRGB(50, 60, 70),
			Material = Enum.Material.Metal,
			Parent = g,
		})
		label(dockSign, def.dock .. " DOCK", 8, def.color)
		for i = 1, def.count do
			local offset = Vector3.new((i - 1) * 6 - (def.count - 1) * 3, 0, -6 + (i % 2) * 3)
			local node = part({
				Name = def.id,
				Shape = if id == "breakout_parts" then Enum.PartType.Block else Enum.PartType.Ball,
				Size = if id == "breakout_parts" then Vector3.new(3, 2.5, 3) else Vector3.new(3.5, 3.5, 3.5),
				CFrame = CFrame.new(o + offset + Vector3.new(0, 1.75, 0)),
				Color = def.color,
				Material = if id == "dig_dog_seam"
					then Enum.Material.Slate
					elseif id == "asteroid_salvage" then Enum.Material.CorrodedMetal
					else Enum.Material.Metal,
				Parent = g,
			})
			node:SetAttribute("NodeType", id)
			local gui = Instance.new("BillboardGui")
			gui.Name = "ChargeGui"
			gui.Size = UDim2.fromOffset(80, 24)
			gui.StudsOffset = Vector3.new(0, 3, 0)
			gui.MaxDistance = 40
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			t.TextColor3 = Color3.new(1, 1, 1)
			t.TextStrokeTransparency = 0.3
			t.Font = Enum.Font.GothamBold
			t.TextScaled = true
			t.Parent = gui
			gui.Parent = node
			table.insert(
				refs.nodes,
				{ part = node, prompt = prompt(node, "Gather", def.name, def.holdSeconds), nodeType = id }
			)
		end
	end
	-- Docks that exist in Godot as scenery only (minigames not implemented there either)
	local offline = {
		{ "MOUSE MAZE", "FOOD + GUIDES" },
		{ "FROGGER", "DELIVERED STOCK" },
		{ "SPACE INVADERS", "DEFENSE TECH" },
	}
	for i, d in offline do
		local p = part({
			Name = "OfflineDock_" .. d[1],
			Size = Vector3.new(8, 4, 3),
			CFrame = at(20 + (i - 1) * 14, 2, 60),
			Color = Color3.fromRGB(45, 50, 60),
			Material = Enum.Material.Metal,
			Parent = g,
		})
		label(p, d[1] .. " DOCK — " .. d[2] .. " (offline)", 4, Color3.fromRGB(160, 170, 180))
	end
end

local function buildAtmosphere()
	Lighting.Ambient = Color3.fromRGB(25, 45, 65)
	Lighting.OutdoorAmbient = Color3.fromRGB(40, 70, 100)
	Lighting.FogColor = Color3.fromRGB(20, 60, 90)
	Lighting.FogEnd = 400
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local a = Instance.new("Atmosphere")
		a.Color = Color3.fromRGB(70, 140, 180)
		a.Decay = Color3.fromRGB(20, 60, 90)
		a.Density = 0.35
		a.Parent = Lighting
	end
end

function HubBuilder.build(): HubRefs
	local existing = workspace:FindFirstChild("GERTECH_Hub")
	if existing then
		existing:Destroy()
	end
	-- Remove the default Baseplate so it doesn't z-fight with the floor
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	root = Instance.new("Model")
	root.Name = "GERTECH_Hub"
	root.Parent = workspace
	local refs: HubRefs = {
		sockets = {},
		nodes = {},
		helixPads = {},
		inspectables = {},
		stationParts = {},
	} :: any
	buildShell()
	buildAtmosphere()
	buildTetraforge(refs)
	buildHelix(refs)
	buildLattice(refs)
	buildStations(refs)
	buildResourceDocks(refs)
	return refs
end

return HubBuilder
