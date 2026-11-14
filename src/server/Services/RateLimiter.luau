--!strict
-- Per-player, per-action token bucket. Anti-spam for remotes and prompts.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: {
		capacity: number,
		refillPerSecond: number,
		buckets: { [any]: { tokens: number, last: number } },
	},
	RateLimiter
))

function RateLimiter.new(capacity: number, refillPerSecond: number): RateLimiter
	return setmetatable({ capacity = capacity, refillPerSecond = refillPerSecond, buckets = {} }, RateLimiter)
end

function RateLimiter.allow(self: RateLimiter, key: any): boolean
	local now = os.clock()
	local b = self.buckets[key]
	if not b then
		b = { tokens = self.capacity, last = now }
		self.buckets[key] = b
	end
	b.tokens = math.min(self.capacity, b.tokens + (now - b.last) * self.refillPerSecond)
	b.last = now
	if b.tokens >= 1 then
		b.tokens -= 1
		return true
	end
	return false
end

function RateLimiter.forget(self: RateLimiter, key: any)
	self.buckets[key] = nil
end

return RateLimiter
