local love = _G.love
require "inits"
require "lovedebug"
require "classcommons"
local common = require "class.commons"
local game
local maxWindowWidth
local maxWindowHeight

function love.load()
	love.window.setTitle("StrataGem!")
	game = common.instance(require "game")

	-- Using the largest full screen dimension as the upper bound for window size
	fullscreenDimensions = love.window.getFullscreenModes()
	table.sort(fullscreenDimensions, function(a, b) return a.width*a.height > b.width*b.height end)
	maxWindowWidth, maxWindowHeight = fullscreenDimensions[1].width, fullscreenDimensions[1].height

	-- default windowed resolution is half native
	local desktopWidth, desktopHeight = love.window.getDesktopDimensions()
	love.window.setMode(desktopWidth / 2, desktopHeight / 2)
end
-- local sandbox = require 'animationsandbox'

local __NOP__ = function () end

function love.draw()
	if game.draw then
		drawspace.tlfres.beginRendering(drawspace.width, drawspace.height)
		game:draw()
		drawspace.tlfres.endRendering({0, 0, 0, 0}) -- Using an opaque color so we don't have a visible letterbox
	end
end

function love.update(dt)
	(game.update or __NOP__)(game, dt)
end

function love.keypressed(key)
	(game.keypressed or __NOP__)(game, key)
end

function love.mousepressed(x, y, button, istouch)
	x, y = drawspace.tlfres.getMousePosition(drawspace.width, drawspace.height)
	local f = game.mousepressed or __NOP__
	f(game, x, y, button, istouch)
end

function love.mousereleased(x, y, button, istouch)
	x, y = drawspace.tlfres.getMousePosition(drawspace.width, drawspace.height)
	local f = game.mousereleased or __NOP__
	f(game, x, y, button, istouch)
end

function love.mousemoved(x, y, dx, dy)
	if game.mousemoved then
		x, y = drawspace.tlfres.getMousePosition(drawspace.width, drawspace.height)
		local scale = drawspace.tlfres.getScale(drawspace.width, drawspace.height)
		dx, dy = dx / scale, dy / scale
		game:mousemoved(x, y, dx, dy)
	end
end

function love.resize(w, h)
	drawspace.scale = drawspace.tlfres.getScale(drawspace.width, drawspace.height) -- Recalculate scale based on new window dimensions
end
