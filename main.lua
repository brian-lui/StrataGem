local love = _G.love
require "inits"
require "lovedebug"
require "classcommons"
local common = require "class.commons"
local game

function love.load()
	love.window.setTitle("StrataGem!")
	game = common.instance(require "game")

	-- default windowed resolution is half native
	local desktopWidth, desktopHeight = love.window.getDesktopDimensions()
	love.window.setMode(desktopWidth / 2, desktopHeight / 2, {resizable=true})

	local DEMO_MODE_ON = false
	if DEMO_MODE_ON then
		game.debug_drawGemOwners = false
		game.debug_drawParticleDestinations = false
		game.debug_drawGamestate = false
		game.debug_drawDamage = false
		game.debug_drawGrid = false
		game.debug_overlay = false
		game.debug_screencaps = false
		game.unittests = {}
	end
end
-- local sandbox = require 'animationsandbox'

local __NOP__ = function () end

function love.draw()
	love.graphics.push("all")
	if game.draw then
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
