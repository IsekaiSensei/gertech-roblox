--!strict
-- GERTECH Roblox server entry point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)

local Services = script.Parent.Services
local DataService = require(Services.DataService)
local Inventory = require(Services.WorkshopInventoryService)
local ForgeService = require(Services.ForgeService)
local GatherService = require(Services.GatherService)
local ExchangeService = require(Services.ExchangeService)
local LatticeService = require(Services.LatticeService)
local PortalService = require(Services.PortalService)
local AmbienceService = require(Services.AmbienceService)
local HubBuilder = require(script.Parent.HubBuilder)

local refs = HubBuilder.build()

Inventory.start()
DataService.start()
ForgeService.start()
GatherService.start()
ExchangeService.start()
LatticeService.start()
PortalService.start()

ForgeService.bindStation(refs.forgeConsole, refs.forgePrompt, refs.chamberCells, refs.chamberLabel)
ExchangeService.bind(refs.exchange, refs.exchangePrompt)
for i, s in refs.sockets do
	LatticeService.bindSocket(i, s.part, s.prompt)
end
for _, n in refs.nodes do
	GatherService.bindNode(n.part, n.prompt, n.nodeType)
end
for _, h in refs.helixPads do
	PortalService.bind(h.prompt, h.destination)
end
for _, ins in refs.inspectables do
	ins.prompt.Triggered:Connect(function(player)
		Remotes.event("Notify"):FireClient(player, ins.text, "info")
	end)
end
AmbienceService.start(refs.stationParts)

Remotes.func("GetSnapshot").OnServerInvoke = function(player: Player)
	return {
		workshop = Inventory.snapshotFor(player),
		loaded = DataService.get(player) ~= nil,
	}
end

DataService.onProfileLoaded(function(player)
	Remotes.event("InventoryUpdated"):FireClient(player, Inventory.snapshotFor(player))
end)

game:BindToClose(function()
	ForgeService.abortAll()
	Inventory.flush()
	DataService.saveAll(true)
end)

print("[GERTECH] Workshop hub ready. Workshop id:", Inventory.workshopId())
