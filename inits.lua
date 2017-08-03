-- For compatibility; Lua 5.3 moved unpack to table.unpack
_G.table.unpack = _G.table.unpack or _G.unpack

window = {
	width = 1024,
	height = 768
}

ID = {
	reset = function(self)
		self.gem, self.piece, self.particle, self.background = 0, 0, 0, 0
	end
}
ID:reset()

--[[
FONT = {
	TITLE = love.graphics.newFont('/fonts/Comic.otf', 30)
}
--]]
--[[
COLOR = {
	WHITE = {255, 255, 255, 255}
}
--]]
--[[
SPEED = {
	MIN_SNAP = window.width / 512, -- snap-to if it's less than this number
	ROTATE = math.pi / 25,
}
--]]
