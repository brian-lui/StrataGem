require 'inits'
require 'utilities'
local image = require 'image'

local stage = {}
stage.width = 1024
stage.height = 768
stage.gem_width = image.red_gem:getWidth()
stage.gem_height = image.red_gem:getHeight()
stage.x_mid = stage.width / 2
stage.y_mid = stage.height / 2

-- this describes the shape of the curve for the hands.
stage.getx = {
	P1 = function(y)
		if y <= stage.height * 0.6 then
			return stage.x_mid - (5.5 * stage.gem_width)
		else
			local start_x = stage.x_mid + (5.5 * stage.gem_width) * -1
			local additional = (((y - stage.height * 0.6) / stage.height) ^ 2) * stage.height
			return start_x + additional * -1
		end
	end,
	P2 = function(y)
		if y <= stage.height * 0.6 then
			return stage.x_mid + (5.5 * stage.gem_width)
		else
			local start_x = stage.x_mid + (5.5 * stage.gem_width) * 1
			local additional = (((y - stage.height * 0.6) / stage.height) ^ 2) * stage.height
			return start_x + additional * 1
		end
	end,
}

stage.super_click = {
	P1 = {0, 0, stage.width * 0.2, stage.height * 0.3}, -- rx, ry, rw, rh
	P2 = {stage.width * 0.8, 0, stage.width * 0.2, stage.height * 0.3},
}

stage.super = {[p1] = {}, [p2] = {}}
stage.super[p1].frame = {x = stage.x_mid - (8.5 * stage.gem_width), y = stage.y_mid - (3 * stage.gem_height)}
stage.super[p2].frame = {x = stage.x_mid + (8.5 * stage.gem_width), y = stage.y_mid - (3 * stage.gem_height)}
local super_width = image.UI.super.red_partial:getWidth()

for i = 1, 4 do
	stage.super[p1][i] = {
		x = stage.super[p1].frame.x + ((i - 2.5) * super_width),
		y = stage.super[p1].frame.y,
		glow_x = stage.super[p1].frame.x + ((i * 0.5 - 2) * super_width),
		glow_y = stage.super[p1].frame.y,
	}
	stage.super[p2][i] = {
		x = stage.super[p2].frame.x + ((2.5 - i) * super_width),
		y = stage.super[p2].frame.y,
		glow_x = stage.super[p2].frame.x + ((2 - i * 0.5) * super_width),
		glow_y = stage.super[p2].frame.y,
	}
end

stage.character = {
	P1 = {x = stage.x_mid - (8 * stage.gem_width), y = stage.y_mid - (5.5 * stage.gem_height)},
	P2 = {x = stage.x_mid + (8 * stage.gem_width), y = stage.y_mid - (5.5 * stage.gem_height)}
}

stage.timer = {x = stage.x_mid, y = stage.height * 0.1}

-------------------------------------------------------------------------------
------------------------------------ GRID -------------------------------------
-------------------------------------------------------------------------------
local tub_bottom = stage.height * 0.95
local grid =  {
	columns = 8,
	rows = 14, -- 7-14 basin, 1-6 for rush/double/normal, 0 and 15 sentinels
	x = {},
	y = {},
	active_rect = {}
}

for i = 0, grid.columns + 1 do
	grid.x[i] = stage.x_mid + (i - (grid.columns / 2) - 0.5) * stage.gem_width
	grid.active_rect[i] = {grid.x[i] - 0.5 * stage.gem_width, 0, stage.gem_width, stage.height}
end

for i = 0, grid.rows + 1 do
	grid.y[i] = tub_bottom + (i - grid.rows - 0.5) * stage.gem_height
end

for row = 0, grid.rows + 1 do
	grid[row] = {}
	for col = 0, grid.columns + 1 do
		grid[row][col] = {gem = false, owner = 0}
	end
end

function grid:getFirstEmptyRow(column)
--[[ This returns the first empty row, used to calculate where to display the shadow
	for the gem landing location. The starting row is 3, because rows 1 and 2 are the
	pending gem drop locations, and row 0 is a sentinel row
	Returns nil if column is invalid.
--]]
	if column then
		local empty_spaces = 2 -- rows 1 and 2 are always considered empty
		for i = 3, self.rows do
			if not self[i][column].gem then empty_spaces = empty_spaces + 1 end
		end
		return empty_spaces
	end
end

function grid:getDropLocations(piece, optional_shift)
--[[ Returns a piece's landing locations as a table of {{column, row}, {c,r}}.
	optional_shift is +1/-1, used if the gem is over midline and column needs to be
	corrected.
--]]
	local column = piece:getColumns(optional_shift)
	local row, ret = {}, {}
	for i = 1, piece.size do
		row[i] = self:getFirstEmptyRow(column[i])
		if not piece.horizontal and row[i] then
			row[i] = row[i] - piece.size + i  
		end
		ret[i] = {column[i], row[i]}
	end
	return ret
end

local function getPermittedColors(use_grid, column, banned_color1, banned_color2)
	use_grid = use_grid or grid
	local avail_color = {"RED", "BLUE", "GREEN", "YELLOW"}
	local ban = {false, false, false, false}
	local ban1 = false
	local ret = {}
	if use_grid[grid.rows - 1][column].gem then
		ban1 = use_grid[grid.rows - 1][column].gem.color
	end
	for i = 1, 4 do
		if ban1 ~= avail_color[i] and banned_color1 ~= avail_color[i]
		and banned_color2 ~= avail_color[i] then
			ret[#ret+1] = avail_color[i]
		end
	end
	--print("column:", column, "permitted:", unpack(ret))
	return ret
end

local function generate1by1(player, column, banned_color1, banned_color2, use_grid, row)
	use_grid = use_grid or grid
	row = row or grid.rows -- grid.rows is the row underneath the bottom row
	local avail_colors = getPermittedColors(use_grid, column, banned_color1, banned_color2)
	local all_gems = {
		{color = "RED", gem = Gem.RedGem, freq = 1},
		{color = "BLUE", gem = Gem.BlueGem, freq = 1},
		{color = "GREEN", gem = Gem.GreenGem, freq = 1},
		{color = "YELLOW", gem = Gem.YellowGem, freq = 1}
	}
	local legal_gems = {}
	for i = 1, 4 do
		for j = 1, #avail_colors do
			if all_gems[i].color == avail_colors[j] then
				legal_gems[#legal_gems+1] = all_gems[i]
			end
		end
	end
	local make_color = Gem:random(legal_gems)
	local distance = grid.y[row+1] - grid.y[row]
	local speed = SPEED.DROP + SPEED.DROP_MULTIPLE * game.scoring_combo
	local duration = distance / speed
	print("garbage distaces, duration", distance, duration)
	local make_gem = function(r, c)
		use_grid[r][c].gem = make_color:new(grid.x[c], grid.y[r+1], true)
		use_grid[r][c].gem:moveTo{x = grid.x[c], y = grid.y[r], duration = duration}
	end
	make_gem(row, column)
end

local function moveAllUp(player, rows_to_add, use_grid)
-- Moves all gems in the player's half up by rows_to_add.
	use_grid = use_grid or grid
	local last_row = grid.rows - rows_to_add
	local start_col, end_col = 1, 4
	if player == p2 then start_col, end_col = 5, 8 end
	for r = 1, last_row do
		for c = start_col, end_col do
			use_grid[r][c].gem = use_grid[r+rows_to_add][c].gem
			if use_grid[r][c].gem then
				grid:moveGemAnim(use_grid[r][c].gem, r, c)
				grid:moveGem(use_grid[r][c].gem, r, c)
			end
		end
	end
	for i = last_row + 1, grid.rows do
		for j = start_col, end_col do
			use_grid[i][j].gem = false
		end
	end
end

function grid:addBottomRow(player)
	moveAllUp(player, 1)
	local start, finish, step = p1.start_col, p1.end_col, 1
	if player == p2 then start, finish, step = p2.end_col, p2.start_col, -1 end
	for col = start, finish, step do
		local ban1, ban2 = false, false
		if col > p1.start_col and col < p2.end_col then
			local prev_col = (col - step)
			local next_col = (col + step)
			ban1 = self[self.rows][prev_col].gem.color
			if self[self.rows][next_col].gem then
				ban2 = self[self.rows][next_col].gem.color
			end
		end
		generate1by1(player, col, ban1, ban2, self)
	end

end

function grid:isSettled()
	local all_unmoved = true
	for gem in gridGems(self) do
		if not gem:isStationary() then all_unmoved = false end
	end
	if all_unmoved then self:updateGrid() end

	return all_unmoved
end

-- animation part of moving gem to a row/column
-- can call this from player functions
function grid:moveGemAnim(gem, row, column)
	local target_x, target_y = self.x[column], self.y[row]
	local dist = ((target_x - gem.x) ^ 2 + (target_y - gem.y) ^ 2) ^ 0.5
	local angle = math.atan2(target_y - gem.y, target_x - gem.x)
	local speed = SPEED.DROP + SPEED.DROP_MULTIPLE * game.scoring_combo
	local duration = math.abs(dist / speed)
	gem:moveTo{x = target_x, y = target_y, duration = duration, exit = {gem.landedInGrid, gem}}
end

-- move a gem from a spot on the grid to another spot
function grid:moveGem(gem, row, column)
	gem.row, gem.column = row, column
end

-- instructions to animate the falling gems
function grid:dropColumnsAnim()
	for gem, r, c in gridGems(self) do
		if gem and (gem.y ~= self.y[r] or gem.x ~= self.x[c]) then
			self:moveGemAnim(gem, r, c)
		end
	end
end

-- creates the grid after gems have fallen
function grid:dropColumns()
	for c = 1, self.columns do
		local sorted_column = columnSort(c, self)
		for r = 1, self.rows do
			self[r][c].gem = sorted_column[r]
			local cell = self[r][c].gem
			if cell then cell.row, cell.column = r, c end
		end
	end
	grid:dropColumnsAnim() -- easy to split out later
end

function grid:updateGravity(dt)
	if game.grid_wait == 0 then
		-- move gems to new positions
		for gem in gridGems(self) do gem:update(dt)	end
	end
end

function grid:getPendingGems(player)
	local ret = {}
	local col_start, col_end = 1, 4
	if player == p2 then col_start, col_end = 5, 8 end
	for gem, r, c in gridGems(self) do
		if r <= 6 and c >= col_start and gem.column <= col_end then
			ret[#ret+1] = gem
		end
	end
	return ret
end

function grid:getIDs()
-- returns the ID, column, row of all gems in the tub
	local ret = {}
	for gem in gridGems(self) do
		if gem then
			ret[#ret+1] = {gem.ID, gem.column, gem.row}
		else
			ret[#ret+1] = false
		end
	end
	return ret
end

function grid:updateGrid()
	for row = 0, self.rows + 1 do
		for col = 0, self.columns + 1 do
			-- update the gem row/column information after columnSort
			if self[row][col].gem then
				self[row][col].gem.row = row
				self[row][col].gem.column = col
				self.tweening = nil
			end
			-- other effects update here
		end
	end
end

function grid:reset()
	for row = 0, self.rows + 1 do
		self[row] = {}
		for col = 0, self.columns + 1 do
			self[row][col] = {gem = false, owner = 0}
		end
	end
end

-- remove a gem
function grid:removeGem(g)
	self[g.row][g.column].gem = false
end

grid.debug = {}
function grid.debug.drawGridlines(self)
	for i = 1, #self.x do
		love.graphics.line(self.x[i], 0, self.x[i], stage.height)
		love.graphics.print(i, self.x[i], 200)
	end
	for i = 0, #self.y do
		love.graphics.line(0, self.y[i], stage.width, self.y[i])
		love.graphics.print(i, 200, self.y[i])
	end
end

function grid.debug.getGridColors(self)
	local ret = {"Printing gem colors:"}
	for i = 1, #self-1 do
		local row = {}
		for j = 1, #self[i]-1 do
			if self[i][j].gem then
				row[j] = self[i][j].gem.color
				row[j] = " " .. row[j] .. string.rep(" ", 7 - #row[j])
			else
				row[j] = " ...... "
			end
		end
		ret[#ret+1] = table.concat({i-1, unpack(row)})
	end
	return ret
end

function grid.debug.getGridOwnership(self)
	local ret = {"Printing gem ownership:"}
	for i = 1, #self-1 do
		local row = {}
		for j = 1, #self[i]-1 do
			if self[i][j].gem then
				if self[i][j].gem.owner == 0 then
					row[j] = "  Nil   "
				elseif self[i][j].gem.owner == 1 then
					row[j] = "   P1   "
				elseif self[i][j].gem.owner == 2 then
					row[j] = "   P2   "
				elseif self[i][j].gem.owner == 3 then
					row[j] = " P1&P2  "
				end
			else
				row[j] = " ...... "
			end
		end
		ret[#ret+1] = table.concat({i-1, unpack(row)})
	end
	return ret
end

stage.grid = grid
return stage