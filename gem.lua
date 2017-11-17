local love = _G.love

local common = require 'class.commons' -- class support
local image = require 'image'
local Pic = require 'pic'

local gemImages = {
	red = image.red_gem,
	blue = image.blue_gem,
	green = image.green_gem,
	yellow = image.yellow_gem,
}

local Gem = {}
function Gem:init(game, x, y, color, garbage)
	self.game = game

	Pic.init(self, game, {x = x, y = y, image = gemImages[color:lower()]})
	ID.gem = ID.gem + 1
	self.horizontal = false -- for gem matches
	self.vertical = false -- for gem matches
	self.target_x = x
	self.target_y = y
	self.target_rotation = 0
	self.pivot_x = self.width * 0.5
	self.pivot_y = self.height * 0.5
	self.color = color
	self.ID = ID.gem
	self.row = -1
	self.column = -1
	self.owner = 0 -- 0 = none, 1 = p1, 2 = p2, 3 = both
	self.garbage = garbage
	self.pending = false -- piece that's been placed in basin but not activated
end

-- Returns a random color string result from a provided gem table
function Gem.random(game, gem_table)
	local rand_table = {}
	local num = 0

	for i = 1, #gem_table do
		for _ = 1, gem_table[i].freq do
			num = num + 1
			rand_table[num] = gem_table[i].color
		end
	end

	local rand = game.rng:random(num)
	return rand_table[rand]
end

-- default colors are "red", "blue", "green", "yellow"
function Gem:setColor(color)
	self.color = color
	self:newImage(gemImages[color:lower()]) -- this is a pic.lua method
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
	--local remove_fx = false
	for _, fx in pairs(self.game.particles.allParticles.WordEffects) do
		if fx.name == "DoublecastCloud" or fx.name == "RushCloud" then
			fx:remove()
		end
	end

	if self.no_yoshi_particle then
		self.no_yoshi_particle = nil
	else
		self.game.particles.dust.generateYoshi(self.game, self)
		self.game.sound:newSFX("sfx_gemdrop", true)
	end
end

-- landed in the staging area above the grid
function Gem:landedInStagingArea(place_type, owner)
	local particles = self.game.particles
	for player in self.game:players() do
		if player.place_type == "double" then
			particles.words.generateDoublecast(self.game, player)
			self.game.sound:newSFX("sfx_doublecast")
			self.game.sound:newSFX("sfx_fountaindoublecast")

		elseif player.place_type == "rush" then
			particles.words.generateRush(self.game, player)
			self.game.sound:newSFX("sfx_rush")
			self.game.sound:newSFX("sfx_fountainrush")
		end
	end
	if place_type == "double" then
		particles.dust.generateStarFountain(self.game, self, 24, owner)
	elseif place_type == "rush" then
		particles.dust.generateStarFountain(self.game, self, 24, owner)
	else
		print("wtf")
	end
end

-- custom function to handle rotation around pivot
function Gem:draw(params)
	params = params or {}
	love.graphics.push("all")
		if params.RGBTable then love.graphics.setColor(params.RGBTable) end
		love.graphics.translate(params.pivot_x or self.x, params.pivot_y or self.y)
		love.graphics.translate(-self.width * 0.5, -self.height * 0.5)
		if params.rotation then love.graphics.rotate(params.rotation) end
		love.graphics.translate(params.displace_x or 0, params.displace_y or 0)
		-- reverse the rotation so the gem always maintains its orientation
		if params.rotation then love.graphics.rotate(-params.rotation) end
		if params.darkened then love.graphics.setColor(127, 127, 127) end
		love.graphics.draw(self.image, self.quad)
	love.graphics.pop()
end

-- these can take either the player object or the number
function Gem:setOwner(player)
	if type(player) == "table" then
		player = player.ID
	end
	if player == 1 or player == "P1" then
		self.owner = 1
	elseif player == 2 or player == "P2" then
		self.owner = 2
	elseif player == 3 then
		self.owner = 3
	else
		print("Error: tried to set invalid gem owner")
	end
end

function Gem:addOwner(player)
	if type(player) == "table" then
		player = player.ID
	end
	if player == 1 or player == "P1" then
		if self.owner == 0 or self.owner == 2 then
			self.owner = self.owner + 1
		end
	elseif player == 2 or player == "P2" then
		if self.owner == 0 or self.owner == 1 then
			self.owner = self.owner + 2
		end
	elseif player ~= 3 then	-- if player == 3, nothing needs to be added
		print("Error: tried to add invalid gem owner")
	end
end

function Gem:removeOwner(player)
	if type(player) == "table" then
		player = player.ID
	end
	if player == 1 or player == "P1" then
		if self.owner == 1 or self.owner == 3 then
			self.owner = self.owner - 1
		end
	elseif player == 2 or player == "P2" then
		if self.owner == 2 or self.owner == 3 then
			self.owner = self.owner - 2
		end
	else
		print("Error: tried to remove invalid gem owner")
	end
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

return common.class("Gem", Gem, Pic)
