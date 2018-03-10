--[[ Color: blue
Passive: Vertical matches create a rain cloud. Gems matched in the rain cloud
	(including opponent matches) heal Walter for 1 damage.

Super: Clear the tallest friendly vertical column. In case of a tie, clear the
	column nearest the edge of the basin.  --]]

local love = _G.love
local common = require "class.commons"
local image = require 'image'
local Pic = require 'pic'
local Character = require "character"

local Walter = {}
Walter.character_id = "Walter"
Walter.meter_gain = {red = 4, blue = 8, green = 4, yellow = 4}

Walter.full_size_image = love.graphics.newImage('images/portraits/walter.png')
Walter.small_image = love.graphics.newImage('images/portraits/waltersmall.png')
Walter.action_image = love.graphics.newImage('images/portraits/walteraction.png')
Walter.shadow_image = love.graphics.newImage('images/portraits/waltershadow.png')

Walter.super_images = {
	word = image.UI.super.blue_word,
	empty = image.UI.super.blue_empty,
	full = image.UI.super.blue_full,
	glow = image.UI.super.blue_glow,
	overlay = love.graphics.newImage('images/characters/walter/walterlogo.png'),
}

Walter.burst_images = {
	partial = image.UI.burst.blue_partial,
	full = image.UI.burst.blue_full,
	glow = {image.UI.burst.blue_glow1, image.UI.burst.blue_glow2}
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
}

Walter.sounds = {
	bgm = "bgm_walter",
	raincloud = "sound/walter/raincloud.ogg",
}

function Walter:init(...)
	Character.init(self, ...)

	self.CLOUD_SLIDE_DURATION = 36 -- how long for the cloud incoming tween
	self.CLOUD_ROW = 11 -- which row for clouds to appear on
	self.CLOUD_EXIST_TURNS = 3 -- how many turns a cloud exists for
	self.CLOUD_INIT_DROPLET_FRAMES = { -- frames between droplets, by turns remaining
		[0] = math.huge,
		[1] = 20,
		[2] = 10,
		[3] = 5,
	} 

	self.pending_clouds = {} -- boolean, clouds for vertical matches generates at t0
	self.cloud_turns_remaining = {0, 0, 0, 0, 0, 0, 0, 0} -- keep track of the state
	self.this_turn_column_healed = {false, false, false, false, false, false, false, false}
end

-------------------------------------------------------------------------------
--[[
Super description:
On the turn you activate super, the gems should light up BUT not explode immediately.
Instead, foam.png should appear on the bottom of the column(s) where the match(es)
were made, and it should expand and shrink to about 105% and 95%. Then, spout.png
should quickly shoot out from the bottom of the column until the top of spout.png
reaches the top of the column. As the spout hits gems, they should explode.
ONLY THE PORTION OF SPOUT ABOVE THE FOAM SHOULD BE VISIBLE. Once it reaches the top,
it should bob up and down by about 40 pixels above and below the top of the basin.
After three bobs everything should fade. (Instead of a single spout image, there are
three. It should constantly be fading between spout 1.2.3 while it's on screen. thanks.)

While this is all going on, drop1 2 and 3 should be shooting out from the foam in 
tight parabolic arcs. (they shouldn't go more than an 2 columns horizontally, but
should reach all the way to the top of the column vertically.) they should again be
in the ratio of 70% 20% 10% and also they need to rotate such that the bottom of the
image is facing the current trajectory. (think about how an arrow flies)

Super pseudocode:
	STATE:
	beforeGravity:
		local super_column = highest_col()
		for each gem in super_column:
			destroyGem with glow delay

	ANIM:
	beforeGravity:
		foamspout instance appears at grid.y[grid.BOTTOM_ROW + 1]

FoamSpout class:
	foam appear at grid.y[grid.BOTTOM_ROW + 1]
	foam change with exit: make spout
	foam has during property with drop 1/2/3 in parabolas
	spout reaches top at duration ___.
	every ___ frames, destroyGem in row grid.BOTTOM_ROW to grid.BOTTOM_ROW - 7 
--]]

-------------------------------------------------------------------------------
local Splatter = {}
function Splatter:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	manager.allParticles.CharEffects[ID.particle] = self
	self.manager = manager
end

function Splatter:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function Splatter.generate(game, owner, x, y, img)
	local stage = game.stage
	local params = {
		x = x,
		y = y,
		image = img,
		owner = owner,
		player_num = owner.player_num,
	}
	for i = 1, math.random(2, 4) do
		local p = common.instance(Splatter, game.particles, params)

		local x_vel = stage.gem_width * (math.random() - 0.5) * 4
		local y_vel = stage.gem_height * - (math.random() * 0.5 + 0.5) * 4
		local gravity = stage.gem_height * 2.5
		local x_dest1 = x + 1 * x_vel
		local x_dest2 = x + 1.5 * x_vel
		local y_func1 = function() return y + p.t * y_vel + p.t^2 * gravity end
		local y_func2 = function() return y + (p.t + 1) * y_vel + (p.t + 1)^2 * gravity end
		local rotation_func1 = function()
			return math.atan2(y_vel + p.t * 2 * gravity, x_vel) - (math.pi * 0.5)
		end
		local rotation_func2 = function()
			return math.atan2(y_vel + (p.t + 1) * 2 * gravity, x_vel) - (math.pi * 0.5)
		end

		if delay_frames then
			p.transparency = 0
			p:wait(delay_frames)
			p:change{duration = 0, transparency = 255}
		end

		p:change{duration = 30, x = x_dest1, y = y_func1, rotation = rotation_func1}
		p:change{duration = 15, x = x_dest2, y = y_func2, rotation = rotation_func2,
			transparency = 0, remove = true}
	end
end

Splatter = common.class("Splatter", Splatter, Pic)
-------------------------------------------------------------------------------
local Droplet = {}
function Droplet:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	manager.allParticles.CharEffects[ID.particle] = self
	self.manager = manager
end

function Droplet:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function Droplet.generate(game, owner, x, y, dest_y)
	local grid = game.grid
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

	local exit_func = {Splatter.generate, game, owner, x, dest_y, splatter_image}
	local p = common.instance(Droplet, game.particles, params)
	p:change{duration = duration, y = dest_y, easing = "inQuad",
		remove = true, exit_func = exit_func}
end

Droplet = common.class("Droplet", Droplet, Pic)

-------------------------------------------------------------------------------
local HealingCloud = {}
function HealingCloud:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	manager.allParticles.CharEffects[ID.particle] = self
	self.manager = manager
end

function HealingCloud:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function HealingCloud:updateDropletFrequency()
	local droplet_lookup = {}
	local turns_remaining = self.owner.cloud_turns_remaining[self.col] 
	self.frames_between_droplets = self.owner.CLOUD_INIT_DROPLET_FRAMES[turns_remaining]

	if turns_remaining == 0 then 
		self:wait(60)
		self:change{duration = 32, transparency = 0, remove = true}
	end
end

function HealingCloud:renewCloud()
	self.frames_between_droplets = self.owner.CLOUD_INIT_DROPLET_FRAMES[self.owner.CLOUD_EXIST_TURNS]
end


function HealingCloud.generate(game, owner, col)
	local grid = game.grid
	local stage = game.stage

	local y = grid.y[owner.CLOUD_ROW]
	local x = grid.x[col]
	local sign = owner.player_num == 2 and 1 or -1
	local img = owner.special_images.cloud
	local duration = owner.CLOUD_SLIDE_DURATION
	local img_width = img:getWidth()
	local img_height = img:getHeight()
	local draw_order = col % 2 == 0 and 2 or 3

	local function update_func(_self, dt)
		Pic.update(_self, dt)
		_self.elapsed_frames = _self.elapsed_frames + 1
		if _self.elapsed_frames >= _self.frames_between_droplets then
			local destination_y = grid.y[grid:getFirstEmptyRow(col, true)] + 0.5 * image.GEM_WIDTH
			local droplet_loc = table.remove(_self.droplet_x, math.random(#_self.droplet_x))
			if #_self.droplet_x == 0 then _self.droplet_x = {-1.5, -0.5, 0.5, 1.5} end
			local x = _self.x + img_width * 0.75 * ((droplet_loc + (math.random() - 0.5)) * 0.25)
			Droplet.generate(game, owner, x, y, destination_y)
			_self.elapsed_frames = 0
		end
	end
	
	local params = {
		x = x,
		y = y,
		image = img,
		scaling = 3,
		transparency = 0,
		frames_between_droplets = owner.CLOUD_INIT_DROPLET_FRAMES[owner.CLOUD_EXIST_TURNS],
		elapsed_frames = -duration, -- only create droplets after finished move
		droplet_x = {-1.5, -0.5, 0.5, 1.5}, -- possible columns for droplets to appear in
		col = col,
		update = update_func,
		owner = owner,
		draw_order = draw_order,
		player_num = owner.player_num,
		name = "WalterCloud",
	}

	local p = common.instance(HealingCloud, game.particles, params)
		p:change{
		duration = duration,
		scaling = 1,
		transparency = 255,
		easing = "inQuad",
	}
	game.sound:newSFX(owner.sounds.raincloud)

	-- blue dust vortexing
	local DUST_FADE_IN_DURATION = 10
	local dust_tween_duration = duration - DUST_FADE_IN_DURATION
	for i = 1, 96 do
		local dust_distance = img_width * (math.random() + 1)
		local dust_rotation = math.random() < 0.5 and 30 or -30
		local dust_p_type = math.random() < 0.5 and "Dust" or "OverDust"
		local dust_image = image.lookup.dust.small("blue", false)
 		local angle = math.random() * math.pi * 2
 		local x_start = dust_distance * math.cos(angle) + x
 		local y_start = dust_distance * math.sin(angle) + y
 		local x_dest = img_width * 0.7 * (math.random() - 0.5) + x
 		local y_dest = img_height * 0.5 * (math.random() - 0.5) + y

 		local p = common.instance(game.particles.dust, game.particles, x_start, y_start, dust_image, dust_p_type)
 		p.transparency = 0
 		p:change{duration = DUST_FADE_IN_DURATION, transparency = 255}
 		p:change{
 			duration = dust_tween_duration,
 			rotation = dust_rotation,
 			x = x_dest,
 			y = y_dest,
 			easing = "inQuart",
 			remove = true,
 		}
	end
end
HealingCloud = common.class("HealingCloud", HealingCloud, Pic)

-------------------------------------------------------------------------------
local HealingColumnAura = {}
function HealingColumnAura:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	manager.allParticles.CharEffects[ID.particle] = self
	self.manager = manager
end

function HealingColumnAura:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function HealingColumnAura.generate(game, owner, col)
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
	p:change{duration = 10, transparency = 255}
	p:wait(30)
	p:change{duration = 20, transparency = 0, remove = true}
end
HealingColumnAura = common.class("HealingColumnAura", HealingColumnAura, Pic)


Walter.particle_fx = {
	healingCloud = HealingCloud,
	healingColumnAura = HealingColumnAura,
}
-------------------------------------------------------------------------------

function Walter:_makeCloud(column)
	self.particle_fx.healingCloud.generate(self.game, self, column)
end

function Walter:afterGravity()
	local delay = 0

	if self.supering then
		local game = self.game
		local grid = game.grid
	
		-- find highest column
		local col, start_row = -1, grid.BOTTOM_ROW
		for i in grid:cols(self.player_num) do
			local rows =  grid:getFirstEmptyRow(i) + 1
			if rows < start_row then col, start_row = i, rows end
		end

		if col ~= -1 then
			for row = grid.BOTTOM_ROW, start_row, -1 do
				local gem = grid[row][col].gem
				gem:setOwner(self.player_num)
				delay = (grid.BOTTOM_ROW - row) * 10 + 10
				grid:destroyGem{
					gem = gem,
					super_meter = false,
					glow_delay = delay,
				}
			end
		end

		self:emptyMP()
		self.supering = false
	end


	return delay + 20
end

function Walter:beforeMatch()
	local game = self.game
	local grid = game.grid
	local particles = game.particles

	local delay = 0

	-- Healing damage from rainclouds
	for col in grid:cols() do
		if self.cloud_turns_remaining[col] > 0 and not self.this_turn_column_healed[col] then
			local x = grid.x[col]
			local y = (grid.y[grid.BASIN_START_ROW] + grid.y[grid.BASIN_END_ROW]) * 0.5
			local y_range = image.GEM_HEIGHT * 4

			delay = particles.healing.generate{
				game = game,
				x = x,
				y = y,
				y_range = y_range,
				owner = self,
			}

			self.hand:healDamage(1)
			self.this_turn_column_healed[col] = true
			game.sound:newSFX("healing")
			self.particle_fx.healingColumnAura.generate(self.game, self, col)
		end
	end

	-- Which columns to get rainclouds next turn
	local gem_table = grid:getMatchedGems()
	for _, gem in pairs(gem_table) do
		if self.player_num == gem.owner and gem.is_in_a_vertical_match then
			self.pending_clouds[gem.column] = true
		end
	end

	-- visual indicator of a vertical match
	local gem_list = grid:getMatchedGemLists()
	for _, list in pairs(gem_list) do
		if self.player_num == list[1].owner and list[1].is_in_a_vertical_match then
			local d = particles.wordEffects.generateEmphasisBars(game, list, "blue")
			delay = math.max(delay, d)
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
	local cloud_in_col = {}
	for cloud in self.game.particles:getInstances("CharEffects", "WalterCloud", self.player_num) do
		cloud_in_col[cloud.col] = true
		cloud:updateDropletFrequency()
	end

	-- make new cloud animations
	for col in self.game.grid:cols() do
		if self.pending_clouds[col] and not cloud_in_col[col] then
			delay = self.CLOUD_SLIDE_DURATION
			self:_makeCloud(col, self.CLOUD_EXIST_TURNS)
		end
	end

	self.pending_clouds = {}

	return delay	
end

function Walter:cleanup()
	self.this_turn_column_healed = {false, false, false, false, false, false, false, false}
	Character.cleanup(self)
end

return common.class("Walter", Walter, Character)
