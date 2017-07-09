require 'utilities' -- helper functions
local class = require 'middleclass' -- class support
--local Pie = require 'pie'
local Piece = require 'piece'
local GemPlatform = require 'gemplatform'
local stage

local Hand = class('Hand')

Hand.PLATFORM_SPEED = window.height / 192 -- pixels per second for pieces to shuffle

function Hand:initialize(player)
	stage = game.stage

	--assert((player == p1 or player == p2), "Invalid player given!")
	self.owner = player
	for i = 0, 10 do
		self[i] = {}
		self[i].piece = nil
		self[i].platform = nil
		self[i].y = stage.height * 0.1375 * i + stage.height * 0.1875
		self[i].x = self:getx(self[i].y)
	end
	self[0].y = stage.height / 8 -- discard place is higher up
	self.garbage = {} -- pending-garbage gems
end

-- make pieces at start of round. They are all then moved up 5 spaces
function Hand:makeInitialPieces(gem_table)
	for i = 8, 10 do
		self[i].piece = Piece:new{
			location = self[i],
			hand_idx = i,
			owner = self.owner,
			x = self[i].x,
			y = self[i].y,
			gem_table = gem_table,
		}
		self:movePiece(i, i-5)
	end
	for i = 6, 10 do
		self[i].platform = GemPlatform:new(self.owner, i)
		self:movePlatform(i, i-5)
	end
end

-- this describes the shape of the curve for the hands.
function Hand:getx(y)
	local sign = self.owner.ID == "P1" and -1 or 1
	if y == nil then print("Invalid y provided to getx!") return nil end
	if y <= stage.height * 0.6 then
		return stage.x_mid + (5.5 * stage.gem_width) * sign
	else
		local start_x = stage.x_mid + (5.5 * stage.gem_width) * sign
		local additional = (((y - stage.height * 0.6) / stage.height) ^ 2) * stage.height
		return start_x + additional * sign
	end
end

local function destroyTopPieceAnim(hand)
	print("Check top piece: ", hand[0].piece, hand.owner.ID)
	for i = 1, #hand[0].piece.gems do
		local this_gem = hand[0].piece.gems[i]
		local x_dist = this_gem.x - hand[0].x
		local y_dist = this_gem.y - hand[0].y
		local dist = (x_dist^2 + y_dist^2)^0.5
		local angle = math.atan2(y_dist, x_dist)
		local duration = math.abs(dist / hand.PLATFORM_SPEED)
		this_gem:moveTo{x = hand[0].x, y = hand[0].y, duration = duration}
	end
end

local function destroyTopPiece(hand)
	for i = 1, #hand[0].piece.gems do
		local this_gem = hand[0].piece.gems[i]
		--hand.garbage[#hand.garbage+1] = this_gem -- do this alter
	end
	hand[0].piece:breakUp()
	stage.grid:addBottomRow(hand.owner) -- add a penalty row TODO: callback function this later
	hand.owner.pieces_fallen = hand.owner.pieces_fallen + 1 -- to determine garbage ownership
end

-- moves a piece from location to location, as integers
function Hand:movePiece(start_pos, end_pos)
	print("Moving piece from, to: ", start_pos, end_pos)
	-- anims
	local dist = stage.height * 0.1375 * (end_pos - start_pos)
	local duration = math.abs(dist / self.PLATFORM_SPEED)
	local to_move = self[start_pos].piece
	to_move:moveTo{
		x = function() return self:getx(to_move.y) end,
		y = self[end_pos].y,
		duration = duration,
	}

	-- state
	if self[end_pos].piece then
		print("warning: moved a piece to location " .. end_pos .. " already with a piece!")
	end
	self[end_pos].piece = self[start_pos].piece
	self[start_pos].piece = nil
	if self[0].piece then
		destroyTopPieceAnim(self)
		destroyTopPiece(self)
	end
end

-- moves a gem platform from location to location, as integers
function Hand:movePlatform(start_pos, end_pos)
	-- anims
	local dist = stage.height * 0.1375 * (end_pos - start_pos)
	local duration = math.abs(dist / self.PLATFORM_SPEED)
	self[start_pos].platform:moveTo{
		x = function() return self:getx(self[end_pos].platform.y) end,
		y = self[end_pos].y,
		duration = duration,
	}

	-- state
	if self[end_pos].platform then
		print("warning: moved a platform to location " .. end_pos .. " already with a platform!")
	end
	self[end_pos].platform = self[start_pos].platform
	self[start_pos].platform = nil
	if self[0].platform then
		self[0].platform:removeAnim()
		self[0].platform = nil
	end
end

-- creates the new pieces for the turn. Takes optional gem_table for gem frequencies
function Hand:getNewTurnPieces(gem_table)
	local player = self.owner
	local distance = stage.height * 0.1375 * player.pieces_to_get
	local duration = math.abs(distance / self.PLATFORM_SPEED)
	for i = 6, player.pieces_to_get + 5 do
		self[i].piece = Piece:new{
			location = self[i],
			hand_idx = i,
			owner = self.owner,
			x = self[i].x,
			y = self[i].y,
			gem_table = gem_table,
		}
		self[i].platform = GemPlatform:new(self.owner, i)
	end
	for i = 1, 10 do -- move up all the pieces
		local end_pos = math.max(i - player.pieces_to_get, 0)
		if self[i].piece then self:movePiece(i, end_pos) end
		if self[i].platform then self:movePlatform(i, end_pos) end
	end
end

-- Checks whether a player's pieces have stopped moving.
-- No need to check gem platforms, because hand[6] will always have a piece.
-- Takes optional start_loc for which position to start checking from.
function Hand:isSettled(start_loc)
	local start_loc = start_loc or 0 -- we may not always want to check if discard finished moving
	local all_unmoved = true
	for i = start_loc, self.owner.hand_size + 1 do
		if self[i].piece then
			if not self[i].piece:isStationary() then all_unmoved = false end
		end
	end
	for i = 1, #self.garbage do
		if self.garbage[i].y ~= self[0].y then all_unmoved = false end
	end
	return all_unmoved
end

-- Returns a list of piece IDs, for netplay use
function Hand:getPieceIDs()
	local ret = {}
	for i = 1, self.owner.hand_size do
		if self[i].piece then
			ret[i] = self[i].piece.ID
		else
			ret[i] = false
		end
	end
	return ret
end

function Hand:update(dt)
	-- move hand gems and platforms
	for i = 0, 10 do
		if self[i].piece then self[i].piece:update(dt) end
		if self[i].platform then self[i].platform:update(dt) end
	end

	-- move garbage gems
	local garbage = self.garbage
	for i = #garbage, 1, -1 do

		-- no need for these three lines after moveTo
		--[[garbage[i].y = math.max(garbage[i].y - self.PLATFORM_SPEED, player.hand[0].y)
		local to_check_y = garbage[i].y - garbage[i].y_diff
		garbage[i].x = stage.getx[player.ID](to_check_y) + garbage[i].x_diff--]]

		-- remove garbage gems if arrived at top
		if garbage[i].y == self[0].y then
			table.remove(garbage, i) -- later split this into a function for destroy top piece particle effects
		end
	end

	-- update pies
	for i = 2, 5 do self.owner.pie[i]:update(dt) end

end

-- Assigns damage to individual pies
function Hand:addDamage(damage)
	local player = self.owner
 	local i = 2
 	while damage > 0 and i <= 5 do
		local amt_to_add = math.min(damage, 4 - player.pie[i].damage)
 		player.pie[i]:addDamage(amt_to_add)
		damage = damage - amt_to_add
		if amt_to_add > 0 then player.pie[i].damage_changed = true end
		i = i + 1
  	end
end

-- Update function only called at end of turn
function Hand:endOfTurnUpdate()
	local player = self.owner
	player.pieces_to_get = 1
	-- full pies add an extra piece to get
	for i = 2, 5 do
		if player.pie[i].damage == 4 then
			player.pieces_to_get = player.pieces_to_get + 1
			player.pie[i]:reset()
		end
	end

	-- Then sort pies so that highest damage pies are at the top
	local damage_arr = {}
	for i = 2, 5 do	damage_arr[i-1] = player.pie[i].damage end
	table.sort(damage_arr, function(a, b) return a > b end)
	for i = 2, 5 do
		player.pie[i].damage = damage_arr[i-1]
		player.pie[i].damage_changed = true
	end
end

return Hand
