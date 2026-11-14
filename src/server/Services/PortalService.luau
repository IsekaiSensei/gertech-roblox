--!strict
-- DNA wormhole helix: the transfer portal to other places in the universe.
-- (Never call it "the zipper".) Destinations come from PlaceRegistry; unbuilt ones say so.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage.Shared
local PlaceRegistry = require(Shared.PlaceRegistry)
local Remotes = require(Shared.Remotes)
local Inventory = require(script.Parent.WorkshopInventoryService)

local PortalService = {}
local cooldown: { [Player]: number } = {}

function PortalService.bind(prompt: ProximityPrompt, destinationKey: string)
	prompt.Triggered:Connect(function(player)
		if (cooldown[player] or 0) > os.clock() then
			return
		end
		cooldown[player] = os.clock() + 5
		local dest = PlaceRegistry.Places[destinationKey]
		if not dest or dest.placeId == 0 then
			Remotes.event("Notify"):FireClient(
				player,
				"The DNA wormhole helix to "
					.. (dest and dest.name or destinationKey)
					.. " is not stable yet (place not built).",
				"info"
			)
			return
		end
		-- Save first, then hand the workshop id over so the destination joins the same economy.
		Inventory.flush()
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData({ workshopId = Inventory.workshopId(), from = "hub" })
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(dest.placeId, { player }, options)
		end)
		if not ok then
			Remotes.event("Notify"):FireClient(player, "Helix transfer failed: " .. tostring(err), "bad")
		end
	end)
end

function PortalService.start()
	Players.PlayerRemoving:Connect(function(p)
		cooldown[p] = nil
	end)
end

return PortalService
