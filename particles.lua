local love = _G.love

local image = require 'image'
local common = require 'class.commons'
local Pic = require 'pic'
local tween = require 'tween'
local pairs = pairs

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
	self.count.created.Garbage = {0, 0}
	self.count.destroyed.MP = {0, 0}
	self.count.destroyed.Damage = {0, 0}
	self.count.destroyed.Garbage = {0, 0}
end

function Particles:reset()
	self.allParticles = {
		Damage = {},
		DamageTrail = {},
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
	}
	self.count = {
		created = {MP = {0, 0}, Damage = {0, 0}, Garbage = {0, 0}},
		destroyed = {MP = {0, 0}, Damage = {0, 0}, Garbage = {0, 0}},
	}

	--check to see if no_rush is being animated. 0 no animation, 1 currently being animated, 2 mouse hovering over.
	self.no_rush_check = {}
	for i = 1, self.game.grid.columns do self.no_rush_check[i] = 0 end
	self.next_tinystar_frame, self.next_star_frame = 0, 0
end

-------------------------------------------------------------------------------
-- Damage particles generated when a player makes a match
local DamageParticle = {}
function DamageParticle:init(manager, gem)
	local img = image.lookup.particle_freq.random(gem.color)
	Pic.init(self, manager.game, {x = gem.x, y = gem.y, image = img, transparency = 0})
	self.owner = gem.owner
	manager.allParticles.Damage[ID.particle] = self
	self.manager = manager
end

function DamageParticle:remove()
	self.manager:incrementCount("destroyed", "Damage", self.owner)
	self.manager.allParticles.Damage[self.ID] = nil
end

-- player.hand.damage is the damage before this round's match(es) is scored
function DamageParticle.generate(game, gem, delay_frames)
	local gem_creator = game:playerByIndex(gem.owner)
	local player = gem_creator.enemy

	-- calculate bezier curve
	local x1, y1 = gem.x, gem.y -- start
	local x4, y4 = player.hand[2].x, player.hand[2].y
	local dist = ((x4 - x1) ^ 2 + (y4 - y1) ^ 2) ^ 0.5
	local x3, y3 = 0.5 * (x1 + x4), 0.5 * (y1 + y4)

	for _ = 1, 3 do
		local created_particles = game.particles:getCount("created", "Damage", gem.owner)
		local final_loc = (player.hand.turn_start_damage + created_particles/3)/4 + 1
		local angle = math.random() * math.pi * 2
		local x2 = x1 + math.cos(angle) * dist * 0.5
		local y2 = y1 + math.sin(angle) * dist * 0.5
		local curve = love.math.newBezierCurve(x1, y1, x2, y2, x3, y3, x4, y4)

		-- create damage particle
		local p = common.instance(DamageParticle, game.particles, gem)
		local duration = game.DAMAGE_PARTICLE_TO_PLATFORM_FRAMES + math.random() * 12
		local rotation = math.random() * 5
		p.final_loc_idx = math.min(5, math.floor(final_loc))

		-- second part of movement once it hits the platform
		local drop_y = player.hand[p.final_loc_idx].y
		local drop_duration = math.max((p.final_loc_idx - 2) * game.DAMAGE_PARTICLE_PER_DROP_FRAMES, 0)
		local drop_x = function() return player.hand:getx(p.y) end
		local exit_1 = function() player.hand[2].platform:screenshake(4) end
		local exit_2 = function()
			local platform = player.hand[p.final_loc_idx].platform
			if platform then
				platform:screenshake(6)
			end
			p:remove()
		end

		if delay_frames then
			p:change{transparency = 0}
		 	p:wait(delay_frames)
		 	p:change{duration = 0, transparency = 255}
		end

		if drop_duration == 0 then
			p:change{duration = duration, rotation = rotation, curve = curve,
				exit = {exit_2}}
		else
			p:change{duration = duration, rotation = rotation, curve = curve, exit = {exit_1}}
			p:change{duration = drop_duration, x = drop_x, y = drop_y, exit = {exit_2}}
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
				trail.drop_duration, trail.drop_x, trail.drop_y = drop_duration, drop_x, drop_y
			end

			game.queue:add(i * 2, game.particles.damageTrail.generate, game, trail, delay_frames)
		end

		game.particles:incrementCount("created", "Damage", gem.owner)
	end
end

DamageParticle = common.class("DamageParticle", DamageParticle, Pic)

-------------------------------------------------------------------------------

local DamageTrailParticle = {}
function DamageTrailParticle:init(manager, gem)
	Pic.init(self, manager.game, {x = gem.x, y = gem.y, image = image.lookup.trail_particle[gem.color]})
	manager.allParticles.DamageTrail[ID.particle] = self
	self.manager = manager
end

function DamageTrailParticle:remove()
	self.manager.allParticles.DamageTrail[self.ID] = nil
end

function DamageTrailParticle.generate(game, trail, delay_frames)
	local p = common.instance(DamageTrailParticle, game.particles, trail.gem)
	p.particle_type = "DamageTrail"

	if delay_frames then
		p:change{transparency = 0}
	 	p:wait(delay_frames)
	 	p:change{duration = 0, transparency = 255}
	 end

	if trail.drop_duration then
		p:change{duration = trail.duration, rotation = trail.rotation, curve = trail.curve}
		p:change{duration = trail.drop_duration, x = trail.drop_x, y = trail.drop_y,
			exit = true}
	else
		p:change{duration = trail.duration, rotation = trail.rotation,
			curve = trail.curve, exit = true}
	end
end

DamageTrailParticle = common.class("DamageTrailParticle", DamageTrailParticle, Pic)

-------------------------------------------------------------------------------
-- particles for super meter generated when a gem is matched
local SuperParticle = {}
function SuperParticle:init(manager, gem)
	local img = image.lookup.super_particle[gem.color]
	Pic.init(self, manager.game, {x = gem.x, y = gem.y, image = img})
	self.owner = gem.owner
	manager.allParticles.SuperParticles[ID.particle] = self
	self.manager = manager
end

function SuperParticle:remove()
	self.manager:incrementCount("destroyed", "MP", self.owner)
	self.manager.allParticles.SuperParticles[self.ID] = nil
end

function SuperParticle.generate(game, gem, num_particles, delay_frames)
	-- particles follow cubic Bezier curve from gem origin to super bar.
	local player = game:playerByIndex(gem.owner)
	for _ = 1, num_particles do
		-- create bezier curve
		local x1, y1 = gem.x, gem.y -- start
		local x4, y4 = game.stage.super[player.ID].x, game.stage.super[player.ID].y -- end
		-- dist and angle vary the second point within a circle around the origin
		local dist = ((x4 - x1) ^ 2 + (y4 - y1) ^ 2) ^ 0.5
		local angle = math.random() * math.pi * 2
		local x2 = x1 + math.cos(angle) * dist * 0.2
		local y2 = y1 + math.sin(angle) * dist * 0.2
		local x3, y3 = 0.5 * (x1 + x4), 0.5 * (y1 + y4)
		local curve = love.math.newBezierCurve(x1, y1, x2, y2, x3, y3, x4, y4)

		-- create particle
		local p = common.instance(SuperParticle, game.particles, gem)
		game.particles:incrementCount("created", "MP", gem.owner)

		if delay_frames then
			p:change{transparency = 0}
		 	p:wait(delay_frames)
		 	p:change{duration = 0, transparency = 255}
		 end

		-- move particle
		local duration = (0.9 + 0.2 * math.random()) * 90
		p:change{duration = duration, curve = curve, easing = "inQuad", exit = true}
	end
end

SuperParticle = common.class("SuperParticle", SuperParticle, Pic)

-------------------------------------------------------------------------------
-- Garbage particles generated when a piece falls off a platform
local GarbageParticles = {}
function GarbageParticles:init(manager, gem)
	local img = image.lookup.particle_freq.random(gem.color)
	Pic.init(self, manager.game, {x = gem.x, y = gem.y, image = img})
	self.owner = gem.owner
	manager.allParticles.GarbageParticles[ID.particle] = self
	self.manager = manager
end

function GarbageParticles:remove()
	self.manager:incrementCount("destroyed", "Garbage", self.owner)
	self.manager.allParticles.GarbageParticles[self.ID] = nil
end

-- player.hand.damage is the damage before this round's match(es) is scored
function GarbageParticles.generate(game, gem, delay_frames)
	local player = game:playerByIndex(gem.owner)
	local start_col, end_col = 1, 4
	local end_row = game.grid.rows
	if player.ID == "P2" then start_col = 5 end_col = 8 end

	local duration = 54 + game.particles:getNumber("GarbageParticles")
	-- calculate bezier curve
	for i = start_col, end_col do
		local x1, y1 = gem.x, gem.y -- start
		local x4, y4 = game.grid.x[i], game.grid.y[end_row] -- end
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
		 	p:change{duration = 0, transparency = 255}
		end
		p:change{duration = duration, rotation = rotation, curve = curve, exit = true}

		-- create damage trails
		for i = 1, 3 do
			local trail = {
				duration = duration,
				gem = gem,
				rotation = rotation,
				curve = curve,
				scaling = 1.25 - 0.25 * i
			}

			game.queue:add(i * 2, game.particles.damageTrail.generate, game, trail, delay_frames)
		end
		game.particles:incrementCount("created", "Garbage", gem.owner)
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
	Pic.init(self, manager.game, {x = params.x, y = params.y, image = params.image})
	manager.allParticles.PopParticles[ID.particle] = self
	self.manager = manager
end

function PopParticles:remove()
	self.manager.allParticles.PopParticles[self.ID] = nil
end

--[[ Mandatory game and either a gem or [x, y, image].
	Optional: duration, delay by delay_frames --]]
function PopParticles.generate(params)
	local manager = params.game.particles
	local x = params.x or params.gem.x 
	local y = params.y or params.gem.y
	local img = params.image or image.lookup.pop_particle[params.gem.color]
	local duration = params.duration or 30

	local p = common.instance(PopParticles, {manager = manager, x = x, y = y, image = img})

	if params.delay_frames then
		p:change{transparency = 0}
	 	p:wait(params.delay_frames)
	 	p:change{duration = 0, transparency = 255}
	end

	p:change{duration = duration, transparency = 0, scaling = 4, exit = true}
	return duration
end

--[[The same animation but in reverse. Used for garbage particle
	game, x, y, image: self-explanatory
	delay_frames is optional
--]]
function PopParticles.generateReversePop(params)
	local manager = params.game.particles
	local p = common.instance(PopParticles, {manager = manager, x = params.x,
		y = params.y, image = params.image})

	p:change{duration = 0, transparency = 0, scaling = 4}
	if params.delay_frames then p:wait(delay_frames.params) end
	p:change{duration = 30, transparency = 255, scaling = 1, exit = true}
end

PopParticles = common.class("PopParticles", PopParticles, Pic)

-------------------------------------------------------------------------------
-- When a match is made, this is the white/grey overlay for the gems
local ExplodingGem = {}
function ExplodingGem:init(params)
	local manager = params.manager
	local gem = params.gem
	local x, y, img, transparency

	if gem then
		local create_grey_gems = gem.owner == 3
		local color = create_grey_gems and (gem.color .. "_grey") or gem.color
		x, y, img = gem.x, gem.y, image.lookup.gem_explode[color]
		transparency = 0
	else
		x, y, img = params.x, params.y, params.image
		transparency = params.transparency
	end

	Pic.init(self, manager.game, {x = x, y = y, image = img, transparency = transparency})
	manager.allParticles.ExplodingGem[ID.particle] = self
	self.manager = manager
end

function ExplodingGem:remove()
	self.manager.allParticles.ExplodingGem[self.ID] = nil
end

--[[ game and gem are mandatory
	explode_frames: optional duration of exploding part. Defaults to game.GEM_EXPLODE_FRAMES
	fade_frames: optional duration of fade part. Defaults to game.GEM_FADE_FRAMES
	shake: boolean for whether to bounce the gam. Used by garbage gem. Defaults to false.
	delay_frames: optional amount of time to delay the start of animation.
--]]
function ExplodingGem.generate(params)
	local game = params.game
	local gem = params.gem
	local explode_frames = params.explode_frames or game.GEM_EXPLODE_FRAMES
	local fade_frames = params.fade_frames or game.GEM_FADE_FRAMES

	local p = common.instance(ExplodingGem, {manager = game.particles, gem = gem})
	p.transparency = 0
	if params.delay_frames then p:wait(params.delay_frames) end

	if params.shake then
		p:change{duration = explode_frames, scaling = 2, easing = "inBounce", transparency = 255}
	else
		p:change{duration = explode_frames, transparency = 255}
	end

	if gem.owner == 3 then
		p:change{duration = fade_frames, exit = true}
	else
		p:change{duration = fade_frames, transparency = 0, scaling = 2,
			exit = true}
	end
end

--[[According to artist, "the gem appears glowy and fades down to normal color". 
	Used for garbage particle. game, x, y, image: self-explanatory.
	delay_frames, duration are optional. --]]
function ExplodingGem.generateReverseExplode(params)
	local game = params.game
	local x, y, img = params.x, params.y, params.image
	local duration = params.duration or game.GEM_EXPLODE_FRAMES

	local p = common.instance(ExplodingGem, {manager = game.particles, x = x,
		y = y, image = img, transparency = 255})

	if params.delay_frames then
		p:change{transparency = 0}
	 	p:wait(params.delay_frames)
	 	p:change{duration = 0, transparency = 255}
	end	

	p:change{duration = duration, transparency = 0, exit = true}
	return duration
end

ExplodingGem = common.class("ExplodingGem", ExplodingGem, Pic)

-------------------------------------------------------------------------------
-- When a gem platform disappears, this is the explody parts
local ExplodingPlatform = {}
function ExplodingPlatform:init(manager, x, y, _image)
	Pic.init(self, manager.game, {x = x, y = y, image = _image})
	manager.allParticles.ExplodingPlatform[ID.particle] = self
	self.manager = manager
end

function ExplodingPlatform:remove()
	self.manager.allParticles.ExplodingPlatform[self.ID] = nil
end

function ExplodingPlatform.generate(game, platform, delay_frames)
	local x, y = platform.x, platform.y
	local todraw = image.UI.starpiece
	local duration = game.EXPLODING_PLATFORM_FRAMES
	local width, height = game.stage.width, game.stage.height

	local moves = {
		{x = width * -0.2, y = height * -0.5,  rotation = -6},
		{x = width *  0.2, y = height * -0.5,  rotation =  6},
		{x = width * -0.2, y = height * -0.05, rotation = -6},
		{x = width *  0.2, y = height * -0.05, rotation =  6},
	}

	for i = 1, #todraw do
		local p = common.instance(ExplodingPlatform, game.particles, x, y, todraw[i])
		p.transparency = 510

		if delay_frames then
			p:change{transparency = 0}
		 	p:wait(delay_frames)
		 	p:change{duration = 0, transparency = 510}
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
			exit = true
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
	manager.allParticles[particle_type][ID.particle] = self
	self.manager = manager
	self.particle_type = particle_type
end

function PlatformStar:remove()
	self.manager.allParticles[self.particle_type][self.ID] = nil
end

function PlatformStar.generate(game, star_type)
	local stage = game.stage
	local left, right_min, right_max = 0.05, 0.2, 0.29 -- % of screen width for TinyStar
	if star_type == "Star" then left, right_min, right_max = 0.05, 0.21, 0.22 end

	local y = stage.height
	local duration = 360
	local rotation = 0.03 * duration
	if star_type == "TinyStar" then rotation = 0.06 * duration end

 	-- p1 star
	local star = star_type .. "P1"
	local rand = math.random(1, #image.lookup.platform_star[star])
	local todraw = image.lookup.platform_star[star][rand]
	local x = math.random(left * stage.width, right_max * stage.width)
	-- bezier curve for bottom half movement
	local curve_right_min = math.max(right_min * stage.width, x)
	local curve_right = math.random(curve_right_min, right_max * stage.width)
	local curve = love.math.newBezierCurve(x, y, curve_right, y * 0.75, curve_right, stage.y_mid)
	local p = common.instance(PlatformStar, game.particles, x, y, todraw, "Platform" .. star_type)
	--move functions
	p:change{duration = duration * 0.5, curve = curve, rotation = rotation * 0.5}
	p:change{duration = duration * 0.2, y = stage.height * 0.3, rotation = rotation * 0.7}
	p:change{duration = duration * 0.15, y = stage.height * 0.15, rotation = rotation * 0.85,
		transparency = 0, exit = true}

	-- p2 star
	star = star_type .. "P2"
	rand = math.random(1, #image.lookup.platform_star[star])
	todraw = image.lookup.platform_star[star][rand]
	x = math.random((1-left) * stage.width, (1-right_max) * stage.width)
	-- bezier curve for bottom half movement
	curve_right_min = math.min((1-right_min) * stage.width, x)
	curve_right = math.random((1-right_max) * stage.width, curve_right_min)
	curve = love.math.newBezierCurve(x, y, curve_right, y * 0.75, curve_right, stage.y_mid)
	p = common.instance(PlatformStar, game.particles, x, y, todraw, "Platform" .. star_type)
	--move functions
	p:change{duration = duration * 0.5, curve = curve, rotation = -rotation * 0.5}
	p:change{duration = duration * 0.2, y = stage.height * 0.3, rotation = -rotation * 0.7}
	p:change{duration = duration * 0.15, y = stage.height * 0.15, rotation = -rotation * 0.85,
		transparency = 0, exit = true}
end

PlatformStar = common.class("PlatformStar", PlatformStar, Pic)

-------------------------------------------------------------------------------
local Dust = {}
function Dust:init(manager, x, y, _image, particle_type)
	Pic.init(self, manager.game, {x = x, y = y, image = _image})
	manager.allParticles[particle_type][ID.particle] = self
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
	 	local todraw = image.lookup.dust.small(gem.color)
		local x_vel = (math.random() - 0.5) * 0.02 * game.stage.width
		local y_vel = (math.random() - 0.5) * 0.015 * game.stage.height

		for j = 1, math.random(1, 3) do
	 		local p = common.instance(Dust, game.particles, gem.x, gem.y, todraw, "OverDust")
	 		p.RGB = {128, 128, 128}
	 		local x_func = function() return x + p.t * x_vel * j end
	 		--local x_func2 = function() return x + x_vel * (1 + p.t * 0.2)end
	 		local y_func = function() return y + p.t * y_vel * j end
	 		--local y_func2 = function() return y + y_vel * (1 + p.t * 0.2) + acc * (1 + p.t * 0.2)^2 end

	 		p:change{duration = duration, rotation = rotation, x = x_func,
	 			y = y_func, scaling = 1 + j * 0.2}
 			p:change{duration = duration * 3, transparency = 0, exit = true}
	 	end
 	end
end

-- yoshi-type star movement. generated when a gem lands
function Dust.generateYoshi(game, gem)
	local x, y = gem.x, gem.y + gem.height * 0.5
	local img = image.lookup.dust.star(gem.color)
	local yoshi = {left = -1, right = 1}
	for _, sign in pairs(yoshi) do
		local p = common.instance(Dust, game.particles, x, y, img, "OverDust")
		p.scaling = 0.5
		p:change{x = x + game.stage.width * 0.05 * sign, y = y - game.stage.height * 0.02,
			duration = 30, rotation = sign, scaling = 0.8, easing = "outQuart"}
		p:change{duration = 30, scaling = 1, transparency = 0, rotation = 1.25 * sign, exit = true}
	end
end

-- gravity-type fountain, called on clicking a gem
function Dust.generateFountain(game, gem, n)
	local x, y = gem.x, gem.y
	local duration = 60
	local rotation = 1
 	for i = 1, n do
	 	local todraw = image.lookup.dust.small(gem.color)
	 	local p_type = (i % 2 == 1) and "Dust" or "OverDust"
	 	local x_vel = (math.random() - 0.5) * 0.1 * game.stage.width
	 	local y_vel = (math.random() + 1) * - 0.1 * game.stage.height
	 	local acc = 0.26 * game.stage.height

 		local p = common.instance(Dust, game.particles, gem.x, gem.y, todraw, p_type)
 		local x1 = x + x_vel
 		local x2 = x + x_vel * 1.2
 		local y_func = function() return y + p.t * y_vel + p.t^2 * acc end
 		local y_func2 = function() return y + y_vel * (1 + p.t * 0.2) + acc * (1 + p.t * 0.2)^2 end

 		p:change{duration = duration, rotation = rotation, x = x1, y = y_func}
 		p:change{duration = duration * 0.2, rotation = rotation * 1.2, x = x2,
 			y = y_func2, transparency = 0, exit = true}
 	end
end

--[[ called when a gem is destroyed (usually through a match)
	mandatory: game, either gem or [x, y, color]. [x, y, color] takes priority
	optional: num (#particles, default 24), duration (default 30), delay_frames
--]]
function Dust.generateBigFountain(params)
	local game = params.game
	local num = params.num or 24
	local x = params.x or params.gem.x
	local y = params.y or params.gem.y
	local img = image.lookup.dust.small(params.color or params.gem.color)
	local duration = params.duration or 30
	local rotation = duration / 60

 	for i = 1, num do
	 	local p_type = (i % 2 == 1) and "Dust" or "OverDust"
	 	local x_vel = (math.random() - 0.5) * 0.4 * game.stage.width
	 	local y_vel = (math.random() - 0.75) * 0.52 * game.stage.height
	 	local acc = 0.2 * game.stage.height

 		local p = common.instance(Dust, game.particles, x, y, img, p_type)
 		local x1 = x + x_vel
 		local x2 = x + x_vel * 1.2
 		local y_func = function() return y + p.t * y_vel + p.t^2 * acc end
 		local y_func2 = function() return y + y_vel * (1 + p.t * 0.5) + acc * (1 + p.t * 0.5)^2 end

		if params.delay_frames then
			p:change{transparency = 0}
		 	p:wait(params.delay_frames)
		 	p:change{duration = 0, transparency = 255}
		end

 		p:change{duration = duration, rotation = rotation, x = x1, y = y_func}
 		p:change{duration = duration * 0.5, rotation = rotation * 1.5, x = x2,
 			y = y_func2, transparency = 0, exit = true}
 	end
end

--[[ A star fountain, like when a doublecast/rush landed in the holding area
	game: game instance (mandatory)
	gem: a gem instance
	x, y: coordinates
	color: color of particles generated
	num: number of particles to generate. Default is 24
	x, y, color override gem if they are provided
	fast: if true, particles are faster. defaults to false
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
 	for i = 1, num do
 		local todraw = image.lookup.particle_freq.random(color)
	 	local p_type = (i % 2 == 1) and "Dust" or "OverDust"
	 	local x_vel = (math.random() - 0.5) * game.stage.width * x_speed_mult
	 	local y_vel = (math.random() - 0.75) * 2 * game.stage.height * y_speed_mult
	 	local acc = 3 * game.stage.height

	 	-- create star
 		local p = common.instance(Dust, game.particles, x, y, todraw, p_type)
 		local x1 = x + x_vel
 		local y_func = function() return y + p.t * y_vel + p.t^2 * acc end
 		p:change{duration = duration, rotation = rotation, x = x1, y = y_func, exit = true}

 		-- create trails
 		for frames = 1, 3 do
	 		local trail_image = image.lookup.trail_particle[color]
			local trail = common.instance(Dust, game.particles, x, y, trail_image, p_type)
			local trail_y = function() return y + trail.t * y_vel + trail.t^2 * acc end
			trail.scaling = 1.25 - (frames * 0.25)
			trail:wait(frames * 2)
			trail:change{duration = duration, rotation = rotation, x = x1, y = trail_y, exit = true}
 		end
 	end
end

-- constant speed falling with no x-movement
function Dust.generateFalling(game, gem, x_drift, y_drift)
	local x, y = gem.x + x_drift, gem.y + y_drift
 	local todraw = image.lookup.dust.small(gem.color, false)
 	local rotation = 6
 	local duration = 60
 	local p_type = (math.random(1, 2) == 2) and "Dust" or "OverDust"

 	local p = common.instance(Dust, game.particles, x, y, todraw, p_type)
 	p:change{duration = duration, rotation = rotation, y = y + 0.13 * game.stage.height}
 	p:change{duration = duration * 0.3, rotation = rotation * 1.3, transparency = 0,
 		y = y + 1.3 * (0.13 * game.stage.height), exit = true}
end

-- generate the spinning dust from platforms
function Dust.generatePlatformSpin(game, x, y, speed)
	local todraw = image.lookup.dust.small("red")
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
	p:change{duration = duration, rotation = rotation, x = x + x_vel, y = y_func, transparency = 0, exit = true}
end

--[[ The circular particles on garbage creation
	mandatory: game, either gem or [x, y, color]. [x, y, color] takes priority
	optional: num (number of particles), duration, delay_frames
--]]
function Dust.generateGarbageCircle(params)
	local game = params.game
	local num = params.num or 8
	local x_dest = params.x or params.gem.x
	local y_dest = params.y or params.gem.y
	local img = image.lookup.dust.star(params.color or params.gem.color)
	local distance = game.stage.gem_width * (math.random() + 1)
	local fade_in_duration = 10
	local duration = (params.duration or game.GEM_EXPLODE_FRAMES) - fade_in_duration
	local rotation = duration / 60
	local p_type = "OverDust"

 	for i = 1, num do
 		local angle = math.random() * math.pi * 2
 		local x_start = distance * math.cos(angle) + x_dest
 		local y_start = distance * math.sin(angle) + y_dest

 		local p = common.instance(Dust, game.particles, x_start, y_start, img, p_type)
		p.transparency = 0
		if params.delay_frames then p:wait(params.delay_frames) end
		p:change{duration = fade_in_duration, transparency = 255}
 		p:change{duration = duration, rotation = rotation, x = x_dest,
 			y = y_dest, easing = "inCubic", exit = true}
 	end
end
Dust = common.class("Dust", Dust, Pic)

-------------------------------------------------------------------------------
-- When a gem is placed in basin, make the gem effects for tweening offscreen.
local UpGem = {}
function UpGem:init(manager, gem)
	Pic.init(self, manager.game, {x = gem.x, y = gem.y, image = gem.image})
	manager.allParticles.UpGem[ID.particle] = self
	self.manager = manager
end

function UpGem:remove()
	self.manager.allParticles.UpGem[self.ID] = nil
end

function UpGem.generate(game, gem)
	local p = common.instance(UpGem, game.particles, gem)
	p:change{y = p.y - game.stage.height, duration = 60, easing = "inQuad", exit = true}
end

-- Remove all gems at end of turn, whether they finished tweening or not
function UpGem.removeAll(manager)
	for _, v in pairs(manager.allParticles.UpGem) do v:remove() end
end

UpGem = common.class("UpGem", UpGem, Pic)

-------------------------------------------------------------------------------
-- When a gem is placed in basin, this is the lighter gem in the holding area
-- to show where you placed it.
local PlacedGem = {}
function PlacedGem:init(manager, gem, y, row, place_type)
	Pic.init(self, manager.game, {x = gem.x, y = y, image = gem.image, transparency = 192})
	manager.allParticles.PlacedGem[ID.particle] = self
	self.manager = manager
	self.owner = gem.owner
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
	if gem.row == 1 or gem.row == 2 then -- doublecast gem, goes in rows 7-8
		row = gem.row + 6
		place_type = "doublecast"
	elseif gem.row == 3 or gem.row == 4 then -- rush gem, goes in rows 9-10
		row = gem.row + 6
		place_type = "rush"
	elseif gem.row == 5 or gem.row == 6 then -- normal gem, goes in rows 7-8 (gets pushed to 11-12)
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

PlacedGem = common.class("PlacedGem", PlacedGem, Pic)

-------------------------------------------------------------------------------
-- A temporary gem in the basin, shown when a gem has been removed from state
-- but still needs to be shown in the basin for display.
local GemImage = {}
function GemImage:init(manager, x, y, image)
	Pic.init(self, manager.game, {x = x, y = y, image = image})
	manager.allParticles.GemImage[ID.particle] = self
	self.manager = manager
end

function GemImage:remove()
	self.manager.allParticles.GemImage[self.ID] = nil
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
	if params.gem then x, y, image = params.gem.x, params.gem.y, params.gem.image end

	local p = common.instance(GemImage, game.particles, x, y, image)
	if params.delay_frames then
		p:change{transparency = 0}
	 	p:wait(params.delay_frames)
	 	p:change{duration = 0, transparency = 255}
	end

	if params.shake then
		p:change{duration = params.duration, scaling = 2, easing = "inBounce", exit = true}
	else
		p:change{duration = params.duration, exit = true}
	end
end

function GemImage.removeAll(manager)
	for _, v in pairs(manager.allParticles.GemImage) do v:remove() end
end

GemImage = common.class("GemImage", GemImage, Pic)

-------------------------------------------------------------------------------
local WordEffects = {}
function WordEffects:init(manager, x, y, todraw)
	Pic.init(self, manager.game, {x = x, y = y, image = todraw})
	manager.allParticles.WordEffects[ID.particle] = self
	self.manager = manager
end

function WordEffects:remove()
	self.manager.allParticles.WordEffects[self.ID] = nil
end

-- the glow cloud behind a doublecast piece.
-- called from anims.putPendingOnTop, and from anims.update
function WordEffects.generateDoublecastCloud(game, gem1, gem2, horizontal)
	local todraw = horizontal and image.words.doublecast_cloud_h or image.words.doublecast_cloud_v
	local p = common.instance(WordEffects, game.particles, (gem1.x + gem2.x) * 0.5, (gem1.y + gem2.y) * 0.5, todraw)
	p.transparency = 0
	p:change{duration = 20, transparency = 255, easing = "inCubic"}
	p.update = function(_self, dt)
		Pic.update(_self, dt)
		_self.x, _self.y = (gem1.x + gem2.x) * 0.5, (gem1.y + gem2.y) * 0.5
	end
	p.cloud = true
end

-- the glow cloud behind a rush piece.
-- called from anims.putPendingOnTop, and from anims.update
function WordEffects.generateRushCloud(game, gem1, gem2, horizontal)
	local todraw = horizontal and image.words.rush_cloud_h or image.words.rush_cloud_v
	local p = common.instance(WordEffects, game.particles, (gem1.x + gem2.x) * 0.5, (gem1.y + gem2.y) * 0.5, todraw)
	p.transparency = 0
	p:change{duration = 20, transparency = 255, easing = "inCubic"}
	p:change{duration = 600, during = {8, 0, WordEffects.generateRushParticle, game, gem1, gem2, horizontal}}
	p.update = function(_self, dt)
		Pic.update(_self, dt)
		_self.x, _self.y = (gem1.x + gem2.x) * 0.5, (gem1.y + gem2.y) * 0.5
	end
	p.cloud = true
end

-- the sparks coming out from the rush cloud.
-- called from WordEffects.generateRushCloud
function WordEffects.generateRushParticle(game, gem1, gem2)
	local horizontal = gem1.row == gem2.row
	local todraw = image.words.rush_particle
	local x, y = (gem1.x + gem2.x) * 0.5, (gem1.y + gem2.y) * 0.5
	local x_drift, y_adj
	if horizontal then
		x_drift = (math.random() - 0.5) * image.GEM_WIDTH * 2
		y_adj = -image.GEM_HEIGHT * 0.5
	else
		x_drift = (math.random() - 0.5) * image.GEM_WIDTH
		y_adj = -image.GEM_HEIGHT
	end

	local p = common.instance(WordEffects, game.particles, x + x_drift, y + y_adj, todraw)
	p.rotation = (x_drift / image.GEM_WIDTH) / (math.pi * 2)
	p:change{duration = 18, scaling = 0.7, exit = true}
end

-- falling stars accompanying Ready at start of match. Called from Words.Ready
function WordEffects.generateReadyParticle(game, size, x, y)
	local todraw = image.lookup.words_ready(size)
	local p = common.instance(WordEffects, game.particles, x, y, todraw)
	local y_func = function() return y + (p.t*3)^2 * 0.15 * game.stage.height end
	p:change{duration = 120, y = y_func, exit = true}
end

-- large gold star accompanying Go at start of match. Called from Words.Go
function WordEffects.generateGoStar(game, x, y, x_vel, y_vel)
	local p = common.instance(WordEffects, game.particles, x, y, image.words.go_star)
	local y_func = function() return y + p.t * y_vel + (p.t)^2 * 3 * game.stage.height end
	p:change{duration = 120, x = x + x_vel, y = y_func, exit = true}
end

-- DoublecastCloud, RushCloud, RushParticle, ReadyParticle, GoStar
function WordEffects.generate(game, effect_type, ...)
	local particle = {
		DoublecastCloud = WordEffects.generateDoublecastCloud,
		RushCloud = WordEffects.generateRushCloud,
		RushParticle = WordEffects.generateRushParticle,
		ReadyParticle = WordEffects.generateReadyParticle,
		GoStar = WordEffects.generateGoStar,
	}
	particle[effect_type](game, ...)
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



-------------------------------------------------------------------------------
-- words! Doublecast, rush, go, and ready so far.
local Words = {}
function Words:init(manager, x, y, todraw)
	Pic.init(self, manager.game, {x = x, y = y, image = todraw})
	manager.allParticles.Words[ID.particle] = self
	self.manager = manager
end

function Words:remove()
	self.manager.allParticles.Words[self.ID] = nil
end

function Words.generateDoublecast(game, player_num)
	local x = player_num == 1 and game.stage.width * 0.4 or game.stage.width * 0.6
	local y = game.stage.height * 0.3
	local todraw = image.words.doublecast
	local p = common.instance(Words, game.particles, x, y, todraw)
	p.scaling = 5
	p:change{duration = 60, scaling = 1, easing = "outQuart"}
	p:change{duration = 60, transparency = 0, easing = "inExpo", exit = true}
end

function Words.generateRush(game, player_num)
	local sign = player_num == 1 and 1 or -1
	local x = game.stage.width * (0.5 - sign * 0.6)
	local y = game.stage.height * 0.3
	local todraw = image.words.rush
	local p = common.instance(Words, game.particles, x, y, todraw)
	p.rotation = 0.25
	p:change{duration = 60, x = game.stage.width * (0.5 + sign * 0.2), rotation = 0, easing = "outBounce"}
	p:change{duration = 60, x = game.stage.width * (0.5 + sign * 0.9), rotation = 0.5, easing = "inBack", exit = true}
end

function Words.generateReady(game)
	local stage = game.stage
	local particles = game.particles
	local x = stage.width * -0.2
	local y = stage.height * 0.3
	local todraw = image.words.ready
	local h, w = todraw:getHeight(), todraw:getWidth()
	local p = common.instance(Words, particles, x, y, todraw)
	local generate_big = function()
		particles.wordEffects.generateReadyParticle(game, "large",
				p.x + (math.random()-0.5)*w, stage.height*0.3 + (math.random()-0.5)*h)
	end
	local generate_small = function()
		particles.wordEffects.generateReadyParticle(game, "small",
			p.x + (math.random()-0.5)*w, stage.height*0.3 + (math.random()-0.5)*h)
	end
	p:change{duration = 60, x = 0.5 * stage.width, transparency = 510,
		during = {{5, 0, generate_big}, {2, 0, generate_small}}, easing = "outElastic"}
	p:change{duration = 30, x = 1.4 * stage.width, transparency = 0,
		during = {{5, 0, generate_big}, {2, 0, generate_small}}, easing = "inQuad", exit = true}
end

function Words.generateGo(game)
	local stage = game.stage
	local x = stage.width * 0.5
	local y = stage.height * 0.3
	local todraw = image.words.go
	local p = common.instance(Words, game.particles, x, y, todraw)
	p.scaling = 0.1
	p:change{duration = 20, scaling = 1, easing = "outQuart"}
	p:wait(10)
	p:change{duration = 18, transparency = 0, easing = "linear", exit = true}

	local particles = game.particles
	particles.wordEffects.generateGoStar(game, x, y, stage.width * 0.25, stage.height * -0.4)
	particles.wordEffects.generateGoStar(game, x, y, stage.width * 0.25, stage.height * -1.2)
	particles.wordEffects.generateGoStar(game, x, y, stage.width * -0.25, stage.height * -0.4)
	particles.wordEffects.generateGoStar(game, x, y, stage.width * -0.25, stage.height * -1.2)
	for i = 1, 51, 10 do
		game.queue:add(i, particles.dust.generateStarFountain, {game = game, x = x,
			y = y, color = "yellow", num = 48, fast = true})
	end
end

--[[ "no rush!" image that appears between 6th and 7th rows whenever a gem ends up in the 
	6th row of a column (either by dropping or by being raised to that level from garbage)
	takes the column it should be displayed in as an argument --]]
function Words.generateNoRush(game, column)
	if game.particles.no_rush_check[column] == 0 then
		game.particles.no_rush_check[column] = 1
		local grid = game.grid
		local x = grid.x[column]
		local y = (grid.y[grid.RUSH_ROW] + grid.y[grid.RUSH_ROW+1]) / 2
		local todraw = image.words.no_rush_one_column
		local p = common.instance(Words, game.particles, x, y, todraw)
		p:change{duration = 20, quad = {x = true, x_percentage = 1, x_anchor = 0.5}}
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
				
				p:change{duration = 15, transparency = 0}
				p:change{duration = 15, transparency = 255, exit = {blinkCheck, blink}}
			else
				p:change{duration = 15, transparency = 0, exit = {function() game.particles.no_rush_check[column] = 0 end}}
				p:change{duration = 1, exit = true}
			end
		end
		p:change{duration = 15, transparency = 0}
		p:change{duration = 15, transparency = 255, exit = {blinkCheck, blink}}	
	end
end

function Words.generateGameOverThanks(game)
	local x = game.stage.width * 0.5
	local y = game.stage.height * 0.4
	local todraw = image.words.gameoverthanks
	local p = common.instance(Words, game.particles, x, y, todraw)
	p:change{duration = 600, exit = true}
end

Words = common.class("Words", Words, Pic)
-------------------------------------------------------------------------------

local CharEffects = {}
-- required stuff in table: x, y, image
function CharEffects:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	manager.allParticles.CharEffects[ID.particle] = self
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
	manager.allParticles.SuperFreezeEffects[ID.particle] = self
	self.manager = manager
end

function SuperFreezeEffects:remove()
	self.manager.allParticles.SuperFreezeEffects[self.ID] = nil
end

SuperFreezeEffects = common.class("SuperFreezeEffects", SuperFreezeEffects, Pic)

-------------------------------------------------------------------------------

Particles.damage = DamageParticle
Particles.damageTrail = DamageTrailParticle
Particles.superParticles = SuperParticle
Particles.popParticles = PopParticles
Particles.explodingGem = ExplodingGem
Particles.explodingPlatform = ExplodingPlatform
Particles.garbageParticles = GarbageParticles
Particles.garbageTrail = GarbageTrail
Particles.platformStar = PlatformStar
Particles.dust = Dust
--Particles.overDust = OverDust
Particles.upGem = UpGem
Particles.placedGem = PlacedGem
Particles.gemImage = GemImage
Particles.words = Words
Particles.wordEffects = WordEffects
Particles.charEffects = CharEffects
Particles.superFreezeEffects = SuperFreezeEffects

return common.class("Particles", Particles)
