local love = _G.love
local common = require "classcommons"

--[==================[
QUEUE COMPONENT
--]==================]

local Queue = {}

function Queue:init(game)
	self.game = game
end

function Queue:add(frames, func, ...)
	assert(frames % 1 == 0 and frames >= 0, "non-integer or negative queue received")
	local a = self.game.frame + frames
	self[a] = self[a] or {}
	table.insert(self[a], {func, {...}})
end

function Queue:update()
	local do_today = self[self.game.frame]
	if do_today then
		for i = 1, #do_today do
			local func, args = do_today[i][1], do_today[i][2]
			func(table.unpack(args))
		end
		self[self.game.frame] = nil
	end
end

Queue = common.class("Queue", Queue)

--[==================[
END QUEUE COMPONENT
--]==================]

local Game = {}

Game.INIT_TIME_TO_NEXT = 430 -- frames in each action phase
Game.INIT_PIECE_WAITING_TIME = 30 -- delay before new pieces
Game.LOSE_ROW = 6
Game.RUSH_ROW = 8 -- can only rush if this row is empty
Game.NETPLAY_MAX_WAIT = 60
Game.STATE_SEND_WAIT = 80
Game.DAMAGE_PARTICLE_TO_PLATFORM_FRAMES = 54
Game.DAMAGE_PARTICLE_PER_DROP_FRAMES = 26
Game.EXPLODING_PLATFORM_FRAMES = 60
Game.VERSION = "64.0"

function Game:init()
	self.debug_drawGemOwners = true	-- TODO: Remove this someday.
	self.debug_drawParticleDestinations = true
	self.debug_drawGamestate = true
	self.debug_drawDamage = true
	self.debug_drawGrid = true

	self.phaseManager = common.instance(require "phasemanager", self)
	self.rng = love.math.newRandomGenerator()
	self.sound = common.instance(require "sound", self)
	self.music = common.instance(require "music", self)
	self.stage = common.instance(require "stage", self)	-- playing field area and grid
	self.p1 = common.instance(require "character", 1, self)	-- Dummies
	self.p2 = common.instance(require "character", 2, self)
	self.background = common.instance(require "background", self)
	self.animations = common.instance(require "animations", self)
	self.particles = common.instance(require "particles", self)
	self.client = common.instance(require "client", self)
	self.ui = common.instance(require "ui", self)
	self.queue = common.instance(Queue, self)

	self.music:setBGM("buzz.ogg", 1)

	self.statemanager = common.instance(require "statemanager", self)
	self.statemanager:switch(require "gs_title")

	self:reset()
end

function Game:start(gametype, char1, char2, bkground, seed, side)
	ID:reset()

	self:reset()
	self.sound:reset()
	self.stage.grid:reset()
	self.particles:reset()
	if seed then
		self.rng:setSeed(seed)
	end

	self.p1 = common.instance(require("characters." .. char1), 1, self)
	self.p2 = common.instance(require("characters." .. char2), 2, self)
	self.p1.enemy = self.p2
	self.p2.enemy = self.p1

	side = side or 1
	if side == 1 then
		self.me_player, self.them_player = self.p1, self.p2
		print("You are PLAYER 1. This will be graphicalized soon")
	elseif side == 2 then
		self.me_player, self.them_player = self.p2, self.p1
		print("You are PLAYER 2. This will be graphicalized soon")
	else
		print("Sh*t")
	end

	for player in self:players() do
		player:cleanup()
	end
	self.background.current = bkground
	self.background.current.reset(self.background)

	self.type = gametype
	self.statemanager:switch(require "gs_main")
end

function Game:update(dt)
	self.client:update(dt)
end

function Game:playerByIndex(i)
	local p = {self.p1, self.p2}
	return p[i]
end

function Game:players()
	local p = {self.p1, self.p2}
  local i = 0
  return function()
		i = i + 1
		return p[i]
	end
end

function Game:newTurn()
	self.turn = self.turn + 1
	self.phase = "Action"
	self.frozen = false
	self.time_to_next = self.INIT_TIME_TO_NEXT
end

function Game:reset()
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
	self.grid_wait = 0
	self.screenshake_frames = 0
	self.screenshake_vel = 0
	self.rng:setSeed(os.time())	-- TODO: This probably causes desyncs
	self.orig_rng_seed = self.rng:getSeed() -- for debugging
	self.frame = 0
end

-- testing!
local Gem = require 'gem'

local colorAliases = {
	r = "red",
	red = "red",
	b = "blue",
	blue = "blue",
	g = "green",
	green = "green",
	y = "yellow",
	yellow = "yellow"
}
-- rows is from 8 at the top to 1 at the bottom
local function n(self, row, column, color, owner)
	owner = owner or 0
	color = colorAliases[color:lower()] or "red"
	if type(row) ~= "number" or type(column) ~= "number" then
		print("row or column not a number!")
		return
	end
	if row % 1 ~= 0 or column % 1 ~= 0 then
		print("row or column not an integer!")
		return
	end
	if row < 1 or row > 8 then
		print("row out of bounds! 1 = bottom, 8 = top")
		return
	end
	if column < 1 or column > 8 then
		print("column out of bounds!")
		return
	end

	row = row + 6
	local x, y = self.stage.grid.x[column], self.stage.grid.y[row]
	self.stage.grid[row][column].gem = common.instance(Gem, self, x, y, color)
	if owner > 0 then
		self.stage.grid[row][column].gem:addOwner(owner)
	end
end

local function nrow(game, row, colors)
	if type(colors) ~= "string" or #colors ~= 8 then
		love.errhand("nrow() received invalid string: \"" .. tostring(colors) .. "\"")
	end
	for i = 1, 8 do
		local c = colors:sub(i, i)
		if c ~= " " then
			n(game, row, i, c)
		end
	end
end

function Game:keypressed(key)
	local stage = self.stage
	local grid = stage.grid
	local p1, p2 = self.p1, self.p2

	if key == "escape" then
		love.event.quit()
	elseif key == "t" then
		grid:addBottomRow(p1)
		for g in grid:gems() do
			g.x = g.target_x
			g.y = g.target_y
		end
	elseif key == "y" then
		grid:addBottomRow(p2)
		for g in grid:gems() do
			g.x = g.target_x
			g.y = g.target_y
		end
	elseif key == "q" then reallyprint(love.filesystem.getSaveDirectory())
	elseif key == "a" then self.time_to_next = 1
	elseif key == "s" then p1.hand:addDamage(1)
	elseif key == "d" then p2.hand:addDamage(1)
	elseif key == "f" then
		for player in self:players() do
			player.cur_burst = math.min(player.cur_burst + 1, player.MAX_BURST)
			player:addSuper(10000)
			player:resetMP()
		end
	elseif key == "k" then self.canvas[6]:renderTo(function() love.graphics.clear() end)
	elseif key == "z" then self:start("1P", "heath", "walter", self.background.Starfall, nil, 1)
	elseif key == "x" then
		nrow(self, 7, "RGBY    ")
		nrow(self, 8, "RGBY    ")
	elseif key == "c" then
		nrow(self, 1, "B       ")
		nrow(self, 2, "B       ")
		nrow(self, 3, "RG      ")
		nrow(self, 4, "YY      ")
		nrow(self, 5, "RRG     ")
		nrow(self, 6, "BGB     ")
		nrow(self, 7, "BRR     ")
		nrow(self, 8, "RGGY    ")
	elseif key == "v" then	-- garbage move up match
		nrow(self, 7, "  BBRRG ")
		nrow(self, 8, "  RRBBY ")
	elseif key == "b" then
		nrow(self, 4, "     R G")
		nrow(self, 5, "    RBBR")
		nrow(self, 6, "  GRBYYR")
		nrow(self, 7, " RRGBGGY")
		nrow(self, 8, " YYRGBBR")
	elseif key == "n" then
		nrow(self, 6, "B       ")
		nrow(self, 7, "YY      ")
		nrow(self, 8, "GRG     ")
	elseif key == "m" then
		self.debug_drawGemOwners = not self.debug_drawGemOwners
		self.debug_drawParticleDestinations = not self.debug_drawParticleDestinations
		self.debug_drawGamestate = not self.debug_drawGamestate
		self.debug_drawDamage = not self.debug_drawDamage
		self.debug_drawGrid = not self.debug_drawGrid
	elseif key == "," then
		self.debug_overlay = function ()
			return p1.super_meter_image.transparency
		end
	elseif key == "." then
		self.timeStep = self.timeStep == 0.1 and 1/60 or 0.1
	end
end

return common.class("Game", Game)
