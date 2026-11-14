--!strict
-- PROVISIONAL LOOK PASS toward Ryan's shared references GERTECH_REF_01..14 (2026-11-14).
-- Not canon and not gameplay: Godot stays the source of truth for logic. This only restyles
-- the procedurally built hub (lighting, materials, colors) and adds non-interactive decor:
--   black space + star dust, polished gold / chrome, glowing cyan edges, gold Platonic
--   frames in crystal spheres, the DNA wormhole helix as a torus of distortion with the
--   helix inside, fractal sphere clusters, a Voronoi-style foam lattice, a golden-spiral
--   polyhedra chain, the Modular Crystal Block, the elemental crystals, the nebula triangle.
-- Image slots (ImageAssets) are used only when an uploaded asset id is filled in; with
-- empty slots everything here is procedural geometry. Toggle: Config.VISUAL_STYLE.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local DecorGeometry = require(Shared.DecorGeometry)
local ImageAssets = require(Shared.ImageAssets)

local VisualStyle = {}

export type Style = { material: Enum.Material, color: Color3, reflectance: number?, transparency: number? }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local M = Enum.Material
VisualStyle.STYLES = {
	gold = { material = M.Metal, color = rgb(212, 175, 55), reflectance = 0.25 },
	goldFoil = { material = M.Foil, color = rgb(225, 185, 70), reflectance = 0.2 },
	chrome = { material = M.Metal, color = rgb(210, 215, 225), reflectance = 0.5 },
	silver = { material = M.Metal, color = rgb(165, 170, 180), reflectance = 0.35 },
	teal = { material = M.Metal, color = rgb(35, 165, 175), reflectance = 0.3 },
	cyanNeon = { material = M.Neon, color = rgb(80, 230, 255) },
	goldNeon = { material = M.Neon, color = rgb(255, 200, 90) },
	crystal = { material = M.Glass, color = rgb(200, 230, 255), transparency = 0.6, reflectance = 0.1 },
	crystalGold = { material = M.Glass, color = rgb(255, 215, 120), transparency = 0.55, reflectance = 0.1 },
	forcefield = { material = M.ForceField, color = rgb(120, 220, 255) },
	star = { material = M.Neon, color = rgb(255, 255, 255) },
	starGold = { material = M.Neon, color = rgb(255, 215, 140) },
	starTeal = { material = M.Neon, color = rgb(120, 230, 240) },
	fireNeon = { material = M.Neon, color = rgb(255, 110, 40) },
	fireGlass = { material = M.Glass, color = rgb(255, 120, 60), transparency = 0.45 },
	frostNeon = { material = M.Neon, color = rgb(150, 235, 245) },
	frostGlass = { material = M.Glass, color = rgb(120, 220, 230), transparency = 0.45 },
	stormNeon = { material = M.Neon, color = rgb(170, 90, 255) },
	stormGlass = { material = M.Glass, color = rgb(150, 90, 230), transparency = 0.45 },
	solarNeon = { material = M.Neon, color = rgb(255, 190, 70) },
	solarGlass = { material = M.Glass, color = rgb(255, 200, 90), transparency = 0.4 },
	cosmicNeon = { material = M.Neon, color = rgb(140, 110, 255) },
	cosmicGlass = { material = M.Glass, color = rgb(110, 90, 220), transparency = 0.4 },
	nebulaPurple = { material = M.Neon, color = rgb(110, 60, 200), transparency = 0.25 },
	nebulaGlass = { material = M.Glass, color = rgb(90, 70, 200), transparency = 0.5 },
} :: { [string]: Style }

local CYAN = rgb(80, 230, 255)

local function vec(p: DecorGeometry.Vec): Vector3
	return Vector3.new(p.x, p.y, p.z)
end

local function angles(r: DecorGeometry.Vec?): CFrame
	if not r then
		return CFrame.identity
	end
	return CFrame.Angles(math.rad(r.x), math.rad(r.y), math.rad(r.z))
end

local function applyStyle(p: BasePart, styleName: string)
	local s = VisualStyle.STYLES[styleName] or VisualStyle.STYLES.chrome
	p.Material = s.material
	p.Color = s.color
	p.Reflectance = s.reflectance or 0
	p.Transparency = s.transparency or 0
end

---------------------------------------------------------------- effects
local function particles(parent: BasePart, kind: string)
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 1
	e.Rate = 6
	e.Lifetime = NumberRange.new(1, 2)
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(0.12, 0)
	if kind == "embers" then
		e.Color = ColorSequence.new(rgb(255, 150, 60), rgb(255, 60, 20))
		e.EmissionDirection = Enum.NormalId.Top
		e.SpreadAngle = Vector2.new(25, 25)
		e.Speed = NumberRange.new(1, 3)
		e.Rate = 10
	elseif kind == "frost" then
		e.Color = ColorSequence.new(rgb(210, 250, 255))
		e.Size = NumberSequence.new(0.18, 0)
	elseif kind == "sparks" then
		e.Color = ColorSequence.new(rgb(200, 150, 255))
		e.Lifetime = NumberRange.new(0.15, 0.35)
		e.Speed = NumberRange.new(4, 8)
		e.Rate = 8
	elseif kind == "swirl" then
		e.Color = ColorSequence.new(rgb(255, 210, 120), CYAN)
		e.RotSpeed = NumberRange.new(90, 180)
		e.Shape = Enum.ParticleEmitterShape.Disc
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.Size = NumberSequence.new(0.25, 0)
		e.Rate = 14
	elseif kind == "stars" then
		e.Color = ColorSequence.new(rgb(255, 255, 255), rgb(170, 140, 255))
		e.Speed = NumberRange.new(0, 0.3)
		e.Size = NumberSequence.new(0.08, 0)
	elseif kind == "nebula" then
		e.Color = ColorSequence.new(rgb(150, 80, 255), rgb(255, 150, 70))
		e.Size = NumberSequence.new(0.6, 1.2)
		e.Transparency = NumberSequence.new(0.6, 1)
		e.Speed = NumberRange.new(0, 0.2)
		e.Rate = 3
		e.Lifetime = NumberRange.new(3, 5)
	end
	e.Parent = parent
end

local function addFx(p: BasePart, fx: string?, styleName: string)
	if not fx then
		return
	end
	if fx == "light" then
		local l = Instance.new("PointLight")
		l.Color = (VisualStyle.STYLES[styleName] or VisualStyle.STYLES.cyanNeon).color
		l.Brightness = 1.6
		l.Range = 14
		l.Shadows = false
		l.Parent = p
	else
		particles(p, fx)
	end
end

---------------------------------------------------------------- primitive -> Part
local function makePart(prim: DecorGeometry.Prim, parent: Instance): BasePart?
	local p: BasePart
	if prim.kind == "ball" then
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Ball
		local d = prim.d or 1
		part.Size = Vector3.new(d, d, d)
		part.CFrame = CFrame.new(vec(prim.p :: DecorGeometry.Vec))
		p = part
	elseif prim.kind == "rod" then
		local a, b = vec(prim.a :: DecorGeometry.Vec), vec(prim.b :: DecorGeometry.Vec)
		local len = (b - a).Magnitude
		if len < 1e-3 then
			return nil
		end
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Cylinder -- cylinder axis is local X
		local w = prim.w or 0.2
		part.Size = Vector3.new(len, w, w)
		local mid = (a + b) / 2
		local dir = (b - a).Unit
		if math.abs(dir.Y) > 0.999 then
			part.CFrame = CFrame.new(mid) * CFrame.Angles(0, 0, math.rad(90))
		else
			part.CFrame = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0)
		end
		p = part
	elseif prim.kind == "disc" then
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Cylinder
		local d = prim.d or 1
		part.Size = Vector3.new(prim.h or 0.2, d, d)
		part.CFrame = CFrame.new(vec(prim.p :: DecorGeometry.Vec))
			* angles(prim.rot)
			* CFrame.Angles(0, 0, math.rad(90))
		p = part
	elseif prim.kind == "wedge" then
		local part = Instance.new("WedgePart")
		part.Size = vec(prim.size :: DecorGeometry.Vec)
		part.CFrame = CFrame.new(vec(prim.p :: DecorGeometry.Vec)) * angles(prim.rot)
		p = part
	else
		local part = Instance.new("Part")
		part.Size = vec(prim.size :: DecorGeometry.Vec)
		part.CFrame = CFrame.new(vec(prim.p :: DecorGeometry.Vec)) * angles(prim.rot)
		p = part
	end
	p.Name = prim.name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	applyStyle(p, prim.style)
	addFx(p, prim.fx, prim.style)
	p.Parent = parent
	return p
end

---------------------------------------------------------------- lighting / sky
local function applyLighting()
	Lighting.ClockTime = 0 -- night sky: the engine draws stars; no sun in a space backdrop
	Lighting.Brightness = 1
	Lighting.Ambient = rgb(34, 38, 52)
	Lighting.OutdoorAmbient = rgb(28, 32, 46)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1 -- lets Metal / Foil gold and chrome reflect
	Lighting.ExposureCompensation = 0.25
	Lighting.FogEnd = 100000
	Lighting.FogColor = rgb(0, 0, 0)
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("Sky") or child:IsA("PostEffect") then
			child:Destroy()
		end
	end
	local sky = Instance.new("Sky")
	sky.Name = "GertechSpace"
	sky.CelestialBodiesShown = false
	sky.StarCount = 5000
	local faces = ImageAssets.sky()
	if faces then
		for face, uri in faces do
			(sky :: any)[face] = uri
		end
	end
	sky.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 1.1
	bloom.Size = 28
	bloom.Threshold = 0.92
	bloom.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Contrast = 0.12
	cc.Saturation = 0.08
	cc.TintColor = rgb(255, 250, 240)
	cc.Parent = Lighting
end

---------------------------------------------------------------- hub restyle (colors only)
local function each(root: Instance, name: string, fn: (BasePart) -> ())
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.Name == name then
			fn(d)
		end
	end
end

local function restyleHub(hub: Instance)
	each(hub, "Floor", function(p)
		p.Color = rgb(16, 18, 24)
		p.Reflectance = 0.08
	end)
	for _, w in { "WallN", "WallS", "WallE", "WallW" } do
		each(hub, w, function(p)
			p.Color = rgb(12, 14, 20)
			p.Material = M.Metal
			p.Reflectance = 0.18
		end)
	end
	-- Roof glass shows the black star field (Godot's undersea roof is kept as a part; only
	-- its tint changes in this provisional look, see README).
	each(hub, "SeaGlassRoof", function(p)
		p.Color = rgb(8, 12, 24)
		p.Transparency = 0.82
		p.Reflectance = 0.05
	end)
	each(hub, "Truss", function(p)
		applyStyle(p, "chrome")
		local sl = Instance.new("SurfaceLight")
		sl.Face = Enum.NormalId.Bottom
		sl.Color = rgb(255, 240, 220)
		sl.Brightness = 1.2
		sl.Range = 26
		sl.Angle = 120
		sl.Parent = p
	end)
	each(hub, "Plinth", function(p)
		applyStyle(p, "chrome")
	end)
	each(hub, "Pedestal", function(p)
		applyStyle(p, "chrome")
	end)
	each(hub, "Leg", function(p)
		applyStyle(p, "chrome")
	end)
	-- DNA wormhole helix: cyan strands, gold base pairs, gold pads, chrome base
	each(hub, "StrandA", function(p)
		p.Color = CYAN
	end)
	each(hub, "StrandB", function(p)
		p.Color = rgb(190, 245, 255)
	end)
	each(hub, "BasePair", function(p)
		p.Color = rgb(255, 205, 100)
	end)
	local helix = hub:FindFirstChild("DNAWormholeHelix")
	if helix then
		for _, d in helix:GetChildren() do
			if d:IsA("BasePart") and string.sub(d.Name, 1, 4) == "Pad_" then
				d.Color = rgb(255, 200, 90)
			elseif d:IsA("BasePart") and d.Name == "Base" then
				applyStyle(d, "chrome")
			elseif d:IsA("BasePart") and d.Name == "Aperture" then
				d.Color = CYAN
			end
		end
	end
end

---------------------------------------------------------------- energy beams in the helix (REF_04)
local function helixBeams(parent: Instance)
	local c = vec(DecorGeometry.LAYOUT.helix)
	local anchor = Instance.new("Part")
	anchor.Name = "BeamAnchor"
	anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(c)
	anchor.Parent = parent
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(math.cos(a) * 2, 2, math.sin(a) * 2)
		a0.Parent = anchor
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(math.cos(a + math.pi) * 2, 22, math.sin(a + math.pi) * 2)
		a1.Parent = anchor
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Color = ColorSequence.new(CYAN, rgb(200, 250, 255))
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Transparency = NumberSequence.new(0.35, 0.7)
		beam.Width0, beam.Width1 = 0.6, 0.25
		beam.CurveSize0, beam.CurveSize1 = 9, -9
		beam.Segments = 24
		beam.FaceCamera = true
		beam.Parent = anchor
	end
end

---------------------------------------------------------------- image slots (only when uploaded)
local function surfaceImage(part: BasePart, face: Enum.NormalId, uri: string, sheet: ImageAssets.Sheet?)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.LightInfluence = 0
	sg.Brightness = 1.5
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.ScaleType = Enum.ScaleType.Fit
	img.Image = uri
	if sheet then
		img.ImageRectSize = Vector2.new(sheet.frameW, sheet.frameH)
		img.ImageRectOffset = Vector2.zero
		img:SetAttribute("Cols", sheet.cols)
		img:SetAttribute("Frames", sheet.frames)
		img:SetAttribute("FrameW", sheet.frameW)
		img:SetAttribute("FrameH", sheet.frameH)
		img:SetAttribute("Fps", sheet.fps)
		CollectionService:AddTag(img, "GertechFlipbook")
	end
	img.Parent = sg
	sg.Parent = part
end

local function posterPart(parent: Instance, name: string, cf: CFrame, size: Vector3): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Size = size
	p.CFrame = cf
	applyStyle(p, "chrome")
	p.Color = rgb(10, 12, 18)
	p.Parent = parent
	return p
end

local function applyImages(decor: Instance, hub: Instance)
	-- Reference gallery on the south wall (posters only for uploaded images).
	local gallery = Instance.new("Model")
	gallery.Name = "ReferenceGallery"
	gallery.Parent = decor
	for i, key in ImageAssets.ORDER do
		local uri = ImageAssets.ref(key)
		if uri then
			local x = -71.5 + (i - 1) * 11
			-- Front face (-Z) looks into the hub from the south wall
			local p = posterPart(gallery, "Poster_" .. key, CFrame.new(x, 13, 63.7), Vector3.new(9, 9, 0.3))
			surfaceImage(p, Enum.NormalId.Front, uri, nil)
			local frameRing = posterPart(
				gallery,
				"PosterFrame_" .. key,
				CFrame.new(x, 13, 63.85),
				Vector3.new(9.6, 9.6, 0.2)
			)
			applyStyle(frameRing, "gold")
		end
	end
	-- Quantum table: REF_13 flipbook on the holo grid top, REF_12 flipbook on a holo screen.
	local qt = hub:FindFirstChild("QuantumTable")
	local holo = qt and qt:FindFirstChild("HoloGrid")
	local s13 = ImageAssets.SHEETS.REF_13
	local u13 = ImageAssets.uri(s13)
	if holo and holo:IsA("BasePart") and u13 then
		surfaceImage(holo, Enum.NormalId.Top, u13, s13)
	end
	local s12 = ImageAssets.SHEETS.REF_12
	local u12 = ImageAssets.uri(s12)
	if qt and u12 then
		local q = vec(DecorGeometry.LAYOUT.quantumTable)
		local screen = posterPart(
			qt,
			"GrowthHoloScreen",
			CFrame.new(q + Vector3.new(0, 4.6, -3.6)),
			Vector3.new(5, 5, 0.15)
		)
		screen.Transparency = 0.3
		surfaceImage(screen, Enum.NormalId.Back, u12, s12) -- faces +Z, toward the table front
	end
	-- REF_14 on the triangle module faces (Texture spans both wedge halves; verify in Studio).
	local u14 = ImageAssets.ref("REF_14")
	local tri = decor:FindFirstChild("NebulaTriangleModule")
	if u14 and tri then
		local side = 6
		local h = side * math.sqrt(3) / 2
		for _, name in { "NebulaFaceL", "NebulaFaceR" } do
			local w = tri:FindFirstChild(name)
			if w and w:IsA("BasePart") then
				for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
					local t = Instance.new("Texture")
					t.Texture = u14
					t.Face = face
					t.StudsPerTileU = side
					t.StudsPerTileV = h
					t.OffsetStudsU = if (name == "NebulaFaceL") == (face == Enum.NormalId.Left)
						then 0
						else side / 2
					t.Parent = w
				end
				w.Transparency = 0
			end
		end
	end
end

---------------------------------------------------------------- entry point
function VisualStyle.apply(hub: Instance): Model?
	if Config.VISUAL_STYLE ~= "refs_2026_11_14" then
		return nil
	end
	applyLighting()
	restyleHub(hub)
	local decor = Instance.new("Model")
	decor.Name = "LookPass_Refs_2026_11_14"
	local scene = DecorGeometry.build()
	local models: { [string]: Model } = {}
	for name, g in scene.groups do
		local m = Instance.new("Model")
		m.Name = name
		m:SetAttribute("Reference", g.ref or "shared")
		m.Parent = decor
		models[name] = m
	end
	for _, prim in scene.prims do
		local m = models[prim.group]
		if not m then
			local extra = Instance.new("Model")
			extra.Name = prim.group
			extra.Parent = decor
			models[prim.group] = extra
			m = extra
		end
		makePart(prim, m)
	end
	for name, g in scene.groups do
		local m = models[name]
		m.WorldPivot = CFrame.new(vec(g.pivot))
		if g.spin and g.spin > 0 then
			m:SetAttribute("SpinRPM", g.spin)
			CollectionService:AddTag(m, "GertechSpin")
		end
		if g.highlight then
			local hl = Instance.new("Highlight")
			hl.FillTransparency = 1
			hl.OutlineColor = (VisualStyle.STYLES[g.highlight] or VisualStyle.STYLES.cyanNeon).color
			hl.OutlineTransparency = 0.25
			hl.DepthMode = Enum.HighlightDepthMode.Occluded
			hl.Parent = m
		end
	end
	helixBeams(decor)
	decor.Parent = hub
	applyImages(decor, hub)
	local missing = ImageAssets.missing()
	if #missing > 0 then
		print(
			string.format(
				"[GERTECH] look pass: %d image slots empty (procedural fallback in use): %s",
				#missing,
				table.concat(missing, ", ")
			)
		)
	end
	return decor
end

return VisualStyle
