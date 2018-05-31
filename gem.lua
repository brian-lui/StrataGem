local love = _G.love

local common = require 'class.commons' -- class support
local image = require 'image'
local Pic = require 'pic'

local gemImages = {
	red = image.gem_red,
	blue = image.gem_blue,
	green = image.gem_green,
	yellow = image.gem_yellow,
}

local Gem = {}
function Gem:init(params)
	self.game = params.game
	Pic.init(self, self.game, {
		x = params.x,
		y = params.y,
		image = gemImages[params.color:lower()],
	})
	ID.gem = ID.gem + 1
	self.is_in_a_horizontal_match = false -- for gem matches
	self.is_in_a_vertical_match = false -- for gem matches
	self.target_x = params.x
	self.target_y = params.y
	self.target_rotation = 0
	self.pivot_x = self.width * 0.5
	self.pivot_y = self.height * 0.5
	self.color = params.color
	self.ID = ID.gem
	self.row = -1
	self.column = -1
	self.owner = 0 -- 0 = none, 1 = p1, 2 = p2, 3 = both
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
function Gem:setColor(color, gem_image, exploding_gem, grey_exploding_gem, pop_particle)
	assert(color, "No color provided")

	self.color = color
	if gem_image then
		self:newImage(gem_image)
	else
		self:newImage(gemImages[color:lower()])
	end

	if color ~= "red" and color ~= "blue" and color ~= "green" and color ~= "yellow" then
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
	--particles.dust:generateGlow(self) -- BT said we don't need glow now
	--TODO: support multiple gems
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
	local rgbt = params.RGBTable or {255, 255, 255, self.transparency or 255}
	if params.darkened and not self.force_max_alpha then
		rgbt[1] = rgbt[1] * params.darkened
		rgbt[2] = rgbt[2] * params.darkened
		rgbt[3] = rgbt[3] * params.darkened
	end


	love.graphics.push("all")
		--if params.RGBTable then love.graphics.setColor(params.RGBTable) end
		love.graphics.translate(params.pivot_x or self.x, params.pivot_y or self.y)
		love.graphics.translate(-self.width * 0.5, -self.height * 0.5)
		if params.rotation then love.graphics.rotate(params.rotation) end
		love.graphics.translate(params.displace_x or 0, params.displace_y or 0)
		-- reverse the rotation so the gem always maintains its orientation
		if params.rotation then love.graphics.rotate(-params.rotation) end
		love.graphics.setColor(rgbt)
		love.graphics.draw(self.image, self.quad)
	love.graphics.pop()
end

-- these can take either the player object or the number
-- respects cannot_remove_owners
function Gem:setOwner(player, set_due_to_match)
	if type(player) == "table" then player = player.player_num end
	if not (player == 0 or player == 1 or player == 2 or player == 3) then
		print("Error: tried to set invalid gem owner as player:", player)
		return
	end

	if self.cannot_remove_owners then
		self:addOwner(player)
	else
		self.owner = player
	end
	if set_due_to_match then
		self.set_due_to_match = true
		self:allowFlagPropagation()
	end
end

-- sometimes we don't want to propagate flags up if they were removed by
-- a special move or passive
function Gem:allowFlagPropagation()
	self.allow_flag_propagation = true
end

function Gem:addOwner(player)
	if type(player) == "table" then player = player.player_num end
	if not (player == 1 or player == 2 or player == 3) then
		print("Error: tried to add invalid gem owner as player:", player)
		return
	end

	if self.owner == 0 then
		self.owner = player
	elseif self.owner == 1 then
		if player == 2 or player == 3 then self.owner = 3 end
	elseif self.owner == 2 then
		if player == 1 or player == 3 then self.owner = 3 end
	end
end

function Gem:removeOwner(player)
	if type(player) == "table" then player = player.player_num end
	if not (player == 1 or player == 2 or player == 3) then
		print("Error: tried to remove invalid gem owner as player:", player)
		return
	end

	if not self.cannot_remove_owners then
		if player == 1 then
			if self.owner == 1 or self.owner == 3 then
				self.owner = self.owner - 1
			end
		elseif player == 2 then
			if self.owner == 2 or self.owner == 3 then
				self.owner = self.owner - 2
			end
		elseif player == 3 then
			self.owner = 0
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
