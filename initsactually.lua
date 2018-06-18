local love = _G.love
local TLfres = require "tlfres"

local inits = {}

local DRAWSPACE_WIDTH = 1920
local DRAWSPACE_HEIGHT = 1080

inits.drawspace = {
	width = DRAWSPACE_WIDTH,
	height = DRAWSPACE_HEIGHT,
	scale = TLfres.getScale(DRAWSPACE_WIDTH, DRAWSPACE_HEIGHT),
	tlfres = TLfres,
}

inits.ID = {
	reset = function(self)
		self.gem = 0
		self.piece = 0
		self.particle = 0
		self.background_particle = 0
		self.character_select = 0
	end
}
inits.ID:reset()

inits.FONT = {
	REGULAR = love.graphics.newFont('/fonts/anonymous.ttf', 20),
	MEDIUM = love.graphics.newFont('/fonts/anonymous.ttf', 30),
	SLIGHTLY_BIGGER = love.graphics.newFont('/fonts/anonymous.ttf', 40),
}

return inits