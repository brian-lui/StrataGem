require 'inits' -- ID
--local GemPlatform = require 'gemplatform'
local image = require 'image'
require 'utilities' -- helper functions
local class = require 'middleclass' -- class support
local stage = game.stage
local particles = game.particles
local engine = game.engine
local tween = require 'tween'
local pic = require 'pic'

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

local Piece = class('Piece')
function Piece:initialize(tbl)
	ID.piece = ID.piece + 1
	local tocopy = {"x", "y", "owner", "gem_table"}
	for i = 1, #tocopy do
		local item = tocopy[i]
		self[item] = tbl[item]
		if tbl[item] == nil and item ~= "gem_table" then print("No " .. item .. " received!") end
	end
	self.ID = ID.piece
	self.size = self.size or 2
	self.gem_table = self.gem_table or {
		{gem = Gem.RedGem, freq = 1},
		{gem = Gem.BlueGem, freq = 1},
		{gem = Gem.GreenGem, freq = 1},
		{gem = Gem.YellowGem, freq = 1}
	}
	self.rotation = 0
	self.rotation_index = 0
	self.horizontal = true
	self.gems = {}
	self:addGems(self.gem_table)
	self.getx = self.owner.hand.getx
end

function Piece:addGems(gem_table)
	for i = 1, self.size do
		local gem = Gem:random(gem_table)
		self.gems[i] = gem:new(self.x, self.y)
	end
	updatePieceGems(self)
end

function Piece:moveTo(target)
	self.queued_moves = self.queued_moves or {}
	pic.moveTo(self, target)
	updatePieceGems(self)
end

function Piece:wait(frames)
	pic.wait(self, frames)
end

function Piece:update(dt)
	pic.update(self, dt)
end

function Piece:isStationary()
	return not self.move_func
end

function Piece:rotate()
	self.horizontal = not self.horizontal
	if self.horizontal then self.gems = reverseTable(self.gems) end
	--for i = 1, #self.gems do
		--self.gems[i].horizontal = self.horizontal
		--self.gems[i].vertical = not self.horizontal
	--end
	self.rotation_index = (self.rotation_index + 1) % 4
	updatePieceGems(self)

	--[[ piece has already rotated pi/2 clockwise. But we show
		the piece from its original starting location --]]
	--self.rotation = math.pi * -0.5
	self:moveTo{rotation = math.pi * -0.5, duration = 20}
end

function Piece:breakUp()
	local player = self.owner
	for i = 0, player.hand_size do
		if self == player.hand[i].piece then
			pic.clear(player.hand[i].piece)
			player.hand[i].piece = nil
		end
	end
end

-- draw gems with displacement depending on piece horizontal/vertical
function Piece:draw()
	for i = 1, self.size do
		local displace_x, displace_y = 0, 0
		if self.horizontal then
			displace_x = stage.gem_width * (i - (1 + self.size) * 0.5)
		else
			displace_y = stage.gem_height * (i - (1 + self.size) * 0.5)
		end
		self.gems[i]:draw(self.x, self.y, nil, self.rotation, displace_x, displace_y)
	end
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
	local ret = {}
	shift = shift or 0
	if shift then shift = shift * stage.gem_width end

	if self.horizontal then
		for i = 1, self.size do
			ret[i] = false
			for j = 1, stage.grid.columns do
				local in_this_column = pointIsInRect(self.gems[i].x + shift, self.gems[i].y,
					unpack(stage.grid.active_rect[j]))
				if in_this_column then ret[i] = j end
			end
		end

	elseif not self.horizontal then
		for i = 1, self.size do ret[i] = false	end -- set array length
		for j = 1, stage.grid.columns do
			local in_this_column = pointIsInRect(self.gems[1].x + shift, self.gems[1].y,
				unpack(stage.grid.active_rect[j]))
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
	if game.phase ~= "Action" then return false end
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
		elseif gems_in_my_tub == 0 and self:isValidRush() and not player.supering then
			place_type = "rush"
		else
			return false
		end
	elseif gems_in_my_tub == self.size and player.cur_mp >= player.current_double_cost and
		not player.supering and player.dropped_piece == "normal" then
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
		return true, game.input_method.isOnLeft()
	else
		return false, nil
	end
end

-- Checks whether the rush placement is valid
-- current_rush_cost is optional
function Piece:isValidRush()
	local player = self.owner
	local cols = self:getColumns()
	local enough_mp = player.cur_mp >= player.current_rush_cost
	local row_ok = true
	for i = 1, self.size do
		local empty_row = stage.grid:getFirstEmptyRow(cols[i])
		if empty_row < game.RUSH_ROW then row_ok = false end
	end
	return enough_mp and row_ok
end

-- Generates dust when playing is holding the piece.
function Piece:generateDust()
	if frame % 12 == 0 then
		for i = 1, self.size do
			local gem = self.gems[i]
			local x_drift = (math.random() - 0.5) * gem.width
			local y_drift = (math.random() - 0.5) * gem.height
			particles.dust:generateFalling(gem, x_drift, y_drift)
		end
	end
end

-- When player picks up a piece. Called from inputs.lua.
function Piece:select()
	game.piece_origin.x = self.x
	game.piece_origin.y = self.y

	game.active_piece = self
	-- generate some particles!
	for i = 1, self.size do
		particles.dust:generateFountain(self.gems[i], math.random(2, 6))
	end
end

-- When player releases a piece. Called from inputs.lua.
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
		(place_type == "rush" and self:isValidRush() and not player.supering) or
		(place_type == "double" and player.cur_mp >= player.current_double_cost and not player.supering)
	local char_ability_ok = player:pieceDroppedOK(self, shift)
	if valid and not game.frozen and go_ahead and char_ability_ok then
		player.place_type = place_type
		self:dropIntoBasin(cols)
	else -- snap back to original place
		self:moveTo{x = game.piece_origin.x, y = game.piece_origin.y}
	end
end

function Piece:dropIntoBasin(coords, received_from_opponent)
-- Transfers piece from player's hand into basin.
-- No error checking, assumes this is a valid move! Be careful please.
	local player = self.owner

	-- not received_from_opponent means it's our piece placing,
	-- so we need to send it to them
	if game.type == "Netplay" and not received_from_opponent then
		client.prepareDelta(self, coords, player.place_type)
	end

	-- Generate uptweening gems
	for i = 1, #self.gems do
		particles.upGem:generate(self.gems[i])
	end

	-- place the gem into the holding area
	local row_adj = 0 -- how many rows down from the top to place the gem
	if player.place_type == "rush" then
		row_adj = 2
		player.cur_mp = player.cur_mp - player.current_rush_cost
		player.dropped_piece = "rushed"
	elseif player.place_type == "double" then
		-- move existing pending piece down, if it's a normal piece
		local pending_gems = stage.grid:getPendingGems(player)
		for _, gem in pairs(pending_gems) do
			if gem.row == 1 or gem.row == 2 then
				stage.grid[gem.row + 4][gem.column].gem = gem
				stage.grid[gem.row][gem.column].gem = false
				gem.row = gem.row + 4
				gem.y = stage.grid.y[gem.row]
				gem.tweening = tween.new(0.01, gem, {})
				-- a nil tween since we are showing the new location now
			end
		end
		player.cur_mp = player.cur_mp - player.current_double_cost
		player.dropped_piece = "doubled"
	elseif player.place_type == "normal" then
		player.dropped_piece = "normal"
	elseif player.place_type == nil then
		print("NIL PLACE TYPE WHAT HAPPENED HERE")
	else
		print("Not a valid dropped piece type!")
	end

	-- set ownership. gem ownership is used to calculate damage and meter gain
	--for i = 1, #self.gems do engine.setGemOwner(self.gems[i], player) end
	for i = 1, #self.gems do self.gems[i]:setOwner(player) end

	local this_played_pieces = {}
	if self.horizontal then
		for i = 1, #self.gems do
			local column = coords[i]
			stage.grid[1 + row_adj][column].gem = self.gems[i]
			self.gems[i].x = stage.grid.x[column]
			self.gems[i].column = column
			self.gems[i].y = stage.grid.y[1 + row_adj]
			self.tween_y = stage.grid.y[1 + row_adj + 4]
			self.gems[i].row = 1 + row_adj
			self.gems[i].tweening = tween.new(0.3, self.gems[i], {y = self.tween_y}, "outBack")
			this_played_pieces[i] = self.gems[i]
		end
	elseif not self.horizontal then
		for i = 1, #self.gems do
			local column = coords[1]
			stage.grid[i + row_adj][column].gem = self.gems[i]
			self.gems[i].x = stage.grid.x[column]
			self.gems[i].column = column
			self.gems[i].y = stage.grid.y[i + row_adj]
			self.tween_y = stage.grid.y[i + row_adj + 4]
			self.gems[i].row = i + row_adj
			self.gems[i].tweening = tween.new(0.3, self.gems[i], {y = self.tween_y}, "outBack")
			if i ~= #self.gems then self.gems[i].no_yoshi_particle = true end
			this_played_pieces[i] = self.gems[i]
		end
	end
	player.played_pieces[#player.played_pieces+1] = this_played_pieces
	self:breakUp()
end

return Piece
