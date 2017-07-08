local love = _G.love
local class = require "middleclass"

local game = class("Game")

game.INIT_TIME_TO_NEXT = 430 -- frames in each action phase
game.INIT_PIECE_WAITING_TIME = 30 -- delay before new pieces
game.LOSE_ROW = 6
game.RUSH_ROW = 8 -- can only rush if this row is empty
game.NETPLAY_MAX_WAIT = 60
game.STATE_SEND_WAIT = 80
game.VERSION = "64.0"

function game:initialize()
	-- TODO: Make Player into a class and uncomment these.
	-- self.p1 = Player()
	-- self.p2 = Player()
	self.current_screen = "title"
	self.input_method = mouse
	self.rng = love.math.newRandomGenerator()
	self.bgm = nil
	self.engine = require "engine"
	self.stage = require "stage"(self)	-- playing field area and grid
	self.particles = require "particles"(self.stage)
	self.character = require "character"

	self.character.initialize(self.stage)
	self.engine.initialize(self)
	self:reset()
end

function game:players()
	local p = {p1, p2}	-- TODO: Make these self.p1 and self.p1 once they're not globals anymore
  local i = 0
  return function()
		i = i + 1
		return p[i]
	end
end

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
	self.rng:setSeed(os.time())	-- TODO: This probably causes desyncs
	self.orig_rng_seed = self.rng:getSeed() -- for debugging
	frame = 0	-- TODO: Deglobalize
end

return game
