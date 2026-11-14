--!strict
-- GERTECH client: shared inventory panel, TETRAFORGE crafting UI, stock exchange, XP bar,
-- notifications. The client only DISPLAYS state and SENDS requests; the server decides.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemDefs = require(Shared:WaitForChild("ItemDefs"))
local RecipeDefs = require(Shared:WaitForChild("RecipeDefs"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Widgets = require(script.Parent:WaitForChild("UI"):WaitForChild("Widgets"))
local ForgeView = require(script.Parent:WaitForChild("UI"):WaitForChild("ForgeView"))

local T = Widgets.Theme
local player = Players.LocalPlayer

local state = {
	inventory = {} :: { [string]: number },
	equipment = {} :: { [string]: number },
	foundryRuns = 0,
	workshopId = "",
	level = 1,
	xp = 0,
	levelXp = 0,
	nextLevelXp = 100,
}

local gui = Widgets.new("ScreenGui", {
	Name = "GERTECH_UI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

---------------------------------------------------------------- XP bar
local xpPanel = Widgets.panel(gui, "XP", UDim2.fromOffset(260, 54), UDim2.fromOffset(12, 12))
local xpLabel = Widgets.text(
	xpPanel,
	"Level 1",
	UDim2.new(1, -16, 0, 22),
	UDim2.fromOffset(8, 4),
	{ Font = Enum.Font.GothamBold }
)
local xpBack = Widgets.new("Frame", {
	Size = UDim2.new(1, -16, 0, 12),
	Position = UDim2.fromOffset(8, 32),
	BackgroundColor3 = T.bg,
	BorderSizePixel = 0,
	Parent = xpPanel,
})
Widgets.corner(xpBack, 6)
local xpFill = Widgets.new(
	"Frame",
	{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.accent, BorderSizePixel = 0, Parent = xpBack }
)
Widgets.corner(xpFill, 6)

---------------------------------------------------------------- Inventory panel
local invPanel =
	Widgets.panel(gui, "Inventory", UDim2.fromOffset(250, 380), UDim2.new(1, -12, 0, 12), Vector2.new(1, 0))
Widgets.text(
	invPanel,
	"<b>SHARED WORKSHOP STOCK</b>",
	UDim2.new(1, -16, 0, 22),
	UDim2.fromOffset(8, 6),
	{ TextColor3 = T.accent }
)
local invSub = Widgets.text(
	invPanel,
	"",
	UDim2.new(1, -16, 0, 16),
	UDim2.fromOffset(8, 28),
	{ TextSize = 12, TextColor3 = T.dim }
)
local invList = Widgets.new("Frame", {
	Size = UDim2.new(1, -16, 1, -56),
	Position = UDim2.fromOffset(8, 50),
	BackgroundTransparency = 1,
	Parent = invPanel,
})
Widgets.new(
	"UIListLayout",
	{ Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = invList }
)
local invRows: { [string]: TextLabel } = {}
for i, id in ItemDefs.ORDER do
	local def = ItemDefs.get(id) :: ItemDefs.ItemDef
	local row = Widgets.text(invList, "", UDim2.new(1, 0, 0, 20), UDim2.new(), { TextSize = 15 })
	row.LayoutOrder = i
	row.TextColor3 = def.color:Lerp(Color3.new(1, 1, 1), 0.35)
	invRows[id] = row
end
local equipRow =
	Widgets.text(invList, "", UDim2.new(1, 0, 0, 20), UDim2.new(), { TextSize = 15, TextColor3 = T.good })
equipRow.LayoutOrder = 100
local toggleInv =
	Widgets.button(gui, "Stock [I]", UDim2.fromOffset(90, 28), UDim2.new(1, -12, 0, 398), T.accent)
toggleInv.AnchorPoint = Vector2.new(1, 0)

local function renderInventory()
	for _, id in ItemDefs.ORDER do
		local def = ItemDefs.get(id) :: ItemDefs.ItemDef
		invRows[id].Text = string.format("%s  <b>%d</b>", def.name, state.inventory[id] or 0)
	end
	equipRow.Text = string.format("Visor chip capacity  <b>%d</b>", state.equipment.visor_chip_capacity or 1)
	invSub.Text = string.format("%s · forge runs %d", state.workshopId, state.foundryRuns)
end

---------------------------------------------------------------- TETRAFORGE
local forgeView = ForgeView.new(gui)

local function fmtMap(map: { [string]: number }, mult: number): string
	local parts = {}
	for _, id in ItemDefs.ORDER do
		local n = map[id]
		if n then
			table.insert(parts, (n * mult) .. " " .. (ItemDefs.get(id) :: ItemDefs.ItemDef).name)
		end
	end
	return table.concat(parts, " + ")
end

---------------------------------------------------------------- Exchange panel
local exPanel = Widgets.panel(
	gui,
	"Exchange",
	UDim2.fromOffset(360, 170),
	UDim2.fromScale(0.5, 0.5),
	Vector2.new(0.5, 0.5)
)
exPanel.Visible = false
Widgets.text(
	exPanel,
	"<b>STOCK EXCHANGE</b>",
	UDim2.new(1, -60, 0, 26),
	UDim2.fromOffset(14, 8),
	{ TextSize = 20, TextColor3 = T.accent }
)
local closeEx = Widgets.button(exPanel, "X", UDim2.fromOffset(30, 30), UDim2.new(1, -40, 0, 10), T.bad)
local up = RecipeDefs.VISOR_CHIP_UPGRADE
Widgets.text(
	exPanel,
	up.name .. "\nCost: " .. fmtMap(up.cost, 1) .. "\nAdds +1 to the workshop's Mouse Maze visor chips.",
	UDim2.new(1, -28, 0, 60),
	UDim2.fromOffset(14, 40),
	{ TextSize = 14 }
)
local buyBtn = Widgets.button(exPanel, "BUILD UPGRADE", UDim2.fromOffset(170, 34), UDim2.fromOffset(14, 120))
buyBtn.MouseButton1Click:Connect(function()
	Remotes.event("BuyUpgrade"):FireServer(up.id)
end)
closeEx.MouseButton1Click:Connect(function()
	exPanel.Visible = false
end)

---------------------------------------------------------------- Notifications
local toastHolder = Widgets.new("Frame", {
	Size = UDim2.fromOffset(460, 300),
	Position = UDim2.new(0.5, 0, 1, -20),
	AnchorPoint = Vector2.new(0.5, 1),
	BackgroundTransparency = 1,
	Parent = gui,
})
Widgets.new("UIListLayout", {
	Padding = UDim.new(0, 4),
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = toastHolder,
})
local toastOrder = 0
local function toast(text: string, kind: string?)
	toastOrder += 1
	local f = Widgets.panel(toastHolder, "Toast", UDim2.new(1, 0, 0, 40), UDim2.new())
	f.LayoutOrder = toastOrder
	local color = if kind == "good" then T.good elseif kind == "bad" then T.bad else T.text
	Widgets.text(
		f,
		text,
		UDim2.new(1, -16, 1, 0),
		UDim2.fromOffset(8, 0),
		{ TextSize = 14, TextColor3 = color }
	)
	task.delay(5, function()
		f:Destroy()
	end)
end

---------------------------------------------------------------- Remotes
local function applyWorkshop(payload: any)
	if type(payload) ~= "table" then
		return
	end
	state.inventory = payload.inventory or state.inventory
	state.equipment = payload.equipment or state.equipment
	state.foundryRuns = payload.foundryRuns or state.foundryRuns
	state.workshopId = payload.workshopId or state.workshopId
	renderInventory()
end

Remotes.event("InventoryUpdated").OnClientEvent:Connect(applyWorkshop)
Remotes.event("ProgressionUpdated").OnClientEvent:Connect(function(p: any)
	state.level, state.xp = p.level, p.xp
	state.levelXp, state.nextLevelXp = p.levelXp, p.nextLevelXp
	xpLabel.Text = string.format("Level %d  ·  %d XP", state.level, state.xp)
	local span = math.max(1, state.nextLevelXp - state.levelXp)
	xpFill.Size = UDim2.fromScale(math.clamp((state.xp - state.levelXp) / span, 0, 1), 1)
end)
Remotes.event("OpenForge").OnClientEvent:Connect(function(info: any)
	exPanel.Visible = false
	forgeView.open(info)
end)
Remotes.event("ForgeBoard").OnClientEvent:Connect(function(s: any, role: string)
	forgeView.apply(s, role)
end)
Remotes.event("OpenExchange").OnClientEvent:Connect(function()
	forgeView.close()
	exPanel.Visible = true
end)
Remotes.event("Notify").OnClientEvent:Connect(function(text: string, kind: string?)
	toast(text, kind)
end)

toggleInv.MouseButton1Click:Connect(function()
	invPanel.Visible = not invPanel.Visible
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.I then
		invPanel.Visible = not invPanel.Visible
	elseif input.KeyCode == Enum.KeyCode.Escape then
		if not forgeView.isOpen() then
			exPanel.Visible = false
		end
	end
end)

local ok, snap = pcall(function()
	return Remotes.func("GetSnapshot"):InvokeServer()
end)
if ok and type(snap) == "table" then
	applyWorkshop(snap.workshop)
end
renderInventory()
