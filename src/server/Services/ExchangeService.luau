--!strict
-- Loft stock exchange. CANON: workshop/inventory.gd make_mouse_visor_chip_upgrade():
-- spend 4 packed_block + 1 forged_blank -> workshop equipment visor_chip_capacity +1.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local RecipeDefs = require(Shared.RecipeDefs)
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)
local Inventory = require(script.Parent.WorkshopInventoryService)
local RateLimiter = require(script.Parent.RateLimiter)

local ExchangeService = {}
local limiter = RateLimiter.new(2, 0.5)
local exchangePart: BasePart? = nil

local function near(player: Player): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return exchangePart ~= nil
		and root ~= nil
		and root:IsA("BasePart")
		and (root.Position - (exchangePart :: BasePart).Position).Magnitude <= Config.STATION_MAX_DISTANCE
end

local function buy(player: Player, upgradeId: any)
	if not limiter:allow(player) or not DataService.get(player) then
		return
	end
	local up = RecipeDefs.VISOR_CHIP_UPGRADE
	if upgradeId ~= up.id then
		return
	end
	if not near(player) then
		Remotes.event("Notify"):FireClient(player, "Stand at the stock exchange.", "bad")
		return
	end
	local ok, reason = Inventory.transact("build_equipment", function(d)
		for k, n in up.cost do
			if (d.inventory[k] or 0) < n then
				return false, "Needs 4 Packed Blocks + 1 Forged Blank."
			end
		end
		for k, n in up.cost do
			d.inventory[k] -= n
		end
		d.equipment[up.equipmentKey] = (d.equipment[up.equipmentKey] or 1) + 1
		table.insert(d.log, {
			t = os.time(),
			kind = "build_equipment",
			actor = "exchange:" .. player.UserId,
			details = { item = up.equipmentKey, cost = up.cost },
		})
		while #d.log > 50 do
			table.remove(d.log, 1)
		end
		return true, nil
	end)
	if ok then
		Remotes.event("Notify")
			:FireAllClients(
				player.DisplayName .. " built a Mouse Visor Chip upgrade for the workshop.",
				"good"
			)
	else
		Remotes.event("Notify"):FireClient(player, reason or "Exchange failed.", "bad")
	end
end

function ExchangeService.bind(part: BasePart, prompt: ProximityPrompt)
	exchangePart = part
	prompt.Triggered:Connect(function(player)
		if DataService.get(player) then
			Remotes.event("OpenExchange"):FireClient(player)
		end
	end)
end

function ExchangeService.start()
	Remotes.event("BuyUpgrade").OnServerEvent:Connect(buy)
	Players.PlayerRemoving:Connect(function(p)
		limiter:forget(p)
	end)
end

return ExchangeService
