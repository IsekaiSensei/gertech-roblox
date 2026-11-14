--!strict
-- Resource nodes: hold the ProximityPrompt to gather raw feed into the SHARED inventory.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local ItemDefs = require(Shared.ItemDefs)
local ProgressionDefs = require(Shared.ProgressionDefs)
local Remotes = require(Shared.Remotes)
local ResourceNodeDefs = require(Shared.ResourceNodeDefs)
local DataService = require(script.Parent.DataService)
local Inventory = require(script.Parent.WorkshopInventoryService)
local RateLimiter = require(script.Parent.RateLimiter)

local GatherService = {}

local limiter = RateLimiter.new(3, 1)

local function setCharges(node: BasePart, charges: number, max: number)
	node:SetAttribute("Charges", charges)
	node.Transparency = if charges <= 0 then 0.7 else 0
	local gui = node:FindFirstChild("ChargeGui")
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = string.format("%d / %d", charges, max)
	end
end

function GatherService.bindNode(node: BasePart, prompt: ProximityPrompt, nodeTypeId: string)
	local def = ResourceNodeDefs.Defs[nodeTypeId]
	assert(def, "unknown node type " .. nodeTypeId)
	setCharges(node, def.charges, def.charges)
	prompt.HoldDuration = def.holdSeconds
	prompt.ActionText = "Gather"
	prompt.ObjectText = def.name

	prompt.Triggered:Connect(function(player: Player)
		if not limiter:allow(player) or not DataService.get(player) then
			return
		end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		if (root.Position - node.Position).Magnitude > Config.GATHER_MAX_DISTANCE then
			return
		end
		local charges = node:GetAttribute("Charges") :: number? or 0
		if charges <= 0 then
			Remotes.event("Notify"):FireClient(player, def.name .. " is depleted. It regrows soon.", "bad")
			return
		end
		setCharges(node, charges - 1, def.charges)
		Inventory.add(def.yield, "gather:" .. player.UserId)
		DataService.addXp(player, ProgressionDefs.XP_PER_GATHER)
		DataService.addStat(player, "gathered", 1)
		local parts = {}
		for k, n in def.yield do
			table.insert(parts, "+" .. n .. " " .. (ItemDefs.get(k) :: any).name)
		end
		Remotes.event("Notify"):FireClient(player, table.concat(parts, "  "), "good")
	end)

	task.spawn(function()
		while node.Parent do
			task.wait(def.regenSeconds)
			local c = node:GetAttribute("Charges") :: number? or 0
			if c < def.charges then
				setCharges(node, c + 1, def.charges)
			end
		end
	end)
end

function GatherService.start()
	Players.PlayerRemoving:Connect(function(p)
		limiter:forget(p)
	end)
end

return GatherService
