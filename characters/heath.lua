-- TODO: need to update the fire y-position after each chain combo, too. Currently, it only updates at the end of the turn. So if there is a chain combo underneath the fire, it won't update.

--[[ Color: red
Passive: Horizontal matches create a fire tile if the matched gem was the top
most gem in that column. Fire tiles last for one turn. At the end of the turn,
they destroy the gem below them UNLESS a gem is placed on top of them (the gem
can come from either player). Heath owns the damage from the fire burn.

Super: Clear the top gem in each friendly column.

Super pseudocode:
	BeforeGravity:
		destroyGem in top row of each column
 --]]

-- *This part is the setup part where we initialize the working variables and images
local love = _G.love
local common = require "class.commons"
local image = require "image"
local Pic = require 'pic'
local Character = require "character"

local Heath = {}
Heath.character_id = "Heath"
Heath.meter_gain = {red = 8, blue = 4, green = 4, yellow = 4}

Heath.full_size_image = love.graphics.newImage('images/portraits/heath.png')
Heath.small_image = love.graphics.newImage('images/portraits/heathsmall.png')
Heath.action_image = love.graphics.newImage('images/portraits/heathaction.png')
Heath.shadow_image = love.graphics.newImage('images/portraits/heathshadow.png')

Heath.super_images = {
	word = image.UI.super.red_word,
	empty = image.UI.super.red_empty,
	full = image.UI.super.red_full,
	glow = image.UI.super.red_glow,
	overlay = love.graphics.newImage('images/characters/heath/firelogo.png')
}

Heath.burst_images = {
	partial = image.UI.burst.red_partial,
	full = image.UI.burst.red_full,
	glow = {image.UI.burst.red_glow1, image.UI.burst.red_glow2}
}

Heath.special_images = {
	fire = {
		love.graphics.newImage('images/characters/heath/fire1.png'),
		love.graphics.newImage('images/characters/heath/fire2.png'),
		love.graphics.newImage('images/characters/heath/fire3.png'),
	},
	boom = {
		love.graphics.newImage('images/characters/heath/boom1.png'),
		love.graphics.newImage('images/characters/heath/boom2.png'),
		love.graphics.newImage('images/characters/heath/boom3.png'),
	},
}

Heath.sounds = {
	bgm = "bgm_heath",
	passive = "sound/heath/passive.ogg",
}

function Heath:init(...)
	Character.init(self, ...)

	-- these columns are stores as booleans for columns 1-8
	self.pending_fires = {} -- fires for horizontal matches generated at t0
	self.ready_fires = {} -- fires at t1, ready to burn
	self.pending_gem_cols = {} -- pending gems, for extinguishing of ready_fires
	self.generated_fire_images = {} -- whether fire particles were generated yet. one for each col
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
	self:change{duration = 32, transparency = 0, remove = true}
end

function SmallFire:countdown()
	self.turns_remaining = self.turns_remaining - 1
end

function SmallFire.generateSmallFire(game, owner, col)
	local grid = game.grid

	local function update_func(self, dt)
		Pic.update(self, dt)
		self.elapsed_frames = self.elapsed_frames + 1
		if self.elapsed_frames >= 6 then -- loop through images
			self.current_image_idx = self.current_image_idx % 3 + 1
			self:newImage(Heath.special_images.fire[self.current_image_idx])	
			self.elapsed_frames = 0
		end
		if self.turns_remaining < 0 and self:isStationary() then
			self:change{duration = 32, transparency = 0, remove = true}
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
		turns_remaining = 1,
		image = Heath.special_images.fire[1],
		image_index = 1,
		SWAP_FRAMES = 6,
		current_frame = 6,
		owner = owner,
		player_num = owner.player_num,
		name = "HeathFire",
	}

	local p = common.instance(SmallFire, game.particles, params)
	p:change{duration = 15, y = bounce_top_y, scaling = 0.5}
	p:change{duration = 15, y = start_y, scaling = 1}
	return 30
end

function SmallFire:update(dt)
	Pic.update(self, dt)
	self.current_frame = self.current_frame - 1
	if self.current_frame <= 0 then
		self.current_frame = self.SWAP_FRAMES
		local fires = #self.owner.special_images.fire
		self.image_index = self.image_index % fires + 1
		local new_image = self.owner.special_images.fire[self.image_index]
		self:newImageFadeIn(new_image, self.SWAP_FRAMES)
	end
	if self.turns_remaining < 0 and self:isStationary() then
		self:change{duration = 32, transparency = 0, remove = true}
	end
end

SmallFire = common.class("SmallFire", SmallFire, Pic)
-------------------------------------------------------------------------------

Heath.particle_fx = {
	smallFire = SmallFire,
}
-------------------------------------------------------------------------------

-- *The following code is executed from phase.lua
-- character.lua has a complete list of all the timings. Can omit unneeded ones
-- we can add more timing phases if needed

-- get the list of pending gem columns for extinguishing in afterGravity
-- also the super
function Heath:beforeGravity()
	local game = self.game
	local grid = game.grid
	local delay = 0

	local pending_gems = grid:getPendingGemsByNum()
	self.pending_gem_cols = {}
	for _, gem in ipairs(pending_gems) do
		self.pending_gem_cols[gem.column] = true
	end

	if self.supering then
		for col in grid:cols(self.player_num) do
			local top_row = grid:getFirstEmptyRow(col, true) + 1
			if top_row <= grid.BOTTOM_ROW then
				local gem = grid[top_row][col].gem
				gem:setOwner(self.player_num)
				delay = grid:destroyGem{
					gem = gem,
					super_meter = false,
					glow_delay = 20,
					force_max_alpha = true,
				}
			end
		end
	end

	return delay
end

function Heath:beforeTween()
	self.supering = false
	self.game:brightenScreen(self.player_num)
end
-- extinguish ready_fires where a gem landed on them
function Heath:afterGravity()
	for i in self.game.grid:cols() do
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

function Heath:beforeMatch()
	local game = self.game
	local grid = game.grid

	local gem_table = grid:getMatchedGems()

	-- store horizontal fire locations, used in aftermatch phase
	for _, gem in pairs(gem_table) do
		local h = "vertical"
		if gem.is_in_a_horizontal_match then h = "horizontal" end

		local top_gem = gem.row-1 == grid:getFirstEmptyRow(gem.column)
		if self.player_num == gem.owner and gem.is_in_a_horizontal_match and top_gem then
			self.pending_fires[gem.column] = true
		end
	end


end

-- create fire particle for passive
function Heath:afterMatch()
	local delay_to_return = 0
	local fire_sound = false
	for i in self.game.grid:cols() do
		if not self.generated_fire_images[i] and self.pending_fires[i] then
			delay_to_return = self.particle_fx.smallFire.generateSmallFire(self.game, self, i)
			self.generated_fire_images[i] = true
			fire_sound = true
		end
	end
	if fire_sound then self.game.sound:newSFX(self.sounds.passive) end

	-- fire passive update, in case of chain combo for a gem below the fire
	for _, particle in pairs(self.game.particles.allParticles.CharEffects) do
		if particle.player_num == self.player_num and particle.name == "HeathFire" then
			particle:updateYPos()
		end
	end

	return delay_to_return
end

-- take away super meter, make fires
function Heath:afterAllMatches()
	local grid = self.game.grid
	-- super
	if self.supering then
		self:emptyMP()
		self.supering = false
	end

	-- activate horizontal match fires
	for i in grid:cols() do
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
	-- fire passive update
	for _, particle in pairs(self.game.particles.allParticles.CharEffects) do
		if particle.player_num == self.player_num and particle.name == "HeathFire" then
			particle:updateYPos()
		end
	end
end

function Heath:cleanup()
	-- fire passive update
	for _, particle in pairs(self.game.particles.allParticles.CharEffects) do
		if particle.player_num == self.player_num and particle.name == "HeathFire" then
			particle:updateYPos()
			particle:countdown()
		end
	end

	-- prepare the active fire columns for next turn
	self.ready_fires = self.pending_fires
	self.pending_fires = {}
	self.generated_fire_images = {}

	Character.cleanup(self)
end

return common.class("Heath", Heath, Character)
