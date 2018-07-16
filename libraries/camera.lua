local love = _G.love
local common = require "class.commons"

local Camera = {
	x = 0,
	y = 0,
	scaleX = 1,
	scaleY = 1,
	rotation = 0
}

function Camera:set(parallax_x, parallax_y)
	love.graphics.push()
	love.graphics.rotate(-self.rotation)
	love.graphics.scale(1 / self.scaleX, 1 / self.scaleY)
	love.graphics.translate(-self.x * parallax_x, -self.y * parallax_y)
end

function Camera:unset()
	love.graphics.pop()
end

function Camera:move(dx, dy)
	self.x = self.x + (dx or 0)
	self.y = self.y + (dy or 0)
end

function Camera:rotate(dr)
	self.rotation = self.rotation + dr
end

function Camera:scale(sx, sy)
	sx = sx or 1
	self.scaleX = self.scaleX * sx
	self.scaleY = self.scaleY * (sy or sx)
end

function Camera:setPosition(x, y)
	self.x = x or self.x
	self.y = y or self.y
end

function Camera:setScale(sx, sy)
	self.scaleX = sx or self.scaleX
	self.scaleY = sy or self.scaleY
end

function Camera:setScreenshake(current_frame, velocity)
	local shake = math.min(velocity or 6, 6)
	local h_displacement = shake * (
		current_frame % 7 * 0.5 +
		current_frame % 13 * 0.25 +
		current_frame % 23 / 6 - 5
	)
	local v_displacement = shake * (
		current_frame % 5 * 2/3 +
		current_frame % 11 * 0.25 +
		current_frame % 17 / 6 - 5
	)
	self:setPosition(h_displacement, v_displacement)
end

return common.class("Camera", Camera)
