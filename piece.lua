local love = _G.love

require 'inits' -- ID
local common = require "class.commons"
local tween = require 'tween'
local Pic = require 'pic'
local Gem = require "gem"

local reverseTable = require "utilities".reverseTable
local pointIsInRect = require "utilities".pointIsInRect

local function updatePieceGems(self)
	if self.horizontal then
		for i = 1, self.size do
			self.gems[i].x =
				self.x
				- (self.gems[i].width / 2) * (self.size - 1)
				+ (i - 1) * self.gems[i].width
			self.gems[i].y = self.y
		end
	else
		for i = 1, self.size do
			self.gems[i].x = self.x
			self.gems[i].y =
				self.y
				- (self.gems[i].height / 2) * (self.size - 1)
				+ (i - 1) * self.gems[i].height
		end
	end
end

local Piece = {}
function Piece:init(game, tbl)
	self.game = game

	ID.piece = ID.piece + 1
	local tocopy = {"x", "y", "owner", "gem_table"}
	for i = 1, #tocopy do
		local item = tocopy[i]
		self[item] = tbl[item]
		if tbl[item] == nil and item ~= "gem_table" then
			print("No " .. item .. " received!")
		end
	end
	self.ID = ID.piece
	self.size = self.size or 2
	self.gem_table = self.gem_table or {
		{color = "red", freq = 1},
		{color = "blue", freq = 1},
		{color = "green", freq = 1},
		{color = "yellow", freq = 1}
	}
	self.rotation = 0
	self.rotation_index = 0
	self.horizontal = true
	self.gems = {}
	self:addGems(self.gem_table)
	self.getx = self.owner.hand.getx
	self.hand_idx = tbl.hand_idx
end

function Piece:screenshake(frames)
	self.shake = frames or 6
end

function Piece:addGems(gem_table)
	for i = 1, self.size do
		local gem_color = Gem.random(self.game, gem_table)
		self.gems[i] = common.instance(Gem, self.game, self.x, self.y, gem_color)
	end
	updatePieceGems(self)
end

function Piece:change(target)
	self.queued_moves = self.queued_moves or {}
	Pic.change(self, target)
	updatePieceGems(self)
end

function Piece:resolve()
	Pic.resolve(self)
end

function Piece:wait(frames)
	Pic.wait(self, frames)
end

function Piece:update(dt)
	Pic.update(self, dt)
	if self.shake then
		self.shake = self.shake - 1
		if self.shake == 0 then self.shake = nil end
	end
	if self._rotateTween then
		local complete = self._rotateTween:update(dt)
		if complete then self._rotateTween = nil end
	end
end

function Piece:isStationary()
	return not self.move_func
end

function Piece:rotate()
	if self._rotateTween then self._rotateTween:set(math.huge) end

	self.horizontal = not self.horizontal
	if self.horizontal then
		self.gems = reverseTable(self.gems)
	end
	self.rotation_index = (self.rotation_index + 1) % 4
	updatePieceGems(self)
	self.rotation = self.rotation % (2 * math.pi)

	--[[ piece has already rotated pi/2 clockwise. But we show
		the piece from its original starting location --]]
	local new_rotation = self.rotation
	self.rotation = self.rotation - (0.5 * math.pi)
	self._rotateTween = tween.new(1, self, {rotation = new_rotation}, 'outExpo')

	self.game.sound:newSFX("sfx_gemrotate")
end

function Piece:breakUp()
	local player = self.owner
	for i = 0, player.hand_size do
		if self == player.hand[i].piece then
			Pic.clear(self)
			player.hand[i].piece = nil
		end
	end
	return self.gems -- we can store these in a dying_actors thing
end

-- draw gems with displacement depending on piece horizontal/vertical
function Piece:draw()
	local frame = self.game.frame
	local stage = self.game.stage
	--screen shake translation
	local h_shake, v_shake = 0, 0
	if self.shake then
		h_shake = math.floor(self.shake * (frame % 7 / 2 + frame % 13 / 4 + frame % 23 / 6 - 5))
		v_shake = math.floor(self.shake * (frame % 5 * 2/3 + frame % 11 / 4 + frame % 17 / 6 - 5))
	end

	love.graphics.push("all")
		love.graphics.translate(h_shake, v_shake)
		for i = 1, self.size do
			local displace_x, displace_y = 0, 0
			if self.horizontal then
				displace_x = stage.gem_width * (i - (1 + self.size) * 0.5)
			else
				displace_y = stage.gem_height * (i - (1 + self.size) * 0.5)
			end
			self.gems[i]:draw{pivot_x = self.x, pivot_y = self.y, rotation = self.rotation,
				displace_x = displace_x, displace_y = displace_y}
		end
	love.graphics.pop()
end

function Piece:getRect()
	local x = self.x - (self.gems[1].width / 2) * self.size
	local w = self.gems[1].width * self.size
	local y = self.y - (self.gems[1].height / 2) * self.size
	local h = self.gems[1].height * self.size
	return x, y, w, h
end

-- Returns the piece columns as an array of size (piece.size).
-- Shift can be either -1 or +1, used when the input is over the midline;
-- it forces the gem to be dropped to the left or the right of midline.
function Piece:getColumns(shift)
	local stage = self.game.stage
	local grid = self.game.grid
	local ret = {}
	shift = shift or 0
	if shift then shift = shift * stage.gem_width end

	if self.horizontal then
		for i = 1, self.size do
			ret[i] = false
			for j = 1, grid.columns do
				local in_this_column = pointIsInRect(self.gems[i].x + shift, self.gems[i].y,
					table.unpack(grid.active_rect[j]))
				if in_this_column then ret[i] = j end
			end
		end

	elseif not self.horizontal then
		for i = 1, self.size do ret[i] = false	end -- set array length
		for j = 1, grid.columns do
			local in_this_column = pointIsInRect(self.gems[1].x + shift, self.gems[1].y,
				table.unpack(grid.active_rect[j]))
			if in_this_column then
				for k = 1, #ret do ret[k] = j end
			end
		end

	else
		print("Exception: invalid horizontality")
	end
	return ret
end

-- Checks that all gems are within columns 1-8 of the tub, and not overlapping midline.
-- accepts optional boolean to test for midline-shifted piece
function Piece:isDropLegal(test_shifted_piece)
	local shift = nil
	if test_shifted_piece then
		local midline, on_left = self:isOnMidline()
		if midline then	shift = on_left and -1 or 1	end
	end
	local cols = self:getColumns(shift)
	local gems_in_my_tub = 0
	for i = 1, self.size do
		if not cols[i] then
			return false
		elseif cols[i] >= self.owner.start_col and cols[i] <= self.owner.end_col then
			gems_in_my_tub = gems_in_my_tub + 1
		end
	end
	return gems_in_my_tub == self.size or gems_in_my_tub == 0
end

-- Checks if the drop location is a legal drop location, and also that the player
-- has the meter to play it. If gem is over midline, this function takes shift
-- in order to force the drop to a legal position.
function Piece:isDropValid(shift)
	local player = self.owner
	local place_type
	local cols = self:getColumns(shift)
	local gems_in_my_tub = 0
	if self.game.phase ~= "Action" then return false end
	for i = 1, self.size do
		if not cols[i] then
			return false
		elseif cols[i] >= player.start_col and cols[i] <= player.end_col then
			gems_in_my_tub = gems_in_my_tub + 1
		end
	end
	if not player.dropped_piece then
		if gems_in_my_tub == self.size then
			place_type = "normal"
		elseif gems_in_my_tub == 0 and self:isValidRush() then
			place_type = "rush"
		else
			return false
		end
	elseif gems_in_my_tub == self.size and player.cur_burst >= player.current_double_cost
		and player.dropped_piece == "normal" then
			place_type = "double"
	else
		return false
	end
	return true, place_type
end

-- Checks if the drop location is overlapping the midline.
function Piece:isOnMidline()
	local player = self.owner
	local cols = self:getColumns()
	local my_col, enemy_col = false, false
	for i = 1, self.size do
		if cols[i] and cols[i] >= player.start_col and cols[i] <= player.end_col then
			my_col = true
		elseif cols[i] and cols[i] >= player.enemy.start_col and cols[i] <= player.enemy.end_col then
			enemy_col = true
		end
	end

	if (my_col and enemy_col) then
		return true, self.game.stage:isOnLeft()
	else
		return false, nil
	end
end

-- Checks whether the rush placement is valid
-- current_rush_cost is optional
function Piece:isValidRush()
	local grid = self.game.grid
	local player = self.owner
	local cols = self:getColumns()
	local enough_burst = player.cur_burst >= player.current_rush_cost
	local row_ok = true
	for i = 1, self.size do
		local empty_row = grid:getFirstEmptyRow(cols[i])
		if empty_row < self.game.RUSH_ROW then 
			row_ok = false 
			if self.game.particles.no_rush_check[cols[i]] == 0 then
				self.game.particles.words.generateNoRush(self.game, cols[i])
			else
				self.game.particles.no_rush_check[cols[i]] = 2
			end
		end
	end
	return enough_burst and row_ok
end

-- Generates dust when playing is holding the piece.
function Piece:generateDust()
	if self.game.frame % 12 == 0 then
		for i = 1, self.size do
			local gem = self.gems[i]
			local x_drift = (math.random() - 0.5) * gem.width
			local y_drift = (math.random() - 0.5) * gem.height
			self.game.particles.dust.generateFalling(self.game, gem, x_drift, y_drift)
		end
	end
end

-- When player picks up a piece. Called from gs_main.lua.
function Piece:select()
	self.game.active_piece = self
	self:resolve()
	for i = 1, self.size do -- generate some particles!
		self.game.particles.dust.generateFountain(self.game, self.gems[i], math.random(2, 6))
	end
end

-- When player releases a piece. Called from gs_main.lua.
function Piece:deselect()
	local player = self.owner
	local shift = 0
	local midline, on_left = self:isOnMidline()
	if midline then
		if on_left then	shift = -1 else	shift = 1 end
	end
	local valid, place_type = self:isDropValid(shift)
	local cols = self:getColumns(shift)
	local go_ahead = (place_type == "normal") or
		(place_type == "rush" and self:isValidRush()) or
		(place_type == "double" and player.cur_burst >= player.current_double_cost)
	local char_ability_ok = player:pieceDroppedOK(self, shift)
	if valid and not self.game.frozen and go_ahead and char_ability_ok and self.game.phase == "Action" then
		player.place_type = place_type
		self:dropIntoBasin(cols)
	else -- snap back to original place. Can't use change because it interferes with rotate tween
		self.x, self.y = player.hand[self.hand_idx].x, player.hand[self.hand_idx].y
	end
end

-- Transfers piece from player's hand into basin.
-- No error checking, assumes this is a valid move! Be careful please.
function Piece:dropIntoBasin(coords, received_from_opponent)
	local game, grid, player, hand = self.game, self.game.grid, self.owner, self.owner.hand

	-- not received_from_opponent means it's our piece placing, so we need to send it to them
	if game.type == "Netplay" and not received_from_opponent then
		game.client.prepareDelta(game.client, self, coords, player.place_type)
	end

	-- place the gem into the holding area
	local row_adj = 0 -- how many rows down from the top to place the gem
	if player.place_type == "rush" then
		row_adj = 2
		player.cur_burst = player.cur_burst - player.current_rush_cost
		player.dropped_piece = "rushed"
	elseif player.place_type == "double" then
		-- move existing pending piece down, if it's a normal piece
		local pending_gems = grid:getPendingGems(player)
		for _, gem in pairs(pending_gems) do
			if gem.row == 1 or gem.row == 2 then
				grid:moveGem(gem, gem.row + 4, gem.column)
				gem.y = grid.y[gem.row]
				gem.tweening = tween.new(0.3, gem, {y = grid.y[gem.row + 4]}, "outBack")
			end
		end
		player.cur_burst = player.cur_burst - player.current_double_cost
		player.dropped_piece = "doubled"
	elseif player.place_type == "normal" then
		player.dropped_piece = "normal"
	elseif player.place_type == nil then
		print("NIL PLACE TYPE WHAT HAPPENED HERE")
	else
		print("Not a valid dropped piece type!")
	end

	local locations = {}
	if self.horizontal then
		for i = 1, #self.gems do locations[i] = {1 + row_adj, coords[i]} end
	else
		for i = 1, #self.gems do locations[i] = {i + row_adj, coords[i]} end
	end
	hand:movePieceToGrid(grid, self, locations)
	hand:movePieceToGridAnim(grid, self, locations)

	if self.horizontal then
		for i = 1, #self.gems do
			local column = coords[i]
			self.tween_y = grid.y[1 + row_adj + 4]
			self.gems[i].tweening = tween.new(0.3, self.gems[i], {y = self.tween_y}, "outBack")
		end
	elseif not self.horizontal then
		for i = 1, #self.gems do
			local column = coords[1]
			self.tween_y = grid.y[i + row_adj + 4]
			self.gems[i].tweening = tween.new(0.3, self.gems[i], {y = self.tween_y}, "outBack")
		end
	end
	player.played_pieces[#player.played_pieces+1] = self.gems
	self:breakUp()
end

return common.class("Piece", Piece)
