--!strict
-- Faithful port of Godot core/tetris/tetromino_grid.gd (TetrominoGrid).
-- Engine-free: no Roblox APIs, so it runs in the offline tests and on server + client.
-- Coordinates match Godot exactly: x 0..WIDTH-1 left->right, y 0..HEIGHT-1 top->bottom,
-- y < 0 is above the chamber. Empty cell = "".

export type Point = { x: number, y: number }
export type LockOutcome = { clearedRows: { { [string]: number } }, overflow: boolean }

local TetrominoGrid = {}
TetrominoGrid.__index = TetrominoGrid

TetrominoGrid.WIDTH = 10
TetrominoGrid.HEIGHT = 20

-- CANON: SHAPES (offsets from the piece origin)
TetrominoGrid.SHAPES = {
	I = { { x = -1, y = 0 }, { x = 0, y = 0 }, { x = 1, y = 0 }, { x = 2, y = 0 } },
	O = { { x = 0, y = 0 }, { x = 1, y = 0 }, { x = 0, y = 1 }, { x = 1, y = 1 } },
	T = { { x = -1, y = 0 }, { x = 0, y = 0 }, { x = 1, y = 0 }, { x = 0, y = 1 } },
	L = { { x = -1, y = 0 }, { x = 0, y = 0 }, { x = 1, y = 0 }, { x = 1, y = 1 } },
	J = { { x = -1, y = 0 }, { x = 0, y = 0 }, { x = 1, y = 0 }, { x = -1, y = 1 } },
	S = { { x = 0, y = 0 }, { x = 1, y = 0 }, { x = -1, y = 1 }, { x = 0, y = 1 } },
	Z = { { x = -1, y = 0 }, { x = 0, y = 0 }, { x = 0, y = 1 }, { x = 1, y = 1 } },
} :: { [string]: { Point } }

export type Grid = typeof(setmetatable({} :: { cells: { { string } } }, TetrominoGrid))

local function emptyRow(): { string }
	return table.create(TetrominoGrid.WIDTH, "")
end

function TetrominoGrid.new(): Grid
	local cells = {}
	for y = 1, TetrominoGrid.HEIGHT do
		cells[y] = emptyRow()
	end
	return setmetatable({ cells = cells }, TetrominoGrid)
end

-- Godot posmod
local function posmod(a: number, b: number): number
	return ((a % b) + b) % b
end

function TetrominoGrid.at(self: Grid, x: number, y: number): string
	if x < 0 or x >= TetrominoGrid.WIDTH or y < 0 or y >= TetrominoGrid.HEIGHT then
		return ""
	end
	return self.cells[y + 1][x + 1]
end

function TetrominoGrid.set(self: Grid, x: number, y: number, value: string)
	self.cells[y + 1][x + 1] = value
end

-- CANON: rotate each offset (x, y) -> (-y, x) per quarter turn; "O" never rotates.
function TetrominoGrid.rotated(shape: string, turns: number): { Point }
	local result = {}
	for _, raw in TetrominoGrid.SHAPES[shape] do
		local px, py = raw.x, raw.y
		if shape ~= "O" then
			for _ = 1, posmod(turns, 4) do
				px, py = -py, px
			end
		end
		table.insert(result, { x = px, y = py })
	end
	return result
end

function TetrominoGrid.occupied(shape: string, rotation: number, ox: number, oy: number): { Point }
	local points = {}
	for _, p in TetrominoGrid.rotated(shape, rotation) do
		table.insert(points, { x = ox + p.x, y = oy + p.y })
	end
	return points
end

function TetrominoGrid.fits(self: Grid, shape: string, rotation: number, ox: number, oy: number): boolean
	for _, p in TetrominoGrid.occupied(shape, rotation, ox, oy) do
		if p.x < 0 or p.x >= TetrominoGrid.WIDTH or p.y >= TetrominoGrid.HEIGHT then
			return false
		end
		if p.y >= 0 and self:at(p.x, p.y) ~= "" then
			return false
		end
	end
	return true
end

-- CANON: lock(): write materials, flag overflow for cells above the top, then clear every
-- solid row bottom-up, tallying its materials, shifting rows down and inserting empties.
function TetrominoGrid.lock(
	self: Grid,
	shape: string,
	rotation: number,
	ox: number,
	oy: number,
	materials: { string }
): LockOutcome
	local overflow = false
	local points = TetrominoGrid.occupied(shape, rotation, ox, oy)
	for i, p in points do
		if p.y < 0 then
			overflow = true
		else
			self:set(p.x, p.y, materials[i])
		end
	end
	local rows = {}
	local y = TetrominoGrid.HEIGHT - 1
	while y >= 0 do
		local row = self.cells[y + 1]
		local solid = true
		for _, cell in row do
			if cell == "" then
				solid = false
				break
			end
		end
		if solid then
			local tally: { [string]: number } = {}
			for _, cell in row do
				tally[cell] = (tally[cell] or 0) + 1
			end
			table.insert(rows, tally)
			table.remove(self.cells, y + 1)
			table.insert(self.cells, 1, emptyRow())
		else
			y -= 1
		end
	end
	return { clearedRows = rows, overflow = overflow }
end

function TetrominoGrid.remainingCells(self: Grid): number
	local count = 0
	for _, row in self.cells do
		for _, cell in row do
			if cell ~= "" then
				count += 1
			end
		end
	end
	return count
end

-- Compact board encoding for replication: one char per cell, row-major from the top.
function TetrominoGrid.encode(self: Grid, codes: { [string]: string }): string
	local parts = table.create(TetrominoGrid.HEIGHT * TetrominoGrid.WIDTH)
	for _, row in self.cells do
		for _, cell in row do
			table.insert(parts, if cell == "" then "." else (codes[cell] or "?"))
		end
	end
	return table.concat(parts)
end

return TetrominoGrid
