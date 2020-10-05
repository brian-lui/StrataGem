--[[
This is the gamestate module for the single player character select screen.
--]]


local common = require "class.commons"

local Singleplayer = {name = "Singleplayer", gametype = "Singleplayer"}
function Singleplayer:init()
	self.charselect = common.instance(require "charselect", self, Singleplayer)
	self.charselect:init(self, Singleplayer)
end

function Singleplayer:enter()
	self.charselect:enter()
end

function Singleplayer:update(dt)
	self.charselect:update(dt)
end

function Singleplayer:draw()
	self.charselect:draw()
end

function Singleplayer:openSettingsMenu()
	self:_openSettingsMenu(Singleplayer)
end

function Singleplayer:closeSettingsMenu()
	self:_closeSettingsMenu(Singleplayer)
end


-- add custom things to these three functions
function Singleplayer:_pressed(x, y)
	self.charselect:_controllerPressed(x, y)
end

function Singleplayer:_released(x, y)
	self.charselect:_controllerReleased(x, y)
end

function Singleplayer:_moved(x, y)
	self.charselect:_controllerMoved(x, y)
end

function Singleplayer:mousepressed(x, y) Singleplayer._pressed(self, x, y) end
function Singleplayer:touchpressed(_, x, y) Singleplayer._pressed(self, x, y) end

function Singleplayer:mousereleased(x, y) Singleplayer._released(self, x, y) end
function Singleplayer:touchreleased(_, x, y) Singleplayer._released(self, x, y) end

function Singleplayer:mousemoved(x, y) Singleplayer._moved(self, x, y) end
function Singleplayer:touchmoved(_, x, y) Singleplayer._moved(self, x, y) end

return Singleplayer
