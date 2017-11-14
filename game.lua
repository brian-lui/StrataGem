local Pic = require 'pic'
local love = _G.love
local common = require "classcommons"
local image = require 'image'

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
	if seed then self.rng:setSeed(seed)	end

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
	self.current_background_name = bkground
	self.statemanager:switch(require "gs_main")
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
	self.settings_menu_open = false
end

--[[ create a clickable object
	mandatory parameters: name, image, image_pushed, end_x, end_y, action
	optional parameters: duration, start_transparency, end_transparency,
		start_x, start_y, easing, exit, pushed, pushed_sfx, released, released_sfx
--]]
function Game:_createButton(gamestate, params)
	params = params or {}
	if params.name == nil then print("No object name received!") end
	if params.image_pushed == nil then print("No push image received for " .. params.name .. "!") end
	local stage = self.stage
	local button = common.instance(Pic, self, {
		name = params.name,
		x = params.start_x or params.end_x,
		y = params.start_y or params.end_y,
		transparency = params.start_transparency or 255,
		image = params.image,
		container = params.container or gamestate.ui.clickable,
	})
	button:change{duration = params.duration, x = params.end_x, y = params.end_y,
		transparency = params.end_transparency or 255,
		easing = params.easing or "linear", exit = params.exit}
	button.pushed = params.pushed or function()
		self.sound:newSFX(params.pushed_sfx or "sfx_button")
		button:newImage(params.image_pushed)
	end
	button.released = params.released or function()
		if released_sfx then self.sound:newSFX(params.released_sfx) end
		button:newImage(params.image)
	end
	button.action = params.action
	return button
end

--[[ creates an object that can be tweened but not clicked
	mandatory parameters: name, image, end_x, end_y
	optional parameters: duration, start_transparency, end_transparency, start_x, start_y, easing, exit
--]]
function Game:_createImage(gamestate, params)
	params = params or {}
	if params.name == nil then print("No object name received!") end
	local stage = self.stage
	local button = common.instance(Pic, self, {
		name = params.name,
		x = params.start_x or params.end_x,
		y = params.start_y or params.end_y,
		transparency = params.start_transparency or 255,
		image = params.image,
		container = params.container or gamestate.ui.static,
	})
	button:change{duration = params.duration, x = params.end_x, y = params.end_y,
		transparency = params.end_transparency or 255, easing = params.easing, exit = params.exit}
	return button
end

-- creates the pop-up settings menu overlays with default parameters
function Game:_openSettingsMenu(gamestate, params)
	local stage = self.stage
	self.settings_menu_open = true
	gamestate.ui.popup_clickable.confirm:change{x = stage.width * 0.45, y = stage.height * 0.6}
	gamestate.ui.popup_clickable.confirm:change{duration = 15, transparency = 255}
	gamestate.ui.popup_clickable.cancel:change{x = stage.width * 0.55, y = stage.height * 0.6}
	gamestate.ui.popup_clickable.cancel:change{duration = 15, transparency = 255}
	gamestate.ui.popup_static.settingstext:change{duration = 15, transparency = 255}
	gamestate.ui.popup_static.settingsframe:change{duration = 15, transparency = 255}
end

function Game:_closeSettingsMenu(gamestate, params)
	local stage = self.stage
	self.settings_menu_open = false
	gamestate.ui.popup_clickable.confirm:change{duration = 10, transparency = 0}
	gamestate.ui.popup_clickable.confirm:change{x = -stage.width, y = -stage.height}
	gamestate.ui.popup_clickable.cancel:change{duration = 10, transparency = 0}
	gamestate.ui.popup_clickable.cancel:change{x = -stage.width, y = -stage.height}
	gamestate.ui.popup_static.settingstext:change{duration = 10, transparency = 0}
	gamestate.ui.popup_static.settingsframe:change{duration = 10, transparency = 0}	
end

--[[	optional arguments:
	settings_icon: image for the settings icon (defaults to image.button.settings)
	settings_iconpush: image for the pushed settings icon (defaults to image.button.settingspush)
	settings_text: image for the text display (defaults to image.unclickable.settingstext)
	exitstate: state to exit upon confirm (e.g. "gs_title", "gs_gamestate", "gs_main", "gs_lobby")
		Defaults to quitting the game if not provided
--]]
function Game:_createSettingsMenu(gamestate, params)
	params = params or {}
	local stage = self.stage
	local settings_icon = params.settings_icon or image.button.settings
	local settings_pushed_icon = params.settings_iconpush or image.button.settingspush
	local settings_text = params.settings_text or image.unclickable.settingstext

	for k, v in pairs(stage.settings_button) do print(k, v) end
	self:_createButton(gamestate, {
		name = "settings",
		image = settings_icon,
		image_pushed = settings_pushed_icon,
		end_x = stage.settings_button[gamestate.name].x,
		end_y = stage.settings_button[gamestate.name].y,
		action = function()
			if not self.settings_menu_open then gamestate.openSettingsMenu(self) end
		end,
	})
	self:_createImage(gamestate, {
		name = "settingstext",
		container = gamestate.ui.popup_static,
		image = settings_text,
		end_x = stage.width * 0.5,
		end_y = stage.height * 0.4,
		end_transparency = 0,
	})
	self:_createImage(gamestate, {
		name = "settingsframe",
		container = gamestate.ui.popup_static,
		image = image.unclickable.settingsframe,
		end_x = stage.width * 0.5,
		end_y = stage.height * 0.5,
		end_transparency = 0,
	})
	self:_createButton(gamestate, {
		name = "cancel",
		container = gamestate.ui.popup_clickable,
		image = image.button.cancel,
		image_pushed = image.button.cancelpush,
		end_x = -stage.width,
		end_y = -stage.height,
		end_transparency = 0,
		action = function()
			if self.settings_menu_open then gamestate.closeSettingsMenu(self) end
		end,
	})
	self:_createButton(gamestate, {
		name = "confirm",
		container = gamestate.ui.popup_clickable,
		image = image.button.confirm,
		image_pushed = image.button.confirmpush,
		end_x = -stage.width,
		end_y = -stage.height,
		end_transparency = 0,
		action = function()
			if self.settings_menu_open then
				if params.exitstate then
					self.settings_menu_open = false
					self.statemanager:switch(require (params.exitstate))
				else
					love.event.quit()
				end
			end
		end,
	})
end

function Game:_drawSettingsMenu(gamestate, params)
	if self.settings_menu_open then
		params = params or {}
		gamestate.ui.popup_static.settingsframe:draw()
		gamestate.ui.popup_static.settingstext:draw()
		for _, v in pairs(gamestate.ui.popup_clickable) do v:draw() end
	end
end

local pointIsInRect = require "utilities".pointIsInRect

--default mousepressed function if not specified by a sub-state
function Game:_mousepressed(x, y, gamestate)
	if self.settings_menu_open then	
		for _, button in pairs(gamestate.ui.popup_clickable) do
			if pointIsInRect(x, y, button:getRect()) then
				gamestate.clicked = button
				button.pushed()
				return
			end
		end
	else
		for _, button in pairs(gamestate.ui.clickable) do
			if pointIsInRect(x, y, button:getRect()) then
				gamestate.clicked = button
				button.pushed()
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
			button.released()
			if pointIsInRect(x, y, button:getRect()) and gamestate.clicked == button then
				button.action()
				break
			end
		end
	else
		for _, button in pairs(gamestate.ui.clickable) do
			button.released()
			if pointIsInRect(x, y, button:getRect()) and gamestate.clicked == button then
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
			gamestate.clicked.released()
			gamestate.clicked = false
		end
	end
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
