--[[
This is the base class for all characters in the game, which is used as a
template by the individual characters.
--]]

local love = _G.love
local common = require "class.commons"
local images = require "images"
local Pic = require "pic"
local Hand = require "hand"

local Character = {}
Character.large_image = love.graphics.newImage('images/portraits/heath.png')
Character.small_image = love.graphics.newImage('images/portraits/heathsmall.png')
Character.action_image = love.graphics.newImage('images/portraits/action_heath.png')
Character.shadow_image = love.graphics.newImage('images/portraits/shadow_heath.png')
Character.super_fuzz_image = love.graphics.newImage('images/ui/superfuzzred.png')

Character.character_name = "Lamer"
Character.meter_gain = {
	red = 4,
	blue = 4,
	green = 4,
	yellow = 4,
	none = 4,
	wild = 4,
}
Character.primary_colors = {"red"}

Character.super_images = {
	word = images.ui_super_text_red,
	empty = images.ui_super_empty_red,
	full = images.ui_super_full_red,
	glow = images.ui_super_glow_red,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Character.burst_images = {
	partial = images.ui_burst_part_red,
	full = images.ui_burst_full_red,
	glow = {images.ui_burst_partglow_red, images.ui_burst_fullglow_red}
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
Character.DOUBLE_COST = 6
Character.cur_burst = 3
Character.hand_size = 5
Character.garbage_rows_created = 0
Character.dropped_piece = nil
Character.is_supering = false
Character.super_params = {}
Character.can_gain_super = true -- set false to gain no meter from matches
Character.CAN_SUPER_AND_PLAY_PIECE = false -- this is always false now
Character.is_further_action_possible = true

function Character:init(player_num, game)
	self.game = game
	self.player_num = player_num
	if player_num == 1 then
		self.start_col, self.end_col = 1, 4
	elseif player_num == 2 then
		self.start_col, self.end_col = 5, 8
	else
		love.errhand("Invalid player_num " .. tostring(player_num))
	end
	self.current_rush_cost = self.RUSH_COST
	self.current_double_cost = self.DOUBLE_COST
	self.played_pieces = {}
	self:setup()
	self.super_button = game.uielements.superMeter.create(
		game,
		self,
		player_num
	)
end

function Character:addSuper(amt)
	if self.can_gain_super then self.mp = self.mp + amt end
end

function Character:addDamage(damage, delay)
	delay = delay or 0
	self.game.queue:add(delay, function()
		self.hand.damage = math.min(self.hand.damage + damage, self.MAX_DAMAGE)
	end)
end

function Character:healDamage(damage, delay)
	delay = delay or 0
	self.game.queue:add(
		delay,
		function() self.hand.damage = self.hand.damage - damage end
	)
end

-- do those things to set up the character. Called at start of match
function Character:setup()
	local stage = self.game.stage

	self.hand = Hand:create{game = self.game, player = self}
	self.hand:makeInitialPieces()

	-- character animation placeholder, waiting for animations
	Pic:create{
		game = self.game,
		x = stage.character[self.player_num].x,
		y = stage.character[self.player_num].y,
		image = self.small_image,
		container = self,
		name = "animation",
	}
end

function Character:emptyMP()
	self.mp = 0
end

-- For netplay: how to serialize the Super parameters
function Character:serializeSuperDeltaParams()
	return ""
end

-- For netplay: how to serialize the passive ability parameters
function Character:serializePassiveDeltaParams()
	return ""
end


-- For netplay: how to serialize the character specials, for gamestate
-- Do NOT use _ character! That will overload the gamestate deserializer
function Character:serializeSpecials()
	return ""
end

-- For replays: how to deserialize the character specials
function Character:deserializeSpecials()
end

-- Called every frame
function Character:update(dt) end

-------------------------------------------------------------------------------
-- No return values accepted
function Character:actionPhase(dt) end

-- Delay accepted as return value
function Character:beforeGravity() end

-- Delay accepted as return value
function Character:beforeTween() end

-- Delay accepted as return value
function Character:duringTween() end

-- (delay, whether to go to gravity phase) accepted as return values
function Character:afterGravity() end

-- Before gems are matched. delay accepted as return value
function Character:beforeMatch() end

-- Right after matches are destroyed. delay accepted as return value
function Character:duringMatch() end

-- After each match round finished. delay accepted as return value
function Character:afterMatch() end

 -- At garbage row creation. delay accepted as return value
function Character:whenCreatingGarbageRow() end

-- After all chain combos finished.
-- Note: can be called multiple times in a turn if garbage is created.
-- (delay, whether to go to gravity phase) accepted as return values
function Character:afterAllMatches() end

-- After afterAllMatches phase, if it doesn't go back to gravity
function Character:beforeDestroyingPlatforms() end

-- (delay, whether to go to gravity phase) accepted as return values
function Character:beforeCleanup() end

-- delay accepted as return value
function Character:cleanup()
	self.is_supering = false
	self.is_further_action_possible = true	
	self.game:brightenScreen(self.player_num)
end

--[[ custom gem frequency and gem replacement
first arg is frequency: {red = 1, blue = 2, green = 3, ...}
second arg is replacement: {{color = "red", image = dog.png}, ...}
accepts functions that return the tables too --]]
function Character:customGemTable()
	local gem_freq_table, gem_replace_table = nil, nil
	return gem_freq_table, gem_replace_table
end

-- callback when gem is destroyed, at start. passes in time to gem explosion
function Character:onGemDestroyStart(gem, delay) end

-- callback when gem is destroyed, at end. passes in time to gem explosion
function Character:onGemDestroyEnd(gem, delay) end

-------------------------------------------------------------------------------

function Character:toggleSuper()
	local game = self.game
	if game.current_phase ~= "Action" then return end

	if self.is_supering then
		self.is_supering = false
		game.sound:newSFX("buttonbacksuper")
	elseif self.mp >= self.SUPER_COST and game.current_phase == "Action" then
		self.is_supering = true
		game.sound:newSFX("buttonsuper")
	end
	return self.is_supering
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
	local delay = self.game.particles.superFreezeEffects.generate(
		self.game,
		self,
		self.shadow_image,
		self.action_image,
		self.super_fuzz_image,
		delay_frames
	)
	return delay
end

-- gets whether the player can still place a piece this turn
function Character:canPlacePiece()
	return not (
		(self.is_supering and not self.CAN_SUPER_AND_PLAY_PIECE) or
		(self.dropped_piece == "rushed" or self.dropped_piece == "doubled") or
		(self.dropped_piece == "normal" and self.cur_burst < self.current_double_cost)
	)
end

function Character:canUseSuper()
	return (self.mp >= self.SUPER_COST) and
		(self.CAN_SUPER_AND_PLAY_PIECE or not self.dropped_piece)
end

function Character:canUsePassive()
	return false
end

function Character:updateFurtherAction()
	if self:canPlacePiece() or self:canUsePassive() then
		self.is_further_action_possible = true
	elseif self:canUseSuper() then
		self.is_further_action_possible = self.is_supering and "super" or true
	else
		self.is_further_action_possible = false
	end
end

return common.class("Character", Character)
