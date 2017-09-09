local love = _G.love

require "inits"
require "lovedebug"
require "classcommons"

local common = require "class.commons"

local game

function love.load()
	-- build screen
	love.window.setMode(window.width, window.height)
	love.window.setTitle("StrataGem!")

	game = common.instance(require "game")
end
-- local sandbox = require 'animationsandbox'

local __NOP__ = function () end

function love.draw()
	(game.draw or __NOP__)(game)
end

function love.update(dt)
	(game.update or __NOP__)(game, dt)
end

function love.keypressed(key)
	(game.keypressed or __NOP__)(game, key)
end

function love.mousepressed(x, y, button, istouch)
	(game.mousepressed or __NOP__)(game, x, y, button, istouch)
end

function love.mousereleased(x, y, button, istouch)
	(game.mousereleased or __NOP__)(game, x, y, button, istouch)
end

function love.mousemoved(x, y, dx, dy)
	(game.mousemoved or __NOP__)(game, x, y, dx, dy)
end
