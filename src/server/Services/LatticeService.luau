--!strict
-- WorldSeed-lite lattice frame. CANON rules from worldseed/world_seed.gd:
--   occupy_vertex: placing a module spends 1 of that module from the shared inventory.
--   free_vertex (salvage/repair): recovering a module returns exactly 1 to inventory;
--   the "core" vertex can never be freed.
-- PLACEHOLDER: a fixed 12-socket ring instead of Godot's grown 36-vertex lattice.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ItemDefs = require(Shared.ItemDefs)
local ProgressionDefs = require(Shared.ProgressionDefs)
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)
local Inventory = require(script.Parent.WorkshopInventoryService)
local RateLimiter = require(script.Parent.RateLimiter)

local LatticeService = {}
local limiter = RateLimiter.new(3, 1)
local sockets: { [number]: BasePart } = {}
local PLACE_MODULE = "packed_block"

local function render()
	local lattice = Inventory.view().lattice
	for i, part in sockets do
		local m = lattice[i] or "empty"
		local def = ItemDefs.get(m)
		if m == "core" then
			part.Color = Color3.fromRGB(255, 215, 90)
			part.Transparency = 0
		elseif m == "empty" then
			part.Color = Color3.fromRGB(80, 90, 110)
			part.Transparency = 0.6
		else
			part.Color = if def then def.color else Color3.new(1, 1, 1)
			part.Transparency = 0.1
		end
		local prompt = part:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = m ~= "core"
			prompt.ActionText = if m == "empty" then "Place Packed Block" else "Recover Module"
		end
	end
end

local function toggle(player: Player, index: number)
	if not limiter:allow(player) or not DataService.get(player) then
		return
	end
	local placed = false
	local ok, reason = Inventory.transact("lattice", function(d)
		local m = d.lattice[index]
		if m == nil or m == "core" then
			return false, "The core socket cannot be salvaged."
		end
		if m == "empty" then
			if (d.inventory[PLACE_MODULE] or 0) < 1 then
				return false, "Needs a Packed Block from the TETRAFORGE."
			end
			d.inventory[PLACE_MODULE] -= 1
			d.lattice[index] = PLACE_MODULE
			placed = true
		else
			d.inventory[m] = (d.inventory[m] or 0) + 1 -- 1:1 recovery
			d.lattice[index] = "empty"
			placed = false
		end
		return true, nil
	end)
	if not ok then
		Remotes.event("Notify"):FireClient(player, reason or "Lattice busy.", "bad")
		return
	end
	if placed then
		DataService.addXp(player, ProgressionDefs.XP_PER_SOCKET)
		DataService.addStat(player, "socketsPlaced", 1)
	end
end

function LatticeService.bindSocket(index: number, part: BasePart, prompt: ProximityPrompt)
	sockets[index] = part
	prompt.Triggered:Connect(function(player)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - part.Position).Magnitude < 14 then
			toggle(player, index)
		end
	end)
end

function LatticeService.start()
	Inventory.onChanged(render)
	render()
	Players.PlayerRemoving:Connect(function(p)
		limiter:forget(p)
	end)
end

return LatticeService
