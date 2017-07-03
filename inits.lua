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

game = {
	current_screen = "title",
	input_method = mouse,
	rng = love.math.newRandomGenerator(),
	BGM = nil,
	INIT_TIME_TO_NEXT = 430, -- frames in each action phase
	INIT_PIECE_WAITING_TIME = 30, -- delay before new pieces
	LOSE_ROW = 6,
	RUSH_ROW = 8, -- can only rush if this row is empty
	NETPLAY_MAX_WAIT = 60,
	STATE_SEND_WAIT = 80,
}

function game:newTurn()
	self.turn = self.turn + 1
	self.phase = "Action"
	self.frozen = false
	self.time_to_next = game.INIT_TIME_TO_NEXT
end

function game:reset()
	self.phase = "Intro"
	self.turn = 1
	self.time_to_next = self.INIT_TIME_TO_NEXT
	self.piece_waiting_time = self.INIT_PIECE_WAITING_TIME
	self.netplay_wait = 0
	self.frozen = false
	self.scoring_combo = 0
	self.round_ended = false
	self.me_player = false
	self.them_player = false
	self.active_piece = false
	self.finished_getting_pieces = false
	self.piece_origin = {x = 0, y = 0}
	self.grid_wait = 0
	self.screenshake_frames = 0
	self.screenshake_vel = 0
	self.rng.setSeed(os.time())	-- TODO: This probably causes desyncs
	self.rng.orig_rng_seed = self.rng.getSeed() -- for debugging
	frame = 0
end
game:reset()
