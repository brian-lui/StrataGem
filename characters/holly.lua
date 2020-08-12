--[[ Color: green
Passive: Each newly spawned gem has a 30% chance of having an attached seed.
Also, if Holly's hand does not contain any gems with seeds, the next gem is
guaranteed to contain a seed (except for the initial starting hand's piece
creation).

Matching a seeded gem (match made by Holly) creates a flower in the opponent’s
basin. When this gem would destroyed by a match, instead it is not destroyed,
but the flower disappears.

Super: Summon two spores pods, one on the topmost gem of a random column, and
one on the second most gem of a random column. When they break they spawn
flowers around the spore.
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
		glow = love.graphics.newImage('images/characters/holly/redflowerglow.png'),
	},
	blue = {
		flower = love.graphics.newImage('images/characters/holly/blueflower.png'),
		petala = love.graphics.newImage('images/characters/holly/bluepetala.png'),
		petalb = love.graphics.newImage('images/characters/holly/bluepetalb.png'),
		glow = love.graphics.newImage('images/characters/holly/blueflowerglow.png'),
	},
	green = {
		flower = love.graphics.newImage('images/characters/holly/greenflower.png'),
		petala = love.graphics.newImage('images/characters/holly/greenpetala.png'),
		petalb = love.graphics.newImage('images/characters/holly/greenpetalb.png'),
		glow = love.graphics.newImage('images/characters/holly/greenflowerglow.png'),
	},
	yellow = {
		flower = love.graphics.newImage('images/characters/holly/yellowflower.png'),
		petala = love.graphics.newImage('images/characters/holly/yellowpetala.png'),
		petalb = love.graphics.newImage('images/characters/holly/yellowpetalb.png'),
		glow = love.graphics.newImage('images/characters/holly/yellowflowerglow.png'),
	},
	seed = love.graphics.newImage('images/characters/holly/seeds.png'),
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
	manager.allParticles.NotDrawnThruParticles[counter] = self
	self.manager = manager

	self.STEM_DOWNSHIFT = 12 -- gem center 39px, stem center 24 + 27px

	self.GLOW_PERIOD = 90 -- frames per glow cycle

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

	Pic:create{
		game = manager.game,
		x = self.x,
		y = self.y,
		image = self.owner.special_images[self.gem.color].glow,
		container = self,
		name = "glow",
	}

	self.glow:change{duration = 0, transparency = 0}
	self.glow.timer = 0
end

function Flower:remove()
	self.manager.allParticles.NotDrawnThruParticles[self.ID] = nil
	self.gem.contained_items.holly_flower = nil
	self.owner.flowers[self.gem] = nil
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

	self.glow:wait(delay)
	self.glow:change{
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

		self.glow.timer = (self.glow.timer + (math.pi * 2) / self.GLOW_PERIOD) % (math.pi * 2)

		self.glow:change{
			duration = 0,
			transparency = (math.cos(self.glow.timer) * 0.5) + 0.5,
			x = self.gem.x,
			y = self.gem.y,
		}

		self.glow:update(dt)

		self.x = self.gem.x
		self.y = self.gem.y
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

	local flower = common.instance(Flower, game.particles, params)
	flower:wait(delay)
	flower:change{duration = 0, transparency = 1}

	owner.flowers[gem] = flower
	gem.contained_items.holly_flower = flower

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

function Flower:draw(params)
	if self.glow then self.glow:draw() end
	if self.stem then self.stem:draw() end
	Pic.draw(self, params)
end

Flower = common.class("Flower", Flower, Pic)

-------------------------------------------------------------------------------
-- these are the seeds that appear randomly in Holly's hand gems
local Seed = {}
function Seed:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.NotDrawnThruParticles[counter] = self
	self.manager = manager
end

function Seed:remove()
	self.manager.allParticles.NotDrawnThruParticles[self.ID] = nil
	self.gem.contained_items.holly_seed = nil
	self.owner.seeds[self.gem] = nil
end

function Seed:leavePlay(delay)
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


	self.is_destroyed = true
end

function Seed:update(dt)
	if self.gem.is_destroyed and not self.is_destroyed then
		self:leavePlay(self.gem.time_to_destruction)
	end

	if not self.is_destroyed then
		self.x = self.gem:getRealX()
		self.y = self.gem:getRealY()
	end

	Pic.update(self, dt)
end

function Seed.generate(game, owner, gem, delay)
	assert(gem:isDefaultColor(), "Tried to create seed on non-default color gem!")

	local params = {
		x = gem.x,
		y = gem.y,
		image = owner.special_images.seed,
		owner = owner,
		draw_order = 3,
		player_num = owner.player_num,
		name = "HollySeed",
		gem = gem,
		scaling = 0,
		force_max_alpha = true,
	}

	local seed = common.instance(Seed, game.particles, params)
	seed:wait(delay)
	seed:change{duration = 15, scaling = 1}

	owner.seeds[gem] = seed
	gem.contained_items.holly_seed = seed
end

Seed = common.class("Seed", Seed, Pic)

-------------------------------------------------------------------------------
-- these are the spore pods that appear for Holly's super
local SporePod = {}
function SporePod:init(manager, tbl)
	local game = manager.game
	local stage = game.stage

	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.NotDrawnThruParticles[counter] = self
	self.manager = manager
	self.SHAKE_PIXELS = stage.width * 0.001
	self.SHAKE_PER_FRAME = stage.width * 0.0005
	self.SHAKE_DIRECTION = 1
	self.draw_x_shift = 0

	self.FRAMES_PER_SPORE = 5
	self.spore_framecount = 0
end

function SporePod:remove()
	self.manager.allParticles.NotDrawnThruParticles[self.ID] = nil
	self.gem.contained_items.holly_spore_pod = nil
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

	self.owner.fx.spore.generateStarburst(self.game, self, delay)

	self.is_destroyed = true

	return delay
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

	local spore_pod = common.instance(SporePod, game.particles, params)
	spore_pod:wait(delay)
	spore_pod:change{duration = 0, transparency = 1}

	owner.spore_pods[gem] = spore_pod
	gem.contained_items.holly_spore_pod = spore_pod

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

function SporePod:draw(params)
	params = params or {}
	local draw_params = params or {}

	if params.x then
		draw_params.x = self.draw_x_shift + params.x
	else
		draw_params.x = self.draw_x_shift + self.x
	end

	Pic.draw(self, draw_params)
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
	seed = Seed,
	sporePod = SporePod,
	spore = Spore,
	--damagePetal = DamagePetal,
}

-------------------------------------------------------------------------------

-- snapshop the current hand gems, so that we don't recheck them for possible
-- seed generation
function Holly:_storeCurrentHandGems()
	self.start_of_turn_gems = {}
	for piece in self.hand:pieces() do
		for gem in piece:getGems() do
			self.start_of_turn_gems[gem] = true
		end
	end
end

function Holly:_addFlowerToGem(gem, delay)
	self.fx.flower.generate(self.game, self, gem, delay)
	self.flowered_gems[gem] = true
end

function Holly:_removeFlowerFromGem(gem, delay)
	self.flowers[gem]:leavePlay(delay)
	self.flowered_gems[gem] = nil

	for i = 1, math.random(8, 16) do
		self.game.particles.dust.generateLeafFloat{
			game = self.game,
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
end

function Holly:_addSeedToGem(gem, delay)
	self.fx.seed.generate(self.game, self, gem, delay)
	self.seeded_gems[gem] = true
end

function Holly:_removeSeedFromGem(gem, delay)
	self.seed[gem]:leavePlay(delay)
	self.seeded_gems[gem] = nil
end

function Holly:_addSporePodToGem(gem, delay)
	self.fx.sporePod.generate(self.game, self, gem, delay)
	self.sporepodded_gems[gem] = true
end

function Holly:_removeSporePodFromGem(gem, delay)
	local ret_delay = self.spore_pods[gem]:leavePlay(delay)
	self.sporepodded_gems[gem] = nil

	return ret_delay
end

function Holly:_addSeedsToHand()
	local game = self.game
	local delay = 0
	local SEED_CHANCE = 30

	for piece in self.hand:pieces() do
		for gem in piece:getGems() do
			if not self.start_of_turn_gems[gem] then
				if game.rng:random(100) < SEED_CHANCE then
					delay = self:_addSeedToGem(gem)
				end
			end
		end
	end

	-- add a seed to a random new piece if no seeds at all
	local all_gems_in_hand = {}
	local any_seeds_at_all = false
	for piece in self.hand:pieces() do
		for gem in piece:getGems() do
			if self.seeded_gems[gem] then any_seeds_at_all = true end
			all_gems_in_hand[#all_gems_in_hand + 1] = gem
		end
	end

	if not any_seeds_at_all then
		print("hand has no seeds, adding seed to random gem in hand")
		local rand = game.rng:random(#all_gems_in_hand)
		local chosen_gem = all_gems_in_hand[rand]

		delay = self:_addSeedToGem(chosen_gem)
	end

	return delay
end


function Holly:_activateSuper()
	local game = self.game
	local grid = game.grid

	local function chooseRandomValidGem(row_str)
		assert(row_str == "first" or row_str == "second", "Invalid row_str")

		local row_gems = {}
		local chosen_gem

		for col in grid:cols(self.enemy.player_num) do
			local row
			if row_str == "first" then
				row = grid:getFirstEmptyRow(col) + 1
			elseif row_str == "second" then
				row = grid:getFirstEmptyRow(col) + 2
			end

			if row <= grid.BASIN_END_ROW then
				local gem = grid[row][col].gem

				-- only valid if no flower and can be broken
				if	not (gem.contained_items and gem.contained_items.holly_flower) and
					not (gem.contained_items and gem.contained_items.holly_spore_pod) and
					not gem.indestructible
				then
					row_gems[#row_gems + 1] = gem
				end
			end
		end

		if #row_gems >= 1 then
			local rand = game.rng:random(#row_gems)
			chosen_gem = row_gems[rand]
		end

		return chosen_gem
	end

	local row_1_gem = chooseRandomValidGem("first")
	if row_1_gem then self:_addSporePodToGem(row_1_gem) end

	local row_2_gem = chooseRandomValidGem("second")
	if row_2_gem then self:_addSporePodToGem(row_2_gem) end

	self:emptyMP()

end

--[[ Spore pod explodes and creates flowers in gems surrounding it.
Cells containing valid gems explode with corresponding percentages.
Cells one square away have HIGH chance of a flower. Cells two squares away
except the diagonals have LOW chance of a flower. --]]
function Holly:_sporePodExplode(gem)
	assert(gem.contained_items.holly_spore_pod, "No spore pod to explode!")
	local game = self.game
	local grid = game.grid

	-- get the valid gems for potential flowers
	local cols
	if self.enemy.player_num == 2 then
		cols = {[5] = true, [6] = true, [7] = true, [8] = true}
	elseif self.enemy.player_num == 1 then
		cols = {[1] = true, [2] = true, [3] = true, [4] = true}
	end

	local high_cells = {
		{row = gem.row - 1, col = gem.column - 1},
		{row = gem.row - 1, col = gem.column},
		{row = gem.row - 1, col = gem.column + 1},
		{row = gem.row, col = gem.column - 1},
		{row = gem.row, col = gem.column + 1},
		{row = gem.row + 1, col = gem.column - 1},
		{row = gem.row + 1, col = gem.column},
		{row = gem.row + 1, col = gem.column + 1},
	}

	local low_cells = {
		{row = gem.row - 2, col = gem.column - 1},
		{row = gem.row - 2, col = gem.column},
		{row = gem.row - 2, col = gem.column + 1},
		{row = gem.row - 1, col = gem.column - 2},
		{row = gem.row - 1, col = gem.column + 2},
		{row = gem.row, col = gem.column - 2},
		{row = gem.row, col = gem.column + 2},
		{row = gem.row + 1, col = gem.column - 2},
		{row = gem.row + 1, col = gem.column + 2},
		{row = gem.row + 2, col = gem.column - 1},
		{row = gem.row + 2, col = gem.column},
		{row = gem.row + 2, col = gem.column + 1},
	}

	local function getValidGems(tbl)
		local ret = {}
		for _, loc in ipairs(tbl) do
			if loc.row <= grid.BASIN_END_ROW and cols[loc.col] then
				print("now testing row, col", loc.row, loc.col)
				if grid[loc.row][loc.col].gem then
					local possible_gem = grid[loc.row][loc.col].gem
					if	not possible_gem.indestructible and
						not possible_gem.contained_items.holly_flower
					then
						ret[#ret + 1] = possible_gem
					end
				end
			end
		end

		return ret
	end

	-- roll the chance for flower generation
	local HIGH_CHANCE = 60
	local LOW_CHANCE = 20

	local high_gems = getValidGems(high_cells)
	local low_gems = getValidGems(low_cells)

	local to_flower_gems = {}
	for _, possible_high_gem in ipairs(high_gems) do
		if game.rng:random(100) < HIGH_CHANCE then
			to_flower_gems[#to_flower_gems + 1] = possible_high_gem
		end
	end
	for _, possible_low_gem in ipairs(low_gems) do
		if game.rng:random(100) < LOW_CHANCE then
			to_flower_gems[#to_flower_gems + 1] = possible_low_gem
		end
	end

	-- destroy spore pod
	local spore_pod_explode_delay = self:_removeSporePodFromGem(gem)
	local EXTRA_DELAY = 40
	local flower_delay = spore_pod_explode_delay + EXTRA_DELAY

	-- generate flowers
	for _, to_flower_gem in ipairs(to_flower_gems) do
		self:_addFlowerToGem(to_flower_gem, flower_delay)
	end
end

function Holly:init(...)
	Character.init(self, ...)

	self.flowers = {} -- flower image objects
	self.seeds = {} -- seed image objects
	self.spore_pods = {} -- spore pod image objects
	self.seeds_matched_this_turn = 0

	self.to_be_removed_flowers = {} -- temporary gemdestroy use

	self.start_of_turn_gems = {} -- don't check these for possible seed creation

	-- to keep track of state
	self.flowered_gems = {}
	self.seeded_gems = {}
	self.sporepodded_gems = {}
end

function Holly:beforeGravity()
	local delay = 0

	if self.is_supering then
		delay = self:_activateSuper()
		self.is_supering = false
	end

	self:_storeCurrentHandGems()

	return delay
end

function Holly:beforeTween()
	self.game:brightenScreen(self.player_num)
end

function Holly:beforeMatch()
	local game = self.game
	local grid = game.grid
	local delay = 0

	-- Get the number of seeded gems that we matched
	-- This determines how many flowers will be generated
	for _, gem in ipairs(grid.matched_gems) do
		if gem.player_num == self.player_num and self.seeded_gems[gem] then
			print("a seeded gem was destroyed!")
			self.seeds_matched_this_turn = self.seeds_matched_this_turn + 1
		end
	end

	return delay
end

function Holly:afterMatch()
	local game = self.game
	local grid = game.grid
	local FLOWER_DELAY = 20

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
	for i = 1, self.seeds_matched_this_turn do
		if eligible_gems[i] then
			local gem = eligible_gems[i]
			self:_addFlowerToGem(gem, FLOWER_DELAY)
		end
	end

	self.seeds_matched_this_turn = 0
end

function Holly:cleanup()
	local delay = self:_addSeedsToHand()

	Character.cleanup(self)

	return delay
end

-- This should also activate from matches
function Holly:onGemDestroyStart(gem, delay)
	-- if destroyed gem has a flower, remove flower instead of destroying gem
	if	gem.contained_items.holly_flower and
		gem.contained_items.holly_flower.player_num == self.player_num and
		(not gem.indestructible)
	then
		gem.indestructible = true
		self.to_be_removed_flowers[#self.to_be_removed_flowers + 1] = gem
	end

	-- if destroyed gem has a spore pod, explode the spore pod
	if	gem.contained_items.holly_spore_pod and
		gem.contained_items.holly_spore_pod.player_num == self.player_num
	then
		self:_sporePodExplode(gem)
	end
end

function Holly:onGemDestroyEnd(gem, delay)
	if	gem.contained_items.holly_flower and
		gem.contained_items.holly_flower.player_num == self.player_num
	then
		for k, this_gem in pairs(self.to_be_removed_flowers) do
			if this_gem == gem then
				self.to_be_removed_flowers[k] = nil
				gem.indestructible = nil
				self:_removeFlowerFromGem(gem, delay)
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
