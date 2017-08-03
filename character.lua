local love = _G.love
require 'inits'
local common = require "class.commons"
local image = require 'image'
local tween = require 'tween'
local pic = require 'pic'
local Hand = require 'hand'

local character = {}
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
	partial = image.UI.super.red_partial,
	full = image.UI.super.red_full,
	glow = {image.UI.super.red_glow1, image.UI.super.red_glow2, image.UI.super.red_glow3, image.UI.super.red_glow4}
}
character.SUPER_COST = 64
character.RUSH_COST = 32
character.DOUBLE_COST = 16
character.MAX_MP = 64
character.cur_mp = 0
character.old_mp = 0
character.hand_size = 5
character.pieces_fallen = 0
character.dropped_piece = false
character.super_clicked = false
character.supering = false
character.super_this_turn = false
character.place_type = "normal"

function character:init(playerNum, game)
	self.game = game
	self.playerNum = playerNum
	if playerNum == 1 then
		self.ID, self.start_col, self.end_col = "P1", 1, 4
	elseif playerNum == 2 then
		self.ID, self.start_col, self.end_col = "P2", 5, 8
	else
		love.errhand("Invalid playerNum " .. tostring(playerNum))
	end
	self.current_rush_cost = self.RUSH_COST
	self.current_double_cost = self.DOUBLE_COST
	self.played_pieces = {}
	self:setup()
end

-- initialize super meter graphics
local function setupSuperMeter(self)
	local stage = self.game.stage
	local super_frame = self.ID == "P1" and image.UI.gauge_gold or image.UI.gauge_silver
	self.super_frame = common.instance(pic, {x = stage.super[self.ID].frame.x,
		y = stage.super[self.ID].frame.y, image = super_frame})
	self.super_word = common.instance(pic, {x = stage.super[self.ID].frame.x,
		y = stage.super[self.ID].frame.y, image = self.super_images.word})
	self.super_block = {}
	self.super_partial = {}
	self.super_glow = {}
	for i = 1, 4 do
		self.super_block[i] = common.instance(pic, {x = stage.super[self.ID][i].x,
			y = stage.super[self.ID][i].y, image = self.super_images.full})
		self.super_partial[i] = common.instance(pic, {x = stage.super[self.ID][i].x,
			y = stage.super[self.ID][i].y, image = self.super_images.partial})
		self.super_glow[i] = common.instance(pic, {x = stage.super[self.ID][i].glow_x,
			y = stage.super[self.ID][i].glow_y, image = self.super_images.glow[i]})

	end
	self.super_glow.full = common.instance(pic, {x = stage.super[self.ID][4].glow_x,
		y = stage.super[self.ID][4].glow_y, image = self.super_images.glow[4]})
	self.super_glow.full.scaling = 0
end

-- placeholder, waiting for animations
local function createCharacterAnimation(self)
	self.animation = common.instance(pic, {x = self.game.stage.character[self.ID].x,
	y = self.game.stage.character[self.ID].y, image = self.small_image})
end


local function setupPieces(self)
	self.pieces_per_turn_init = self.pieces_per_turn_init or 1
	self.pieces_per_turn = self.pieces_per_turn_init
	self.pieces_to_get = 1
end

-- TODO: Make player and/or character into classes and put this in there
function character:addSuper(amt)
	self.old_mp = self.cur_mp
	self.cur_mp = math.min(self.cur_mp + amt, self.MAX_MP)
end

-- do those things to set up the character. Called at start of match
function character:setup()
	self.hand = common.instance(Hand, self.game, self)
	self.hand:makeInitialPieces()
	setupSuperMeter(self)
	createCharacterAnimation(self)
	setupPieces(self)
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

function character:super()
	if self.cur_mp >= self.SUPER_COST then
		self.super_glow.full.scaling = 0
		self.supering = not self.supering
	end
end

function character:pieceDroppedOK(piece, shift)
	local _, place_type = piece:isDropValid(shift)
	if place_type == "normal" then
		return true
	elseif place_type == "rush" then
		return self.cur_mp >= (self.current_rush_cost) and not self.supering
	elseif place_type == "double" then
		return self.cur_mp >= (self.current_double_cost) and not self.supering
	end
end


function character:superSlideIn()
	local stage = self.game.stage
	local x_pos = self.ID == "P1" and stage.width * -0.2 or stage.width * 1.2

	local particles = self.game.particles

	local shadow = common.instance(particles.superEffects2, {
		image = self.shadow_image,
		x = x_pos,
		y = stage.height * 0.5,
		update = function(_self, dt)
			if _self.tweening then
				local complete = _self.tweening:update(dt)
				if complete then
					self.game.queue.add(25, _self.remove, _self)
					_self.tweening = nil
				end
			end
		end
	})
	local action = common.instance(particles.superEffects3, {
		image = self.action_image,
		x = x_pos,
		y = stage.height * 0.5,
		update = function(_self, dt)
			if _self.tweening then
				local complete = _self.tweening:update(dt)
				if complete then
					self.game.queue.add(25, _self.remove, _self)
					_self.tweening = nil
				end
			end
		end
	})

	local fuzz1 = common.instance(particles.superEffects1, {
		image = self.super_fuzz_image,
		x = stage.width * 0.5,
		y = self.super_fuzz_image:getHeight() * -0.5,
		update = function(_self, dt)
			if _self.tweening then
				local complete = _self.tweening:update(dt)
				if complete then
					self.game.queue.add(40, _self.remove, _self)
					_self.tweening = nil
				end
			end
		end
	})

	local fuzz2 = common.instance(pic, particles.superEffects1, {
		image = self.super_fuzz_image,
		x = stage.width * 0.5,
		y = self.super_fuzz_image:getHeight() * 0.5 + stage.height,
		update = function(_self, dt)
			if _self.tweening then
				local complete = _self.tweening:update(dt)
				if complete then
					self.game.queue.add(40, _self.remove, _self)
					_self.tweening = nil
				end
			end
		end
	})

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

return common.class("Character", character)
