--[[
This is the gamestate module for the multiplayer character select screen.
--]]


local common = require "class.commons"

local Multiplayer = {name = "Multiplayer", gametype = "Netplay"}
function Multiplayer:init()
	Multiplayer.charselect = common.instance(require "charselect", self, Multiplayer)
	Multiplayer.charselect:init(self, Multiplayer)
end

function Multiplayer:enter()
	Multiplayer.charselect:enter()
end

function Multiplayer:update(dt)
	Multiplayer.charselect:update(dt)
end

function Multiplayer:draw()
	Multiplayer.charselect:draw()
end

function Multiplayer:openSettingsMenu()
	self:_openSettingsMenu(Multiplayer)
end

function Multiplayer:closeSettingsMenu()
	self:_closeSettingsMenu(Multiplayer)
end


-- add custom things to these three functions
function Multiplayer:_pressed(x, y)
	Multiplayer.charselect:_controllerPressed(x, y)
end

function Multiplayer:_released(x, y)
	Multiplayer.charselect:_controllerReleased(x, y)
end

function Multiplayer:_moved(x, y)
	Multiplayer.charselect:_controllerMoved(x, y)
end

function Multiplayer:mousepressed(x, y) Multiplayer._pressed(self, x, y) end
function Multiplayer:touchpressed(_, x, y) Multiplayer._pressed(self, x, y) end

function Multiplayer:mousereleased(x, y) Multiplayer._released(self, x, y) end
function Multiplayer:touchreleased(_, x, y) Multiplayer._released(self, x, y) end

function Multiplayer:mousemoved(x, y) Multiplayer._moved(self, x, y) end
function Multiplayer:touchmoved(_, x, y) Multiplayer._moved(self, x, y) end


return Multiplayer
