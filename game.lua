--[[
This is the main game module.
It contains several major components:
Queue - this is the component that allows convenient callbacks, for situations
where there isn't a better way to callback
Serialization - this module has a section for serializing the gamestate and
delta
Menu - this has the menu prototype, e.g. the settings menu and actions
Global default callbacks - this has global default functions for things like
keypress, mouse actions
Global default functions - this has global functions that apply to multiple
states, such as darkening and brightening screen
--]]

local love = _G.love
local Pic = require "pic"
local common = require "/libraries/classcommons"
local Gem = require "gem"
local Piece = require "piece"
local images = require "images"

--[==================[
QUEUE COMPONENT
--]==================]

local Queue = {}

function Queue:init(game)
	self.game = game
end

function Queue:add(frames, func, ...)
	assert(frames % 1 == 0 and frames >= 0, "non-integer or negative queue received")
	assert(type(func) == "function", "non-function of type " .. type(func) .. " received")
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

Game.NETPLAY_MAX_WAIT = 60
Game.STATE_SEND_WAIT = 80
Game.DAMAGE_PARTICLE_TO_PLATFORM_FRAMES = 54
Game.DAMAGE_PARTICLE_PER_DROP_FRAMES = 26
Game.GEM_EXPLODE_FRAMES = 20
Game.GEM_FADE_FRAMES = 10
Game.PLATFORM_FALL_EXPLODE_FRAMES = 30
Game.PLATFORM_FALL_FADE_FRAMES = 8
Game.EXPLODING_PLATFORM_FRAMES = 60
Game.TWEEN_TO_LANDING_ZONE_DURATION = 24
Game.VERSION = "71.0"

function Game:init()
	self.frame, self.time_step, self.timeBucket = 0, 1/60, 0
	self.global_ui = { -- all-screens effects
		fx = {},
		fades = {},
	}
	self.debugconsole = common.instance(require "/helpers/debugconsole", self)
	self.quotes = require "/quotes/quotes"
	self.camera = common.instance(require "/libraries/camera")
	self.inits = require "/helpers/inits"
	self.settings = require "/helpers/settings"
	self.rng = love.math.newRandomGenerator()
	self.unittests = common.instance(require "/helpers/unittests", self)
	self.phase = common.instance(require "phase", self)
	self.sound = common.instance(require "sound", self)
	self.stage = common.instance(require "stage", self)	-- playing field
	self.grid = common.instance(require "grid", self)
	self.uielements = common.instance(require "uielements", self)
	self.p1 = common.instance(require "character", 1, self)	-- Dummies
	self.p2 = common.instance(require "character", 2, self)
	self.background = common.instance(require "background", self)
	self.animations = common.instance(require "animations", self)
	self.particles = common.instance(require "particles", self)
	self.client = common.instance(require "client", self)
	self.queue = common.instance(Queue, self)
	self.statemanager = common.instance(require "/libraries/statemanager", self)
	self.debugtextdump = common.instance(require "/helpers/debugtextdump", self)
	self:switchState("gs_title")

	-- need to load it again haha
	self.debugconsole = common.instance(require "/helpers/debugconsole", self)
	self.debugconsole:setDefaultDisplayParams()
	self:reset()
end

function Game:reset()
	self.current_phase = "Intro"
	self.turn = 1
	self.netplay_wait = 0
	self.inputs_frozen = false
	self.scoring_combo = 0
	self.round_ended = false
	self.me_player = false
	self.them_player = false
	self.active_piece = false
	self.grid_wait = 0
	self.rng:setSeed(os.time())
	self.frame = 0
	self.paused = false
	self.settings_menu_open = false
	self.screen_dark = {false, false, false}
	self.inits.ID:reset()
	self.sound:reset()
	self.grid:reset()
	self.particles:reset()
	self.uielements:clearScreenUIColor()

	self.tie_priority = self.rng:random(2) -- Who has ability priority in a tie
end

-- takes a string
function Game:switchState(gamestate)
	self.current_gamestate = require(gamestate)
	self.statemanager:switch(self.current_gamestate)
end

--[[
This is a wrapper to do stuff at 60hz. We want the logic stuff to be at
60hz, but the drawing can be at whatever! So each love.update runs at
unbounded speed, and then adds dt to bucket. When bucket is larger
than 1/60, it runs the logic functions until bucket is less than 1/60,
or we reached the maximum number of times to run the logic this cycle.
--]]
function Game:timeDip(func, ...)
	for _ = 1, 4 do -- run a maximum of 4 logic cycles per love.update cycle
		if self.timeBucket >= self.time_step then
			func(...)
			self.frame = self.frame + 1
			self.timeBucket = self.timeBucket - self.time_step
		end
	end
end

--[[ Mandatory parameters:
	gametype - Netplay or Singleplayer
	char1 - string for the character in p1
	char2 - string for the character in p2
	playername1 - name of the player in p1
	playername2 - name of the player in p1
	background - string for the background
	(for replays) deltas - table of deltas[turn][player_num]

	Optional parameters:
	side - player's side, defaults to 1
	seed - number to use as the RNG seed
--]]

function Game:start(params)
	self:reset()
	if params.seed then self.rng:setSeed(params.seed) end

	self.p1 = common.instance(require("characters." .. params.char1), 1, self)
	self.p2 = common.instance(require("characters." .. params.char2), 2, self)
	self.p1.enemy = self.p2
	self.p2.enemy = self.p1

	local side = params.side or 1
	assert(side == 1 or side == 2, "Invalid side provided")
	if side == 1 then
		self.me_player, self.them_player = self.p1, self.p2
		print("You are PLAYER 1. This will be graphicalized soon")
	elseif side == 2 then
		self.me_player, self.them_player = self.p2, self.p1
		print("You are PLAYER 2. This will be graphicalized soon")
	end

	self.p1.player_name = params.playername1
	self.p2.player_name = params.playername2

	-- Spawn the appropriate ai to handle opponent (net input or actual AI)
	if params.gametype == "Netplay" then
		self.ai = common.instance(require("ai_netplay"), self, self.them_player)
	elseif params.gametype == "Singleplayer" then
		self.ai = common.instance(require("ai_singleplayer"), self, self.them_player)
	elseif params.gametype == "Replay" then
		assert(params.deltas, "Deltas not provided for replay")
		self.ai = common.instance(require("ai_replay"), self, self.them_player)
		self.ai:storeDeltas(params.deltas)
	else
		error("Invalid gametype provided")
	end

	for player in self:players() do player:cleanup() end

	self.type = params.gametype

	self.uielements:reset()

	self.current_background_name = params.background

	self.phase:reset()

	self:switchState("gs_versussplash")
end

function Game:setSaveFileLocation()
	local function lpad (s) return string.rep("0", 4 - #s) .. s end
	local index = 1
	local padded_index = lpad(tostring(index))
	local filename = os.date("%Y%m%d") .. padded_index .. ".txt"
	while love.filesystem.getInfo(filename, "file") do
		index = index + 1
		padded_index = lpad(tostring(index))
		filename = os.date("%Y%m%d") .. padded_index .. ".txt"
	end
	self.replay_save_location = filename
	print("set save location to " .. filename)
end

--[[
	1	game version (string)
	2	game type (string)
	3	char 1 (string)
	4	char 2 (string)
	5	player 1 name (string)
	6	player 2 name (string)
	7	background (string)
	8	seed (number)
	9	active player side (number)
-- ]]
function Game:writeReplayHeader()
	local text = {}
	text[#text+1] = self.VERSION .. ":"
	text[#text+1] = self.type .. ":"
	text[#text+1] = self.p1.character_name .. ":"
	text[#text+1] = self.p2.character_name .. ":"
	text[#text+1] = self.p1.player_name .. ":"
	text[#text+1] = self.p2.player_name .. ":"
	text[#text+1] = self.current_background_name .. ":"
	text[#text+1] = self.rng:getSeed() .. ":"
	text[#text+1] = self.me_player.player_num .. ":"

	text = table.concat(text) .. "\n"
	love.filesystem.append(self.replay_save_location, text)
end

function Game:writeDeltas()
	local client = self.client
	local text
	if self.type == "Netplay" then
		if self.me_player.player_num == 1 then
			text = client.our_delta .. ":" .. client.their_delta .. ":\n"
		elseif self.me_player.player_num == 2 then
			text = client.their_delta .. ":" .. client.our_delta .. ":\n"
		else
			error("invalid me_player.player_num")
		end
	elseif self.type == "Singleplayer" then
		text = self.ai.player_delta .. ":" .. self.ai.ai_delta .. ":\n"
	end

	love.filesystem.append(self.replay_save_location, text)
end

-- Writes END to the replay so we know it's finished
-- TODO: better handling
function Game:writeGameEnd()
	love.filesystem.append(self.replay_save_location, "END:END:\n")
end

function Game:playReplay(replay_string)
	replay_string = replay_string or love.filesystem.read(self.replay_save_location)

	-- convert replay string to table
	local replay = {}
	for s in (replay_string):gmatch("(.-)\n") do table.insert(replay, s) end

	-- extract header from deltas, convert to table
	local header_string = table.remove(replay, 1)
	local header = {}
	for s in (header_string):gmatch("(.-):") do table.insert(header, s) end

	-- convert deltas to tables of deltas[turn][player_num]
	local deltas = {}
	for i = 1, #replay do
		deltas[i] = {}
		for s in (replay[i]):gmatch("(.-):") do table.insert(deltas[i], s) end
	end	-- need to change all of this

	-- get parameters
	local version = header[1]
	if version ~= self.VERSION then
		print("Wrong game version for replay!")
		print("Replay version: " .. version)
		print("Game version: " .. self.VERSION)
		-- TODO: nicer handling
		return
	end

	self:start{
		gametype = "Replay",
		char1 = header[3],
		char2 = header[4],
		playername1 = header[5],
		playername2 = header[6],
		background = header[7],
		seed = header[8],
		side = 1,
		deltas = deltas,
	}
end

function Game:update(dt)
	self.client:update(dt)
	self.sound:update()
	self.uielements:screenUIupdate(dt)
	self:updateDarkenedScreenTracker(dt) -- haha
	for _, tbl in pairs(self.global_ui) do
		for _, v in pairs(tbl) do v:update(dt) end
	end
end

function Game:playerByIndex(i)
	local p = {self.p1, self.p2}
	return p[i]
end

--[[ priority:
1) Whoever has the highest basin has priority
2) If that's same, whoever has more gems in basin
3) If that's same, coin flip
--]]
function Game:players()
	local grid = self.grid
	local p1_highest_row, p2_highest_row = math.huge, math.huge
	local p1_total_gems, p2_total_gems = 0, 0

	for gem in grid:basinGems(1) do
		p1_highest_row = math.min(p1_highest_row, gem.row)
		p1_total_gems = p1_total_gems + 1
	end
	for gem in grid:basinGems(2) do
		p2_highest_row = math.min(p2_highest_row, gem.row)
		p2_total_gems = p2_total_gems + 1
	end

	local p
	if p1_highest_row > p2_highest_row then
		p = {self.p1, self.p2}
	elseif p1_highest_row < p2_highest_row then
		p = {self.p2, self.p1}
	else -- if equal tallest row
		if p1_total_gems > p2_total_gems then
			p = {self.p1, self.p2}
		elseif p1_total_gems < p2_total_gems then
			p = {self.p2, self.p1}
		else -- if number of gems is equal too
			if self.tie_priority == 1 then
				p = {self.p1, self.p2}
			else
				p = {self.p2, self.p1}
			end
		end
	end

	local i = 0
	return function()
		i = i + 1
		return p[i]
	end
end

function Game:newTurn()
	self.turn = self.turn + 1
	self.inputs_frozen = false
	self.phase.time_to_next = self.phase.INIT_ACTION_TIME
end


-- Screen will remain darkened until all nums are cleared
-- 1: player 1. 2: player 2. 3: game-wide.
function Game:darkenScreen(num)
	num = num or 3
	self.screen_dark[num] = true
end

function Game:brightenScreen(num)
	num = num or 3
	self.screen_dark[num] = false
end

local darkened_screen_tracker = {1, 1, 1}
function Game:updateDarkenedScreenTracker(dt)
	local MAX_DARK = 0.5
	for i = 1, #self.screen_dark do
		if self.screen_dark[i] then
			darkened_screen_tracker[i] = math.max(MAX_DARK, darkened_screen_tracker[i] - 0.04)
		else
			darkened_screen_tracker[i] = math.min(1, darkened_screen_tracker[i] + 0.04)
		end
	end
end

-- whether screen is dark
function Game:isScreenDark()
	local darkness_level = 1
	for i = 1, #self.screen_dark do
		darkness_level = math.min(darkened_screen_tracker[i], darkness_level)
	end
	if darkness_level ~= 1 then return darkness_level end
end

-------------------------------------------------------------------------------
------------------------------------DELTA--------------------------------------
-------------------------------------------------------------------------------
--[[
Actions can be:
	1) Play first piece
	2) Play second piece (doublecast)
	3) Play super + super parameters. Mutually exclusive with 1/2
	4) Use passive ability, if available
Encoding:
	0) Default string is "N_", for no action.
	1) Pc1_ID[piece hand position]_[piece rotation index]_[first gem column]_
		e.g. Pc1_60_3_3_
	2) Same as above, e.g. Pc2_60_2_3_
	3) S_[parameters]_
		e.g. S__, S_58390496405_
	4) P_[parameters]_
		e.g. P__, P_2405248524_
	5) ACT_[T/F]_ (whether further actions are possible)
		e.g. ACT_T_, ACT_F_
	Concatenate to get final string, e.g.:
		Pc1_59_3_2_Pc2_60_1_3_
		Pc1_59_3_2_
		S__
		N_ (no action)
--]]

-- returns the delta from playing a piece
function Game:serializeDelta(current_delta, piece, coords)
	assert(current_delta:sub(1, 2) ~= "S_", "Received piece delta, but player is supering")
	local pos = piece.hand_idx
	local rotation = piece.rotation_index
	local column = coords[1]
	local pc, ret
	if current_delta == "N_" then -- no piece played yet
		pc = "Pc1"
	elseif current_delta:sub(1, 3) == "Pc1" then
		pc = "Pc2"
	else
		error("Unexpected current_delta found: ", current_delta)
	end

	local serial = pc .. "_" .. pos .. "_" .. rotation .. "_" .. column .. "_"

	if current_delta == "N_" then
		ret = serial
	elseif current_delta:sub(1, 3) == "Pc1" then
		ret = current_delta .. serial
	else
		error("Unexpected current_delta found: ", current_delta)
	end
	print("current_delta serial is now " .. ret)
	return ret
end

-- returns the delta from playing a super
function Game:serializeSuper(current_delta)
	local player = self.me_player
	assert(current_delta == "N_", "Received super instruction, but player has action")
	local serial = player:serializeSuperDeltaParams()

	return "S_" .. serial .. "_"
end

function Game:serializePassive(current_delta)
	local serial = player:serializePassiveDeltaParams()

	return "P_" .. serial .. "_"
end

-- takes a delta and plays it to the game
function Game:deserializeDelta(delta_string, player)
	print("performing delta " .. delta_string .. " for player " .. player.player_num)

	local delta = {}
	for s in (delta_string.."_"):gmatch("(.-)_") do table.insert(delta, s) end

	for i, v in ipairs(delta) do
		if (v == "Pc1") or (v == "Pc2") then
			local pos = tonumber(delta[i+1])
			local piece = player.hand[pos].piece
			local rotation = tonumber(delta[i+2])
			local column = tonumber(delta[i+3])

			assert(piece, "piece in position " .. pos .. " not found")
			assert(rotation, "rotation not provided")
			assert(column, "placement column not provided")

			for _ = 1, rotation do piece:rotate() end

			local coords
			if piece.size == 2 then
				if piece.is_horizontal then
					coords = {column, column + 1}
				else
					coords = {column, column}
				end
			else
				coords = {column}
			end

			piece:dropIntoBasin(coords, true)

		elseif v == "S" then
			assert(player.mp >= player.SUPER_COST, "Not enough meter to super")
			player.is_supering = true
			player.super_params = delta[i+1]
		end
	end
end

-------------------------------------------------------------------------------
------------------------------------STATE--------------------------------------
-------------------------------------------------------------------------------
--[[ Serializes the current state.
State information:
	1) P1 character, P2 character
	2) P1 burst, P1 super, P1 damage
	3) P2 burst, P2 super, P2 damage
	4) Grid gems. Colors are (R, B, G, Y, W, N)
	5) Player 1 pieces
	6) Player 2 pieces
	7) Current rng_state
	8) P1 other special info
	9) P2 other special info
	Note: special items must belong to a player, even if they are "neutral".
Encoding:
	1) [char1]_[char2]_
		e.g. Heath_Walter_
	2) [p1 burst meter]_[p1 super]_[p1 damage]_
		e.g. 4_35_4_
	3) [p2 burst meter]_[p2 super]_[p2 damage]_
		e.g. 5_23_6_
	4) 64 byte string, 8x8, from top left across to bottom right. [color] or 0_
		e.g. 000000000000000000000000000000000000000000000000RRYBG000RYRBGGYB_
	5) P1 pieces from 1-5, [color][color]_
		e.g. RY_YY____
	6) P2 pieces from 1-5, [color][color]_
		e.g. RY_YY_GG___
	7) [rng_state]_
	6) [depends]_
		e.g. SPEC__ to denote location of Heath fires
	7) [depends]_
		e.g. SPEC__ to denote column/remaining turns of Walter clouds
--]]
function Game:serializeState()
	local p1, p2 = self.p1, self.p2

	local function getPieceString(pc) -- get string representation of piece
		local s
		if pc.size == 1 then
			s = pc.gems[1].color:sub(1, 1)
		elseif pc.size == 2 then
			-- If it is in rotation_index 2 or 3, the gem table was reversed
			-- This is because of bad coding from before. Haha
			if pc.rotation_index == 2 or pc.rotation_index == 3 then
				s = pc.gems[2].color:sub(1, 1) .. pc.gems[1].color:sub(1, 1)
			else
				s = pc.gems[1].color:sub(1, 1) .. pc.gems[2].color:sub(1, 1)
			end
		else
			error("Piece size is not 1 or 2")
		end
		return s:upper()
	end

	local function getGridString(loc) -- get string representation of grid
		return loc.gem and loc.gem.color:sub(1, 1):upper() or "z"
	end

	local p1char, p2char = p1.character_name, p2.character_name

	-- super, burst, damage
	local p1burst, p1super, p1damage = p1.cur_burst, p1.mp, p1.hand.damage
	local p2burst, p2super, p2damage = p2.cur_burst, p2.mp, p2.hand.damage

	-- grid gems
	local grid = self.grid
	local grid_str, idx = {}, 1
	for row = grid.BASIN_START_ROW, grid.BASIN_END_ROW do
		for col = 1, grid.COLUMNS do
			grid_str[idx] = getGridString(grid[row][col])
			idx = idx + 1
		end
	end
	grid_str = table.concat(grid_str)

	-- player hand pieces
	local p1hand, p2hand = {}, {}
	for i = 1, 5 do
		local p1str = p1.hand[i].piece and getPieceString(p1.hand[i].piece) or ""
		local p2str = p2.hand[i].piece and getPieceString(p2.hand[i].piece) or ""
		p1hand[i] = p1str .. "_"
		p2hand[i] = p2str .. "_"
	end
	p1hand, p2hand = table.concat(p1hand), table.concat(p2hand)

	-- rng state
	local rng_state = self.rng:getState()

	-- player passives
	local p1special, p2special = p1:serializeSpecials(), p2:serializeSpecials()

	return
		p1char .. "_" .. p2char .. "_" ..
		p1burst .. "_" .. p1super .. "_" .. p1damage .. "_" ..
		p2burst .. "_" .. p2super .. "_" .. p2damage .. "_" ..
		grid_str .. "_" ..
		p1hand ..
		p2hand ..
		rng_state .. "_" ..
		p1special .. "_" ..
		p2special .. "_"
end

--[[ replaces the current state with the provided state
	index to data:
	1: p1 character, string
	2: p2 character, string
	3: p1 burst, integer
	4: p1 super, integer
	5: p1 damage, integer
	6: p2 burst, integer
	7: p2 super, integer
	8: p2 damage, integer
	9: grid, 64-length string
	10-14: p1 pieces, [color][color][ID#] string
	15-19: p2 pieces, [color][color][ID#] string
	20: rng state, string
	21: p1 specials, serialized string
	22: p2 specials, serialized string
--]]
function Game:deserializeState(state_string)
	print("applying state " .. state_string)
	local state = {}
	for s in (state_string.."_"):gmatch("(.-)_") do table.insert(state, s) end
	assert(#state == 23, "Malformed state string " .. #state)

	local p1char, p2char = state[1], state[2]
	local p1burst = tonumber(state[3])
	local p1super = tonumber(state[4])
	local p1damage = tonumber(state[5])
	local p2burst = tonumber(state[6])
	local p2super = tonumber(state[7])
	local p2damage = tonumber(state[8])
	local grid_str = state[9]
	local p1_hand = {state[10], state[11], state[12], state[13], state[14]}
	local p2_hand = {state[15], state[16], state[17], state[18], state[19]}
	local rng_state = state[20]
	local p1_special_str, p2_special_str = state[21], state[22]

	-- if p1.character_name or p2.character_name not match, replace them
	if p1char ~= self.p1.character_name then
		print("p1char, id", p1char, self.p1.character_name)
		self.p1 = common.instance(require("characters." .. p1char), 1, self)
	end
	if p2char ~= self.p2.character_name then
		print("p2char, id", p2char, self.p2.character_name)
		self.p2 = common.instance(require("characters." .. p2char), 2, self)
	end
	self.p1.enemy = self.p2
	self.p2.enemy = self.p1
	local p1, p2 = self.p1, self.p2
	self.me_player, self.them_player = self.p1, self.p2

	-- overwrite burst, super, damage for both players
	p1.cur_burst = p1burst
	p1.mp = p1super
	p1.hand.damage = p1damage
	p2.cur_burst = p2burst
	p2.mp = p2super
	p2.hand.damage = p2damage

	local color_table = {
		R = "red",
		B = "blue",
		G = "green",
		Y = "yellow",
		W = "wild",
		N = "none",
		z = "empty",
	}
	-- overwrite grid
	local function writeGridString(row, col, color)
		local loc = self.grid[row][col]
		loc.gem = false

		assert(color_table[color], "Invalid color " .. color .. " provided!")
		if color == "R" or color == "B" or color == "G" or color == "Y" then
			loc.gem = Gem:create{
				game = self,
				x = self.grid.x[col],
				y = self.grid.y[row],
				color = color_table[color],
			}
		elseif color == "W" or color == "N" then
			loc.gem = Gem:create{
				game = self,
				x = self.grid.x[col],
				y = self.grid.y[row],
				color = color_table[color],
				exploding_gem_image = images.dummy,
				grey_exploding_gem_image = images.dummy,
				pop_particle_image = images.dummy,
			}
		end
	end

	local grid = self.grid
	for i = 1, #grid_str do
		local color = grid_str:sub(i, i)
		local row = math.ceil(i / grid.COLUMNS) + grid.PENDING_END_ROW
		local col = (i - 1) % grid.COLUMNS + 1
		writeGridString(row, col, color)
	end

	-- delete current hands, overwrite with new hands
	for i = 1, 5 do
		p1.hand[i].piece = nil
		if #p1_hand[i] == 1 or #p1_hand[i] == 2 then
			local gem_replace_table = {}
			for gem_idx = 1, #p1_hand[i] do
				local color_abbrev = p1_hand[i]:sub(gem_idx, gem_idx)
				local color = color_table[color_abbrev]

				if color == "red"
				or color == "blue"
				or color == "green"
				or color == "yellow" then
					gem_replace_table[gem_idx] = {color = color}
				elseif color == "wild" or color == "none" then
					gem_replace_table[gem_idx] = {
						color = color,
						image = images.dummy,
						exploding_gem_image = images.dummy,
						grey_exploding_gem_image = images.dummy,
						pop_particle_image = images.dummy,
					}
				end
			end

			p1.hand[i].piece = Piece:create{
				game = self,
				hand_idx = i,
				owner = p1,
				player_num = p1.player_num,
				x = p1.hand[i].x,
				y = p1.hand[i].y,
				gem_replace_table = gem_replace_table,
			}
		end
	end

	for i = 1, 5 do
		p2.hand[i].piece = nil
		if #p2_hand[i] == 1 or #p2_hand[i] == 2 then
			local gem_replace_table = {}
			for gem_idx = 1, #p2_hand[i] do
				local color_abbrev = p2_hand[i]:sub(gem_idx, gem_idx)
				local color = color_table[color_abbrev]

				if color == "red"
				or color == "blue"
				or color == "green"
				or color == "yellow" then
					gem_replace_table[gem_idx] = {color = color}
				elseif color == "wild" or color == "none" then
					gem_replace_table[gem_idx] = {
						color = color,
						image = images.dummy,
						exploding_gem_image = images.dummy,
						grey_exploding_gem_image = images.dummy,
						pop_particle_image = images.dummy,
					}
				end
			end

			p2.hand[i].piece = Piece:create{
				game = self,
				hand_idx = i,
				owner = p2,
				player_num = p2.player_num,
				x = p2.hand[i].x,
				y = p2.hand[i].y,
				gem_replace_table = gem_replace_table,
			}
		end
	end
	grid:updateGrid()

	-- replace rng state
	self.rng:setState(rng_state)

	-- run p1special, p2special deserialization functions
	p1:deserializeSpecials(p1_special_str)
	p2:deserializeSpecials(p2_special_str)
end

-------------------------------------------------------------------------------


--[[ create a clickable object
	mandatory parameters: name, image, image_pushed, end_x, end_y, action
	optional parameters: duration, start_transparency, end_transparency,
		start_x, start_y, easing, exit, pushed, pushed_sfx, released,
		released_sfx, force_max_alpha
--]]
function Game:_createButton(gamestate, params)
	params = params or {}
	if params.name == nil then print("No object name received!") end
	if params.image_pushed == nil then
		print("Caution: no push image received for " .. params.name .. "!")
	end

	local button = Pic:create{
		game = self,
		name = params.name,
		x = params.start_x or params.end_x,
		y = params.start_y or params.end_y,
		transparency = params.start_transparency or 1,
		image = params.image,
		container = params.container or gamestate.ui.clickable,
		force_max_alpha = params.force_max_alpha,
	}

	button:change{
		duration = params.duration,
		x = params.end_x,
		y = params.end_y,
		transparency = params.end_transparency or 1,
		easing = params.easing or "linear",
		exit_func = params.exit_func,
	}
	button.pushed = params.pushed or function(_self)
		_self.game.sound:newSFX(params.pushed_sfx or "button")
		_self:newImage(params.image_pushed)
	end
	button.released = params.released or function(_self)
		if params.released_sfx then
			_self.game.sound:newSFX(params.released_sfx)
		end
		_self:newImage(params.image)
	end
	button.action = params.action
	return button
end

--[[ creates an object that can be tweened but not clicked
	mandatory parameters: name, image, end_x, end_y
	optional parameters: duration, start_transparency, end_transparency,
		start_x, start_y, easing, remove, exit_func, force_max_alpha,
		start_scaling, end_scaling, container, counter, h_flip
--]]
function Game:_createImage(gamestate, params)
	params = params or {}
	if params.name == nil then print("No object name received!") end

	local button = Pic:create{
		game = self,
		name = params.name,
		x = params.start_x or params.end_x,
		y = params.start_y or params.end_y,
		transparency = params.start_transparency or 1,
		scaling = params.start_scaling or 1,
		image = params.image,
		counter = params.counter,
		container = params.container or gamestate.ui.static,
		force_max_alpha = params.force_max_alpha,
		h_flip = params.h_flip,
	}

	button:change{
		duration = params.duration,
		x = params.end_x,
		y = params.end_y,
		transparency = params.end_transparency or 1,
		scaling = params.end_scaling or 1,
		easing = params.easing,
		remove = params.remove,
		exit_func = params.exit_func,
	}
	return button
end

-- creates the pop-up settings menu overlays
function Game:_openSettingsMenu(gamestate)
	local stage = self.stage
	local clickable = gamestate.ui.popup_clickable
	local static = gamestate.ui.popup_static
	self.settings_menu_open = true
	self:darkenScreen()
	static.settings_text:change{
		duration = 15,
		transparency = 1,
	}
	static.settingsframe:change{
		duration = 15,
		transparency = 1,
	}
	clickable.open_quit_menu:change{
		duration = 0,
		x = stage.settings_locations.quit_button.x,
	}
	clickable.open_quit_menu:change{
		duration = 15,
		transparency = 1
	}
	clickable.close_settings_menu:change{
		duration = 0,
		x = stage.settings_locations.close_menu_button.x,
	}
	clickable.close_settings_menu:change{
		duration = 15,
		transparency = 1,
	}
end

-- change to the quitconfirm menu
function Game:_openQuitConfirmMenu(gamestate)
	local stage = self.stage
	local clickable = gamestate.ui.popup_clickable
	local static = gamestate.ui.popup_static
	self.settings_menu_open = true
	self:darkenScreen()

	clickable.confirm_quit:change{
		duration = 0,
		x = stage.settings_locations.confirm_quit_button.x,
	}
	clickable.confirm_quit:change{
		duration = 15,
		transparency = 1,
	}
	clickable.close_quit_menu:change{
		duration = 0,
		x = stage.settings_locations.cancel_quit_button.x,
	}
	clickable.close_quit_menu:change{
		duration = 15,
		transparency = 1,
	}
	static.settings_text:change{
		duration = 10,
		transparency = 0,
	}
	static.sure_to_quit:change{
		duration = 15,
		transparency = 1,
	}
	clickable.open_quit_menu:change{
		duration = 0,
		x = -stage.width,
		transparency = 0,
	}
	clickable.close_settings_menu:change{
		duration = 0,
		x = -stage.width,
		transparency = 0,
	}
end

-- change back to the settings menu
function Game:_closeQuitConfirmMenu(gamestate)
	local stage = self.stage
	local clickable = gamestate.ui.popup_clickable
	local static = gamestate.ui.popup_static
	self.settings_menu_open = true
	self:darkenScreen()

	clickable.confirm_quit:change{
		duration = 0,
		x = -stage.width,
		transparency = 0,
	}
	clickable.close_quit_menu:change{
		duration = 0,
		x = -stage.width,
		transparency = 0,
	}
	static.settings_text:change{
		duration = 15,
		transparency = 1,
	}
	static.sure_to_quit:change{
		duration = 10,
		transparency = 0,
	}
	clickable.open_quit_menu:change{
		duration = 0,
		x = stage.settings_locations.quit_button.x,
	}
	clickable.open_quit_menu:change{
		duration = 15,
		transparency = 1,
	}
	clickable.close_settings_menu:change{
		duration = 0,
		x = stage.settings_locations.close_menu_button.x,
	}
	clickable.close_settings_menu:change{
		duration = 15,
		transparency = 1,
	}
end

function Game:_closeSettingsMenu(gamestate)
	local stage = self.stage
	local clickable = gamestate.ui.popup_clickable
	local static = gamestate.ui.popup_static
	self.settings_menu_open = false
	self:brightenScreen()

	clickable.confirm_quit:change{
		duration = 0,
		x = -stage.width,
		transparency = 0,
	}
	clickable.close_quit_menu:change{
		duration = 0,
		x = -stage.width,
		transparency = 0,
	}
	static.settings_text:change{
		duration = 10,
		transparency = 0,
	}
	static.sure_to_quit:change{
		duration = 10,
		transparency = 0,
	}
	static.settingsframe:change{
		duration = 10,
		transparency = 0,
	}
	clickable.open_quit_menu:change{
		duration = 0,
		x = -stage.width,
		transparency = 0,
	}
	clickable.close_settings_menu:change{
		duration = 0,
		x = -stage.width,
		transparency = 0,
	}
end

--[[	optional arguments:
	settings_icon: image for the settings icon (defaults to images.buttons_settings)
	settings_iconpush: image for the pushed settings icon (defaults to images.buttons_settingspush)
	settings_text: image for the text display (defaults to images.unclickables_pausetext)
	exitstate: state to exit upon confirm (e.g. "gs_title", "gs_gamestate", "gs_main", "gs_multiplayerselect")
		Defaults to quitting the game if not provided
--]]
function Game:_createSettingsMenu(gamestate, params)
	params = params or {}
	local stage = self.stage
	local settings_icon = params.settings_icon or images.buttons_settings
	local settings_pushed_icon = params.settings_iconpush or images.buttons_settingspush
	local settings_text = params.settings_text or images.unclickables_pausetext

	self:_createButton(gamestate, {
		name = "settings",
		image = settings_icon,
		image_pushed = settings_pushed_icon,
		end_x = params.x or stage.settings_button[gamestate.name].x,
		end_y = params.y or stage.settings_button[gamestate.name].y,
		action = function()
			if not self.settings_menu_open then
				gamestate.openSettingsMenu(self)
			end
		end,
	})
	self:_createImage(gamestate, {
		name = "settings_text",
		container = gamestate.ui.popup_static,
		image = settings_text,
		end_x = stage.settings_locations.pause_text.x,
		end_y = stage.settings_locations.pause_text.y,
		end_transparency = 0,
		force_max_alpha = true,
	})
	self:_createButton(gamestate, {
		name = "open_quit_menu",
		container = gamestate.ui.popup_clickable,
		image = images.buttons_quit,
		image_pushed = images.buttons_quitpush,
		end_x = stage.settings_locations.quit_button.x,
		end_y = stage.settings_locations.quit_button.y,
		action = function()
			if self.settings_menu_open then
				self:_openQuitConfirmMenu(gamestate)
			end
		end,
		force_max_alpha = true,
	})
	self:_createButton(gamestate, {
		name = "close_settings_menu",
		container = gamestate.ui.popup_clickable,
		image = images.buttons_back,
		image_pushed = images.buttons_backpush,
		end_x = stage.settings_locations.close_menu_button.x,
		end_y = stage.settings_locations.close_menu_button.y,
		pushed_sfx = "buttonback",
		action = function()
			if self.settings_menu_open then
				gamestate.closeSettingsMenu(self)
			end
		end,
		force_max_alpha = true,
	})
	self:_createImage(gamestate, {
		name = "sure_to_quit",
		container = gamestate.ui.popup_static,
		image = images.unclickables_suretoquit,
		end_x = stage.settings_locations.confirm_quit_text.x,
		end_y = stage.settings_locations.confirm_quit_text.y,
		end_transparency = 0,
		force_max_alpha = true,
	})
	self:_createImage(gamestate, {
		name = "settingsframe",
		container = gamestate.ui.popup_static,
		image = images.unclickables_settingsframe,
		end_x = stage.settings_locations.frame.x,
		end_y = stage.settings_locations.frame.y,
		end_transparency = 0,
		force_max_alpha = true,
	})
	self:_createButton(gamestate, {
		name = "close_quit_menu",
		container = gamestate.ui.popup_clickable,
		image = images.buttons_no,
		image_pushed = images.buttons_nopush,
		end_x = stage.settings_locations.cancel_quit_button.x,
		end_y = stage.settings_locations.cancel_quit_button.y,
		end_transparency = 0,
		pushed_sfx = "buttonback",
		action = function()
			if self.settings_menu_open then
				self:_closeQuitConfirmMenu(gamestate)
			end
		end,
		force_max_alpha = true,
	})
	self:_createButton(gamestate, {
		name = "confirm_quit",
		container = gamestate.ui.popup_clickable,
		image = images.buttons_yes,
		image_pushed = images.buttons_yespush,
		end_x = stage.settings_locations.confirm_quit_button.x,
		end_y = stage.settings_locations.confirm_quit_button.y,
		pushed_sfx = "buttonback",
		end_transparency = 0,
		action = function()
			if self.settings_menu_open then
				if params.exitstate then
					self:_closeQuitConfirmMenu(gamestate)
					self.settings_menu_open = false
					self:brightenScreen()
					self:switchState(params.exitstate)
				else
					love.event.quit()
				end
			end
		end,
		force_max_alpha = true,
	})
end

function Game:_drawSettingsMenu(gamestate)
	if self.settings_menu_open then
		gamestate.ui.popup_static.settingsframe:draw()
		gamestate.ui.popup_static.settings_text:draw()
		gamestate.ui.popup_static.sure_to_quit:draw()
		for _, v in pairs(gamestate.ui.popup_clickable) do v:draw() end
	end
end

local pointIsInRect = require "/helpers/utilities".pointIsInRect

-- draw the globals
function Game:_drawGlobals()
	for _, v in pairs(self.global_ui.fx) do v:draw() end
	for _, v in pairs(self.global_ui.fades) do v:draw() end
end

--default mousepressed function if not specified by a sub-state
function Game:_mousepressed(x, y, gamestate)
	self.uielements.screenPress.create(self, gamestate, x, y)

	if self.settings_menu_open then
		for _, button in pairs(gamestate.ui.popup_clickable) do
			if pointIsInRect(x, y, button:getRect()) then
				gamestate.clicked = button
				button:pushed()
				return
			end
		end
	else
		for _, button in pairs(gamestate.ui.clickable) do
			if pointIsInRect(x, y, button:getRect()) then
				gamestate.clicked = button
				button:pushed()
				return
			end
		end
	end
	gamestate.clicked = false
end

-- default mousereleased function if not specified by a sub-state
function Game:_mousereleased(x, y, gamestate)
	if self.settings_menu_open then
		for _, button in pairs(gamestate.ui.popup_clickable) do
			if gamestate.clicked == button then button:released() end
			if pointIsInRect(x, y, button:getRect())
			and gamestate.clicked == button then
				button.action()
				break
			end
		end
	else
		for _, button in pairs(gamestate.ui.clickable) do
			if gamestate.clicked == button then button:released() end
			if pointIsInRect(x, y, button:getRect())
			and gamestate.clicked == button then
				button.action()
				break
			end
		end
	end
	gamestate.clicked = false
end

-- default mousemoved function if not specified by a sub-state
function Game:_mousemoved(x, y, gamestate)
	if gamestate.clicked then
		if not pointIsInRect(x, y, gamestate.clicked:getRect()) then
			gamestate.clicked:released()
			gamestate.clicked = false
		end
	end
end

-- checks if mouse is down (for ui). Can use different function for touchscreen
function Game:_ismousedown()
	return love.mouse.isDown(1)
end

-- get current mouse position
function Game:_getmouseposition()
	local drawspace = self.inits.drawspace
	local x, y = drawspace.tlfres.getMousePosition(drawspace.width, drawspace.height)
	return x, y
end

function Game:keypressed(key)
	if key == "escape" then
		love.event.quit()
	else
		if self.unittests[key] then
			self.unittests[key](self)
		end
	end
end

return common.class("Game", Game)
