--[[ Color: yellow
Passive: Only considers opponent's four columns.
At end of turn, the highest row of gems "blows" one column over away from the
casting Gail. If there are multiple gems then all possible gems are blown.
Matches made in this way are attributed to the blowing Gail.

Super: A tornado grabs up to the top 4 gems of Gail's lowest column (random on
tie) and then drops the gems into the opponent's lowest column at a rate of one
gem per turn for (up to) 4 turns. (The order of gems dropped should be the
topmost grabbed gem to the bottommost).

Super Animations:
Tornado fades between Tornado 1 and 2, just like Walter fountain. Poofs (random
x and y) constantly appear and follow SWIRL PATTERN (see attached image)

Tornado slides in from the bottom, along the column it initially affects, and
the affected gems follow SWIRL PATTERN, but disappear behind the tornado rather
than fade out. When it reaches the top it slides (smooth slide, not a linear
slide AND NOT A FUCKING BOUNCE) to the column it's going to attack. If it ever
changes columns, it smooth slides again. (NO BOUNCE)

Gems just drop from the tornado the way gems drop.
--]]

local love = _G.love
local common = require "class.commons"
local Character = require "character"
local images = require "images"
local Pic = require "pic"

local Gail = {}

Gail.large_image = love.graphics.newImage('images/portraits/gail.png')
Gail.small_image = love.graphics.newImage('images/portraits/gailsmall.png')
Gail.action_image = love.graphics.newImage('images/portraits/action_gail.png')
Gail.shadow_image = love.graphics.newImage('images/portraits/shadow_gail.png')
Gail.super_fuzz_image = love.graphics.newImage('images/ui/superfuzzyellow.png')

Gail.character_name = "Gail"
Gail.meter_gain = {
	red = 4,
	blue = 4,
	green = 4,
	yellow = 8,
	none = 4,
	wild = 4,
}
Gail.primary_colors = {"yellow"}

Gail.super_images = {
	word = images.ui_super_text_yellow,
	empty = images.ui_super_empty_yellow,
	full = images.ui_super_full_yellow,
	glow = images.ui_super_glow_yellow,
	overlay = love.graphics.newImage('images/characters/gail/gaillogo.png'),
}
Gail.burst_images = {
	partial = images.ui_burst_part_yellow,
	full = images.ui_burst_full_yellow,
	glow = {images.ui_burst_partglow_yellow, images.ui_burst_fullglow_yellow}
}

Gail.special_images = {
	leaf1 = love.graphics.newImage('images/characters/gail/leaf1.png'),
	leaf2 = love.graphics.newImage('images/characters/gail/leaf2.png'),
	poof = love.graphics.newImage('images/characters/gail/poof.png'),
	tornado = {
		love.graphics.newImage('images/characters/gail/tornado1.png'),
		love.graphics.newImage('images/characters/gail/tornado2.png'),
	}
}

Gail.sounds = {
	bgm = "bgm_gail",
}

function Gail:init(...)
	Character.init(self, ...)
	self.should_activate_passive = true
	local game = self.game

	self.should_activate_tornado = false
	self.tornado_gems = {}
	self.moving_gems = {} -- for passive gem update

	-- init tornado image
	self.tornado_anim = self.fx.tornado.create(game, self)
	self.TORNADO_HEIGHT = self.tornado_anim.image:getHeight()
	self.TORNADO_WIDTH = self.tornado_anim.image:getWidth()
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

	return APPEAR_DURATION
end

function Tornado:disappear()
	local DISAPPEAR_DURATION = 10
	self:change{duration = DISAPPEAR_DURATION, transparency = 0}
	self:change{duration = 0, x = self.tornado_init_x, y = self.tornado_init_y}

	return DISAPPEAR_DURATION
end

function Tornado:acquireGem(gem)
end

function Tornado:releaseGem(column)
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
		name = "GailTornado",
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
	local starting_pos = math.random() > 0.5 and "left" or "right"
	local sign = math.random() > 0.5 and 1 or -1
	local image = owner.special_images.poof
	local h_flip = math.random() > 0.5 and true or false
	local v_flip = math.random() > 0.5 and true or false
	local x = tornado.x + (math.random() * 0.1 + 0.4) * tornado.width * sign
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
		name = "GailTornadoMovePoof",
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
		name = "GailTornadoMovePoof",
	}

	local p_over = common.instance(TornadoMovePoof, game.particles, p1_params)
	local p_under = common.instance(TornadoMovePoof, game.particles, p2_params)

	local SEGMENT_TIME = 10
	local FADE_TIME = 5
	local X1 = tornado.x + (math.random() * 0.1 + 0.4) * tornado.width * sign
	local Y1 = tornado.y + (math.random() * 0.1 + 0.12) * tornado.height
	local X2 = tornado.x - (math.random() * 0.1 + 0.4) * tornado.width * sign
	local Y2 = tornado.y + (math.random() * 0.1 - 0.22) * tornado.height
	local X3 = tornado.x + (math.random() * 0.1 + 0.4) * tornado.width * sign
	local Y3 = tornado.y + (math.random() * 0.1 - 0.5) * tornado.height

	p_over:change{transparency = sign * 0.5 + 0.5}
	p_under:change{transparency = sign * -0.5 + 0.5}

	p_over:change{duration = FADE_TIME, scaling = 1}
	p_under:change{duration = FADE_TIME, scaling = 1}

	p_over:change{duration = SEGMENT_TIME, x = X1, y = Y1, easing = "inOutQuad"}
	p_under:change{duration = SEGMENT_TIME, x = X1, y = Y1, easing = "inOutQuad"}

	p_over:change{duration = 1, transparency = sign * -0.5 + 0.5}
	p_under:change{duration = 1, transparency = sign * 0.5 + 0.5}

	p_over:change{duration = SEGMENT_TIME, x = X2, y = Y2, easing = "inOutQuad"}
	p_under:change{duration = SEGMENT_TIME, x = X2, y = Y2, easing = "inOutQuad"}

	p_over:change{duration = 1, transparency = sign * 0.5 + 0.5}
	p_under:change{duration = 1, transparency = sign * -0.5 + 0.5}

	p_over:change{duration = SEGMENT_TIME, x = X3, y = Y3, easing = "inOutQuad"}
	p_under:change{duration = SEGMENT_TIME, x = X3, y = Y3, easing = "inOutQuad"}

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
		name = "GailTornadoFloatPoof",
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
			name = "GailLeaves",
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
			name = "GailGemBorderPoofs",
		}

		local p = common.instance(GemBorderPoofs, game.particles, params)

		p:change{duration = 10, scaling = 1}
		p:change{duration = 40, scaling = 2, transparency = 0, remove = true}
	end
end

GemBorderPoofs = common.class("GemBorderPoofs", GemBorderPoofs, Pic)

-------------------------------------------------------------------------------

Gail.fx = {
	tornado = Tornado,
	tornadoMovePoof = TornadoMovePoof,
	tornadoFloatPoof = TornadoFloatPoof,
	leaves = Leaves,
	gemBorderPoofs = GemBorderPoofs,
}

-------------------------------------------------------------------------------

--[[ Find lowest column non-empty in all own columns, select randomly if more
	than one. Put up to 4 of the top gems in that column into the tornado. --]]
function Gail:_activateSuper()
	local game = self.game
	local stage = game.stage
	local grid = game.grid

	local MAX_GEMS_PICKED_UP = 4
	local delay = 0

	local TORNADO_TOP_Y = grid.y[10]
	local AT_GEM_DELAY = 10 -- pause at each gem
	local MOVE_TO_NEXT_GEM = 10 -- time taken to move to next gem
	local MOVE_TO_TOP = 30 -- time taken to move to top of screen

	-- time taken to move to first gem. Subtract MOVE_TO_NEXT GEM because
	-- the code makes it move to the first gem twice lol
	local MOVE_TO_FIRST = 30 - MOVE_TO_NEXT_GEM


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

		local start_x = grid.x[selected_col]
		local start_y = stage.height + self.TORNADO_HEIGHT
		local appear_delay = self.tornado_anim:appear(start_x, start_y)
		delay = delay + disappear_delay + appear_delay

		-- identify the gems
		local temp_gems = {} -- Top gem is in index 1, and so on
		for i = 1, MAX_GEMS_PICKED_UP do
			local gem_row = grid:getFirstEmptyRow(selected_col) + i
			if gem_row <= grid.BASIN_END_ROW then
				local gem = grid[gem_row][selected_col].gem
				if gem then temp_gems[#temp_gems + 1] = gem end
			end
		end

		-- move tornado to "last" gem (first to get picked up)
		local first_gem_y = temp_gems[#temp_gems].y
		self.tornado_anim:change{y = first_gem_y, duration = MOVE_TO_FIRST}
		delay = delay + MOVE_TO_FIRST

		-- append to existing tornado gems, preserving LIFO
		for i = #temp_gems, 1, -1 do
			local gem = temp_gems[i]
			self.tornado_anim:change{y = gem.y, duration = MOVE_TO_NEXT_GEM}
			self.tornado_anim:wait(AT_GEM_DELAY)
			delay = delay + MOVE_TO_NEXT_GEM + AT_GEM_DELAY

			-- move tornado to the new place and pause there
			if not gem.indestructible then
				self.tornado_gems[#self.tornado_gems + 1] = gem
				grid[gem.row][gem.column].gem = false
			end
		end

		self.tornado_anim:change{y = TORNADO_TOP_Y, duration = MOVE_TO_TOP}
		delay = delay + MOVE_TO_TOP
	end

	self:emptyMP()

	return delay
end

-- returns the animation time and whether to go to gravity phase
function Gail:_activatePassive()
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
		error("Gail has invalid player_num!")
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
					error("Gail has an invalid player_num. Sad!")
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

function Gail:beforeGravity()
	local delay = 0

	if self.is_supering then
		delay = self:_activateSuper()
		self.is_supering = false
	end

	return delay
--[[
	Super: A tornado grabs up to the top 4 gems of Gail's lowest column (random on
tie) and then drops the gems into the opponent's lowest column at a rate of one
gem per turn for (up to) 4 turns. (The order of gems dropped should be the
topmost grabbed gem to the bottommost). The tornado drop happens before the
regular gems are dropped. Any matches made are credited to the casting Gail.

The drop from tornado gems are flagged as owned by Gail
The drop from tornado happens in AfterAllMatches phase.
--]]
end

function Gail:beforeTween()
	self.game:brightenScreen(self.player_num)
end

function Gail:afterAllMatches()
	--[[ Super 2
	if self.should_activate_tornado:
		Determine lowest column in all enemy columns
		If more than one: select randomly
		if tornado[1]:
			Pop tornado[1] gem
			Flag gem as owned by Gail
			Move gem into enemy's lowest column
	self.should_activate_tornado = false
	--]]
end

function Gail:beforeCleanup()
	local delay = 0
	local go_to_gravity_phase = false

	-- activate passive wind blow
	if self.should_activate_passive then
		delay, go_to_gravity_phase = self:_activatePassive()
		self.should_activate_passive = false
	end

	return delay, go_to_gravity_phase
end

function Gail:cleanup()
	self.should_activate_passive = true
	self.should_activate_tornado = true
	--[[
	if tornado has at least one gem:
		move the tornado to the appropriate column
	else:
		disappear it
	--]]
end

function Gail:update(dt)
	--[[ Update the position of gems being moved by passive.
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

return common.class("Gail", Gail, Character)
