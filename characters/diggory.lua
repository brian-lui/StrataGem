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
Diggory.action_image = love.graphics.newImage('images/portraits/action_diggory.png')
Diggory.shadow_image = love.graphics.newImage('images/portraits/shadow_diggory.png')
Diggory.super_fuzz_image = love.graphics.newImage('images/ui/superfuzzyellow.png')

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
	local y_vel = images.GEM_HEIGHT * - (math.random() * 0.5 + 0.5) * 20
	local gravity = images.GEM_HEIGHT * 12
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
		self:change{duration = self.gem.time_to_destruction, remove = true}
		self.is_destroyed = true
	end
end

function Crack.generate(game, owner, gem, delay)
	local params = {
		x = gem.x,
		y = gem.y,
		image = owner.special_images.crack,
		owner = owner,
		draw_order = 2,
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
-- these are the UI indicators of yellow passive for gems
local PassiveSpark = {}
function PassiveSpark:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
end

function PassiveSpark:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function PassiveSpark:update(dt)
	Pic.update(self, dt)
	self.x = self.gem.x
	self.y = self.gem.y

	self.game.particles.dust.generateFalling(
		self.game,
		self.gem,
		(math.random() - 0.5) * images.GEM_WIDTH,
		(math.random() - 0.5) * images.GEM_HEIGHT
	)

	if self.gem.is_in_grid or self.gem.is_destroyed then self:remove() end
end

function PassiveSpark.generate(game, owner, gem)
	local params = {
		x = gem.x,
		y = gem.y,
		image = images.dummy,
		owner = owner,
		draw_order = 3,
		player_num = owner.player_num,
		name = "DiggoryPassiveSpark",
		gem = gem,
	}

	common.instance(PassiveSpark, game.particles, params)
end

PassiveSpark = common.class("PassiveSpark", PassiveSpark, Pic)


-------------------------------------------------------------------------------
Diggory.fx = {
	passive_clouds = PassiveClouds,
	super_animation = SuperAnimation,
	clod = Clod,
	crack = Crack,
	passive_spark = PassiveSpark,
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

	local CRACK_GEM_PERCENTAGE = 0.5
	local SUPER_DURATION = 120
	local CRACK_START_TIME = 30
	local CRACK_ROW_WAIT = 10

	-- super cloud animations
	self.fx.super_animation.generate(game, self, SUPER_DURATION, 0)

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
	shuffle(possible_cracks, game.rng)

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
function Diggory:_getCrackedGemsToDestroy(destroyed_gems)
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
				if gem.diggory_cracked == self.player_num -- it's our crack
				and destr_gem.player_num == self.player_num -- it's our match
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

-- destroys the flagged gems. Put it in a function so we can move it around
-- updates phase.damage_particle_duration
function Diggory:_destroyFlaggedGems(to_destroy)
	local game = self.game
	local phase = game.phase
	local grid = game.grid
	local max_delay, max_particle_t = 0, 0
	local AFTER_DESTROY_PAUSE = game.GEM_EXPLODE_FRAMES

	for gem in pairs(to_destroy or self.cracked_gems_to_destroy) do
		local explode_t, particle_t = self:_clodDestroyGem(gem, game.GEM_EXPLODE_FRAMES)
		max_delay = math.max(max_delay, explode_t + AFTER_DESTROY_PAUSE)
		max_particle_t = math.max(max_particle_t, particle_t)
	end

	if not to_destroy then self.cracked_gems_to_destroy = {} end

	phase.damage_particle_duration = math.max(phase.damage_particle_duration, max_particle_t)
	return max_delay
end

-- destroy a gem using "clod" animation, not regular explode animation
function Diggory:_clodDestroyGem(gem, delay)
	local game = self.game
	local grid = game.grid
	delay = delay or 0
	
	local time_to_explode, particle_duration = grid:destroyGem{
		gem = gem,
		credit_to = self.player_num,
		show_exploding_gem = false,
		show_pop_glow = false,
		delay = delay,
	}

	-- clouds animation
	self.fx.passive_clouds.generate(game, self, gem.x, gem.y, time_to_explode)

	-- clods animation
	local color_func
	if gem.color == "red"
	or gem.color == "blue"
	or gem.color == "green"
	or gem.color == "yellow" then
		color_func = function() return gem.color end
	elseif gem.color == "wild" then
		color_func = function()
			local colors = {"red", "blue", "green", "yellow"}
			local rand = math.random(#colors)
			return colors[rand]
		end
	else
		error("Invalid color provided for Diggory _clodDestroyGem!")
	end

	for _ = 1, math.random(25, 40) do
		self.fx.clod.generate(
			game,
			self,
			gem.x,
			gem.y,
			color_func(),
			time_to_explode
		)
	end

	-- shaking
	for _, i in ipairs{5, 20} do
		game.queue:add(
			i + delay,
			game.uielements.screenshake,
			game.uielements,
			1
		)
	end

	return time_to_explode, particle_duration
end

function Diggory:beforeGravity()
	local game = self.game
	local grid = game.grid
	local delay = 0

	local pending_gems = grid:getPendingGems()
	for _, gem in pairs(pending_gems) do
		if gem.player_num == self.player_num and gem.color == "yellow" then
			self.slammy_gems[#self.slammy_gems + 1] = gem

			self.fx.passive_spark.generate(game, self, gem)
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
	
	local match_gems = grid:getMatchedGems()

	-- If any friendly gem made a match, don't activate it
	-- check up to the gem below the slammy gem
	local function _colHasFriendlyMatch(slammy_gem, player_num)
		local last_row = math.min(slammy_gem.row + 1, grid.BASIN_END_ROW)
		for row = grid.PENDING_START_ROW, last_row do
			local gem = grid[row][slammy_gem.column].gem
			if gem then
				for _, match in ipairs(match_gems) do
					if gem == match and gem.player_num == match.player_num then
						return true
					end
				end
			end
		end
		return false
	end

	-- activate passive
	for key, gem in pairs(self.slammy_gems) do
		local col_has_match = _colHasFriendlyMatch(gem, self.player_num)
		local below_gem = grid[gem.row + 1][gem.column].gem
		if below_gem then
			if not(col_has_match
			or (below_gem.color == "yellow" and not below_gem.diggory_cracked)
			or below_gem.color == "none"
			or below_gem.indestructible) then
				-- destroy the gem
				local time_to_explode, particle_duration = self:_clodDestroyGem(below_gem)

				-- get the gems adjacent to the below gem
				local left_gem = grid[below_gem.row][below_gem.column - 1].gem
				local right_gem = grid[below_gem.row][below_gem.column + 1].gem
				local down_gem = grid[below_gem.row + 1][below_gem.column].gem

				-- destroy adjacent cracked gems
				local check_gems = {}
				if left_gem then check_gems[#check_gems + 1] = left_gem end
				if right_gem then check_gems[#check_gems + 1] = right_gem end
				if down_gem then check_gems[#check_gems + 1] = down_gem end
				
				if #check_gems > 0 then
					local to_destroy = self:_getCrackedGemsToDestroy(check_gems)
					self:_destroyFlaggedGems(to_destroy)
				end

				-- crack a gem that's to the left or right of the destroyed gem
				local new_cracks = {}

				if left_gem then new_cracks[#new_cracks + 1] = left_gem end
				if right_gem then new_cracks[#new_cracks + 1] = right_gem end
				
				if #new_cracks > 0 then
					local CRACK_DELAY = time_to_explode + delay + 15
					local rand = game.rng:random(#new_cracks)
					to_crack = new_cracks[rand]
					to_crack.diggory_cracked = self.player_num
					self.fx.crack.generate(game, self, to_crack, crack_delay)
				end

				self.slammy_gems[key] = nil
				self.slammy_particle_wait_time = delay + particle_duration
				delay = delay + time_to_explode
				go_to_gravity = true
			end
		end

		self.slammy_gems[key] = nil
	end

	return delay, go_to_gravity
end

function Diggory:beforeMatch()
	local grid = self.game.grid
	local delay = 0

	local matched_gems, matches = grid:getMatchedGems()

	if matches == 0 then delay = self.slammy_particle_wait_time end
	self.slammy_particle_wait_time = 0

	self.cracked_gems_to_destroy = self:_getCrackedGemsToDestroy(matched_gems)

	return delay
end

function Diggory:duringMatch()
	local delay = self:_destroyFlaggedGems()
	return delay
end

function Diggory:cleanup()
	Character.cleanup(self)
end


return common.class("Diggory", Diggory, Character)
