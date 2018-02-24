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

Walter.full_size_image = love.graphics.newImage('images/characters/walter.png')
Walter.small_image = love.graphics.newImage('images/characters/waltersmall.png')
Walter.action_image = love.graphics.newImage('images/characters/walteraction.png')
Walter.shadow_image = love.graphics.newImage('images/characters/waltershadow.png')

Walter.super_images = {
	word = image.UI.super.blue_word,
	empty = image.UI.super.blue_empty,
	full = image.UI.super.blue_full,
	glow = image.UI.super.blue_glow,
	overlay = love.graphics.newImage('images/specials/walter/walterlogo.png'),
}

Walter.burst_images = {
	partial = image.UI.burst.blue_partial,
	full = image.UI.burst.blue_full,
	glow = {image.UI.burst.blue_glow1, image.UI.burst.blue_glow2}
}

Walter.special_images = {
	cloud = love.graphics.newImage('images/specials/walter/cloud.png'),
	foam = love.graphics.newImage('images/specials/walter/foam.png'),
	spout = love.graphics.newImage('images/specials/walter/spout.png'),
	drop = {
		love.graphics.newImage('images/specials/walter/drop1.png'),
		love.graphics.newImage('images/specials/walter/drop2.png'),
		love.graphics.newImage('images/specials/walter/drop3.png'),
	},
	splatter = {
		love.graphics.newImage('images/specials/walter/splatter1.png'),
		love.graphics.newImage('images/specials/walter/splatter2.png'),
		love.graphics.newImage('images/specials/walter/splatter3.png'),
	},
}

Walter.sounds = {
	bgm = "bgm_walter",
}

function Walter:init(...)
	Character.init(self, ...)

	self.CLOUD_SLIDE_DURATION = 36 -- how long for the cloud incoming tween
	self.CLOUD_ROW = 11 -- which row for clouds to appear on
	self.HEALING_ANIM_DURATION = 120
	self.HEALING_GLOW_DURATION = 100
	self.CLOUD_EXIST_TURNS = 3 -- how many turns a cloud exists for
	self.CLOUD_INIT_DROPLET_FRAMES = 5 -- initial frames between droplets

	self.pending_clouds = {} -- clouds for vertical matches generates at t0
	self.ready_clouds = {} -- clouds at t1, gives healing
	self.ready_clouds_state = {} -- keep track of the state
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
After three bobs everything should fade.

While this is all going on, drop1 2 and 3 should be shooting out from the foam in 
tight parabolic arcs. (they shouldn't go more than an 2 columns horizontally, but
should reach all the way to the top of the column vertically.) they should again be
in the ratio of 70% 20% 10% and also they need to rotate such that the bottom of the
image is facing the current trajectory. (think about how an arrow flies)

Super pseudocode:
	particles.popParticles.generate for ___ frames
	particles.explodingGem.generate for ___ frames

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
	self.owner.ready_clouds[self.col] = nil
end

function HealingCloud:countdown()
	self.turns_remaining = self.turns_remaining - 1
	self.frames_between_droplets = (self.owner.CLOUD_EXIST_TURNS - self.turns_remaining) * self.owner.CLOUD_INIT_DROPLET_FRAMES
	if self.turns_remaining <= 0 then
		self:remove()
	end
	print("Cloud in column " .. self.col .. " turns remaining: " .. self.turns_remaining)
end

function HealingCloud:renewCloud(turns_remaining)
	self.turns_remaining = turns_remaining or self.owner.CLOUD_EXIST_TURNS
	self.frames_between_droplets = self.owner.CLOUD_INIT_DROPLET_FRAMES
	print("Cloud in column " .. self.col .. " turns remaining: " .. self.turns_remaining)
end


function HealingCloud.generate(game, owner, col, turns_remaining)
	local grid = game.grid
	local stage = game.stage

	local y = grid.y[owner.CLOUD_ROW]
	local x = grid.x[col]
	local sign = owner.player_num == 2 and 1 or -1
	local img = owner.special_images.cloud
	local duration = owner.CLOUD_SLIDE_DURATION
	local img_width = img:getWidth()
	local img_height = img:getHeight()

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
		if _self.turns_remaining < 0 then
			_self:wait(60)
			_self:change{duration = 32, transparency = 0, remove = true}
		end
	end
	
	local params = {
		x = x,
		y = y,
		image = img,
		scaling = 3,
		transparency = 0,
		turns_remaining = turns_remaining,
		frames_between_droplets = owner.CLOUD_INIT_DROPLET_FRAMES,
		elapsed_frames = -duration, -- only create droplets after finished move
		droplet_x = {-1.5, -0.5, 0.5, 1.5}, -- possible columns for droplets to appear in
		col = col,
		update = update_func,
		owner = owner,
		player_num = owner.player_num,
		name = "WalterCloud",
	}

	owner.ready_clouds[col] = common.instance(HealingCloud, game.particles, params)
	owner.ready_clouds[col]:change{
		duration = duration,
		scaling = 1,
		transparency = 255,
		easing = "inQuad",
	}

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

Walter.particle_fx = {
	healingCloud = HealingCloud,
}
-------------------------------------------------------------------------------

function Walter:_makeCloud(column, turns_remaining)
	self.particle_fx.healingCloud.generate(self.game, self, column, turns_remaining)
end

function Walter:beforeMatch()
	local game = self.game
	local grid = game.grid
	local particles = game.particles

	local delay = 0

	-- Healing damage from rainclouds
	for col = 1, grid.COLUMNS do
		if not self.this_turn_column_healed[col] then 
			local first_empty_row = grid:getFirstEmptyRow(col)
			if self.ready_clouds_state[col] and first_empty_row < grid.BOTTOM_ROW then
				self.hand:healDamage(1)
				self.this_turn_column_healed[col] = true

				local gem = grid[first_empty_row + 1][col].gem
				-- gem glow
				particles.popParticles.generate{
					game = game,
					gem = gem,
					duration = self.HEALING_GLOW_DURATION,
				}
				particles.explodingGem.generateReverseExplode{
					game = game,
					x = gem.x,
					y = gem.y,
					image = image.lookup.gem_explode[gem.color],
					duration = self.HEALING_GLOW_DURATION,
				}
				-- healing particles
				particles.healing.generate{game = game, x = gem.x, y = gem.y, owner = self}

				delay = self.HEALING_ANIM_DURATION
				game.sound:newSFX("healing")
			end
		end
	end


	-- Which columns to get rainclouds next turn
	local gem_table = grid:getMatchedGems()
	for _, gem in pairs(gem_table) do
		if self.player_num == gem.owner and gem.is_vertical then
			self.pending_clouds[gem.column] = true
		end
	end

	-- visual indicator of a vertical match
	local gem_list = grid:getMatchedGemLists()
	for _, list in pairs(gem_list) do
		if self.player_num == list[1].owner and list[1].is_vertical then
			local d = particles.wordEffects.generateEmphasisBars(game, list, "blue")
			delay = math.max(delay, d)
		end
	end

	return delay
end


function Walter:beforeCleanup()
	local delay = 0
	for i = 1, 8 do
		if self.pending_clouds[i] then
			if not self.ready_clouds_state[i] then -- anim for new cloud
				delay = self.CLOUD_SLIDE_DURATION
				self:_makeCloud(i, self.CLOUD_EXIST_TURNS)
			else -- update existing cloud anim
				self.ready_clouds[i]:renewCloud()
			end
			self.ready_clouds_state[i] = self.CLOUD_EXIST_TURNS -- state update
		else -- update existing clouds, if any
			if self.ready_clouds[i] then self.ready_clouds[i]:countdown() end -- anim
			if self.ready_clouds_state[i] then -- state
				self.ready_clouds_state[i] = self.ready_clouds_state[i] - 1
				if self.ready_clouds_state[i] <= 0 then self.ready_clouds_state[i] = nil end
			end
		end
	end
	self.pending_clouds = {}

	self.hand.damage = math.max(4, self.hand.damage)

	return delay	
end

function Walter:cleanup()
	self.this_turn_column_healed = {false, false, false, false, false, false, false, false}
	Character.cleanup(self)
end

return common.class("Walter", Walter, Character)
