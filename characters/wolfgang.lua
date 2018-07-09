--[[ Color: red
Passive: Wolfgang has a BARK meter. Every time you make a match of a certain
color, the BARK meter gains a letter. (Blue, Amarillo, Red, Kreen). When the
Bark meter is filled, your next gem cluster you gain will contain a Dog piece.
Dogs placed in your basin are good dogs. Good dogs are wild and last until
matched. Basins placed in the opponent's basin (rush) are bad dogs. Bad dogs
do not listen and do nothing. They last for 3 turns and then go home.

Super: You gain four dog-icons. Once per turn, a dog-icon replaces a gem in
your basin with a dog. The dog will create a match if possible, out of all
possible matches. Otherwise, it will replace a random gem.
--]]

local love = _G.love
local common = require "class.commons"
local Character = require "character"
local images = require "images"
local Pic = require "pic"
local deepcpy = require "/helpers/utilities".deepcpy

local Wolfgang = {}

Wolfgang.large_image = love.graphics.newImage('images/portraits/wolfgang.png')
Wolfgang.small_image = love.graphics.newImage('images/portraits/wolfgangsmall.png')
Wolfgang.action_image = love.graphics.newImage('images/portraits/action_wolfgang.png')
Wolfgang.shadow_image = love.graphics.newImage('images/portraits/shadow_wolfgang.png')
Wolfgang.super_fuzz_image = love.graphics.newImage('images/ui/superfuzzred.png')

Wolfgang.character_id = "Wolfgang"
Wolfgang.meter_gain = {
	red = 8,
	blue = 4,
	green = 4,
	yellow = 4,
	none = 4,
	wild = 4,
}

Wolfgang.super_images = {
	word = images.ui_super_text_red,
	empty = images.ui_super_empty_red,
	full = images.ui_super_full_red,
	glow = images.ui_super_glow_red,
	overlay = love.graphics.newImage('images/characters/wolfgang/wolfganglogo.png'),
}
Wolfgang.burst_images = {
	partial = images.ui_burst_part_red,
	full = images.ui_burst_full_red,
	glow = {images.ui_burst_partglow_red, images.ui_burst_fullglow_red}
}

Wolfgang.special_images = {
	good_dog = {
		love.graphics.newImage('images/characters/wolfgang/goodblacklab.png'),
		love.graphics.newImage('images/characters/wolfgang/goodgoldenlab.png'),
		love.graphics.newImage('images/characters/wolfgang/goodrussel.png'),
	},
	good_dog_colored = {
		love.graphics.newImage('images/characters/wolfgang/goodb.png'),
		love.graphics.newImage('images/characters/wolfgang/gooda.png'),
		love.graphics.newImage('images/characters/wolfgang/goodr.png'),
		love.graphics.newImage('images/characters/wolfgang/goodk.png'),
	},
	bad_dog = {
		love.graphics.newImage('images/characters/wolfgang/badblacklab.png'),
		love.graphics.newImage('images/characters/wolfgang/badgoldenlab.png'),
		love.graphics.newImage('images/characters/wolfgang/badrussel.png'),
	},
	bad_dog_mad = love.graphics.newImage('images/characters/wolfgang/badmad.png'),
	dog_explode = {
		love.graphics.newImage('images/characters/wolfgang/blacklabexplode.png'),
		love.graphics.newImage('images/characters/wolfgang/goldenlabexplode.png'),
		love.graphics.newImage('images/characters/wolfgang/russelexplode.png'),
	},
	dog_grey = love.graphics.newImage('images/characters/wolfgang/greydog.png'),
	dog_pop = love.graphics.newImage('images/characters/wolfgang/dogpop.png'),
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
	self.BARK_X = {
		stage.width * 0.055 + add,
		stage.width * 0.095 + add,
		stage.width * 0.135 + add,
		stage.width * 0.175 + add,
	}
	self.BARK_Y = stage.height * 0.57

	local super_x = stage.super[self.player_num].x
	local super_y = stage.super[self.player_num].y
	self.SUPER_DOG_LOCS = {
		{x = super_x - stage.width * 0.07, y = super_y + stage.width * 0.02},
		{x = super_x - stage.width * 0.07, y = super_y - stage.width * 0.02},
		{x = super_x + stage.width * 0.07, y = super_y + stage.width * 0.02},
		{x = super_x + stage.width * 0.07, y = super_y - stage.width * 0.02},
		{x = -stage.width, y = stage.height * 2}, -- don't show 5th+ icons
	}

	self.letters = {
		blue = self.fx.colorLetter.create(
			game,
			self,
			self.BARK_X[1],
			self.BARK_Y,
			"blue"
		),
		yellow = self.fx.colorLetter.create(
			game,
			self,
			self.BARK_X[2],
			self.BARK_Y,
			"yellow"
		),
		red = self.fx.colorLetter.create(
			game,
			self,
			self.BARK_X[3],
			self.BARK_Y,
			"red"
		),
		green = self.fx.colorLetter.create(
			game,
			self,
			self.BARK_X[4],
			self.BARK_Y,
			"green"
		),
	}
	self.FULL_BARK_DOG_ADDS = 2
	self.BAD_DOG_DURATION = 3
	self.GEM_TO_DOG_ANIM_TIME = 30
	self.SUPER_DOG_CREATION_DELAY = 45 -- in frames
	self.GOOD_DOG_CYCLE = 135 -- calling a good dog animation cycle
	self.BAD_DOG_CYCLE = 30 -- calling a bad dog animation cycle
	self.good_dog_frames, self.bad_dog_frames = 0, 0
	self.this_turn_matched_colors = {}
	self.good_dogs = {} -- set of {dog-gems = true}
	self.good_dog_color_index = 1 -- current good dog color switch
	self.good_dog_color_image = self.special_images.good_dog_colored[self.good_dog_color_index]
	self.bad_dogs = {} -- dict of {dog-gem = turns remaining to disappearance}
	self.bad_dog_counter = 1 -- cycles from 1 to self.BAD_DOG_DURATION
	self.bad_dog_mad_image = self.special_images.bad_dog_mad
	self.single_dogs_to_make = 0
	self.super_dogs_to_make = 0
	self.need_to_activate_super_dog = true
	self.super_dog_icons = {}
end
-------------------------------------------------------------------------------
-- These are the BARK letter classes
local ColorLetter = {}
function ColorLetter:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
	self.game = manager.game
end

function ColorLetter:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

-- BARK meter appears below the super meter.
function ColorLetter.create(game, owner, x, y, color)
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
		self:change{duration = 25, scaling = 0.7, easing = "inBack"}
		self:change{duration = 25, scaling = 1, easing = "outBack"}
	end
end

ColorLetter = common.class("ColorLetter", ColorLetter, Pic)
-------------------------------------------------------------------------------
-- The appropriate words (BLUE! AMARILLO! etc) appear at the matched gem
local ColorWord = {}
function ColorWord:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
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
		p:change{duration = 0, transparency = 1}
	end
	p:change{
		duration = 60,
		y = y - game.stage.height * 0.072,
		easing = "outCubic",
	}
	p:wait(30)
	p:change{duration = 45, transparency = 0, remove = true}
end

ColorWord = common.class("ColorWord", ColorWord, Pic)
-------------------------------------------------------------------------------
-- The pending super-dog icons
local SuperDog = {}
function SuperDog:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
end

function SuperDog:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function SuperDog.create(game, owner, delay)
	local i = math.min(owner.super_dogs_to_make, 5)
	local x, y = owner.SUPER_DOG_LOCS[i].x, owner.SUPER_DOG_LOCS[i].y
	local rand = math.random(#owner.special_images.good_dog)
	local image = owner.special_images.good_dog[rand]

	local params = {
		x = x,
		y = y,
		image = image,
		owner = owner,
		index = i,
		player_num = owner.player_num,
		name = "WolfgangSuperDogIcon",
	}

	local dog = common.instance(SuperDog, game.particles, params)
	dog.scaling = 0.75
	if delay then
		dog:change{transparency = 0}
		dog:wait(delay)
		dog:change{duration = 0, transparency = 1}
	end

	-- pop background
	local pop_params = {
		x = x,
		y = y,
		image = owner.special_images.dog_pop,
		draw_order = -1,
		owner = owner,
		player_num = owner.player_num,
		name = "SuperDogPop",
	}
	local pop = common.instance(SuperDog, game.particles, pop_params)
	pop.scaling = 0.75
	if delay then
		pop:change{transparency = 0}
		pop:wait(delay)
		pop:change{duration = 0, transparency = 1}
	end
	pop:change{duration = 30, transparency = 0, scaling = 3, remove = true}

	-- star fountain
	game.particles.dust.generateStarFountain{
		game = game,
		x = x,
		y = y,
		color = "wild",
		delay = delay,
	}

	return dog
end

function SuperDog:moveToGrid(gem, delay)
	local game = self.game
	local owner = self.owner
	local INIT_EXPLODE_TIME = 20 -- initial explosion duration
	local TRAVEL_TIME = 90 -- origin explosion to destination animation
	delay = delay or 0

	-- move 5th+ dogs back to 4th spot
	local start_x, start_y = self.x, self.y
	if self.index == 5 then
		start_x, start_y = owner.SUPER_DOG_LOCS[4].x, owner.SUPER_DOG_LOCS[4].y
	end

	-- pop background at origin
	local pop_params = {
		x = start_x,
		y = start_y,
		image = owner.special_images.dog_pop,
		draw_order = -1,
		owner = owner,
		player_num = owner.player_num,
		name = "SuperDogPop",
	}
	local pop = common.instance(SuperDog, game.particles, pop_params)
	pop.scaling = 0.75
	if delay then
		pop:change{transparency = 0}
		pop:wait(delay)
		pop:change{duration = 0, transparency = 1}
	end
	pop:change{duration = 30, transparency = 0, scaling = 3, remove = true}

	-- move the dog to the destination, and replace image when there
	local x1, y1 = start_x, start_y -- start
	local x2, y2 = gem.x, start_y - (gem.y - start_y)  
	local x3, y3 = gem.x, gem.y -- end
	local curve = love.math.newBezierCurve(x1, y1, x2, y2, x3, y3)
	self:wait(INIT_EXPLODE_TIME + delay)
	self:change{
		duration = TRAVEL_TIME,
		curve = curve,
		scaling = 1,
		remove = true,
		exit_func = function() owner:_turnGemToGoodDog(gem) end,
	}

	-- garbage circle particles at destination
	for i = 0, 1 do
		game.particles.dust.generateGarbageCircle{
			game = game,
			x = gem.x,
			y = gem.y,
			delay_frames = i * 8 + delay + INIT_EXPLODE_TIME + TRAVEL_TIME,
			color = "wild",
		}
	end

	-- reverse pop at destination
	local reverse_pop = {
		x = gem.x,
		y = gem.y,
		image = owner.special_images.dog_pop,
		draw_order = -1,
		owner = owner,
		player_num = owner.player_num,
		name = "SuperDogReversePop",
	}
	local rev_pop = common.instance(SuperDog, game.particles, reverse_pop)
	rev_pop:change{transparency = 0, scaling = 4}
	rev_pop:wait(delay + INIT_EXPLODE_TIME + TRAVEL_TIME)
	rev_pop:change{
		duration = 30,
		transparency = 1,
		scaling = 1,
		remove = true,
	}

	-- reverse explode at destination
	local rev_explode_time = game.particles.explodingGem.generateReverseExplode{
		game = game,
		x = gem.x,
		y = gem.y,
		image = self.image,
		delay_frames = delay + INIT_EXPLODE_TIME + TRAVEL_TIME,
	}

	local total_delay = delay + INIT_EXPLODE_TIME + TRAVEL_TIME + rev_explode_time

	-- fountain at destination
	game.particles.dust.generateBigFountain{
		game = game,
		x = gem.x,
		y = gem.y,
		color = "wild",
		delay_frames = total_delay,
	}

	gem:setOwner(self.player_num)
	return total_delay
end

SuperDog = common.class("SuperDog", SuperDog, Pic)

-------------------------------------------------------------------------------
Wolfgang.fx = {
	colorLetter = ColorLetter,
	colorWord = ColorWord,
	superDog = SuperDog,
}

-------------------------------------------------------------------------------
-- turns a piece in the hand into a dog. 'both' to true to turn both.
-- creates a piece if no piece exists in the position

-- returns a dog image package in the form {dog, explode, grey, pop}
function Wolfgang:_getRandomDog()
	local i = math.random(#self.special_images.good_dog)
	local dog = self.special_images.good_dog[i]
	local explode = self.special_images.dog_explode[i]
	local grey = self.special_images.dog_grey
	local pop = self.special_images.dog_pop
	return {dog = dog, explode = explode, grey = grey, pop = pop}
end

-- returns a random dog in the form of a gem_replace_table
function Wolfgang:_getDogReplaceTable()
	local image = self:_getRandomDog()
	return {
		color = "wild",
		image = image.dog,
		exploding_gem_image = image.explode,
		grey_exploding_gem_image = image.grey,
		pop_particle_image = image.pop,
	}
end

-- Turns a grid gem into a friendly dog
-- Used during super
function Wolfgang:_turnGemToDog(gem, delay)
	local image = self:_getRandomDog()
	gem:setColor(
		"wild",
		image.dog,
		image.explode,
		image.grey,
		image.pop,
		delay,
		self.GEM_TO_DOG_ANIM_TIME
	)
	gem:setOwner(self.player_num)
	gem:setMaxAlpha(true)
	self.good_dogs[gem] = true
end

-- same but for good dog in deserialization
function Wolfgang:_turnGemToGoodDog(gem, delay)
	local image = self:_getRandomDog()
	gem:setColor(
		"wild",
		image.dog,
		image.explode,
		image.grey,
		image.pop,
		delay,
		self.GEM_TO_DOG_ANIM_TIME
	)

	local function stateChanges() self.good_dogs[gem] = true end

	if delay then
		self.game.queue:add(delay, stateChanges)
	else
		stateChanges()
	end
end

-- same but for bad dog, used in deserialization
function Wolfgang:_turnGemToBadDog(gem, turns_remaining, delay)
	local image = self:_getRandomDog()
	gem:setColor("wild",
		image.dog,
		image.explode,
		image.grey,
		image.pop,
		delay,
		self.GEM_TO_DOG_ANIM_TIME
	)

	local function stateChanges()
		for i = 1, #self.special_images.good_dog do
			if gem.image == self.special_images.good_dog[i] then
				gem.bad_dog_image = self.special_images.bad_dog[i]
			end
		end

		gem.good_dog_image = gem.image
		gem.image = gem.bad_dog_image
		gem.indestructible = true
		gem.color = "none"
		self.bad_dogs[gem] = turns_remaining
	end

	if delay then
		self.game.queue:add(delay, stateChanges)
	else
		stateChanges()
	end
end

-- same but for a dog in the hand, used in deserialization
function Wolfgang:_turnHandGemToDog(gem, delay)
	local image = self:_getRandomDog()
	gem:setColor(
		"wild",
		image.dog,
		image.explode,
		image.grey,
		image.pop,
		delay,
		self.GEM_TO_DOG_ANIM_TIME
	)

	local function stateChanges() self.good_dogs[gem] = true end

	if delay then
		self.game.queue:add(delay, stateChanges)
	else
		stateChanges()
	end
end

-- check all gems in grid for which would create a match, then
-- choose randomly. Returns the gem to replace
function Wolfgang:_getSuperArrivalLocation()
	local game = self.game
	local grid = game.grid
	local possible_gems = {}

	-- check possible matches
	local _, original_matched_gems = grid:getMatchedGems()
	for gem, r, c in grid:basinGems(self.player_num) do
		if gem.color ~= "wild" and gem.color ~= "none" then
			local grid_clone = deepcpy(grid)
			grid_clone[r][c].gem.color = "wild"
			local _, new_matched_gems = grid_clone:getMatchedGems()
			if new_matched_gems > original_matched_gems then
				possible_gems[#possible_gems + 1] = gem
			end
		end
	end

	-- if no possible matches
	if #possible_gems == 0 then
		for gem in grid:basinGems(self.player_num) do
			if gem.color ~= "wild" and gem.color ~= "none" then
				possible_gems[#possible_gems + 1] = gem
			end
		end
	end

	-- get a random dog
	local ret
	if #possible_gems > 0 then
		local rand = game.rng:random(#possible_gems)
		ret = possible_gems[rand]
	end

	return ret
end


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
			dog:setOwner(self.player_num)
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
	return any_dogs_destroyed
end

-- change the colors of the good dog
-- called every X seconds. queues a swap to the next color, then swap back
function Wolfgang:_goodDogAnimation(dog)
	if dog:isStationary() then
		local current_image = dog.image
		local duration = self.GOOD_DOG_CYCLE / 6
		dog:newImageFadeIn(self.good_dog_color_image, duration)
		dog:newImageFadeIn(current_image, duration, duration * 2)
	end
end

-- change the colors of the bad dog
function Wolfgang:_badDogAnimation(dog, turns_remaining)
	if dog:isStationary() then
		local current_image = dog.image
		local duration = self.BAD_DOG_CYCLE * turns_remaining / 6
		dog:newImageFadeIn(self.bad_dog_mad_image, duration)
		dog:newImageFadeIn(current_image, duration, duration)
	end
end

-------------------------------------------------------------------------------
-- update the grid good dog and bad dog animations
function Wolfgang:update(dt)
	local good_dog_anim, bad_dog_anim = false, false
	if self.good_dog_frames >= self.GOOD_DOG_CYCLE then
		self.good_dog_frames = self.good_dog_frames - self.GOOD_DOG_CYCLE
		self.good_dog_color_index = self.good_dog_color_index % #self.special_images.good_dog_colored + 1
		self.good_dog_color_image = self.special_images.good_dog_colored[self.good_dog_color_index]
		good_dog_anim = true
	else
		self.good_dog_frames = self.good_dog_frames + 1
	end

	if self.bad_dog_frames >= self.BAD_DOG_CYCLE then
		self.bad_dog_frames = self.bad_dog_frames - self.BAD_DOG_CYCLE
		self.bad_dog_counter = self.bad_dog_counter % self.BAD_DOG_DURATION + 1
		bad_dog_anim = true
	else
		self.bad_dog_frames = self.bad_dog_frames + 1
	end

	for dog in pairs(self.good_dogs) do
		if dog.is_destroyed then
			self.good_dogs[dog] = nil
		else
			if good_dog_anim then self:_goodDogAnimation(dog) end
		end
		if dog:isStationary() then dog:update(dt) end
	end

	for dog, turns_remaining in pairs(self.bad_dogs) do
		local actual_turns_remaining = math.min(turns_remaining + 1, 3) -- lol
		if bad_dog_anim and self.bad_dog_counter % actual_turns_remaining == 0 then
			self:_badDogAnimation(dog, actual_turns_remaining)
		end
		if dog:isStationary() then dog:update(dt) end
	end
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
					self.good_dogs[gem] = nil
					self.bad_dogs[gem] = self.BAD_DOG_DURATION
				elseif place_type ~= "rush" and gem.image == gem.bad_dog_image then
					gem:newImage(gem.good_dog_image)
					self.good_dogs[gem] = true
					self.bad_dogs[gem] = nil
				end
			end
		end
	end
end

function Wolfgang:beforeGravity()
	local grid = self.game.grid
	local pending_rush_gems = grid:getPendingGems(self.enemy.player_num)
	local pending_my_gems = grid:getPendingGems(self.player_num)
	local delay = 0

	-- Change good dogs to bad dogs if they are in rush column
	for _, gem in ipairs(pending_rush_gems) do
		if gem.player_num == self.player_num and gem.color == "wild" then
			gem.indestructible = true
			gem.color = "none"
			gem.image = gem.bad_dog_image
			self.bad_dogs[gem] = self.BAD_DOG_DURATION
			self.good_dogs[gem] = nil
		end
	end

	-- Add good dogs to table too
	for _, gem in ipairs(pending_my_gems) do
		if gem.player_num == self.player_num and gem.color == "wild" then
			self.bad_dogs[gem] = nil
			self.good_dogs[gem] = true
		end
	end

	-- Create super dogs
	if self.is_supering then
		for i = 1, 4 do
			self.super_dogs_to_make = self.super_dogs_to_make + 1
			local new_dog = self.fx.superDog.create(self.game, self, (i-1) * 15)
			new_dog.force_max_alpha = true
			self.super_dog_icons[self.super_dogs_to_make] = new_dog
			delay = math.max(delay, i * 15)
		end

		self:emptyMP()
		self.is_supering = false
	end

	return delay
end

function Wolfgang:beforeTween()
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
			if gem.player_num == self.player_num then owned_by_me = true end
		end

		if owned_by_me then
			local is_vertical = true
			local color
			local total_x, total_y = 0, 0 -- for calculating average
			for _, gem in ipairs(list) do
				if gem.column ~= list[1].column then is_vertical = false end

				if gem.color == "red"
				or gem.color == "blue"
				or gem.color == "green"
				or gem.color == "yellow" then
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
				if is_vertical
				and create_words[color]
				and (not create_words[color].is_vertical) then
					overwrite = false
				end
				if overwrite then
					create_words[color] = {
						x = mid_x,
						y = mid_y,
						is_vertical = is_vertical,
					}
					self.this_turn_matched_colors[color] = true
				end
			end
		end
	end

	-- create the colorwords
	for color, pos in pairs(create_words) do
		self.fx.colorWord.generate(
			self.game,
			self,
			pos.x,
			pos.y,
			color,
			self.game.GEM_EXPLODE_FRAMES
		)
	end

	return delay
end

-- Light up the BARK meter for any matches
function Wolfgang:afterMatch()
	local delay = 0
	for color in pairs(self.this_turn_matched_colors) do
		self.letters[color]:lightUp()
		delay = 30
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
		self.single_dogs_to_make = self.single_dogs_to_make + self.FULL_BARK_DOG_ADDS
		for _, letter in pairs(self.letters) do letter:darken() end
		delay = 30
	end

	-- if any bad dogs were destroyed, go to gravity phase again
	local force_gravity_phase = self:_upkeepBadDogs()

	-- Move a superdog to grid
	if self.super_dogs_to_make > 0 and self.need_to_activate_super_dog then
		local arrival_gem = self:_getSuperArrivalLocation()
		if arrival_gem then
			local moving_dog = self.super_dog_icons[self.super_dogs_to_make]
			local super_dog_delay = moving_dog:moveToGrid(arrival_gem, delay)
			delay = math.max(delay, super_dog_delay)
			self.super_dogs_to_make = self.super_dogs_to_make - 1
			force_gravity_phase = true
			self.need_to_activate_super_dog = false
			self.can_gain_super = false
		end
	else
		self.can_gain_super = true -- in case of garbage matches
	end

	return delay, force_gravity_phase
end

-- Make a bark dog if there are any dogs queued
function Wolfgang:customGemTable()
	if self.single_dogs_to_make > 0 then
		local dog_return = function()
			self.single_dogs_to_make = self.single_dogs_to_make - 1
			return self:_getDogReplaceTable()
		end
		return nil, dog_return
	end
end

-- put the hand piece dogs into the good dog list too
function Wolfgang:beforeCleanup()
	for gem in self.hand:gems() do
		if gem.color == "wild" then self.good_dogs[gem] = true end
	end
end

function Wolfgang:cleanup()
	self:_assignBadDogImages()
	self:_countdownBadDogs()
	self.this_turn_matched_colors = {}
	self.need_to_activate_super_dog = true
	self.can_gain_super = true
	Character.cleanup(self)
end

--[[
	Serial is:
	bark lighting as BARK (Y for on, N for off) ,
	good dogs in hand, as [hand_idx, gem #] ,
	good dogs in basin, as [row, col] ,
	bad dogs in basin, as [row, col, turns remaining] ,
	single_dogs_to_make, as integer
--]]
function Wolfgang:serializeSpecials()
	local ret = {}

	-- bark lighting
	ret[#ret+1] = self.letters.blue.lighted and "Y" or "N"
	ret[#ret+1] = self.letters.yellow.lighted and "Y" or "N"
	ret[#ret+1] = self.letters.red.lighted and "Y" or "N"
	ret[#ret+1] = self.letters.green.lighted and "Y" or "N"
	ret[#ret+1] = ","

	-- dogs in hand
	for piece in self.hand:pieces() do
		for gem, location in piece:getGems() do
			if self.good_dogs[gem] then
				if piece.size == 1 then
					ret[#ret+1] = piece.hand_idx .. 1
				elseif piece.size == 2 then
					-- If it is in rotation_index 2 or 3, the gem table was reversed
					-- This is because of bad coding from before. Haha
					if piece.rotation_index == 2 or piece.rotation_index == 3 then
						if location == 1 then
							ret[#ret+1] = piece.hand_idx .. 2
						elseif location == 2 then
							ret[#ret+1] = piece.hand_idx .. 1
						else
							error("Invalid location provided for Wolfgang")
						end
					else
						ret[#ret+1] = piece.hand_idx .. location
					end
				else
					error("Piece size is not 1 or 2")
				end
			end
		end
	end
	ret[#ret+1] = ","

	-- good dogs in basin
	for gem, row, col in self.game.grid:gems() do
		if self.good_dogs[gem] then
			-- leftpad it so rows are always 2 digits
			if row <= 9 then
				ret[#ret+1] = "0" .. row .. col
			else
				ret[#ret+1] = row .. col
			end
		end
	end
	ret[#ret+1] = ","

	-- bad dogs in basin
	for gem, row, col in self.game.grid:gems() do
		if self.bad_dogs[gem] then
			if row <= 9 then
				ret[#ret+1] = "0" .. row .. col .. self.bad_dogs[gem]
			else
				ret[#ret+1] = row .. col .. self.bad_dogs[gem]
			end
		end
	end
	ret[#ret+1] = ","

	-- pending single dogs to make
	ret[#ret+1] = self.single_dogs_to_make
	ret[#ret+1] = ","

	-- pending super dogs to make
	ret[#ret+1] = self.super_dogs_to_make
	ret[#ret+1] = ","

	return table.concat(ret)
end

function Wolfgang:deserializeSpecials(str)
	local game = self.game
	local grid = game.grid

	local specials = {}
	for s in (str..","):gmatch("(.-),") do table.insert(specials, s) end

	local lighting = specials[1]
	local hand_dogs = specials[2]
	local good_dogs = specials[3]
	local bad_dogs = specials[4]
	local upcoming_single_dogs = specials[5]
	local upcoming_super_dogs = specials[6]

	-- lighting
	local letters = {
		blue = lighting:sub(1, 1),
		yellow = lighting:sub(2, 2),
		red = lighting:sub(3, 3),
		green = lighting:sub(4, 4),
	}

	for color, bool in pairs(letters) do
		assert(bool == "Y" or bool == "N", "Invalid colorletter specified")
		if bool == "Y" then
			self.letters[color]:lightUp()
		else
			self.letters[color]:darken()
		end
	end

	-- clear
	self.good_dogs = {}
	self.bad_dogs = {}

	-- hand dogs
	assert(#hand_dogs % 2 == 0, "Incorrect length of hand dogs")
	for i = 1, #hand_dogs, 2 do
		local hand_idx = tonumber(hand_dogs:sub(i, i))
		local location = tonumber(hand_dogs:sub(i + 1, i + 1))
		local piece = self.hand[hand_idx].piece
		assert(piece, "No piece found for hand dog")
		local gem = piece.gems[location]
		assert(gem, "No gem found for hand dog piece)")
		self:_turnHandGemToDog(gem)
	end

	-- grid good dogs
	assert(#good_dogs % 3 == 0, "Incorrect length of good dogs")
	for i = 1, #good_dogs, 3 do
		local row = tonumber(good_dogs:sub(i, i + 1))
		local column = tonumber(good_dogs:sub(i + 2, i + 2))
		local gem = grid[row][column].gem
		assert(gem, "No gem found for grid good dog")
		assert(gem.color == "wild", "Non-wild gem provided for grid good dog")
		self:_turnGemToGoodDog(gem)
	end

	-- grid bad dogs
	assert(#bad_dogs % 4 == 0, "Incorrect length of bad dogs")
	for i = 1, #bad_dogs, 4 do
		local row = tonumber(bad_dogs:sub(i, i + 1))
		local column = tonumber(bad_dogs:sub(i + 2, i + 2))
		local turns_remaining = tonumber(bad_dogs:sub(i + 3, i + 3))
		print("row, column", row, column)

		local gem = grid[row][column].gem
		assert(gem, "No gem found for grid bad dog")
		assert(gem.color == "none", "Non-black gem provided for grid bad dog")
		self:_turnGemToBadDog(gem, turns_remaining)
	end

	-- upcoming dogs
	self.single_dogs_to_make = tonumber(upcoming_single_dogs)
	self.super_dogs_to_make = tonumber(upcoming_super_dogs)

	-- upkeep
	self:_assignBadDogImages()
end

return common.class("Wolfgang", Wolfgang, Character)
