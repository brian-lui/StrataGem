--[[ Color: yellow
Passive: Yellow gems cast by Diggory destroy the gem below them, dealing one
damage. This ability can't destroy other yellows or indestructible gems.

Super: 40% of Diggory’s gems get cracked. Cracked gems break if a match occurs
adjacent to them. Also Diggory yellows POWER through them and break the next
gem down.
--]]

local love = _G.love
local common = require "class.commons"
local images = require "images"
local Pic = require "pic"
local Character = require "character"

local Diggory = {}

Diggory.large_image = love.graphics.newImage('images/portraits/diggory.png')
Diggory.small_image = love.graphics.newImage('images/portraits/diggorysmall.png')
Diggory.character_name = "Diggory"
Diggory.meter_gain = {
	red = 4,
	blue = 4,
	green = 4,
	yellow = 8,
	none = 4,
	wild = 4,
}
Diggory.primary_colors = {"yellow"}

Diggory.super_images = {
	word = images.ui_super_text_yellow,
	empty = images.ui_super_empty_yellow,
	full = images.ui_super_full_yellow,
	glow = images.ui_super_glow_yellow,
	overlay = love.graphics.newImage('images/characters/diggory/diggorylogo.png'),
}
Diggory.burst_images = {
	partial = images.ui_burst_part_yellow,
	full = images.ui_burst_full_yellow,
	glow = {images.ui_burst_partglow_yellow, images.ui_burst_fullglow_yellow}
}

Diggory.special_images = {
	clod = {
		regular = {
			love.graphics.newImage('images/characters/diggory/clod1.png'),
			love.graphics.newImage('images/characters/diggory/clod2.png'),
			love.graphics.newImage('images/characters/diggory/clod3.png'),
			love.graphics.newImage('images/characters/diggory/clod4.png'),
		},
		red = {
			love.graphics.newImage('images/characters/diggory/rclod1.png'),
			love.graphics.newImage('images/characters/diggory/rclod2.png'),
			love.graphics.newImage('images/characters/diggory/rclod3.png'),
			love.graphics.newImage('images/characters/diggory/rclod4.png'),
		},
		blue = {
			love.graphics.newImage('images/characters/diggory/bclod1.png'),
			love.graphics.newImage('images/characters/diggory/bclod2.png'),
			love.graphics.newImage('images/characters/diggory/bclod3.png'),
			love.graphics.newImage('images/characters/diggory/bclod4.png'),
		},
		green = {
			love.graphics.newImage('images/characters/diggory/gclod1.png'),
			love.graphics.newImage('images/characters/diggory/gclod2.png'),
			love.graphics.newImage('images/characters/diggory/gclod3.png'),
			love.graphics.newImage('images/characters/diggory/gclod4.png'),
		},
		yellow = {
			love.graphics.newImage('images/characters/diggory/yclod1.png'),
			love.graphics.newImage('images/characters/diggory/yclod2.png'),
			love.graphics.newImage('images/characters/diggory/yclod3.png'),
			love.graphics.newImage('images/characters/diggory/yclod4.png'),
		},
	},
	crack = love.graphics.newImage('images/characters/diggory/crack.png'),
	dustcloud = love.graphics.newImage('images/characters/diggory/dustcloud.png'),
}

Diggory.sounds = {
	bgm = "bgm_diggory",
}

-------------------------------------------------------------------------------
-- these appear when passive gets activated
local PassiveClouds = {}
function PassiveClouds:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
end

function PassiveClouds:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function PassiveClouds.generate(game, owner, x, y, delay)
	local image = owner.special_images.dustcloud
	local smokes = {
		left = {
			sign = -1,
			flip_x = math.random() < 0.5,
			flip_y = math.random() < 0.5,
		},
		right = {
			sign = 1,
			flip_x = math.random() < 0.5,
			flip_y = math.random() < 0.5,
		},
	}

	for _, smoke in pairs(smokes) do
		local p = common.instance(PassiveClouds, game.particles, {
			x = x,
			y = y,
			image = image,
			draw_order = 4,
			h_flip = smoke.flip_x,
			v_flip = smoke.flip_y,
			owner = owner,
		})
		p.scaling = 0.5
		p.transparency = 0
		p:wait(delay)
		p:change{duration = 0, transparency = 1}
		p:change{
			duration = 30,
			x = x + game.stage.width * 0.05 * smoke.sign,
			y = y - game.stage.height * 0.02,
			rotation = smoke.sign,
			scaling = 0.8,
			easing = "outQuart",
		}
		p:change{
			duration = 30,
			rotation = 1.25 * smoke.sign,
			scaling = 1,
			transparency = 0,
			remove = true,
		}
	end
end

PassiveClouds = common.class("PassiveClouds", PassiveClouds, Pic)

-------------------------------------------------------------------------------
-- these are the parabola-ing clods
local Clod = {}
function Clod:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
end

function Clod:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function Clod.generate(game, owner, x, y, color, delay)
	-- decide the color
	if color == "none" or color == nil then color = "regular" end
	if color == "wild" then
		local colors = {"red", "blue", "green", "yellow"}
		color = colors[math.random(#colors)]
	end

	local possible_images = owner.special_images.clod[color]
	local image = possible_images[math.random(#possible_images)]

	local p = common.instance(Clod, game.particles, {
		x = x,
		y = y,
		image = image,
		draw_order = 3,
		owner = owner,
		color = color,
		h_flip = math.random() < 0.5,
		v_flip = math.random() < 0.5,
	})

	local x_vel = images.GEM_WIDTH * (math.random() - 0.5) * 16
	local y_vel = images.GEM_HEIGHT * - (math.random() * 0.5 + 0.5) * 16
	local gravity = images.GEM_HEIGHT * 10
	local x_dest1 = x + 1 * x_vel
	local x_dest2 = x + 1.5 * x_vel
	local y_func1 = function()
		return y + p.t * y_vel + p.t^2 * gravity
	end
	local y_func2 = function()
		return y + (p.t + 1) * y_vel + (p.t + 1)^2 * gravity
	end
	local rotation_func1 = function()
		return math.atan2(y_vel + p.t * 2 * gravity, x_vel) - (math.pi * 0.5)
	end
	local rotation_func2 = function()
		return math.atan2(y_vel + (p.t + 1) * 2 * gravity, x_vel) - (math.pi * 0.5)
	end

	p.transparency = 0
	p:wait(delay)
	p:change{duration = 0, transparency = 1}
	p:change{
		duration = 60,
		x = x_dest1,
		y = y_func1,
		rotation = rotation_func1,
	}
	p:change{
		duration = 30,
		x = x_dest2,
		y = y_func2,
		rotation = rotation_func2,
		transparency = 0,
		remove = true,
	}
end

Clod = common.class("Clod", Clod, Pic)

-------------------------------------------------------------------------------
Diggory.fx = {
	passive_clouds = PassiveClouds,
	clod = Clod,
	--crack = Crack,
}
-------------------------------------------------------------------------------

function Diggory:init(...)
	Character.init(self, ...)

	self.slammy_gems = {}
	self.slammed_this_turn = false
	self.slammy_particle_wait_time = 0
end

function Diggory:beforeGravity()
	local game = self.game
	local grid = game.grid
	local delay = 0

	local pending_gems = grid:getPendingGems()
	for _, gem in pairs(pending_gems) do
		if gem.player_num == self.player_num and gem.color == "yellow" then
			self.slammy_gems[#self.slammy_gems + 1] = gem
		end
	end

	-- destroy last two rows of basin
	if self.is_supering then
		-- add the cracks

		self:emptyMP()
		self.is_supering = false
	end

	return delay
end

function Diggory:beforeTween()
	self.game:brightenScreen(self.player_num)
end

function Diggory:afterGravity()
	local game = self.game
	local grid = game.grid
	local delay = 0
	local go_to_gravity

	-- activate passive
	if not self.slammed_this_turn then
		for _, gem in pairs(self.slammy_gems) do
			local below_gem = grid[gem.row + 1][gem.column].gem
			if below_gem then
				if below_gem.color ~= "yellow" then
					local time_to_explode, particle_duration = grid:destroyGem{
						gem = below_gem,
						credit_to = self.player_num,
					}
					delay = math.max(delay, time_to_explode)

					-- clouds animation
					self.fx.passive_clouds.generate(
						game,
						self,
						below_gem.x,
						below_gem.y,
						time_to_explode
					)

					-- clods animation
					for _ = 2, 5 do
						self.fx.clod.generate(
							game,
							self,
							below_gem.x,
							below_gem.y,
							"regular",
							time_to_explode
						)
					end

					-- shaking
					for _, i in ipairs{5, 20} do
						game.queue:add(
							i,
							game.uielements.screenshake,
							game.uielements,
							1
						)
					end

					self.slammy_particle_wait_time = particle_duration
					go_to_gravity = true
				end
			end
		end

		self.slammy_gems = {}
		self.slammed_this_turn = true
	end

	return delay, go_to_gravity
end

function Diggory:beforeMatch()
	local ret = self.slammy_particle_wait_time
	self.slammy_particle_wait_time = 0
	return ret
end

function Diggory:cleanup()
	self.slammed_this_turn = false
	Character.cleanup(self)
end


return common.class("Diggory", Diggory, Character)
