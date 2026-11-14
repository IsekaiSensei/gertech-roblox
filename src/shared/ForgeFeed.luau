--!strict
-- TETRAFORGE feed sources (engine-free, testable offline).
--
--   static(budget)  : Godot's model. A fixed budget handed to the run; nothing else spends it.
--   hopper(reserved, shared)
--                   : the Roblox model. The run may use the WHOLE shared workshop stock:
--                     remaining(kind) = unspent hopper + unreserved shared stock (what Godot's
--                     _choose_materials sees). A piece may only spawn once its 4 cells are
--                     physically in the hopper (`covers`), i.e. already reserved atomically,
--                     so a lock can never spend material another player also spent.
--
-- ForgeSession only calls remaining() and covers(); the host owns topping the hopper up.

local ForgeRules = require(script.Parent.ForgeRules)

local ForgeFeed = {}

export type Feed = {
	remaining: (self: any, kind: string, spent: number) -> number,
	covers: (self: any, materials: { string }, spent: { [string]: number }) -> boolean,
}

local function counts(materials: { string }): { [string]: number }
	local need: { [string]: number } = {}
	for _, m in materials do
		need[m] = (need[m] or 0) + 1
	end
	return need
end
ForgeFeed.counts = counts

---------------------------------------------------------------- static (Godot)
function ForgeFeed.static(budget: { [string]: number }): Feed
	local feed = { budget = table.clone(budget) }
	function feed.remaining(self: any, kind: string, spent: number): number
		return math.max(0, (self.budget[kind] or 0) - spent)
	end
	function feed.covers(_self: any, _materials: { string }, _spent: { [string]: number }): boolean
		return true
	end
	return feed :: any
end

---------------------------------------------------------------- hopper (shared stock)
export type Hopper = Feed & {
	reserved: { [string]: number }, -- cumulative amount moved out of the shared stock
	shared: (kind: string) -> number, -- unreserved shared stock (host's live view)
	left: (self: any, kind: string, spent: number) -> number,
	wants: (self: any, spent: { [string]: number }, waiting: { string }?) -> { [string]: number }?,
	credit: (self: any, granted: { [string]: number }) -> (),
	refund: (self: any, spent: { [string]: number }) -> { [string]: number },
}

function ForgeFeed.hopper(reserved: { [string]: number }, shared: (kind: string) -> number): Hopper
	local feed: any = { reserved = {}, shared = shared }
	for _, k in ForgeRules.FEED_MATERIALS do
		feed.reserved[k] = math.max(0, reserved[k] or 0)
	end

	-- Unspent cells physically in the hopper.
	function feed.left(self: any, kind: string, spent: number): number
		return math.max(0, (self.reserved[kind] or 0) - spent)
	end

	function feed.remaining(self: any, kind: string, spent: number): number
		return self:left(kind, spent) + math.max(0, self.shared(kind))
	end

	function feed.covers(self: any, materials: { string }, spent: { [string]: number }): boolean
		for k, n in counts(materials) do
			if self:left(k, spent[k] or 0) < n then
				return false
			end
		end
		return true
	end

	-- Top-up request: nil when the hopper is healthy. Refills every kind to HOPPER_TARGET
	-- (never more than the shared stock) once any kind falls below HOPPER_LOW, or at once
	-- when a spawned piece is waiting for cells the hopper does not hold yet.
	function feed.wants(self: any, spent: { [string]: number }, waiting: { string }?): { [string]: number }?
		local trigger = false
		if waiting and not self:covers(waiting, spent) then
			trigger = true
		end
		for _, k in ForgeRules.FEED_MATERIALS do
			if self:left(k, spent[k] or 0) < ForgeRules.HOPPER_LOW[k] and self.shared(k) > 0 then
				trigger = true
			end
		end
		if not trigger then
			return nil
		end
		local want: { [string]: number } = {}
		local any = false
		for _, k in ForgeRules.FEED_MATERIALS do
			local need = ForgeRules.HOPPER_TARGET[k] - self:left(k, spent[k] or 0)
			if waiting then
				need = math.max(need, (counts(waiting)[k] or 0) - self:left(k, spent[k] or 0))
			end
			local n = math.min(need, math.max(0, self.shared(k)))
			if n > 0 then
				want[k] = n
				any = true
			end
		end
		return if any then want else nil
	end

	-- Called after the atomic top-up write succeeded.
	function feed.credit(self: any, granted: { [string]: number })
		for k, n in granted do
			if self.reserved[k] ~= nil and n > 0 then
				self.reserved[k] += n
			end
		end
	end

	-- Unspent hopper contents (returned to the shared stock at settlement).
	function feed.refund(self: any, spent: { [string]: number }): { [string]: number }
		local out = {}
		for _, k in ForgeRules.FEED_MATERIALS do
			out[k] = self:left(k, spent[k] or 0)
		end
		return out
	end

	return feed :: Hopper
end

return ForgeFeed
