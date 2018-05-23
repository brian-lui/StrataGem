local love = _G.love
require 'inits'
local common = require "class.commons"
local image = require 'image'
local Pic = require 'pic'
local Hand = require 'hand'

local Character = {}
Character.full_size_image = love.graphics.newImage('images/portraits/heath.png')
Character.small_image = love.graphics.newImage('images/portraits/heathsmall.png')
Character.action_image = love.graphics.newImage('images/portraits/heathaction.png')
Character.shadow_image = love.graphics.newImage('images/portraits/heathshadow.png')
Character.super_fuzz_image = love.graphics.newImage('images/ui/superfuzzred.png')

Character.character_id = "Lamer"
Character.meter_gain = {red = 4, blue = 4, green = 4, yellow = 4}
Character.primary_colors = {"red"}

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
Character.MAX_BURST = 6
Character.RUSH_COST = 3
Character.DOUBLE_COST = 3
Character.cur_burst = 3
Character.hand_size = 5
Character.garbage_rows_created = 0
Character.dropped_piece = nil
Character.supering = false
Character.super_params = {}
Character.place_type = "none"
Character.CAN_SUPER_AND_PLAY_PIECE = false -- this is always false now

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
	self.mp = self.mp + amt
end

function Character:addDamage(damage, delay)
	delay = delay or 0
	self.game.queue:add(delay, function()
		self.hand.damage = math.min(self.hand.damage + damage, self.MAX_DAMAGE)
	end)
end

function Character:healDamage(damage, delay)
	delay = delay or 0
	self.game.queue:add(delay, function() self.hand.damage = self.hand.damage - damage end)
end

-- do those things to set up the character. Called at start of match
function Character:setup()
	local stage = self.game.stage

	self.hand = Hand:create{game = self.game, player = self}
	self.hand:makeInitialPieces()

	-- character animation placeholder, waiting for animations
	self.animation = Pic:create{
		game = self.game,
		x = stage.character[self.ID].x,
		y = stage.character[self.ID].y,
		image = self.small_image,
	}
end

function Character:emptyMP()
	self.mp = 0
end

-- For netplay: how to serialize the Super parameters
function Character:serializeSuperDeltaParams()
	return ""
end

-- For netplay: how to serialize the character specials, for gamestate
function Character:serializeSpecials()
	return ""
end

-- For replays: how to deserialize the character specials
function Character:deserializeSpecials()
end

-------------------------------------------------------------------------------
-- All these abilities can optionally return the number of frames
-- to pause for the animation.
-------------------------------------------------------------------------------
function Character:actionPhase(dt) end
function Character:beforeGravity() end
function Character:beforeTween() end
function Character:afterGravity() end
function Character:beforeMatch() end -- before gems are matched
function Character:duringMatch() end -- while matches are exploding
function Character:afterMatch() end -- after each match
function Character:whenCreatingGarbageRow() end -- at garbage row creation
function Character:modifyGemTable() end -- provide custom gem table
function Character:afterAllMatches()
-- after all chain combos finished.
-- Can be called multiple times in a turn if garbage is created
end
function Character:beforeCleanup() end

function Character:cleanup()
	self.supering = false
	self.game:brightenScreen(self.player_num)
end
-------------------------------------------------------------------------------

function Character:toggleSuper(received_from_opponent)
	local game = self.game
	if game.current_phase ~= "Action" then return end

	if self.supering then
		self.supering = false
		self.game.sound:newSFX("buttonbacksuper")
	elseif self.mp >= self.SUPER_COST and self.game.current_phase == "Action" then
		self.supering = true
		self.game.sound:newSFX("buttonsuper")
	end
	return self.supering
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

-- gets whether the player can still place a piece this turn
function Character:canPlacePiece()
	return not (
		(self.supering and not self.CAN_SUPER_AND_PLAY_PIECE) or
		(self.dropped_piece == "rushed" or self.dropped_piece == "doubled") or
		(self.dropped_piece == "normal" and self.cur_burst < self.current_double_cost)
	)
end

function Character:canUseSuper()
	return (self.mp >= self.SUPER_COST) and (self.CAN_SUPER_AND_PLAY_PIECE or not self.dropped_piece)
end

return common.class("Character", Character)
