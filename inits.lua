local love = _G.love

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

AllParticles = {}

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

mouse = {
	x = 0,
	y = 0,
	last_clicked_frame = 0,
	last_clicked_x = 0,
	last_clicked_y = 0,
	down = false,
	QUICKCLICK_FRAMES = 15,
	QUICKCLICK_MAX_MOVE = 0.05,
}
