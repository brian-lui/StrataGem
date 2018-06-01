local love = _G.love
require 'utilities' -- move
local image = require 'image'
local common = require "class.commons" -- class support
local Pic = require 'pic'

local DebugConsole = {}

function DebugConsole:init(params)
	self.game = params.game
end

function DebugConsole:create(params)
	assert(params.game, "Game object not received!")
	return common.instance(self, params)
end

function DebugConsole:draw(params)
	print("draw the debug console stuff here")
end

function DebugConsole:update(dt)
	print("update the debug console stuff here")
end

return common.class("DebugConsole", DebugConsole)
