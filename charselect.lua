--[[
This is the character select as a class, so it can be instantiated by either
singleplayer or netplay gamestates.
--]]

local common = require "class.commons"
local images = require "images"
local Pic = require "pic"
local spairs = require "/helpers/utilities".spairs
local Spellbook = require "spellbook"
local Lobby = require "lobby"

local Charselect = {}

function Charselect:init(game, gamestate)
	assert(gamestate.name == "Singleplayer" or gamestate.name == "Multiplayer",
		"Invalid gamestate name '" .. gamestate.name .. "' provided!")
	self.game = game
	self.gamestate = gamestate
	self.selectable_chars = {"heath", "walter", "fuka", "holly",
		"wolfgang", "hailey", "diggory", "ivy", "joy", "mort", "buzz", "damon"}
	self.gamestate.ui = {
		clickable = {},
		static = {},
		popup_clickable = {},
		popup_static = {},
	}

	if gamestate.name == "Multiplayer" then
		self.lobby = common.instance(Lobby, game, self)
	end

	self.spellbook = common.instance(Spellbook, self)
end

-- refer to game.lua for instructions for _createButton and _createImage
function Charselect:_createButton(params)
	return self.game:_createButton(self.gamestate, params)
end

function Charselect:_createImage(params)
	return self.game:_createImage(self.gamestate, params)
end

-- creates the clickable buttons for selecting characters
function Charselect:_createCharacterButtons()
	local game = self.game
	local gamestate = self.gamestate
	local stage = game.stage
	self.clicked = nil
	local end_x, end_y
	for i = 1, #self.selectable_chars do
		local char = self.selectable_chars[i]
		if i >= 1 and i < 5 then
			end_x = stage.width * (0.1 * i + 0.525)
			end_y = stage.height * 0.175
		elseif i >= 5 and i < 9 then
			end_x = stage.width * (0.1 * i + 0.0725)
			end_y = stage.height * 0.35
		elseif i >= 9 and i < 13 then
			end_x = stage.width * (0.1 * i - 0.275)
			end_y = stage.height * 0.525
		end
		self:_createButton{
			name = char,
			image = images["charselect_ring_"..char],
			image_pushed = images["charselect_ring_"..char],
			duration = 30,
			start_x = -0.05 * i,
			end_x = end_x,
			start_y = 0.1 * i,
			end_y = end_y,
			start_transparency = 0.75,
			easing = "inOutSine",
			pushed_sfx = "buttoncharacter",
			action = function()
				if self.my_character ~= char and not self.spellbook.char_displayed then
					self.my_character = char
					self.displayed_character_shadow:newImage(images["portraits_shadow_"..char])
					self.displayed_character:newImage(images["portraits_action_"..char])
					self.displayed_character_text:newImage(images["charselect_name_"..char])
					self.displayed_character_shadow:reset()
					self.displayed_character:reset()
					self.displayed_character_text:reset()
				end
			end,
		}
	end

	-- Temporary thing for demo version
	for name, data in pairs(gamestate.ui.clickable) do
		if name ~= "heath"
		and name ~= "walter"
		and name ~= "wolfgang"
		and name ~= "diggory"
		and name ~= "holly"
		and name ~= "fuka" then
			data.action = function() end
			data.RGB = {0.35, 0.35, 0.35}
		end
	end
end

-- creates the clickable UI objects
function Charselect:_createUIButtons()
	local game = self.game
	local gamestate = self.gamestate
	local stage = game.stage

	local start_action
	if gamestate.name == "Singleplayer" then
		start_action = function()
			if self.my_character and not self.spellbook.char_displayed then
				game:start{
					gametype = gamestate.gametype,
					char1 = self.my_character,
					char2 = self.opponent_character,
					playername1 = game.settings.player.name,
					playername2 = "Sucky AI",
					background = game.background:idx_to_str(self.game_background),
					side = 1,
				}
				self.my_character = nil
			end
		end
	elseif gamestate.name == "Multiplayer" then
		start_action = function()
			if 	self.my_character and
				not game.client.queuing and
				not self.spellbook.char_displayed
			then
				local queue_details = {
					character = self.my_character,
					background = game.background:idx_to_str(self.game_background),
				}
				self.lobby:joinRankedQueue(queue_details)
				gamestate.ui.clickable.start:newImage(images.buttons_lobbycancelsearch)
			elseif self.my_character and game.client.queuing then
				self.lobby:cancelRankedQueue()
				gamestate.ui.clickable.start:newImage(images.buttons_start)
				-- TODO: we should probably have a separate button object here
			end
		end
	end

	-- start button
	self:_createButton{
		name = "start",
		image = images.buttons_start,
		image_pushed = images.buttons_startpush,
		duration = 15,
		end_x = stage.width * 0.15,
		start_y = stage.height + images.buttons_start:getHeight(),
		end_y = stage.height * 0.9,
		easing = "outQuad",
		action = start_action,
	}

	-- spellbook button
	self:_createButton{
		name = "spellbook",
		image = images.buttons_spellbook,
		image_pushed = images.buttons_spellbookpush,
		duration = 15,
		end_x = stage.width * 0.155 + images.buttons_spellbook:getWidth(),
		start_y = stage.height + images.buttons_start:getHeight(),
		end_y = stage.height * 0.9,
		easing = "outQuad",
		action = function()
			if self.my_character and not self.spellbook.char_displayed then
				self.spellbook:displayCharacter(self.my_character)
			end
		end,
	}
	local back_action
	if gamestate.name == "Singleplayer" then
		back_action = function()
			game:switchState("gs_title")
			if self.spellbook.char_displayed then
				self.spellbook:hideCharacter()
			end
		end
	elseif gamestate.name == "Multiplayer" then
		back_action = function()
			self.lobby:goBack()
			if self.spellbook.char_displayed then
				self.spellbook:hideCharacter()
			end
		end
	end

	-- back button
	self:_createButton{
		name = "back",
		image = images.buttons_back,
		image_pushed = images.buttons_backpush,
		duration = 15,
		end_x = stage.width * 0.05,
		end_y = stage.height * 0.09,
		pushed_sfx = "buttonback",
		action = back_action,
	}

	-- left arrow for background select
	self:_createButton{
		name = "backgroundleft",
		image = images.buttons_backgroundleft,
		image_pushed = images.buttons_backgroundleft,
		duration = 60,
		end_x = stage.width * 0.6,
		end_y = stage.height * 0.8,
		transparency = 0.5,
		easing = "linear",
		action = function()
			self.game_background = (self.game_background - 2) % game.background.total + 1
			local selected_background = game.background:idx_to_str(self.game_background)
			local new_image = images["charselect_thumbnail_" .. selected_background]
			self.game_background_image:newImage(new_image)
		end,
	}

	-- right arrow for background select
	self:_createButton{
		name = "backgroundright",
		image = images.buttons_backgroundright,
		image_pushed = images.buttons_backgroundright,
		duration = 60,
		end_x = stage.width * 0.9,
		end_y = stage.height * 0.8,
		transparency = 0.5,
		easing = "linear",
		action = function()
			self.game_background = self.game_background % game.background.total + 1
			local selected_background = game.background:idx_to_str(self.game_background)
			local new_image = images["charselect_thumbnail_" .. selected_background]
			self.game_background_image:newImage(new_image)
		end,
	}
end

-- creates the unclickable UI display images
function Charselect:_createUIImages()
	local game = self.game
	local stage = game.stage

	-- large portrait shadow
	Pic:create{
		game = game,
		image = images.dummy,
		x = stage.width * 0.275,
		y = stage.height * 0.45,
		transparency = 0.25,
		container = self,
		name = "displayed_character_shadow",
	}

	self.displayed_character_shadow.reset = function(c)
		c:clear()
		c:change{
			duration = 0,
			x = stage.width * 0.275,
			transparency = 0.25,
		}
		c:change{
			duration = 24,
			x = stage.width * 0.325,
			transparency = 1,
			easing = "outQuart",
		}
	end
	self.displayed_character_shadow:reset()

	-- large portrait with dummy pic
	Pic:create{
		game = game,
		image = images.dummy,
		x = stage.width * 0.25,
		y = stage.height * 0.45,
		transparency = 0.25,
		container = self,
		name = "displayed_character",
	}

	self.displayed_character.reset = function(c)
		c:clear()
		c:change{
			duration = 0,
			x = stage.width * 0.25,
			transparency = 0.25,
		}
		c:change{
			duration = 18,
			x = stage.width * 0.3,
			transparency = 1,
			easing = "outQuart",
		}
	end
	self.displayed_character:reset()

	-- large text of character name
	Pic:create{
		game = game,
		image = images.dummy,
		x = stage.width * 0.272,
		y = stage.height * 0.7,
		transparency = 0.25,
		container = self,
		name = "displayed_character_text",
	}
	self.displayed_character_text.reset = function(c)
		c:change{
			duration = 0,
			y = stage.height * 0.7,
			transparency = 0.25,
		}
		c:change{
			duration = 6,
			y = stage.height * 0.65,
			transparency = 1,
			easing = "outQuart",
		}
	end
	self.displayed_character_text:reset()

	-- background_image_frame
	self:_createImage{
		name = "backgroundframe",
		image = images.unclickables_selectstageborder,
		duration = 60,
		end_x = stage.width * 0.75,
		end_y = stage.height * 0.8,
		transparency = 0.5,
		easing = "linear",
	}

	local selected_background = game.background:idx_to_str(self.game_background)
	-- background_image
	self.game_background_image = self:_createImage{
		name = "backgroundimage",
		image = images["charselect_thumbnail_" .. selected_background],
		duration = 60,
		end_x = stage.width * 0.75,
		end_y = stage.height * 0.8,
		transparency = 0.5,
		easing = "linear",
	}
end

function Charselect:enter()
	local game = self.game
	local stage = game.stage
	local gamestate = self.gamestate
	self.clicked = nil
	if game.sound:getCurrentBGM() ~= "bgm_menu" then
		game.sound:stopBGM()
		game.sound:newBGM("bgm_menu", true)
	end

	game.uielements:clearScreenUIColor()
	self.current_background = common.instance(game.background.checkmate, game)
	self.game_background = 1 -- what's chosen for the maingame background
	self:_createCharacterButtons()
	self:_createUIButtons()
	self:_createUIImages()
	self.my_character = nil -- selected character for gamestart

	local opp_chars = {"heath", "walter", "fuka", "holly", "wolfgang", "diggory"}
	math.randomseed(os.time())
	local rand = math.random(#opp_chars)
	self.opponent_character = opp_chars[rand]

	self:_createImage{
		name = "fadein",
		container = game.global_ui.fades,
		image = images.unclickables_fadein,
		duration = 30,
		end_x = stage.width * 0.5,
		end_y = stage.height * 0.5,
		end_transparency = 0,
		easing = "linear",
		remove = true,
	}

	if gamestate.name == "Multiplayer" then self.lobby:connect() end
end

function Charselect:openSettingsMenu()
	self.game:_openSettingsMenu(self.gamestate)
end

function Charselect:closeSettingsMenu()
	self.game:_closeSettingsMenu(self.gamestate)
end

function Charselect:update(dt)
	local gamestate = self.gamestate
	self.current_background:update(dt)
	for _, tbl in pairs(gamestate.ui) do
		for _, v in pairs(tbl) do v:update(dt) end
	end
	self.displayed_character_shadow:update(dt)
	self.displayed_character:update(dt)
	self.displayed_character_text:update(dt)
	self.spellbook:update(dt)
end

function Charselect:draw()
	local game = self.game
	local gamestate = self.gamestate

	local darkened = game:isScreenDark()
	self.current_background:draw{darkened = darkened}
	self.displayed_character_shadow:draw{darkened = darkened}
	self.displayed_character:draw{darkened = darkened}
	self.displayed_character_text:draw{darkened = darkened}
	for _, v in spairs(gamestate.ui.static) do v:draw{darkened = darkened} end
	for _, v in pairs(gamestate.ui.clickable) do v:draw{darkened = darkened} end

	self.spellbook:draw()

	game:_drawSettingsMenu(self.gamestate)

	if gamestate.name == "Multiplayer" then
		self.lobby:draw()
	end
	game:_drawGlobals()
end

function Charselect:mousepressed(x, y)
	local pointIsInRect = require "/helpers/utilities".pointIsInRect

	if self.spellbook.char_displayed then
		for _, button in pairs(self.spellbook.sub_images) do
			if pointIsInRect(x, y, button:getRect()) then
				self.gamestate.clicked = button
				button:pushed()
				return
			end
		end
	end

	self.game:_mousepressed(x, y, self.gamestate)
end

function Charselect:mousereleased(x, y)
	local pointIsInRect = require "/helpers/utilities".pointIsInRect

	if self.spellbook.char_displayed then
		for _, button in pairs(self.spellbook.sub_images) do
			if self.gamestate.clicked == button then button:released() end
			if pointIsInRect(x, y, button:getRect())
			and self.gamestate.clicked == button then
				button.action()
				return
			end
		end

		self.spellbook:hideCharacter()
		return
	end

	self.game:_mousereleased(x, y, self.gamestate)
end

function Charselect:mousemoved(x, y)
	self.game:_mousemoved(x, y, self.gamestate)
end

return common.class("Charselect", Charselect)
