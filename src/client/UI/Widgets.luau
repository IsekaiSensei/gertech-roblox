--!strict
-- Tiny UI helpers so the client can build its ScreenGui in code (no .rbxm assets).

local Widgets = {}

Widgets.Theme = {
	bg = Color3.fromRGB(14, 22, 32),
	panel = Color3.fromRGB(22, 34, 48),
	accent = Color3.fromRGB(60, 200, 255),
	forge = Color3.fromRGB(255, 160, 70),
	text = Color3.fromRGB(225, 240, 250),
	dim = Color3.fromRGB(140, 160, 175),
	good = Color3.fromRGB(110, 230, 140),
	bad = Color3.fromRGB(255, 110, 110),
}

function Widgets.new(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function Widgets.corner(parent: Instance, radius: number?)
	Widgets.new("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

function Widgets.panel(parent: Instance, name: string, size: UDim2, pos: UDim2, anchor: Vector2?): Frame
	local f = Widgets.new("Frame", {
		Name = name,
		Size = size,
		Position = pos,
		AnchorPoint = anchor or Vector2.zero,
		BackgroundColor3 = Widgets.Theme.panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Parent = parent,
	})
	Widgets.corner(f, 10)
	Widgets.new("UIStroke", { Color = Widgets.Theme.accent, Transparency = 0.6, Thickness = 1, Parent = f })
	return f
end

function Widgets.text(
	parent: Instance,
	text: string,
	size: UDim2,
	pos: UDim2,
	opts: { [string]: any }?
): TextLabel
	local o: { [string]: any } = opts or {}
	return Widgets.new("TextLabel", {
		Text = text,
		Size = size,
		Position = pos,
		BackgroundTransparency = 1,
		Font = o.Font or Enum.Font.Gotham,
		TextSize = o.TextSize or 16,
		TextColor3 = o.TextColor3 or Widgets.Theme.text,
		TextXAlignment = o.TextXAlignment or Enum.TextXAlignment.Left,
		TextWrapped = true,
		RichText = true,
		Parent = parent,
	})
end

function Widgets.button(parent: Instance, text: string, size: UDim2, pos: UDim2, color: Color3?): TextButton
	local b = Widgets.new("TextButton", {
		Text = text,
		Size = size,
		Position = pos,
		BackgroundColor3 = color or Widgets.Theme.accent,
		TextColor3 = Color3.fromRGB(10, 15, 20),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		AutoButtonColor = true,
		BorderSizePixel = 0,
		Parent = parent,
	})
	Widgets.corner(b, 6)
	return b
end

return Widgets
