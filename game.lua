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
Game.VERSION = "65.0"

function Game:init()
	self.debug_drawGemOwners = true	-- TODO: Remove this someday.
	self.debug_drawParticleDestinations = true
	self.debug_drawGamestate = true
	self.debug_drawDamage = true
	self.debug_drawGrid = true
	self.debug_drawTurnNumber = true
	self.debug_overlay = function()
		if self.current_phase == "Pause" then
			return "Pausing at " .. self.phase.current_phase_for_debug_purposes_only .. ", " ..
				self.phase.frames_until_next_phase .. "\nGarbage this round: " .. self.phase.garbage_this_round
		else
			return self.current_phase
		end
	end
	self.debug_screencaps = true
	self.debug_pause_mode = false

	self.rng = love.math.newRandomGenerator()
	self.unittests = common.instance(require "unittests", self) -- debug testing
	self.phase = common.instance(require "phase", self)
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
	self.debugconsole = common.instance(require "debugconsole", self)
	self.debugconsole:setDefaultDisplayParams()
	self:reset()
end

function Game:start(gametype, char1, char2, bkground, seed, side)
	ID:reset()
	self:reset()
	self.sound:reset()
	self.grid:reset()
	self.particles:reset()
	self.phase:reset()
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

local finished_loading = false
function Game:update(dt)
	if not finished_loading then
		finished_loading = image:updateLoader(dt)
		if finished_loading then print("loaded " .. finished_loading .. " images!") end
	end
	self.client:update(dt)
	self.sound:update()
	self:updateDarkenedScreenTracker(dt) -- haha
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
	self.inputs_frozen = false
	self.phase.time_to_next = self.phase.INIT_TIME_TO_NEXT
end

function Game:reset()
	self.current_phase = "Intro"
	self.turn = 1
	self.phase.time_to_next = self.phase.INIT_TIME_TO_NEXT
	self.netplay_wait = 0
	self.inputs_frozen = false
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
	self.screen_dark = {false, false, false}
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

--[[ create a clickable object
	mandatory parameters: name, image, image_pushed, end_x, end_y, action
	optional parameters: duration, start_transparency, end_transparency,
		start_x, start_y, easing, exit, pushed, pushed_sfx, released,
		released_sfx, force_max_alpha
--]]

function Game:_createButton(gamestate, params)
	params = params or {}
	if params.name == nil then print("No object name received!") end
	if params.image_pushed == nil then print("No push image received for " .. params.name .. "!") end

	local button = Pic:create{
		game = self,
		name = params.name,
		x = params.start_x or params.end_x,
		y = params.start_y or params.end_y,
		transparency = params.start_transparency or 255,
		image = params.image,
		container = params.container or gamestate.ui.clickable,
		force_max_alpha = params.force_max_alpha,
	}

	button:change{duration = params.duration, x = params.end_x, y = params.end_y,
		transparency = params.end_transparency or 255,
		easing = params.easing or "linear", exit_func = params.exit_func}
	button.pushed = params.pushed or function(_self)
		_self.game.sound:newSFX(params.pushed_sfx or "button")
		_self:newImage(params.image_pushed)
	end
	button.released = params.released or function(_self)
		if params.released_sfx then _self.game.sound:newSFX(params.released_sfx) end
		_self:newImage(params.image)
	end
	button.action = params.action
	return button
end

--[[ creates an object that can be tweened but not clicked
	mandatory parameters: name, image, end_x, end_y
	optional parameters: duration, start_transparency, end_transparency,
		start_x, start_y, easing, exit, force_max_alpha
--]]
function Game:_createImage(gamestate, params)
	params = params or {}
	if params.name == nil then print("No object name received!") end

	local button = Pic:create{
		game = self,
		name = params.name,
		x = params.start_x or params.end_x,
		y = params.start_y or params.end_y,
		transparency = params.start_transparency or 255,
		image = params.image,
		container = params.container or gamestate.ui.static,
		force_max_alpha = params.force_max_alpha,
	}

	button:change{duration = params.duration, x = params.end_x, y = params.end_y,
		transparency = params.end_transparency or 255, easing = params.easing, exit_func = params.exit_func}
	return button
end

-- creates the pop-up settings menu overlays
function Game:_openSettingsMenu(gamestate)
	local stage = self.stage
	local clickable = gamestate.ui.popup_clickable
	local static = gamestate.ui.popup_static
	self.settings_menu_open = true
	self:darkenScreen()
	static.settings_text:change{duration = 15, transparency = 255}
	static.settingsframe:change{duration = 15, transparency = 255}
	clickable.open_quit_menu:change{duration = 0, x = stage.settings_locations.quit_button.x}
	clickable.open_quit_menu:change{duration = 15, transparency = 255}
	clickable.close_settings_menu:change{duration = 0, x = stage.settings_locations.close_menu_button.x}
	clickable.close_settings_menu:change{duration = 15, transparency = 255}
end

-- change to the quitconfirm menu
function Game:_openQuitConfirmMenu(gamestate)
	local stage = self.stage
	local clickable = gamestate.ui.popup_clickable
	local static = gamestate.ui.popup_static
	self.settings_menu_open = true
	self:darkenScreen()

	clickable.confirm_quit:change{duration = 0, x = stage.settings_locations.confirm_quit_button.x}
	clickable.confirm_quit:change{duration = 15, transparency = 255}
	clickable.close_quit_menu:change{duration = 0, x = stage.settings_locations.cancel_quit_button.x}
	clickable.close_quit_menu:change{duration = 15, transparency = 255}
	static.settings_text:change{duration = 10, transparency = 0}
	static.sure_to_quit:change{duration = 15, transparency = 255}
	clickable.open_quit_menu:change{duration = 0, x = -stage.width, transparency = 0}
	clickable.close_settings_menu:change{duration = 0, x = -stage.width, transparency = 0}
end

-- change back to the settings menu
function Game:_closeQuitConfirmMenu(gamestate)
	local stage = self.stage
	local clickable = gamestate.ui.popup_clickable
	local static = gamestate.ui.popup_static
	self.settings_menu_open = true
	self:darkenScreen()

	clickable.confirm_quit:change{duration = 0, x = -stage.width, transparency = 0}
	clickable.close_quit_menu:change{duration = 0, x = -stage.width, transparency = 0}
	static.settings_text:change{duration = 15, transparency = 255}
	static.sure_to_quit:change{duration = 10, transparency = 0}
	clickable.open_quit_menu:change{duration = 0, x = stage.settings_locations.quit_button.x}
	clickable.open_quit_menu:change{duration = 15, transparency = 255}
	clickable.close_settings_menu:change{duration = 0, x = stage.settings_locations.close_menu_button.x}
	clickable.close_settings_menu:change{duration = 15, transparency = 255}
end

function Game:_closeSettingsMenu(gamestate)
	local stage = self.stage
	local clickable = gamestate.ui.popup_clickable
	local static = gamestate.ui.popup_static
	self.settings_menu_open = false
	self:brightenScreen()

	clickable.confirm_quit:change{duration = 0, x = -stage.width, transparency = 0}
	clickable.close_quit_menu:change{duration = 0, x = -stage.width, transparency = 0}
	static.settings_text:change{duration = 10, transparency = 0}
	static.sure_to_quit:change{duration = 10, transparency = 0}
	static.settingsframe:change{duration = 10, transparency = 0}
	clickable.open_quit_menu:change{duration = 0, x = -stage.width, transparency = 0}
	clickable.close_settings_menu:change{duration = 0, x = -stage.width, transparency = 0}
end

--[[	optional arguments:
	settings_icon: image for the settings icon (defaults to image.buttons_settings)
	settings_iconpush: image for the pushed settings icon (defaults to image.buttons_settingspush)
	settings_text: image for the text display (defaults to image.unclickables_pausetext)
	exitstate: state to exit upon confirm (e.g. "gs_title", "gs_gamestate", "gs_main", "gs_lobby")
		Defaults to quitting the game if not provided
--]]
function Game:_createSettingsMenu(gamestate, params)
	params = params or {}
	local stage = self.stage
	local settings_icon = params.settings_icon or image.buttons_settings
	local settings_pushed_icon = params.settings_iconpush or image.buttons_settingspush
	local settings_text = params.settings_text or image.unclickables_pausetext

	self:_createButton(gamestate, {
		name = "settings",
		image = settings_icon,
		image_pushed = settings_pushed_icon,
		end_x = params.x or stage.settings_button[gamestate.name].x,
		end_y = params.y or stage.settings_button[gamestate.name].y,
		action = function()
			if not self.settings_menu_open then gamestate.openSettingsMenu(self) end
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
		image = image.buttons_quit,
		image_pushed = image.buttons_quitpush,
		end_x = stage.settings_locations.quit_button.x,
		end_y = stage.settings_locations.quit_button.y,
		action = function()
			if self.settings_menu_open then self:_openQuitConfirmMenu(gamestate) end
		end,
		force_max_alpha = true,
	})
	self:_createButton(gamestate, {
		name = "close_settings_menu",
		container = gamestate.ui.popup_clickable,
		image = image.buttons_back,
		image_pushed = image.buttons_backpush,
		end_x = stage.settings_locations.close_menu_button.x,
		end_y = stage.settings_locations.close_menu_button.y,
		pushed_sfx = "buttonback",
		action = function()
			if self.settings_menu_open then gamestate.closeSettingsMenu(self) end
		end,
		force_max_alpha = true,
	})
	self:_createImage(gamestate, {
		name = "sure_to_quit",
		container = gamestate.ui.popup_static,
		image = image.unclickables_suretoquit,
		end_x = stage.settings_locations.confirm_quit_text.x,
		end_y = stage.settings_locations.confirm_quit_text.y,
		end_transparency = 0,
		force_max_alpha = true,
	})
	self:_createImage(gamestate, {
		name = "settingsframe",
		container = gamestate.ui.popup_static,
		image = image.unclickables_settingsframe,
		end_x = stage.settings_locations.frame.x,
		end_y = stage.settings_locations.frame.y,
		end_transparency = 0,
		force_max_alpha = true,
	})
	self:_createButton(gamestate, {
		name = "close_quit_menu",
		container = gamestate.ui.popup_clickable,
		image = image.buttons_no,
		image_pushed = image.buttons_nopush,
		end_x = stage.settings_locations.cancel_quit_button.x,
		end_y = stage.settings_locations.cancel_quit_button.y,
		end_transparency = 0,
		pushed_sfx = "buttonback",
		action = function()
			if self.settings_menu_open then self:_closeQuitConfirmMenu(gamestate) end
		end,
		force_max_alpha = true,
	})
	self:_createButton(gamestate, {
		name = "confirm_quit",
		container = gamestate.ui.popup_clickable,
		image = image.buttons_yes,
		image_pushed = image.buttons_yespush,
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
					self.statemanager:switch(require (params.exitstate))
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

local pointIsInRect = require "utilities".pointIsInRect

--default mousepressed function if not specified by a sub-state
function Game:_mousepressed(x, y, gamestate)
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
			if pointIsInRect(x, y, button:getRect()) and gamestate.clicked == button then
				button.action()
				break
			end
		end
	else
		for _, button in pairs(gamestate.ui.clickable) do
			if gamestate.clicked == button then button:released() end
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
			gamestate.clicked:released()
			gamestate.clicked = false
		end
	end
end

function Game:keypressed(key)
	if key == "escape" then
		love.event.quit()
	elseif key == "f3" then	-- Toggle debug mode (see lovedebug.lua). Key chosen from Minecraft.
		_G.debugEnabled = not _G.debugEnabled
	else
		if self.unittests[key] then
			self.unittests[key](self)
		end
	end
end

return common.class("Game", Game)
