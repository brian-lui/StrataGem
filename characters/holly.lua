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
--]]

local love = _G.love
local common = require "class.commons"
local Character = require "character"
local images = require "images"
local shuffle = require "/helpers/utilities".shuffle

local Holly = {}

Holly.large_image = love.graphics.newImage('images/portraits/holly.png')
Holly.small_image = love.graphics.newImage('images/portraits/hollysmall.png')
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
-Flowers appear in a "garbage" way. In addition to dust, also include some
petala and petalb of the appropriate color.

FLOWERS DANCE WHILE ACTIVE

-A flower consists of two parts. stem (same for all colors) and flower. stem
should appear with the bottom pixel at the bottom of the square. flower appears
in the middle of the square.

-Flowers dance while active.

-Blue and Red dance by alternating between [150% height and 75% width], [100%
height and 100% width], and [75% heigth and 150% width].

-Yellow and Green dance by slowly rotating.

WHEN A FLOWER EXPLODES

-See attached "petal explosion" diagram

Damage sent by flower should be made up of attack particles AND the addition of
some petala and petalb of the appropriate color.
--]]
--[[
Garbage way:
	-- garbage circle particles
	game.particles.dust.generateGarbageCircle{
		game = game,
		gem = gem,
		delay_frames = delay,
	}
	game.particles.dust.generateGarbageCircle{
		game = game,
		gem = gem,
		image = petala/petalb,
		delay_frames = delay,
		num = 4,
	}

--]]
---[[
local Flower = {}
function Flower:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
end

function Flower:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
	self.owner.flower_images[self.gem] = nil
end

function Flower:update(dt)
	Pic.update(self, dt)
	self.x = self.gem.x
	self.y = self.gem.y
	if self.gem.is_destroyed and not self.is_destroyed then
		local game = self.game
		local end_time = self.gem.time_to_destruction
		local start_time = math.max(0, end_time - game.GEM_EXPLODE_FRAMES)

		self:wait(end_time)
		self:change{
			duration = game.GEM_EXPLODE_FRAMES,
			scaling = 2,
			transparency = 0,
			remove = true,
		}

		--game.queue:add(end_time, self.remove, self)
		self.is_destroyed = true
	end
end

function Flower.generate(game, owner, gem, delay)
	local params = {
		x = gem.x,
		y = gem.y,
		image = owner.special_images.flower,
		owner = owner,
		draw_order = 1,
		player_num = owner.player_num,
		name = "HollyFlower",
		h_flip = math.random() < 0.5,
		v_flip = math.random() < 0.5,
		gem = gem,
		transparency = 0,
		force_max_alpha = true,
	}

	owner.flower_images[gem] = common.instance(Flower, game.particles, params)
	owner.flower_images[gem]:wait(delay)
	owner.flower_images[gem]:change{duration = 0, transparency = 1}

	-- generate garbage appear circle with extra petals
	game.particles.dust.generateGarbageCircle{
		game = game,
		gem = gem,
		--delay_frames = delay,
	}
	game.particles.dust.generateGarbageCircle{
		game = game,
		gem = gem,
		"image = petala",
		--delay_frames = delay,
		num = 4,
	}	
	game.particles.dust.generateGarbageCircle{
		game = game,
		gem = gem,
		"image = petalb",
		--delay_frames = delay,
		num = 4,
	}	
end

Flower = common.class("Flower", Flower, Pic)
--]]
-------------------------------------------------------------------------------
Holly.fx = {
	flower = Flower,
}


function Holly:init(...)
	Character.init(self, ...)

	self.flower_images = {}
	self.spore_images = {}
	self.matches_made = 0
end

function Holly:beforeGravity()
	-- Super 1
	-- gain super spore pods
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
	print("HOLLY made " .. self.matches_made .. " matches this round.")
end

function Holly:duringMatch()
	-- Passive 4
	-- apply flower heal/damage

	-- Super 3
	--[[ if a match contains both player's spores, grey match. otherwise,
	if a match contains a spore, force it to be flagged for the opponent]]
end

function Holly:afterMatch()
	local game = self.game
	local grid = game.grid
	local FLOWER_DELAY = 10
	-- Passive: For each match, a random gem in your basin gains a flower mark
	-- Get all eligible gems
	local eligible_gems = {}
	for gem in grid:basinGems(self.player_num) do
		if gem.color ~= "none" and not gem.indestructible then
			eligible_gems[#eligible_gems + 1] = gem
		end
	end
	shuffle(eligible_gems, game.rng)

	-- add the flowers
	for i = 1, self.matches_made do
		if eligible_gems[i] then
			print("HOLLY is adding a flower now.")
			local gem = eligible_gems[i]
			gem.holly_flower = self.player_num 

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
