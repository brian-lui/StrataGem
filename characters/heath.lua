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

local love = _G.love
local common = require "class.commons"
local image = require "image"
local Pic = require 'pic'
local Character = require "character"

local Heath = {}

Heath.full_size_image = love.graphics.newImage('images/characters/heath.png')
Heath.small_image = love.graphics.newImage('images/characters/heathsmall.png')
Heath.action_image = love.graphics.newImage('images/characters/heathaction.png')
Heath.shadow_image = love.graphics.newImage('images/characters/heathshadow.png')

Heath.character_id = "Heath"
Heath.meter_gain = {red = 8, blue = 4, green = 4, yellow = 4}
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
	fire = {love.graphics.newImage('images/specials/heath/fire1.png'),
		love.graphics.newImage('images/specials/heath/fire2.png'),
		love.graphics.newImage('images/specials/heath/fire3.png'),
	},
	fire_particle = love.graphics.newImage('images/specials/heath/fireparticle.png'),
	boom1 = love.graphics.newImage('images/specials/heath/explode1.png'),
	boom2 = love.graphics.newImage('images/specials/heath/explode2.png'),
	boom3 = love.graphics.newImage('images/specials/heath/explode3.png'),
	boom4 = love.graphics.newImage('images/specials/heath/explode4.png'),
	boom5 = love.graphics.newImage('images/specials/heath/explode5.png'),
	boomparticle1 = love.graphics.newImage('images/specials/heath/boomparticle1.png'),
	boomparticle2 = love.graphics.newImage('images/specials/heath/boomparticle2.png'),
	boomparticle3 = love.graphics.newImage('images/specials/heath/boomparticle3.png'),
}

Heath.sounds = {
	bgm = "bgm_heath",
}

function Heath:init(...)
	Character.init(self, ...)
	self.fire_columns = {}
	self.pending_fires = {} -- fires for horizontal matches generated at t0
	self.ready_fires = {} -- fires at t1, ready to burn
	self.super_clears = {}
end

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
	local row = grid:getFirstEmptyRow(col)
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
		if _self.elapsed_frames >= 10 then -- loop through images
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
local BoomEffect = {}
function BoomEffect:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	manager.allParticles.CharEffects[ID.particle] = self
	self.manager = manager
end

function BoomEffect:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function BoomEffect.generateBoomParticle(game, boom)
end

function BoomEffect.generateBoomEffect(game, owner, row, col)
end

BoomEffect = common.class("BoomEffect", BoomEffect, Pic)
-------------------------------------------------------------------------------


Heath.particles = {
	smallFire = SmallFire,
	boomEffect = BoomEffect,
}

-------------------------------------------------------------------------------

local particle_effects = {}
function particle_effects:BoomParticle(boom)
	local stage = self.game.stage

	local x_vel = stage.gem_width * (math.random() - 0.5)
	local y_vel = stage.gem_height * -(math.random()*0.5 + 0.5)
	local gravity = stage.gem_height
	local update_func = function(_self, dt)
		_self.t = _self.t + dt * 2
		_self.x = boom.x + (_self.t * x_vel)
		_self.y = boom.y + (_self.t * y_vel) + (_self.t^2 * gravity * 0.5)
		local angle = math.atan2(y_vel + gravity * _self.t, x_vel)
		_self.rotation = angle - math.pi * 0.5
		if _self.y > stage.height * 1.1 then _self:remove() end
	end

	return {
		x = boom.x,
		y = boom.y,
		rotation = 0,
		image = Heath.special_images["boomparticle"..math.random(1, 3)],
		t = 0,
		update = update_func,
		owner = boom.owner,
		name = "HeathBoomParticle",
	}
end

function particle_effects:Boom(row, col, owner)
	local game = self.game
	local particles = game.particles
	local stage = game.stage
	local grid = game.grid

	local draw_t, draw_img = 0, 1
	local draw_order = {1, 2, 3, 4, 5}
	local already_boom_particled = false
	local update_func = function(_self, dt)
		_self.t, draw_t = _self.t + dt, draw_t + dt
		if draw_t >= 0.1 then
			draw_t = draw_t - 0.1
			draw_img = draw_img + 1
			if draw_img > #draw_order then
				_self:remove()
			else
				_self:newImage(Heath.special_images["boom"..draw_order[draw_img] ])
			end
		end
		if _self.t >= 0.2 and not already_boom_particled then
			for _ = 1, 10 do
				local boom_particle = particle_effects.BoomParticle(_self)
				common.instance(particles.charEffects, boom_particle)
			end
			already_boom_particled = true
		end
	end

	return {
		x = grid.x[col],
		y = grid.y[row],
		rotation = math.pi * 2 / math.random(4),
		image = Heath.special_images.boom1,
		t = 0,
		update = update_func,
		owner = owner,
		name = "HeathBoom",
	}
end

function Heath:actionPhase(dt)
	local game = self.game
	-- Set rush cost to 0 if a gem is over a fire.
	if game.active_piece then
		local midline, on_left = game.active_piece:isOnMidline()
		local shift = 0
		if midline then shift = on_left and -1 or 1 end
		local legal = game.active_piece:isDropLegal(shift)
		if legal then
			local cols = game.active_piece:getColumns(shift)
			local free_rush = false
			for i = 1, #cols do
				for fire_col, _ in pairs(self.fire_columns) do
					if cols[i] == fire_col then
						free_rush = true
					end
				end
			end
			if free_rush then
				self.current_rush_cost = 0
			else
				self.current_rush_cost = self.RUSH_COST
			end
		end
	else
		self.current_rush_cost = self.RUSH_COST
	end
end

-- generate ouchies for enemy gems landing on fire
function Heath:afterGravity()
	local particles = self.game.particles

	if self.game.scoring_combo > 0 then -- only check on the first round of gravity
		return {}
	end
	local own_tbl = {self.game.p1, self.game.p2}
	local gem_table = {} -- all enemy gems played this turn
	local ret = {}
	for i = 1, #self.enemy.played_pieces do
		for _, gem in pairs(self.enemy.played_pieces[i]) do
			gem_table[#gem_table+1] = gem
		end
	end
	for i = 1, #self.played_pieces do -- need to consider own gems as well for bottom
		for _, gem in pairs(self.played_pieces[i]) do
			gem_table[#gem_table+1] = gem
		end
	end

	local bottom_gems = {} -- only consider the bottom gem
	for i = 1, #gem_table do
		local gem = gem_table[i]
		if not bottom_gems[gem.column] then
			bottom_gems[gem.column] = gem
		elseif bottom_gems[gem.column].row < gem.row then -- existing row is higher up
			bottom_gems[gem.column] = gem
		end
	end

	local ouches = 0
	local ouch_gems = {}
	for col, _ in pairs(self.fire_columns) do
		for _, gem in pairs(bottom_gems) do
			if gem.column == col and gem.color ~= "red" and own_tbl[gem.owner] == self.enemy then
				ouches = ouches + 1
				ouch_gems[#ouch_gems+1] = gem
			end
		end
	end
	if ouches > 0 then
		self.enemy:addDamage(ouches)
		for i = 1, #ouch_gems do
			particles.dust.generateBigFountain{game = self.game, gem = ouch_gems[i], num = 120} -- placeholder animation
			ret[#ret+1] = {1, particles.dust.generateBigFountain, {game = self.game, gem = ouch_gems[i], num = 120}}
		end
	end
	return ret
end

-- Make fire for horizontal matches
-- Super-clear if super was active
function Heath:beforeMatch(gem_table)
	local grid = self.game.grid

	local own_tbl = {self.game.p1, self.game.p2}

	-- store horizontal fire locations, used in aftermatch phase
	for _, gem in pairs(gem_table) do
		local owned = own_tbl[gem.owner] == self
		local top_gem = gem.row-1 == grid:getFirstEmptyRow(gem.column)
		if owned and gem.horizontal and top_gem then
			self.pending_fires[#self.pending_fires+1] = gem.column
		end
	end

	-- super
	if self.supering then
		self.super_this_turn = true
		for _, gem in pairs(gem_table) do
			local owned = own_tbl[gem.owner] == self
			if owned and gem.horizontal then
				self.super_clears[#self.super_clears+1] = gem
			end
		end
		--[[
		-- generate match exploding gems for super clears
		for _, gem in ipairs(self.super_clears) do
			local r, c = gem.row, gem.column
			if grid[r-1][c].gem then
				grid:generateExplodingGem(grid[r-1][c].gem)
			end
			if grid[r+1][c].gem then
				grid:generateExplodingGem(grid[r+1][c].gem)
			end
		end
		--]]
	end
end


-- process the super_clears list
-- TODO: the piece the opponent played this turn is incorrectly counted as belong to him,
-- even if it didn't participate in a match.

function Heath:afterMatch(gem_table)
	local game = self.game
	local particles = game.particles
	local grid = game.grid

	-- create animation particles for horizontal match fires
	for _, col in ipairs(self.pending_fires) do
		self.particles.smallFire.generateSmallFire(self.game, self, col)
	end

	if self.supering and game.scoring_combo == 1 then	-- don't super on followups
		local damage_to_add = 0 -- add it all at the end so it doesn't interfere with particles

		local function processGemGamestate(gem)
			gem:addOwner(self)
			if gem.owner ~= 3 then
				damage_to_add = damage_to_add + 1
				particles.damage.generate(game, gem)
				grid:destroyGem{gem = gem}
			end
		end

		grid:updateGrid()
		for _, v in ipairs(self.super_clears) do
			local r, c = v.row, v.column
			if grid[r-1][c].gem then
				processGemGamestate(grid[r-1][c].gem)
			end
			if grid[r+1][c].gem then
				processGemGamestate(grid[r+1][c].gem)
			end
		end
		self.enemy:addDamage(damage_to_add)
	end
end

-- take away super meter, make fires
function Heath:afterAllMatches()
	local particles = self.game.particles

	-- super
	if self.supering then
		self.mp = 0
		self.super_clears = {}
		self.supering = false
	end

	-- activate horizontal match fires
	for _, col in ipairs(self.ready_fires) do
		print("this fire makes ouch!", col)
	end

	self.ready_fires = self.pending_fires
	self.pending_fires = {}
end

function Heath:cleanup()
	-- particle update
	for _, particle in pairs(self.game.particles.allParticles.CharEffects) do
		if particle.player_num == self.player_num and particle.name == "HeathFire" then
			particle:countdown()
		end
	end

	-- fire column update
	for col, turns in pairs(self.fire_columns) do
		self.fire_columns[col] = turns - 1
		if self.fire_columns[col] < 0 then self.fire_columns[col] = nil end
	end

	self.current_rush_cost, self.current_double_cost = self.RUSH_COST, self.DOUBLE_COST
	self.supering = false
	self.super_this_turn = false
	Character.cleanup(self)
end

return common.class("Heath", Heath, Character)
