local image = require 'image'
local common = require "class.commons"
local Gem = require "gem"

local deepcpy = require "utilities".deepcpy

local Grid = {}

local window = _G.window -- TODO: Remove global
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
Row 21: bottom grid row where trash gems tween from.
--]]
function Grid:init(game)
	self.LOSE_ROW = 12 -- game over if a gem ends the turn in this row or above
	self.RUSH_ROW = 14 -- can only rush if this row is empty
	self.BOTTOM_ROW = 20 -- used for garbage appearance
	
	local stage = game.stage
	local tub_bottom = stage.height * 0.95
	self.game = game
	self.columns = 8
	self.rows = 20
	self.x = {}
	self.y = {}
	self.active_rect = {}

	for i = 0, self.columns + 1 do
		self.x[i] = stage.x_mid + (i - (self.columns / 2) - 0.5) * stage.gem_width
		self.active_rect[i] = {self.x[i] - 0.5 * stage.gem_width, 0, stage.gem_width, stage.height}
	end

	-- pending gem positions
	for i = 1, 6 do self.y[i] = stage.gem_height * (i - 8) end

	-- landing gem positions
	self.y[7] = tub_bottom - 11.75 * stage.gem_height
	self.y[8] = tub_bottom - 10.75 * stage.gem_height
	self.y[9] = tub_bottom - 10.75 * stage.gem_height
	self.y[10] = tub_bottom - 9.75 * stage.gem_height
	self.y[11] = tub_bottom - 9.75 * stage.gem_height
	self.y[12] = tub_bottom - 8.75 * stage.gem_height

	-- basin positions
	for i = 13, self.rows + 1 do
		self.y[i] = tub_bottom + (i - self.rows - 0.75) * stage.gem_height
	end

	for row = 1, self.rows + 1 do
		self[row] = {}
		for col = 0, self.columns + 1 do
			self[row][col] = {gem = nil, owner = 0}
		end
	end
end

function Grid:reset()
	for row = 0, self.rows + 1 do
		self[row] = {}
		for col = 0, self.columns + 1 do
			self[row][col] = {gem = false, owner = 0}
		end
	end
end

function Grid:gems()
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

-- sends all gems to the bottom immediately
function Grid:simulateGravity()
	for j = 1, self.columns do
		local sorted_column = self:columnSort(j)
		for i = 1, self.rows do
			self[i][j].gem = sorted_column[i]
		end
	end
end

-- place piece into simulated grid
function Grid:simulatePlacePiece(piece, coords)
	if piece.horizontal then
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
function Grid:getMatches(minimumLength)
	local function getColor(row, column)
		return self[row][column].gem and self[row][column].gem.color
	end

	minimumLength = minimumLength or 3
	local match_colors = {"red", "blue", "green", "yellow"}
	local ret = {}
	for _, c in pairs(match_colors) do
		for _, row, column in self:gems() do
			if tostring(getColor(row, column)):lower() == c then
				-- HORIZONTAL MATCHES
				local matchLength = 0
				if tostring(getColor(row, column - 1)):lower() ~= c then	-- Only start a match at the beginning of a run
					repeat
						matchLength = matchLength + 1
					until tostring(getColor(row, column + matchLength)):lower() ~= c
				end
				if matchLength >= minimumLength then
					ret[#ret+1] = {length = matchLength, row = row, column = column, horizontal = true}
				end

				-- VERTICAL MATCHES
				--[[local]] matchLength = 0
				if tostring(getColor(row - 1, column, self)):lower() ~= c then -- Only start a match at the beginning of a run
					repeat
						matchLength = matchLength + 1
					until tostring(getColor(row + matchLength, column, self)):lower() ~= c
				end
				if matchLength >= minimumLength then
					ret[#ret+1] = {length = matchLength, row = row, column = column, horizontal = false}
				end
			end
		end
	end
	return ret
end

-- Returns a list of gems which are part of matches, and the total number of
-- matches (not number of matched gems).
function Grid:getMatchedGems(minimumLength)
	local matches = self:getMatches(minimumLength or 3)
	local gem_set = {}

	for _, match in pairs(matches) do
		if match.horizontal then
			for i = 1, match.length do
				local r, c = match.row, match.column + i - 1
				local this_gem = self[r][c].gem
				if this_gem then
					gem_set[this_gem] = true
					this_gem.horizontal = true
				end
			end
		else
			for i = 1, match.length do
				local r, c = match.row + i - 1, match.column
				local this_gem = self[r][c].gem
				if this_gem then
					gem_set[this_gem] = true
					this_gem.vertical = true
				end
			end
		end
	end

	local gem_table = {}
	for gem, _ in pairs(gem_set) do gem_table[#gem_table+1] = gem end

	return gem_table, #matches
end

-- If any gem in a set is owned by a player, make all other gems in its match
-- also owned by that player (may be owned by both players).
function Grid:flagMatchedGems()
	local matches = self:getMatches()
	for i = 1, #matches do
		local p1flag, p2flag = false, false
		if matches[i].horizontal then
			-- Check whether p1 or p2 own any of the gems in this match
			for j = 1, matches[i].length do
				local row = matches[i].row
				local column = matches[i].column + (j-1)
				if self[row][column].gem.owner == 1 then p1flag = true end
				if self[row][column].gem.owner == 2 then p2flag = true end
				if self[row][column].gem.owner == 3 then p1flag = true p2flag = true end
			end
			-- Propagate owners to all gems in the match
			for j = 1, matches[i].length do
				local row = matches[i].row
				local column = matches[i].column + (j-1)
				if p1flag then self[row][column].gem:addOwner(self.game.p1) end
				if p2flag then self[row][column].gem:addOwner(self.game.p2) end
			end
		else
			-- Check whether p1 or p2 own any of the gems in this match
			for j = 1, matches[i].length do
				local row = matches[i].row + (j-1)
				local column = matches[i].column
				if self[row][column].gem.owner == 1 then p1flag = true end
				if self[row][column].gem.owner == 2 then p2flag = true end
				if self[row][column].gem.owner == 3 then p1flag = true p2flag = true end
			end
			-- Propagate owners to all gems in the match
			for j = 1, matches[i].length do
				local row = matches[i].row + (j-1)
				local column = matches[i].column
				if p1flag then self[row][column].gem:addOwner(self.game.p1) end
				if p2flag then self[row][column].gem:addOwner(self.game.p2) end
			end
		end
	end
end

-- get score of simulated piece placements
function Grid:getScore(matching_number)
	return #self:getMatchedGems(matching_number or 3)
end

function Grid:removeAllGemOwners(player)
	for gem in self:gems() do gem:removeOwner(player) end
end

function Grid:setAllGemOwners(flag_num)
	for gem in self:gems() do gem.owner = flag_num end
end

function Grid:getFirstEmptyRow(column)
	if column then
		local empty_spaces = 0
		for i = 1, self.rows do
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
		if not piece.horizontal and row[i] then
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
	if self[self.rows - 1][column].gem then
		ban1 = self[self.rows - 1][column].gem.color
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
	local row = self.rows -- grid.rows is the row underneath the bottom row
	local avail_colors = self:getPermittedColors(column, banned_color1, banned_color2)
	local all_gems = {
		{color = "red", freq = 1},
		{color = "blue", freq = 1},
		{color = "green", freq = 1},
		{color = "yellow", freq = 1}
	}
	local legal_gems = {}
	for i = 1, 4 do
		for j = 1, #avail_colors do
			if all_gems[i].color == avail_colors[j] then
				legal_gems[#legal_gems+1] = all_gems[i]
			end
		end
	end
	local make_color = Gem.random(self.game, legal_gems)
	local distance = self.y[row+1] - self.y[row]
	local speed = self.DROP_SPEED + self.DROP_MULTIPLE_SPEED * self.game.scoring_combo
	local duration = distance / speed

	self[row][column].gem = common.instance(Gem, self.game, self.x[column], self.y[row+1], make_color, true)
	self[row][column].gem:change{x = self.x[column], y = self.y[row], duration = duration}
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
	gem:change{
		x = target_x,
		y = target_y,
		duration = duration,
		exit = target_y > gem.y and {gem.landedInGrid, gem} or nil
		-- only call landing function if it was moving downwards
	}
end

function Grid:moveAllUp(player, rows_to_add)
-- Moves all gems in the player's half up by rows_to_add.
	local last_row = self.rows - rows_to_add
	local start_col, end_col = 1, 4
	if player.ID == "P2" then start_col, end_col = 5, 8 end
	for r = 1, last_row do
		for c = start_col, end_col do
			self[r][c].gem = self[r+rows_to_add][c].gem
			if self[r][c].gem then
				self:moveGemAnim(self[r][c].gem, r, c)
				self[r][c].gem.row = r
				self[r][c].gem.column = c
			end
		end
	end
	for i = last_row + 1, self.rows do
		for j = start_col, end_col do
			self[i][j].gem = false
		end
	end
end

--[[ Returns a list of gem colors generated. List is in the order for
	{col 1, 2, 3, 4} for player 1, {col 8, 7, 6, 5} for player 2
	Not used now, but could be useful later maybe --]]
function Grid:addBottomRow(player, skip_animation)
	local game = self.game
	local grid = game.grid
	local particles = game.particles
	local generated_gems = {}

	self:moveAllUp(player, 1)
	local start, finish, step = game.p1.start_col, game.p1.end_col, 1
	if player.ID == "P2" then
		start, finish, step = game.p2.end_col, game.p2.start_col, -1
	end
	for col = start, finish, step do
		local ban1, ban2 = false, false
		if col > game.p1.start_col and col < game.p2.end_col then
			local prev_col = (col - step)
			local next_col = (col + step)
			ban1 = self[self.rows][prev_col].gem.color
			if self[self.rows][next_col].gem then
				ban2 = self[self.rows][next_col].gem.color
			end
		end
		local gem_color = self:generate1by1(col, ban1, ban2, player.enemy)
		generated_gems[#generated_gems+1] = gem_color

		if not skip_animation then
			local x = grid.x[col]
			local y = grid.y[grid.BOTTOM_ROW]
			local pop_image = image.lookup.pop_particle[gem_color]
			local explode_image = image.lookup.gem_explode[gem_color]

			particles.popParticles.generateReversePop{game = game, x = x,
				y = y, image = pop_image}
			particles.explodingGem.generateReverseExplode{game = game, x = x,
				y = y, image = explode_image, shake = true}

			--particles appear randomly in a circle about 48 pixel radius from where the gem will spawn.
			--Also spray some dust
			-- particles.dust.generateBigFountain{game = game, x = x, y = y, color = gem_color, num = 24, duration = game.GEM_EXPLODE_FRAMES}
		end		
	end

	if player.garbage_rows_created > player.enemy.garbage_rows_created then
		self:setAllGemOwners(player.enemy.player_num)
	end

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

-- creates the grid after gems have fallen, and shows animation by default
-- Set skip_animation to true to not show animation
function Grid:dropColumns(params)
	params = params or {}
	for c = 1, self.columns do
		local sorted_column = self:columnSort(c)
		for r = 1, self.rows do
			self[r][c].gem = sorted_column[r]
			local cell = self[r][c].gem
			if cell then cell.row, cell.column = r, c end
		end
	end

	if not params.skip_animation then
		for gem, r, c in self:gems() do
			if gem and (gem.y ~= self.y[r] or gem.x ~= self.x[c]) then
				self:moveGemAnim(gem, r, c)
			end
		end
	end
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

function Grid:getIDs()
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

function Grid:updateGravity(dt)
	if self.game.grid_wait == 0 then
		for gem in self:gems() do gem:update(dt) end -- move gems to new positions
	end
end

function Grid:updateGrid()
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

-- If the only pieces placed are a rush and a normal, reverse their falling order
function Grid:updateRushPriority()
	print("Update rush priority!")
	--check p1 place type, p2 place type
end

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
		self:destroyGem{gem = gem, extra_damage = extra_damage}
	end
end

-- removes a gem from the grid, and plays all of the associated animations
--[[ TODO: Takes a table of:
	gem: gem to destroy
	extra_damage: how much extra damage to do
	super_meter: if false, don't build super meter
	damage: if false, don't deal damage
--]]
function Grid:destroyGem(params)
	local gem = params.gem
	local extra_damage = params.extra_damage or 0
	local game = self.game
	local particles = game.particles
	local player = game:playerByIndex(gem.owner)

	if player == nil then -- grey gem
		local sfx = game.sound:newSFX("sfx_gembreakgrey")
		sfx:setPosition((gem.column - 4.5) * 0.02, 0, 0)
	else
		-- state
		local super_to_add = player.meter_gain[gem.color]
		if super_to_add == nil then print("Nil value found when looking up super meter gain!") end
		player.enemy:addDamage(1 + extra_damage)
		game.queue:add(game.GEM_EXPLODE_FRAMES, player.addSuper, player, super_to_add)
		game.queue:add(game.GEM_EXPLODE_FRAMES, game.ui.screenshake, game.ui, 1)

		-- animations
		local soundfile_name = "sfx_gembreak" .. math.min(5, game.scoring_combo + 1)
		local sfx = game.sound:newSFX(soundfile_name)
		sfx:setPosition((gem.column - 4.5) * 0.02, 0, 0)
		local num_super_particles = player.supering and 0 or player.meter_gain[gem.color]
		particles.superParticles.generate(game, gem, num_super_particles, game.GEM_EXPLODE_FRAMES)
		particles.damage.generate(game, gem, game.GEM_EXPLODE_FRAMES)
		particles.popParticles.generate{game = game, gem = gem, delay_frames = game.GEM_EXPLODE_FRAMES}
		particles.dust.generateBigFountain(game, gem, 24, game.GEM_EXPLODE_FRAMES)	
		for i = 1, extra_damage do particles.damage.generate(game, gem, game.GEM_EXPLODE_FRAMES) end
	end

	particles.explodingGem.generate{game = game, gem = gem}

	-- remove gem
	if params.propogate_flags_up ~= false then
		local above_gems = {}
		for i = (gem.row or 1), 1, -1 do
			if self[i][gem.column].gem then
				self[i][gem.column].gem:setOwner(gem.owner)
			end
		end
	end

	particles.gemImage.generate{game = game, gem = gem, duration = game.GEM_EXPLODE_FRAMES}
	self[gem.row][gem.column].gem = false
end

function Grid:setGarbageMatchFlags()
	local garbage_diff = self.game.p1.garbage_rows_created - self.game.p2.garbage_rows_created
	if garbage_diff == 0 then
		self:setAllGemOwners(0)
	elseif garbage_diff < 0 then
		self:setAllGemOwners(1)
	elseif garbage_diff > 0 then
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
	for i = 1, self.columns do
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

	local start_col, end_col
	if loser_num == 1 then
		start_col, end_col = 1, 4
	elseif loser_num == 2 then
		start_col, end_col = 5, 8
	elseif loser_num == 3 then
		start_col, end_col = 1, 8
	else
		print("craps")
	end

	particles.words.generateGameOverThanks(game)

	for row = 20, 5, -1 do
		local delay = (20 - row) * EACH_ROW_DELAY + 1
		local duration = game.phase.INIT_GAMEOVER_PAUSE

		for col = start_col, end_col do
			if self[row][col].gem then
				local gem = self[row][col].gem
				local img = image.lookup.gem_explode[gem.color .. "_grey"]
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
