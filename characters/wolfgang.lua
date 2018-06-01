--[[ Color: blue
Passive: Wolfgang has a BARK meter. Every time you make a match of a certain
color, the BARK meter gains a letter. (Blue, Amarillo, Red, Kreen). When the
Bark meter is filled, your next gem cluster you gain will contain a Dog piece.
Dogs placed in your basin are good dogs. Good dogs are wild and last until
matched. Basins placed in the opponent's basin (rush) are bad dogs. Bad dogs
do not listen and do nothing. They last for 3 turns and then go home.

Super: Up to four non-wilds in your half of the basin are replaced with
friendly dogs.
--]]

local love = _G.love
local common = require "class.commons"
local Character = require "character"
local image = require 'image'
local Pic = require 'pic'
local Piece = require 'piece'
local Wolfgang = {}

Wolfgang.full_size_image = love.graphics.newImage('images/portraits/wolfgang.png')
Wolfgang.small_image = love.graphics.newImage('images/portraits/wolfgangsmall.png')
Wolfgang.character_id = "Wolfgang"
Wolfgang.meter_gain = {red = 8, blue = 4, green = 4, yellow = 4, none = 4, wild = 4}

Wolfgang.super_images = {
	word = image.ui_super_text_red,
	empty = image.ui_super_empty_red,
	full = image.ui_super_full_red,
	glow = image.ui_super_glow_red,
	overlay = love.graphics.newImage('images/characters/wolfgang/wolfganglogo.png'),
}
Wolfgang.burst_images = {
	partial = image.ui_burst_part_red,
	full = image.ui_burst_full_red,
	glow = {image.ui_burst_partglow_red, image.ui_burst_fullglow_red}
}

Wolfgang.special_images = {
	good_dog = {
		love.graphics.newImage('images/characters/wolfgang/goodblacklab.png'),
		love.graphics.newImage('images/characters/wolfgang/goodgoldenlab.png'),
		love.graphics.newImage('images/characters/wolfgang/goodrussel.png'),
	},
	bad_dog = {
		love.graphics.newImage('images/characters/wolfgang/badblacklab.png'),
		love.graphics.newImage('images/characters/wolfgang/badgoldenlab.png'),
		love.graphics.newImage('images/characters/wolfgang/badrussel.png'),
	},
	dog_explode = {
		image.gems_explode_red,
		image.gems_explode_red,
		image.gems_explode_red,
	},
	dog_grey = {
		image.gems_grey_red,
		image.gems_grey_red,
		image.gems_grey_red,
	},
	dog_pop = {
		image.gems_pop_red,
		image.gems_pop_red,
		image.gems_pop_red,
	},
	red = {
		dark = love.graphics.newImage('images/characters/wolfgang/r.png'),
		glow = love.graphics.newImage('images/characters/wolfgang/rglow.png'),
		word = love.graphics.newImage('images/characters/wolfgang/red.png'),
	},
	blue = {
		dark = love.graphics.newImage('images/characters/wolfgang/b.png'),
		glow = love.graphics.newImage('images/characters/wolfgang/bglow.png'),
		word = love.graphics.newImage('images/characters/wolfgang/blue.png'),
	},
	green = {
		dark = love.graphics.newImage('images/characters/wolfgang/k.png'),
		glow = love.graphics.newImage('images/characters/wolfgang/kglow.png'),
		word = love.graphics.newImage('images/characters/wolfgang/kreen.png'),
	},
	yellow = {
		dark = love.graphics.newImage('images/characters/wolfgang/a.png'),
		glow = love.graphics.newImage('images/characters/wolfgang/aglow.png'),
		word = love.graphics.newImage('images/characters/wolfgang/amarillo.png'),
	},
}

Wolfgang.sounds = {
	bgm = "bgm_wolfgang",
}

function Wolfgang:init(...)
	Character.init(self, ...)
	local game = self.game
	local stage = game.stage

	-- init BARK
	local add = self.player_num == 2 and stage.width * 0.77 or 0
	local x = {
		stage.width * 0.055 + add,
		stage.width * 0.095 + add,
		stage.width * 0.135 + add,
		stage.width * 0.175 + add,
	}
	local y = stage.height * 0.57
	self.letters = {
		blue = self.fx.colorLetter.generate(game, self, x[1], y, "blue"),
		yellow = self.fx.colorLetter.generate(game, self, x[2], y, "yellow"),
		red = self.fx.colorLetter.generate(game, self, x[3], y, "red"),
		green = self.fx.colorLetter.generate(game, self, x[4], y, "green"),
	}

	self.FULL_BARK_DOG_ADDS = 2
	self.BAD_DOG_DURATION = 1
	self.SUPER_DOG_CREATION_DELAY = 45 -- in frames
	self.this_turn_matched_colors = {}
	self.bad_dogs = {} -- dict of {dog-gem, turns remaining to disappearance}
	self.single_dogs_to_make, self.double_dogs_to_make = 0, 0
end
-------------------------------------------------------------------------------
-- These are the BARK letter classes
local ColorLetter = {}
function ColorLetter:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	manager.allParticles.CharEffects[ID.particle] = self
	self.manager = manager
	self.game = manager.game
end

function ColorLetter:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

-- BARK meter appears below the super meter.
function ColorLetter.generate(game, owner, x, y, color)
	local params = {
		x = x,
		y = y,
		image = owner.special_images[color].dark,
		owner = owner,
		player_num = owner.player_num,
		name = "WolfgangLetter",
		color = color,
		lighted = false,
	}

	return common.instance(ColorLetter, game.particles, params)
end

function ColorLetter:lightUp()
	if not self.lighted then
		self.lighted = true
		self:newImageFadeIn(self.owner.special_images[self.color].glow, 10)
		self.manager.dust.generateStarFountain{
			game = self.game,
			x = self.x,
			y = self.y,
			color = self.color,
		}
		self:change{duration = 25, scaling = 1.5, easing = "inBack"}
		self:change{duration = 25, scaling = 1, easing = "outBack"}
	end
end

function ColorLetter:darken()
	if self.lighted then
		self.lighted = false
		self:newImageFadeIn(self.owner.special_images[self.color].dark, 30)
		self.manager.dust.generateStarFountain{
			game = self.game,
			x = self.x,
			y = self.y,
			color = self.color,
		}
	end
end

ColorLetter = common.class("ColorLetter", ColorLetter, Pic)
-------------------------------------------------------------------------------
-- The appropriate words (BLUE! AMARILLO! etc) appear at the matched gem
local ColorWord = {}
function ColorWord:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	manager.allParticles.CharEffects[ID.particle] = self
	self.manager = manager
end

function ColorWord:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function ColorWord.generate(game, owner, x, y, color, delay)
	local params = {
		x = x,
		y = y,
		image = owner.special_images[color].word,
		owner = owner,
		player_num = owner.player_num,
		name = "WolfgangColorWord",
	}

	local p = common.instance(ColorWord, game.particles, params)
	p.rotation = (math.random() - 0.5) * 0.3
	if delay then
		p:change{transparency = 0}
		p:wait(delay)
		p:change{duration = 0, transparency = 255}
	end
	p:change{duration = 60, y = y - game.stage.height * 0.072, easing = "outCubic"}
	p:wait(30)
	p:change{duration = 45, transparency = 0, remove = true}
end

ColorWord = common.class("ColorWord", ColorWord, Pic)
-------------------------------------------------------------------------------
Wolfgang.fx = {
	colorLetter = ColorLetter,
	colorWord = ColorWord,
}

-------------------------------------------------------------------------------
-- turns a piece in the hand into a dog. 'both' to true to turn both.
-- creates a piece if no piece exists in the position

-- returns a dog image package in the form {dog, explode, grey, pop}
function Wolfgang:_getRandomDog()
	local i = math.random(#self.special_images.good_dog)
	local dog = self.special_images.good_dog[i]
	local explode = self.special_images.dog_explode[i]
	local grey = self.special_images.dog_grey[i]
	local pop = self.special_images.dog_pop[i]
	return {dog = dog, explode = explode, grey = grey, pop = pop}
end

-- returns a random dog in the form of a gem_replace_table
function Wolfgang:_getDogReplaceTable()
	local images = self:_getRandomDog()
	return {
		color = "wild",
		image = images.dog,
		exploding_gem_image = images.explode,
		grey_exploding_gem_image = images.grey,
		pop_particle_image = images.pop,
	}
end

-- Turns a grid gem into a friendly dog
-- Used during super
function Wolfgang:_turnGemToDog(gem)
	local images = self:_getRandomDog()
	gem:setColor("wild", images.dog, images.explode, images.grey, images.pop)
	gem:setOwner(self.player_num)
	gem:setMaxAlpha(true)
end

function Wolfgang:_turnRandomFriendlyBasinGemToDog()
	local game = self.game

	local start_col, end_col
	if self.player_num == 1 then
		start_col, end_col = 1, 4
	elseif self.player_num == 2 then
		start_col, end_col = 5, 8
	else
		error("Invalid player number")
	end

	local valid_gems = {}
	for gem, _, col in game.grid:basinGems() do
		if col >= start_col and col <= end_col and gem.color ~= "wild" then
			valid_gems[#valid_gems+1] = gem
		end
	end

	if #valid_gems > 0 then
		local rand = game.rng:random(#valid_gems)
		self:_turnGemToDog(valid_gems[rand])
	end
end

--[[
-- Turn a hand piece into a dog. Was previously used for Wolfgang super
-- Currently unused
function Wolfgang:_turnPieceToDog(hand_idx, both)
	assert(hand_idx >= 1 and hand_idx <= 5, "hand_idx not within range!")
	local hand_loc = self.hand[hand_idx]

	if hand_loc.piece then
		if both then
			for i = 1, hand_loc.piece.size do
				local images = self:_getRandomDog()
				hand_loc.piece.gems[i]:setColor(
					"wild", images.dog, images.explode, images.grey, images.pop
				)
			end
		else
			local images = self:_getRandomDog()
			local pos = self.game.rng:random(hand_loc.piece.size)
			-- If it is in rotation_index 2 or 3, the gem table was reversed
			-- This is because of bad coding from before. Haha
			if hand_loc.piece.size == 2 and (hand_loc.piece.rotation_index == 2 or
			hand_loc.piece.rotation_index == 3) then
				if pos == 2 then pos = 1 elseif pos == 1 then pos = 2 end
			end
			hand_loc.piece.gems[pos]:setColor(
				"wild", images.dog, images.explode, images.grey, images.pop
			)
		end
	else
		local gem_replace_table
		if both then
			gem_replace_table = {
				self:_getDogReplaceTable(),
				self:_getDogReplaceTable(),
			}
		else
			gem_replace_table = self:_getDogReplaceTable()
		end

		hand_loc.piece = Piece:create{
			game = self.game,
			hand_idx = hand_idx,
			owner = self,
			player_num = self.player_num,
			x = hand_loc.x,
			y = hand_loc.y,
			gem_replace_table = gem_replace_table,
		}
	end
	self:_assignBadDogImages()
end
--]]

-- Goes through hand dogs and writes the bad dog images. No hurry to do so,
-- since it won't matter until next action phase, so we do it in cleanup phase
function Wolfgang:_assignBadDogImages()
	for piece in self.hand:pieces() do
		for gem in piece:getGems() do
			if gem.color == "wild" and not gem.bad_dog_image then
				for i = 1, #self.special_images.good_dog do
					if gem.image == self.special_images.good_dog[i] then
						gem.good_dog_image = gem.image
						gem.bad_dog_image = self.special_images.bad_dog[i]
						piece.contains_dog = true
					end
				end
			end
		end
	end
end

-- undarken the screen after super
function Wolfgang:_brightenScreen()
	local game = self.game

	local start_col, end_col
	if self.player_num == 1 then
		start_col, end_col = 1, 4
	elseif self.player_num == 2 then
		start_col, end_col = 5, 8
	else
		error("Invalid player number")
	end

	for gem, _, col in game.grid:gems() do
		if col >= start_col and col <= end_col and gem.color == "wild" then
			gem:setMaxAlpha(false)
		end
	end

	game:brightenScreen(self.player_num)
end

-- countdown bad dogs and destroy if at zero
-- Only once per turn
function Wolfgang:_countdownBadDogs()
	for dog, counter in pairs(self.bad_dogs) do
		assert(counter > 0, "Wolfgang countdown went wrong somewhere")
		self.bad_dogs[dog] = counter - 1
	end
end

-- If any dogs were destroyed, force a new gravity phase
function Wolfgang:_upkeepBadDogs()
	local any_dogs_destroyed = false
	local delete_dogs = {}
	for dog, counter in pairs(self.bad_dogs) do
		if counter == 0 then
			dog.indestructible = false
			dog:allowFlagPropagation()
			self.game.grid:destroyGem{
				gem = dog,
				super_meter = false,
				damage = false,
				credit_to = self.player_num,
			}
			delete_dogs[#delete_dogs+1] = dog
		end
	end
	for _, dog in ipairs(delete_dogs) do
		self.bad_dogs[dog] = nil
		any_dogs_destroyed = true
	end
	print("any dogs destroyed?", any_dogs_destroyed)
	return any_dogs_destroyed
end

-- update a piece to bad dog if it is rushable
function Wolfgang:actionPhase()
	local piece = self.game.active_piece
	if piece and piece.contains_dog then
		local midline, on_left = piece:isOnMidline()
		local shift = 0
		if midline then
			if on_left then shift = -1 else shift = 1 end
		end
		local _, place_type = piece:isDropValid(shift)

		for gem in piece:getGems() do
			if gem.color == "wild" then
				if place_type == "rush" and gem.image == gem.good_dog_image then
					gem:newImage(gem.bad_dog_image)
				elseif place_type ~= "rush" and gem.image == gem.bad_dog_image then
					gem:newImage(gem.good_dog_image)
				end
			end
		end
	end
end

function Wolfgang:beforeGravity()
	local grid = self.game.grid
	local pending_gems = grid:getPendingGems(self.enemy)
	local delay = 0

	-- Change good dogs to bad dogs if they are in rush column
	for _, gem in ipairs(pending_gems) do
		if gem.owner == self.player_num and gem.color == "wild" then
			gem.indestructible = true
			gem.color = "none"
			gem.image = gem.bad_dog_image
			self.bad_dogs[gem] = self.BAD_DOG_DURATION
		end
	end

	-- Create super dogs
	if self.supering then
		for _ = 1, 4 do
			self:_turnRandomFriendlyBasinGemToDog()
			delay = self.SUPER_DOG_CREATION_DELAY
			self.gain_super_meter = false
		end
	end

	return delay
end

function Wolfgang:beforeTween()
	self.supering = false
	self:_brightenScreen()
end

function Wolfgang:beforeMatch()
	local game = self.game
	local grid = game.grid
	local delay = 0

	-- See which color matches we made, for BARK lighting up
	-- Also find the position of the colorwords here
	local create_words = {
		red = nil,
		blue = nil,
		green = nil,
		yellow = nil,
	}

	local match_lists = grid:getMatchedGemLists()

	-- if both horizontal and vertical matches exist for a color, ignore verticals
	-- otherwise, choose a display location arbitrarily
	for _, list in ipairs(match_lists) do
		-- check that this match is ours
		local owned_by_me = false
		for _, gem in ipairs(list) do
			if gem.owner == self.player_num then owned_by_me = true end
		end

		if owned_by_me then
			local is_vertical = true
			local color
			local total_x, total_y = 0, 0 -- for calculating average
			for _, gem in ipairs(list) do
				if gem.column ~= list[1].column then is_vertical = false end
				if gem.color == "red" or gem.color == "blue" or gem.color == "green" or gem.color == "yellow" then
					color = gem.color
				end
				total_x = total_x + gem.x
				total_y = total_y + gem.y
			end
			local mid_x = total_x / #list
			local mid_y = total_y / #list

			-- don't do anything if it's already lighted up
			-- also handle rare case of no color if we have a 3 wild gems match
			if not color then
				for _, c in ipairs{"red", "blue", "green", "yellow"} do
					if not self.letters[c].lighted then
						self.this_turn_matched_colors[c] = true
					end
				end
			elseif not self.letters[color].lighted then
				local overwrite = true
				if is_vertical and create_words[color] and (not create_words[color].is_vertical) then
					overwrite = false
				end
				if overwrite then
					create_words[color] = {x = mid_x, y = mid_y, is_vertical = is_vertical}
					self.this_turn_matched_colors[color] = true
				end
			end
		end
	end

	-- create the colorwords
	for color, pos in pairs(create_words) do
		self.fx.colorWord.generate(self.game, self, pos.x, pos.y, color, self.game.GEM_EXPLODE_FRAMES)
	end

	return delay
end

-- Light up the BARK meter for any matches
function Wolfgang:afterMatch()
	local delay = 0
	for color in pairs(self.this_turn_matched_colors) do
		self.letters[color]:lightUp()
		delay = 45
	end
	return delay
end

-- Queue the dog if all BARK was lit up
-- Also update bad dogs
function Wolfgang:afterAllMatches()
	local delay = 0
	local all_lit_up = true
	for _, letter in pairs(self.letters) do
		if not letter.lighted then all_lit_up = false end
	end

	if all_lit_up then
		-- TODO: animation to show we're making a dog
		self.single_dogs_to_make = self.single_dogs_to_make + self.FULL_BARK_DOG_ADDS
		for _, letter in pairs(self.letters) do letter:darken() end
		delay = 60
	end

	-- if any bad dogs were destroyed, go to gravity phase again
	local force_gravity_phase = self:_upkeepBadDogs()
	if force_gravity_phase then print("going to gravity phase") end
	return delay, force_gravity_phase
end

-- Make a bark dog if there are any dogs queued
function Wolfgang:modifyGemTable()
	if self.double_dogs_to_make > 0 then
		local dog_return = function()
			self.double_dogs_to_make = self.double_dogs_to_make - 1
			return {self:_getDogReplaceTable(),	self:_getDogReplaceTable()}
		end
		return nil, dog_return
	elseif self.single_dogs_to_make > 0 then
		local dog_return = function()
			self.single_dogs_to_make = self.single_dogs_to_make - 1
			return self:_getDogReplaceTable()
		end
		return nil, dog_return
	end
end

function Wolfgang:cleanup()
	self:_assignBadDogImages()
	self:_countdownBadDogs()
	self.this_turn_matched_colors = {}
	self.need_to_countdown_bad_dogs = true
	self.gain_super_meter = nil
	Character.cleanup(self)
end

function Wolfgang:serializeSpecials()
	local ret = ""
	return ret
end

function Wolfgang:deserializeSpecials(str)
end

return common.class("Wolfgang", Wolfgang, Character)
