local love = _G.love
require 'inits'
local common = require "class.commons"
local image = require 'image'
local Pic = require 'pic'
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
character.meter_gain = {red = 4, blue = 4, green = 4, yellow = 4}
--[[
character.super_images = {
	word = image.UI.super.red_word,
	empty = love.graphics.newImage('images/characters/emptyheath.png'),
	full = love.graphics.newImage('images/characters/fullheath.png'),
	glow = love.graphics.newImage('images/characters/fullheathglow.png')
}--]]
character.burst_images = {
	partial = image.UI.burst.red_partial,
	full = image.UI.burst.red_full,
	glow = {image.UI.burst.red_glow1, image.UI.burst.red_glow2}
}
character.MAX_MP = 64
character.SUPER_COST = 64
character.mp = 0
character.turn_start_mp = 0
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
	local game = self.game
	local stage = game.stage
	self.super_frame = common.instance(Pic, game, {x = stage.super[self.ID].x,
		y = stage.super[self.ID].y, image = self.super_images.empty})
	self.super_word = common.instance(Pic, game, {x = stage.super[self.ID].x,
		y = stage.super[self.ID].word_y, image = self.super_images.full})
	self.super_meter_image = common.instance(Pic, game, {x = stage.super[self.ID].x,
		y = stage.super[self.ID].y, image = self.super_images.full})
	self.super_glow = common.instance(Pic, game, {x = stage.super[self.ID].x,
		y = stage.super[self.ID].y, image = self.super_images.glow})
end

-- initialize burst meter graphics
local function setupBurstMeter(self)
	local stage = self.game.stage
	local burst_frame = self.ID == "P1" and image.UI.gauge_gold or image.UI.gauge_silver
	self.burst_frame = common.instance(Pic, self.game, {x = stage.burst[self.ID].frame.x,
		y = stage.burst[self.ID].frame.y, image = burst_frame})
	self.burst_block = {}
	self.burst_partial = {}
	self.burst_glow = {}
	for i = 1, 2 do
		self.burst_block[i] = common.instance(Pic, self.game, {x = stage.burst[self.ID][i].x,
			y = stage.burst[self.ID][i].y, image = self.burst_images.full})
		self.burst_partial[i] = common.instance(Pic, self.game, {x = stage.burst[self.ID][i].x,
			y = stage.burst[self.ID][i].y, image = self.burst_images.partial})
		self.burst_glow[i] = common.instance(Pic, self.game, {x = stage.burst[self.ID][i].x,
			y = stage.burst[self.ID][i].y, image = self.burst_images.glow[i]})
	end
end

-- placeholder, waiting for animations
local function createCharacterAnimation(self)
	self.animation = common.instance(Pic, self.game, {x = self.game.stage.character[self.ID].x,
	y = self.game.stage.character[self.ID].y, image = self.small_image})
end

function character:addSuper(amt)
	self.mp = math.min(self.mp + amt, self.MAX_MP)
end

-- do those things to set up the character. Called at start of match
function character:setup()
	self.hand = common.instance(Hand, self.game, self)
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
	self.turn_start_mp = self.mp
end

function character:activateSuper()
	if self.mp >= self.SUPER_COST then
		self.supering = not self.supering
	end
end

function character:pieceDroppedOK(piece, shift)
	local _, place_type = piece:isDropValid(shift)
	if place_type == "normal" then
		return true
	elseif place_type == "rush" then
		return self.cur_burst >= self.current_rush_cost
	elseif place_type == "double" then
		return self.cur_burst >= self.current_double_cost
	end
end


function character:superSlideIn()
	local stage = self.game.stage
	local particles = self.game.particles
	local sign = self.ID == "P2" and -1 or 1

	local shadow = common.instance(particles.superFreezeEffects, {
		image = self.shadow_image,
		draw_order = 2,
		x = stage.width * (0.5 - sign * 0.7),
		y = stage.height * 0.5,
		flip = sign == -1
	})
	shadow:moveTo{duration = 30, x = stage.width * (0.5 + 0.025 * sign), easing = "outQuart"}
	shadow:wait(25)
	shadow:moveTo{duration = 5, transparency = 0, exit = true}
	local portrait = common.instance(particles.superFreezeEffects, {
		image = self.action_image,
		draw_order = 3,
		x = stage.width * (0.5 - sign * 0.7),
		y = stage.height * 0.5,
		flip = sign == -1
	})
	shadow:moveTo{duration = 30, x = stage.width * (0.5 + 0.025 * sign), easing = "outQuart"}
	shadow:wait(25)
	shadow:moveTo{duration = 5, transparency = 0, exit = true}

	local top_fuzz = common.instance(particles.superFreezeEffects, {
		image = self.super_fuzz_image,
		draw_order = 1,
		x = stage.width * 0.5,
		y = self.super_fuzz_image:getHeight() * -0.5
	})
	top_fuzz:moveTo{duration = 21, y = 0, easing = "outQuart"}
	top_fuzz:wait(40)
	top_fuzz:moveTo{duration = 5, transparency = 0, exit = true}

	local bottom_fuzz = common.instance(particles.superFreezeEffects, {
		image = self.super_fuzz_image,
		draw_order = 1,
		x = stage.width * 0.5,
		y = self.super_fuzz_image:getHeight() * 0.5 + stage.height,
	})
	bottom_fuzz:moveTo{duration = 21, y = stage.height, easing = "outQuart"}
	bottom_fuzz:wait(40)
	bottom_fuzz:moveTo{duration = 5, transparency = 0, exit = true}
end

return common.class("Character", character)
