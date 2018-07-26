--[[
This module is the class for an individual gem.
Because of some previous coding issues, this doesn't fully conform to pic.lua
standards, especially in Gem:draw().
--]]
local love = _G.love
local common = require "class.commons" -- class support
local images = require "images"
local Pic = require "pic"

local gemImages = {
	red = images.gems_red,
	blue = images.gems_blue,
	green = images.gems_green,
	yellow = images.gems_yellow,
	wild = images.dummy,
	none = images.dummy,
}

local Gem = {}
function Gem:init(params)
	self.game = params.game
	Pic.init(self, self.game, {
		x = params.x,
		y = params.y,
		image = params.image or gemImages[params.color:lower()],
	})
	self.game.inits.ID.gem = self.game.inits.ID.gem + 1
	self.is_in_a_horizontal_match = false -- for gem matches
	self.is_in_a_vertical_match = false -- for gem matches
	self.target_x = params.x
	self.target_y = params.y
	self.target_rotation = 0
	self.pivot_x = self.width * 0.5
	self.pivot_y = self.height * 0.5
	self.color = params.color
	self.ID = self.game.inits.ID.gem
	self.row = -1
	self.column = -1
	self.player_num = 0 -- 0 = none, 1 = p1, 2 = p2, 3 = both
	self.garbage = params.is_garbage
	self.pending = false -- piece that's been placed in basin but not activated
	self.exploding_gem_image = params.exploding_gem_image
	self.grey_exploding_gem_image = params.grey_exploding_gem_image
	self.pop_particle_image = params.pop_particle_image
end

-- If a non-standard gem color is created, must also provide exploding gem and
-- grey exploding gem images
-- .indestructible true to not be destroyed by grid:destroyGem method
function Gem:create(params)
	assert(params.game, "Game object not received!")
	assert(params.x, "x-value not received!")
	assert(params.y, "y-value not received!")
	assert(params.color, "Color not received!")

	if params.color ~= "red" and params.color ~= "blue" and
	params.color ~= "green" and params.color ~= "yellow" then
		assert(params.exploding_gem_image, "No exploding_gem_image for custom color")
		assert(params.grey_exploding_gem_image, "No grey_exploding_gem_image for custom color")
		assert(params.pop_particle_image, "No pop_particle_image for custom color")
	end
	return common.instance(self, params)
end

-- Returns a random color string result from a provided gem table
-- Defaults to equal frequencies of each color if not provided
function Gem.random(game, gem_table)
	gem_table = gem_table or {red = 1, blue = 1, green = 1, yellow = 1}
	local rand_table = {}
	local num = 0

	for color, freq in pairs(gem_table) do
		for _ = 1, freq do
			num = num + 1
			rand_table[num] = color
		end
	end

	local rand = game.rng:random(num)
	return rand_table[rand]
end

-- default colors are "red", "blue", "green", "yellow"
-- If a non-standard gem color is specified, must also provide exploding gem,
-- grey exploding gem, and pop particle images
function Gem:setColor(color, gem_image, exploding_gem, grey_exploding_gem, pop_particle, delay, duration)
	assert(color, "No color provided")

	self.color = color

	local new_image = gem_image and gem_image or gemImages[color:lower()]

	if delay then
		self:newImageFadeIn(new_image, duration or 0, delay)
	else
		self:newImage(new_image)
	end

	if color ~= "red"
	and color ~= "blue"
	and color ~= "green"
	and color ~= "yellow" then
		assert(exploding_gem, "No exploding_gem_image for custom color")
		assert(grey_exploding_gem, "No grey_exploding_gem_image for custom color")
		assert(pop_particle, "No pop_particle_image for custom color")
		self.exploding_gem_image = exploding_gem
		self.grey_exploding_gem_image = grey_exploding_gem
		self.pop_particle_image = pop_particle
	end
end

function Gem:isStationary()
	local stationary = true
	if self.move_func then stationary = false end
	if self.row > -1 then -- in grid
		if self.y ~= self.game.grid.y[self.row] then stationary = false end
	end
	return stationary
end

function Gem:updateGrid(row, column)
	self.row = row
	self.column = column
end

-- arrived at destination in grid, make some particles
-- called from grid:moveGemAnim()
function Gem:landedInGrid()
	for _, fx in pairs(self.game.particles.allParticles.WordEffects) do
		if fx.name == "DoublecastCloud" or fx.name == "RushCloud" then
			fx:remove()
		end
	end

	if self.no_yoshi_particle then
		self.no_yoshi_particle = nil
	else
		self.game.particles.dust.generateYoshi(self.game, self)
		self.game.sound:newSFX("gemdrop", true)
	end
end

-- custom function to handle rotation around pivot
function Gem:draw(params)
	params = params or {}
	local rgbt = params.RGBTable or {1, 1, 1, self.transparency or 1}
	if params.darkened and not self.force_max_alpha then
		rgbt[1] = rgbt[1] * params.darkened
		rgbt[2] = rgbt[2] * params.darkened
		rgbt[3] = rgbt[3] * params.darkened
	end

	love.graphics.push("all")
		love.graphics.translate(params.pivot_x or self.x, params.pivot_y or self.y)
		love.graphics.translate(-self.width * 0.5, -self.height * 0.5)
		if params.rotation then love.graphics.rotate(params.rotation) end
		love.graphics.translate(params.displace_x or 0, params.displace_y or 0)
		-- reverse the rotation so the gem always maintains its orientation
		if params.rotation then love.graphics.rotate(-params.rotation) end
		love.graphics.setColor(rgbt)
		love.graphics.draw(self.image, self.quad)

		if self.new_image then
			local new_image_rgbt = {rgbt[1], rgbt[2], rgbt[3], self.new_image.transparency or 1}
			love.graphics.setColor(new_image_rgbt)
			love.graphics.draw(self.new_image.image, self.quad)
		end
	love.graphics.pop()
end

-- respects cannot_remove_owners
function Gem:setOwner(player_num, set_due_to_match)
	assert(player_num >= 0 and player_num <= 3, "Invalid player_num provided")

	if self.cannot_remove_owners then
		self:addOwner(player_num)
	else
		self.player_num = player_num
	end
	if set_due_to_match then self.set_due_to_match = true end
end

function Gem:addOwner(player_num)
	assert(player_num >= 1 and player_num <= 3, "Invalid player_num provided")

	if self.player_num == 0 then
		self.player_num = player_num
	elseif self.player_num == 1 then
		if player_num == 2 or player_num == 3 then self.player_num = 3 end
	elseif self.player_num == 2 then
		if player_num == 1 or player_num == 3 then self.player_num = 3 end
	end
end

function Gem:removeOwner(player_num)
	assert(player_num >= 1 and player_num <= 3, "Invalid player_num provided")

	if not self.cannot_remove_owners then
		if player_num == 1 then
			if self.player_num == 1 or self.player_num == 3 then
				self.player_num = self.player_num - 1
			end
		elseif player_num == 2 then
			if self.player_num == 2 or self.player_num == 3 then
				self.player_num = self.player_num - 2
			end
		elseif player_num == 3 then
			self.player_num= 0
		end
	end
end

-- If true, can only add to ownership, not replace or remove
function Gem:setProtectedFlag(bool)
	self.cannot_remove_owners = bool
end

-- returns how many frames it will take to completely animate
function Gem:getAnimFrames()
	local f = 0
	if self.tweening then
		f = f + self.tweening.duration
	end
	for i = 1, #self.queued_moves do
		f = f + self.queued_moves[i].duration
	end
	return f
end

-- If true, always shown brightened
function Gem:setMaxAlpha(bool)
	if bool ~= false then bool = true end
	self.force_max_alpha = bool
end

return common.class("Gem", Gem, Pic)
