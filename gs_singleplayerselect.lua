local common = require "class.commons"

local Singleplayer = {name = "Singleplayer", gametype = "Singleplayer"}
function Singleplayer:init()
	self.charselect = common.instance(require 'charselect', self, Singleplayer)
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

function Singleplayer:mousepressed(x, y)
	self:_mousepressed(x, y, Singleplayer)
end

function Singleplayer:mousereleased(x, y)
	self:_mousereleased(x, y, Singleplayer)
end

function Singleplayer:mousemoved(x, y)
	self:_mousemoved(x, y, Singleplayer)
end

return Singleplayer
