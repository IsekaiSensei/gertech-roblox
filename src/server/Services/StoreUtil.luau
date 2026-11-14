--!strict
-- DataStore access with retries and an in-memory fallback so the game still runs in Studio
-- when "Enable Studio Access to API Services" is off (nothing persists in that mode).

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local StoreUtil = {}

export type Store = {
	UpdateAsync: (self: Store, key: string, fn: (any) -> any) -> any,
	GetAsync: (self: Store, key: string) -> any,
}

-- Minimal mock with the same call shape
local MockStore = {}
MockStore.__index = MockStore

function MockStore.new()
	return setmetatable({ data = {} :: { [string]: any } }, MockStore)
end

function MockStore:GetAsync(key: string): any
	return self.data[key]
end

function MockStore:UpdateAsync(key: string, fn: (any) -> any): any
	local result = fn(self.data[key])
	if result ~= nil then
		self.data[key] = result
	end
	return result
end

local mocks: { [string]: any } = {}
StoreUtil.usingMock = false

local function probeRealStores(): boolean
	local ok = pcall(function()
		local s = DataStoreService:GetDataStore("GERTECH_Probe")
		s:GetAsync("probe")
	end)
	return ok
end

local probed: boolean? = nil

function StoreUtil.getStore(name: string): any
	if probed == nil then
		probed = probeRealStores()
		if not probed then
			StoreUtil.usingMock = true
			warn(
				"[GERTECH] DataStores unavailable (Studio API access off?). Using in-memory mock: progress will NOT persist."
			)
		end
	end
	if StoreUtil.usingMock then
		if not mocks[name] then
			mocks[name] = MockStore.new()
		end
		return mocks[name]
	end
	return DataStoreService:GetDataStore(name)
end

-- Retry with exponential backoff. Returns (ok, result|err).
function StoreUtil.retry(label: string, fn: () -> ...any): (boolean, any)
	local attempt = 0
	local lastErr: any = nil
	while attempt < Config.DATASTORE_RETRIES do
		attempt += 1
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		warn(string.format("[GERTECH] %s failed (attempt %d): %s", label, attempt, tostring(result)))
		if attempt < Config.DATASTORE_RETRIES then
			task.wait(math.min(2 ^ attempt, 16))
		end
	end
	return false, lastErr
end

function StoreUtil.isStudio(): boolean
	return RunService:IsStudio()
end

return StoreUtil
