--[[ Color: yellow
Passive: Only considers opponent's four columns.
At end of turn, the highest row of gems "blows" one column over away from the
casting Fuka. If there are multiple gems then all possible gems are blown.
Matches made in this way are attributed to the blowing Fuka.

Super: A tornado grabs up to the top 4 gems of Fuka's lowest column (random on
tie) and then drops the gems into the opponent's lowest column at a rate of one
gem per turn for (up to) 4 turns. (The order of gems dropped should be the
topmost grabbed gem to the bottommost).
--]]

local love = _G.love
local common = require "class.commons"
local Character = require "character"
local images = require "images"
local Pic = require "pic"

local Fuka = {}

Fuka.large_image = love.graphics.newImage('images/portraits/fuka.png')
Fuka.small_image = love.graphics.newImage('images/portraits/fukasmall.png')
Fuka.action_image = love.graphics.newImage('images/portraits/action_fuka.png')
Fuka.shadow_image = love.graphics.newImage('images/portraits/shadow_fuka.png')
Fuka.super_fuzz_image = love.graphics.newImage('images/ui/superfuzzyellow.png')

Fuka.character_name = "Fuka"
Fuka.meter_gain = {
	red = 4,
	blue = 4,
	green = 4,
	yellow = 8,
	none = 4,
	wild = 4,
}
Fuka.primary_colors = {"yellow"}

Fuka.super_images = {
	word = images.ui_super_text_yellow,
	empty = images.ui_super_empty_yellow,
	full = images.ui_super_full_yellow,
	glow = images.ui_super_glow_yellow,
	overlay = love.graphics.newImage('images/characters/fuka/fukalogo.png'),
}
Fuka.burst_images = {
	partial = images.ui_burst_part_yellow,
	full = images.ui_burst_full_yellow,
	glow = {images.ui_burst_partglow_yellow, images.ui_burst_fullglow_yellow}
}

Fuka.special_images = {
	leaf1 = love.graphics.newImage('images/characters/fuka/leaf1.png'),
	leaf2 = love.graphics.newImage('images/characters/fuka/leaf2.png'),
	poof = love.graphics.newImage('images/characters/fuka/poof.png'),
	tornado = {
		love.graphics.newImage('images/characters/fuka/tornado1.png'),
		love.graphics.newImage('images/characters/fuka/tornado2.png'),
	}
}

Fuka.sounds = {
	bgm = "bgm_fuka",
}

Fuka.MAX_MP = 48
Fuka.SUPER_COST = 48

function Fuka:init(...)
	Character.init(self, ...)
	self.should_activate_passive = true
	local game = self.game

	self.should_activate_tornado = false
	self.tornado_gems = {}
	self.moving_gems = {} -- for passive/super gem update

	-- init tornado image
	self.tornado_anim = self.fx.tornado.create(game, self)
	self.TORNADO_HEIGHT = self.tornado_anim.image:getHeight()
	self.TORNADO_WIDTH = self.tornado_anim.image:getWidth()
	self.TORNADO_TIME_PER_ROW = 12
	self.TORNADO_H_SPEED = 8 -- pixels per frame

	self.TORNADO_AT_TOP_ROW = 10 -- where it arrives at, at the top
end


-------------------------------------------------------------------------------
-- The tornado for super
local Tornado = {}
function Tornado:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
	self.game = manager.game
end

function Tornado:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function Tornado:appear(x, y)
	local APPEAR_DURATION = 10
	self:change{duration = 0, x = x, y = y}
	self:change{duration = APPEAR_DURATION, transparency = 1}
	self.destination_y = y

	return APPEAR_DURATION
end

function Tornado:disappear()
	local DISAPPEAR_DURATION = 10
	self:change{duration = DISAPPEAR_DURATION, transparency = 0}
	self:change{duration = 0, x = self.tornado_init_x, y = self.tornado_init_y}
	self.destination_y = self.tornado_init_y

	return DISAPPEAR_DURATION
end

function Tornado:acquireGem(gem)
	self.owner.fx.tornadoGem.generate(self.owner.game, self.owner, gem)
end

function Tornado:moveToColumn(column)
	local grid = self.game.grid

	local dest_x = grid.x[column]
	local dist = dest_x - self.x
	local duration = math.ceil(math.abs(dist) / self.owner.TORNADO_H_SPEED)

	self:change{duration = duration, x = dest_x}

	return duration
end

function Tornado:releaseGem()
	-- a lot of tornadoFloatPoofs
	return 0
end

-- Tornado initially appears offscreen
function Tornado.create(game, owner)
	local params = {
		init_x = game.stage.x_mid,
		init_y = game.stage.height * 2,
		x = game.stage.x_mid,
		y = game.stage.height * 2,
		image = owner.special_images.tornado[1],
		image_index = 1,
		SWAP_FRAMES = 30,
		frames_until_swap = 15,
		POOF_FRAMES = 15,
		frames_until_poof = 8,
		owner = owner,
		transparency = 0,
		player_num = owner.player_num,
		destination_y = game.stage.height * 2,
		name = "FukaTornado",
	}

	return common.instance(Tornado, game.particles, params)
end

function Tornado:update(dt)
	Pic.update(self, dt)
	self.frames_until_swap = self.frames_until_swap - 1
	if self.frames_until_swap <= 0 then
		self.frames_until_swap = self.SWAP_FRAMES
		local num_tornados = #self.owner.special_images.tornado
		self.image_index = self.image_index % num_tornados + 1
		local new_image = self.owner.special_images.tornado[self.image_index]
		self:newImageFadeIn(new_image, self.SWAP_FRAMES)
	end

	self.frames_until_poof = self.frames_until_poof - 1
	if self.frames_until_poof <= 0 then
		self.frames_until_poof = self.POOF_FRAMES
		self.owner.fx.tornadoMovePoof.generate(self.owner.game, self.owner, self)
		self.owner.fx.tornadoFloatPoof.generate(self.owner.game, self.owner, self)
	end
end

Tornado = common.class("Tornado", Tornado, Pic)

-------------------------------------------------------------------------------
-- gem images that are in the tornado
local TornadoGem = {}
function TornadoGem:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
end

function TornadoGem:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function TornadoGem:removeAnim()
end

function TornadoGem.generate(game, owner, gem)
	local params = {
		x = gem.x,
		y = gem.y,
		image = gem.image,
		gem = gem,
		x_wave_time = 0,
		y_wave_time = 0,
		owner = owner,
		player_num = owner.player_num,
		name = "FukaTornadoGem",
	}

	common.instance(TornadoGem, game.particles, params)
end

function TornadoGem:update(dt)
	-- if gem not in self.owner.tornado_gems, remove this image with the fadeout
	local gem_still_exists = false
	for i = 1, #self.owner.tornado_gems do
		if self.owner.tornado_gems[i] == self.gem then gem_still_exists = true end
	end

	if not gem_still_exists then
		self:removeAnim()
		self:remove()
		return
	end

	local X_PERIOD, Y_PERIOD = 120, 60
	self.x_wave_time = (self.x_wave_time + 2 * math.pi / X_PERIOD) % (2 * math.pi)
	self.y_wave_time = (self.y_wave_time + 2 * math.pi / Y_PERIOD) % (2 * math.pi)

	local tornado = self.owner.tornado_anim
	local x = math.sin(self.x_wave_time) * images.GEM_WIDTH + tornado.x
	local y = math.sin(self.y_wave_time) * images.GEM_HEIGHT / 2 + tornado.y

	local position -- find gem position to find its scaling
	for i = 1, #self.owner.tornado_gems do
		if self.owner.tornado_gems[i] == self.gem then position = i end
	end
	assert(position, "TornadoGem gem not found")

	local pos_from_first = #self.owner.tornado_gems - position
	local scaling = 0.8 ^ pos_from_first
	local transparency = 0.8 - 0.1 * pos_from_first

	self:change{x = x, y = y, scaling = scaling, transparency = transparency}
end

TornadoGem = common.class("TornadoGem", TornadoGem, Pic)

-------------------------------------------------------------------------------
-- Poofs that regularly come out of the tornado
local TornadoMovePoof = {}
function TornadoMovePoof:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
end

function TornadoMovePoof:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function TornadoMovePoof.generate(game, owner, tornado)
	local sign = math.random() > 0.5 and 1 or -1
	local image = owner.special_images.poof
	local h_flip = math.random() > 0.5 and true or false
	local v_flip = math.random() > 0.5 and true or false
	local x = tornado.x - (math.random() * 0.1 + 0.4) * tornado.width * sign
	local y = tornado.y + (math.random() * 0.1 + 0.4) * tornado.height

	-- create two images, one under and one over
	local p1_params = {
		x = x,
		y = y,
		image = image,
		owner = owner,
		player_num = owner.player_num,
		scaling = 0,
		h_flip = h_flip,
		v_flip = v_flip,
		draw_order = 2,
		name = "FukaTornadoMovePoof",
	}
	local p2_params = {
		x = x,
		y = y,
		image = image,
		owner = owner,
		player_num = owner.player_num,
		scaling = 0,
		h_flip = h_flip,
		v_flip = v_flip,
		draw_order = -2,
		name = "FukaTornadoMovePoof",
	}

	local p_over = common.instance(TornadoMovePoof, game.particles, p1_params)
	local p_under = common.instance(TornadoMovePoof, game.particles, p2_params)

	local SEGMENT_TIME = 30
	local FADE_TIME = 5
	local x0 = x
	local y0 = y
	local x1 = tornado.x + (math.random() * 0.1 + 0.4) * tornado.width * sign
	local y1 = tornado.y + (math.random() * 0.1 + 0.12) * tornado.height
	local x2 = tornado.x - (math.random() * 0.1 + 0.4) * tornado.width * sign
	local y2 = tornado.y + (math.random() * 0.1 - 0.22) * tornado.height
	local x3 = tornado.x + (math.random() * 0.1 + 0.4) * tornado.width * sign
	local y3 = tornado.y + (math.random() * 0.1 - 0.5) * tornado.height

	--[[
	-- adjustments to y-position if the tornado is moving up
	-- temporarily disabled because it looks bad
	if tornado.y ~= tornado.destination_y then
		local y_per_frame = images.GEM_HEIGHT / owner.TORNADO_TIME_PER_ROW

		local y0_adjust = y_per_frame * FADE_TIME
		local y1_adjust = y_per_frame * (FADE_TIME + SEGMENT_TIME)
		local y2_adjust = y_per_frame * (FADE_TIME + SEGMENT_TIME * 2)
		local y3_adjust = y_per_frame * (FADE_TIME + SEGMENT_TIME * 3)
		local max_y_adjust = tornado.y - tornado.destination_y

		y0 = y0 - math.min(y0_adjust, max_y_adjust)
		y1 = y1 - math.min(y1_adjust, max_y_adjust)
		y2 = y2 - math.min(y2_adjust, max_y_adjust)
		y3 = y3 - math.min(y3_adjust, max_y_adjust)
	end
	--]]

	local curve1 = love.math.newBezierCurve(x0, y0, x1, y0, x1, y1)
	local curve2 = love.math.newBezierCurve(x1, y1, x1, y2, x2, y2)
	local curve3 = love.math.newBezierCurve(x2, y2, x3, y2, x3, y3)

	p_over:change{transparency = sign * 0.5 + 0.5}
	p_under:change{transparency = sign * -0.5 + 0.5}

	p_over:change{duration = FADE_TIME, scaling = 1}
	p_under:change{duration = FADE_TIME, scaling = 1}

	p_over:change{duration = SEGMENT_TIME, curve = curve1, easing = "inOutQuad"}
	p_under:change{duration = SEGMENT_TIME, curve = curve1, easing = "inOutQuad"}

	p_over:change{duration = 1, transparency = sign * -0.5 + 0.5}
	p_under:change{duration = 1, transparency = sign * 0.5 + 0.5}

	p_over:change{duration = SEGMENT_TIME, curve = curve2, easing = "inOutQuad"}
	p_under:change{duration = SEGMENT_TIME, curve = curve2, easing = "inOutQuad"}

	p_over:change{duration = 1, transparency = sign * 0.5 + 0.5}
	p_under:change{duration = 1, transparency = sign * -0.5 + 0.5}

	p_over:change{duration = SEGMENT_TIME, curve = curve3, easing = "inOutQuad"}
	p_under:change{duration = SEGMENT_TIME, curve = curve3, easing = "inOutQuad"}

	p_over:change{duration = FADE_TIME, transparency = sign * -0.5 + 0.5, remove = true}
	p_under:change{duration = FADE_TIME, transparency = sign * 0.5 + 0.5, remove = true}
end

TornadoMovePoof = common.class("TornadoMovePoof", TornadoMovePoof, Pic)

-------------------------------------------------------------------------------
-- Poofs that regularly come out of the tornado
local TornadoFloatPoof = {}
function TornadoFloatPoof:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
end

function TornadoFloatPoof:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function TornadoFloatPoof.generate(game, owner, tornado)
	local x = tornado.x + (math.random() - 0.5) * tornado.width
	local y = tornado.y + (math.random() - 0.5) * tornado.height

	local params = {
		x = x,
		y = y,
		image = owner.special_images.poof,
		owner = owner,
		player_num = owner.player_num,
		scaling = 0,
		h_flip = math.random() > 0.5 and true or false,
		v_flip = math.random() > 0.5 and true or false,
		draw_order = math.random() > 0.5 and 2 or -2,
		name = "FukaTornadoFloatPoof",
	}

	local p = common.instance(TornadoFloatPoof, game.particles, params)

	p:change{duration = 10, scaling = 1}
	p:change{duration = 40, scaling = 2, transparency = 0, remove = true}
end

TornadoFloatPoof = common.class("TornadoFloatPoof", TornadoFloatPoof, Pic)

-------------------------------------------------------------------------------
local Leaves = {}
function Leaves:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
end

function Leaves:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function Leaves.generate(game, owner, delay)
	local stage = game.stage
	for _ = 1, 4 do
		local x1, x2, x3, y1, y2, y3

		local sign
		if owner.player_num == 1 then
			sign = 1
		elseif owner.player_num == 2 then
			sign = -1
		else
			error("Invalid owner.player_num!")
		end

		-- starting x, y
		if math.random() > 0.5 then -- left side
			x1 = 0.5 * (1 - sign) * stage.width
			y1 = math.random() * stage.height * 0.5
		else
			x1 = ((math.random() * 0.5) + (0.25 * (1 - sign))) * stage.width
			y1 = 0
		end

		-- ending x, y
		x3 = ((math.random() * 0.5) + (0.25 * (1 + sign))) * stage.width
		y3 = ((math.random() * 0.5) + 0.5) * stage.height

		-- bezier intermediate x, y
		x2 = x1
		y2 = y3

		local curve = love.math.newBezierCurve(x1, y1, x2, y2, x3, y3)

		local leaf_image
		if math.random() > 0.5 then
			leaf_image = owner.special_images.leaf1
		else
			leaf_image = owner.special_images.leaf2
		end

		local params = {
			x = x1,
			y = y1,
			image = leaf_image,
			transparency = 0,
			owner = owner,
			player_num = owner.player_num,
			name = "FukaLeaves",
		}

		local p = common.instance(Leaves, game.particles, params)

		local rotation = math.random() * 10

		p:wait(delay)
		p:change{duration = 5, transparency = 1}
		p:change{
			duration = 45,
			curve = curve,
			rotation = rotation,
			remove = true,
		}
	end
end

Leaves = common.class("Leaves", Leaves, Pic)

-------------------------------------------------------------------------------
-- currently unused, previously would appear when gem moves
local GemBorderPoofs = {}
function GemBorderPoofs:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
end

function GemBorderPoofs:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function GemBorderPoofs.generate(game, owner, gem)
	local total_poofs = math.random(2, 4)

	for _ = 1, total_poofs do
		local x, y
		local rnd = math.random()
		if rnd > 0.75 then -- top
			x = gem.x + (math.random() - 0.5) * gem.width
			y = gem.y - (0.5 * gem.height)
		elseif rnd > 0.5 then -- bottom
			x = gem.x + (math.random() - 0.5) * gem.width
			y = gem.y + (0.5 * gem.height)
		elseif rnd > 0.25 then -- left
			x = gem.x - (0.5 * gem.width)
			y = gem.y + (math.random() - 0.5) * gem.height
		else -- right
			x = gem.x + (0.5 * gem.width)
			y = gem.y + (math.random() - 0.5) * gem.height
		end

		local params = {
			x = x,
			y = y,
			image = owner.special_images.poof,
			owner = owner,
			player_num = owner.player_num,
			scaling = 0,
			h_flip = math.random() > 0.5 and true or false,
			v_flip = math.random() > 0.5 and true or false,
			draw_order = math.random() > 0.5 and 1 or -1,
			name = "FukaGemBorderPoofs",
		}

		local p = common.instance(GemBorderPoofs, game.particles, params)

		p:change{duration = 10, scaling = 1}
		p:change{duration = 40, scaling = 2, transparency = 0, remove = true}
	end
end

GemBorderPoofs = common.class("GemBorderPoofs", GemBorderPoofs, Pic)

-------------------------------------------------------------------------------

Fuka.fx = {
	tornado = Tornado,
	tornadoGem = TornadoGem,
	tornadoMovePoof = TornadoMovePoof,
	tornadoFloatPoof = TornadoFloatPoof,
	leaves = Leaves,
	gemBorderPoofs = GemBorderPoofs,
}

-------------------------------------------------------------------------------

--[[ Find lowest column non-empty in all own columns, select randomly if more
	than one. Put up to 4 of the top gems in that column into the tornado. --]]
function Fuka:_activateSuper()
	local game = self.game
	local grid = game.grid

	local MAX_GEMS_PICKED_UP = 4
	local delay = 0

	local EXTRA_ROWS = 2 -- extra rows to appear below basin bottom
	local START_ROW = grid.BASIN_END_ROW + EXTRA_ROWS

	local START_Y = grid.y[grid.BASIN_END_ROW] + EXTRA_ROWS * images.GEM_HEIGHT
	local END_Y =  grid.y[self.TORNADO_AT_TOP_ROW]

	local TOTAL_ROWS = START_ROW - self.TORNADO_AT_TOP_ROW
	local TOTAL_MOVE_DURATION = self.TORNADO_TIME_PER_ROW * TOTAL_ROWS

	-- don't activate the tornado this turn if it was empty to start
	if not self.tornado_gems[1] then self.should_activate_tornado = false end

	-- find lowest column for the tornado to pick up gems from
	local lowest_row = 0
	for i in grid:cols(self.player_num) do
		local row = grid:getFirstEmptyRow(i) + 1
		if row > lowest_row and row ~= grid.BASIN_END_ROW + 1 then
			lowest_row = row -- ignore empty columns
		end
	end

	if lowest_row ~= 0 then -- exclude totally empty basin
		local lowest_cols = {}
		for i in grid:cols(self.player_num) do
			local row = grid:getFirstEmptyRow(i) + 1
			if row == lowest_row then lowest_cols[#lowest_cols + 1] = i end
		end

		local rand = game.rng:random(#lowest_cols)
		local selected_col = lowest_cols[rand]

		-- tornado appears
		local disappear_delay = self.tornado_anim:disappear()
		local START_X = grid.x[selected_col]
		local appear_delay = self.tornado_anim:appear(START_X, START_Y)
		delay = delay + disappear_delay + appear_delay

		-- move tornado to top
		self.tornado_anim:change{y = END_Y, duration = TOTAL_MOVE_DURATION}
		self.tornado_anim.destination_y = END_Y

		delay = delay + TOTAL_MOVE_DURATION

		-- identify the gems to be picked up
		local temp_gems = {} -- Top gem is in index 1, and so on
		for i = 1, MAX_GEMS_PICKED_UP do
			local gem_row = grid:getFirstEmptyRow(selected_col) + i
			if gem_row <= grid.BASIN_END_ROW then
				local gem = grid[gem_row][selected_col].gem
				if gem then temp_gems[#temp_gems + 1] = gem end
			end
		end

		-- append to existing tornado gems, preserving LIFO
		for i = #temp_gems, 1, -1 do
			local gem = temp_gems[i]
			local WAIT_TIME = (START_ROW - gem.row) * self.TORNADO_TIME_PER_ROW
			if not gem.indestructible then
				local removeGem = function()
					self.tornado_gems[#self.tornado_gems + 1] = gem
					grid[gem.row][gem.column].gem = false
					self.tornado_anim:acquireGem(gem)
				end

				game.queue:add(WAIT_TIME, removeGem)
			end
		end
	end

	self:emptyMP()

	return delay
end

-- drop a gem from the tornado at end of turn
function Fuka:_activateTornado()
	local delay = 0

	local to_drop_gem = self.tornado_gems[#self.tornado_gems]

	if to_drop_gem and self.should_activate_tornado then
		local game = self.game
		local grid = self.game.grid

		-- Find lowest column in enemy basin to drop gem into
		local lowest_row = 0
		for i in grid:cols(self.enemy.player_num) do
			local row = grid:getFirstEmptyRow(i) + 1
			if row > lowest_row then lowest_row = row end
		end

		local lowest_cols = {}
		for i in grid:cols(self.enemy.player_num) do
			local row = grid:getFirstEmptyRow(i) + 1
			if row == lowest_row then lowest_cols[#lowest_cols + 1] = i end
		end

		local rand = game.rng:random(#lowest_cols)
		local selected_col = lowest_cols[rand]

		-- Flag and drop gem, then pop from tornado_gems
		to_drop_gem:setOwner(self.player_num, false)
		self.moving_gems[to_drop_gem] = true

		grid[self.TORNADO_AT_TOP_ROW][selected_col].gem = to_drop_gem
		to_drop_gem.row = self.TORNADO_AT_TOP_ROW
		to_drop_gem.column = selected_col
		to_drop_gem.x = grid.x[selected_col]
		to_drop_gem.y = grid.y[self.TORNADO_AT_TOP_ROW]

		local move_delay = self.tornado_anim:moveToColumn(selected_col)
		local anim_delay = self.tornado_anim:releaseGem()

		to_drop_gem.transparency = 0 -- hide gem until delay ends

		-- when delay ends, show real gem and delete tornado gem image
		local reappear = function()
			to_drop_gem.transparency = 1
			self.tornado_gems[#self.tornado_gems] = nil
		end

		self.game.queue:add(move_delay + anim_delay, reappear)

		-- move gem to destination
		if move_delay > 0 then to_drop_gem:wait(move_delay) end
		if anim_delay > 0 then to_drop_gem:wait(anim_delay) end

		local dest_row = grid:getFirstEmptyRow(selected_col)
		grid:moveGem(to_drop_gem, dest_row, selected_col)
		local grid_drop_delay = grid:moveGemAnim(to_drop_gem, dest_row, selected_col)

		delay = move_delay + anim_delay + grid_drop_delay
	end

	self.should_activate_tornado = false

	return delay
end

-- returns the animation time and whether to go to gravity phase
function Fuka:_activatePassive()
	local grid = self.game.grid

	local check_columns = {}
	local columns = {}
	local to_move_gems = {}
	local should_create_leaves = false
	local animation_delay = 0
	local go_to_gravity_phase = false

	if self.player_num == 1 then
		check_columns = {8, 7, 6, 5}
	elseif self.player_num == 2 then
		check_columns = {1, 2, 3, 4}
	else
		error("Fuka has invalid player_num!")
	end

	-- get top row
	local top_row = grid.BOTTOM_ROW
	for _, col in ipairs(check_columns) do
		columns[col] = grid:getFirstEmptyRow(col)
		if columns[col] < top_row then top_row = columns[col] end
	end

	-- get column(s) with highest gem
	for _ , col in ipairs(check_columns) do
		if columns[col] == top_row then
			to_move_gems[#to_move_gems + 1] = grid[top_row + 1][col].gem
		end
	end

	if top_row ~= grid.BOTTOM_ROW then
		for i = 1, #to_move_gems do
			local to_move_gem = to_move_gems[i]

			if (to_move_gem.column ~= 1) and (to_move_gem.column ~= 8) then
				local sign
				if self.player_num == 1 then
					sign = 1
				elseif self.player_num == 2 then
					sign = -1
				else
					error("Fuka has an invalid player_num. Sad!")
				end

				local dest_row = to_move_gem.row
				local dest_col = to_move_gem.column + (1 * sign)

				-- only move gem if there's no gem already there
				if not grid[dest_row][dest_col].gem then
					-- flag gem
					to_move_gem:setOwner(self.player_num, false)

					self.moving_gems[to_move_gem] = true

					grid:moveGemAnim(to_move_gem, dest_row, dest_col, 40, 30)
					animation_delay = 70
					go_to_gravity_phase = true
					should_create_leaves = true

					-- move gem
					grid:moveGem(to_move_gem, dest_row, dest_col)
				end
			end
		end
	end

	-- curved descent leaf animations
	if should_create_leaves then
		for frame = 0, 110, 10 do
			self.fx.leaves.generate(self.game, self, frame)
		end
	end

	return animation_delay, go_to_gravity_phase
end

-------------------------------------------------------------------------------

function Fuka:beforeGravity()
	local delay = 0

	if self.is_supering then
		delay = self:_activateSuper()
		self.is_supering = false
	end

	return delay
end

function Fuka:beforeTween()
	self.game:brightenScreen(self.player_num)
end

function Fuka:afterAllMatches()
	local delay = self:_activateTornado()

	return delay
end

function Fuka:beforeCleanup()
	local delay = 0
	local go_to_gravity_phase = false

	-- activate passive wind blow
	if self.should_activate_passive then
		delay, go_to_gravity_phase = self:_activatePassive()
		self.should_activate_passive = false
	end

	return delay, go_to_gravity_phase
end

function Fuka:cleanup()
	self.should_activate_passive = true
	self.should_activate_tornado = true
	--[[
	if tornado has at least one gem:
		move the tornado to the appropriate column
	else:
		disappear it
	--]]
end

function Fuka:update(dt)
	--[[ Update the position of gems being moved by passive/super.
		Gems normally only update when phase.lua calls grid:updateGravity(dt)
		This forces them to update every frame.
	--]]
	for gem in pairs(self.moving_gems) do
		gem:update(dt)
		if gem:isStationary() then
			self.moving_gems[gem] = nil
		end
	end
end

return common.class("Fuka", Fuka, Character)
