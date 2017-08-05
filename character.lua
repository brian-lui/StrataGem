local love = _G.love
require 'inits'
local common = require "class.commons"
local image = require 'image'
local Pic = require 'pic'
local Hand = require 'hand'

local Character = {}
--Character.defaults = require 'characters/default' -- called from charselect
--Character.heath = require 'characters/heath'
--Character.walter = require 'characters/walter'
--Character.gail = require 'characters/gail'

Character.full_size_image = love.graphics.newImage('images/characters/heath.png')
Character.small_image = love.graphics.newImage('images/characters/heathsmall.png')
Character.action_image = love.graphics.newImage('images/characters/heathaction.png')
Character.shadow_image = love.graphics.newImage('images/characters/heathshadow.png')
Character.super_fuzz_image = love.graphics.newImage('images/ui/superfuzzred.png')

Character.character_id = "Lamer"
Character.meter_gain = {red = 4, blue = 4, green = 4, yellow = 4}

Character.super_images = {
	word = image.UI.super.red_word,
	empty = love.graphics.newImage('images/characters/emptyheath.png'),
	full = love.graphics.newImage('images/characters/fullheath.png'),
	glow = love.graphics.newImage('images/characters/fullheathglow.png')
}

Character.burst_images = {
	partial = image.UI.burst.red_partial,
	full = image.UI.burst.red_full,
	glow = {image.UI.burst.red_glow1, image.UI.burst.red_glow2}
}

assert(image.UI.burst.red_partial)
assert(Character.burst_images.partial)

Character.MAX_MP = 64
Character.SUPER_COST = 64
Character.mp = 0
Character.turn_start_mp = 0
Character.MAX_BURST = 6
Character.RUSH_COST = 6
Character.DOUBLE_COST = 3
Character.cur_burst = 3
Character.hand_size = 5
Character.pieces_fallen = 0
Character.dropped_piece = false
Character.super_clicked = false
Character.supering = false
Character.super_this_turn = false
Character.place_type = "normal"

function Character:init(playerNum, game)
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

function Character:addSuper(amt)
	self.mp = math.min(self.mp + amt, self.MAX_MP)
end

-- do those things to set up the character. Called at start of match
function Character:setup()
	self.hand = common.instance(Hand, self.game, self)
	self.hand:makeInitialPieces()
	setupBurstMeter(self)
	setupSuperMeter(self)
	createCharacterAnimation(self)
end

function Character:actionPhase(dt)
end

-- returns a list of {frames, func, args to execute}
function Character:afterGravity()
	return {}
end


function Character:beforeMatch(gem_table)
end

function Character:duringMatch(gem_table)
end

function Character:afterMatch()
end

function Character:cleanup()
	self:resetMP()
end

function Character:resetMP()
	self.turn_start_mp = self.mp
end

function Character:activateSuper()
	if self.mp >= self.SUPER_COST then
		self.supering = not self.supering
	end
end

function Character:pieceDroppedOK(piece, shift)
	local _, place_type = piece:isDropValid(shift)
	if place_type == "normal" then
		return true
	elseif place_type == "rush" then
		return self.cur_burst >= self.current_rush_cost
	elseif place_type == "double" then
		return self.cur_burst >= self.current_double_cost
	end
end


function Character:superSlideIn()
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
	portrait:moveTo{duration = 30, x = stage.width * (0.5 + 0.025 * sign), easing = "outQuart"}
	portrait:wait(25)
	portrait:moveTo{duration = 5, transparency = 0, exit = true}

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

return common.class("Character", Character)
