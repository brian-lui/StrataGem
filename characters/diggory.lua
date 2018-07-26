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
local shuffle = require "/helpers/utilities".shuffle

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
	delay = delay or 0
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
-- these appear when super gets activated
local SuperAnimation = {}
function SuperAnimation:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
end

function SuperAnimation:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function SuperAnimation.generate(game, owner, duration, delay)
	delay = delay or 0
	local grid = game.grid
	local FADE_IN_DURATION = 15
	local FADE_OUT_DURATION = 20
	local CLOUDS_PER_COL = 10
	local FRAMES_PER_CLOD = 4

	local cloud_image = owner.special_images.dustcloud
	local y_start = grid.y[grid.BASIN_END_ROW]
	local y_end = grid.y[grid.BASIN_END_ROW + 1]

	-- screenshake
	for i = 1, duration, 10 do
		game.queue:add(i, game.uielements.screenshake, game.uielements, 1)
	end

	-- clouds
	for i = 1, CLOUDS_PER_COL do
		for col in grid:cols(owner.player_num) do
			local p = common.instance(SuperAnimation, game.particles, {
				x = grid.x[col] + (math.random() - 0.5) * images.GEM_WIDTH,
				y = math.random(y_start, y_end),
				image = cloud_image,
				draw_order = 4,
				h_flip = math.random() < 0.5,
				v_flip = math.random() < 0.5,
				owner = owner,
				force_max_alpha = true,
			})

			p.transparency = 0
			p:wait(delay + i * 3)
			p:change{duration = FADE_IN_DURATION, transparency = 1}
			p:wait(duration - FADE_IN_DURATION)
			p:change{duration = FADE_OUT_DURATION, remove = true}
		end
	end

	-- clods
	for i = FADE_IN_DURATION, duration - FADE_IN_DURATION, FRAMES_PER_CLOD do
		for col in grid:cols(owner.player_num) do
			local possible_images = owner.special_images.clod.regular
			local clod_image = possible_images[math.random(#possible_images)]
			local x = grid.x[col]
			local y = (grid.y[grid.BASIN_END_ROW] + grid.y[grid.BASIN_END_ROW + 1]) * 0.5

			local p = common.instance(SuperAnimation, game.particles, {
				x = x,
				y = y,
				image = clod_image,
				draw_order = 2,
				owner = owner,
				h_flip = math.random() < 0.5,
				v_flip = math.random() < 0.5,
				force_max_alpha = true,
			})

			local x_vel = images.GEM_WIDTH * (math.random() - 0.5) * 12
			local y_vel = images.GEM_HEIGHT * - (math.random() * 0.5 + 0.5) * 12
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
			p:wait(delay + i)
			p:change{duration = 0, transparency = 1}
			p:change{
				duration = 45,
				x = x_dest1,
				y = y_func1,
				rotation = rotation_func1,
			}
			p:change{
				duration = 15,
				x = x_dest2,
				y = y_func2,
				rotation = rotation_func2,
				transparency = 0,
				remove = true,
			}
		end
	end
end

SuperAnimation = common.class("SuperAnimation", SuperAnimation, Pic)

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

function Clod.generate(game, owner, x, y, color, delay, force_max_alpha)
	delay = delay or 0

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
		force_max_alpha = force_max_alpha,
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
-- these are the cracks for gems

---[[
local Crack = {}
function Crack:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
end

function Crack:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
	self.owner.crack_images[self.gem] = nil
end

function Crack:update(dt)
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

function Crack.generate(game, owner, gem, delay)
	local params = {
		x = gem.x,
		y = gem.y,
		image = owner.special_images.crack,
		owner = owner,
		draw_order = 1,
		player_num = owner.player_num,
		name = "DiggoryCrack",
		h_flip = math.random() < 0.5,
		v_flip = math.random() < 0.5,
		gem = gem,
		transparency = 0,
		force_max_alpha = true,
	}

	owner.crack_images[gem] = common.instance(Crack, game.particles, params)
	owner.crack_images[gem]:wait(delay)
	owner.crack_images[gem]:change{duration = 0, transparency = 1}

	-- generate clods
	for _ = 2, 5 do
		owner.fx.clod.generate(game, owner, gem.x, gem.y, gem.color, delay, true)
	end
end

Crack = common.class("Crack", Crack, Pic)

-------------------------------------------------------------------------------
Diggory.fx = {
	passive_clouds = PassiveClouds,
	super_animation = SuperAnimation,
	clod = Clod,
	crack = Crack,
}
-------------------------------------------------------------------------------

function Diggory:init(...)
	Character.init(self, ...)

	self.slammy_gems = {}
	self.slammy_particle_wait_time = 0
	self.crack_images = {} -- Crack image objects
	self.cracked_gems_to_destroy = {} -- set
end

function Diggory:_activateSuper()
	local game = self.game
	local grid = game.grid

	local CRACK_GEM_PERCENTAGE = 0.4
	local SUPER_DURATION = 120
	local CRACK_START_TIME = 30
	local CRACK_ROW_WAIT = 10

	-- super cloud animations
	local delay = self.fx.super_animation.generate(game, self, SUPER_DURATION, 0)

	-- determine crack gems and add to table
	local possible_cracks = {}
	local this_turn_new_cracks = {}
	for gem in grid:basinGems(self.player_num) do
		if gem.color ~= "none" and (not gem.indestructible) and
		(not gem.diggory_cracked) then
			possible_cracks[#possible_cracks + 1] = gem
		end
	end

	local total_crack_gems = math.ceil(#possible_cracks * CRACK_GEM_PERCENTAGE)
	shuffle(possible_cracks)

	for i = 1, total_crack_gems do
		local gem = possible_cracks[i]
		gem.diggory_cracked = self.player_num
		this_turn_new_cracks[gem] = true
	end

	-- add alpha to gems
	for gem in grid:basinGems(self.player_num) do
		gem.force_max_alpha = true
	end

	-- add crack animation objects
	local crack_delay = CRACK_START_TIME
	for row = grid.BASIN_END_ROW, grid.BASIN_START_ROW, -1 do
		for col in grid:cols(self.player_num) do
			if grid[row][col].gem then
				local gem = grid[row][col].gem
				if this_turn_new_cracks[gem] then
					self.fx.crack.generate(game, self, gem, crack_delay)
				end
			end
		end
		crack_delay = crack_delay + CRACK_ROW_WAIT
	end

	self:emptyMP()

	return SUPER_DURATION
end

-- takes destroyed_gems as a list of gems, and flags ownership.
-- returns all cracked gems that are adjacent to these gems, as a set
function Diggory:_checkAndFlagCrackedGems(destroyed_gems)
	local game = self.game
	local grid = game.grid

	local to_destroy = {}

	for _, destr_gem in pairs(destroyed_gems) do
		local left_gem = grid[destr_gem.row][destr_gem.column - 1].gem
		local right_gem = grid[destr_gem.row][destr_gem.column + 1].gem
		local up_gem = grid[destr_gem.row - 1][destr_gem.column].gem
		local down_gem = grid[destr_gem.row + 1][destr_gem.column].gem

		for _, gem in pairs{left_gem, right_gem, up_gem, down_gem} do
			if gem then
				-- don't flag if it's in a match already
				local in_a_match = false
				for _, check in pairs(destroyed_gems) do
					if check == gem then in_a_match = true end
				end

				if gem.diggory_cracked == self.player_num
				and (not in_a_match)
				and (not gem.indestructible)
				and (not gem.is_destroyed)
				and (not (destr_gem.player_num == 3)) then
					gem:addOwner(destr_gem.player_num)
					to_destroy[gem] = true
				end
			end
		end
	end

	return to_destroy
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

	-- activate super
	if self.is_supering then
		delay = self:_activateSuper()
		self.is_supering = false
	end

	return delay
end

function Diggory:beforeTween()
	local game = self.game
	local grid = game.grid

	game:brightenScreen(self.player_num)
	for _, crack in pairs(self.crack_images) do crack.force_max_alpha = nil end
	for gem in grid:basinGems(self.player_num) do gem.force_max_alpha = nil end
end

function Diggory:afterGravity()
	local game = self.game
	local grid = game.grid
	local delay = 0
	local go_to_gravity = false

	-- activate passive
	for key, gem in pairs(self.slammy_gems) do
		local below_gem = grid[gem.row + 1][gem.column].gem
		if below_gem then

			if (below_gem.color == "yellow" and not below_gem.diggory_cracked)
			or below_gem.color == "none"
			or below_gem.indestructible then
				-- don't destroy below gem
				self.slammy_gems[key] = nil
			else
				-- destroy the gem
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
				local min_clod, max_clod = 2, 5
				if below_gem.diggory_cracked then
					min_clod, max_clod = 20, 50
				end
				for _ = min_clod, max_clod do
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

				-- power through if cracked gem, otherwise stop
				if not below_gem.diggory_cracked then
					self.slammy_gems[key] = nil
				end

				self.slammy_particle_wait_time = delay + particle_duration

				go_to_gravity = true
			end
		else
			self.slammy_gems[key] = nil
		end
	end

	return delay, go_to_gravity
end

function Diggory:beforeMatch()
	local grid = self.game.grid

	local ret = self.slammy_particle_wait_time
	self.slammy_particle_wait_time = 0

	local matched_gems = grid:getMatchedGems()
	self.cracked_gems_to_destroy = self:_checkAndFlagCrackedGems(matched_gems)

	return ret
end

function Diggory:afterMatch()
	local game = self.game
	local phase = game.phase
	local grid = game.grid
	local max_delay, max_particle_duration = 0, 0

	for gem in pairs(self.cracked_gems_to_destroy) do
		local explode_delay, particle_duration = grid:destroyGem{
			gem = gem,
			glow_delay = game.GEM_EXPLODE_FRAMES,
		}
		max_delay = math.max(max_delay, explode_delay)
		max_particle_duration = math.max(max_particle_duration, particle_duration)
	end

	self.cracked_gems_to_destroy = {}

	phase.damage_particle_duration = math.max(phase.damage_particle_duration, max_particle_duration)
	return max_delay
end

function Diggory:cleanup()
	Character.cleanup(self)
end


return common.class("Diggory", Diggory, Character)
