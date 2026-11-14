--!strict
-- Client-only motion for the provisional look pass (no gameplay): slow spins of decor models
-- tagged "GertechSpin" (attribute SpinRPM) and sprite-sheet flipbooks on ImageLabels tagged
-- "GertechFlipbook" (REF_12 / REF_13, only exist once their asset ids are uploaded).
-- Throttled to 30 Hz and to models near the camera to keep it cheap.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local DecorFx = {}

local SPIN_RANGE = 140 -- studs from the camera
local STEP = 1 / 30

type Spinner = { model: Model, base: CFrame, rpm: number }

function DecorFx.start()
	local spinners: { [Instance]: Spinner } = {}
	local function addSpin(inst: Instance)
		if inst:IsA("Model") then
			local rpm = tonumber(inst:GetAttribute("SpinRPM")) or 0
			if rpm > 0 then
				spinners[inst] = { model = inst, base = inst:GetPivot(), rpm = rpm }
			end
		end
	end
	for _, inst in CollectionService:GetTagged("GertechSpin") do
		addSpin(inst)
	end
	CollectionService:GetInstanceAddedSignal("GertechSpin"):Connect(addSpin)
	CollectionService:GetInstanceRemovedSignal("GertechSpin"):Connect(function(inst)
		spinners[inst] = nil
	end)

	local acc, clock = 0, 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		clock += dt
		if acc < STEP then
			return
		end
		acc = 0
		local cam = workspace.CurrentCamera
		local camPos = if cam then cam.CFrame.Position else Vector3.zero
		for inst, s in spinners do
			if not inst.Parent then
				spinners[inst] = nil
			elseif (s.base.Position - camPos).Magnitude < SPIN_RANGE then
				local angle = clock * s.rpm / 60 * math.pi * 2
				s.model:PivotTo(s.base * CFrame.Angles(0, angle, 0))
			end
		end
		for _, img in CollectionService:GetTagged("GertechFlipbook") do
			if img:IsA("ImageLabel") then
				local frames = tonumber(img:GetAttribute("Frames")) or 1
				local cols = tonumber(img:GetAttribute("Cols")) or 1
				local fw = tonumber(img:GetAttribute("FrameW")) or 0
				local fh = tonumber(img:GetAttribute("FrameH")) or 0
				local fps = tonumber(img:GetAttribute("Fps")) or 6
				local i = math.floor(clock * fps) % frames
				img.ImageRectOffset = Vector2.new((i % cols) * fw, math.floor(i / cols) * fh)
			end
		end
	end)
end

return DecorFx
