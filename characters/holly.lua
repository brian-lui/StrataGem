--[[ Color: green
Passive: For every match you make, a random gem in your basin gains a flower
mark. When the flower gem breaks (regardless of who breaks it, including grey
breaks) the Holly who made the flower heals one damage and the opponent takes
one damage.

Super: 2 spores appear randomly in either the topmost row or second top most
row of any of the opponent’s columns. (So 2 spores randomly appearing in 2 of 8
possible spaces.) If the opponent breaks a spore through matching, all
the damage (including combo damage) is reflected. Spores disappear after three
turns.

Animations:
Spore Pods appear on stems the same way a flower does, but instead of dancing,
they shake left and right. (rapidly tween back and forth like 5 pixels total.)
Also, while they are on screen, they drop spore.png in the same way that gems
drop dust when held or rotated.

When spore pods explode, they should shoot spores the same way gems shoot dust.
lots of spores. thanks.
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
	stem = love.graphics.newImage('images/characters/holly/stem.png'),
}

Holly.sounds = {
	bgm = "bgm_holly",
}


-------------------------------------------------------------------------------
-- these are the flowers that appear whenever Holly makes a match
--[[
WHEN A FLOWER EXPLODES

-See attached "petal explosion" diagram

Damage sent by flower should be made up of attack particles AND the addition of
some petala and petalb of the appropriate color.
--]]

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
	self.owner.flower_images[self.gem] = nil
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

function Flower:update(dt)
	self.stem.x = self.gem.x
	self.stem.y = self.gem.y + self.STEM_DOWNSHIFT
	self.stem:update(dt)

	self.x = self.gem.x
	self.y = self.gem.y
	Pic.update(self, dt)

	if not self.is_destroyed then
		if self.color == "red" or self.color == "blue" then
			self:_sizeDance()
		elseif self.color == "green" or self.color == "yellow" then
			self:_rotateDance()
		end
	end

	if self.gem.is_destroyed and not self.is_destroyed then
		local game = self.game
		local start_time = self.gem.time_to_destruction

		self:wait(start_time)
		self:change{
			duration = game.GEM_EXPLODE_FRAMES,
			x_scaling = 2,
			y_scaling = 2,
			transparency = 0,
			remove = true,
		}

		self.stem:wait(start_time)
		self.stem:change{
			duration = game.GEM_EXPLODE_FRAMES,
			scaling = 2,
			transparency = 0,
			remove = true,
		}

		self.is_destroyed = true
	end
end

function Flower.generate(game, owner, gem, delay)
	local color = gem.color
	assert(color == "red" or color == "blue" or color == "green" or color == "yellow",
		"Tried to generate flower on non-default color gem!")

	local params = {
		x = gem.x,
		y = gem.y,
		image = owner.special_images[color].flower,
		owner = owner,
		draw_order = 2,
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

	owner.flower_images[gem] = common.instance(Flower, game.particles, params)
	owner.flower_images[gem]:wait(delay)
	owner.flower_images[gem]:change{duration = 0, transparency = 1}

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

function Flower:draw()
	self.stem:draw()
	Pic.draw(self)
end

Flower = common.class("Flower", Flower, Pic)

-------------------------------------------------------------------------------
-- extra damage petals, follows the bezier to the second platform slowly
local DamagePetal = {}
function DamagePetal:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
end

function DamagePetal:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function DamagePetal.generate(game, owner, gem, delay)
	local TRAVEL_TIME = 60
	local x1, y1 = gem.x, gem.y
	local x4, y4 = owner.enemy.hand[2].x, owner.enemy.hand[2].y
	local dist = ((x4 - x1) ^ 2 + (y4 - y1) ^ 2) ^ 0.5
	local x3, y3 = 0.5 * (x1 + x4), 0.5 * (y1 + y4)

	local images = {
		owner.special_images[gem.color].petala,
		owner.special_images[gem.color].petalb,
	}

	for _, image in ipairs(images) do
		for i = 1, 4 do
			local angle = math.random() * math.pi * 2
			local x2 = x1 + math.cos(angle) * dist * 0.5
			local y2 = y1 + math.sin(angle) * dist * 0.5

			local curve = love.math.newBezierCurve(x1, y1, x2, y2, x3, y3, x4, y4)

			local params = {
				x = x1,
				y = y1,
				image = image,
				draw_order = 2,
				owner = owner,
			}

			local p = common.instance(DamagePetal, game.particles, params)

			if delay then
				p.transparency = 0
				p:wait(delay)
				p:change{duration = 0, transparency = 1}
			end

			p:change{duration = TRAVEL_TIME + i * 5, curve = curve, remove = true}
		end
	end
end

DamagePetal = common.class("DamagePetal", DamagePetal, Pic)

-------------------------------------------------------------------------------
Holly.fx = {
	flower = Flower,
	damagePetal = DamagePetal,
}

-------------------------------------------------------------------------------

function Holly:init(...)
	Character.init(self, ...)

	self.flower_images = {}
	self.spore_images = {}
	self.matches_made = 0
end

-- callback activated from grid:destroyGem
function Holly._onFlowerDestroy(gem, delay, self)
	local damage_particle_duration = 0
	local game = self.game

	-- slightly delay if it's not a grey match
	if gem.player_num == 1 or gem.player_num == 2 then
		delay = delay + game.GEM_EXPLODE_FRAMES
	end

	-- deal 1 damage
	self.enemy:addDamage(1, delay)
	local d = game.particles.damage.generate(
		game,
		gem,
		delay,
		nil,
		self.player_num
	)
	local damage_particle_duration = math.max(damage_particle_duration, d)

	-- extra petal damage particles
	self.fx.damagePetal.generate(game, self, gem, delay)

	-- heal 1 damage
	self:healDamage(1, delay)
	local h = game.particles.healing.generate{
		game = game,
		x = gem.x,
		y = gem.y,
		owner = self,
	}
	local damage_particle_duration = math.max(damage_particle_duration, h)
	game.queue:add(delay, game.sound.newSFX, game.sound, "healing")

	for i = 1, math.random(4, 8) do
		game.particles.dust.generateLeafFloat{
			game = game,
			x = gem.x,
			y = gem.y,
			image = self.special_images[gem.color].petala,
			delay = i,
			y_dist = images.GEM_WIDTH * 0.5,
			x_drift = images.GEM_WIDTH,
			swap_image = self.special_images[gem.color].petalb,
			swap_tween = "y_scaling",
			swap_period = 30,
		}
	end

	return damage_particle_duration
end

function Holly:beforeGravity()
	-- Super 1
	-- gain super spore pods
	--[[
		2 spores appear randomly in either the topmost row or second top most
		row of any of the opponent’s columns. (So 2 spores randomly appearing in 2 of 8
		possible spaces.)
	--]]
	--[[
		spore is set to the gem as gem.holly_spore = self.player_num
		spore image referenced in self.spore_images
		spore class remove method has self.owner.spore_images[self.gem] = nil
	--]]
end

function Holly:beforeMatch()
	local game = self.game
	local grid = game.grid

	-- Passive: get the number of matches made that belong to us
	local match_lists = grid:getMatchedGemLists()
	for _, list in ipairs(match_lists) do
		local owned_by_me = false
		for _, gem in ipairs(list) do
			if gem.player_num == self.player_num then owned_by_me = true end
		end

		if owned_by_me then self.matches_made = self.matches_made + 1 end
	end
end

function Holly:duringMatch()
	-- Super 3
	--[[
	count number of matches of both player's spores.
	If match owner's opponent has more spores than you, reflect it.
	flag them with gem.holly_reflected for future animation use
	--]]
end

function Holly:afterMatch()
	local game = self.game
	local grid = game.grid
	local FLOWER_DELAY = 20

	-- Passive: For each match, a random gem in your basin gains a flower mark:
	-- Get all eligible gems
	local eligible_gems = {}
	for gem in grid:basinGems(self.player_num) do
		if gem.color ~= "none"
		and gem.color ~= "wild"
		and not gem.indestructible
		and not gem.holly_flower then
			eligible_gems[#eligible_gems + 1] = gem
		end
	end
	shuffle(eligible_gems, game.rng)

	-- add the flowers
	for i = 1, self.matches_made do
		if eligible_gems[i] then
			local gem = eligible_gems[i]
			gem.holly_flower = self.player_num 
			gem:addDestroyFunc(self.player_num, self._onFlowerDestroy, self)

			self.fx.flower.generate(game, self, gem, FLOWER_DELAY)
		end
	end

	self.matches_made = 0
end

function Holly:cleanup()
	-- Super 2
	-- countdown spores and disappear ones that reach 0 turns remaining
	Character.cleanup(self)
end

return common.class("Holly", Holly, Character)
