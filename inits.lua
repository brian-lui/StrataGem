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
AllGemPlatforms = {}

-- put unique things and empty table inits here
-- shallowcopy startGame will set both players to the same empty table otherwise
p1 = {hand = {}, start_col = 1, end_col = 4, ID = "P1", played_pieces = {}}
p2 = {hand = {}, start_col = 5, end_col = 8, ID = "P2", played_pieces = {}}
p1.enemy = p2
p2.enemy = p1
players = {p1, p2}

FONT = {
	TITLE = love.graphics.newFont('/fonts/Comic.otf', 30)
}

COLOR = {
	WHITE = {255, 255, 255, 255}
}

SPEED = {
	MIN_SNAP = window.width / 512, -- snap-to if it's less than this number
	ROTATE = math.pi / 25,
	PLATFORM_ROTATION = 0.02,
	PLATFORM_FADE = 8,
	DAMAGE_SHAKE_FRAMES = 4,
	DAMAGE_DROP = window.height / 192, -- pixels for damage particles after reaching platform
	PLATFORM = window.height / 192, -- pixels per second for pieces to shuffle
	GEM_EXPLODE_FRAMES = 20,
	GEM_FADE_FRAMES = 10,
	GEM_PLATFORM_TURN_RED = 8,
}

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
