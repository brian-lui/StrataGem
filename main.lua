local love = _G.love

require 'inits'
--require 'lovedebug'
require 'utilities' -- helper functions
require "classcommons"
local common = require "class.commons"

local game

local music

function love.load()
	_G.game = common.instance(require "game")
	game = _G.game

	music = require 'music'

	music.setBGM("bgm.mp3", 1)
end
-- local sandbox = require 'animationsandbox'

-- build screen
love.window.setMode(window.width, window.height)
love.window.setTitle("StrataGem!")

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

-- TODO: Remove this bit and animationsandbox.lua
--game.current_screen = "animation_testing"
--sandbox.g()

--local background = require 'background'
--game:start("1P", character.heath, character.walter, background.list[1].background, nil, 1)
