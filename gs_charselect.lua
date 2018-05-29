local common = require "class.commons"

local SinglePlayer = {name = "SinglePlayer", gametype = "1P"}
function SinglePlayer:init()
	self.gametype = "1P"
	self.charselect = common.instance(require 'charselect', self, SinglePlayer)
	self.charselect:init(self, SinglePlayer)
	self.gametype = "1P"
end	

function SinglePlayer:enter()
	self.charselect:enter()
end

function SinglePlayer:update(dt)
	self.charselect:update(dt)
end

function SinglePlayer:draw()
	self.charselect:draw()
end

function SinglePlayer:openSettingsMenu()
	self:_openSettingsMenu(SinglePlayer)
end

function SinglePlayer:closeSettingsMenu()
	self:_closeSettingsMenu(SinglePlayer)
end

function SinglePlayer:mousepressed(x, y)
	self:_mousepressed(x, y, SinglePlayer)
end

function SinglePlayer:mousereleased(x, y)
	self:_mousereleased(x, y, SinglePlayer)
end

function SinglePlayer:mousemoved(x, y)
	self:_mousemoved(x, y, SinglePlayer)
end

return SinglePlayer
