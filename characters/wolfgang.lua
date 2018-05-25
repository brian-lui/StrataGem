--[[ Color: blue
Passive: Wolfgang has a BARK meter. Every time you make a match of a certain
color, the BARK meter gains a letter. (Blue, Amarillo, Red, Kreen). When the
Bark meter is filled, your next gem cluster you gain will contain a Dog piece.
Dogs placed in your basin are good dogs. Good dogs are wild and last until
matched. Basins placed in the opponent's basin (rush) are bad dogs. Bad dogs
do not listen and do nothing. They last for 3 turns and then go home.

Passive animation:
When the BARK meter is lit entirely, a good dog piece (Random) appears in the
next set of gems on the stars when it moves again.

When you drag a piece to the opponent's side (rush), the good dog should change
to a bad dog as soon as you hover to the other side, and return to good dog if
you bring the piece back.

Super: The bottom most platform in your hand gains a double Dog (or becomes a
double dog), and the 4th platform gains a single dog + [gem] (or becomes a
single dog + [gem].
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
Wolfgang.meter_gain = {red = 4, blue = 8, green = 4, yellow = 4}

Wolfgang.super_images = {
	word = image.UI.super.blue_word,
	empty = image.UI.super.blue_empty,
	full = image.UI.super.blue_full,
	glow = image.UI.super.blue_glow,
	overlay = love.graphics.newImage('images/characters/wolfgang/wolfganglogo.png'),
}
Wolfgang.burst_images = {
	partial = image.UI.burst.blue_partial,
	full = image.UI.burst.blue_full,
	glow = {image.UI.burst.blue_glow1, image.UI.burst.blue_glow2}
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
	local y = stage.height * 0.57
	local add = self.player_num == 2 and stage.width * 0.77 or 0
	local x = {
		stage.width * 0.055 + add,
		stage.width * 0.095 + add,
		stage.width * 0.135 + add,
		stage.width * 0.175 + add,
	}

	self.letters = {
		blue = self.fx.colorLetter.generate(game, self, x[1], y, "blue"),
		yellow = self.fx.colorLetter.generate(game, self, x[2], y, "yellow"),
		red = self.fx.colorLetter.generate(game, self, x[3], y, "red"),
		green = self.fx.colorLetter.generate(game, self, x[4], y, "green"),
	}

	self.this_turn_matched_colors = {}
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
function Wolfgang:_turnToDog(hand_idx, both)
	assert(hand_idx >= 1 and hand_idx <= 5, "hand_idx not within range!")
	local hand_loc = self.hand[hand_idx]

	if hand_loc.piece then
		if both then
			for i = 1, hand_loc.piece.size do
				local dog_images = self.special_images.good_dog
				local dog = dog_images[math.random(#dog_images)]
				hand_loc.piece.gems[i]:setColor("wild", dog)
			end
		else
			local dog_images = self.special_images.good_dog
			local dog = dog_images[math.random(#dog_images)]
			local pos = self.game.rng:random(hand_loc.piece.size)
			-- If it is in rotation_index 2 or 3, the gem table was reversed
			-- This is because of bad coding from before. Haha
			if hand_loc.piece.size == 2 and (hand_loc.piece.rotation_index == 2 or
			hand_loc.piece.rotation_index == 3) then
				if pos == 2 then pos = 1 elseif pos == 1 then pos = 2 end
			end
			hand_loc.piece.gems[pos]:setColor("wild", dog)
		end
	else
		local gem_replace_table
		if both then
			local dog_images = self.special_images.good_dog
			local dog1 = dog_images[math.random(#dog_images)]
			local dog2 = dog_images[math.random(#dog_images)]
			gem_replace_table = {
				{color = "wild", image = dog1},
				{color = "wild", image = dog2},
			}
		else
			local dog_images = self.special_images.good_dog
			local dog = dog_images[math.random(#dog_images)]
			gem_replace_table = {color = "wild", image = dog}
		end

		hand_loc.piece = Piece:create{
			game = self.game,
			hand_idx = hand_idx,
			owner = self,
			owner_num = self.player_num,
			x = hand_loc.x,
			y = hand_loc.y,
			gem_replace_table = gem_replace_table,
		}
	end
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
			local row = list[1].row
			local total_x, total_y = 0, 0 -- for calculating average
			for _, gem in ipairs(list) do
				if gem.column ~= column then is_vertical = false end
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
			if (not self.letters[color].lighted) and color then
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
function Wolfgang:afterAllMatches()
	local delay = 0
	local all_lit_up = true
	for _, letter in pairs(self.letters) do
		if not letter.lighted then all_lit_up = false end
	end

	if all_lit_up then
		-- TODO: animation to show we're making a dog
		self.single_dogs_to_make = self.single_dogs_to_make + 1
		for _, letter in pairs(self.letters) do letter:darken() end
		delay = 60
	end

	return delay
end

-- Make a bark dog if there are any dogs queued
function Wolfgang:modifyGemTable()
	if self.double_dogs_to_make > 0 then
		local dog_return = function()
			self.double_dogs_to_make = self.double_dogs_to_make - 1
			local dog_images = self.special_images.good_dog
			local dog1 = dog_images[math.random(#dog_images)]
			local dog2 = dog_images[math.random(#dog_images)]
			return {
				{color = "wild", image = dog1},
				{color = "wild", image = dog2},
			}
		end
		return nil, dog_return
	elseif self.single_dogs_to_make > 0 then
		local dog_return = function()
			self.single_dogs_to_make = self.single_dogs_to_make - 1
			local dog_images = self.special_images.good_dog
			local dog = dog_images[math.random(#dog_images)]
			return {color = "wild", image = dog}
		end
		return nil, dog_return
	end
end

function Wolfgang:cleanup()
	self.this_turn_matched_colors = {}
	Character.cleanup(self)
end

function Wolfgang:serializeSpecials()
	local ret = ""
	return ret
end

function Wolfgang:deserializeSpecials(str)
end

return common.class("Wolfgang", Wolfgang, Character)
