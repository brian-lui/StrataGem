--[[
This module contains all the pre-defined animated objects for non-character
images. Particles are objects that are displayed on-screen but do not affect
the gamestate.

There should never be gamestate code that depends on particles, except for
code that uses particle duration to calculate delay times.

Note about draw_order, as used in gs_main:drawGems(). Draw order is as
follows, from drawn first to drawn last:

	gem platforms
	word effects, dust, pop particles
	-4
	-3
	-2
	-1
	0
	gems
	super particles, damage trails, garbage particles
	1
	2
	3
	4
	5
	super freeze effects
--]]

local love = _G.love
local images = require "images"
local common = require "class.commons"
local Pic = require "pic"
local spairs = require "/helpers/utilities".spairs

local Particles = {}

function Particles:init(game)
	self.game = game
	self.NEXT_TINYSTAR, self.NEXT_STAR = 10, 42
	self.next_tinystar_frame, self.next_star_frame = 0, 0
	self:reset()
end

function Particles:update(dt)
	for _, particle_tbl in pairs(self.allParticles) do
		for _, particle in pairs(particle_tbl) do particle:update(dt) end
	end

	-- make the platform river stars
	if self.game.frame >= self.next_tinystar_frame then
		self.platformStar.generate(self.game, "TinyStar")
		self.next_tinystar_frame = self.next_tinystar_frame + self.NEXT_TINYSTAR
	end

	if self.game.frame >= self.next_star_frame then
		self.platformStar.generate(self.game, "Star")
		self.next_star_frame = self.next_star_frame + self.NEXT_STAR
	end
end

-- returns the number of particles in a specificed self.allParticles subtable.
function Particles:getNumber(particle_tbl, player)
	local num = 0
	if self.allParticles[particle_tbl] then
		for _, particle in pairs(self.allParticles[particle_tbl]) do
			if not player or particle.owner == player then
				num = num + 1
			end
		end
	else
		print("Erreur, invalid particle table requested")
		print(particle_tbl)
		print(self.allParticles[particle_tbl])
	end
	return num
end

-- increments the count: c_d is "created" or "destroyed",
-- p_type is "MP" or "Damage", player_num is 1 or 2
function Particles:incrementCount(c_d, p_type, player_num)
	self.count[c_d][p_type][player_num] = self.count[c_d][p_type][player_num] + 1
end

-- takes "created", "destroyed", or "onscreen"
function Particles:getCount(count_type, p_type, player_num)
	if count_type == "onscreen" then
		return self.count.created[p_type][player_num] - self.count.destroyed[p_type][player_num]
	end
	return self.count[count_type][p_type][player_num]
end

function Particles:clearCount()
	self.count.created.MP = {0, 0}
	self.count.created.Damage = {0, 0}
	self.count.created.Healing = {0, 0}
	self.count.created.Garbage = {0, 0}
	self.count.destroyed.MP = {0, 0}
	self.count.destroyed.Damage = {0, 0}
	self.count.destroyed.Healing = {0, 0}
	self.count.destroyed.Garbage = {0, 0}
end

-- an iterator which returns all matching instances
function Particles:getInstances(category, player_num, name)
	assert(category, "Category not provided!")
	assert(self.allParticles[category], "Category doesn't exist!")
	local instances, index = {}, 0
	for _, instance in pairs(self.allParticles[category]) do
		local player_ok = (not player_num) or instance.player_num == player_num
		local name_ok = (not name) or instance.name == name
		if name_ok and player_ok then instances[#instances+1] = instance end
	end

	return function()
		index = index + 1
		return instances[index]
	end
end

function Particles:reset()
	self.allParticles = {
		Damage = {},
		DamageTrail = {},
		Healing = {},
		HealingTrail = {},
		SuperParticles = {},
		GarbageParticles = {},
		PopParticles = {},
		ExplodingGem = {},
		ExplodingPlatform = {},
		PlatformTinyStar = {},
		PlatformStar = {},
		Dust = {},
		OverDust = {},
		UpGem = {},
		PlacedGem = {},
		GemImage = {},
		Words = {},
		WordEffects = {},
		CharEffects = {},
		SuperFreezeEffects = {},
		NotDrawnThruParticles = {}, -- drawn elsewhere e.g. attached to gem
	}
	self.count = {
		created = {
			MP = {0, 0},
			Damage = {0, 0},
			Healing = {0, 0},
			Garbage = {0, 0},
		},
		destroyed = {
			MP = {0, 0},
			Damage = {0, 0},
			Healing = {0, 0},
			Garbage = {0, 0},
		},
	}

	-- check to see if no_rush is being animated
	-- 0 no animation, 1 currently being animated, 2 mouse hovering over
	self.no_rush_check = {}
	for i = 1, self.game.grid.COLUMNS do self.no_rush_check[i] = 0 end
	self.next_tinystar_frame, self.next_star_frame = 0, 0
end

local function randomStandardColor()
	local colors = {"red", "blue", "green", "yellow"}
	return colors[math.random(#colors)]
end
-------------------------------------------------------------------------------
-- Damage particles generated when a player makes a match
local DamageParticle = {}
function DamageParticle:init(manager, gem, player_num)
	local image = images.lookup.particle_freq(gem.color)
	if not image then
		image = images.lookup.particle_freq(randomStandardColor())
	end
	Pic.init(
		self,
		manager.game,
		{x = gem.x, y = gem.y, image = image, transparency = 0}
	)
	self.player_num = player_num
	local counter = self.game.inits.ID.particle
	manager.allParticles.Damage[counter] = self
	self.manager = manager
end

function DamageParticle:remove()
	self.manager:incrementCount("destroyed", "Damage", self.player_num)
	self.manager.allParticles.Damage[self.ID] = nil
end

-- player.hand.damage is the damage before this round's match(es) is scored
-- player_num_override is to force ownership for a player, for animation only
function DamageParticle.generate(game, gem, delay_frames, force_max_alpha, player_num_override)
	local player_num = player_num_override or gem.player_num
	local gem_creator = game:playerByIndex(player_num)
	local player = gem_creator.enemy
	local frames_taken = 0

	-- calculate bezier curve
	local x1, y1 = gem.x, gem.y -- start
	local x4, y4 = player.hand[2].x, player.hand[2].y
	local dist = ((x4 - x1) ^ 2 + (y4 - y1) ^ 2) ^ 0.5
	local x3, y3 = 0.5 * (x1 + x4), 0.5 * (y1 + y4)

	for _ = 1, 3 do
		local created_particles = game.particles:getCount("created", "Damage", player_num)
		local final_loc = (player.hand.turn_start_damage + created_particles/3)/4 + 1
		local angle = math.random() * math.pi * 2
		local x2 = x1 + math.cos(angle) * dist * 0.5
		local y2 = y1 + math.sin(angle) * dist * 0.5
		local curve = love.math.newBezierCurve(x1, y1, x2, y2, x3, y3, x4, y4)

		-- create damage particle
		local p = common.instance(DamageParticle, game.particles, gem, player_num)
		p.force_max_alpha = force_max_alpha

		local duration = game.DAMAGE_PARTICLE_TO_PLATFORM_FRAMES + _ * 3
		local rotation = math.random() * 5
		p.final_loc_idx = math.min(5, math.floor(final_loc))

		-- second part of movement once it hits the platform
		local drop_y = player.hand[p.final_loc_idx].y
		local drop_duration = math.max((p.final_loc_idx - 2) * game.DAMAGE_PARTICLE_PER_DROP_FRAMES, 0)
		local drop_x = function() return player.hand:getx(p.y) end
		local exit_1 = function()
			player.hand[2].platform:screenshake(4)
		end
		local exit_2 = function()
			local platform = player.hand[p.final_loc_idx].platform
			if platform then platform:screenshake(6) end
		end

		if delay_frames then
			p:change{transparency = 0}
			p:wait(delay_frames)
			p:change{duration = 0, transparency = 1}
		end

		if drop_duration == 0 then
			p:change{
				duration = duration,
				rotation = rotation,
				curve = curve,
				exit_func = exit_2,
				remove = true,
			}
		else
			p:change{
				duration = duration,
				rotation = rotation,
				curve = curve,
				exit_func = exit_1,
			}
			p:change{
				duration = drop_duration,
				x = drop_x,
				y = drop_y,
				exit_func = exit_2,
				remove = true,
			}
		end

		-- create damage trails
		for i = 1, 3 do
			local trail = {
				duration = duration,
				gem = gem,
				rotation = rotation,
				curve = curve,
				scaling = 1.25 - 0.25 * i
			}
			if drop_duration > 0 then
				trail.drop_duration = drop_duration
				trail.drop_x = drop_x
				trail.drop_y = drop_y
			end

			game.particles._damageTrail.generate(
				game,
				trail,
				delay_frames + i * 2,
				force_max_alpha
			)
		end

		game.particles:incrementCount("created", "Damage", player_num)

		frames_taken = math.max(frames_taken, game.DAMAGE_PARTICLE_TO_PLATFORM_FRAMES + 9 + drop_duration)
	end

	return frames_taken
end

DamageParticle = common.class("DamageParticle", DamageParticle, Pic)

-------------------------------------------------------------------------------

local DamageTrailParticle = {}
function DamageTrailParticle:init(manager, gem)
	local image
	if gem:isDefaultColor() then
		image = images["particles_trail_" .. gem.color]
	else
		image = images["particles_trail_" .. randomStandardColor()]
	end
	Pic.init(self, manager.game, {x = gem.x, y = gem.y, image = image})
	local counter = self.game.inits.ID.particle
	manager.allParticles.DamageTrail[counter] = self
	self.manager = manager
end

function DamageTrailParticle:remove()
	self.manager.allParticles.DamageTrail[self.ID] = nil
end

function DamageTrailParticle.generate(game, trail, delay_frames, force_max_alpha)
	local p = common.instance(DamageTrailParticle, game.particles, trail.gem)
	p.particle_type = "DamageTrail"

	p.force_max_alpha = force_max_alpha

	if delay_frames then
		p:change{transparency = 0}
		p:wait(delay_frames)
		p:change{duration = 0, transparency = 1}
	 end

	if trail.drop_duration then
		p:change{
			duration = trail.duration,
			rotation = trail.rotation,
			curve = trail.curve,
		}
		p:change{
			duration = trail.drop_duration,
			x = trail.drop_x,
			y = trail.drop_y,
			remove = true,
		}
	else
		p:change{
			duration = trail.duration,
			rotation = trail.rotation,
			curve = trail.curve,
			remove = true,
		}
	end
end

DamageTrailParticle = common.class("DamageTrailParticle", DamageTrailParticle, Pic)

-------------------------------------------------------------------------------
-- particles for super meter generated when a gem is matched
local SuperParticle = {}
function SuperParticle:init(manager, x, y, image, player_num, color)
	Pic.init(self, manager.game, {x = x, y = y, image = image})
	self.player_num = player_num
	self.color = color
	local counter = self.game.inits.ID.particle
	manager.allParticles.SuperParticles[counter] = self
	self.manager = manager
end

function SuperParticle:remove()
	self.manager:incrementCount("destroyed", "MP", self.player_num)
	self.manager.allParticles.SuperParticles[self.ID] = nil
end

-- particles follow cubic Bezier curve from gem origin to super bar.
function SuperParticle.generate(game, gem, num_particles, delay_frames, force_max_alpha)
	local player = game:playerByIndex(gem.player_num)
	if not player.can_gain_super then
		print("Warning: player super gain disabled but SuperParticle.generate called")
		return
	end

	for _ = 1, num_particles do
		-- create bezier curve
		local x1, y1 = gem.x, gem.y -- start
		local x4, y4 = game.stage.super[gem.player_num].x, game.stage.super[gem.player_num].y -- end
		-- dist and angle vary the second point within a circle around the origin
		local dist = ((x4 - x1) ^ 2 + (y4 - y1) ^ 2) ^ 0.5
		local angle = math.random() * math.pi * 2
		local x2 = x1 + math.cos(angle) * dist * 0.2
		local y2 = y1 + math.sin(angle) * dist * 0.2
		local x3, y3 = 0.5 * (x1 + x4), 0.5 * (y1 + y4)
		local curve = love.math.newBezierCurve(x1, y1, x2, y2, x3, y3, x4, y4)

		local image
		-- create particle
		if gem:isDefaultColor() then
			image = images["particles_super_" .. gem.color]
		else
			image = images["particles_super_" .. randomStandardColor()]
		end

		local p = common.instance(
			SuperParticle,
			game.particles,
			gem.x,
			gem.y,
			image,
			gem.player_num,
			gem.color
		)
		game.particles:incrementCount("created", "MP", gem.player_num)

		p.force_max_alpha = force_max_alpha

		if delay_frames then
			p:change{transparency = 0}
			p:wait(delay_frames)
			p:change{duration = 0, transparency = 1}
		 end

		-- move particle
		local duration = (0.9 + 0.2 * math.random()) * 90
		p:change{
			duration = duration,
			curve = curve,
			easing = "inQuad",
			remove = true,
		}
	end
end

SuperParticle = common.class("SuperParticle", SuperParticle, Pic)

-------------------------------------------------------------------------------
-- Healing particles generated when a player makes a match
local HealingParticle = {}
function HealingParticle:init(manager, x, y, image, owner, particle_type)
	Pic.init(self, manager.game, {x = x, y = y, image = image})
	self.particle_type = particle_type
	self.owner = owner
	local counter = self.game.inits.ID.particle
	manager.allParticles[particle_type][counter] = self
	self.manager = manager
end

function HealingParticle:remove()
	if self.particle_type == "Healing" then
		self.manager:incrementCount("destroyed", "Healing", self.owner.player_num)
		self.manager.allParticles.Healing[self.ID] = nil
	else
		self.manager.allParticles.HealingTrail[self.ID] = nil
	end
end

-- Mandatory: game, x, y, owner
-- Optional: delay for delay frames, default 0
-- Optional: x_range, y_range (pixels +/- the x/y value. 100 = +/- 100)
function HealingParticle.generate(params)
	local game = params.game
	local x_range, y_range = params.x_range, params.y_range
	local owner = params.owner
	local delay = params.delay or 0

	for i = 1, 5 do
		-- calculate bezier curve
		local x, y = params.x, params.y
		if x_range then x = math.random(x + x_range, x - x_range) end
		if y_range then y = math.random(y + y_range, y - y_range) end

		local image = images.lookup.particle_freq("healing")
		local x4, y4 = owner.hand[i].x, owner.hand[i].y
		local dist = ((x4 - x) ^ 2 + (y4 - y) ^ 2) ^ 0.5
		local x3, y3 = 0.5 * (x + x4), 0.5 * (y + y4)
		local angle = math.random() * math.pi * 2
		local x2 = x + math.cos(angle) * dist * 0.5
		local y2 = y + math.sin(angle) * dist * 0.5
		local curve = love.math.newBezierCurve(x, y, x2, y2, x3, y3, x4, y4)

		-- create healing particle
		local p = common.instance(
			HealingParticle,
			game.particles,
			x,
			y,
			image,
			owner,
			"Healing"
		)
		local duration = game.DAMAGE_PARTICLE_TO_PLATFORM_FRAMES * 1.5 + math.random() * 12
		local rotation = math.random() * 5
		local exit_func = function()
			if owner.hand[i].platform then
				owner.hand[i].platform:healingGlow()
			end
		end

		if delay then
			p:change{transparency = 0}
			p:wait(delay)
			p:change{duration = 0, transparency = 1}
		end
		p:change{
			duration = duration,
			rotation = rotation,
			curve = curve,
			exit_func = exit_func,
			remove = true,
		}
		HealingParticle.generateTrail{
			game = game,
			x = x,
			y = y,
			owner = owner,
			delay = delay,
			curve = curve,
			duration = duration,
		}
		game.particles:incrementCount("created", "Healing", owner.player_num)
	end

	return 120
end

-- Mandatory: game, x, y, owner, curve, duration
-- Optional: delay for delay frames, default 0
function HealingParticle.generateTrail(params)
	local game = params.game
	local x, y = params.x, params.y
	local owner = params.owner
	local delay = params.delay or 0
	local curve = params.curve
	local duration = params.duration

	for i = 1, 3 do
		local trail_image = images.particles_trail_healing
		local trail = common.instance(
			HealingParticle,
			game.particles,
			x,
			y,
			trail_image,
			owner,
			"HealingTrail"
		)
		trail.scaling = 1.25 - 0.25 * i
		trail:change{transparency = 0}
		trail:wait(delay + i * 2)
		trail:change{duration = 0, transparency = 1}
		trail:change{duration = duration, curve = curve, remove = true}
	end
end

-- Mandatory: game, owner_platform
-- Twinkle effect around the platform when it arrives
function HealingParticle.generateTwinkle(game, platform, delay_frames)
	delay_frames = delay_frames or 0
	local stars_to_make = math.random(6, 9)
	for i = 1, stars_to_make do
		local image = images.lookup.particle_freq("healing")
		local x_change = platform.width * 1.5 * (math.random() - 0.5)
		local y_change = platform.height * 1.5 * (math.random() - 0.5)
		local x = platform.owner.hand[platform.hand_idx].x + x_change
		local y = platform.owner.hand[platform.hand_idx].y + y_change

		local p = common.instance(
			HealingParticle,
			game.particles,
			x,
			y,
			image,
			platform.owner,
			"HealingTrail"
		)
		p.scaling, p.transparency = 0, 0
		p:wait(delay_frames + (i - 1) * 12)
		p:change{duration = 0, transparency = 1}
		p:change{duration = 30, scaling = 1}
		p:change{duration = 30, scaling = 0, remove = true}
	end
end

HealingParticle = common.class("HealingParticle", HealingParticle, Pic)

-------------------------------------------------------------------------------
-- Garbage particles generated when a piece falls off a platform
local GarbageParticles = {}
function GarbageParticles:init(manager, gem)
	local image = images.lookup.particle_freq(gem.color)
	Pic.init(self, manager.game, {x = gem.x, y = gem.y, image = image})
	self.player_num = gem.player_num
	local counter = self.game.inits.ID.particle
	manager.allParticles.GarbageParticles[counter] = self
	self.manager = manager
end

function GarbageParticles:remove()
	self.manager:incrementCount("destroyed", "Garbage", self.player_num)
	self.manager.allParticles.GarbageParticles[self.ID] = nil
end

-- player.hand.damage is the damage before this round's match(es) is scored
function GarbageParticles.generate(game, gem, delay_frames)
	local grid = game.grid
	local player = game:playerByIndex(gem.player_num)

	local duration = 54 + game.particles:getNumber("GarbageParticles")
	-- calculate bezier curve
	for i in grid:cols(player.player_num) do
		local x1, y1 = gem.x, gem.y -- start
		local x4, y4 = grid.x[i], grid.y[grid.BOTTOM_ROW] -- end
		local dist = ((x4 - x1) ^ 2 + (y4 - y1) ^ 2) ^ 0.5
		local x3, y3 = 0.5 * (x1 + x4), 0.5 * (y1 + y4)

		local angle = math.random() * math.pi * 2
		local x2 = x1 + math.cos(angle) * dist * 0.5
		local y2 = y1 + math.sin(angle) * dist * 0.5
		local curve = love.math.newBezierCurve(x1, y1, x2, y2, x3, y3, x4, y4)

		-- create damage particle
		local p = common.instance(GarbageParticles, game.particles, gem)
		local rotation = math.random() * 5

		if delay_frames then
			p:change{transparency = 0}
			p:wait(delay_frames)
			p:change{duration = 0, transparency = 1}
		end
		p:change{
			duration = duration,
			rotation = rotation,
			curve = curve,
			remove = true,
		}

		-- create damage trails
		for j = 1, 3 do
			local trail = {
				duration = duration,
				gem = gem,
				rotation = rotation,
				curve = curve,
				scaling = 1.25 - 0.25 * j
			}

			game.particles._damageTrail.generate(
				game,
				trail,
				delay_frames + j * 2
			)
		end
		game.particles:incrementCount("created", "Garbage", gem.player_num)
	end

	delay_frames = delay_frames or 0
	return duration + delay_frames
end
GarbageParticles = common.class("GarbageParticles", GarbageParticles, Pic)

-------------------------------------------------------------------------------
-- When a match is made, this is the glow behind the gems
local PopParticles = {}
function PopParticles:init(params)
	local manager = params.manager
	Pic.init(
		self,
		manager.game,
		{x = params.x, y = params.y, image = params.image}
	)
	local counter = self.game.inits.ID.particle
	manager.allParticles.PopParticles[counter] = self
	self.manager = manager
end

function PopParticles:remove()
	self.manager.allParticles.PopParticles[self.ID] = nil
end

--[[ Mandatory game and either a gem or [x, y, image].
	Optional: delay by delay_frames
	Optional: glow_duration, for how long it stays at max glow
	Optiona: duration, animation duration --]]
function PopParticles.generate(params)
	local manager = params.game.particles
	local x = params.x or params.gem.x
	local y = params.y or params.gem.y
	local image = params.image
	if not image then
		if params.gem:isDefaultColor() then
			image = images["gems_pop_" .. params.gem.color]
		else
			image = params.gem.pop_particle_image or images.dummy
		end
	end

	local duration = params.duration or 30

	local p = common.instance(
		PopParticles,
		{manager = manager, x = x, y = y, image = image}
	)

	p.force_max_alpha = params.force_max_alpha

	if params.delay_frames then
		p:change{transparency = 0}
		p:wait(params.delay_frames)
		p:change{duration = 0, transparency = 1}
	end

	if params.glow_duration then p:wait(params.glow_duration) end
	p:change{duration = duration, transparency = 0, scaling = 4, remove = true}

	return duration + (params.glow_duration or 0)
end

--[[The same animation but in reverse. Used for garbage particle
	game, x, y, image: self-explanatory
	delay_frames is optional
--]]
function PopParticles.generateReversePop(params)
	local manager = params.game.particles
	local p = common.instance(
		PopParticles,
		{manager = manager, x = params.x, y = params.y, image = params.image}
	)

	p:change{duration = 0, transparency = 0, scaling = 4}
	if params.delay_frames then p:wait(params.delay_frames) end
	p:change{duration = 30, transparency = 1, scaling = 1, remove = true}
end

PopParticles = common.class("PopParticles", PopParticles, Pic)

-------------------------------------------------------------------------------
-- When a match is made, this is the white/grey overlay for the gems
local ExplodingGem = {}
function ExplodingGem:init(params)
	local manager = params.manager
	local gem = params.gem
	local x, y, image, transparency

	if gem then
		if gem.player_num == 0 or gem.player_num == 3 then
			if gem.player_num == 0 then
				print("Warning! player_num 0 gem destroyed!")
			end

			if gem:isDefaultColor() then
				image = images["gems_grey_" .. gem.color]
			else
				image = gem.grey_exploding_gem_image
				assert(image, "No grey_exploding_gem_image for custom gem")
			end
		else
			if gem:isDefaultColor() then
				image = images["gems_explode_" .. gem.color]
			else
				image = gem.exploding_gem_image
				assert(image, "No exploding_gem_image for custom gem")
			end
		end
		x, y, transparency = gem.x, gem.y, 0
	else
		x, y, image, transparency = params.x, params.y, params.image, params.transparency
	end

	Pic.init(
		self,
		manager.game,
		{x = x, y = y, image = image, transparency = transparency}
	)
	local counter = self.game.inits.ID.particle
	manager.allParticles.ExplodingGem[counter] = self
	self.manager = manager
end

function ExplodingGem:remove()
	self.manager.allParticles.ExplodingGem[self.ID] = nil
end

--[[ Mandatory: game, gem
	Optional:
	explode_frames - duration of exploding part, default game.GEM_EXPLODE_FRAMES
	glow_duration - duration of after-explosion part, default 0
	fade_frames - duration of fade part, default game.GEM_FADE_FRAMES
	shake: boolean for whether to bounce gem, used by garbage gem, default false
	delay_frames - amount of time to delay the start of animation
--]]
function ExplodingGem.generate(params)
	local game = params.game
	local gem = params.gem
	local explode_frames = params.explode_frames or game.GEM_EXPLODE_FRAMES
	local fade_frames = params.fade_frames or game.GEM_FADE_FRAMES

	local p = common.instance(ExplodingGem, {manager = game.particles, gem = gem})
	p.transparency = 0

	p.force_max_alpha = params.force_max_alpha

	if params.delay_frames then p:wait(params.delay_frames) end

	if params.shake then
		p:change{
			duration = explode_frames,
			scaling = 2,
			easing = "inBounce",
			transparency = 1,
		}
	else
		p:change{duration = explode_frames, transparency = 1}
	end

	if params.glow_duration then p:wait(params.glow_duration) end

	if gem.player_num == 0 or gem.player_num == 3 then
		p:change{duration = fade_frames, remove = true}
	else
		p:change{
			duration = fade_frames,
			transparency = 0,
			scaling = 2,
			remove = true,
		}
	end
end

--[[According to artist, "the gem appears glowy and fades down to normal color".
	Used for garbage particle. game, x, y, image: self-explanatory.
	delay_frames, duration are optional. --]]
function ExplodingGem.generateReverseExplode(params)
	local game = params.game
	local x, y, image = params.x, params.y, params.image
	local duration = params.duration or game.GEM_EXPLODE_FRAMES

	local p = common.instance(
		ExplodingGem,
		{manager = game.particles, x = x, y = y, image = image, transparency = 1}
	)

	if params.delay_frames then
		p:change{transparency = 0}
		p:wait(params.delay_frames)
		p:change{duration = 0, transparency = 1}
	end

	p:change{duration = duration, transparency = 0, remove = true}
	return duration
end

ExplodingGem = common.class("ExplodingGem", ExplodingGem, Pic)

-------------------------------------------------------------------------------
-- When a gem platform disappears, this is the explody parts
local ExplodingPlatform = {}
function ExplodingPlatform:init(manager, x, y, _image)
	Pic.init(self, manager.game, {x = x, y = y, image = _image})
	local counter = self.game.inits.ID.particle
	manager.allParticles.ExplodingPlatform[counter] = self
	self.manager = manager
end

function ExplodingPlatform:remove()
	self.manager.allParticles.ExplodingPlatform[self.ID] = nil
end

function ExplodingPlatform.generate(game, platform, delay_frames)
	local x, y = platform.x, platform.y
	local duration = game.EXPLODING_PLATFORM_FRAMES
	local width, height = game.stage.width, game.stage.height

	local moves = {
		{x = width * -0.2, y = height * -0.5,  rotation = -6},
		{x = width *  0.2, y = height * -0.5,  rotation =  6},
		{x = width * -0.2, y = height * -0.05, rotation = -6},
		{x = width *  0.2, y = height * -0.05, rotation =  6},
	}

	for i = 1, 4 do
		local todraw = images["ui_starpiece" .. i]
		local p = common.instance(
			ExplodingPlatform,
			game.particles,
			x,
			y,
			todraw
		)
		p.transparency = 2

		if delay_frames then
			p:change{transparency = 0}
			p:wait(delay_frames)
			p:change{duration = 0, transparency = 2}
		end

		local function y_func()
			return y + p.t * moves[i].y + p.t^2 * height
		end

		p:change{
			duration = duration,
			rotation = moves[i].rotation,
			x = x + moves[i].x,
			y = y_func,
			transparency = 0,
			scaling = 1.5,
			remove = true
		}
	end
end

ExplodingPlatform = common.class("ExplodingPlatform", ExplodingPlatform, Pic)

-------------------------------------------------------------------------------
--[[
	Generates the stars underneath the platforms. They follow a bezier curve
	for the first half, then become linear.
	star_type: either "Star" or "TinyStar"
 --]]
local PlatformStar = {}
function PlatformStar:init(manager, x, y, _image, particle_type)
	Pic.init(self, manager.game, {x = x, y = y, image = _image})
	local counter = self.game.inits.ID.particle
	manager.allParticles[particle_type][counter] = self
	self.manager = manager
	self.particle_type = particle_type
end

function PlatformStar:remove()
	self.manager.allParticles[self.particle_type][self.ID] = nil
end

function PlatformStar.generate(game, star_type)
	local stage = game.stage
	local left, right_min, right_max = 0.05, 0.2, 0.29 -- % of screen width for TinyStar
	if star_type == "Star" then
		left, right_min, right_max = 0.05, 0.21, 0.22
	end

	local y = stage.height
	local duration = 360
	local rotation = 0.03 * duration
	if star_type == "TinyStar" then rotation = 0.06 * duration end

	-- p1 star
	local todraw = images.lookup.platform_star(1, star_type == "TinyStar")
	local x = math.random(left * stage.width, right_max * stage.width)
	-- bezier curve for bottom half movement
	local curve_right_min = math.max(right_min * stage.width, x)
	local curve_right = math.random(curve_right_min, right_max * stage.width)
	local curve = love.math.newBezierCurve(
		x,
		y,
		curve_right,
		y * 0.75,
		curve_right,
		stage.y_mid
	)

	local p = common.instance(
		PlatformStar,
		game.particles,
		x,
		y,
		todraw,
		"Platform" .. star_type
	)
	p:change{
		duration = duration * 0.5,
		curve = curve,
		rotation = rotation * 0.5,
	}
	p:change{
		duration = duration * 0.2,
		y = stage.height * 0.3,
		rotation = rotation * 0.7,
	}
	p:change{
		duration = duration * 0.15,
		y = stage.height * 0.15,
		rotation = rotation * 0.85,
		transparency = 0,
		remove = true,
	}

	-- p2 star
	--[[local]] todraw = images.lookup.platform_star(2, star_type == "TinyStar")
	x = math.random((1-left) * stage.width, (1-right_max) * stage.width)
	-- bezier curve for bottom half movement
	curve_right_min = math.min((1-right_min) * stage.width, x)
	curve_right = math.random((1-right_max) * stage.width, curve_right_min)
	curve = love.math.newBezierCurve(
		x,
		y,
		curve_right,
		y * 0.75,
		curve_right,
		stage.y_mid
	)

	--[[local]] p = common.instance(
		PlatformStar,
		game.particles,
		x,
		y,
		todraw,
		"Platform" .. star_type
	)
	p:change{
		duration = duration * 0.5,
		curve = curve,
		rotation = -rotation * 0.5,
	}
	p:change{
		duration = duration * 0.2,
		y = stage.height * 0.3,
		rotation = -rotation * 0.7,
	}
	p:change{
		duration = duration * 0.15,
		y = stage.height * 0.15,
		rotation = -rotation * 0.85,
		transparency = 0,
		remove = true,
	}
end

PlatformStar = common.class("PlatformStar", PlatformStar, Pic)

-------------------------------------------------------------------------------
local Dust = {}
function Dust:init(manager, x, y, _image, particle_type)
	Pic.init(self, manager.game, {x = x, y = y, image = _image})
	local counter = self.game.inits.ID.particle
	manager.allParticles[particle_type][counter] = self
	self.manager = manager
	self.particle_type = particle_type
end

function Dust:remove()
	self.manager.allParticles[self.particle_type][self.ID] = nil
end

-- starburst along n lines, like when you capture a pokemon. Unused
function Dust.generateStarburst(game, gem, n)
	local x, y = gem.x, gem.y
	local duration = 10
	local rotation = 0.2
	for _ = 1, n do
		local todraw = images.lookup.smalldust(gem.color)
		local x_vel = (math.random() - 0.5) * 0.02 * game.stage.width
		local y_vel = (math.random() - 0.5) * 0.015 * game.stage.height

		for j = 1, math.random(1, 3) do
			local p = common.instance(
				Dust,
				game.particles,
				gem.x,
				gem.y,
				todraw,
				"OverDust"
			)
			p.RGB = {128, 128, 128}
			local x_func = function() return x + p.t * x_vel * j end
			local y_func = function() return y + p.t * y_vel * j end

			p:change{
				duration = duration,
				rotation = rotation,
				x = x_func,
				y = y_func,
				scaling = 1 + j * 0.2,
			}
			p:change{
				duration = duration * 3,
				transparency = 0,
				remove = true,
			}
		end
	end
end

-- yoshi-type star movement. generated when a gem lands
function Dust.generateYoshi(game, gem)
	local x, y = gem.x, gem.y + gem.height * 0.5
	local image = images.lookup.stardust(gem.color)
	local yoshi = {left = -1, right = 1}
	for _, sign in pairs(yoshi) do
		local p = common.instance(Dust, game.particles, x, y, image, "OverDust")
		p.scaling = 0.5
		p:change{
			duration = 30,
			x = x + game.stage.width * 0.05 * sign,
			y = y - game.stage.height * 0.02,
			rotation = sign,
			scaling = 0.8,
			easing = "outQuart",
		}
		p:change{
			duration = 30,
			scaling = 1,
			transparency = 0,
			rotation = 1.25 * sign,
			remove = true,
		}
	end
end

-- gravity-type fountain, called on clicking a gem
function Dust.generateFountain(game, x, y, color, n)
	local duration = 60
	local rotation = 1
	for i = 1, n do
		local todraw = images.lookup.smalldust(color)
		local p_type = (i % 2 == 1) and "Dust" or "OverDust"
		local x_vel = (math.random() - 0.5) * 0.1 * game.stage.width
		local y_vel = (math.random() + 1) * - 0.1 * game.stage.height
		local acc = 0.26 * game.stage.height

		local p = common.instance(Dust, game.particles, x, y, todraw, p_type)
		local x1 = x + x_vel
		local x2 = x + x_vel * 1.2
		local y_func = function()
			return y + p.t * y_vel + p.t^2 * acc
		end
		local y_func2 = function()
			return y + y_vel * (1 + p.t * 0.2) + acc * (1 + p.t * 0.2)^2
		end

		p:change{
			duration = duration,
			rotation = rotation,
			x = x1,
			y = y_func,
		}
		p:change{
			duration = duration * 0.2,
			rotation = rotation * 1.2,
			x = x2,
			y = y_func2,
			transparency = 0,
			remove = true,
		}
	end
end

--[[ called when a gem is destroyed (usually through a match)
	mandatory: game, either gem or [x, y, color]. [x, y, color] takes priority
	optional: num (#particles, default 24), duration (default 30),
		delay_frames, force_max_alpha, image
--]]
function Dust.generateBigFountain(params)
	local game = params.game
	local num = params.num or 24
	local x = params.x or params.gem.x
	local y = params.y or params.gem.y
	local color = params.color or params.gem.color
	local image = params.image or images.lookup.smalldust(color)
	local duration = params.duration or 30
	local rotation = duration / 60

	for i = 1, num do
		if not params.image then
			if color == "wild" then
				image = images.lookup.smalldust(color)
			elseif color == "none" then
				image = images.dummy
			end
		end
		local p_type = (i % 2 == 1) and "Dust" or "OverDust"
		local x_vel = (math.random() - 0.5) * 0.4 * game.stage.width
		local y_vel = (math.random() - 0.75) * 0.52 * game.stage.height
		local acc = 0.2 * game.stage.height

		local p = common.instance(Dust, game.particles, x, y, image, p_type)
		local x1 = x + x_vel
		local x2 = x + x_vel * 1.2
		local y_func = function()
			return y + p.t * y_vel + p.t^2 * acc
		end
		local y_func2 = function()
			return y + y_vel * (1 + p.t * 0.5) + acc * (1 + p.t * 0.5)^2
		end

		p.force_max_alpha = params.force_max_alpha

		if params.delay_frames then
			p:change{transparency = 0}
			p:wait(params.delay_frames)
			p:change{duration = 0, transparency = 1}
		end

		p:change{
			duration = duration,
			rotation = rotation,
			x = x1,
			y = y_func,
		}
		p:change{
			duration = duration * 0.5,
			rotation = rotation * 1.5,
			x = x2,
			y = y_func2,
			transparency = 0,
			remove = true,
		}
	end
end

--[[ A star fountain, like when a doublecast/rush landed in the holding area
	game: game instance (mandatory)
	gem: a gem instance (either this or {x, y, color} is mandatory)
	x, y: coordinates (either this or gem is mandatory)
	color: color of particles generated (either this or gem is mandatory)
	num: number of particles to generate. Default is 24
	x, y, color override gem if they are provided
	fast: if true, particles are faster. defaults to false
	delay: frames to delay the animation
--]]
function Dust.generateStarFountain(params)
	local game, gem, num = params.game, params.gem, params.num or 24
	local x = params.x or gem.x
	local y = params.y or gem.y
	local color = params.color or gem.color
	local duration = 120
	local rotation = 0.5
	local x_speed_mult = params.fast and 2 or 1
	local y_speed_mult = params.fast and 1.5 or 1
	local delay = params.delay

	for i = 1, num do
		local todraw = images.lookup.particle_freq(color)
		local p_type = (i % 2 == 1) and "Dust" or "OverDust"
		local x_vel = (math.random() - 0.5) * game.stage.width * x_speed_mult
		local y_vel = (math.random() - 0.75) * 2 * game.stage.height * y_speed_mult
		local acc = 3 * game.stage.height

		-- create star
		local p = common.instance(Dust, game.particles, x, y, todraw, p_type)
		local x1 = x + x_vel
		local y_func = function() return y + p.t * y_vel + p.t^2 * acc end

		if delay then
			p:change{transparency = 0}
			p:wait(delay)
			p:change{duration = 0, transparency = 1}
		end

		p:change{
			duration = duration,
			rotation = rotation,
			x = x1,
			y = y_func,
			remove = true,
		}

		-- create trails
		for frames = 1, 3 do
			local trail_image
			if color == "red"
			or color == "blue"
			or color == "green"
			or color == "yellow" then
				trail_image = images["particles_trail_" .. color]
			else
				trail_image = images["particles_trail_" .. randomStandardColor()]
			end

			local trail = common.instance(
				Dust,
				game.particles,
				x,
				y,
				trail_image,
				p_type
			)
			local trail_y = function()
				return y + trail.t * y_vel + trail.t^2 * acc
			end
			trail.scaling = 1.25 - (frames * 0.25)
			if delay then
				trail:change{transparency = 0}
				trail:wait(delay)
				trail:change{duration = 0, transparency = 1}
			end
			trail:wait(frames * 2)
			trail:change{
				duration = duration,
				rotation = rotation,
				x = x1,
				y = trail_y,
				remove = true,
			}
		end
	end
end

-- constant speed falling with no x-movement
function Dust.generateFalling(game, gem, x_drift, y_drift)
	local x, y = gem.x + x_drift, gem.y + y_drift
	local todraw = images.lookup.smalldust(gem.color, false)
	local rotation = 6
	local duration = 60
	local p_type = (math.random(1, 2) == 2) and "Dust" or "OverDust"

	local p = common.instance(Dust, game.particles, x, y, todraw, p_type)
	p:change{
		duration = duration,
		rotation = rotation,
		y = y + 0.13 * game.stage.height,
	}
	p:change{
		duration = duration * 0.3,
		rotation = rotation * 1.3,
		transparency = 0,
		y = y + 1.3 * (0.13 * game.stage.height),
		remove = true,
	}
end

-- generate the spinning dust from platforms
function Dust.generatePlatformSpin(game, x, y, speed)
	local todraw = images.lookup.smalldust("red")
	local rotation = 6
	local duration = 60

	local stage = game.stage
	local x_vel = (math.random() - 0.5) * 2 * stage.width * (speed + 0.2)
	local y_vel = (math.random() - 0.75) * 3 * stage.height * (speed + 0.2)
	local acc = stage.height * (speed + 0.2) * 3

	local p = common.instance(Dust, game.particles, x, y, todraw, "Dust")
	local function y_func()
		return y + p.t * y_vel + p.t^2 * acc
	end
	p:change{
		duration = duration,
		rotation = rotation,
		x = x + x_vel,
		y = y_func,
		transparency = 0,
		remove = true,
	}
end

--[[ The circular particles on garbage creation
	mandatory: game, either gem or [x, y, color]. [x, y, color] takes priority
	optional: num (number of particles), duration, delay_frames,
		force_max_alpha, image
--]]
function Dust.generateGarbageCircle(params)
	local game = params.game
	local num = params.num or 8
	local x_dest = params.x or params.gem.x
	local y_dest = params.y or params.gem.y
	local image = params.image or images.lookup.stardust(params.color or params.gem.color)
	local distance = images.GEM_WIDTH * (math.random() + 1)
	local fade_in_duration = 10
	local duration = (params.duration or game.GEM_EXPLODE_FRAMES) - fade_in_duration
	local rotation = duration / 60
	local p_type = "OverDust"

	for _ = 1, num do
		local angle = math.random() * math.pi * 2
		local x_start = distance * math.cos(angle) + x_dest
		local y_start = distance * math.sin(angle) + y_dest

		local p = common.instance(
			Dust,
			game.particles,
			x_start,
			y_start,
			image,
			p_type
		)
		p.force_max_alpha = params.force_max_alpha
		p.transparency = 0
		if params.delay_frames then p:wait(params.delay_frames) end
		p:change{
			duration = fade_in_duration,
			transparency = 1,
		}
		p:change{
			duration = duration,
			rotation = rotation,
			x = x_dest,
			y = y_dest,
			easing = "inCubic",
			remove = true,
		}
	end
end

--[[ An animation type for like, a leaf floating downwards.
	Takes mandatory arguments for: game, x, y, image, y_dist (in pixels)

	Takes optional arguments for:
	x_drift (in pixels, default is equal to y_distance)
	travel_duration (default is 180 frames)
	init_shoot_dist (in pixels, default is stage.height * 0.1)
	init_shoot_duration (default is 8 frames)
	init_shoot_type (default is "random", or else no shoot. Can add more later)
	init_shoot_easing (default is "outCubic" )
	swings (number of times it swings, default 5)
	fade_out_duration (default is 20 frames)
	delay: how many frames to delay the animation
	force_max_alpha

	Need all three of the following, to have image swapping:
	swap_image
	swap_tween - how to tween the swap: y_scaling, x_scaling
	swap_period - swap period of each swap
--]]
function Dust.generateLeafFloat(params)
	assert(params.game and params.x and params.y and params.image and params.y_dist,
		"Mandatory game/x/y/image/y_dist not provided!")

	local game = params.game
	local x = params.x
	local y = params.y
	local image = params.image
	local y_dist = params.y_dist
	local x_drift = params.x_drift or y_dist
	local travel_duration = (params.travel_duration or 180) *
		(1 + (math.random() - 0.5) * 0.5)
	local init_shoot_dist = params.init_shoot_dist or game.stage.height * 0.1
	local init_shoot_duration = params.init_shoot_duration or 8
	local init_shoot_type = params.init_shoot_type or "random"
	local init_shoot_easing = params.init_shoot_easing or "outCubic"
	local swings = params.swings or 5
	local fade_out_duration = params.fade_out_duration or 20
	local delay = params.delay or 0

	local p = common.instance(Dust, game.particles, x, y, image, "OverDust")

	p.force_max_alpha = params.force_max_alpha

	if delay > 0 then
		p:change{transparency = 0}
		p:wait(delay)
		p:change{duration = 0, transparency = 1}
	end

	local last_x, last_y = x, y

	if init_shoot_type == "random" then
		local angle = math.random() * math.pi * 2
		local init_x = init_shoot_dist * math.cos(angle) * math.random()
		local init_y = init_shoot_dist * math.sin(angle) * math.random()

		p:change{
			duration = init_shoot_duration,
			x = last_x + init_x,
			y = last_y + init_y,
			easing = init_shoot_easing,
		}

		last_x, last_y = last_x + init_x, last_y + init_y
	end

	local swing_duration = travel_duration / swings
	local y_per_swing = y_dist / (swings - 0.5)

	local sign = math.random() < 0.5 and 1 or -1

	local x_move = function()
		return x_drift * 1 + (math.random() - 0.5) * 0.2
	end

	local y_move = function()
		return y_per_swing * 1 + (math.random() - 0.5) * 0.2
	end

	local tween_type = function()
		local choices = {"inQuad", "linear", "inSine"}
		local rand = math.random(#choices)
		return choices[rand]
	end

	-- first swing
	local x1 = last_x
	local y1 = last_y
	local x2 = last_x + x_move() * sign * 0.5
	local y2 = last_y + y_move() * 0.5
	local x3 = last_x + x_move() * sign * 0.5
	local y3 = last_y - y_move() * 0.5
	local curve = love.math.newBezierCurve(x1, y1, x2, y2, x3, y3)

	p:change{
		duration = swing_duration,
		curve = curve,
		easing = tween_type(),
	}

	last_x, last_y = x3, y3

	-- intermediate swings
	for _ = 2, swings - 1 do
		sign = sign * -1
		x1 = last_x
		y1 = last_y
		x2 = last_x + x_move() * sign
		y2 = last_y + y_move() * 2
		x3 = last_x + x_move() * sign
		y3 = last_y + y_move()
		curve = love.math.newBezierCurve(x1, y1, x2, y2, x3, y3)

		p:change{
			duration = swing_duration,
			curve = curve,
			easing = tween_type(),
		}

		last_x, last_y = x3, y3
	end

	-- last swing
	sign = sign * -1
	x1 = last_x
	y1 = last_y
	x2 = last_x + x_move() * sign * 0.5
	y2 = last_y + y_move() * 2
	x3 = last_x + x_move() * sign * 0.5
	y3 = last_y + y_move()

	curve = love.math.newBezierCurve(x1, y1, x2, y2, x3, y3)

	p:change{
		duration = swing_duration,
		curve = curve,
		easing = tween_type(),
	}

	-- fadeout
	p:change{duration = fade_out_duration, transparency = 0, remove = true}


	-- custom update, if params.swap_image and params.swap_period provided
	if params.swap_image and params.swap_tween and params.swap_period then
		local tw = params.swap_tween
		p.tween_sign = -1 -- -1 for shrink, 1 for expand
		p.swap_image = params.swap_image
		p.tween_per_frame = 1 / params.swap_period
		p[tw] = 1

		-- "squishing" animation
		p.update = function(leaf, dt)
			Pic.update(leaf, dt)

			leaf[tw] = leaf[tw] + leaf.tween_sign * leaf.tween_per_frame

			if leaf[tw] <= 0 then
				leaf.tween_sign = 1
				leaf[tw] = 0
				local img = leaf.swap_image
				leaf.swap_image = leaf.image
				leaf:newImage(img)
			elseif leaf[tw] >= 1 then
				leaf.tween_sign = -1
				leaf[tw] = 1
				local img = leaf.swap_image
				leaf.swap_image = leaf.image
				leaf:newImage(img)
			end
		end
	end

	return delay + travel_duration + fade_out_duration
end

Dust = common.class("Dust", Dust, Pic)

-------------------------------------------------------------------------------
-- When a gem is placed in basin, make the gem effects for tweening offscreen.
local UpGem = {}
function UpGem:init(manager, gem)
	Pic.init(self, manager.game, {x = gem.x, y = gem.y, image = gem.image})
	local counter = self.game.inits.ID.particle
	manager.allParticles.UpGem[counter] = self
	self.gem = gem
	self.manager = manager
end

function UpGem:remove()
	self.manager.allParticles.UpGem[self.ID] = nil
end

function UpGem.generate(game, gem)
	local p = common.instance(UpGem, game.particles, gem)
	p:change{
		duration = 60,
		y = p.y - game.stage.height,
		easing = "inQuad",
		remove = true,
	}
end

-- Remove all gems at end of turn, whether they finished tweening or not
function UpGem.removeAll(manager)
	for _, v in pairs(manager.allParticles.UpGem) do v:remove() end
end

-- draw anything that's contained by the gem, too
function UpGem:draw()
	Pic.draw(self)
	self.gem:drawContainedItems{x = self.x, y = self.y}
end

UpGem = common.class("UpGem", UpGem, Pic)

-------------------------------------------------------------------------------
-- When a gem is placed in basin, this is the lighter gem in the holding area
-- to show where you placed it.
local PlacedGem = {}
function PlacedGem:init(manager, gem, y, row, place_type)
	Pic.init(
		self,
		manager.game,
		{x = gem.x, y = y, image = gem.image, transparency = 0.75}
	)
	local counter = self.game.inits.ID.particle
	manager.allParticles.PlacedGem[counter] = self
	self.manager = manager
	self.player_num = gem.player_num
	self.gem = gem
	self.row = row
	self.place_type = place_type
	self.tweened_down = false
	self.tweened_down_permanently = false
end

function PlacedGem:remove()
	self.manager.allParticles.PlacedGem[self.ID] = nil
end

function PlacedGem.generate(game, gem)
	-- We calculate the placedgem location based on the gem row
	local row, y, place_type
	if gem.row == 1 or gem.row == 2 then
	-- doublecast gem, goes in rows 7-8
		row = gem.row + 6
		place_type = "doublecast"
	elseif gem.row == 3 or gem.row == 4 then
	-- rush gem, goes in rows 9-10
		row = gem.row + 6
		place_type = "rush"
	elseif gem.row == 5 or gem.row == 6 then
	-- normal gem, goes in rows 7-8 (gets pushed to 11-12)
		row = gem.row + 2
		place_type = "normal"
	else
		print("Error, placedgem received a gem without a row")
	end
	y = game.grid.y[row]
	common.instance(PlacedGem, game.particles, gem, y, row, place_type)
end

-- In case of doublecast mouseover, we show it moved down
function PlacedGem:tweenDown(permanent)
	if not self.tweened_down then
		local destination = self.manager.game.grid.y[self.row + 4]
		self:change{duration = 18, y = destination, easing = "outBack"}
		self.tweened_down = true
	end
	if permanent then self.tweened_down_permanently = true end
end

-- If doublecast mouseover cancelled
function PlacedGem:tweenUp()
	if not self.tweened_down_permanently and self.tweened_down then
		local destination = self.manager.game.grid.y[self.row]
		self:change{y = destination}
		self.tweened_down = false
	end
end

-- Remove all gems at end of turn, whether they finished tweening or not
function PlacedGem.removeAll(manager)
	for _, v in pairs(manager.allParticles.PlacedGem) do v:remove() end
end

-- draw anything that's contained by the gem, too
function PlacedGem:draw()
	Pic.draw(self)
	self.gem:drawContainedItems{x = self.x, y = self.y}
end

PlacedGem = common.class("PlacedGem", PlacedGem, Pic)

-------------------------------------------------------------------------------
-- A temporary gem in the basin, shown when a gem has been removed from state
-- but still needs to be shown in the basin for display.
local GemImage = {}
function GemImage:init(manager, x, y, image)
	Pic.init(self, manager.game, {x = x, y = y, image = image})
	local counter = self.game.inits.ID.particle
	manager.allParticles.GemImage[counter] = self
	self.manager = manager
end

function GemImage:remove()
	self.manager.allParticles.GemImage[self.ID] = nil
end

function GemImage:draw()
	Pic.draw(self)

	if self.contained_items then
		for _, item in spairs(self.contained_items) do
			item:draw()
		end
	end
end

--[[ Takes mandatory game and duration arguments, and either
	1) gem: will use the x, y, image from the gem, (takes priority), or
	2) x, y, image arguments
	shake: whether to bounce, currently used for garbage gem animations
	delay_frames: how many frames to delay the animation
]]
function GemImage.generate(params)
	local game = params.game
	local x, y, image = params.x, params.y, params.image
	if params.gem then
		x, y, image = params.gem.x, params.gem.y, params.gem.image
	end

	local p = common.instance(GemImage, game.particles, x, y, image)

	p.force_max_alpha = params.force_max_alpha
	if params.gem then p.player_num = params.gem.player_num end

	if params.delay_frames then
		p:change{transparency = 0}
		p:wait(params.delay_frames)
		p:change{duration = 0, transparency = 1}
	end

	if params.shake then
		p:change{
			duration = params.duration,
			scaling = 2,
			easing = "inBounce",
			remove = true,
		}
	else
		p:change{duration = params.duration, remove = true}
	end

	-- add any items contained by the gem
	if params.gem and params.gem.contained_items then
		p.contained_items = {}
		for key, item in spairs(params.gem.contained_items) do
			p.contained_items[key] = item
		end
	end

	return params.duration + (params.delay_frames or 0)
end

function GemImage.removeAll(manager)
	for _, v in pairs(manager.allParticles.GemImage) do v:remove() end
end

GemImage = common.class("GemImage", GemImage, Pic)

-------------------------------------------------------------------------------
local WordEffects = {}
function WordEffects:init(manager, x, y, todraw)
	Pic.init(self, manager.game, {x = x, y = y, image = todraw})
	local counter = self.game.inits.ID.particle
	manager.allParticles.WordEffects[counter] = self
	self.manager = manager
end

function WordEffects:remove()
	self.manager.allParticles.WordEffects[self.ID] = nil
end

-- the glow cloud behind a doublecast piece.
-- called from anims.putPendingOnTop, and from anims.update
function WordEffects.generateDoublecastCloud(game, gem1, gem2, is_horizontal)
	local todraw = is_horizontal and images.words_doublecastcloudh or images.words_doublecastcloudv
	local p = common.instance(
		WordEffects,
		game.particles,
		(gem1.x + gem2.x) * 0.5,
		(gem1.y + gem2.y) * 0.5,
		todraw
	)
	p.transparency = 0
	p:change{duration = 20, transparency = 1, easing = "inCubic"}
	p.update = function(_self, dt)
		Pic.update(_self, dt)
		_self.x, _self.y = (gem1.x + gem2.x) * 0.5, (gem1.y + gem2.y) * 0.5
	end
	p.cloud = true
end

-- the glow cloud behind a rush piece.
-- called from anims.putPendingOnTop, and from anims.update
function WordEffects.generateRushCloud(game, gem1, gem2, is_horizontal)
	local PULSE_FRAMES = 6

	for _, gem in ipairs{gem1, gem2} do
		local p = common.instance(
			WordEffects,
			game.particles,
			gem.x,
			gem.y,
			images.ui_rushball
		)
		p.transparency = 0
		p:change{
			duration = 20,
			transparency = 1,
			easing = "inCubic",
		}

		p.update = function(_self, dt)
			Pic.update(_self, dt)
			_self.x, _self.y = gem.x, gem.y

			if _self:isStationary() then
				if _self.transparency == 1 then
					_self:change{duration = PULSE_FRAMES, transparency = 0.5}
				else
					_self:change{duration = PULSE_FRAMES, transparency = 1}
				end
			end
		end
		p.cloud = true
	end
end

-- falling stars accompanying Ready at start of match. Called from Words.Ready
function WordEffects.generateReadyParticle(game, size, x, y)
	local todraw = images.lookup.words_ready(size)
	local p = common.instance(WordEffects, game.particles, x, y, todraw)
	local y_func = function()
		return y + (p.t*3)^2 * 0.15 * game.stage.height
	end
	p:change{duration = 120, y = y_func, remove = true}
end

-- large gold star accompanying Go at start of match. Called from Words.Go
function WordEffects.generateGoStar(game, x, y, x_vel, y_vel, delay)
	local p = common.instance(
		WordEffects,
		game.particles,
		x,
		y,
		images.words_gostar
	)
	local y_func = function()
		return y + p.t * y_vel + (p.t)^2 * 3 * game.stage.height
	end
	if delay then
		p:change{transparency = 0}
		p:wait(delay)
		p:change{duration = 0, transparency = 1}
	end
	p:change{duration = 120, x = x + x_vel, y = y_func, remove = true}
end

function WordEffects:cloudExists()
	for _, effect in pairs(self.allParticles.WordEffects) do
		if effect.cloud then return true end
	end
	return false
end

function WordEffects.clear(manager)
	for _, effect in pairs(manager.allParticles.WordEffects) do
		if effect.cloud then effect:remove() end
	end
end

WordEffects = common.class("WordEffects", WordEffects, Pic)

-------------------------------------------------------------------------------
-- words! Doublecast, rush, go, and ready so far.
local Words = {}
function Words:init(manager, x, y, todraw)
	Pic.init(self, manager.game, {x = x, y = y, image = todraw})
	local counter = self.game.inits.ID.particle
	manager.allParticles.Words[counter] = self
	self.manager = manager
end

function Words:remove()
	self.manager.allParticles.Words[self.ID] = nil
end

function Words.generateDoublecast(game, player_num)
	local x = player_num == 1 and game.stage.width * 0.4 or game.stage.width * 0.6
	local y = game.stage.height * 0.3
	local todraw = images.words_doublecast
	local p = common.instance(Words, game.particles, x, y, todraw)
	p.scaling = 5
	p:change{duration = 60, scaling = 1, easing = "outQuart"}
	p:change{duration = 60, transparency = 0, easing = "inExpo", remove = true}
end

function Words.generateRush(game, player_num)
	local sign = player_num == 1 and 1 or -1
	local x = game.stage.width * (0.5 - sign * 0.6)
	local y = game.stage.height * 0.3
	local todraw = images.words_rush
	local p = common.instance(Words, game.particles, x, y, todraw)
	p.rotation = 0.25
	p:change{
		duration = 60,
		x = game.stage.width * (0.5 + sign * 0.2),
		rotation = 0,
		easing = "outBounce",
	}
	p:change{
		duration = 60,
		x = game.stage.width * (0.5 + sign * 0.9),
		rotation = 0.5,
		easing = "inBack",
		remove = true,
	}
end

function Words.generateReady(game, delay)
	local stage = game.stage
	local particles = game.particles
	local x = stage.width * -0.2
	local y = stage.height * 0.3
	local todraw = images.words_ready
	local h, w = todraw:getHeight(), todraw:getWidth()
	local p = common.instance(Words, particles, x, y, todraw)
	local generate_big = function()
		particles.wordEffects.generateReadyParticle(
			game,
			"large",
			p.x + (math.random() - 0.5) * w,
			stage.height * 0.3 + (math.random() - 0.5) * h
		)
	end
	local generate_small = function()
		particles.wordEffects.generateReadyParticle(
			game,
			"small",
			p.x + (math.random() - 0.5) * w,
			stage.height * 0.3 + (math.random() - 0.5) * h
		)
	end

	if delay then
		p:change{transparency = 0}
		p:wait(delay)
		p:change{duration = 0, transparency = 1}
	end

	p:change{
		duration = 60,
		x = 0.5 * stage.width,
		transparency = 2,
		during = {{5, 0, generate_big}, {2, 0, generate_small}},
		easing = "outElastic",
	}
	p:change{
		duration = 30,
		x = 1.4 * stage.width,
		transparency = 0,
		during = {{5, 0, generate_big}, {2, 0, generate_small}},
		easing = "inQuad",
		remove = true,
	}
end

function Words.generateGo(game, delay)
	local stage = game.stage
	local particles = game.particles

	local x = stage.width * 0.5
	local y = stage.height * 0.3
	local todraw = images.words_go

	local p = common.instance(Words, game.particles, x, y, todraw)
	if delay then
		p:change{transparency = 0}
		p:wait(delay)
		p:change{duration = 0, transparency = 1}
	end

	p.scaling = 0.1
	p:change{duration = 20, scaling = 1, easing = "outQuart"}
	p:wait(10)
	p:change{duration = 18, transparency = 0, easing = "linear", remove = true}

	particles.wordEffects.generateGoStar(
		game,
		x,
		y,
		stage.width * 0.25,
		stage.height * -0.4,
		delay
	)
	particles.wordEffects.generateGoStar(
		game,
		x,
		y,
		stage.width * 0.25,
		stage.height * -1.2,
		delay
	)
	particles.wordEffects.generateGoStar(
		game,
		x,
		y,
		stage.width * -0.25,
		stage.height * -0.4,
		delay
	)
	particles.wordEffects.generateGoStar(
		game,
		x,
		y,
		stage.width * -0.25,
		stage.height * -1.2,
		delay
	)
	particles.dust.generateStarFountain{
		game = game,
		x = x,
		y = y,
		color = "yellow",
		num = 48,
		fast = true,
		delay = delay,
	}
end

--[[ "no rush!" image that appears between 6th and 7th rows whenever a gem ends
	up in the 6th row of a column (either by dropping or by being raised to
	that level from garbage)
	takes the column it should be displayed in as an argument --]]
function Words.generateNoRush(game, column)
	if game.particles.no_rush_check[column] == 0 then
		game.particles.no_rush_check[column] = 1
		local grid = game.grid
		local x = grid.x[column]
		local y = (grid.y[grid.RUSH_ROW] + grid.y[grid.RUSH_ROW+1]) / 2
		local todraw = images.words_norush
		local p = common.instance(Words, game.particles, x, y, todraw)
		p:change{
			duration = 20,
			quad = {x = true, x_percentage = 1, x_anchor = 0.5},
		}
		p:change{duration = 40}
		local blink = 0
		local blinkCheck
		blinkCheck = function(b)
			local blink = b + 1
			if game.particles.no_rush_check[column] == 2 then
				blink = 2
				game.particles.no_rush_check[column] = 1
			end
			if blink ~= 3 then
				p:change{
					duration = 15,
					transparency = 0,
				}
				p:change{
					duration = 15,
					transparency = 1,
					exit_func = {blinkCheck, blink},
				}
			else
				p:change{
					duration = 15,
					transparency = 0,
					remove = true,
					exit_func = function()
						game.particles.no_rush_check[column] = 0
					end,
				}
			end
		end
		p:change{
			duration = 15,
			transparency = 0,
		}
		p:change{
			duration = 15,
			transparency = 1,
			exit_func = {blinkCheck, blink},
		}
	end
end

function Words.generateGameOverThanks(game)
	local x = game.stage.width * 0.5
	local y = game.stage.height * 0.4
	local todraw = images.words_gameoverthanks
	local p = common.instance(Words, game.particles, x, y, todraw)
	p:change{duration = 600, remove = true}
end

Words = common.class("Words", Words, Pic)
-------------------------------------------------------------------------------

local CharEffects = {}
--[[ required stuff in table: x, y, image
	optional stuff: layer, defaults to 1.
	1+: above the gems. Images are drawn with 1 at bottom, 5 on top
	0-: below the gems. Images are drawn with -4 at bottom, 0 on top
--]]
function CharEffects:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
end

function CharEffects:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

CharEffects = common.class("CharEffects", CharEffects, Pic)

-------------------------------------------------------------------------------

local SuperFreezeEffects = {}
-- required stuff in table: x, y, rotation, image
function SuperFreezeEffects:init(manager, tbl)
	tbl.draw_order = tbl.draw_order or 1
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.SuperFreezeEffects[counter] = self
	self.manager = manager
end

function SuperFreezeEffects:remove()
	self.manager.allParticles.SuperFreezeEffects[self.ID] = nil
end

function SuperFreezeEffects.generate(game, player, shadow_image, action_image, fuzz_image, delay_frames)
	local stage = game.stage
	local sign = player.player_num == 2 and -1 or 1

	local shadow = common.instance(SuperFreezeEffects, game.particles, {
		image = shadow_image,
		draw_order = 2,
		x = stage.width * (0.5 - sign * 0.7),
		y = stage.height * 0.5,
		h_flip = sign == -1,
		force_max_alpha = true,
	})
	if delay_frames then
		shadow:change{transparency = 0}
		shadow:wait(delay_frames)
		shadow:change{duration = 0, transparency = 1}
	end
	shadow:change{
		duration = 50,
		x = stage.width * (0.5 + 0.05 * sign),
		easing = "outQuart",
	}
	shadow:wait(15)
	shadow:change{duration = 5, transparency = 0, remove = true}

	local portrait = common.instance(SuperFreezeEffects, game.particles, {
		image = action_image,
		draw_order = 3,
		x = stage.width * (0.5 - sign * 0.7),
		y = stage.height * 0.5,
		h_flip = sign == -1,
		force_max_alpha = true,
	})
	if delay_frames then
		portrait:change{transparency = 0}
		portrait:wait(delay_frames)
		portrait:change{duration = 0, transparency = 1}
	end
	portrait:change{
		duration = 30,
		x = stage.width * (0.5 + 0.025 * sign),
		easing = "outQuart",
	}
	portrait:wait(35)
	portrait:change{duration = 5, transparency = 0, remove = true}

	local top_fuzz = common.instance(SuperFreezeEffects, game.particles, {
		image = fuzz_image,
		draw_order = 1,
		x = stage.width * 0.5,
		y = fuzz_image:getHeight() * -0.5,
		force_max_alpha = true,
	})
	if delay_frames then
		top_fuzz:change{transparency = 0}
		top_fuzz:wait(delay_frames)
		top_fuzz:change{duration = 0, transparency = 1}
	end
	top_fuzz:change{duration = 21, y = 0, easing = "outQuart"}
	top_fuzz:wait(50)
	top_fuzz:change{duration = 5, transparency = 0, remove = true}

	local bottom_fuzz = common.instance(SuperFreezeEffects, game.particles, {
		image = fuzz_image,
		draw_order = 1,
		x = stage.width * 0.5,
		y = fuzz_image:getHeight() * 0.5 + stage.height,
		force_max_alpha = true,
	})
	if delay_frames then
		bottom_fuzz:change{transparency = 0}
		bottom_fuzz:wait(delay_frames)
		bottom_fuzz:change{duration = 0, transparency = 1}
	end
	bottom_fuzz:change{duration = 21, y = stage.height, easing = "outQuart"}
	bottom_fuzz:wait(50)
	bottom_fuzz:change{duration = 5, transparency = 0, remove = true}
	game.sound:newSFX("superactivate")

	return 100
end

SuperFreezeEffects = common.class("SuperFreezeEffects", SuperFreezeEffects, Pic)

-------------------------------------------------------------------------------

Particles.damage = DamageParticle
Particles._damageTrail = DamageTrailParticle
Particles.healing = HealingParticle
Particles.superParticles = SuperParticle
Particles.popParticles = PopParticles
Particles.explodingGem = ExplodingGem
Particles.explodingPlatform = ExplodingPlatform
Particles.garbageParticles = GarbageParticles
Particles.platformStar = PlatformStar
Particles.dust = Dust
Particles.upGem = UpGem
Particles.placedGem = PlacedGem
Particles.gemImage = GemImage
Particles.words = Words
Particles.wordEffects = WordEffects
Particles.charEffects = CharEffects
Particles.superFreezeEffects = SuperFreezeEffects

return common.class("Particles", Particles)
