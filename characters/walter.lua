--[[ Color: blue
Passive: Vertical matches create a rain cloud. Gems matched in the rain cloud
	(including opponent matches) heal Walter for 1 damage.

Super: Clear the tallest friendly vertical column. In case of a tie, clear the
	column nearest the edge of the basin.  --]]

local love = _G.love
local common = require "class.commons"
local images = require "images"
local Pic = require "pic"
local Character = require "character"

local Walter = {}
Walter.character_name = "Walter"
Walter.meter_gain = {
	red = 4,
	blue = 8,
	green = 4,
	yellow = 4,
	none = 4,
	wild = 4,
}
Walter.primary_colors = {"blue"}

Walter.large_image = love.graphics.newImage('images/portraits/walter.png')
Walter.small_image = love.graphics.newImage('images/portraits/waltersmall.png')
Walter.action_image = love.graphics.newImage('images/portraits/action_walter.png')
Walter.shadow_image = love.graphics.newImage('images/portraits/shadow_walter.png')
Walter.super_fuzz_image = love.graphics.newImage('images/ui/superfuzzblue.png')

Walter.super_images = {
	word = images.ui_super_text_blue,
	empty = images.ui_super_empty_blue,
	full = images.ui_super_full_blue,
	glow = images.ui_super_glow_blue,
	overlay = love.graphics.newImage('images/characters/walter/walterlogo.png'),
}

Walter.burst_images = {
	partial = images.ui_burst_part_blue,
	full = images.ui_burst_full_blue,
	glow = {images.ui_burst_partglow_blue, images.ui_burst_fullglow_blue}
}

Walter.special_images = {
	cloud = love.graphics.newImage('images/characters/walter/cloud.png'),
	foam = love.graphics.newImage('images/characters/walter/foam.png'),
	aura = love.graphics.newImage('images/characters/walter/healrain.png'),
	drop = {
		love.graphics.newImage('images/characters/walter/drop1.png'),
		love.graphics.newImage('images/characters/walter/drop2.png'),
		love.graphics.newImage('images/characters/walter/drop3.png'),
	},
	splatter = {
		love.graphics.newImage('images/characters/walter/splatter1.png'),
		love.graphics.newImage('images/characters/walter/splatter2.png'),
		love.graphics.newImage('images/characters/walter/splatter3.png'),
	},
	spout = {
		love.graphics.newImage('images/characters/walter/spout1.png'),
		love.graphics.newImage('images/characters/walter/spout2.png'),
		love.graphics.newImage('images/characters/walter/spout3.png'),
	},
	bubble = {
		love.graphics.newImage('images/characters/walter/bubble1.png'),
		love.graphics.newImage('images/characters/walter/bubble2.png'),
		love.graphics.newImage('images/characters/walter/bubble3.png'),
	},
}

Walter.sounds = {
	bgm = "bgm_walter",
	raincloud = "sound/walter/raincloud.ogg",
}

function Walter:init(...)
	Character.init(self, ...)

	self.FOAM_APPEAR_DURATION = 30 -- how long it takes for foam to appear
	self.FOAM_FRAMES_BETWEEN_DROPLETS = 3 -- frames before new foam-droplet
	self.SPOUT_SPEED = 8 -- frames for the spout to move one gem_height
	self.SPOUT_STAY_FRAMES = 90 -- frames for spout to remain after full height
	self.SPOUT_FADE_FRAMES = 30 -- how long for fade-out of spout
	self.CLOUD_SLIDE_DURATION = 36 -- how long for the cloud incoming tween
	self.CLOUD_ROW = 11 -- which row for clouds to appear on
	self.CLOUD_EXIST_TURNS = 2 -- how many turns a cloud exists for
	self.DROPLET_FRAMES = { -- frames between droplets, by turns left
		[0] = math.huge,
		[1] = 20,
		[2] = 5,
		[3] = 5,
	}

	self.pending_clouds = {} -- booleans, clouds for matches generated at t0
	self.cloud_turns_remaining = {0, 0, 0, 0, 0, 0, 0, 0} -- state tracker
	self.this_turn_column_healed = {} -- booleans
	self.this_turn_already_created_cloud = {} -- booleans
end


-------------------------------------------------------------------------------
local FoamDroplet = {}
function FoamDroplet:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
end

function FoamDroplet:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function FoamDroplet.generate(game, owner, col, delay_frames)
	local grid = game.grid
	local image_table = {1, 1, 1, 1, 1, 1, 1, 2, 2, 3}
	local image_index = image_table[math.random(#image_table)]
	local drop_or_splatter = math.random() < 0.5 and "drop" or "splatter"
	local droplet_image = owner.special_images[drop_or_splatter][image_index]

	local x = grid.x[col]
	local y = grid.y[grid.BASIN_END_ROW] + images.GEM_HEIGHT * (2 * math.random() - 0.5)
	local params = {
		x = x,
		y = y,
		image = droplet_image,
		col = col,
		owner = owner,
		draw_order = 4,
		player_num = owner.player_num,
		name = "WalterFoamDroplet",
	}

	local p = common.instance(FoamDroplet, game.particles, params)

	local x_vel = images.GEM_WIDTH * (math.random() - 0.5) * 4
	local y_vel = -images.GEM_HEIGHT * 20
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

	if delay_frames then
		p.transparency = 0
		p:wait(delay_frames)
		p:change{duration = 0, transparency = 1}
	end

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
		remove = true,
	}
end
FoamDroplet = common.class("FoamDroplet", FoamDroplet, Pic)

-------------------------------------------------------------------------------
local Foam = {}
function Foam:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
end

function Foam:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function Foam.generate(game, owner, col)
	local grid = game.grid

	local function update_func(self, dt)
		Pic.update(self, dt)
		self.elapsed_frames = self.elapsed_frames + 1
		if self.elapsed_frames >= self.owner.FOAM_FRAMES_BETWEEN_DROPLETS then
			FoamDroplet.generate(game, owner, col)
			self.elapsed_frames = 0
		end
	end

	local params = {
		x = grid.x[col],
		y = grid.y[grid.BASIN_END_ROW] + images.GEM_HEIGHT * 0.5,
		image = owner.special_images.foam,
		col = col,
		owner = owner,
		draw_order = 5,
		player_num = owner.player_num,
		elapsed_frames = -owner.FOAM_APPEAR_DURATION,
		update = update_func,
		name = "WalterFoam",
	}

	local p = common.instance(Foam, game.particles, params)
	p:change{duration = owner.FOAM_APPEAR_DURATION * (1/3), scaling = 1.05}
	p:change{duration = owner.FOAM_APPEAR_DURATION * (2/3), scaling = 0.95}
	p:wait(owner.SPOUT_SPEED * 8 + owner.SPOUT_STAY_FRAMES)
	p:change{
		duration = owner.SPOUT_FADE_FRAMES,
		transparency = 0,
		remove = true,
	}
end
Foam = common.class("Foam", Foam, Pic)

-------------------------------------------------------------------------------
local Spout = {}
function Spout:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
end

function Spout:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function Spout.generate(game, owner, col)
	local grid = game.grid
	local stage = game.stage
	local spout_height = owner.special_images.spout[1]:getHeight()
	local params = {
		x = grid.x[col],
		y = grid.y[grid.BASIN_END_ROW] + images.GEM_HEIGHT * 0.5 + spout_height * 0.5,
		image = owner.special_images.spout[1],
		image_index = 1,
		SWAP_FRAMES = 8,
		current_frame = 6,

		col = col,
		owner = owner,
		draw_order = 3,
		player_num = owner.player_num,
		name = "WalterSpout",
	}

	local p = common.instance(Spout, game.particles, params)
	p:change{duration = 0, transparency = 0}
	p:wait(owner.FOAM_APPEAR_DURATION)
	p:change{duration = 0, transparency = 1}

	local dest_y = grid.y[grid.BASIN_START_ROW] - images.GEM_HEIGHT * 0.5 + spout_height * 0.5
	p:change{
		duration = owner.SPOUT_SPEED * 8,
		y = dest_y,
		quad = {y = true, y_percentage = 1, y_anchor = 0},
	}
	p:wait(owner.SPOUT_STAY_FRAMES)
	p:change{
		duration = owner.SPOUT_FADE_FRAMES,
		transparency = 0,
		remove = true,
	}
end

function Spout:update(dt)
	Pic.update(self, dt)
	self.current_frame = self.current_frame - 1
	if self.current_frame <= 0 then
		self.current_frame = self.SWAP_FRAMES
		local spouts = #self.owner.special_images.spout
		self.image_index = self.image_index % spouts + 1
		local new_image = self.owner.special_images.spout[self.image_index]
		self:newImageFadeIn(new_image, self.SWAP_FRAMES)
	end
end
Spout = common.class("Spout", Spout, Pic)

-------------------------------------------------------------------------------
local Splatter = {}
function Splatter:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
end

function Splatter:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function Splatter.generate(game, owner, x, y, image, delay_frames)
	local params = {
		x = x,
		y = y,
		image = image,
		owner = owner,
		player_num = owner.player_num,
	}
	for _ = 1, math.random(2, 4) do
		local p = common.instance(Splatter, game.particles, params)

		local x_vel = images.GEM_WIDTH * (math.random() - 0.5) * 4
		local y_vel = images.GEM_HEIGHT * - (math.random() * 0.5 + 0.5) * 4
		local gravity = images.GEM_HEIGHT * 2.5
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

		if delay_frames then
			p.transparency = 0
			p:wait(delay_frames)
			p:change{duration = 0, transparency = 1}
		end

		p:change{
			duration = 30,
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

Splatter = common.class("Splatter", Splatter, Pic)
-------------------------------------------------------------------------------
local Droplet = {}
function Droplet:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
end

function Droplet:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function Droplet.generate(game, owner, x, y, dest_y)
	local SPEED = game.stage.height * 0.011
	local image_table = {1, 1, 1, 1, 1, 1, 1, 2, 2, 3}
	local image_index = image_table[math.random(#image_table)]
	local droplet_image = owner.special_images.drop[image_index]
	local splatter_image = owner.special_images.splatter[image_index]
	local duration = (dest_y - y) / SPEED

	local params = {
		x = x,
		y = y,
		image = droplet_image,
		owner = owner,
		player_num = owner.player_num,
		name = "WalterDroplet",
	}

	local exit_func = {
		Splatter.generate,
		game,
		owner,
		x,
		dest_y,
		splatter_image,
	}
	local p = common.instance(Droplet, game.particles, params)
	p:change{duration = duration, y = dest_y, easing = "inQuad",
		remove = true, exit_func = exit_func}
end

Droplet = common.class("Droplet", Droplet, Pic)

-------------------------------------------------------------------------------
local HealingCloud = {}
function HealingCloud:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
end

function HealingCloud:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function HealingCloud:updateDropletFrequency()
	local turns_remaining = self.owner.cloud_turns_remaining[self.col]
	self.frames_between_droplets = self.owner.DROPLET_FRAMES[turns_remaining]

	if turns_remaining == 0 then
		self:wait(60)
		self:change{duration = 32, transparency = 0, remove = true}
	end
end

function HealingCloud:renewCloud()
	self.frames_between_droplets = self.owner.DROPLET_FRAMES[self.owner.CLOUD_EXIST_TURNS]
end

function HealingCloud.generate(game, owner, col)
	local grid = game.grid

	local y = grid.y[owner.CLOUD_ROW]
	local x = grid.x[col]
	local image = owner.special_images.cloud
	local duration = owner.CLOUD_SLIDE_DURATION
	local image_width = image:getWidth()
	local image_height = image:getHeight()
	local draw_order = col % 2 == 0 and 2 or 3

	local params = {
		x = x,
		y = y,
		image = image,
		scaling = 3,
		transparency = 0,
		frames_between_droplets = owner.DROPLET_FRAMES[owner.CLOUD_EXIST_TURNS],
		elapsed_frames = -duration, -- only create droplets after finished move
		droplet_x = {-1.5, -0.5, 0.5, 1.5}, -- possible columns for droplets
		col = col,
		owner = owner,
		draw_order = draw_order,
		player_num = owner.player_num,
		name = "WalterCloud",
	}

	local p = common.instance(HealingCloud, game.particles, params)
		p:change{
		duration = duration,
		scaling = 1,
		transparency = 1,
		easing = "inQuad",
	}
	game.sound:newSFX(owner.sounds.raincloud)

	-- blue dust vortexing
	local DUST_FADE_IN_DURATION = 10
	local dust_tween_duration = duration - DUST_FADE_IN_DURATION
	for _ = 1, 96 do
		local dust_distance = image_width * (math.random() + 1)
		local dust_rotation = math.random() < 0.5 and 30 or -30
		local dust_p_type = math.random() < 0.5 and "Dust" or "OverDust"
		local dust_image = images.lookup.smalldust("blue", false)
		local angle = math.random() * math.pi * 2
		local x_start = dust_distance * math.cos(angle) + x
		local y_start = dust_distance * math.sin(angle) + y
		local x_dest = image_width * 0.7 * (math.random() - 0.5) + x
		local y_dest = image_height * 0.5 * (math.random() - 0.5) + y

		local dust = common.instance(
			game.particles.dust,
			game.particles,
			x_start,
			y_start,
			dust_image,
			dust_p_type
		)
		dust.transparency = 0
		dust:change{duration = DUST_FADE_IN_DURATION, transparency = 1}
		dust:change{
			duration = dust_tween_duration,
			rotation = dust_rotation,
			x = x_dest,
			y = y_dest,
			easing = "inQuart",
			remove = true,
		}
	end
end

function HealingCloud:update(dt)
	Pic.update(self, dt)
	local grid = self.game.grid
	self.elapsed_frames = self.elapsed_frames + 1
	if self.elapsed_frames >= self.frames_between_droplets then
		local target_row = grid:getFirstEmptyRow(self.col)
		local dest_y = grid.y[target_row] + 0.5 * images.GEM_WIDTH
		local droplet_loc = table.remove(self.droplet_x, math.random(#self.droplet_x))
		if #self.droplet_x == 0 then
			self.droplet_x = {-1.5, -0.5, 0.5, 1.5}
		end
		local x = self.x + self.width * 0.75 * ((droplet_loc + (math.random() - 0.5)) * 0.25)
		Droplet.generate(self.game, self.owner, x, self.y, dest_y)
		self.elapsed_frames = 0
	end
end

HealingCloud = common.class("HealingCloud", HealingCloud, Pic)

-------------------------------------------------------------------------------
local HealingColumnAura = {}
function HealingColumnAura:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
end

function HealingColumnAura:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function HealingColumnAura.generate(game, owner, col, delay)
	local grid = game.grid
	local params = {
		x = grid.x[col],
		y = (grid.y[grid.BASIN_START_ROW] + grid.y[grid.BASIN_END_ROW]) * 0.5,
		image = owner.special_images.aura,
		transparency = 0,
		col = col,
		owner = owner,
		draw_order = -4,
		player_num = owner.player_num,
		name = "WalterAura",
	}

	local p = common.instance(HealingColumnAura, game.particles, params)
	if delay then
		p.transparency = 0
		p:wait(delay)
		p:change{duration = 0, transparency = 1}
	end

	p:change{duration = 8, transparency = 1}
	p:wait(30)
	p:change{duration = 8, transparency = 0, remove = true}

	return 48
end
HealingColumnAura = common.class("HealingColumnAura", HealingColumnAura, Pic)

-------------------------------------------------------------------------------
local MatchBubbles = {}
function MatchBubbles:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
end

function MatchBubbles:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function MatchBubbles.generate(game, owner, match_list)
	local grid = game.grid
	local stage = game.stage
	local TIME_TO_DEST = 120

	local bubble_func = function()
		local image_table = {1, 1, 1, 1, 1, 1, 1, 2, 2, 3}
		local image_index = image_table[math.random(#image_table)]
		local bubble_image = owner.special_images.bubble[image_index]
		return bubble_image
	end

	-- "gather" bubbles
	for i = 1, #match_list do
		for j = 1, 30 do
			local row, col = match_list[i].row, match_list[i].column
			local x_start = grid.x[col] + images.GEM_WIDTH * (math.random()-0.5) * 3
			local y_start = grid.y[row] + images.GEM_HEIGHT * (math.random()-0.5) * 2
			local x_dest = grid.x[col]
			local y_dest = grid.y[owner.CLOUD_ROW]

			local params = {
				x = grid.x[col],
				y = grid.y[row],
				image = bubble_func(),
				col = col,
				owner = owner,
				draw_order = 1,
				player_num = owner.player_num,
				name = "WalterMatchBubbles",
			}

			local p = common.instance(MatchBubbles, game.particles, params)
			p.transparency = 0
			p:wait(j)
			p:change{
				duration = 15,
				x = x_start,
				y = y_start,
				transparency = 1,
				easing = "inCubic",
			}
			p:change{
				duration = TIME_TO_DEST - 15,
				x = x_dest,
				y = y_dest,
				easing = "inCubic",
				remove = true,
			}
		end
	end

	-- vertical dust sparklies
	for _, gem in ipairs(match_list) do
		for i = 0, 59, 3 do
			local params = {
				x = grid.x[gem.column] + images.GEM_WIDTH * (math.random()-0.5) * 1.2,
				y = stage.height * 1.1,
				image = bubble_func(),
				draw_order = -2,
				name = "WalterMatchSparkle",
			}

			local up = common.instance(MatchBubbles, game.particles, params)
			up.transparency = 0
			up:wait(i)
			up:change{duration = 0, transparency = 1}
			up:change{
				duration = 30 + math.random() * 36,
				y = stage.height * -0.1,
				remove = true,
			}
		end
	end

	return TIME_TO_DEST - 15 
end
MatchBubbles = common.class("MatchBubbles", MatchBubbles, Pic)

-------------------------------------------------------------------------------
Walter.fx = {
	foam = Foam,
	spout = Spout,
	healingCloud = HealingCloud,
	healingColumnAura = HealingColumnAura,
	matchBubbles = MatchBubbles,
}
-------------------------------------------------------------------------------

function Walter:_makeCloud(column, delay)
	self.game.queue:add(
		delay,
		self.fx.healingCloud.generate,
		self.game,
		self,
		column
	)
end

function Walter:_activateSuper()
	local game = self.game
	local grid = game.grid

	local explode_delay, particle_delay = 0, 0

	-- find highest column
	local col, start_row = -1, grid.BOTTOM_ROW
	for i in grid:cols(self.player_num) do
		local rows =  grid:getFirstEmptyRow(i) + 1
		if rows <= start_row then col, start_row = i, rows end
	end

	if col ~= -1 then
		for row = grid.BOTTOM_ROW, start_row, -1 do
			local delay = (grid.BOTTOM_ROW - row) * self.SPOUT_SPEED +
				self.FOAM_APPEAR_DURATION - game.GEM_EXPLODE_FRAMES
			local gem = grid[row][col].gem
			gem:setOwner(self.player_num)
			local cur_explode_delay, cur_particle_delay = grid:destroyGem{
				gem = gem,
				super_meter = false,
				glow_delay = delay,
				force_max_alpha = true,
			}
			explode_delay = math.max(explode_delay, cur_explode_delay)
			particle_delay = math.max(particle_delay, cur_particle_delay)
		end

		self.fx.foam.generate(self.game, self, col)
		self.fx.spout.generate(self.game, self, col)
	end

	self:emptyMP()

	return explode_delay + particle_delay
end

-- Healing damage from rainclouds
function Walter:_cloudHealingDamage(delay)
	local game = self.game
	local grid = game.grid

	delay = delay or 0
	local additional_delay = 0

	for col in grid:cols() do
		if self.cloud_turns_remaining[col] > 0
		and not self.this_turn_column_healed[col] then
			local x = grid.x[col]
			local y = (grid.y[grid.BASIN_START_ROW] + grid.y[grid.BASIN_END_ROW]) * 0.5
			local y_range = images.GEM_HEIGHT * 4

			additional_delay = game.particles.healing.generate{
				game = game,
				x = x,
				y = y,
				y_range = y_range,
				owner = self,
				delay = delay,
			}

			self:healDamage(1, delay)
			self.this_turn_column_healed[col] = true
			game.queue:add(delay, game.sound.newSFX, game.sound, "healing")
			self.fx.healingColumnAura.generate(self.game, self, col, delay)
		end
	end

	return additional_delay
end

function Walter:beforeGravity()
	local delay = 0

	if self.is_supering then
		delay = self:_activateSuper()
		self.is_supering = false
	end

	local additional_delay = self:_cloudHealingDamage(delay)

	return delay + additional_delay
end

function Walter:beforeTween()
	self.game:brightenScreen(self.player_num)
end

function Walter:beforeMatch()
	local game = self.game
	local grid = game.grid

	local delay = 0
	local frames_until_cloud_forms = 0

	-- Which columns to get rainclouds next turn
	for _, gem in pairs(grid.matched_gems) do
		if self.player_num == gem.player_num and gem.is_in_a_vertical_match then
			self.pending_clouds[gem.column] = true
		end
	end

	-- visual indicator of a vertical match
	local gem_list = grid.matched_gem_lists
	for _, list in pairs(gem_list) do
		if self.player_num == list[1].player_num and list[1].is_in_a_vertical_match then
			delay = math.max(delay, game.GEM_EXPLODE_FRAMES)
			frames_until_cloud_forms = self.fx.matchBubbles.generate(game, self, list)
		end
	end

	-- get which columns already have clouds
	local cloud_in_col = {}
	for cloud in game.particles:getInstances("CharEffects", self.player_num, "WalterCloud") do
		cloud_in_col[cloud.col] = true
	end

	-- make new cloud animations
	for col in game.grid:cols() do
		if self.pending_clouds[col] and not cloud_in_col[col] and
		not self.this_turn_already_created_cloud[col] then
			self:_makeCloud(col, frames_until_cloud_forms)
			self.this_turn_already_created_cloud[col] = true
		end
	end

	return delay
end

function Walter:beforeCleanup()
	local delay = 0

	-- update cloud turns remaining
	for col in self.game.grid:cols() do
		if self.pending_clouds[col] then
			self.cloud_turns_remaining[col] = self.CLOUD_EXIST_TURNS
		else
			self.cloud_turns_remaining[col] = math.max(self.cloud_turns_remaining[col] - 1, 0)
		end
	end

	-- updating existing cloud animations
	for cloud in self.game.particles:getInstances("CharEffects", self.player_num, "WalterCloud") do
		cloud:updateDropletFrequency()
	end

	self.pending_clouds = {}

	return delay
end

function Walter:cleanup()
	self.this_turn_column_healed = {}
	self.this_turn_already_created_cloud = {}
	Character.cleanup(self)
end

-------------------------------------------------------------------------------

-- We store the remaining cloud turns in each column
function Walter:serializeSpecials()
	return table.concat(self.cloud_turns_remaining)
end

function Walter:deserializeSpecials(str)
	for col = 1, #str do
		self.cloud_turns_remaining[col] = tonumber(str:sub(col, col))
		if self.cloud_turns_remaining[col] ~= 0 then
			self.fx.healingCloud.generate(self.game, self, col)
		end
	end

	for cloud in self.game.particles:getInstances("CharEffects", self.player_num, "WalterCloud") do
		cloud:updateDropletFrequency()
	end
end

return common.class("Walter", Walter, Character)
