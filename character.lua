local love = _G.love
require 'inits'
local common = require "class.commons"
local image = require 'image'
local Pic = require 'pic'
local Hand = require 'hand'

local Character = {}
Character.full_size_image = love.graphics.newImage('images/characters/heath.png')
Character.small_image = love.graphics.newImage('images/characters/heathsmall.png')
Character.action_image = love.graphics.newImage('images/characters/heathaction.png')
Character.shadow_image = love.graphics.newImage('images/characters/heathshadow.png')
Character.super_fuzz_image = love.graphics.newImage('images/ui/superfuzzred.png')

Character.character_id = "Lamer"
Character.meter_gain = {red = 4, blue = 4, green = 4, yellow = 4}

Character.super_images = {
	word = image.UI.super.red_word,
	empty = image.UI.super.red_empty,
	full = image.UI.super.red_full,
	glow = image.UI.super.red_glow,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Character.burst_images = {
	partial = image.UI.burst.red_partial,
	full = image.UI.burst.red_full,
	glow = {image.UI.burst.red_glow1, image.UI.burst.red_glow2}
}

Character.sounds = {
	bgm = "bgm_heath",
}

Character.MAX_DAMAGE = 20
Character.MAX_MP = 64
Character.SUPER_COST = 64
Character.mp = 0
Character.turn_start_mp = 0
Character.MAX_BURST = 6
Character.RUSH_COST = 3
Character.DOUBLE_COST = 3
Character.cur_burst = 3
Character.hand_size = 5
Character.garbage_rows_created = 0
Character.dropped_piece = false
Character.supering = false
Character.super_params = {}
Character.super_this_turn = false
Character.place_type = "normal"

function Character:init(player_num, game)
	self.game = game
	self.player_num = player_num
	if player_num == 1 then
		self.ID, self.start_col, self.end_col = "P1", 1, 4
	elseif player_num == 2 then
		self.ID, self.start_col, self.end_col = "P2", 5, 8
	else
		love.errhand("Invalid player_num " .. tostring(player_num))
	end
	self.current_rush_cost = self.RUSH_COST
	self.current_double_cost = self.DOUBLE_COST
	self.played_pieces = {}
	self:setup()
end

function Character:addSuper(amt)
	self.mp = math.min(self.mp + amt, self.MAX_MP)
end

function Character:addDamage(damage)
	self.hand.damage = math.min(self.hand.damage + damage, self.MAX_DAMAGE)
end

-- do those things to set up the character. Called at start of match
function Character:setup()
	local stage = self.game.stage

	self.hand = common.instance(Hand, self.game, self)
	self.hand:makeInitialPieces()

	-- super meter
	self.super_frame = common.instance(Pic, self.game, {x = stage.super[self.ID].x,
		y = stage.super[self.ID].y, image = self.super_images.empty})
	self.super_word = common.instance(Pic, self.game, {x = stage.super[self.ID].x,
		y = stage.super[self.ID].word_y, image = self.super_images.word})
	self.super_meter_image = common.instance(Pic, self.game, {x = stage.super[self.ID].x,
		y = stage.super[self.ID].y, image = self.super_images.full})
	self.super_glow = common.instance(Pic, self.game, {x = stage.super[self.ID].x,
		y = stage.super[self.ID].y, image = self.super_images.glow})
	self.super_overlay = common.instance(Pic, self.game, {x = stage.super[self.ID].x,
		y = stage.super[self.ID].y, image = self.super_images.overlay})

	-- character animation placeholder, waiting for animations
	self.animation = common.instance(Pic, self.game, {x = self.game.stage.character[self.ID].x,
	y = self.game.stage.character[self.ID].y, image = self.small_image})

end

function Character:actionPhase(dt)
end


-------------------------------------------------------------------------------
-- All these abilities can optionally return the number of frames
-- to pause for the animation.
-------------------------------------------------------------------------------
function Character:beforeGravity() end
function Character:afterGravity() end
function Character:beforeMatch() end -- before gems are matched
function Character:duringMatchAnimation() end -- while matches are exploding
function Character:afterMatch() end -- after each match
function Character:whenCreatingGarbageRow() end -- at garbage row creation
function Character:afterAllMatches() end -- after all chain combos finished
function Character:beforeCleanup() end

function Character:cleanup()
	self:resetMP()
	self.supering = false
	self.super_this_turn = false
end

function Character:resetMP()
	self.turn_start_mp = self.mp
end

function Character:toggleSuper(received_from_opponent)
	local game = self.game
	if game.current_phase ~= "Action" then return end

	if self.supering then
		self.supering = false
		if game.type == "Netplay" and not received_from_opponent then
			game.client.prepareDelta(game.client, self, "cancelsuper", self.super_params)
		end
		self.game.sound:newSFX("buttonbacksuper")
	elseif self.mp >= self.SUPER_COST and self.game.current_phase == "Action" then
		self.supering = true
		if game.type == "Netplay" and not received_from_opponent then
			game.client.prepareDelta(game.client, self, "super", self.super_params)
		end
		self.game.sound:newSFX("buttonsuper")
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


function Character:superSlideInAnim(delay_frames)
	local delay = self.game.particles.superFreezeEffects.generate(self.game, self,
		self.shadow_image, self.action_image, self.super_fuzz_image, delay_frames)
	return delay
end

return common.class("Character", Character)
