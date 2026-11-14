--!strict
-- TETRAFORGE client view: renders server snapshots of the 10x20 chamber in a ScreenGui,
-- interpolates the falling piece, and sends INPUT INTENTS only (the server simulates).

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemDefs = require(Shared:WaitForChild("ItemDefs"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local TetrominoGrid = require(Shared:WaitForChild("TetrominoGrid"))
local Widgets = require(script.Parent:WaitForChild("Widgets"))

local T = Widgets.Theme
local W, H = TetrominoGrid.WIDTH, TetrominoGrid.HEIGHT
local CELL = 22
local ACTION = "GERTECH_TetraforgeControls"
local REPEAT_DELAY, REPEAT_RATE = 0.17, 0.06

local CODE_COLORS: { [string]: Color3 } = {
	o = (ItemDefs.get("ore") :: ItemDefs.ItemDef).color,
	s = (ItemDefs.get("salvage") :: ItemDefs.ItemDef).color,
	p = (ItemDefs.get("pure_component") :: ItemDefs.ItemDef).color,
}
local EMPTY = Color3.fromRGB(12, 26, 36)

local ForgeView = {}

function ForgeView.new(gui: ScreenGui)
	local mode = "idle" -- idle | operator | watch
	local snap: any = nil
	local lastBoard = ""
	local softHeld = false
	local paused = false
	local repeatKey: Enum.KeyCode? = nil
	local repeatIntent = ""
	local repeatAt = 0

	local panel = Widgets.panel(
		gui,
		"Tetraforge",
		UDim2.fromOffset(660, 560),
		UDim2.fromScale(0.5, 0.5),
		Vector2.new(0.5, 0.5)
	)
	panel.Visible = false
	Widgets.text(
		panel,
		"<b>TETRAFORGE</b>  ·  forge foundry",
		UDim2.new(1, -60, 0, 28),
		UDim2.fromOffset(14, 8),
		{ TextSize = 22, TextColor3 = T.forge }
	)
	local subtitle = Widgets.text(
		panel,
		"",
		UDim2.new(1, -60, 0, 18),
		UDim2.fromOffset(14, 36),
		{ TextSize = 13, TextColor3 = T.dim }
	)
	local closeBtn = Widgets.button(panel, "X", UDim2.fromOffset(30, 30), UDim2.new(1, -40, 0, 10), T.bad)

	-- Left column: hoppers, score, heat, rows, status
	local left =
		Widgets.text(panel, "", UDim2.fromOffset(180, 250), UDim2.fromOffset(14, 64), { TextSize = 15 })
	left.TextYAlignment = Enum.TextYAlignment.Top
	Widgets.text(
		panel,
		"HEAT",
		UDim2.fromOffset(60, 18),
		UDim2.fromOffset(14, 320),
		{ TextSize = 13, TextColor3 = T.dim }
	)
	local heatBack = Widgets.new("Frame", {
		Size = UDim2.fromOffset(170, 12),
		Position = UDim2.fromOffset(14, 340),
		BackgroundColor3 = T.bg,
		BorderSizePixel = 0,
		Parent = panel,
	})
	local heatFill = Widgets.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromHex("e8a65a"),
		BorderSizePixel = 0,
		Parent = heatBack,
	})
	local statusLabel = Widgets.text(
		panel,
		"",
		UDim2.fromOffset(180, 80),
		UDim2.fromOffset(14, 362),
		{ TextSize = 13, TextColor3 = T.accent }
	)
	statusLabel.TextYAlignment = Enum.TextYAlignment.Top

	-- Board
	local boardFrame = Widgets.new("Frame", {
		Size = UDim2.fromOffset(W * CELL + 4, H * CELL + 4),
		Position = UDim2.fromOffset(204, 60),
		BackgroundColor3 = Color3.fromRGB(5, 12, 18),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = panel,
	})
	Widgets.new("UIStroke", { Color = Color3.fromHex("b9a06d"), Thickness = 2, Parent = boardFrame })
	local cells: { Frame } = {}
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			cells[y * W + x + 1] = Widgets.new("Frame", {
				Size = UDim2.fromOffset(CELL - 2, CELL - 2),
				Position = UDim2.fromOffset(2 + x * CELL + 1, 2 + y * CELL + 1),
				BackgroundColor3 = EMPTY,
				BorderSizePixel = 0,
				Parent = boardFrame,
			})
		end
	end
	-- Active piece overlay (interpolated)
	local pieceFrame = Widgets.new(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = boardFrame }
	)
	local pieceCells: { Frame } = {}
	for i = 1, 4 do
		local f = Widgets.new("Frame", {
			Size = UDim2.fromOffset(CELL - 2, CELL - 2),
			BorderSizePixel = 0,
			ZIndex = 3,
			Visible = false,
			Parent = pieceFrame,
		})
		Widgets.new(
			"UIStroke",
			{ Color = Color3.new(1, 1, 1), Transparency = 0.5, Thickness = 1, Parent = f }
		)
		pieceCells[i] = f
	end
	local overlay = Widgets.text(
		boardFrame,
		"",
		UDim2.fromScale(1, 1),
		UDim2.new(),
		{ TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold }
	)
	overlay.ZIndex = 5
	overlay.BackgroundTransparency = 1

	-- Right column: next, hold, outputs, buttons
	local rightX = 204 + W * CELL + 22
	local function miniBox(title: string, y: number): Frame
		Widgets.text(
			panel,
			title,
			UDim2.fromOffset(120, 18),
			UDim2.fromOffset(rightX, y),
			{ TextSize = 13, TextColor3 = T.dim }
		)
		local box = Widgets.new("Frame", {
			Size = UDim2.fromOffset(96, 52),
			Position = UDim2.fromOffset(rightX, y + 20),
			BackgroundColor3 = Color3.fromRGB(5, 12, 18),
			BorderSizePixel = 0,
			Parent = panel,
		})
		for i = 1, 4 do
			Widgets.new("Frame", {
				Name = "C" .. i,
				Size = UDim2.fromOffset(15, 15),
				BackgroundColor3 = T.accent,
				BorderSizePixel = 0,
				Visible = false,
				Parent = box,
			})
		end
		return box
	end
	local nextBox = miniBox("NEXT", 60)
	local holdBox = miniBox("HOLD  [C]", 140)
	local outputs =
		Widgets.text(panel, "", UDim2.fromOffset(170, 110), UDim2.fromOffset(rightX, 220), { TextSize = 14 })
	outputs.TextYAlignment = Enum.TextYAlignment.Top
	local startBtn =
		Widgets.button(panel, "START RUN", UDim2.fromOffset(170, 38), UDim2.fromOffset(rightX, 340), T.forge)
	local endBtn = Widgets.button(
		panel,
		"END RUN  [Backspace]",
		UDim2.fromOffset(170, 30),
		UDim2.fromOffset(rightX, 340),
		T.bad
	)
	local help = Widgets.text(
		panel,
		"A/D or ←/→ move · W/↑/X rotate\nS/↓ soft drop · Space hard drop\nC hold · P pause · Backspace end run",
		UDim2.fromOffset(190, 60),
		UDim2.fromOffset(rightX, 384),
		{ TextSize = 12, TextColor3 = T.dim }
	)
	help.TextYAlignment = Enum.TextYAlignment.Top
	-- Touch / mouse buttons
	local touchRow = Widgets.new("Frame", {
		Size = UDim2.new(1, -28, 0, 40),
		Position = UDim2.new(0, 14, 1, -50),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	Widgets.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = touchRow,
	})

	local function send(intent: string)
		if mode == "operator" then
			Remotes.event("ForgeInput"):FireServer(intent)
		end
	end

	local touchButtons: { TextButton } = {}
	for _, def in
		{
			{ "◀", "left" },
			{ "▶", "right" },
			{ "⟳", "rotate" },
			{ "▼", "soft" },
			{ "⤓", "hard" },
			{ "HOLD", "hold" },
			{ "⏸", "pause" },
		}
	do
		local b = Widgets.button(touchRow, def[1], UDim2.fromOffset(70, 36), UDim2.new(), T.accent)
		local intent = def[2]
		if intent == "soft" then
			b.MouseButton1Down:Connect(function()
				send("soft_on")
			end)
			b.MouseButton1Up:Connect(function()
				send("soft_off")
			end)
		elseif intent == "pause" then
			b.MouseButton1Click:Connect(function()
				send(if paused then "resume" else "pause")
			end)
		else
			b.MouseButton1Click:Connect(function()
				send(intent)
			end)
		end
		table.insert(touchButtons, b)
	end

	---------------------------------------------------------------- rendering
	local function drawMini(box: Frame, shape: string?, color: Color3)
		local offsets = if shape and shape ~= "" then TetrominoGrid.rotated(shape, 0) else {}
		for i = 1, 4 do
			local c = box:FindFirstChild("C" .. i) :: Frame
			local p = offsets[i]
			c.Visible = p ~= nil
			if p then
				c.Position = UDim2.fromOffset(32 + p.x * 16, 10 + p.y * 16)
				c.BackgroundColor3 = color
			end
		end
	end

	local displayX, displayY = 0, 0
	local targetX, targetY = 0, 0
	local pieceKey = ""
	local pieceOffsets: { { x: number, y: number } } = {}

	local function applyPiece(piece: any)
		if not piece then
			for _, f in pieceCells do
				f.Visible = false
			end
			pieceKey = ""
			return
		end
		-- Offsets relative to the origin, from the server's own cell list
		pieceOffsets = {}
		for i = 1, 4 do
			local cx, cy = piece.cells[i * 2 - 1], piece.cells[i * 2]
			pieceOffsets[i] = { x = cx - piece.x, y = cy - piece.y }
			local code = string.sub(piece.m, i, i)
			pieceCells[i].BackgroundColor3 = CODE_COLORS[code] or Color3.new(1, 1, 1)
		end
		local key = piece.shape .. ":" .. piece.r .. ":" .. piece.m
		targetX, targetY = piece.x, piece.y
		-- Snap on a new piece / rotation or when the piece moved up (respawn)
		if key ~= pieceKey or targetY < displayY - 0.5 then
			displayX, displayY = targetX, targetY
		end
		pieceKey = key
	end

	local function renderPiece()
		if pieceKey == "" then
			return
		end
		for i, o in pieceOffsets do
			local px, py = displayX + o.x, displayY + o.y
			local f = pieceCells[i]
			f.Visible = py > -1
			f.Position = UDim2.fromOffset(2 + px * CELL + 1, 2 + py * CELL + 1)
		end
	end

	local function fmtHopper(name: string, key: string): string
		local spent = snap and snap.spent and snap.spent[key] or 0
		local budget = snap and snap.budget and snap.budget[key] or 0
		local hopper = snap and snap.hopper and snap.hopper[key] or 0
		return string.format("%s  <b>%d / %d</b>  (hopper %d)", name, spent, budget, hopper)
	end

	local function renderAll()
		local isOp = mode == "operator"
		startBtn.Visible = mode == "idle" or (snap ~= nil and snap.finished)
		endBtn.Visible = isOp and snap ~= nil and not snap.finished
		for _, b in touchButtons do
			b.Visible = isOp
		end
		if mode == "idle" and (not snap or snap.finished) then
			subtitle.Text =
				"Chamber free. A run draws on the whole shared workshop stock; only a small feed hopper is held out at a time."
		elseif mode == "watch" then
			subtitle.Text = "Watching " .. (snap and snap.operatorName or "the forge") .. " — read-only."
		elseif isOp then
			subtitle.Text =
				"You are operating the chamber. Unspent feed returns to the workshop when the run ends."
		end
		if not snap then
			left.Text = "INPUT HOPPERS\n\nwaiting for feed…"
			outputs.Text = ""
			statusLabel.Text = ""
			overlay.Text = ""
			heatFill.Size = UDim2.fromScale(0, 1)
			return
		end
		left.Text = string.format(
			"<b>INPUT HOPPERS</b>  used / available\n%s\n%s\n%s\n\nSCORE  <b>%06d</b>\nROWS  <b>%d / %d</b>",
			fmtHopper("ORE", "ore"),
			fmtHopper("SALVAGE", "salvage"),
			fmtHopper("PURE", "pure_component"),
			snap.score,
			snap.lines,
			snap.target
		)
		heatFill.Size = UDim2.fromScale(math.clamp(snap.heat, 0, 1), 1)
		statusLabel.Text = snap.status
		local prod = snap.produced or {}
		outputs.Text = string.format(
			"<b>OUTPUT</b>\nPACKED BLOCKS  %d\nSALVAGE FRAMES  %d\nFORGED BLANKS  %d%s",
			prod.packed_block or 0,
			prod.stabilized_frame or 0,
			prod.forged_blank or 0,
			if snap.finished then string.format("\nSCRAP  %d", prod.scrap or 0) else ""
		)
		overlay.Text = if snap.finished then snap.status elseif snap.paused then "PAUSED" else ""
		paused = snap.paused
		drawMini(nextBox, snap.nextShape, T.accent)
		drawMini(holdBox, snap.heldShape, if snap.canHold then T.forge else T.dim)
		if snap.board ~= lastBoard then
			for i = 1, W * H do
				local c = string.sub(snap.board, i, i)
				if c ~= string.sub(lastBoard, i, i) then
					cells[i].BackgroundColor3 = CODE_COLORS[c] or EMPTY
				end
			end
			lastBoard = snap.board
		end
		applyPiece(if snap.finished then nil else snap.piece)
	end

	---------------------------------------------------------------- input
	local function bindControls(on: boolean)
		ContextActionService:UnbindAction(ACTION)
		repeatKey = nil
		if not on then
			if softHeld then
				softHeld = false
				send("soft_off")
			end
			return
		end
		ContextActionService:BindActionAtPriority(
			ACTION,
			function(_, state, input)
				if mode ~= "operator" then
					return Enum.ContextActionResult.Pass
				end
				local key = input.KeyCode
				local began = state == Enum.UserInputState.Begin
				local ended = state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel
				if
					key == Enum.KeyCode.A
					or key == Enum.KeyCode.Left
					or key == Enum.KeyCode.D
					or key == Enum.KeyCode.Right
				then
					local intent = if key == Enum.KeyCode.A or key == Enum.KeyCode.Left
						then "left"
						else "right"
					if began then
						send(intent)
						repeatKey, repeatIntent, repeatAt = key, intent, os.clock() + REPEAT_DELAY
					elseif ended and repeatKey == key then
						repeatKey = nil
					end
				elseif key == Enum.KeyCode.W or key == Enum.KeyCode.Up or key == Enum.KeyCode.X then
					if began then
						send("rotate")
					end
				elseif key == Enum.KeyCode.S or key == Enum.KeyCode.Down then
					if began then
						softHeld = true
						send("soft_on")
					elseif ended then
						softHeld = false
						send("soft_off")
					end
				elseif key == Enum.KeyCode.Space then
					if began then
						send("hard")
					end
				elseif key == Enum.KeyCode.C then
					if began then
						send("hold")
					end
				elseif key == Enum.KeyCode.P then
					if began then
						send(if paused then "resume" else "pause")
					end
				elseif key == Enum.KeyCode.Backspace then
					if began then
						send("end")
					end
				end
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.A,
			Enum.KeyCode.D,
			Enum.KeyCode.Left,
			Enum.KeyCode.Right,
			Enum.KeyCode.W,
			Enum.KeyCode.Up,
			Enum.KeyCode.X,
			Enum.KeyCode.S,
			Enum.KeyCode.Down,
			Enum.KeyCode.Space,
			Enum.KeyCode.C,
			Enum.KeyCode.P,
			Enum.KeyCode.Backspace
		)
	end

	RunService.RenderStepped:Connect(function(dt)
		if not panel.Visible then
			return
		end
		local a = 1 - math.exp(-dt * 25)
		displayX += (targetX - displayX) * a
		displayY += (targetY - displayY) * a
		renderPiece()
		if repeatKey and os.clock() >= repeatAt then
			send(repeatIntent)
			repeatAt = os.clock() + REPEAT_RATE
		end
	end)

	startBtn.MouseButton1Click:Connect(function()
		Remotes.event("ForgeStart"):FireServer()
	end)
	endBtn.MouseButton1Click:Connect(function()
		send("end")
	end)

	local view = {}

	local function setMode(m: string)
		mode = m
		bindControls(panel.Visible and mode == "operator")
		renderAll()
	end

	function view.close()
		if mode == "watch" then
			Remotes.event("ForgeWatch"):FireServer(false)
		end
		panel.Visible = false
		bindControls(false)
	end
	closeBtn.MouseButton1Click:Connect(view.close)

	function view.open(info: any)
		panel.Visible = true
		snap = nil
		lastBoard = ""
		for _, c in cells do
			c.BackgroundColor3 = EMPTY
		end
		setMode(if type(info) == "table" and type(info.mode) == "string" then info.mode else "idle")
	end

	function view.apply(s: any, role: string)
		if type(s) ~= "table" then
			return
		end
		if role == "operator" then
			if mode ~= "operator" and panel.Visible then
				snap = s
				setMode("operator")
			end
			if s.finished then
				-- Run over: drop back to idle so the operator can start another.
				snap = s
				mode = "idle"
				bindControls(false)
			end
		elseif role == "watcher" and mode == "idle" and not s.finished then
			mode = "watch"
		end
		snap = s
		renderAll()
	end

	function view.isOpen(): boolean
		return panel.Visible
	end

	return view
end

return ForgeView
