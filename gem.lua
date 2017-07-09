--require 'inits'
local image = require 'image'
require 'utilities' -- helper functions
local class = require 'middleclass' -- class support
local GemPlatform = require 'gemplatform'
local tween = require 'tween'
local pic = require 'pic'
local particles	-- Set in initializer
local stage	-- Set in initializer

local Gem = class('Gem', pic)
function Gem:initialize(x, y, image, color, garbage)
	particles = game.particles
	stage = game.stage

	pic.initialize(self, {x = x, y = y, image = image})
	ID.gem = ID.gem + 1
	self.horizontal = false -- for gem matches
	self.vertical = false -- for gem matches
	self.target_x = x
	self.target_y = y
	self.target_rotation = 0
	self.pivot_x = self.width / 2
	self.pivot_y = self.height / 2
	self.color = color
	self.ID = ID.gem
	self.row = -1
	self.column = -1
	self.owner = 0 -- 0 = none, 1 = p1, 2 = p2, 3 = both
	self.garbage = garbage
	self.pending = false -- piece that's been placed in basin but not activated
end

function Gem:random(gem_table)
	local rand_table = {}
	local num = 0

	for i = 1, #gem_table do
		for j = 1, gem_table[i].freq do
			num = num + 1
			rand_table[num] = gem_table[i].gem
		end
	end

	local rand = game.rng:random(num)
	return rand_table[rand]
end

function Gem:isStationary()
	local stationary = true
	if self.move_func then stationary = false end
	if self.row > -1 then -- in grid
		if self.y ~= stage.grid.y[self.row] then stationary = false end
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
	for _, fx in pairs(AllParticles.WordEffects) do
		if fx.name == "DoublecastCloud" or fx.name == "RushCloud" then
			fx:remove()
		end
	end

	if self.no_yoshi_particle then
		self.no_yoshi_particle = nil
	else
		particles.dust:generateYoshi(self)
	end
end

-- landed in the staging area above the grid
function Gem:landedInStagingArea(place_type, owner)
	print("gem landed in staging area!")
	for player in game:players() do
		if player.place_type == "double" then
			particles.words:generateDoublecast(player)
		elseif player.place_type == "rush" then
			particles.words:generateRush(player)
		end
	end
	if place_type == "double" then
		particles.dust:generateStarFountain(self, 24, owner)
	elseif place_type == "rush" then
		particles.dust:generateStarFountain(self, 24, owner)
	else
		print("wtf")
	end
end

function Gem:draw(pivot_x, pivot_y, RGBTable, rotation, displace_x, displace_y)
	love.graphics.push("all")
		if RGBTable then love.graphics.setColor(RGBTable) end

		love.graphics.translate(pivot_x or self.x, pivot_y or self.y)
		love.graphics.translate(-self.width / 2, -self.height / 2)

		if rotation then love.graphics.rotate(rotation) end

		love.graphics.translate(displace_x or 0, displace_y or 0)

		-- reverse the rotation so the gem always maintains its orientation
		if rotation then love.graphics.rotate(-rotation) end

		love.graphics.draw(self.image, self.quad)
	love.graphics.pop()
end

-- these can take either the player object or the number
function Gem:setOwner(player)
	if player == 1 or player.ID == "P1" then
		self.owner = 1
	elseif player == 2 or player.ID == "P2" then
		self.owner = 2
	elseif player == 3 then
		self.owner = 3
	else
		print("Error: tried to set invalid gem owner")
	end
end

function Gem:addOwner(player)
	if player == 1 or player.ID == "P1" then
		if self.owner == 0 or self.owner == 2 then
			self.owner = self.owner + 1
		end
	elseif player == 2 or player.ID == "P2" then
		if self.owner == 0 or self.owner == 1 then
			self.owner = self.owner + 2
		end
	elseif player == 3 then
		-- no need to add owner
	else
		print("Error: tried to add invalid gem owner")
	end
end

function Gem:removeOwner(player)
	if player == 1 or player.ID == "P1" then
		if self.owner == 1 or self.owner == 3 then
			self.owner = self.owner - 1
		end
	elseif player == 2 or player.ID == "P2" then
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
	if self.tweening then f = f + self.tweening.duration end
	for i = 1, #self.queued_moves do f = f + self.queued_moves[i].duration end
	return f
end

Gem.RedGem = class('Gem.RedGem', Gem)
function Gem.RedGem:initialize(x, y, garbage)
	Gem.initialize(self, x, y, image.red_gem, "RED", garbage)
end

Gem.BlueGem = class('Gem.BlueGem', Gem)
function Gem.BlueGem:initialize(x, y, garbage)
	Gem.initialize(self, x, y, image.blue_gem, "BLUE", garbage)
end

Gem.GreenGem = class('Gem.GreenGem', Gem)
function Gem.GreenGem:initialize(x, y, garbage)
	Gem.initialize(self, x, y, image.green_gem, "GREEN", garbage)
end

Gem.YellowGem = class('Gem.YellowGem', Gem)
function Gem.YellowGem:initialize(x, y, garbage)
	Gem.initialize(self, x, y, image.yellow_gem, "YELLOW", garbage)
end

return Gem
