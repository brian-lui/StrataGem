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
	drop1 = love.graphics.newImage('images/specials/walter/drop1.png'),
	drop2 = love.graphics.newImage('images/specials/walter/drop2.png'),
	drop3 = love.graphics.newImage('images/specials/walter/drop3.png'),
}

Walter.sounds = {
	bgm = "bgm_walter",
}

function Walter:init(...)
	Character.init(self, ...)

	self.CLOUD_SLIDE_DURATION = 45 -- how long for the cloud incoming tween
	self.CLOUD_ROW = 11 -- which row for clouds to appear on

	self.pending_clouds = {} -- clouds for vertical matches generates at t0
	self.ready_clouds = {} -- clouds at t1, gives healing
	self.ready_clouds_state = {} -- keep track of the state
	self.healing_by_columns = {0, 0, 0, 0, 0, 0, 0, 0} -- how much damage to heal by each column
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

--]]

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

function Droplet.generate(game, owner, x, y)
	local image_table = {
		owner.special_images.drop1,
		owner.special_images.drop1,
		owner.special_images.drop1,
		owner.special_images.drop1,
		owner.special_images.drop1,
		owner.special_images.drop1,
		owner.special_images.drop1,
		owner.special_images.drop2,
		owner.special_images.drop2,
		owner.special_images.drop3,
	}
	local img = image_table[math.random(#image_table)]
	local duration = 90
	local dest_y = game.stage.height * 1.1

	local params = {
		x = x,
		y = y,
		image = img,
		owner = owner,
		player_num = owner.player_num,
		name = "WalterDroplet",
	}

	local p = common.instance(Droplet, game.particles, params)
	p:change{duration = duration, y = dest_y, exit = true}
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

function HealingCloud:countdown()
	self.turns_remaining = self.turns_remaining - 1
end

function HealingCloud.generate(game, owner, col, turns_remaining)
	local grid = game.grid
	local stage = game.stage

	local FRAMES_BETWEEN_DROPLETS = 5
	local y = grid.y[owner.CLOUD_ROW]
	local dest_x = grid.x[col]
	local sign = owner.player_num == 2 and 1 or -1
	local start_x = dest_x + stage.width * 0.5 * sign
	local img = owner.special_images.cloud
	local duration = owner.CLOUD_SLIDE_DURATION
	local img_width = img:getWidth() * 0.5

	local function update_func(_self, dt)
		Pic.update(_self, dt)
		_self.elapsed_frames = _self.elapsed_frames + 1
		if _self.elapsed_frames >= FRAMES_BETWEEN_DROPLETS then
			local x = _self.x + (math.random() - 0.5) * img_width
			Droplet.generate(game, owner, x, y)
			_self.elapsed_frames = 0
		end
		if _self.turns_remaining < 0 and _self:isStationary() then
			_self:change{duration = 32, transparency = 0, exit = true}
		end
	end
	
	local params = {
		x = start_x,
		y = y,
		image = img,
		turns_remaining = turns_remaining,
		elapsed_frames = -duration, -- only create droplets after finished move
		col = col,
		update = update_func,
		owner = owner,
		player_num = owner.player_num,
		name = "WalterCloud",
	}

	owner.ready_clouds[col] = common.instance(HealingCloud, game.particles, params)
	owner.ready_clouds[col]:change{duration = duration, x = dest_x, easing = "outQuart"}
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

	local gem_table = grid:getMatchedGems()

	for _, gem in pairs(gem_table) do
		local col = gem.column
		-- Which columns to get rainclouds next turn
		if self.player_num == gem.owner and gem.is_vertical then
			self.pending_clouds[col] = true
		end

		-- Whether to heal damage for any matches
		if self.player_num == gem.owner and self.ready_clouds[col] then
			self.healing_by_columns[col] = self.healing_by_columns[col] + 1 
		end
	end
end

function Walter:afterMatch()
	local game = self.game
	local grid = game.grid

	for i = 1, 8 do
		local this_column_healing = self.healing_by_columns[i]
		for heals = 1, this_column_healing do
			self.hand:healDamage(1)
			game.particles.healing.generate{
				game = game,
				x = grid.x[i],
				y = grid.y[self.CLOUD_ROW],
				owner = self,
			}
		end
	end
end

function Walter:getEndOfTurnDelay()
	local delay = 0
	for i = 1, 8 do
		if self.pending_clouds[i] then delay = self.CLOUD_SLIDE_DURATION end
	end
	return delay
end


function Walter:beforeCleanup()
	for i = 1, 8 do
		if self.pending_clouds[i] then
			local TURNS_TO_EXIST = 1
			self:_makeCloud(i, TURNS_TO_EXIST)
			self.ready_clouds_state[i] = TURNS_TO_EXIST
		end
	end
	self.pending_clouds = {}
end

function Walter:cleanup()
	for i = 1, 8 do
		if self.ready_clouds[i] then -- animation
			self.ready_clouds[i]:countdown()
		end

		if self.ready_clouds_state[i] then -- state
			self.ready_clouds_state[i] = self.ready_clouds_state[i] - 1
			if self.ready_clouds_state[i] < 0 then self.ready_clouds_state[i] = nil end
		end
	end
	self.healing_by_columns = {0, 0, 0, 0, 0, 0, 0, 0}
end

return common.class("Walter", Walter, Character)
