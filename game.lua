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
Game.VERSION = "64.0"

function Game:init()
	self.p1 = common.instance(require "character")	-- Dummy
	self.p2 = common.instance(require "character")
	self.phaseManager = common.instance(require "phasemanager", self)
	self.rng = love.math.newRandomGenerator()
	self.bgm = nil
	self.stage = common.instance(require "stage", self)	-- playing field area and grid
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
	self.frame = 0	-- TODO: Deglobalize
end

-- testing!
local Gem = require 'gem'

local colorAliases = {
	r = "Red",
	red = "Red",
	b = "Blue",
	blue = "Blue",
	g = "Green",
	green = "Green",
	y = "Yellow",
	yellow = "Yellow"
}
-- rows is from 8 at the top to 1 at the bottom
local function n(self, row, column, color)
	color = colorAliases[color:lower()]
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
	local gem_color = Gem[color .. "Gem"]
	self.stage.grid[row][column].gem = common.instance(gem_color, x, y)
	self.stage.grid[row][column].gem:addOwner(1)
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
		p1.cur_mp = math.min(p1.cur_mp + 20, p1.MAX_MP)
		p2.cur_mp = math.min(p2.cur_mp + 20, p2.MAX_MP)
	elseif key == "k" then self.canvas[6]:renderTo(function() love.graphics.clear() end)
	elseif key == "z" then self:start("1P", "heath", "walter", self.background.Starfall, nil, 1)
	elseif key == "x" then
		p1.cur_mp = 64
		--p2.cur_mp = 20
	elseif key == "c" then
		local Pic = require 'pic'
		local image = require 'image'
		local temp = common.instance(Pic, self, {x = stage.width * 0.5, y = stage.height * 0.5, image = image.red_gem})
		self.particles.allParticles.PieEffects[ID.particle] = temp
		temp.update = temp.greatupdate
		local newbluegem = function()
			local x, y = temp.x, temp.y
			local blue = common.instance(Pic, self, {x = x, y = y, image = image.blue_gem})
			blue.update = blue.greatupdate
			self.particles.allParticles.PieEffects[ID.particle] = blue
		end
		local during = {10, 5, newbluegem}
		temp:moveTo{x = 300, y = 200, duration = 120, during = during}
		self.queue:add(10, temp.moveTo, temp, {x = 600, y = 450, duration = 60, easing = "outQuart"})
	elseif key == "v" then	-- print summary state
		local toprint = {"", "", "", "", "", "", "", "", ""}
		for row = 7, 14 do
			for col = 1, 8 do
				if grid[row][col].gem then
					local colors = {red = "R", blue = "B", green = "G", yellow = "Y"}
					toprint[row-6] = toprint[row-6] .. colors[ grid[row][col].gem.color ]
				else
					toprint[row-6] = toprint[row-6] .. "."
				end
			end
		end
		toprint[9] = p1.cur_mp .. "|" .. p2.cur_mp
		for i = 1, #toprint do print(toprint[i]) end
	elseif key == "b" then
		n(8, 7, "G")
		n(8, 6, "G")
		n(7, 5, "G")
		n(8, 5)
		n(8, 4)
		n(7, 3)
		n(8, 3, "Y")
		n(8, 2, "Y")
	elseif key == "n" then
		n(8, 2, "G")
		n(8, 4, "G")
		n(8, 5, "G")
		n(7, 5, "G")
		n(8, 6, "R")
	elseif key == "m" then
		p1.hand[3].platform:screenshake(30)
	elseif key == "," then
		self.debug_overlay = function ()
			return self.particles:getNumber("Damage", self:playerByIndex(2))
		end
	elseif key == "." then
		self.timeStep = self.timeStep == 0.1 and 1/60 or 0.1
	end
end

return common.class("Game", Game)
