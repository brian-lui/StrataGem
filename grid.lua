local image = require 'image'
local common = require "class.commons"
local Gem = require "gem"

local deepcpy = require "utilities".deepcpy

local Grid = {}

Grid.DROP_SPEED = drawspace.height / 50 -- pixels per frame for loose gems to drop
Grid.DROP_MULTIPLE_SPEED = drawspace.height / 180 -- multiplier for scoring_combo

--[[
Rows 1-2: doublecast gem pending position.
Rows 3-4: rush gem pending position.
Rows 5-6: normal gem pending position.
Rows 7-8: doublecast gem landing position.
Rows 9-10: rush gem landing position.
Rows 11-12: normal gem landing position.
Rows 13-20: basin. Row 13 is at top, 20 at bottom.
Row 21: bottom grid row where trash gems tween from. (now it's just a sentinel)
--]]
function Grid:init(game)
	self.COLUMNS = 8
	self.ROWS = 20
	self.LOSE_ROW = 12 -- game over if a gem ends the turn in this row or above
	self.RUSH_ROW = 16 -- can only rush if this row is empty
	self.BOTTOM_ROW = 20 -- used for garbage appearance
	self.PENDING_START_ROW = 1
	self.PENDING_END_ROW = 12
	self.BASIN_START_ROW = 13
	self.BASIN_END_ROW = 20

	local stage = game.stage
	local basin_bottom = stage.height * 0.95
	self.game = game
	self.x = {}
	self.y = {}
	self.active_rect = {}

	for i = 0, self.COLUMNS + 1 do
		self.x[i] = stage.x_mid + (i - (self.COLUMNS / 2) - 0.5) * stage.gem_width
		self.active_rect[i] = {self.x[i] - 0.5 * stage.gem_width, 0, stage.gem_width, stage.height}
	end

	-- pending gem positions
	for i = 1, 6 do self.y[i] = stage.gem_height * (i - 8) end

	-- landing gem positions
	self.y[7] = basin_bottom - 11.75 * stage.gem_height
	self.y[8] = basin_bottom - 10.75 * stage.gem_height
	self.y[9] = basin_bottom - 10.75 * stage.gem_height
	self.y[10] = basin_bottom - 9.75 * stage.gem_height
	self.y[11] = basin_bottom - 9.75 * stage.gem_height
	self.y[12] = basin_bottom - 8.75 * stage.gem_height

	-- basin positions
	for i = self.BASIN_START_ROW, self.BASIN_END_ROW + 1 do
		self.y[i] = basin_bottom + (i - self.ROWS - 0.75) * stage.gem_height
	end

	for row = self.PENDING_START_ROW, self.BASIN_END_ROW + 1 do
		self[row] = {}
		for col = 0, self.COLUMNS + 1 do
			self[row][col] = {gem = nil, owner = 0}
		end
	end
end

function Grid:reset()
	for row = self.PENDING_START_ROW, self.BASIN_END_ROW + 1 do
		self[row] = {}
		for col = 0, self.COLUMNS + 1 do
			self[row][col] = {gem = false, owner = 0}
		end
	end
end

function Grid:gems()
	local gems, rows, columns, index = {}, {}, {}, 0
	for i = self.PENDING_START_ROW, self.BASIN_END_ROW + 1 do
		for j = 0, self.COLUMNS + 1 do
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

function Grid:basinGems()
	local gems, rows, columns, index = {}, {}, {}, 0
	for i = self.BASIN_START_ROW, self.BASIN_END_ROW + 1 do
		for j = 0, self.COLUMNS + 1 do
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

function Grid:pendingGems()
	local gems, rows, columns, index = {}, {}, {}, 0
	for i = self.PENDING_START_ROW, self.PENDING_END_ROW do
		for j = 0, self.COLUMNS + 1 do
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

function Grid:cols(player_num)
	local c, i = {1, 2, 3, 4, 5, 6, 7, 8}, 0
	if player_num == 1 then c = {1, 2, 3, 4} end
	if player_num == 2 then c = {8, 7, 6, 5} end
	return function()
		i = i + 1
		return c[i]
	end
end

-- sends all gems to the bottom immediately
function Grid:simulateGravity()
	for j in self:cols() do
		local sorted_column = self:columnSort(j)
		for i = 1, self.ROWS do
			self[i][j].gem = sorted_column[i]
		end
	end
end

-- place piece into simulated grid
function Grid:simulatePlacePiece(piece, coords)
	if piece.is_horizontal then
		for i = 1, #piece.gems do
			local column = coords[i]
			self[1][column].gem = piece.gems[i]
		end
	else
		for i = 1, #piece.gems do
			local column = coords[1]
			self[i][column].gem = piece.gems[i]
		end
	end
end

-- return score for simulated grid + piece placement
function Grid:simulateScore(piece, coords)
	local orig_grid = deepcpy(self)
	orig_grid:simulatePlacePiece(piece, coords)
	orig_grid:simulateGravity()
	if not orig_grid:getScore() then print ("nil score") end
	return orig_grid:getScore()
end

-- Returns a list of matches, where each match is listed as the row and column
-- of its topmost/leftmost gem, a length, and whether it's horizontal.
function Grid:_getRawMatches(min_length)
	local function getColor(row, column)
		if self[row][column].gem then
			return self[row][column].gem.color
		end
	end

	min_length = min_length or 3
	local match_colors = {"red", "blue", "green", "yellow"}
	local ret = {}
	for _, color in pairs(match_colors) do
		for _, r, c in self:gems() do
			if getColor(r, c) == color or getColor(r, c) == "wild" then
				-- HORIZONTAL MATCHES
				local match_len = 0
				-- Only start a match at the beginning of a run
				if getColor(r, c-1) ~= color and getColor(r, c-1) ~= "wild" then
					repeat
						match_len = match_len + 1
					until
						getColor(r, c+match_len) ~= color and getColor(r, c+match_len) ~= "wild"
				end
				if match_len >= min_length then
					ret[#ret+1] = {length = match_len, row = r, column = c, is_a_horizontal_match = true}
				end

				-- VERTICAL MATCHES
				--[[local]] match_len = 0
				-- Only start a match at the beginning of a run
				if getColor(r-1, c) ~= color and getColor(r-1, c) ~= "wild" then
					repeat
						match_len = match_len + 1
					until
						getColor(r+match_len, c) ~= color and getColor(r+match_len, c) ~= "wild"
				end
				if match_len >= min_length then
					ret[#ret+1] = {length = match_len, row = r, column = c, is_a_vertical_match = true}
				end
			end
		end
	end
	return ret
end

-- Returns a list of gems which are part of matches, and the total number of
-- matches (not number of matched gems).
function Grid:getMatchedGems(minimumLength)
	local matches = self:_getRawMatches(minimumLength or 3)
	local gem_set = {}

	for _, match in pairs(matches) do
		if match.is_a_horizontal_match then
			for i = 1, match.length do
				local r, c = match.row, match.column + i - 1
				local this_gem = self[r][c].gem
				if this_gem then gem_set[this_gem] = true end
			end
		elseif match.is_a_vertical_match then
			for i = 1, match.length do
				local r, c = match.row + i - 1, match.column
				local this_gem = self[r][c].gem
				if this_gem then gem_set[this_gem] = true end
			end
		else
			print("Warning: a match was created that was neither horizontal nor vertical")
		end
	end

	local gem_table = {}
	for gem in pairs(gem_set) do gem_table[#gem_table+1] = gem end

	return gem_table, #matches
end

-- same as above, but returns in the format {list1, list2, ...}
-- e.g. {{gem1, gem2, gem3}, {gem4, gem5, gem6, gem7}}
function Grid:getMatchedGemLists(min_length)
	local matches = self:_getRawMatches(min_length or 3)
	local ret = {}
	for _, match in pairs(matches) do
		local gem_list = {}
		if match.is_a_horizontal_match then
			for i = 1, match.length do
				local gem = self[match.row][match.column + i - 1].gem
				if gem then gem_list[#gem_list+1] = gem end
			end
		elseif match.is_a_vertical_match then
			for i = 1, match.length do
				local gem = self[match.row + i - 1][match.column].gem
				if gem then gem_list[#gem_list+1] = gem end
			end
		else
			print("Warning: a match was created that was neither horizontal nor vertical")
		end
		ret[#ret+1] = gem_list
	end
	return ret
end


--[[ If any gem in a set is owned by a player, make all other gems in its match
	also owned by that player (may be owned by both players).
	Call this function only once per matching, otherwise intersecting matches
	will be flagged incorrectly.
	the addOwner method adds a allow_flag_propagation flag to the gem, too, for use
	in propagating the flags upwards, in the destroyGem method.

	Also sets .is_in_a_horizontal_match and/or .is_in_a_vertical_match attributes of gems
--]]

function Grid:flagMatchedGems()
	local matches = self:_getRawMatches()
	local gem_flags = {} -- a set

	-- get gem owners
	for _, match in ipairs(matches) do
		local this_match_p1, this_match_p2 = false, false
		local gems = {}
		if match.is_a_horizontal_match then
			for i = 1, match.length do
				local row = match.row
				local column = match.column + i - 1
				local gem = self[row][column].gem
				if gem.owner == 1 then
					this_match_p1 = true
				elseif gem.owner == 2 then
					this_match_p2 = true
				elseif gem.owner == 3 then
					this_match_p1, this_match_p2 = true, true
				end
				gem.is_in_a_horizontal_match = true
				gems[#gems+1] = gem
			end
		elseif match.is_a_vertical_match then
			for i = 1, match.length do
				local row = match.row + i - 1
				local column = match.column
				local gem = self[row][column].gem

				-- special case: chain combos ignore flags from non-original gems, if opponent made a match last turn
				if self.game.scoring_combo == 0 then
					if gem.owner == 1 then
						this_match_p1 = true
					elseif gem.owner == 2 then
						this_match_p2 = true
					elseif gem.owner == 3 then
						this_match_p1, this_match_p2 = true, true
					end
				else
					if gem.flag_match_originator then
						if gem.flag_match_originator == 1 then
							this_match_p1 = true
						elseif gem.flag_match_originator == 2 then
							this_match_p2 = true
						elseif gem.flag_match_originator == 3 then
							this_match_p1, this_match_p2 = true, true
						end
					else
						--[[ TODO: This is too annoying so I'm ignoring this for now
						Ideally we should have the testVerticalCombo unit test working correctly,
						but without affecting the situation where both players do a 2 part combo
						on the same turn
						--]]
						--[[
						local ignore_p1 = not self.game.phase.matched_this_round[1]
						local ignore_p2 = not self.game.phase.matched_this_round[2]
						if ignore_p1 and not ignore_p2 then
							if gem.owner == 2 or gem.owner == 3 then this_match_p2 = true end
						elseif ignore_p2 and not ignore_p1 then
							if gem.owner == 1 or gem.owner == 3 then this_match_p1 = true end
						end
						--]]
						if gem.owner == 1 then
							this_match_p1 = true
						elseif gem.owner == 2 then
							this_match_p2 = true
						elseif gem.owner == 3 then
							this_match_p1, this_match_p2 = true, true
						end
					end
				end
				gem.is_in_a_vertical_match = true
				gems[#gems+1] = gem
			end
		else
			print("Warning: a match was created which was neither a horizontal nor vertical match")
		end

		-- calculate new flags
		local player_num = 0
		if this_match_p1 then
			player_num = player_num + 1
		end
		if this_match_p2 then
			player_num = player_num + 2
		end

		-- store flags
		for _, gem in pairs(gems) do
			if gem_flags[gem] then
				if gem_flags[gem] == 0 then
					print("This shouldn't happen")
				elseif gem_flags[gem] == 1 then
					if player_num == 2 or player_num == 3 then gem_flags[gem] = 3 end
				elseif gem_flags[gem] == 2 then
					if player_num == 1 or player_num == 3 then gem_flags[gem] = 3 end
				else
					print("This shouldn't happen either")
				end
			else
				gem_flags[gem] = player_num
			end
		end
	end

	-- apply the flags
	for gem, player_num in pairs(gem_flags) do gem:setOwner(player_num, true) end
end

--[[ Any gems placed in the action phase will be considered an "original" gem.
	The purpose is for correct attribution of flags for follow-on vertical
	matches: Followup vertical matches ignore ownership flags for gems without
	this flag.
	This flag is cleared for any player who didn't make a match in the previous
	round.
--]]
function Grid:assignGemOriginators()
	for gem in self:pendingGems() do gem.flag_match_originator = gem.owner end
end

function Grid:removeGemOriginators()
	for gem in self:gems() do gem.flag_match_originator = nil end
end

-- get score of simulated piece placements
function Grid:getScore(matching_number)
	return #self:getMatchedGems(matching_number or 3)
end

function Grid:removeAllGemOwners(player)
	for gem in self:gems() do gem:removeOwner(player) end
end

function Grid:setAllGemOwners(flag_num)
	for gem in self:gems() do gem:setOwner(flag_num) end
end

function Grid:setAllGemReadOnlyFlags(bool)
	for gem in self:gems() do gem:setProtectedFlag(bool) end
end

-- ignore_pending boolean will return the first empty row ignoring pending gems
function Grid:getFirstEmptyRow(column, ignore_pending)
	if column then
		local empty_spaces = ignore_pending and 12 or 0 -- pending cols as empty
		local start_row = ignore_pending and 13 or 1
		for i = start_row, self.BOTTOM_ROW do
			if not self[i][column].gem then empty_spaces = empty_spaces + 1 end
		end
		return empty_spaces
	end
end

-- Returns a piece's landing locations as a table of {{column, row}, {c,r}}.
-- optional_shift is +1/-1, used if the gem is over midline and column needs to be
-- corrected.
function Grid:getDropLocations(piece, optional_shift)
	local column = piece:getColumns(optional_shift)
	local row, ret = {}, {}
	for i = 1, piece.size do
		row[i] = self:getFirstEmptyRow(column[i])
		if not piece.is_horizontal and row[i] then
			row[i] = row[i] - piece.size + i
		end
		ret[i] = {column[i], row[i]}
	end
	return ret
end

function Grid:getPermittedColors(column, banned_color1, banned_color2)
	local avail_color = {"red", "blue", "green", "yellow"}
	local ban1 = false
	local ret = {}
	if self[self.ROWS - 1][column].gem then
		ban1 = self[self.ROWS - 1][column].gem.color
	end
	for i = 1, 4 do
		if ban1 ~= avail_color[i] and banned_color1 ~= avail_color[i]
		and banned_color2 ~= avail_color[i] then
			ret[#ret+1] = avail_color[i]
		end
	end
	return ret
end

-- Returns a string representing the color of the gem generated
function Grid:generate1by1(column, banned_color1, banned_color2)
	local row = self.BOTTOM_ROW
	local avail_colors = self:getPermittedColors(column, banned_color1, banned_color2)
	local legal_gems = {}
	for _, color in ipairs(avail_colors) do legal_gems[color] = 1 end
	local make_color = Gem.random(self.game, legal_gems)

	local new_gem = Gem:create{
		game = self.game,
		x = self.x[column],
		y = self.y[row],
		color = make_color,
		is_garbage = true,
	}

	new_gem.transparency = 0
	new_gem:wait(self.game.GEM_EXPLODE_FRAMES)
	new_gem:change{duration = 0, transparency = 255}

	self[row][column].gem = new_gem
	return make_color
end

-- move a gem from a spot on the grid to another spot
-- state only, doesn't change the gem x and gem y, use moveGemAnim for that
function Grid:moveGem(gem, new_row, new_column)
	if self[new_row][new_column].gem then print("Warning: attempt to move gem to location with existing gem") end
	self[new_row][new_column].gem = gem
	self[gem.row][gem.column].gem = false
	gem.row, gem.column = new_row, new_column
end

-- animation part of moving gem to a row/column
-- can call this from player functions
function Grid:moveGemAnim(gem, row, column)
	local target_x, target_y = self.x[column], self.y[row]
	local dist = ((target_x - gem.x) ^ 2 + (target_y - gem.y) ^ 2) ^ 0.5
	--local angle = math.atan2(target_y - gem.y, target_x - gem.x)
	local speed = self.DROP_SPEED + self.DROP_MULTIPLE_SPEED * self.game.scoring_combo
	local duration = math.abs(dist / speed)
	local exit_func = target_y > gem.y and {gem.landedInGrid, gem} or nil

	gem:change{
		x = target_x,
		y = target_y,
		duration = duration,
		exit_func = exit_func,
		-- only call landing function if it was moving downwards
	}
	return duration
end

function Grid:moveAllUp(player, rows_to_add)
-- Moves all gems in the player's half up by rows_to_add.
	local last_row = self.ROWS - rows_to_add
	local max_anim_duration = 0
	for r = 1, last_row do
		for c in self:cols(player.player_num) do
			self[r][c].gem = self[r+rows_to_add][c].gem
			if self[r][c].gem then
				local duration = self:moveGemAnim(self[r][c].gem, r, c)
				max_anim_duration = math.max(max_anim_duration, duration)
				self[r][c].gem.row = r
				self[r][c].gem.column = c
			end
		end
	end
	for i = last_row + 1, self.ROWS do
		for j in self:cols(player.player_num) do
			self[i][j].gem = false
		end
	end
	return max_anim_duration
end

--[[ Returns a list of gem colors generated. List is in the order for
	{col 1, 2, 3, 4} for player 1, {col 8, 7, 6, 5} for player 2
--]]
function Grid:addBottomRow(player, skip_animation)
	local game = self.game
	local grid = game.grid
	local particles = game.particles
	local generated_gems = {}

	self:moveAllUp(player, 1)
	local step = player.player_num == 1 and 1 or -1

	for col in grid:cols(player.player_num) do
		local ban1, ban2 = false, false
		if col > game.p1.start_col and col < game.p2.end_col then
			local prev_col = (col - step)
			local next_col = (col + step)
			ban1 = self[self.ROWS][prev_col].gem.color
			if self[self.ROWS][next_col].gem then
				ban2 = self[self.ROWS][next_col].gem.color
			end
		end
		local gem_color = self:generate1by1(col, ban1, ban2, player.enemy)
		generated_gems[#generated_gems+1] = gem_color

		if not skip_animation then
			local x = grid.x[col]
			local y = grid.y[grid.BOTTOM_ROW]
			local pop_image = image["gems_pop_" .. gem_color]
			local explode_image = image["gems_explode_"..gem_color]

			particles.dust.generateGarbageCircle{game = game, x = x, y = y,
				color = gem_color}
			particles.popParticles.generateReversePop{game = game, x = x,
				y = y, image = pop_image}
			local explode_time = particles.explodingGem.generateReverseExplode{
				game = game, x = x, y = y, image = explode_image, shake = true}
			particles.dust.generateBigFountain{game = game, x = x, y = y,
				color = gem_color, delay_frames = explode_time}
		end
	end

	if player.garbage_rows_created > player.enemy.garbage_rows_created then
		self:setAllGemOwners(player.enemy.player_num)
	end

	game.sound:newSFX("trashrow")
	return generated_gems
end

function Grid:isSettled()
	local all_unmoved = true
	for gem in self:gems() do
		if not gem:isStationary() then all_unmoved = false end
	end
	if all_unmoved then self:updateGrid() end
	return all_unmoved
end

function Grid:columnSort(column_num)
	local column = {}
	for i = 1, self.ROWS do
		column[i] = self[i][column_num].gem
	end
	for i = self.ROWS, 1, -1 do
		 if not column[i] then
			 table.remove(column, i)
		 end
	end
	for _ = 1, self.ROWS - #column do
		table.insert(column, 1, false)
	end
	return column
end

-- creates the grid after gems have fallen, and shows animation by default
-- Set skip_animation to true to not show animation
function Grid:dropColumns(params)
	params = params or {}
	for c in self:cols() do
		local sorted_column = self:columnSort(c)
		for r = 1, self.ROWS do
			self[r][c].gem = sorted_column[r]
			local cell = self[r][c].gem
			if cell then cell.row, cell.column = r, c end
		end
	end

	local max_anim_duration = 0
	if not params.skip_animation then
		for gem, r, c in self:gems() do
			if gem and (gem.y ~= self.y[r] or gem.x ~= self.x[c]) then
				local duration = self:moveGemAnim(gem, r, c)
				max_anim_duration = math.max(max_anim_duration, duration)
			end
		end
	end
	return max_anim_duration
end

function Grid:getPendingGems(player)
	local ret = {}
	local col_start, col_end = 1, 4
	if player.ID == "P2" then col_start, col_end = 5, 8 end
	for gem, r, c in self:gems() do
		if r <= 6 and c >= col_start and gem.column <= col_end then
			ret[#ret+1] = gem
		end
	end
	return ret
end

function Grid:getPendingGemsByNum(player_num)
	player_num = player_num or 3
	local ret = {}
	local col_start, col_end
	if player_num == 1 then
		col_start, col_end = 1, 4
	elseif player_num == 2 then
		col_start, col_end = 5, 8
	elseif player_num == 3 then
		col_start, col_end = 1, 8
	end
	for gem, r, c in self:gems() do
		if r <= 6 and c >= col_start and gem.column <= col_end then
			ret[#ret+1] = gem
		end
	end
	return ret
end


function Grid:getIDs()
-- returns the ID, column, row of all gems in the basin
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

function Grid:updateGravity(dt) -- animation only
	if self.game.grid_wait == 0 then
		for gem in self:gems() do gem:update(dt) end -- move gems to new positions
	end
end

function Grid:updateGrid()
	for row = self.PENDING_START_ROW, self.BASIN_END_ROW + 1 do
		for col = 0, self.COLUMNS + 1 do
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

-- If the only pieces placed are a rush and a normal, reverse their falling order
function Grid:updateRushPriority()
	local normal_pieces, rush_pieces = 0, 0
	for player in self.game:players() do
		if player.place_type == "normal" then
			normal_pieces = normal_pieces + 1
		elseif player.place_type == "rush" then
			rush_pieces = rush_pieces + 1
		end
	end

	-- it's tricky to move them because of overlap
	if normal_pieces == 1 and rush_pieces == 1 then
		local normal_gems, rush_gems = {}, {}

		-- store the gems and delete from grid first
		for gem in self:pendingGems() do
			if gem.row == 3 or gem.row == 4 then
				rush_gems[#rush_gems+1] = gem
				self[gem.row][gem.column].gem = false
				gem.row = gem.row + 2
				gem.y = self.y[gem.row]
			elseif gem.row == 5 or gem.row == 6 then
				normal_gems[#normal_gems+1] = gem
				self[gem.row][gem.column].gem = false
				gem.row = gem.row - 2
				gem.y = self.y[gem.row]
			end
		end

		-- place them back in grid
		for _, gem in ipairs(normal_gems) do self[gem.row][gem.column].gem = gem end
		for _, gem in ipairs(rush_gems) do self[gem.row][gem.column].gem = gem end
	end

end

-- Which players made a match this turn
function Grid:checkMatchedThisTurn()
	local gem_table = self:getMatchedGems()
	local matched = {false, false}
	for i = 1, #gem_table do
		local owner = gem_table[i].owner
		if owner == 1 or owner == 3 then
			matched[1]  = true
		end
		if owner == 2 or owner == 3 then
			matched[2] = true
		end
	end
	return matched
end

-- adds an extra combo_bonus of damage, up to a maximum of double damage
function Grid:destroyMatchedGems(combo_bonus)
	local p1_remaining_damage, p2_remaining_damage = combo_bonus, combo_bonus

	for _, gem in pairs(self:getMatchedGems()) do
		local extra_damage = 0
		if p1_remaining_damage > 0 and gem.owner == 1 then
			extra_damage = 1
			p1_remaining_damage = p1_remaining_damage - 1
		elseif p2_remaining_damage > 0 and gem.owner == 2 then
			p2_remaining_damage = p2_remaining_damage - 1
			extra_damage = 1
		end

		local gain_super = nil
		local owner = self.game:playerByIndex(gem.owner)
		if owner then gain_super = owner.gain_super_meter end

		self:destroyGem{
			gem = gem,
			extra_damage = extra_damage,
			super_meter = gain_super,
		}
	end
end

-- removes a gem from the grid, and plays all of the associated animations
--[[ TODO: Takes a table of:
	gem: gem to destroy
	super_meter: optional if false, don't build super meter
	damage: optional if false, don't deal damage
	extra_damage: optional how much extra damage to do
	credit_to: optional player_num (to deal damage to player_num's opponent)
	glow_delay: optional extra frames to stay in full-glow phase
	propagate_flags_up: optionally credit above gems to owner. Default true
	force_max_alpha: optional force gem image to be bright
--]]
function Grid:destroyGem(params)
	local game = self.game
	local particles = game.particles
	local gem = params.gem
	local extra_damage = params.extra_damage or 0
	local glow_delay = params.glow_delay or 0
	local delay_until_explode = game.GEM_EXPLODE_FRAMES + glow_delay
	if gem.is_destroyed then return end
	if gem.indestructible then return end
	if params.credit_to then gem:setOwner(params.credit_to) end

	local player = game:playerByIndex(gem.owner)
	if player == nil then -- grey gem
		local sfx = game.sound:newSFX("gembreakgrey")
		sfx:setPosition((gem.column - 4.5) * 0.02, 0, 0)
	else
		-- state
		if params.damage ~= false then
			player.enemy:addDamage(1 + extra_damage, delay_until_explode)
		end
		if params.super_meter ~= false then
			assert(player.meter_gain[gem.color], "Nil value found when looking up super meter gain!")
			player:addSuper(player.meter_gain[gem.color])
		end
		game.queue:add(delay_until_explode, game.ui.screenshake, game.ui, 1)

		-- animations
		local soundfile_name = "gembreak" .. math.min(5, game.scoring_combo + 1)
		game.queue:add(delay_until_explode, game.sound.newSFX, game.sound, soundfile_name)

		if params.super_meter ~= false then
			local num = player.supering and 0 or player.meter_gain[gem.color]
			particles.superParticles.generate(game, gem, num, delay_until_explode, params.force_max_alpha)
		end

		if params.damage ~= false then
			particles.damage.generate(game, gem, delay_until_explode, params.force_max_alpha)
			for _ = 1, extra_damage do
				particles.damage.generate(game, gem, delay_until_explode, params.force_max_alpha)
			end
		end

		particles.dust.generateBigFountain{
			game = game,
			gem = gem,
			delay_frames = delay_until_explode,
			force_max_alpha = params.force_max_alpha,
		}

		particles.popParticles.generate{
			game = game,
			gem = gem,
			delay_frames = game.GEM_EXPLODE_FRAMES,
			glow_duration = glow_delay,
			force_max_alpha = params.force_max_alpha,
		}
	end

	-- animations
	particles.explodingGem.generate{
		game = game,
		gem = gem,
		glow_duration = glow_delay,
		force_max_alpha = params.force_max_alpha
	}
	particles.gemImage.generate{
		game = game,
		gem = gem,
		duration = delay_until_explode,
		force_max_alpha = params.force_max_alpha
	}

	-- flag above gems
	if params.propagate_flags_up ~= false then
		for i = gem.row - 1, 1, -1 do
			local current_gem = self[i][gem.column].gem
			if current_gem then
				 -- skip propagation if this gem was part of (another) match
				if not current_gem.set_due_to_match then
					current_gem:setOwner(gem.owner)
				end
			end
		end
	end

	-- state
	gem.is_destroyed = true -- in case we try to destroy it again
	self[gem.row][gem.column].gem = false

	return delay_until_explode
end

function Grid:setGarbageMatchFlags(diff)
	if diff == 0 then
		self:setAllGemOwners(3)
	elseif diff < 0 then
		self:setAllGemOwners(1)
	elseif diff > 0 then
		self:setAllGemOwners(2)
	end
end

function Grid:calculateScore()
	local gem_table = self:getMatchedGems()
	local dmg, super = {0, 0}, {0, 0}
	for i = 1, #gem_table do
		if gem_table[i].owner ~= 3 then
			local gem, own_idx = gem_table[i], gem_table[i].owner
			local owner = self.game:playerByIndex(own_idx)
			dmg[own_idx] = dmg[own_idx] + 1
			super[own_idx] = super[own_idx] + owner.meter_gain[gem.color]
		end
	end
	for player in self.game:players() do
		local i = player.player_num
		if dmg[i] > 0 then dmg[i] = dmg[i] + self.game.scoring_combo - 1 end
		if player.supering then super[i] = 0 end
	end
	return dmg[1], dmg[2], super[1], super[2]
end

function Grid:getLoser()
	local p1loss, p2loss = false, false
	for i = 1, self.COLUMNS do
		local empty_row = self:getFirstEmptyRow(i)
		if empty_row < self.LOSE_ROW then
			if i <= 4 then p1loss = true else p2loss = true end
		end
	end

	if p1loss and p2loss then
		return 3
	elseif p1loss then
		return 1
	elseif p2loss then
		return 2
	end
	return
end

function Grid:animateGameOver(loser_num)
	local game = self.game
	local particles = game.particles
	local EACH_ROW_DELAY = 5

	particles.words.generateGameOverThanks(game)

	for row = 20, 5, -1 do
		local delay = (20 - row) * EACH_ROW_DELAY + 1
		local duration = game.phase.GAMEOVER_DELAY

		for col in game.grid:cols(loser_num) do
			if self[row][col].gem then
				local gem = self[row][col].gem
				local img
				if gem.color == "red" or gem.color == "blue" or	gem.color == "green" or
				gem.color == "yellow" then
					img = image["gems_grey_" .. gem.color]
				else
					img = gem.grey_exploding_gem_image
					assert(img, "No grey gem image found for grey_exploding_gem_image")
				end
				particles.gemImage.generate{game = game, x = gem.x, y = gem.y, image = img,
					duration = duration, delay_frames = delay}
			end
		end
	end
end

function Grid:clearGameOverAnims()
	self.game.particles.gemImage.removeAll(self.game.particles)
end

return common.class("Grid", Grid)
