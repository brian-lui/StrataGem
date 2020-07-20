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
	local stage = game.stage

	self.should_activate_tornado = false
	self.tornado_gems = {}

	-- init tornado image
	self.tornado_anim = self.fx.tornado.create(game, self)

	-- TODO: just testing anim
	self.tornado_anim:appear(stage.width * 0.8, stage.height * 0.8)
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
	self:change{duration = 0, x = x, y = y}
	self:change{duration = 10, transparency = 1}
end

function Tornado:disappear()
	self:change{duration = 10, transparency = 0}
	self:change{duration = 0, x = self.tornado_init_x, y = self.tornado_init_y}
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
		self.owner.fx.tornadoPoof.generate(self.owner.game, self.owner, self)
	end
end

Tornado = common.class("Tornado", Tornado, Pic)

-------------------------------------------------------------------------------
-- Poofs that regularly come out of the tornado
local TornadoPoof = {}
function TornadoPoof:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	local counter = self.game.inits.ID.particle
	manager.allParticles.CharEffects[counter] = self
	self.manager = manager
end

function TornadoPoof:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function TornadoPoof.generate(game, owner, tornado)
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
		name = "GailTornadoPoof",
	}

	local p = common.instance(TornadoPoof, game.particles, params)

	p:change{duration = 10, scaling = 1}
	p:change{duration = 40, scaling = 2, transparency = 0, remove = true}
end

TornadoPoof = common.class("TornadoPoof", TornadoPoof, Pic)

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
	tornadoPoof = TornadoPoof,
	leaves = Leaves,
	gemBorderPoofs = GemBorderPoofs,
}

-------------------------------------------------------------------------------

--[[ Super 1
	Find lowest column in all own columns
	If more than one: select randomly

	Select up to 4 of the top gems in that column
	Move them to the tornado, starting from the top gem
--]]
function Gail:_activateSuper()
	--[[
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
	--]]
end

function Gail:beforeGravity()
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
		local grid = self.game.grid

		local check_columns = {}
		local columns = {}
		local to_move_gems = {}

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
			print("first empty row", top_row)
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

						-- move gem animation
						-- TODO: This is bugged because the gem doesn't immediately animate in this phase
						grid:moveGemAnim(to_move_gem, dest_row, dest_col, 30)
						delay = 60
						go_to_gravity_phase = true

						-- curved descent leaf animations
						for frame = 0, 110, 10 do
							self.fx.leaves.generate(self.game, self, frame)
						end

						-- move gem
						grid:moveGem(to_move_gem, dest_row, dest_col)
					end
				end
			end
		end

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
return common.class("Gail", Gail, Character)
