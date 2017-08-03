local love = _G.love
require 'utilities'
local animations = require 'animations'

local draw = {}

-- camera manipulations
draw.camera = {
	x = 0,
	y = 0,
	scaleX = 1,
	scaleY = 1,
	rotation = 0
}

function draw.camera:set(parallax_x, parallax_y)
	love.graphics.push()
	love.graphics.rotate(-self.rotation)
	love.graphics.scale(1 / self.scaleX, 1 / self.scaleY)
	love.graphics.translate(-self.x * parallax_x, -self.y * parallax_y)
end

function draw.camera:unset()
	love.graphics.pop()
end

function draw.camera:move(dx, dy)
	self.x = self.x + (dx or 0)
	self.y = self.y + (dy or 0)
end

function draw.camera:rotate(dr)
	self.rotation = self.rotation + dr
end

function draw.camera:scale(sx, sy)
	sx = sx or 1
	self.scaleX = self.scaleX * sx
	self.scaleY = self.scaleY * (sy or sx)
end

function draw.camera:setPosition(x, y)
	self.x = x or self.x
	self.y = y or self.y
end

function draw.camera:setScale(sx, sy)
	self.scaleX = sx or self.scaleX
	self.scaleY = sy or self.scaleY
end

-- screenshake effect
function draw.screenshake(shake)
	shake = shake or 6
	local h_displacement = shake * (frame % 7 / 2 + frame % 13 / 4 + frame % 23 / 6 - 5)
	local v_displacement = shake * (frame % 5 * 2/3 + frame % 11 / 4 + frame % 17 / 6 - 5)
	draw.camera:setPosition(h_displacement, v_displacement)
end

function draw.drawAnimations()
	love.graphics.clear(255, 255, 255)

	for i = 1, #draw_array do
		drawThis(draw_array[i])
	end

	-- debug display
	love.graphics.push("all")
		love.graphics.setColor(255, 0, 255)
		love.graphics.print("Thanks for trying things out!", 600, 100)
		love.graphics.print("You can edit animationsandbox.lua to change what they do.", 600, 280)
		love.graphics.print("Thanks.", 600, 310)

	love.graphics.pop()
	--[[
	love.graphics.push("all")
		love.graphics.setLineWidth(1)
		love.graphics.setColor(0, 255, 0)
		for i = 0, 400, 20 do
			love.graphics.line(0, i, stage.width, i)
			love.graphics.line(i, 0, i, stage.height)
			love.graphics.print(i, 0, i)
			love.graphics.print(i, i, 0)
		end
	love.graphics.pop()
	--]]
end

function draw.drawAnimationTracers()
	animations:drawTracers()
end

return draw
