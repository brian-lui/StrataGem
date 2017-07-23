local love = _G.love
require 'inits'
local class = require "middleclass"
local image = require 'image'
local stage
local pic = require 'pic'
local hand = require 'hand'
local tween = require 'tween'

local character = class("Character")
--character.defaults = require 'characters/default' -- called from charselect
--character.heath = require 'characters/heath'
--character.walter = require 'characters/walter'
--character.gail = require 'characters/gail'

character.full_size_image = love.graphics.newImage('images/characters/heath.png')
character.small_image = love.graphics.newImage('images/characters/heathsmall.png')
character.action_image = love.graphics.newImage('images/characters/heathaction.png')
character.shadow_image = love.graphics.newImage('images/characters/heathshadow.png')
character.super_fuzz_image = love.graphics.newImage('images/ui/superfuzzred.png')

character.character_id = "Lamer"
character.meter_gain = {RED = 4, BLUE = 4, GREEN = 4, YELLOW = 4}

character.super_images = {
	word = image.UI.super.red_word,
	empty = love.graphics.newImage('images/characters/emptyheath.png'),
	full = love.graphics.newImage('images/characters/fullheath.png'),
	glow = love.graphics.newImage('images/characters/fullheathglow.png'),
}

character.burst_images = {
	partial = image.UI.burst.red_partial,
	full = image.UI.burst.red_full,
	glow = {image.UI.burst.red_glow1, image.UI.burst.red_glow2}
}
character.MAX_MP = 64
character.SUPER_COST = 64
character.cur_mp = 0
character.old_mp = 0
character.MAX_BURST = 6
character.RUSH_COST = 6
character.DOUBLE_COST = 3
character.cur_burst = 3
character.hand_size = 5
character.pieces_fallen = 0
character.dropped_piece = false
character.super_clicked = false
character.supering = false
character.super_this_turn = false
character.place_type = "normal"

function character:initialize(playerNum, _stage)
	stage = _stage
	if playerNum == 1 then
		self.ID, self.start_col, self.end_col = "P1", 1, 4
		p1 = self
	elseif playerNum == 2 then
		self.ID, self.start_col, self.end_col = "P2", 5, 8
		p2 = self
	else
		love.errhand("Invalid playerNum " .. tostring(playerNum))
	end
	self.current_rush_cost = self.RUSH_COST
	self.current_double_cost = self.DOUBLE_COST
	self.played_pieces = {}
	self:setup()
end

-- initialize super meter graphics
local function setupSuperMeter(player)
	player.super_frame = pic:new{x = stage.super[player.ID].x,
		y = stage.super[player.ID].y, image = player.super_images.empty}
	player.super_word = pic:new{x = stage.super[player.ID].x,
		y = stage.super[player.ID].word_y, image = player.super_images.word}
	player.super_meter_image = pic:new{x = stage.super[player.ID].x,
		y = stage.super[player.ID].y, image = player.super_images.full}
	player.super_glow = pic:new{x = stage.super[player.ID].x,
		y = stage.super[player.ID].y, image = player.super_images.glow}
end

-- initialize burst meter graphics
local function setupBurstMeter(player)
	local burst_frame = player.ID == "P1" and image.UI.gauge_gold or image.UI.gauge_silver
	player.burst_frame = pic:new{x = stage.burst[player.ID].frame.x,
		y = stage.burst[player.ID].frame.y, image = burst_frame}
	player.burst_block = {}
	player.burst_partial = {}
	player.burst_glow = {}
	for i = 1, 2 do
		player.burst_block[i] = pic:new{x = stage.burst[player.ID][i].x,
			y = stage.burst[player.ID][i].y, image = player.burst_images.full}
		player.burst_partial[i] = pic:new{x = stage.burst[player.ID][i].x,
			y = stage.burst[player.ID][i].y, image = player.burst_images.partial}
		player.burst_glow[i] = pic:new{x = stage.burst[player.ID][i].glow_x,
			y = stage.burst[player.ID][i].glow_y, image = player.burst_images.glow[i]}

	end
	player.burst_glow.full = pic:new{x = stage.burst[player.ID][2].glow_x,
		y = stage.burst[player.ID][2].glow_y, image = player.burst_images.glow[2]}
end

-- placeholder, waiting for animations
local function createCharacterAnimation(player)
	player.animation = pic:new{x = stage.character[player.ID].x,
	y = stage.character[player.ID].y, image = player.small_image}
end


-- TODO: Make player and/or character into classes and put this in there
function character:addSuper(amt)
	self.old_mp = self.cur_mp
	self.cur_mp = math.min(self.cur_mp + amt, self.MAX_MP)
end

-- do those things to set up the character. Called at start of match
function character:setup()
	self.hand = hand:new(self)
	self.hand:makeInitialPieces()
	setupBurstMeter(self)
	setupSuperMeter(self)
	createCharacterAnimation(self)
end

function character:actionPhase(dt)
end

-- returns a list of {frames, func, args to execute}
function character:afterGravity()
	return {}
end


function character:beforeMatch(gem_table)
end

function character:duringMatch(gem_table)
end

function character:afterMatch()
end

function character:cleanup()
end

function character:activateSuper()
	if self.cur_mp >= self.SUPER_COST then
		self.supering = not self.supering
	end
end

function character:pieceDroppedOK(piece, shift)
	local _, place_type = piece:isDropValid(shift)
	if place_type == "normal" then
		return true
	elseif place_type == "rush" then
		return self.cur_burst >= (self.current_rush_cost) and not self.supering
	elseif place_type == "double" then
		return self.cur_burst >= (self.current_double_cost) and not self.supering
	end
end


function character:superSlideIn()
	local x_pos = self.ID == "P1" and stage.width * -0.2 or stage.width * 1.2

	local particles = game.particles

	local shadow = particles.superEffects2:new{
		image = self.shadow_image,
		x = x_pos,
		y = stage.height * 0.5,
		update = function(self, dt)
			if self.tweening then
				local complete = self.tweening:update(dt)
				if complete then
					queue.add(25, self.remove, self)
					self.tweening = nil
				end
			end
		end
	}
	local action = particles.superEffects3:new{
		image = self.action_image,
		x = x_pos,
		y = stage.height * 0.5,
		update = function(self, dt)
			if self.tweening then
				local complete = self.tweening:update(dt)
				if complete then
					queue.add(25, self.remove, self)
					self.tweening = nil
				end
			end
		end
	}

	local fuzz1 = particles.superEffects1:new{
		image = self.super_fuzz_image,
		x = stage.width * 0.5,
		y = self.super_fuzz_image:getHeight() * -0.5,
		update = function(self, dt)
			if self.tweening then
				local complete = self.tweening:update(dt)
				if complete then
					queue.add(40, self.remove, self)
					self.tweening = nil
				end
			end
		end
	}

	local fuzz2 = particles.superEffects1:new{
		image = self.super_fuzz_image,
		x = stage.width * 0.5,
		y = self.super_fuzz_image:getHeight() * 0.5 + stage.height,
		update = function(self, dt)
			if self.tweening then
				local complete = self.tweening:update(dt)
				if complete then
					queue.add(40, self.remove, self)
					self.tweening = nil
				end
			end
		end
	}

	fuzz1.tweening = tween.new(0.35, fuzz1, {y = 0}, "outQuart")
	fuzz2.tweening = tween.new(0.35, fuzz2, {y = stage.height}, "outQuart")

	if self.ID == "P1" then
		action.tweening = tween.new(0.5, action, {x = stage.width * 0.475}, "outQuart")
		shadow.tweening = tween.new(0.5, shadow, {x = stage.width * 0.525}, "outQuart")
	else
		action.tweening = tween.new(0.5, action, {x = stage.width * 0.525}, "outQuart")
		shadow.tweening = tween.new(0.5, shadow, {x = stage.width * 0.475}, "outQuart")
		shadow.flip, action.flip = true, true
	end
end

return character
