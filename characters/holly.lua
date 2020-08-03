--[[ Color: green
Passive: Making a match creates a flower in a random non-special gem in the
opponent's basin. When this gem would destroyed by a match, instead it is not
destroyed, but the flower disappears.

Super: Spore pod that makes some flower shit
--]]

local love = _G.love
local common = require "class.commons"
local Pic = require "pic"
local Character = require "character"
local images = require "images"
local shuffle = require "/helpers/utilities".shuffle

local Holly = {}

Holly.large_image = love.graphics.newImage('images/portraits/holly.png')
Holly.small_image = love.graphics.newImage('images/portraits/hollysmall.png')
Holly.action_image = love.graphics.newImage('images/portraits/action_holly.png')
Holly.shadow_image = love.graphics.newImage('images/portraits/shadow_holly.png')
Holly.super_fuzz_image = love.graphics.newImage('images/ui/superfuzzgreen.png')

Holly.character_name = "Holly"
Holly.meter_gain = {
	red = 4,
	blue = 4,
	green = 8,
	yellow = 4,
	none = 4,
	wild = 4,
}
Holly.primary_colors = {"green"}

Holly.super_images = {
	word = images.ui_super_text_green,
	empty = images.ui_super_empty_green,
	full = images.ui_super_full_green,
	glow = images.ui_super_glow_green,
	overlay = love.graphics.newImage('images/characters/holly/hollylogo.png'),
}
Holly.burst_images = {
	partial = images.ui_burst_part_green,
	full = images.ui_burst_full_green,
	glow = {images.ui_burst_partglow_green, images.ui_burst_fullglow_green}
}

Holly.special_images = {
	red = {
		flower = love.graphics.newImage('images/characters/holly/redflower.png'),
		petala = love.graphics.newImage('images/characters/holly/redpetala.png'),
		petalb = love.graphics.newImage('images/characters/holly/redpetalb.png'),
		rage = love.graphics.newImage('images/characters/holly/redrage.png'),
	},
	blue = {
		flower = love.graphics.newImage('images/characters/holly/blueflower.png'),
		petala = love.graphics.newImage('images/characters/holly/bluepetala.png'),
		petalb = love.graphics.newImage('images/characters/holly/bluepetalb.png'),
		rage = love.graphics.newImage('images/characters/holly/bluerage.png'),
	},
	green = {
		flower = love.graphics.newImage('images/characters/holly/greenflower.png'),
		petala = love.graphics.newImage('images/characters/holly/greenpetala.png'),
		petalb = love.graphics.newImage('images/characters/holly/greenpetalb.png'),
		rage = love.graphics.newImage('images/characters/holly/greenrage.png'),
	},
	yellow = {
		flower = love.graphics.newImage('images/characters/holly/yellowflower.png'),
		petala = love.graphics.newImage('images/characters/holly/yellowpetala.png'),
		petalb = love.graphics.newImage('images/characters/holly/yellowpetalb.png'),
		rage = love.graphics.newImage('images/characters/holly/yellowrage.png'),
	},
	spore_pod = love.graphics.newImage('images/characters/holly/sporepod.png'),
	spore = love.graphics.newImage('images/characters/holly/spore.png'),
	stem = love.graphics.newImage('images/characters/holly/stem.png'),
}

Holly.sounds = {
	bgm = "bgm_holly",
}


-------------------------------------------------------------------------------
-- these are the flowers that appear whenever Holly makes a match
local Flower = {}
function Flower:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager

	self.STEM_DOWNSHIFT = 12 -- gem center 39px, stem center 24 + 27px

	self.SIZE_DANCE_SPEED = 15 -- frames for each phase
	self.SIZE_DANCE_PHASE = 0
	self.size_dance_frame = 0

	self.ROTATE_DANCE_SPEED = math.pi / 240 -- movement each frame

	Pic:create{
		game = manager.game,
		x = self.x,
		y = self.y + self.STEM_DOWNSHIFT,
		image = self.owner.special_images.stem,
		container = self,
		name = "stem",
	}

	self.stem:change{duration = 0, transparency = 0}
	self.stem:wait(tbl.stem_appear_delay)
	self.stem:change{duration = 0, transparency = 1}
end

function Flower:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
	self.owner.flowers[self.gem] = nil
end

--[[ I want to do this inelegant way so we don't use Pic:change()
	Phase 0: x/y from 1.0/1.0 to 1.05/0.95
	Phase 1: x/y from 1.05/0.95 to 1.0/1.0
	Phase 2: x/y from 1.0/1.0 to 0.95/1.05
	Phase 3: x/y from 0.95/1.05 to 1.0/1.0 --]]
function Flower:_sizeDance()
	local SMALL_STEP, LARGE_STEP = 0.05, 0.05
	local x_step, y_step
	if self.SIZE_DANCE_PHASE == 0 then
		x_step = LARGE_STEP / self.SIZE_DANCE_SPEED
		y_step = -SMALL_STEP / self.SIZE_DANCE_SPEED
	elseif self.SIZE_DANCE_PHASE == 1 then
		x_step = -LARGE_STEP / self.SIZE_DANCE_SPEED
		y_step = SMALL_STEP / self.SIZE_DANCE_SPEED
	elseif self.SIZE_DANCE_PHASE == 2 then
		x_step = -SMALL_STEP / self.SIZE_DANCE_SPEED
		y_step = LARGE_STEP / self.SIZE_DANCE_SPEED
	elseif self.SIZE_DANCE_PHASE == 3 then
		x_step = SMALL_STEP / self.SIZE_DANCE_SPEED
		y_step = -LARGE_STEP / self.SIZE_DANCE_SPEED
	end
	self.x_scaling = self.x_scaling + x_step
	self.y_scaling = self.y_scaling + y_step

	self.size_dance_frame = self.size_dance_frame + 1
	if self.size_dance_frame >= self.SIZE_DANCE_SPEED then
		self.size_dance_frame = 0
		self.SIZE_DANCE_PHASE = (self.SIZE_DANCE_PHASE + 1) % 4

		if self.SIZE_DANCE_PHASE == 0 then
			self.x_scaling, self.y_scaling = 1, 1
		elseif self.SIZE_DANCE_PHASE == 1 then
			self.x_scaling, self.y_scaling = 1 + LARGE_STEP, 1 - SMALL_STEP
		elseif self.SIZE_DANCE_PHASE == 2 then
			self.x_scaling, self.y_scaling = 1, 1
		elseif self.SIZE_DANCE_PHASE == 3 then
			self.x_scaling, self.y_scaling = 1 - SMALL_STEP, 1 + LARGE_STEP
		end
	end
end

function Flower:_rotateDance()
	self.rotation = (self.rotation + self.ROTATE_DANCE_SPEED) % (math.pi * 2)
end

function Flower:leavePlay(delay)
	local game = self.game
	delay = delay or 0

	self:wait(delay)
	self:change{
		duration = game.GEM_EXPLODE_FRAMES,
		x_scaling = 2,
		y_scaling = 2,
		transparency = 0,
		remove = true,
	}

	self.stem:wait(delay)
	self.stem:change{
		duration = game.GEM_EXPLODE_FRAMES,
		scaling = 2,
		transparency = 0,
		remove = true,
	}

	self.is_destroyed = true
end

function Flower:update(dt)
	if self.gem.is_destroyed and not self.is_destroyed then
		self:leavePlay(self.gem.time_to_destruction)
	end

	if not self.is_destroyed then
		self.stem.x = self.gem.x
		self.stem.y = self.gem.y + self.STEM_DOWNSHIFT
		self.stem:update(dt)

		self.x = self.gem.x
		self.y = self.gem.y

		if self.color == "red" or self.color == "blue" then
			self:_sizeDance()
		elseif self.color == "green" or self.color == "yellow" then
			self:_rotateDance()
		end
	end

	Pic.update(self, dt)
end

function Flower.generate(game, owner, gem, delay)
	local color = gem.color
	assert(gem:isDefaultColor(), "Tried to create flower on non-default color gem!")

	local params = {
		x = gem.x,
		y = gem.y,
		image = owner.special_images[color].flower,
		owner = owner,
		draw_order = 3,
		color = color,
		player_num = owner.player_num,
		name = "HollyFlower",
		gem = gem,
		transparency = 0,
		x_scaling = 1,
		y_scaling = 1,
		force_max_alpha = true,
		stem_appear_delay = delay,
	}

	owner.flowers[gem] = common.instance(Flower, game.particles, params)
	owner.flowers[gem]:wait(delay)
	owner.flowers[gem]:change{duration = 0, transparency = 1}

	-- generate garbage appear circle with extra petals
	game.particles.dust.generateGarbageCircle{
		game = game,
		gem = gem,
		delay_frames = delay,
	}
	game.particles.dust.generateGarbageCircle{
		game = game,
		gem = gem,
		image = owner.special_images[color].petala,
		delay_frames = delay,
		rotation = math.random() * math.pi * 2,
		num = 4,
	}
	game.particles.dust.generateGarbageCircle{
		game = game,
		gem = gem,
		image = owner.special_images[color].petalb,
		delay_frames = delay,
		rotation = math.random() * math.pi * 2,
		num = 4,
	}

	return owner.flowers[gem]
end

function Flower:draw()
	if self.stem then self.stem:draw() end
	Pic.draw(self)
end

Flower = common.class("Flower", Flower, Pic)

-------------------------------------------------------------------------------
-- these are the spore pods that appear for Holly's super
local SporePod = {}
function SporePod:init(manager, tbl)
	local game = manager.game
	local stage = game.stage

	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager

	self.STEM_DOWNSHIFT = 12 -- gem center 39px, stem center 24 + 27px

	self.SHAKE_PIXELS = stage.width * 0.001
	self.SHAKE_PER_FRAME = stage.width * 0.0005
	self.SHAKE_DIRECTION = 1
	self.draw_x_shift = 0

	self.FRAMES_PER_SPORE = 5
	self.spore_framecount = 0

	Pic:create{
		game = manager.game,
		x = self.x,
		y = self.y + self.STEM_DOWNSHIFT,
		image = self.owner.special_images.stem,
		container = self,
		name = "stem",
	}

	self.stem:change{duration = 0, transparency = 0}
	self.stem:wait(tbl.stem_appear_delay)
	self.stem:change{duration = 0, transparency = 1}
end

function SporePod:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
	self.owner.spore_pods[self.gem] = nil
end

-- remove through either gem destroyed, or timer expiry
function SporePod:leavePlay(delay)
	local game = self.game
	delay = delay or game.GEM_EXPLODE_FRAMES

	self:wait(delay)
	self:change{
		duration = game.GEM_EXPLODE_FRAMES,
		x_scaling = 2,
		y_scaling = 2,
		transparency = 0,
		remove = true,
	}

	self.stem:wait(delay)
	self.stem:change{
		duration = game.GEM_EXPLODE_FRAMES,
		scaling = 2,
		transparency = 0,
		remove = true,
	}

	self.owner.fx.spore.generateStarburst(self.game, self, delay)

	self.is_destroyed = true
end

function SporePod:_shake()
	self.draw_x_shift = self.SHAKE_DIRECTION * self.SHAKE_PER_FRAME +
		self.draw_x_shift

	if self.draw_x_shift > self.SHAKE_PIXELS then
		self.SHAKE_DIRECTION = -1
	elseif self.draw_x_shift < -self.SHAKE_PIXELS then
		self.SHAKE_DIRECTION = 1
	end
end

function SporePod:_dropSporePod()
	self.spore_framecount = self.spore_framecount + 1
	if self.spore_framecount >= self.FRAMES_PER_SPORE then
		self.spore_framecount = 0
		self.owner.fx.spore.generateFalling(self.game, self)
	end
end

function SporePod:update(dt)
	if self.gem.is_destroyed and not self.is_destroyed then
		local delay = self.gem.time_to_destruction
		self:leavePlay(delay)
	end

	if not self.is_destroyed then
		self.stem.x = self.gem.x
		self.stem.y = self.gem.y + self.STEM_DOWNSHIFT
		self.stem:update(dt)

		self.x = self.gem.x
		self.y = self.gem.y
		self:_shake()
		self:_dropSporePod()
	end

	Pic.update(self, dt)
end

function SporePod.generate(game, owner, gem, delay)
	local color = gem.color
	assert(gem:isDefaultColor(), "Tried to create spore pod on non-default color gem!")

	local params = {
		x = gem.x,
		y = gem.y,
		image = owner.special_images.spore_pod,
		owner = owner,
		draw_order = 3,
		player_num = owner.player_num,
		name = "HollySporePod",
		gem = gem,
		transparency = 0,
		x_scaling = 1,
		y_scaling = 1,
		force_max_alpha = true,
	}

	owner.spore_pods[gem] = common.instance(SporePod, game.particles, params)
	owner.spore_pods[gem]:wait(delay)
	owner.spore_pods[gem]:change{duration = 0, transparency = 1}

	-- generate garbage appear circle with extra petals
	game.particles.dust.generateGarbageCircle{
		game = game,
		gem = gem,
		delay_frames = delay,
	}
	game.particles.dust.generateGarbageCircle{
		game = game,
		gem = gem,
		image = owner.special_images[color].petala,
		delay_frames = delay,
		rotation = math.random() * math.pi * 2,
		num = 4,
	}
	game.particles.dust.generateGarbageCircle{
		game = game,
		gem = gem,
		image = owner.special_images[color].petalb,
		delay_frames = delay,
		rotation = math.random() * math.pi * 2,
		num = 4,
	}
end

function SporePod:draw()
	if self.stem then self.stem:draw() end
	Pic.draw(self, {x = self.draw_x_shift + self.x})
end

SporePod = common.class("SporePod", SporePod, Pic)

-------------------------------------------------------------------------------
-- Spores generated from spore pods
local Spore = {}
function Spore:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
end

function Spore:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

-- regular falling spore
function Spore.generateFalling(game, spore_pod)
	local owner = spore_pod.owner

	local DURATION = 160
	local ROTATION = 6
	local FALL_DIST = 0.13 * game.stage.height

	local x = spore_pod.x + (math.random() - 0.5) * spore_pod.width * 0.75
	local y = spore_pod.y + (math.random() - 0.5) * spore_pod.height * 0.75

	local params = {
		name = "spore",
		x = x,
		y = y,
		image = owner.special_images.spore,
		draw_order = 3,
		owner = owner,
	}

	local p = common.instance(Spore, game.particles, params)
	p:change{
		duration = DURATION,
		rotation = ROTATION,
		y = p.y + FALL_DIST,
	}
	p:change{
		duration = DURATION * 0.3,
		rotation = ROTATION * 1.3,
		transparency = 0,
		y = p.y + 1.3 * FALL_DIST,
		remove = true,
	}
end

-- starburst spore
function Spore.generateStarburst(game, spore_pod, delay)
	local SPORE_NUM = 1000
	local DURATION = 160

	local owner = spore_pod.owner
	local x, y = spore_pod.x, spore_pod.y

	local starburst_end_xy = function(start_x, start_y)
		local dist = game.stage.width * 0.1 * (0.5 + math.random())
		local angle = math.random() * math.pi * 2
		local end_x = dist * math.cos(angle) + start_x
		local end_y = dist * math.sin(angle) + start_y
		return end_x, end_y
	end

	for i = 1, SPORE_NUM do
		local end_x, end_y = starburst_end_xy(x, y)

		local params = {
			name = "spore",
			x = x,
			y = y,
			image = owner.special_images.spore,
			draw_order = 3,
			owner = owner,
		}

		local p = common.instance(Spore, game.particles, params)

		if delay then
			p.transparency = 0
			p:wait(delay)
			p:change{duration = 0, transparency = 1}
		end

		p:change{
			duration = DURATION,
			x = end_x,
			y = end_y,
			transparency = 0.5,
			easing = "outCubic",
		}

		p:change{
			duration = math.floor(i * 0.04),
			transparency = 0,
			remove = true,
		}
	end
end

Spore = common.class("Spore", Spore, Pic)
-------------------------------------------------------------------------------
Holly.fx = {
	flower = Flower,
	sporePod = SporePod,
	spore = Spore,
}

-------------------------------------------------------------------------------

function Holly:init(...)
	Character.init(self, ...)

	self.flowers = {} -- flower image objects
	self.matches_made = 0

	self.to_be_removed_flowers = {} -- temporary gemdestroy use
end

function Holly:beforeGravity()
	local game = self.game
	local grid = game.grid
	local delay = 0

	if self.is_supering then
		--[[
		TODO: generate a spore pod somewhere or other
		--]]

		delay = 30
		self:emptyMP()
		self.is_supering = false
		self.supered_this_turn = true
	end

	return delay
end

function Holly:beforeTween()
	self.game:brightenScreen(self.player_num)
end

function Holly:beforeMatch()
	local game = self.game
	local grid = game.grid
	local delay = 0

	-- Get the number of matches made that belong to us
	-- This determines how many flowers will be generated
	local match_lists = grid.matched_gem_lists
	for _, list in ipairs(match_lists) do
		local owned_by_me = false
		for _, gem in ipairs(list) do
			if gem.player_num == self.player_num then owned_by_me = true end
		end

		if owned_by_me then self.matches_made = self.matches_made + 1 end
	end

	-- Check if any of the matched gems have a flower on them
	-- If so, remove the flower and remove them from the matched list
	-- This happens before destroyGem, so it doesn't activate onGemDestroy
	local to_unmatch = {}
	for i = #grid.matched_gems, 1, -1 do
		local gem = grid.matched_gems[i]
		if gem.contained_items.holly_flower then
			assert(self.flowers[gem], "Tried to remove non-existent flower!")
			gem.contained_items.holly_flower = nil
			self.flowers[gem]:leavePlay()
			to_unmatch[#to_unmatch + 1] = gem
		end
	end

	for _, unmatch in ipairs(to_unmatch) do grid:clearMatchedGem(unmatch) end

	return delay
end

function Holly:afterMatch()
	local game = self.game
	local grid = game.grid
	local FLOWER_DELAY = 20

	-- Passive: For each match, a random gem in your basin gains a flower mark:
	-- Get all eligible gems
	local eligible_gems = {}
	for gem in grid:basinGems(self.enemy.player_num) do
		if gem.color ~= "none"
		and gem.color ~= "wild"
		and not gem.indestructible
		and not gem.contained_items.holly_flower then
			eligible_gems[#eligible_gems + 1] = gem
		end
	end
	shuffle(eligible_gems, game.rng)

	-- add the flowers
	for i = 1, self.matches_made do
		if eligible_gems[i] then
			local gem = eligible_gems[i]
			local flower = self.fx.flower.generate(game, self, gem, FLOWER_DELAY)
			gem.contained_items.holly_flower = flower
		end
	end

	self.matches_made = 0
end

function Holly:cleanup()
	local game = self.game
	local grid = game.grid
	local delay = 0

	Character.cleanup(self)

	return delay
end

function Holly:onGemDestroyStart(gem, delay)
	if	(gem.contained_items.holly_flower) and
		(gem.contained_items.holly_flower.player_num == self.player_num) and
		(not gem.indestructible)
	then
		gem.indestructible = true
		self.to_be_removed_flowers[#self.to_be_removed_flowers + 1] = gem
	end
end

function Holly:onGemDestroyEnd(gem, delay)
	if	(gem.contained_items.holly_flower) and
		(gem.contained_items.holly_flower.player_num == self.player_num)
	then
		for k, this_gem in pairs(self.to_be_removed_flowers) do
			if this_gem == gem then
				assert(self.flowers[gem], "Tried to remove non-existent flower!")

				self.to_be_removed_flowers[k] = nil
				gem.indestructible = nil
				gem.contained_items.holly_flower = nil
				self.flowers[gem]:leavePlay(delay)
			end
		end
	end
end

--[[

TODO
function Holly:serializeSpecials()
	local ret = ""
	for i in self.game.grid:cols() do ret = ret .. self.ready_fires[i] end
	return ret
end

function Holly:deserializeSpecials(str)
	for i = 1, #str do
		local col = i
		local turns_remaining = tonumber(str:sub(i, i))
		self.ready_fires[col] = turns_remaining
		if turns_remaining > 0 then
			self.fx.smallFire.generateSmallFire(
				self.game,
				self,
				col,
				nil,
				turns_remaining
			)
		end
	end
end
--]]

return common.class("Holly", Holly, Character)
