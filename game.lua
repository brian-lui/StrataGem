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
Game.GEM_EXPLODE_FRAMES = 20
Game.GEM_FADE_FRAMES = 10
Game.EXPLODING_PLATFORM_FRAMES = 60
Game.VERSION = "64.0"

function Game:init()
	self.debug_drawGemOwners = true	-- TODO: Remove this someday.
	self.debug_drawParticleDestinations = true
	self.debug_drawGamestate = true
	self.debug_drawDamage = true
	self.debug_drawGrid = true

	self.unittests = common.instance(require "unittests", self) -- debug testing
	self.phaseManager = common.instance(require "phasemanager", self)
	self.rng = love.math.newRandomGenerator()
	self.sound = common.instance(require "sound", self)
	self.stage = common.instance(require "stage", self)	-- playing field area and grid
	self.grid = common.instance(require "grid", self)
	self.p1 = common.instance(require "character", 1, self)	-- Dummies
	self.p2 = common.instance(require "character", 2, self)
	self.background = common.instance(require "background", self)
	self.animations = common.instance(require "animations", self)
	self.particles = common.instance(require "particles", self)
	self.client = common.instance(require "client", self)
	self.ui = common.instance(require "ui", self)
	self.queue = common.instance(Queue, self)
	self.statemanager = common.instance(require "statemanager", self)
	self.statemanager:switch(require "gs_title")
	self:reset()
end

function Game:start(gametype, char1, char2, bkground, seed, side)
	ID:reset()

	self:reset()
	self.sound:reset()
	self.grid:reset()
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

	-- Spawn the appropriate ai to handle opponent (net input or actual AI)
	self.ai = common.instance(require(gametype == "Netplay" and "ai_net" or "ai"), self, self.them_player)

	for player in self:players() do player:cleanup() end

	self.type = gametype
	self.statemanager:switch(require "gs_main")
	self.current_background = common.instance(self.background[bkground], self)
end

function Game:update(dt)
	self.client:update(dt)
	self.sound:update()
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
	self.paused = false
end

function Game:keypressed(key)
	local grid = self.grid
	local p1, p2 = self.p1, self.p2

	if key == "escape" then
		love.event.quit()
	elseif key == "f3" then	-- Toggle debug mode (see lovedebug.lua). Key chosen from Minecraft.
		_G.debugEnabled = not _G.debugEnabled
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
	elseif key == "g" then
		self.unittests.displayNoRush(self)
	elseif key == "k" then self.canvas[6]:renderTo(function() love.graphics.clear() end)
	elseif key == "z" then self.unittests.resetWithSeed(self, nil)
	elseif key == "f1" then self.unittests.resetWithSeed(self, 12345)
	elseif key == "x" then
		self.unittests.garbageMatch(self)
	elseif key == "c" then
		self.unittests.multiCombo(self)
	elseif key == "v" then
		self.unittests.p2VerticalMatch(self)
	elseif key == "b" then
		self.unittests.allRedGems(self)
	elseif key == "n" then
		self.unittests.shuffleHands(self)
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
