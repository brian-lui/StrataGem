local love = _G.love

local common = require "class.commons"
local image = require "image"
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
	fire1 = love.graphics.newImage('images/specials/heath/fire1.png'),
	fire2 = love.graphics.newImage('images/specials/heath/fire2.png'),
	fire3 = love.graphics.newImage('images/specials/heath/fire3.png'),
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
	self.pending_fires = {}
	self.super_clears = {}
end

local particle_effects = {}
function particle_effects.FireParticle(fire)
	local y_dest = -fire.height * 4
	local x_start = (math.random() - 0.5) * fire.width
	local dist = (x_start^2 + y_dest^2)^0.5
	local angle = math.atan2(y_dest, -x_start)
	local update_func = function(self, dt)
		self.t = self.t + dt * 2
		self.x = self.t * dist * math.cos(angle) + (fire.x + x_start)
		self.y = self.t * dist * math.sin(angle) + fire.y
		self.transparency = math.max(255 * (0.5 - self.t) * 2, 0)
		if self.transparency == 0 then self:remove() end
	end
	return {
		x = fire.x + x_start,
		y = fire.y,
		rotation = angle + math.pi * 0.5,
		image = Heath.special_images.fire_particle,
		t = 0,
		update = update_func,
		owner = fire.owner,
		name = "HeathFireParticle"
	}
end

--function particle_effects.SmallFire(gem)
function particle_effects:SmallFire(row, col, owner)
	local game = self.game
	local stage = game.stage
	local grid = game.grid

	--[[
		TODO: update the y-tracking:
			get the first_empty_row, and adjust as normal
			however, instead of moving directly to y_dest, only move at speed of SPEED.DROP
			this will make sure it moves along with the other gems, instead of instantly
	--]]
	--local first_empty_row = grid:getFirstEmptyRow(gem.column)
	local first_empty_row = row
	local new_particle_t = 0
	local draw_t, draw_img = 0, 1
	-- it pops up and then settles at y_dest. Then it fades out if removed
	local draw_order = {1, 2, 3}

	local function update_func(_self, dt)
		if self.turns_remaining == 1 then -- stop updating position after cleanup phase
			first_empty_row = grid:getFirstEmptyRow(col)
		end
		local y_dest = grid.y[first_empty_row]
		_self.t = _self.t + dt
		new_particle_t = new_particle_t + dt
		draw_t = draw_t + dt
		--[[
		if new_particle_t >= 0.2 then -- generate ember
			new_particle_t = new_particle_t - 0.2
			local fire_particle = particle_effects.FireParticle(self)
			common.instance(self.charEffects, fire_particle)
		end
		--]]

		if draw_t >= 0.1 then -- swap image
			draw_t = draw_t - 0.1
			draw_img = draw_img % #draw_order + 1
			_self.image = Heath.special_images["fire" .. draw_order[draw_img] ]
		end

		_self.x = grid.x[col]
		_self.y = grid.y[row] + (-_self.t * 0.5 * stage.height) + (_self.t^2 * stage.height)

		if _self.scaling < 1 then -- scale in
			_self.scaling = math.min(_self.t * 2, 1)
			_self.y = _self.y + image.GEM_HEIGHT * _self.t
		end

		if _self.t > 0.2 then _self.y = math.min(_self.y, y_dest) end
		if _self.turns_remaining < 0 then -- fadeout

			if not _self.transparency then _self.transparency = 255 end
			_self.transparency = math.max(_self.transparency - 8, 0)
			if _self.transparency == 0 then _self:remove() end
		end
	end
	return {
		x = grid.x[col],
		y = grid.y[row],
		rotation = 0,
		image = Heath.special_images.fire1,
		t = 0,
		update = update_func,
		turns_remaining = 1,
		owner = owner,
		name = "HeathFire",
		scaling = 0,
		--draw = draw_func
	}
end

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
			particles.dust.generateBigFountain(self.game, ouch_gems[i], 120) -- placeholder animation
			ret[#ret+1] = {1, particles.dust.generateBigFountain, self.game, particles.dust, ouch_gems[i], 120, self}
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
			self.pending_fires[#self.pending_fires+1] = {gem.row, gem.column, self}
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
	end
end

-- process the super_clears list
-- TODO: the piece the opponent played this turn is incorrectly counted as belong to him,
-- even if it didn't participate in a match.
-- TODO: warning - queue.add grid.removeGem affects state

function Heath:duringMatch(gem_table)
	local game = self.game
	local particles = game.particles
	local grid = game.grid

	if self.supering and game.scoring_combo == 1 then	-- don't super on followups
		local damage_to_add = 0 -- add it all at the end so it doesn't interfere with particles

		local function processGemGamestate(gem)
			gem:addOwner(self)
			if gem.owner ~= 3 then
				damage_to_add = damage_to_add + 1
				particles.damage.generate(game, gem)
				grid:removeGem(gem)
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
function Heath:afterMatch()
	local particles = self.game.particles

	-- super
	if self.supering then
		self.mp = 0
		self.super_clears = {}
		self.supering = false
	end

	-- horizontal match fires
	local makeFire = function(row, col, owner)
		self.fire_columns[col] = 1
		local fire_object = particle_effects.SmallFire(self, row, col, owner)
		common.instance(particles.charEffects, self.game.particles, fire_object)
	end

	for i = 1, #self.pending_fires do
		makeFire(table.unpack(self.pending_fires[i]))
	end
	self.pending_fires = {}
end

function Heath:cleanup()
	-- particle update
	for _, particle in pairs(self.game.particles.allParticles.CharEffects) do
		if particle.owner == self and particle.name == "HeathFire" then
			particle.turns_remaining = particle.turns_remaining - 1
		end
	end

	-- fire column update
	for col, turns in pairs(self.fire_columns) do
		self.fire_columns[col] = turns - 1
		if self.fire_columns[col] < 0 then self.fire_columns[col] = nil end
	end

	--[[
	for k, v in pairs(self.fire_columns) do
		print("column " .. k .. ", " .. v .. " turns left")
	end
	--]]
	self.current_rush_cost, self.current_double_cost = self.RUSH_COST, self.DOUBLE_COST
	self.supering = false
	self.super_this_turn = false
	Character.cleanup(self)
end

return common.class("Heath", Heath, Character)
