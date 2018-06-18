-- For compatibility; Lua 5.3 moved unpack to table.unpack
_G.table.unpack = _G.table.unpack or _G.unpack

local love = _G.love
require "classcommons"
local common = require "class.commons"
local game

function love.load()
	print(love.filesystem.getSaveDirectory())
	love.window.setTitle("StrataGem!")
	game = common.instance(require "game")

	-- default windowed resolution is half native
	local desktopWidth, desktopHeight = love.window.getDesktopDimensions()
	love.window.setMode(desktopWidth / 2, desktopHeight / 2, {resizable=true})

	-- set icon
	local icon = love.graphics.newImage("/images/unclickables/windowicon.png")
	love.window.setIcon(icon:getData())
end
-- local sandbox = require 'animationsandbox'

local __NOP__ = function () end

function love.quit()
	local lily = require "lily"
	lily.quit()
end

function love.draw()
	love.graphics.push("all")
	if game.draw then
		local drawspace = game.inits.drawspace
		drawspace.tlfres.beginRendering(drawspace.width, drawspace.height)
		game:draw()
		drawspace.tlfres.endRendering()
	end
	love.graphics.pop()
end

function love.update(dt)
	(game.update or __NOP__)(game, dt)
end

function love.keypressed(key)
	(game.keypressed or __NOP__)(game, key)
end

function love.mousepressed(x, y, button, istouch)
	local drawspace = game.inits.drawspace
	x, y = drawspace.tlfres.getMousePosition(drawspace.width, drawspace.height)
	local f = game.mousepressed or __NOP__
	f(game, x, y, button, istouch)
end

function love.mousereleased(x, y, button, istouch)
	local drawspace = game.inits.drawspace
	x, y = drawspace.tlfres.getMousePosition(drawspace.width, drawspace.height)
	local f = game.mousereleased or __NOP__
	f(game, x, y, button, istouch)
end

function love.mousemoved(x, y, dx, dy)
	if game.mousemoved then
		local drawspace = game.inits.drawspace
		x, y = drawspace.tlfres.getMousePosition(drawspace.width, drawspace.height)
		local scale = drawspace.tlfres.getScale(drawspace.width, drawspace.height)
		dx, dy = dx / scale, dy / scale
		game:mousemoved(x, y, dx, dy)
	end
end
