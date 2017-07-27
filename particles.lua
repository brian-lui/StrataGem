local image = require 'image'
local class = require 'middleclass'
local stage
local pic = require 'pic'
local tween = require 'tween'
local pairs = pairs

local particles = class("Particles")

function particles:initialize(_stage)
	stage = _stage
	self.count = {
		created = {MP = {0, 0}, Damage = {0, 0}},
		destroyed = {MP = {0, 0}, Damage = {0, 0}},
	}
end

function particles:update(dt)
	for _, particle_tbl in pairs(AllParticles) do
		for _, particle in pairs(particle_tbl) do
			particle:update(dt)
		end
	end
end

-- returns the number of particles in a specificed AllParticles table.
function particles:getNumber(particle_tbl, player)
	local num = 0
	if AllParticles[particle_tbl] then
		if player then
			for _, particle in pairs(AllParticles[particle_tbl]) do
				if particle.owner == player then num = num + 1 end
			end
		else
			for _, particle in pairs(AllParticles[particle_tbl]) do	num = num + 1	end
		end
	else
		print("Erreur, invalid particle table requested")
		print(particle_tbl)
		print(AllParticles[particle_tbl])
	end
	return num
end

-- increments the count: c_d is "created" or "destroyed", 
-- p_type is "MP" or "Damage", player_num is 1 or 2
function particles:incrementCount(c_d, p_type, player_num)
	self.count[c_d][p_type][player_num] = self.count[c_d][p_type][player_num] + 1
end

-- takes "created", "destroyed" or "onscreen"
function particles:getCount(count_type, p_type, player_num)
	if count_type == "onscreen" then
		return self.count.created[p_type][player_num] - self.count.destroyed[p_type][player_num]
	else
		return self.count[count_type][p_type][player_num]
	end
end

-- called at end of turn
function particles:clearCount()
	self.count.created.MP = {0, 0}
	self.count.created.Damage = {0, 0}
	self.count.destroyed.MP = {0, 0}
	self.count.destroyed.Damage = {0, 0}
end

-- initialize the global "AllParticles" and empty it
-- Please refactor this especially DamageParticlesCount
function particles:reset()
	AllParticles = {
		Damage = {},
		DamageTrail = {},
		SuperParticles = {},
		Pop = {},
		ExplodingGem = {},
		ExplodingPlatform = {},
		PlatformTinyStar = {},
		PlatformStar = {},
		Dust = {},
		OverDust = {},
		UpGem = {},
		Words = {},
		WordEffects = {},
		PieEffects = {},
		CharEffects = {},
		SuperFreezeEffects = {},
	}
end

-------------------------------------------------------------------------------
-- Damage particles generated when a player makes a match
local DamageParticle = class('DamageParticle', pic)
DamageParticle.DAMAGE_DROP_SPEED = window.height / 192	-- pixels for damage particles after reaching platform
function DamageParticle:initialize(gem)
	local img = image.lookup.particle_freq.random(gem.color)
	pic.initialize(self, {x = gem.x, y = gem.y, image = img})
	self.owner = gem.owner
	AllParticles.Damage[ID.particle] = self
end

function DamageParticle:remove()
	game.particles:incrementCount("destroyed", "Damage", self.owner)
	AllParticles.Damage[self.ID] = nil
end

-- player.hand.damage is the damage before this round's match(es) is scored
function DamageParticle:generate(gem)
	local owner_lookup = {p2, p1, nil} -- send to enemy
	local player = owner_lookup[gem.owner]
	local full_segments = math.floor(player.hand.damage / 4)

	-- calculate bezier curve
	local x1, y1 = gem.x, gem.y -- start
	local x4, y4 = player.hand[2].x, player.hand[2].y
	local dist = ((x4 - x1) ^ 2 + (y4 - y1) ^ 2) ^ 0.5
	local x3, y3 = 0.5 * (x1 + x4), 0.5 * (y1 + y4)

	for i = 1, 3 do
		local created_particles = game.particles:getCount("created", "Damage", gem.owner)
		local final_loc = (player.hand.turn_start_damage + created_particles/3) * 0.25 + 1
		local angle = math.random() * math.pi * 2
		local x2 = x1 + math.cos(angle) * dist * 0.5
		local y2 = y1 + math.sin(angle) * dist * 0.5
		local curve = love.math.newBezierCurve(x1, y1, x2, y2, x3, y3, x4, y4)

		-- create damage particle
		local p = self:new(gem)
		local duration = 54 + math.random() * 12
		local rotation = math.random() * 5
		p.final_loc_idx = math.min(math.floor(final_loc), 5)

		-- second part of movement once it hits the platform
		local drop_y = player.hand[p.final_loc_idx].y
		local drop_duration = math.max((drop_y - player.hand[2].y) / self.DAMAGE_DROP_SPEED, 0)
		local drop_x = function() return player.hand:getx(p.y) end
		local exit_1 = function() player.hand[2].platform:screenshake(4) end
		local exit_2 = function()
			if player.hand[p.final_loc_idx].platform then
				player.hand[p.final_loc_idx].platform:screenshake(6)
			end
			p:remove()
		end
		if drop_duration == 0 then
			p:moveTo{duration = duration, rotation = rotation, curve = curve,
				exit = {exit_2}}
		else
			p:moveTo{duration = duration, rotation = rotation, curve = curve, exit = {exit_1}}
			p:moveTo{duration = drop_duration, x = drop_x, y = drop_y, exit = {exit_2}}
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
			queue.add(i * 2, particles.damageTrail.generate, particles.damageTrail, trail)
		end

		game.particles:incrementCount("created", "Damage", gem.owner)
	end

end

-------------------------------------------------------------------------------

local DamageTrailParticle = class('DamageTrailParticle', pic)
function DamageTrailParticle:initialize(gem)
	pic.initialize(self, {x = gem.x, y = gem.y, image = image.lookup.trail_particle[gem.color]})
	AllParticles.DamageTrail[ID.particle] = self
end

function DamageTrailParticle:remove()
	AllParticles.DamageTrail[self.ID] = nil
end

function DamageTrailParticle:generate(trail)
	local p = self:new(trail.gem)
	p.particle_type = "DamageTrail"
	if trail.drop_duration then
		p:moveTo{duration = trail.duration, rotation = trail.rotation, curve = trail.curve}
		p:moveTo{duration = trail.drop_duration, x = trail.drop_x, y = trail.drop_y,
			exit = true}
	else
		p:moveTo{duration = trail.duration, rotation = trail.rotation,
			curve = trail.curve, exit = true}
	end
end

-------------------------------------------------------------------------------
-- particles for super meter generated when a gem is matched
local SuperParticle = class('SuperParticle', pic)
function SuperParticle:initialize(gem)
	local img = image.lookup.super_particle[gem.color]
	pic.initialize(self, {x = gem.x, y = gem.y, image = img})
	self.owner = gem.owner
	AllParticles.SuperParticles[ID.particle] = self
end

function SuperParticle:remove()
	game.particles:incrementCount("destroyed", "MP", self.owner)	
	AllParticles.SuperParticles[self.ID] = nil
end

function SuperParticle:generate(gem, num_particles)
-- particles follow cubic Bezier curve from gem origin to super bar.
	local owner_lookup = {p1, p2, nil}
	local player = owner_lookup[gem.owner]
	for i = 1, num_particles do
		-- create bezier curve
		local x1, y1 = gem.x, gem.y -- start
		local x4, y4 = stage.super[player.ID].x, stage.super[player.ID].y -- end
		-- dist and angle vary the second point within a circle around the origin
		local dist = ((x4 - x1) ^ 2 + (y4 - y1) ^ 2) ^ 0.5
		local angle = math.random() * math.pi * 2
		local x2 = x1 + math.cos(angle) * dist * 0.2
		local y2 = y1 + math.sin(angle) * dist * 0.2
		local x3, y3 = 0.5 * (x1 + x4), 0.5 * (y1 + y4)
		local curve = love.math.newBezierCurve(x1, y1, x2, y2, x3, y3, x4, y4)

		-- create particle
		local p = self:new(gem)
		game.particles:incrementCount("created", "MP", gem.owner)

		-- move particle
		local duration = (0.9 + 0.2 * math.random()) * 90
		p:moveTo{duration = duration, curve = curve, easing = "inQuad", exit = true}
	end
end

-------------------------------------------------------------------------------
-- When a match is made, this is the glow behind the gems
local PopParticle = class('PopParticle', pic)
function PopParticle:initialize(gem)
	pic.initialize(self, {x = stage.grid.x[gem.column], y = stage.grid.y[gem.row],
		image = image.lookup.pop_particle[gem.color]})
	AllParticles.Pop[ID.particle] = self
end

function PopParticle:remove()
	AllParticles.Pop[self.ID] = nil
end

function PopParticle:generate(gem)
	local p = self:new(gem)
	p:moveTo{duration = 30, transparency = 0, scaling = 4, exit = true}
end

-------------------------------------------------------------------------------
-- When a match is made, this is the white/gray overlay for the gems
local ExplodingGem = class('ExplodingGem', pic)
ExplodingGem.GEM_EXPLODE_FRAMES = 20
ExplodingGem.GEM_FADE_FRAMES = 10
function ExplodingGem:initialize(gem)
	local grey_gems = gem.owner == 3
	local color = grey_gems and (gem.color .. "_GRAY") or gem.color
	local img = image.lookup.gem_explode[color]
	pic.initialize(self, {x = gem.x, y = gem.y, image = img, transparency = 0})
	AllParticles.ExplodingGem[ID.particle] = self
end

function ExplodingGem:remove()
	AllParticles.ExplodingGem[self.ID] = nil
end

function ExplodingGem:generate(gem)
	local p = self:new(gem)
	p:moveTo{duration = self.GEM_EXPLODE_FRAMES, transparency = 255}
	if gem.owner == 3 then
		p:moveTo{duration = self.GEM_FADE_FRAMES, exit = true}
	else
		p:moveTo{duration = self.GEM_FADE_FRAMES, transparency = 0, scaling = 2,
			exit = true}
	end
end

-------------------------------------------------------------------------------
-- When a gem platform disappears, this is the explody parts 
local ExplodingPlatform = class('ExplodingPlatform', pic)
function ExplodingPlatform:initialize(x, y, image)
	pic.initialize(self, {x = x, y = y, image = image})
	AllParticles.ExplodingPlatform[ID.particle] = self
end

function ExplodingPlatform:remove()
	AllParticles.ExplodingPlatform[self.ID] = nil
end

function ExplodingPlatform:generate(platform)
	local x, y = platform.x, platform.y
	local todraw = image.UI.starpiece
	local rotation = 6
	local duration = 60
 	local acc = stage.height

	local moves = {
		{x = stage.width * -0.2, y = stage.height * -0.5, rotation = -6},
		{x = stage.width * 0.2, y = stage.height * -0.5, rotation = 6},
		{x = stage.width * -0.2, y = stage.height * -0.05, rotation = -6},
		{x = stage.width * 0.2, y = stage.height * -0.05, rotation = 6},
	}

	for i = 1, #todraw do
		local p = self:new(x, y, todraw[i])
		p.transparency = 510
		local y_func = function() return y + p.t * moves[i].y + p.t^2 * acc end

		p:moveTo{
			duration = duration,
			rotation = moves[i].rotation,
			x = x + moves[i].x,
			y = y_func,
			transparency = 0,
			scaling = 1.5,
			exit = true}
	end
end

-------------------------------------------------------------------------------
--[[
	Generates the stars underneath the platforms. They follow a bezier curve
	for the first half, then become linear.
	star_type: either "Star" or "TinyStar"
	left: the left-most x to generate particles from, as a percentage of stage width.
	right_min: the left-most x that particles end up moving to.
	right_max: the right-most x that particles end up moving to.
 --]]
local PlatformStar = class('PlatformStar', pic)
function PlatformStar:initialize(x, y, image, particle_type)
	pic.initialize(self, {x = x, y = y, image = image})
	AllParticles[particle_type][ID.particle] = self
	self.particle_type = particle_type
end

function PlatformStar:remove()
	AllParticles[self.particle_type][self.ID] = nil
end

function PlatformStar:generate(player, star_type, left, right_min, right_max)
 	-- generate particle
	local star = star_type .. player.ID
	local rand = math.random(1, #image.lookup.platform_star[star])
	local todraw = image.lookup.platform_star[star][rand]
	local x = math.random(left * stage.width, right_max * stage.width)
	local y = stage.height
	local p = self:new(x, y, todraw, "Platform" .. star_type)

	-- create bezier curve for bottom half movement
	local curve_right_min = math.max(right_min * stage.width, x)
	local curve_right = math.random(curve_right_min, right_max * stage.width)
	if player.ID == "P2" then
		curve_right_min = math.min(right_min * stage.width, x)
		curve_right = math.random(right_max * stage.width, curve_right_min)
	end
	local curve = love.math.newBezierCurve(x, y, curve_right, y * 0.75, curve_right, stage.y_mid)

	-- create move functions
	local duration = 360
	local rotation = 0.03 * duration
	if star_type == "TinyStar" then rotation = 0.06 * duration end
	if player.ID == "P2" then rotation = -rotation end
	p:moveTo{duration = duration * 0.5, curve = curve, rotation = rotation * 0.5}
	p:moveTo{duration = duration * 0.2, y = stage.height * 0.3, rotation = rotation * 0.7}
	p:moveTo{duration = duration * 0.15, y = stage.height * 0.15, rotation = rotation * 0.85,
		transparency = 0, exit = true}
end

-------------------------------------------------------------------------------
local Dust = class('Dust', pic)
function Dust:initialize(x, y, image, particle_type)
	pic.initialize(self, {x = x, y = y, image = image})
	AllParticles[particle_type][ID.particle] = self
	self.particle_type = particle_type
end

function Dust:remove()
	AllParticles[self.particle_type][self.ID] = nil
end

-- starburst along n lines, like when you capture a pokemon. Unused
function Dust:generateStarburst(gem, n)
	local x, y = gem.x, gem.y
	local duration = 10
	local rotation = 0.2
 	for i = 1, n do
	 	local todraw = image.lookup.dust.small(gem.color)
		local x_vel = (math.random() - 0.5) * 0.02 * stage.width
		local y_vel = (math.random() - 0.5) * 0.015 * stage.height

		for j = 1, math.random(1, 3) do
	 		local p = self:new(gem.x, gem.y, todraw, "OverDust")
	 		p.RGB = {128, 128, 128}
	 		local x_func = function() return x + p.t * x_vel * j end
	 		local x_func2 = function() return x + x_vel * (1 + p.t * 0.2)end
	 		local y_func = function() return y + p.t * y_vel * j end
	 		local y_func2 = function() return y + y_vel * (1 + p.t * 0.2) + acc * (1 + p.t * 0.2)^2 end

	 		p:moveTo{duration = duration, rotation = rotation, x = x_func,
	 			y = y_func, scaling = 1 + j * 0.2}
 			p:moveTo{duration = duration * 3, transparency = 0, exit = true}
	 	end
 	end
end

-- yoshi-type star movement. generated when a gem lands
function Dust:generateYoshi(gem)
	local x, y = gem.x, gem.y + gem.height * 0.5
	local image = image.lookup.dust.star(gem.color)
	local yoshi = {left = -1, right = 1}
	for dir, sign in pairs(yoshi) do
		local p = self:new(x, y, image, "OverDust")
		p.scaling = 0.5
		p:moveTo{x = x + stage.width * 0.05 * sign, y = y - stage.height * 0.02,
			duration = 30, rotation = sign, scaling = 0.8, easing = "outQuart"}
		p:moveTo{duration = 30, scaling = 1, transparency = 0, rotation = 1.25 * sign, exit = true}
	end
end

-- gravity-type fountain, called on clicking a gem
function Dust:generateFountain(gem, n)
	local x, y = gem.x, gem.y
	local duration = 60
	local rotation = 1
 	for i = 1, n do
	 	local todraw = image.lookup.dust.small(gem.color)
	 	local p_type = (i % 2 == 1) and "Dust" or "OverDust"
	 	local x_vel = (math.random() - 0.5) * 0.1 * stage.width
	 	local y_vel = (math.random() + 1) * - 0.1 * stage.height
	 	local acc = 0.26 * stage.height

 		local p = self:new(gem.x, gem.y, todraw, p_type)
 		local x1 = x + x_vel
 		local x2 = x + x_vel * 1.2
 		local y_func = function() return y + p.t * y_vel + p.t^2 * acc end
 		local y_func2 = function() return y + y_vel * (1 + p.t * 0.2) + acc * (1 + p.t * 0.2)^2 end

 		p:moveTo{duration = duration, rotation = rotation, x = x1, y = y_func}
 		p:moveTo{duration = duration * 0.2, rotation = rotation * 1.2, x = x2,
 			y = y_func2, transparency = 0, exit = true}
 	end
end

-- called when a match is made
function Dust:generateBigFountain(gem, n, owner)
	local x, y = gem.x, gem.y
	local duration = 30
	local rotation = 0.5
 	for i = 1, n do
 		local todraw = image.lookup.dust.small(gem.color)
	 	local p_type = (i % 2 == 1) and "Dust" or "OverDust"
	 	local x_vel = (math.random() - 0.5) * 0.4 * stage.width
	 	local y_vel = (math.random() - 0.75) * 0.52 * stage.height
	 	local acc = 0.2 * stage.height

 		local p = self:new(gem.x, gem.y, todraw, p_type)
 		local x1 = x + x_vel
 		local x2 = x + x_vel * 1.2
 		local y_func = function() return y + p.t * y_vel + p.t^2 * acc end
 		local y_func2 = function() return y + y_vel * (1 + p.t * 0.5) + acc * (1 + p.t * 0.5)^2 end

 		p:moveTo{duration = duration, rotation = rotation, x = x1, y = y_func}
 		p:moveTo{duration = duration * 0.5, rotation = rotation * 1.5, x = x2,
 			y = y_func2, transparency = 0, exit = true}
 	end
end

-- called when a doublecast/rush landed in the holding area
function Dust:generateStarFountain(gem, n, owner)
	local x, y = gem.x, gem.y
	local duration = 120
	local rotation = 0.5
 	for i = 1, n do
 		local todraw = image.lookup.particle_freq.random(gem.color)
	 	local p_type = (i % 2 == 1) and "Dust" or "OverDust"
	 	local x_vel = (math.random() - 0.5) * stage.width
	 	local y_vel = (math.random() - 0.75) * 2 * stage.height
	 	local acc = 3 * stage.height

	 	-- create star
 		local p = self:new(gem.x, gem.y, todraw, p_type)
 		local x1 = x + x_vel
 		local y_func = function() return y + p.t * y_vel + p.t^2 * acc end
 		p:moveTo{duration = duration, rotation = rotation, x = x1, y = y_func, exit = true}

 		-- create trails
 		for frames = 1, 3 do
	 		local trail_image = image.lookup.trail_particle[gem.color]
			local trail = self:new(x, y, trail_image, p_type)
			local trail_y = function() return y + trail.t * y_vel + trail.t^2 * acc end
			trail.scaling = 1.25 - (frames * 0.25)
			trail:wait(frames * 2)
			trail:moveTo{duration = duration, rotation = rotation, x = x1, y = trail_y, exit = true}
 		end
 	end
end

-- called from "Go" word. Similar to generateStarFountain but faster
function Dust:generateYellowFountain(x, y)
	local duration = 120
	local rotation = 0.5

	for i = 1, 48 do
		local todraw = image.lookup.particle_freq.random("YELLOW")
		local p_type = (i % 2 == 1) and "Dust" or "OverDust"
	 	local x_vel = (math.random() - 0.5) * 2 * stage.width
	 	local y_vel = (math.random() - 0.75) * 3 * stage.height
	 	local acc = 3 * stage.height

		-- create star
	 	local p = self:new(x, y, todraw, p_type)
	 	local x1 = x + x_vel
	 	local y_func = function() return y + p.t * y_vel + p.t^2 * acc end
	 	p:moveTo{duration = duration, rotation = rotation, x = x1, y = y_func, exit = true}

		-- create trails
 		for frames = 1, 3 do
	 		local trail_image = image.lookup.trail_particle.YELLOW
			local trail = self:new(x, y, trail_image, p_type)
			local trail_y = function() return y + trail.t * y_vel + trail.t^2 * acc end
			trail.scaling = 1.25 - (frames * 0.25)
			trail:wait(frames * 2)
			trail:moveTo{duration = duration, rotation = rotation, x = x1, y = trail_y, exit = true}
 		end
 	end
end

-- constant speed falling with no x-movement
function Dust:generateFalling(gem, x_drift, y_drift)
	local x, y = gem.x + x_drift, gem.y + y_drift
 	local todraw = image.lookup.dust.small(gem.color, false)
 	local rotation = 6
 	local duration = 60
 	local p_type = (math.random(1, 2) == 2) and "Dust" or "OverDust"

 	local p = self:new(x, y, todraw, p_type)
 	p:moveTo{duration = duration, rotation = rotation, y = y + 0.13 * stage.height}
 	p:moveTo{duration = duration * 0.3, rotation = rotation * 1.3, transparency = 0,
 		y = y + 1.3 * (0.13 * stage.height), exit = true}
end

-- generate the spinning dust from platforms
function Dust:generatePlatformSpin(x, y, speed)
	local todraw = image.lookup.dust.small("RED", true)
	local rotation = 6
	local duration = 60

 	local x_vel = (math.random() - 0.5) * 2 * stage.width * (speed + 0.2)
 	local y_vel = (math.random() - 0.75) * 3 * stage.height * (speed + 0.2)
 	local acc = stage.height * (speed + 0.2) * 3

	local p = self:new(x, y, todraw, "Dust")
	local y_func = function() return y + p.t * y_vel + p.t^2 * acc end
 	p:moveTo{duration = duration, rotation = rotation, x = x + x_vel, y = y_func, transparency = 0, exit = true}
end
-------------------------------------------------------------------------------
-- When a gem is placed in basin, make the gem effects for tweening offscreen.
local UpGem = class('UpGem', pic)
function UpGem:initialize(gem)
	pic.initialize(self, {x = gem.x, y = gem.y, image = gem.image})
	AllParticles.UpGem[ID.particle] = self
end

function UpGem:remove()
	AllParticles.UpGem[self.ID] = nil
end

function UpGem:generate(gem)
	local p = self:new(gem)
	p:moveTo{y = -p.height, duration = 60, easing = "inQuad", exit = true}
end

-- Remove all gems at end of turn, whether they finished tweening or not
function UpGem:removeAll()
	for _, v in pairs(AllParticles.UpGem) do v:remove() end
end

-------------------------------------------------------------------------------
local WordEffects = class ('WordEffects', pic)
function WordEffects:initialize(x, y, todraw)
	pic.initialize(self, {x = x, y = y, image = todraw})
	AllParticles.WordEffects[ID.particle] = self
end

function WordEffects:remove()
	AllParticles.WordEffects[self.ID] = nil
end

-- the glow cloud behind a doublecast piece.
-- called from anims.putPendingOnTop, and from anims.update
function WordEffects:generateDoublecastCloud(gem1, gem2, horizontal)
	local todraw = horizontal and image.words.doublecast_cloud_h or image.words.doublecast_cloud_v
	local p = self:new((gem1.x + gem2.x) * 0.5, (gem1.y + gem2.y) * 0.5, todraw)
	p.transparency = 0
	p:moveTo{duration = 20, transparency = 255, easing = "inCubic"}
	p.update = function(self, dt)
		pic.update(self, dt)
		self.x, self.y = (gem1.x + gem2.x) * 0.5, (gem1.y + gem2.y) * 0.5
	end
	p.cloud = true
end

-- the glow cloud behind a rush piece.
-- called from anims.putPendingOnTop, and from anims.update
function WordEffects:generateRushCloud(gem1, gem2, horizontal)
	local todraw = horizontal and image.words.rush_cloud_h or image.words.rush_cloud_v
	local p = self:new((gem1.x + gem2.x) * 0.5, (gem1.y + gem2.y) * 0.5, todraw)
	p.transparency = 0
	p:moveTo{duration = 20, transparency = 255, easing = "inCubic"}
	p:moveTo{duration = 600, during = {8, 0, WordEffects.generateRushParticle, WordEffects, gem1, gem2, horizontal}}
	p.update = function(self, dt)
		pic.update(self, dt)
		self.x, self.y = (gem1.x + gem2.x) * 0.5, (gem1.y + gem2.y) * 0.5
	end
	p.cloud = true
end

-- the sparks coming out from the rush cloud.
-- called from WordEffects:generateRushCloud
function WordEffects:generateRushParticle(gem1, gem2, horizontal)
	local todraw = image.words.rush_particle
	local x, y = (gem1.x + gem2.x) * 0.5, (gem1.y + gem2.y) * 0.5
	local x_drift, x_center, y_adj
	if horizontal then
		x_drift = (math.random() - 0.5) * image.GEM_WIDTH * 2
		x_center = math.random() * stage.width * 0.002
		y_adj = -image.GEM_HEIGHT * 0.5
	else
		x_drift = (math.random() - 0.5) * image.GEM_WIDTH
		x_center = math.random() * stage.width * 0.001
		y_adj = -image.GEM_HEIGHT
	end
	local rotation = (x_drift / image.GEM_WIDTH) / (math.pi * 2)

	local p = self:new(x + x_drift, y + y_adj, todraw)
	p.rotation = (x_drift / image.GEM_WIDTH) / (math.pi * 2)
	p:moveTo{duration = 18, scaling = 0.7, exit = true}
end

-- falling stars accompanying Ready at start of match. Called from Words.Ready
function WordEffects:generateReadyParticle(size, x, y)
	local todraw = image.lookup.words_ready(size)
	local p = self:new(x, y, todraw)
	local y_func = function() return y + (p.t*3)^2 * 0.15 * stage.height end
	p:moveTo{duration = 120, y = y_func, exit = true}
end

-- large gold star accompanying Go at start of match. Called from Words.Go
function WordEffects:generateGoStar(x, y, x_vel, y_vel)
	local p = self:new(x, y, image.words.go_star)
	local y_func = function() return y + p.t * y_vel + (p.t)^2 * 3 * stage.height end
	p:moveTo{duration = 120, x = x + x_vel, y = y_func, exit = true}
end

-- DoublecastCloud, RushCloud, RushParticle, ReadyParticle, GoStar
function WordEffects:generate(effect_type, ...)
	local particle = {
		DoublecastCloud = self.generateDoublecastCloud,
		RushCloud = self.generateRushCloud,
		RushParticle = self.generateRushParticle,
		ReadyParticle = self.generateReadyParticle,
		GoStar = self.generateGoStar,
	}
	particle[effect_type](particle[effect_type], ...)
end

function WordEffects:cloudExists()
	for _, effect in pairs(AllParticles.WordEffects) do
		if effect.cloud then return true end
	end
	return false
end

function WordEffects:clear()
	for _, effect in pairs(AllParticles.WordEffects) do
		if effect.cloud then effect:remove() end
	end
end

-------------------------------------------------------------------------------



-------------------------------------------------------------------------------
-- words! Doublecast, rush, go, and ready so far.
local Words = class ('Words', pic)
function Words:initialize(x, y, todraw)
	pic.initialize(self, {x = x, y = y, image = todraw})
	AllParticles.Words[ID.particle] = self
end

function Words:remove()
	AllParticles.Words[self.ID] = nil
end

function Words:generateDoublecast(player)
	local x = player.ID == "P1" and stage.width * 0.4 or stage.width * 0.6
	local y = stage.height * 0.3
	local todraw = image.words.doublecast
	local p = self:new(x, y, todraw, nil, nil, nil, nil, nil, true)
	p.scaling = 5
	p:moveTo{duration = 60, scaling = 1, easing = "outQuart"}
	p:moveTo{duration = 60, transparency = 0, easing = "inExpo", exit = true}
end

function Words:generateRush(player)
	local sign = player.ID == "P1" and 1 or -1
	local x = stage.width * (0.5 - sign * 0.6)
	local y = stage.height * 0.3
	local todraw = image.words.rush
	local p = self:new(x, y, todraw, nil, nil, nil, nil, nil, true)
	p.rotation = 0.25
	p:moveTo{duration = 60, x = stage.width * (0.5 + sign * 0.2), rotation = 0, easing = "outBounce"}
	p:moveTo{duration = 60, x = stage.width * (0.5 + sign * 0.9), rotation = 0.5, easing = "inBack", exit = true}
end

function Words:generateReady()
	local x = stage.width * -0.4
	local y = stage.height * 0.3
	local todraw = image.words.ready
	local h, w = todraw:getHeight(), todraw:getWidth()
	local p = self:new(x, y, todraw, nil, nil, nil, nil, nil, true)
	local generate_big = function()
		particles.wordEffects:generateReadyParticle("large",
				p.x + (math.random()-0.5)*w, stage.height*0.3 + (math.random()-0.5)*h)
	end
	local generate_small = function()
		particles.wordEffects:generateReadyParticle("small",
			p.x + (math.random()-0.5)*w, stage.height*0.3 + (math.random()-0.5)*h)
	end
	p:moveTo{duration = 60, x = 0.5 * stage.width, transparency = 510, 
		during = {{5, 0, generate_big}, {2, 0, generate_small}}, easing = "outQuart"}
	p:moveTo{duration = 60, x = 1.4 * stage.width, transparency = 0,
		during = {{5, 0, generate_big}, {2, 0, generate_small}}, easing = "inQuad", exit = true}
end

function Words:generateGo()
	local x = stage.width * 0.5
	local y = stage.height * 0.3
	local todraw = image.words.go
	local p = self:new(x, y, todraw)
	p.scaling = 0.1
	p:moveTo{duration = 36, scaling = 1, easing = "outQuart"}
	p:moveTo{duration = 18, transparency = 0, easing = "linear", exit = true}

	particles.wordEffects:generateGoStar(x, y, stage.width * 0.25, stage.height * -0.4)
	particles.wordEffects:generateGoStar(x, y, stage.width * 0.25, stage.height * -1.2)
	particles.wordEffects:generateGoStar(x, y, stage.width * -0.25, stage.height * -0.4)
	particles.wordEffects:generateGoStar(x, y, stage.width * -0.25, stage.height * -1.2)
	particles.dust:generateYellowFountain(x, y)
end

-------------------------------------------------------------------------------

local PieEffects = class ('PieEffects', pic)
function PieEffects:initialize(x, y, rotation, todraw, update_func, tw)
	pic.initialize(self, {x = x, y = y, rotation = rotation, image = todraw})
	AllParticles.PieEffects[ID.particle] = self
	self.update = update_func
	self.t = 0
	self.tweening = tween.new(tw.duration, self, tw.var, tw.movement)
end

function PieEffects:remove()
	AllParticles.PieEffects[self.ID] = nil
end

function PieEffects:generateSegment(segment, todraw)
	todraw = todraw or segment.image
	local x_sign, y_sign
	if segment.owner.ID == "P1" then
		x_sign = (segment.segment_number == 1 or segment.segment_number == 2) and 1 or -1
	elseif segment.owner.ID == "P2" then
		x_sign = (segment.segment_number == 1 or segment.segment_number == 2) and -1 or 1
	end
	y_sign = (segment.segment_number == 1 or segment.segment_number == 4) and -1 or 1

	local update_func = function(self, dt)
		local complete = self.tweening:update(dt)
		self.x = segment.x + self.t * x_sign * stage.width * 0.2
		self.y = segment.y + self.t * y_sign * stage.height * 0.2
		self.scaling = 1 + (self.t * 10)
		self.transparency = math.max(255 - (self.t * 255), 0)
		if complete then self:remove() end
	end
	local tweening = {duration = 0.5,	var = {t = 1}, movement = "inCubic"}
	self:new(segment.x, segment.y, segment.rotation, todraw, update_func, tweening)
end

function PieEffects:generatePie(pie)
end

-------------------------------------------------------------------------------

local CharEffects = class ('CharEffects', pic)
-- required stuff in table: x, y, image
function CharEffects:initialize(tbl)
	pic.initialize(self, tbl)
	AllParticles.CharEffects[ID.particle] = self
end

function CharEffects:remove()
	AllParticles.CharEffects[self.ID] = nil
end

-------------------------------------------------------------------------------

local SuperFreezeEffects = class ('SuperFreezeEffects', pic)
-- required stuff in table: x, y, image, draw_order
function SuperFreezeEffects:initialize(tbl)
	pic.initialize(self, tbl)
	pic.draw_order = tbl.draw_order or 1
	AllParticles.SuperFreezeEffects[ID.particle] = self
end

function SuperFreezeEffects:remove()
	AllParticles.SuperFreezeEffects[self.ID] = nil
end

-------------------------------------------------------------------------------

particles.damage = DamageParticle
particles.superParticles = SuperParticle
particles.pop = PopParticle
particles.explodingGem = ExplodingGem
particles.explodingPlatform = ExplodingPlatform
particles.damageTrail = DamageTrailParticle
particles.platformStar = PlatformStar
particles.dust = Dust
--particles.overDust = OverDust
particles.upGem = UpGem
particles.words = Words
particles.wordEffects = WordEffects
particles.pieEffects = PieEffects
particles.charEffects = CharEffects
particles.superFreezeEffects = SuperFreezeEffects

return particles
