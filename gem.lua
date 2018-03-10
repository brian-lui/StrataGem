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
	self.is_in_a_horizontal_match = false -- for gem matches
	self.is_in_a_vertical_match = false -- for gem matches
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
		self.game.sound:newSFX("gemdrop", true)
	end
end

-- custom function to handle rotation around pivot
function Gem:draw(params)
	params = params or {}
	local rgbt = params.RGBTable or {255, 255, 255, self.transparency or 255}
	if params.darkened and not self.force_max_alpha then
		rgbt[1], rgbt[2], rgbt[3] = rgbt[1] * 0.5, rgbt[2] * 0.5, rgbt[3] * 0.5
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
	if set_due_to_match then self.matched_this_turn = true end
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

return common.class("Gem", Gem, Pic)
