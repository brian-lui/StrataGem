local common = require "class.commons"

local MultiPlayer = {name = "MultiPlayer", gametype = "Netplay"}
function MultiPlayer:init()
	self.charselect = common.instance(require 'charselect', self, MultiPlayer)
	self.charselect:init(self, MultiPlayer)
end	

function MultiPlayer:enter()
	self.charselect:enter()
end

function MultiPlayer:update(dt)
	self.charselect:update(dt)
end

function MultiPlayer:draw()
	self.charselect:draw()
end

function MultiPlayer:openSettingsMenu()
	self:_openSettingsMenu(MultiPlayer)
end

function MultiPlayer:closeSettingsMenu()
	self:_closeSettingsMenu(MultiPlayer)
end

function MultiPlayer:mousepressed(x, y)
	self:_mousepressed(x, y, MultiPlayer)
end

function MultiPlayer:mousereleased(x, y)
	self:_mousereleased(x, y, MultiPlayer)
end

function MultiPlayer:mousemoved(x, y)
	self:_mousemoved(x, y, MultiPlayer)
end

return MultiPlayer
