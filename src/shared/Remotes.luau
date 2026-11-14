--!strict
-- Creates (server) or waits for (client) all remotes in ReplicatedStorage.GERTECH_Remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local EVENTS = {
	"InventoryUpdated", -- S->C (inventory, equipment, flags)
	"ProgressionUpdated", -- S->C (xp, level, unlocked)
	"ForgeState", -- S->C (job state for this player)
	"OpenForge", -- S->C
	"OpenExchange", -- S->C
	"Notify", -- S->C (text, kind)
	"StartCraft", -- C->S (recipeId, rows)
	"CancelCraft", -- C->S
	"BuyUpgrade", -- C->S (upgradeId)
}

local FUNCTIONS = {
	"GetSnapshot", -- C->S returns full UI snapshot
}

local FOLDER_NAME = "GERTECH_Remotes"
local folder: Folder

if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		folder = existing :: Folder
	else
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local e = Instance.new("RemoteEvent")
			e.Name = name
			e.Parent = folder
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local f = Instance.new("RemoteFunction")
			f.Name = name
			f.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function Remotes.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
