local class = require "middleclass"

local Gem = require "gem"

local grid = class("Grid")

local window = _G.window -- TODO: Remove global
grid.static.DROP_SPEED = window.height / 120 -- pixels per frame for loose gems to drop
grid.static.DROP_MULTIPLE_SPEED = window.height / 240 -- multiplier for scoring_combo

function grid:initialize(stage, game)
	self.game = game
	self.columns = 8
	self.rows = 14	-- 7-14 basin, 1-6 for rush/double/normal, 0 and 15 sentinels
	self.x = {}
	self.y = {}
	self.active_rect = {}

	for i = 0, self.columns + 1 do
		self.x[i] = stage.x_mid + (i - (self.columns / 2) - 0.5) * stage.gem_width
		self.active_rect[i] = {self.x[i] - 0.5 * stage.gem_width, 0, stage.gem_width, stage.height}
	end

	local tub_bottom = stage.height * 0.95
	for i = 0, self.rows + 1 do
		self.y[i] = tub_bottom + (i - self.rows - 0.5) * stage.gem_height
	end

	for row = 0, self.rows + 1 do
		self[row] = {}
		for col = 0, self.columns + 1 do
			self[row][col] = {gem = false, owner = 0}
		end
	end
end

function grid:gems()
	--if not grd then print(debug.traceback()) assert(grd, "wrong grid") end
	local gems, rows, columns, index = {}, {}, {}, 0

	for i = 0, self.rows + 1 do
		for j = 0, self.columns + 1 do
			if self[i][j].gem then
				gems[#gems+1] = self[i][j].gem
				rows[#rows+1] = i
				columns[#columns+1] = j
			end
		end
	end
	return function()
		index = index + 1
		return gems[index], rows[index], columns[index]
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

function grid:getPermittedColors(column, banned_color1, banned_color2)
	local avail_color = {"RED", "BLUE", "GREEN", "YELLOW"}
	local ban1 = false
	local ret = {}
	if self[self.rows - 1][column].gem then
		ban1 = self[self.rows - 1][column].gem.color
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

function grid:generate1by1(column, banned_color1, banned_color2)
	local row = self.rows -- grid.rows is the row underneath the bottom row
	local avail_colors = self:getPermittedColors(column, banned_color1, banned_color2)
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
	local distance = self.y[row+1] - self.y[row]
	local speed = self.DROP_SPEED + self.DROP_MULTIPLE_SPEED * self.game.scoring_combo
	local duration = distance / speed
	print("garbage distaces, duration", distance, duration)
	local make_gem = function(r, c)
		self[r][c].gem = make_color:new(self.x[c], self.y[r+1], true)
		self[r][c].gem:moveTo{x = self.x[c], y = self.y[r], duration = duration}
	end
	make_gem(row, column)
end

-- TODO: Remove this? Gems shouldn't store their own grid coordinates
-- move a gem from a spot on the grid to another spot
local function moveGem(gem, row, column)
	gem.row, gem.column = row, column
end

local p1, p2 = _G.p1, _G.p2	-- TODO: Remove globals
function grid:moveAllUp(player, rows_to_add)
-- Moves all gems in the player's half up by rows_to_add.
	local last_row = self.rows - rows_to_add
	local start_col, end_col = 1, 4
	if player == p2 then
		start_col, end_col = 5, 8
	end
	for r = 1, last_row do
		for c = start_col, end_col do
			self[r][c].gem = self[r+rows_to_add][c].gem
			if self[r][c].gem then
				grid:moveGemAnim(self[r][c].gem, r, c)
				moveGem(self[r][c].gem, r, c)
			end
		end
	end
	for i = last_row + 1, self.rows do
		for j = start_col, end_col do
			self[i][j].gem = false
		end
	end
end

function grid:addBottomRow(player)
	self:moveAllUp(player, 1)
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
		self:generate1by1(col, ban1, ban2)
	end

end

function grid:isSettled()
	local all_unmoved = true
	for gem in self:gems() do
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
	--local angle = math.atan2(target_y - gem.y, target_x - gem.x)
	local speed = self.DROP_SPEED + self.DROP_MULTIPLE_SPEED * self.game.scoring_combo
	local duration = math.abs(dist / speed)
	gem:moveTo{x = target_x, y = target_y, duration = duration, exit = {gem.landedInGrid, gem}}
end

-- instructions to animate the falling gems
function grid:dropColumnsAnim()
	for gem, r, c in self:gems() do
		if gem and (gem.y ~= self.y[r] or gem.x ~= self.x[c]) then
			self:moveGemAnim(gem, r, c)
		end
	end
end

function grid:columnSort(column_num)
	local column = {}
	for i = 1, self.rows do
		column[i] = self[i][column_num].gem
	end
	for i = self.rows, 1, -1 do
		 if not column[i] then
			 table.remove(column, i)
		 end
	end
	for _ = 1, self.rows - #column do
		table.insert(column, 1, false)
	end
	return column
end

-- creates the grid after gems have fallen
function grid:dropColumns()
	for c = 1, self.columns do
		local sorted_column = self:columnSort(c)
		for r = 1, self.rows do
			self[r][c].gem = sorted_column[r]
			local cell = self[r][c].gem
			if cell then cell.row, cell.column = r, c end
		end
	end
	self:dropColumnsAnim() -- easy to split out later
end

function grid:updateGravity(dt)
	if self.game.grid_wait == 0 then
		-- move gems to new positions
		for gem in self:gems() do
			gem:update(dt)
		end
	end
end

function grid:getPendingGems(player)
	local ret = {}
	local col_start, col_end = 1, 4
	if player == p2 then col_start, col_end = 5, 8 end
	for gem, r, c in self:gems() do
		if r <= 6 and c >= col_start and gem.column <= col_end then
			ret[#ret+1] = gem
		end
	end
	return ret
end

function grid:getIDs()
-- returns the ID, column, row of all gems in the tub
	local ret = {}
	for gem in self:gems() do
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

--[[
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
--]]

return grid
