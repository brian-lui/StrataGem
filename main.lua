local love = _G.love
require "inits"
require "lovedebug"
require "classcommons"
local common = require "class.commons"
local game
local maxWindowWidth
local maxWindowHeight

function love.load()
	love.window.setMode(drawspace.width * drawspace.scale, drawspace.height * drawspace.scale, {resizable=true})
	love.window.setTitle("StrataGem!")
	game = common.instance(require "game")
	
	-- Using the largest full screen dimension as the upper bound for window size
	fullscreenDimensions = love.window.getFullscreenModes()
	table.sort(fullscreenDimensions, function(a, b) return a.width*a.height > b.width*b.height end)
	maxWindowWidth, maxWindowHeight = fullscreenDimensions[1].width, fullscreenDimensions[1].height
end
-- local sandbox = require 'animationsandbox'

local __NOP__ = function () end 

function love.draw()
	local f = game.draw or __NOP__
	love.graphics.push("all")
		love.graphics.scale(drawspace.scale, drawspace.scale)
		f(game)
	drawspace.tlfres.beginRendering(drawspace.width, drawspace.height)
	drawspace.tlfres.endRendering({0, 0, 0, 0}) -- Using an opaque color so we don't have a visible letterbox
	love.graphics.pop()
end

function love.update(dt)
	(game.update or __NOP__)(game, dt)
end

function love.keypressed(key)
	(game.keypressed or __NOP__)(game, key)
end

function love.mousepressed(x, y, button, istouch)
	x, y = x / drawspace.scale, y / drawspace.scale
	local f = game.mousepressed or __NOP__
	f(game, x, y, button, istouch)
end

function love.mousereleased(x, y, button, istouch)
	x, y = x / drawspace.scale, y / drawspace.scale
	local f = game.mousereleased or __NOP__
	f(game, x, y, button, istouch)
end

function love.mousemoved(x, y, dx, dy)
	x, y, dx, dy = x / drawspace.scale, y / drawspace.scale, dx / drawspace.scale, dy / drawspace.scale
	local f = game.mousemoved or __NOP__
	f(game, x, y, dx, dy)
end

function love.resize(w, h)
	local newHeight = math.min(maxWindowHeight, h)
	local newWidth = math.min(maxWindowWidth, newHeight * drawspace.aspectRatio)
	love.window.setMode(newWidth, newHeight, {resizable = true})
	drawspace.scale = drawspace.tlfres.getScale(drawspace.width, drawspace.height) -- Recalculate scale based on new window dimensions
end
