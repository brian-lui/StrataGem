local common = require "class.commons"

local Multiplayer = {name = "Multiplayer", gametype = "Netplay"}
function Multiplayer:init()
	self.charselect = common.instance(require 'charselect', self, Multiplayer)
	self.charselect:init(self, Multiplayer)
end

function Multiplayer:enter()
	self.charselect:enter()
end

function Multiplayer:update(dt)
	self.charselect:update(dt)
end

function Multiplayer:draw()
	self.charselect:draw()
end

function Multiplayer:openSettingsMenu()
	self:_openSettingsMenu(Multiplayer)
end

function Multiplayer:closeSettingsMenu()
	self:_closeSettingsMenu(Multiplayer)
end

function Multiplayer:mousepressed(x, y)
	self:_mousepressed(x, y, Multiplayer)
end

function Multiplayer:mousereleased(x, y)
	self:_mousereleased(x, y, Multiplayer)
end

function Multiplayer:mousemoved(x, y)
	self:_mousemoved(x, y, Multiplayer)
end

return Multiplayer
