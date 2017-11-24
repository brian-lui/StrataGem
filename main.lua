local love = _G.love
require "inits"
require "lovedebug"
require "classcommons"
local common = require "class.commons"
local game

function love.load()
	love.window.setMode(window.width * window.scale, window.height * window.scale)
	love.window.setTitle("StrataGem!")
	game = common.instance(require "game")
end
-- local sandbox = require 'animationsandbox'

local __NOP__ = function () end

function love.draw()
	local f = game.draw or __NOP__
	local TLfres = window.tlfres
	love.graphics.push("all")
		love.graphics.scale(window.scale, window.scale)
		f(game)
	TLfres.beginRendering(window.width, window.height)
	TLfres.endRendering()
	love.graphics.pop()
end

function love.update(dt)
	(game.update or __NOP__)(game, dt)
end

function love.keypressed(key)
	(game.keypressed or __NOP__)(game, key)
end

function love.mousepressed(x, y, button, istouch)
	x, y = x / window.scale, y / window.scale
	local f = game.mousepressed or __NOP__
	f(game, x, y, button, istouch)
end

function love.mousereleased(x, y, button, istouch)
	x, y = x / window.scale, y / window.scale
	local f = game.mousereleased or __NOP__
	f(game, x, y, button, istouch)
end

function love.mousemoved(x, y, dx, dy)
	x, y, dx, dy = x / window.scale, y / window.scale, dx / window.scale, dy / window.scale
	local f = game.mousemoved or __NOP__
	f(game, x, y, dx, dy)
end
