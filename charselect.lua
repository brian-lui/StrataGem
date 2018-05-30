-- This is the character select as a class, so it can be instantiated by either
-- 1P or netplay 

local common = require "class.commons"
local image = require 'image'
local Pic = require 'pic'
local spairs = require "utilities".spairs

local Charselect = {}
function Charselect:init(game, gamestate)
	assert(gamestate.name == "SinglePlayer" or gamestate.name == "Netplay",
		"Invalid gamestate name '" .. gamestate.name .. "' provided!")
	self.game = game
	self.gamestate = gamestate
	self.selectable_chars = {"heath", "walter", "gail", "holly",
		"wolfgang", "hailey", "buzz", "ivy", "joy", "mort", "diggory", "damon"}
	self.gamestate.ui = {clickable = {}, static = {}, popup_clickable = {}, popup_static = {}}
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
			image = image["charselect_"..char.."ring"],
			image_pushed = image["charselect_"..char.."ring"],
			duration = 30,
			start_x = -0.05 * i,
			end_x = end_x,
			start_y = 0.1 * i,
			end_y = end_y,
			start_transparency = 195,
			easing = "inOutSine",
			pushed_sfx = "buttoncharacter",
			action = function()
				if self.my_character ~= char then
					self.my_character = char
					self.displayed_character_shadow:newImage(image["charselect_"..char.."shadow"])
					self.displayed_character:newImage(image["charselect_"..char.."char"])
					self.displayed_character_text:newImage(image["charselect_"..char.."name"])
					self.displayed_character_shadow:reset()
					self.displayed_character:reset()
					self.displayed_character_text:reset()
				end
			end,
		}
	end

	-- Temporary thing for demo version
	for name, data in pairs(gamestate.ui.clickable) do
		if name ~= "heath" and name ~= "walter" and name ~= "wolfgang" then
			data.action = function() end
			data.RGB = {96, 96, 96}
		end
	end
end

-- creates the clickable UI objects
function Charselect:_createUIButtons()
	local game = self.game
	local gamestate = self.gamestate
	local stage = game.stage

	local start_action
	if gamestate.name == "SinglePlayer" then
		start_action = function()
			if self.my_character then
				local gametype = gamestate.gametype
				local char1 = self.my_character
				local char2 = self.opponent_character
				local bkground = game.background:idx_to_str(self.game_background)
				self.my_character = nil
				game:start(gametype, char1, char2, bkground, nil, 1)
			end
		end
	elseif gamestate.name == "Netplay" then
		start_action = function()
			if self.my_character and not game.client.queuing then
				local queue_details = {
					character = self.my_character,
					background = game.background:idx_to_str(self.game_background),
				}
				game.client:queue("join", queue_details)
			end
		end
	end

	-- start button
	self:_createButton{
		name = "start",
		image = image.buttons_start,
		image_pushed = image.buttons_startpush,
		duration = 15,
		end_x = stage.width * 0.15,
		start_y = stage.height + image.buttons_start:getHeight(),
		end_y = stage.height * 0.9,
		easing = "outQuad",
		action = start_action,
	}

	-- details button
	self:_createButton{
		name = "details",
		image = image.buttons_details,
		image_pushed = image.buttons_detailspush,
		duration = 15,
		end_x = stage.width * 0.155 + image.buttons_details:getWidth(),
		start_y = stage.height + image.buttons_start:getHeight(),
		end_y = stage.height * 0.9,
		easing = "outQuad",
		action = function()
			if self.my_character then
				print("Some details!")
			end
		end,
	}

	-- back button
	self:_createButton{
		name = "back",
		image = image.buttons_back,
		image_pushed = image.buttons_backpush,
		duration = 15,
		end_x = stage.width * 0.05,
		end_y = stage.height * 0.09,
		pushed_sfx = "buttonback",
		action = function()
			game.statemanager:switch(require "gs_title")
		end,
	}

	-- left arrow for background select
	self:_createButton{
		name = "backgroundleft",
		image = image.buttons_backgroundleft,
		image_pushed = image.buttons_backgroundleft,
		duration = 60,
		end_x = stage.width * 0.6,
		end_y = stage.height * 0.8,
		transparency = 127,
		easing = "linear",
		action = function()
			self.game_background = (self.game_background - 2) % game.background.total + 1
			local selected_background = game.background:idx_to_str(self.game_background)
			local new_image = image.background[selected_background].thumbnail
			self.game_background_image:newImage(new_image)
		end,
	}

	-- right arrow for background select
	self:_createButton{
		name = "backgroundright",
		image = image.buttons_backgroundright,
		image_pushed = image.buttons_backgroundright,
		duration = 60,
		end_x = stage.width * 0.9,
		end_y = stage.height * 0.8,
		transparency = 127,
		easing = "linear",
		action = function()
			self.game_background = self.game_background % game.background.total + 1
			local selected_background = game.background:idx_to_str(self.game_background)
			local new_image = image.background[selected_background].thumbnail
			self.game_background_image:newImage(new_image)
		end,
	}

	-- leave queue button in netplay
	if gamestate.name == "Netplay" then
		-- create leave queue button
	end
end

-- creates the unclickable UI display images
function Charselect:_createUIImages()
	local game = self.game
	local gamestate = self.gamestate
	local stage = game.stage

	-- large portrait shadow
	self.displayed_character_shadow = Pic:create{
		game = game,
		name = "maincharacter",
		image = image.dummy,
		x = stage.width * 0.275,
		y = stage.height * 0.45,
		transparency = 60,
	}

	self.displayed_character_shadow.reset = function(c)
		c:change{duration = 0, x = stage.width * 0.275, transparency = 60}
		c:change{duration = 6, x = stage.width * 0.325, transparency = 255, easing = "outQuart"}
	end
	self.displayed_character_shadow:reset()

	-- large portrait with dummy pic
	self.displayed_character = Pic:create{
		game = game,
		name = "maincharacter",
		image = image.dummy,
		x = stage.width * 0.25,
		y = stage.height * 0.45,
		transparency = 60,
	}

	self.displayed_character.reset = function(c)
		c:change{duration = 0, x = stage.width * 0.25, transparency = 60}
		c:change{duration = 6, x = stage.width * 0.3, transparency = 255, easing = "outQuart"}
	end
	self.displayed_character:reset()

	-- large text of character name
	self.displayed_character_text = Pic:create{
		game = game,
		name = "maincharactertext",
		image = image.dummy,
		x = stage.width * 0.272,
		y = stage.height * 0.7,
		transparency = 60,
	}
	self.displayed_character_text.reset = function(c)
		c:change{duration = 0, y = stage.height * 0.7, transparency = 60}
		c:change{duration = 6, y = stage.height * 0.65, transparency = 255, easing = "outQuart"}
	end
	self.displayed_character_text:reset()

	-- background_image_frame
	self:_createImage{
		name = "backgroundframe",
		image = image.unclickables_selectstageborder,
		duration = 60,
		end_x = stage.width * 0.75,
		end_y = stage.height * 0.8,
		transparency = 127,
		easing = "linear",
	}

	local selected_background = game.background:idx_to_str(self.game_background)
	-- background_image
	self.game_background_image = self:_createImage{
		name = "backgroundimage",
		image = image.background[selected_background].thumbnail,
		duration = 60,
		end_x = stage.width * 0.75,
		end_y = stage.height * 0.8,
		transparency = 127,
		easing = "linear",
	}

	-- leave queue window
	if gamestate.name == "Netplay" then
		-- create leave queue background + text
	end
end

function Charselect:enter()
	local game = self.game
	local gamestate = self.gamestate
	self.clicked = nil
	if game.sound:getCurrentBGM() ~= "bgm_menu" then
		game.sound:stopBGM()
		game.sound:newBGM("bgm_menu", true)
	end

	self.current_background = common.instance(game.background.checkmate, game)
	self.game_background = 1 -- what's chosen for the maingame background
	self:_createCharacterButtons()
	self:_createUIButtons()
	self:_createUIImages()
	self.my_character = nil -- selected character for gamestart
	self.opponent_character = math.random() < 0.5 and "walter" or "heath"-- ditto
end

function Charselect:openSettingsMenu()
	self.game:_openSettingsMenu(self.gamestate)
end

function Charselect:closeSettingsMenu()
	self.game:_closeSettingsMenu(self.gamestate)
end

function Charselect:update(dt)
	local game = self.game
	local gamestate = self.gamestate
	self.current_background:update(dt)
	for _, tbl in pairs(gamestate.ui) do
		for _, v in pairs(tbl) do v:update(dt) end
	end
	self.displayed_character_shadow:update(dt)
	self.displayed_character:update(dt)
	self.displayed_character_text:update(dt)

	if gamestate.name == "Netplay" then
		-- update "Waiting in queue..." image
		-- update "Leave queue" button
	end
end

function Charselect:draw()
	local game = self.game
	local gamestate = self.gamestate
	
	local darkened = game:isScreenDark()
	self.current_background:draw{darkened = darkened}
	for _, v in spairs(gamestate.ui.static) do v:draw{darkened = darkened} end
	for _, v in pairs(gamestate.ui.clickable) do v:draw{darkened = darkened} end
	self.displayed_character_shadow:draw{darkened = darkened}
	self.displayed_character:draw{darkened = darkened}
	self.displayed_character_text:draw{darkened = darkened}
	game:_drawSettingsMenu(self.gamestate)

	if gamestate.name == "Netplay" then
		-- draw waiting in queue background, text, and leave queue button
	end
end

function Charselect:mousepressed(x, y)
	self.game:_mousepressed(x, y, self.gamestate)
end

function Charselect:mousereleased(x, y)
	self.game:_mousereleased(x, y, self.gamestate)
end

function Charselect:mousemoved(x, y)
	self.game:_mousemoved(x, y, self.gamestate)
end

return common.class("Charselect", Charselect)
