local love = _G.love
local class = require "middleclass"
local image = require 'image'
local Character = require "character"
--local pic = require 'pic'
--local engine = game.engine
--local hand = require 'hand'
--local default = require 'characters/default'
--local stage = game.stage

local heath = class("Heath", Character)

heath.full_size_image = love.graphics.newImage('images/characters/heath.png')
heath.small_image = love.graphics.newImage('images/characters/heathsmall.png')
heath.action_image = love.graphics.newImage('images/characters/heathaction.png')
heath.shadow_image = love.graphics.newImage('images/characters/heathshadow.png')

heath.character_id = "Heath"
heath.meter_gain = {RED = 8, BLUE = 4, GREEN = 4, YELLOW = 4}
heath.super_images = {
	word = image.UI.super.red_word,
	partial = image.UI.super.red_partial,
	full = image.UI.super.red_full,
	glow = {image.UI.super.red_glow1, image.UI.super.red_glow2, image.UI.super.red_glow3, image.UI.super.red_glow4}
}
heath.special_images = {
	--fire1 = love.graphics.newImage('images/specials/heath/fire1.png'),
	--fire2 = love.graphics.newImage('images/specials/heath/fire2.png'),
	--fire3 = love.graphics.newImage('images/specials/heath/fire3.png'),
	testfire1 = love.graphics.newImage('images/specials/heath/testfire1.png'),
	testfire2 = love.graphics.newImage('images/specials/heath/testfire2.png'),
	testfire3 = love.graphics.newImage('images/specials/heath/testfire3.png'),
	testfire4 = love.graphics.newImage('images/specials/heath/testfire4.png'),
	testfire5 = love.graphics.newImage('images/specials/heath/testfire5.png'),
	--glow1 = love.graphics.newImage('images/specials/heath/glow1.png'),
	--glow2 = love.graphics.newImage('images/specials/heath/glow2.png'),
	fire_particle = love.graphics.newImage('images/specials/heath/fireparticle.png'),
	boom1 = love.graphics.newImage('images/specials/heath/boom1.png'),
	boom2 = love.graphics.newImage('images/specials/heath/boom2.png'),
	boom3 = love.graphics.newImage('images/specials/heath/boom3.png'),
	boom4 = love.graphics.newImage('images/specials/heath/boom4.png'),
	boom5 = love.graphics.newImage('images/specials/heath/boom5.png'),
	boomparticle1 = love.graphics.newImage('images/specials/heath/boomparticle1.png'),
	boomparticle2 = love.graphics.newImage('images/specials/heath/boomparticle2.png'),
	boomparticle3 = love.graphics.newImage('images/specials/heath/boomparticle3.png'),
}

function heath:initialize(...)
	Character.initialize(self, ...)
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
		rotation = angle + math.pi/2,
		image = heath.special_images.fire_particle,
		t = 0,
		update = update_func,
		owner = fire.owner,
		name = "HeathFireParticle"
	}
end

--function particle_effects.SmallFire(gem)
function particle_effects.SmallFire(row, col, owner)
	local stage = game.stage

	--[[
		TODO: update the y-tracking:
			get the first_empty_row, and adjust as normal
			however, instead of moving directly to y_dest, only move at speed of SPEED.DROP
			this will make sure it moves along with the other gems, instead of instantly
	--]]
	--local first_empty_row = stage.grid:getFirstEmptyRow(gem.column)
	local first_empty_row = row
	local new_particle_t = 0
	local draw_t, draw_img = 0, 1
	-- it pops up and then settles at y_dest. Then it fades out if removed
	local draw_order = {1, 2, 3, 2, 4, 2, 5, 2}

	local update_func = function(self, dt)
		if self.turns_remaining == 1 then -- stop updating position after cleanup phase
			first_empty_row = stage.grid:getFirstEmptyRow(col)
		end
		local y_dest = stage.grid.y[first_empty_row]
		self.t = self.t + dt
		new_particle_t = new_particle_t + dt
		draw_t = draw_t + dt
		--[[
		if new_particle_t >= 0.2 then -- generate ember
			new_particle_t = new_particle_t - 0.2
			local fire_particle = particle_effects.FireParticle(self)
			particles.charEffects:new(fire_particle)
		end
		--]]

		if draw_t >= 0.1 then -- swap image
			draw_t = draw_t - 0.1
			draw_img = draw_img % #draw_order + 1
			--self.old_image = self.image
			--self.old_image_transparency = 255
			self.image = heath.special_images["testfire" .. draw_order[draw_img] ]
		end

		self.x = stage.grid.x[col]
		self.y = stage.grid.y[row] + (-self.t * 0.5 * stage.height) + (self.t^2 * stage.height)

		if self.scaling < 1 then -- scale in
			self.scaling = math.min(self.t * 2, 1)
			self.y = self.y + image.GEM_HEIGHT * self.t
		end

		if self.t > 0.2 then self.y = math.min(self.y, y_dest) end
		if self.turns_remaining < 0 then -- fadeout

			if not self.transparency then self.transparency = 255 end
			self.transparency = math.max(self.transparency - 8, 0)
			if self.transparency == 0 then self:remove() end
		end
	end
	--[[
	local draw_func = function(self, dt)
		pic.draw(self)
		if self.old_image then
			pic.draw(self, nil, nil, nil, nil, nil, {255, 255, 255, self.old_image_transparency}, self.old_image)
			self.old_image_transparency = self.old_image_transparency - 16
		end
	end
	--]]
	--[[
	local draw_func = function(self, dt)
		local trans = (self.transparency or 255)/255
		--local glow2 = trans * ((math.sin(self.t * 20) + 1) * 127.5)
		--local glow1 = trans * ((math.cos(self.t * 20) + 1) * 127.5)
		local trans1 = trans * 255
		--local trans2 = trans * ((math.sin(self.t * 20) + 1) * 127.5)
		local trans2 = math.sin(self.t * 20) > 0 and 255 * trans or 0
		pic.draw(self, nil, nil, nil, nil, nil, {255, 255, 255, trans1})
		pic.draw(self, nil, nil, nil, nil, nil, {255, 255, 255, trans2}, heath.special_images.fire2)
		--pic.draw(self, nil, nil, nil, nil, nil, {255, 255, 255, glow1}, heath.special_images.glow1)
		--pic.draw(self, nil, nil, nil, nil, nil, {255, 255, 255, glow2}, heath.special_images.glow2)
	end
	--]]
	return {
		x = stage.grid.x[col],
		y = stage.grid.y[row],
		rotation = 0,
		image = heath.special_images.testfire1,
		t = 0,
		update = update_func,
		turns_remaining = 1,
		owner = owner,
		name = "HeathFire",
		scaling = 0,
		--draw = draw_func
	}
end

function particle_effects.BoomParticle(boom)
	local stage = game.stage

	local x_vel = stage.gem_width * (math.random() - 0.5)
	local y_vel = stage.gem_height * -(math.random()*0.5 + 0.5)
	local gravity = stage.gem_height
	local update_func = function(self, dt)
		self.t = self.t + dt * 2
		self.x = boom.x + (self.t * x_vel)
		self.y = boom.y + (self.t * y_vel) + (self.t^2 * gravity * 0.5)
		local angle = math.atan2(y_vel + gravity * self.t, x_vel)
		self.rotation = angle - math.pi * 0.5
		if self.y > stage.height * 1.1 then self:remove() end
	end

	return {
		x = boom.x,
		y = boom.y,
		rotation = 0,
		image = heath.special_images["boomparticle"..math.random(1, 3)],
		t = 0,
		update = update_func,
		owner = owner,
		name = "HeathBoomParticle",
	}
end

function particle_effects.Boom(row, col, owner)
	local particles = game.particles
	local stage = game.stage

	local draw_t, draw_img = 0, 1
	local draw_order = {1, 2, 3, 4, 5}
	local already_boom_particled = false
	local update_func = function(self, dt)
		self.t, draw_t = self.t + dt, draw_t + dt
		if draw_t >= 0.1 then
			draw_t = draw_t - 0.1
			draw_img = draw_img + 1
			if draw_img > #draw_order then
				self:remove()
			else
				self:newImage(heath.special_images["boom"..draw_order[draw_img] ])
			end
		end
		if self.t >= 0.2 and not already_boom_particled then
			for i = 1, 10 do
				local boom_particle = particle_effects.BoomParticle(self)
				particles.charEffects:new(boom_particle)
			end
			already_boom_particled = true
		end
	end

	return {
		x = stage.grid.x[col],
		y = stage.grid.y[row],
		rotation = math.pi * 2 / math.random(1, 4),
		image = heath.special_images.boom1,
		t = 0,
		update = update_func,
		owner = owner,
		name = "HeathBoom",
	}
end

function heath:actionPhase(dt)
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
function heath:afterGravity()
	local particles = game.particles

	if game.scoring_combo > 0 then -- only check on the first round of gravity
		return {}
	end
	local own_tbl = {p1, p2}
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
	for col, turns in pairs(self.fire_columns) do
		for _, gem in pairs(bottom_gems) do
			if gem.column == col and gem.color ~= "RED" and own_tbl[gem.owner] == self.enemy then
				ouches = ouches + 1
				ouch_gems[#ouch_gems+1] = gem
			end
		end
	end
	if ouches > 0 then
		self.enemy.hand:addDamage(ouches)
		for i = 1, #ouch_gems do
			particles.dust:generateBigFountain(ouch_gems[i], 120, self) -- placeholder animation
			ret[#ret+1] = {1, particles.dust.generateBigFountain, particles.dust, ouch_gems[i], 120, self}
		end
	end
	return ret
end

-- Make fire for horizontal matches
-- Super-clear if super was active
function heath:beforeMatch(gem_table)
	local stage = game.stage

	local own_tbl = {p1, p2}

	-- store horizontal fire locations, used in aftermatch phase
	for _, gem in pairs(gem_table) do
		local owned = own_tbl[gem.owner] == self
		local top_gem = gem.row-1 == stage.grid:getFirstEmptyRow(gem.column)
		if owned and gem.horizontal and top_gem then
			self.pending_fires[#self.pending_fires+1] = {gem.row, gem.column, self}
		end
	end

	-- super
	if self.supering then
		self.super_this_turn = true
		local rows_to_clear = {}
		-- find out which rows to clear, add to a set
		for _, gem in pairs(gem_table) do
			local owned = own_tbl[gem.owner] == self
			if owned and gem.horizontal then
				rows_to_clear[gem.row] = true
				rows_to_clear[gem.row+1] = true
				rows_to_clear[gem.row-1] = true
			end
		end
		-- add clear-gems to gem_table for processing
		for gem in stage.grid:gems() do
			-- flag gems to clear
			local toclear = false
			for clear_row, _ in pairs(rows_to_clear) do
				if gem.row == clear_row then toclear = true end
			end
			-- add to super_clears list
			if toclear then	self.super_clears[#self.super_clears+1] = gem end
		end
	end
end

-- process the super_clears list
-- TODO: the piece the opponent played this turn is incorrectly counted as belong to him,
-- even if it didn't participate in a match.
-- TODO: warning - queue.add stage.grid.removeGem affects state

function heath:duringMatch(gem_table)
	local particles = game.particles
	local stage = game.stage

	if self.supering then
		-- update the grid and add the ownership to the super-clear gems
		stage.grid:updateGrid()
		for i = 1, #self.super_clears do self.super_clears[i]:addOwner(self) end

		-- first queue the super particles
		local own_tbl = {p1, p2}
		local current_columns, check_columns = {}, {} -- use these as sets
		--[[
		local still_need_checks = function()
			for k in pairs(check_columns) do return true end
			return false
		end
		--]]
		for i = 1, stage.grid.columns do check_columns[i] = true end
		for _, gem in pairs(gem_table) do
			if gem.horizontal and self == own_tbl[gem.owner] then
				current_columns[gem.column] = true
			end
		end

		local explode_round = 1 -- do the matched columns first, then expand outwards
		--while still_need_checks() do
		while next(check_columns) do
			for i = 1, #self.super_clears do -- make booms
				local gem = self.super_clears[i]
				if gem.owner ~= 3 and current_columns[gem.column] and check_columns[gem.column] then
					local boom_object = particle_effects.Boom(gem.row, gem.column, gem.owner)
					local delay = 3 + explode_round * 4
					queue.add(delay, particles.charEffects.new, particles.charEffects, boom_object)
					queue.add(delay, stage.grid.removeGem, stage.grid, gem) -- this is state-affecting!
				end
			end
			local add_columns = {} -- columns to check for next round
			for k in pairs(current_columns) do
				check_columns[k] = nil
				if k ~= 1 and k ~= stage.grid.columns then
					add_columns[k-1], add_columns[k+1] = true, true
				end
			end
			for k in pairs(add_columns) do current_columns[k] = true end
			explode_round = explode_round + 1
		end

		-- then process the gamestate and generate other particles
		-- TODO: don't generate damage if it was part of the gem_table match
		for i = 1, #self.super_clears do
			local gem = self.super_clears[i]
			local in_match_table = false
			for _, tblgem in pairs(gem_table) do
				if gem == tblgem then
					in_match_table = true
					break
				end
			end
			if gem.owner ~= 3 and not in_match_table then
				self.enemy.hand:addDamage(1)
				particles.damage:generate(gem)
			end
		end
	end
end


-- take away super meter
function heath:afterMatch()
	local particles = game.particles

	-- super
	if self.supering then
		self.cur_mp = 0
		self.super_clears = {}
		self.supering = false
	end

	-- horizontal match fires
	local makeFire = function(row, col, owner)
		self.fire_columns[col] = 1
		local fire_object = particle_effects.SmallFire(row, col, owner)
		particles.charEffects:new(fire_object)
	end

	for i = 1, #self.pending_fires do
		makeFire(unpack(self.pending_fires[i]))
	end
	self.pending_fires = {}
end

function heath:cleanup()
	-- particle update
	for _, particle in pairs(AllParticles.CharEffects) do
		if particle.owner == self and particle.name == "HeathFire" then
			particle.turns_remaining = particle.turns_remaining - 1
		end
	end

	-- fire column update
	for col, turns in pairs(self.fire_columns) do
		self.fire_columns[col] = turns - 1
		if self.fire_columns[col] < 0 then self.fire_columns[col] = nil end
	end

	for k, v in pairs(self.fire_columns) do
		--print("column " .. k .. ", " .. v .. " turns left")
	end
	self.current_rush_cost, self.current_double_cost = self.RUSH_COST, self.DOUBLE_COST
	self.supering = false
	self.super_this_turn = false
end

--[[
function heath:super()
	if self.cur_mp >= self.SUPER_COST then
	end
end
--]]

return heath
