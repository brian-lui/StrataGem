--[[
This file describes some "global" defaults.
--]]

local love = _G.love
local TLfres = require "/libraries/tlfres"

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
	STANDARD_REGULAR = love.graphics.newFont('/fonts/anonymous.ttf', 20),
	STANDARD_MEDIUM = love.graphics.newFont('/fonts/anonymous.ttf', 30),
	STANDARD_BIGGER = love.graphics.newFont('/fonts/anonymous.ttf', 40),
	CARTOON_SMALL = love.graphics.newFont('/fonts/BD_Cartoon_Shout.ttf', 30),
	CARTOON_MEDIUM = love.graphics.newFont('/fonts/BD_Cartoon_Shout.ttf', 60),
	CARTOON_BIG = love.graphics.newFont('/fonts/BD_Cartoon_Shout.ttf', 90),
}
inits.FONT.CARTOON_SMALL_ROWADJUST = -math.ceil(inits.FONT.CARTOON_SMALL:getHeight() * 0.5)
inits.FONT.CARTOON_MEDIUM_ROWADJUST = -math.ceil(inits.FONT.CARTOON_MEDIUM:getHeight() * 0.5)
inits.FONT.CARTOON_BIG_ROWADJUST = -math.ceil(inits.FONT.CARTOON_BIG:getHeight() * 0.5)

return inits