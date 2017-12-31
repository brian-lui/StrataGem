require 'utilities' -- helper functions
local common = require "class.commons" -- class support
local Piece = require 'piece'
local GemPlatform = require 'gemplatform'
local Pic = require 'pic'
local image = require 'image'

local Hand = {}
Hand.PLATFORM_SPEED = drawspace.height / 192 -- pixels per second for pieces to shuffle

function Hand:init(game, player)
	self.game = game
	local stage = game.stage

	--assert((player == p1 or player == p2), "Invalid player given!")
	self.owner = player
	for i = 0, 10 do
		self[i] = {}
		self[i].piece = nil
		self[i].platform = nil
		self[i].y = stage.height * 0.1475 * i ^ 0.92 + stage.height * 0.1875
		self[i].x = self:getx(self[i].y)
	end
	self[0].y = stage.height * 0.125 -- discard place is higher up
	self.garbage = {} -- pending-garbage gems
	self.damage = 4 -- each 4 damage is one more platform movement
	self.turn_start_damage = 4	-- damage at the start of the turn, used in particles calcs
end

-- make pieces at start of round. They are all then moved up 5 spaces
-- gem_table is optional
function Hand:makeInitialPieces(gem_table)
	for i = 8, 10 do
		self[i].piece = common.instance(Piece, self.game, {
			location = self[i],
			hand_idx = i,
			owner = self.owner,
			x = self[i].x,
			y = self[i].y,
			--gem_table = gem_table,
		})
		self:movePiece(i, i-5)
	end
	for i = 6, 10 do
		self[i].platform = common.instance(GemPlatform, self.game, self.owner, i)
		self:movePlatform(i, i-5)
	end
	self[1].platform:setSpin(0.02)
end

-- this describes the shape of the curve for the hands.
function Hand:getx(y)
	local stage = self.game.stage
	local sign = self.owner.ID == "P1" and -1 or 1
	if y == nil then print("Invalid y provided to getx!") return nil end
	local start_x = stage.x_mid + (5.5 * stage.gem_width) * sign
	local additional = (((y - stage.height * 0.35) / stage.height) ^ 2) * stage.height
	return start_x + additional * sign
end

function Hand:createGarbageAnimation()
	local game = self.game
	for i = 1, #self[0].piece.gems do
		local gem = self[0].piece.gems[i]
		gem.owner = self.owner.playerNum
		game.particles.explodingGem.generate(game, gem)
		game.queue:add(game.GEM_EXPLODE_FRAMES, game.particles.garbageParticles.generate, game, gem)
		--game.queue:add(game.GEM_EXPLODE_FRAMES, game.particles.pop.generate, game, gem)
		--game.queue:add(game.GEM_EXPLODE_FRAMES, game.particles.dust.generateBigFountain, game, gem, 24)
	end
	game.ui:screenshake(3)

	local gems = self[0].piece:breakUp() -- but need to show the gems still, until game.GEM_EXPLODE_FRAMES later
	self.game.grid:addBottomRow(self.owner) -- add a penalty row TODO: callback function this later
	self.owner.pieces_fallen = self.owner.pieces_fallen + 1 -- to determine garbage ownership
	self.game.queue:add(45, self.game.sound.newSFX, self.game.sound, "sfx_trashrow") -- TODO: this is hacky and sucky
end

-- moves a piece from location to location, as integers
function Hand:movePiece(start_pos, end_pos)
	if start_pos == end_pos then
		return
	end

	-- anims
	local dist = self.game.stage.height * 0.1375 * (end_pos - start_pos)
	local duration = math.abs(dist / Hand.PLATFORM_SPEED)
	local to_move = self[start_pos].piece
	to_move.hand_idx = end_pos
	to_move:resolve()
	to_move:change{
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
		self:createGarbageAnimation()
	end
end

-- moves a gem platform from location to location, as integers
function Hand:movePlatform(start_pos, end_pos)
	if start_pos == end_pos then return end

	-- anims
	local dist = self.game.stage.height * 0.1375 * (end_pos - start_pos)
	local duration = math.abs(dist / Hand.PLATFORM_SPEED)

	self[start_pos].platform.pic:change{
		x = function() return self:getx(self[end_pos].platform.pic.y) end,
		y = self[end_pos].y,
		duration = duration,
	}

	-- state
	if self[end_pos].platform then
		print("warning: moved a platform to location " .. end_pos .. " already with a platform!")
	end
	self[end_pos].platform = self[start_pos].platform
	self[end_pos].platform.hand_idx = end_pos
	self[start_pos].platform = nil

	self:destroyPlatform(0)
end

-- moves a piece from the hand to the grid.
-- rows and columns should be given as a table for each gem
-- e.g. {{3, 4}, {6, 6}} to move piece to r3/c6, r4/c6
function Hand:movePieceToGrid(grid, piece, locations)
	for i = 1, #piece.gems do
		-- gamestate
		local gem, r, c = piece.gems[i], locations[i][1], locations[i][2]
		gem:setOwner(self.owner) -- set ownership
		if grid[r][c].gem then -- check if gem exists in destination
			print("warning: existing gem in destination (row " .. r .. ", column " .. c .. ")")
		end
		grid[r][c].gem = gem
		gem.row, gem.column = r, c
		if not piece.horizontal and i ~= #piece.gems then
			gem.no_yoshi_particle = true
		end

		-- animations
		gem.x = grid.x[c] -- snap x-position to column first
		self.game.particles.upGem.generate(self.game, gem) -- call upGem from current position
		gem.y = grid.y[r]
		self.game.particles.placedGem.generate(self.game, gem) -- put a placedGem image
	end	
	self[piece.hand_idx].piece = nil
	piece.hand_idx = nil
end

-- creates the new pieces for the turn and clears damage.
-- Takes optional gem_table for gem frequencies
function Hand:getNewTurnPieces(gem_table)
	local player = self.owner
	local pieces_to_get = math.floor(self.damage * 0.25)
	self.damage = self.damage % 4
	self.turn_start_damage = self.damage
	if pieces_to_get == 0 then return end

	for i = 6, pieces_to_get + 5 do
		self[i].piece = common.instance(Piece, self.game, {
			location = self[i],
			hand_idx = i,
			owner = player,
			x = self[i].x,
			y = self[i].y,
			gem_table = gem_table,
		})
		self[i].platform = common.instance(GemPlatform, self.game, player, i)
	end
	for i = 1, 10 do -- move up all the pieces
		local end_pos = math.max(i - pieces_to_get, 0)
		if self[i].piece then self:movePiece(i, end_pos) end
		if self[i].platform then self:movePlatform(i, end_pos) end
	end
end

function Hand:destroyPlatform(num)
	-- TODO: if platform has a gem, make some garbage anims
	self[num].platform = nil	
end

function Hand:destroyPlatforms()
	local each_platform_delay = 10
	local game = self.game
	local to_destroy = math.min(5, math.floor(self.damage * 0.25))
	for i = 1, to_destroy do
		local delay = (i - 1) * each_platform_delay
		game.queue:add(delay, game.sound.newSFX, game.sound, "sfx_starbreak")
		game.queue:add(delay, game.particles.explodingPlatform.generate,
			self.game, self[i].platform.pic)
		game.queue:add(delay, self.destroyPlatform, self, i)
	end
end

-- Checks whether a player's pieces have stopped moving.
-- No need to check gem platforms, because hand[6] will always have a piece.
-- Takes optional start_loc for which position to start checking from.
function Hand:isSettled(start_loc)
	start_loc = start_loc or 0 -- we may not always want to check if discard finished moving
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
		-- remove garbage gems if arrived at top
		if garbage[i].y == self[0].y then
			table.remove(garbage, i) -- later split this into a function for destroy top piece particle effects
		end
	end
end

-- meh. Just in case damage goes over 20
function Hand:addDamage(damage)
	self.damage = math.min(self.damage + damage, 20)
end

-- Update function only called after action phase
function Hand:afterActionPhaseUpdate()
	for i = 1, 5 do
		if self[i].piece then
			self[i].piece:resolve()
		end
		self[i].platform:setFastSpin(true)
	end
end

-- Update function only called at end of turn
function Hand:endOfTurnUpdate()
	for i = 1, 5 do
		self[i].platform:setFastSpin(false)
	end
	self.damage = self.damage + 4
	self.turn_start_damage = self.damage
	self.owner.cur_burst = math.min(self.owner.cur_burst + 1, self.owner.MAX_BURST)
end

return common.class("Hand", Hand)
