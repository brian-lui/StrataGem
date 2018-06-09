local love = _G.love
require 'inits'
local common = require "class.commons"
local image = require 'image'
local Pic = require 'pic'
local Hand = require 'hand'

local Character = {}
Character.full_size_image = love.graphics.newImage('images/portraits/heath.png')
Character.small_image = love.graphics.newImage('images/portraits/heathsmall.png')
Character.action_image = love.graphics.newImage('images/portraits/action_heath.png')
Character.shadow_image = love.graphics.newImage('images/portraits/shadow_heath.png')
Character.super_fuzz_image = love.graphics.newImage('images/ui/superfuzzred.png')

Character.character_id = "Lamer"
Character.meter_gain = {red = 4, blue = 4, green = 4, yellow = 4, none = 4, wild = 4}
Character.primary_colors = {"red"}

Character.super_images = {
	word = image.ui_super_text_red,
	empty = image.ui_super_empty_red,
	full = image.ui_super_full_red,
	glow = image.ui_super_glow_red,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Character.burst_images = {
	partial = image.ui_burst_part_red,
	full = image.ui_burst_full_red,
	glow = {image.ui_burst_partglow_red, image.ui_burst_fullglow_red}
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
Character.gain_super_meter = nil -- set to 'false' if don't wanna gain meter from matches
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

-- called every frame
function Character:update(dt) end

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
function Character:afterAllMatches()
-- after all chain combos finished.
-- Can be called multiple times in a turn if garbage is created
end
function Character:beforeCleanup() end
function Character:cleanup()
	self.supering = false
	self.game:brightenScreen(self.player_num)
end
function Character:customGemTable() -- custom gem frequency and gem replacement
	-- first arg is frequency: {red = 1, blue = 2, green = 3, ...} or function
	-- second arg is replacement: {{color = "red", image = dog.png}, ...} or function
	local gem_freq_table, gem_replace_table = nil, nil
	return gem_freq_table, gem_replace_table
end

-------------------------------------------------------------------------------

function Character:toggleSuper()
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
