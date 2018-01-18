--[[ Color: red
Passive: Horizontal matches create a fire tile if the matched gem was the top
most gem in that column. Fire tiles last for one turn. At the end of the turn,
they destroy the gem below them UNLESS a gem is placed on top of them (the gem
can come from either player). Heath owns the damage from the fire burn.

Super: If Heath makes a horizontal match on the turn he activates super, it
clears out the gems in the row above and below match. (example, a match 3 would
clear out a 3x3 box with the matched row being the middle box. a match 4 would
clear out a 4x3 box with the matched row being the middle box.)
(this should leave fire also) --]]

-- *This part is the setup part where we initialize the working variables and images
local love = _G.love
local common = require "class.commons"
local image = require "image"
local Pic = require 'pic'
local Character = require "character"

local Heath = {}
Heath.character_id = "Heath"
Heath.meter_gain = {red = 8, blue = 4, green = 4, yellow = 4}

Heath.full_size_image = love.graphics.newImage('images/characters/heath.png')
Heath.small_image = love.graphics.newImage('images/characters/heathsmall.png')
Heath.action_image = love.graphics.newImage('images/characters/heathaction.png')
Heath.shadow_image = love.graphics.newImage('images/characters/heathshadow.png')

Heath.super_images = {
	word = image.UI.super.red_word,
	empty = image.UI.super.red_empty,
	full = image.UI.super.red_full,
	glow = image.UI.super.red_glow,
	overlay = love.graphics.newImage('images/specials/heath/firelogo.png')
}

Heath.burst_images = {
	partial = image.UI.burst.red_partial,
	full = image.UI.burst.red_full,
	glow = {image.UI.burst.red_glow1, image.UI.burst.red_glow2}
}

Heath.special_images = {
	fire = {
		love.graphics.newImage('images/specials/heath/fire1.png'),
		love.graphics.newImage('images/specials/heath/fire2.png'),
		love.graphics.newImage('images/specials/heath/fire3.png'),
	},
	fire_particle = love.graphics.newImage('images/specials/heath/fireparticle.png'),
	boom = {
		love.graphics.newImage('images/specials/heath/explode1.png'),
		love.graphics.newImage('images/specials/heath/explode2.png'),
		love.graphics.newImage('images/specials/heath/explode3.png'),
		love.graphics.newImage('images/specials/heath/explode4.png'),
		love.graphics.newImage('images/specials/heath/explode5.png'),
	},
	boom_particle = {
		love.graphics.newImage('images/specials/heath/boomparticle1.png'),
		love.graphics.newImage('images/specials/heath/boomparticle2.png'),
		love.graphics.newImage('images/specials/heath/boomparticle3.png'),
	},
}

Heath.sounds = {
	bgm = "bgm_heath",
}

function Heath:init(...)
	Character.init(self, ...)

	-- these columns are stores as booleans for columns 1-8
	self.pending_fires = {} -- fires for horizontal matches generated at t0
	self.ready_fires = {} -- fires at t1, ready to burn
	self.pending_gem_cols = {} -- pending gems, for extinguishing of ready_fires
	self.generated_fires = false -- whether fire particles were generated yet
	self.super_gems = {} -- gems to be reflagged and destroyed by super effect
	self.super_boom_effects = {} -- {row/col} of boom effects to be created
end

-- *This part creates the animations for the character's specials and supers
-- The templating is the same as particles.lua, but the init and remove refers
-- to manager.allParticels.CharEffects
-------------------------------------------------------------------------------
local SmallFire = {}
function SmallFire:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	manager.allParticles.CharEffects[ID.particle] = self
	self.manager = manager
end

function SmallFire:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function SmallFire:updateYPos()
	local grid = self.game.grid
	local row = grid:getFirstEmptyRow(self.col)
	local new_y = grid.y[row]
	if self.y ~= new_y and self:isStationary() then
		local duration = math.abs(self.y - new_y) / grid.DROP_SPEED
		self:change{duration = duration, y = new_y}
	end
end

function SmallFire:fadeOut()
	self:change{duration = 32, transparency = 0, exit = true}
end

function SmallFire:countdown()
	self.turns_remaining = self.turns_remaining - 1
end

function SmallFire.generateSmallFire(game, owner, col)
	local grid = game.grid

	local function update_func(_self, dt)
		Pic.update(_self, dt)
		_self.elapsed_frames = _self.elapsed_frames + 1
		if _self.elapsed_frames >= 6 then -- loop through images
			_self.current_image_idx = _self.current_image_idx % 3 + 1
			_self:newImage(Heath.special_images.fire[_self.current_image_idx])	
			_self.elapsed_frames = 0
		end
		if _self.turns_remaining < 0 and _self:isStationary() then
			_self:change{duration = 32, transparency = 0, exit = true}
		end
	end

	local start_row = grid:getFirstEmptyRow(col)
	local start_y = grid.y[start_row]
	local bounce_top_y = grid.y[start_row - 1]

	local params = {
		x = grid.x[col],
		y = start_y,
		col = col,
		scaling = 0,
		image = Heath.special_images.fire[1],
		turns_remaining = 1,
		current_image_idx = 1,
		elapsed_frames = 0,
		update = update_func,
		owner = owner,
		player_num = owner.player_num,
		name = "HeathFire",
	}

	local p = common.instance(SmallFire, game.particles, params)
	p:change{duration = 15, y = bounce_top_y, scaling = 0.5}
	p:change{duration = 15, y = start_y, scaling = 1}
end

SmallFire = common.class("SmallFire", SmallFire, Pic)
-------------------------------------------------------------------------------
local Boom = {}
function Boom:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	manager.allParticles.CharEffects[ID.particle] = self
	self.manager = manager
end

function Boom:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function Boom._generateBoomParticle(game, boom, delay_frames)
	local stage = game.stage
	local particle_idx = math.random(1, 3)
	local params = {
		x = boom.x,
		y = boom.y,
		image = Heath.special_images.boom_particle[particle_idx],
		owner = boom.owner,
		player_num = boom.player_num,
		name = "HeathBoomParticle",
	}

	local p = common.instance(Boom, game.particles, params)

	local x_vel = stage.gem_width * (math.random() - 0.5) * 4
	local y_vel = stage.gem_height * - (math.random() * 0.5 + 0.5) * 4
	local gravity = stage.gem_height * 3
	local x_dest1 = boom.x + 1 * x_vel
	local x_dest2 = boom.x + 1.5 * x_vel
	local y_func1 = function() return boom.y + p.t * y_vel + p.t^2 * gravity end
	local y_func2 = function() return boom.y + (p.t + 1) * y_vel + (p.t + 1)^2 * gravity end
	local rotation_func = function()
		return math.atan2(y_vel + gravity * 1, x_vel) - (math.pi * 0.5)
	end

	if delay_frames then
		p.transparency = 0
		p:wait(delay_frames)
		p:change{duration = 0, transparency = 255}
	end

	p:change{duration = 60, x = x_dest1, y = y_func1, rotation = rotation_func}
	p:change{duration = 30, x = x_dest2, y = y_func2, rotation = rotation_func,
		transparency = 0, exit = true}
end

function Boom.generateBoom(game, owner, row, col)
	local particles = game.particles
	local grid = game.grid

	local function update_func(_self, dt)
		Pic.update(_self, dt)
		_self.elapsed_frames = _self.elapsed_frames + 1
		if _self.elapsed_frames >= 6 then -- loop through images
			if _self.current_image_idx < 5 then
				_self.current_image_idx = _self.current_image_idx + 1
				_self:newImage(Heath.special_images.boom[_self.current_image_idx])	
				_self.elapsed_frames = 0
			else
				_self:remove()
			end
		end
	end

	local params = {
		x = grid.x[col],
		y = grid.y[row], 
		image = Heath.special_images.boom[1],
		current_image_idx = 1,
		elapsed_frames = 0,
		update = update_func,
		owner = owner,
		player_num = owner.player_num,
		name = "HeathBoom",
	}

	local p = common.instance(Boom, game.particles, params)
	for i = 1, 20 do
		Heath.particle_fx.boom._generateBoomParticle(game, p)
		Heath.particle_fx.boom._generateBoomParticle(game, p, 5)
		Heath.particle_fx.boom._generateBoomParticle(game, p, 10)
	end
end

Boom = common.class("Boom", Boom, Pic)
-------------------------------------------------------------------------------
Heath.particle_fx = {
	smallFire = SmallFire,
	boom = Boom,
}
-------------------------------------------------------------------------------

-- *The following code is executed from phase.lua
-- character.lua has a complete list of all the timings. Can omit unneeded ones
-- we can add more timing phases if needed

-- get the list of pending gem columns for extinguishing in afterGravity
function Heath:beforeGravity()
	local pending_gems = self.game.grid:getPendingGemsByNum(3)
	self.pending_gem_cols = {}
	for _, gem in ipairs(pending_gems) do
		self.pending_gem_cols[gem.column] = true
	end
end

-- extinguish ready_fires where a gem landed on them
function Heath:afterGravity()
	for i = 1, 8 do
		if self.pending_gem_cols[i] then
			self.ready_fires[i] = false
			for _, particle in pairs(self.game.particles.allParticles.CharEffects) do
				if particle.player_num == self.player_num and particle.col == i and
				particle.name == "HeathFire" and particle.turns_remaining == 0 then
					particle:fadeOut()
				end
			end
		end
	end
end

function Heath:beforeMatch(gem_table)
	local game = self.game
	local grid = game.grid

	-- store horizontal fire locations, used in aftermatch phase
	for _, gem in pairs(gem_table) do
		local top_gem = gem.row-1 == grid:getFirstEmptyRow(gem.column)
		if self.player_num == gem.owner and gem.is_horizontal and top_gem then
			self.pending_fires[gem.column] = true
		end
	end

	-- store gems in self.super_gems, to be destroyed during afterMatch
	-- store {row, col} of Booms in self.super_boom_effects to be created during afterMatch
	if self.supering and game.scoring_combo == 0 then
		self.super_this_turn = true
		local gem_lists = grid:getMatchedGemLists()
		for _, gem_list in ipairs(gem_lists) do
			if self.player_num == gem_list[1].owner and gem_list[1].is_horizontal then
				for i = 1, #gem_list do
					local gem = gem_list[i]
					local row, col = gem.row, gem.column
					local upper = grid[row - 1][col].gem
					local lower = grid[row + 1][col].gem
					-- add to destroy queue
					if upper then
						upper:setOwner(0)
						upper:addOwner(self.player_num)
						upper:setProtectedFlag(true)
						self.super_gems[#self.super_gems+1] = upper
					end
					if lower then
						lower:setOwner(0)
						lower:addOwner(self.player_num)
						lower:setProtectedFlag(true)
						self.super_gems[#self.super_gems+1] = lower
					end

					-- add to boom particle queue
					if i > 1 and i < #gem_list then
						self.super_boom_effects[#self.super_boom_effects+1] = {row, col}
					end
				end
			end
		end
	end
end

-- explode the super gems concurrently with gem matches
function Heath:duringMatchAnimation()
	if self.super_this_turn then
		for _, gem in ipairs(self.super_gems) do
			self.game.grid:destroyGem{gem = gem, credit_to = self.player_num}
		end

		for _, location in ipairs(self.super_boom_effects) do
			self.particle_fx.boom.generateBoom(self.game, self, location[1], location[2])
		end
	end
	self.super_gems, self.super_boom_effects = {}, {}
end

function Heath:afterMatch(gem_table)
	-- create fire particle for passive
	if not self.generated_fires then -- only activate this once per turn
		for i = 1, 8 do
			if self.pending_fires[i] then
				self.particle_fx.smallFire.generateSmallFire(self.game, self, i)
			end
		end
		self.generated_fires = true
	end
end

-- take away super meter, make fires
function Heath:afterAllMatches()
	local grid = self.game.grid
	-- super
	if self.supering then
		self.mp = 0
		self.supering = false
	end

	-- activate horizontal match fires
	for i = 1, 8 do
		if self.ready_fires[i] then
			local row = grid:getFirstEmptyRow(i) + 1
			if grid[row][i].gem then
				grid:destroyGem{gem = grid[row][i].gem, credit_to = self.player_num}
				for _, particle in pairs(self.game.particles.allParticles.CharEffects) do
					if particle.player_num == self.player_num and particle.col == i and
					particle.name == "HeathFire" and particle.turns_remaining == 0 then
						particle:fadeOut()
					end
				end
			end
		end
	end
	self.ready_fires = {}
end

function Heath:whenCreatingGarbageRow()
	for _, particle in pairs(self.game.particles.allParticles.CharEffects) do
		if particle.player_num == self.player_num and particle.name == "HeathFire" then
			particle:updateYPos()
		end
	end
end

function Heath:cleanup()
	-- particle update
	for _, particle in pairs(self.game.particles.allParticles.CharEffects) do
		if particle.player_num == self.player_num and particle.name == "HeathFire" then
			particle:updateYPos()
			particle:countdown()
		end
	end

	-- prepare the active fire columns for next turn
	self.ready_fires = self.pending_fires
	self.pending_fires = {}
	self.generated_fires = false

	Character.cleanup(self)
end

return common.class("Heath", Heath, Character)
