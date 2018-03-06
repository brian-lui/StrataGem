local common = require "class.commons"
local image = require 'image'
local Pic = require 'pic'
local pointIsInRect = require "utilities".pointIsInRect
local spairs = require "utilities".spairs

local charselect = {name = "charselect"}
function charselect:init()
	charselect.selectable_chars = {"heath", "walter", "gail", "holly",
		"wolfgang", "hailey", "diggory", "buzz", "ivy", "joy", "mort", "damon"}
	charselect.ui = {clickable = {}, static = {}, popup_clickable = {}, popup_static = {}}
end

-- refer to game.lua for instructions for _createButton and _createImage
function charselect:_createButton(params)
	return self:_createButton(charselect, params)
end

function charselect:_createImage(params)
	return self:_createImage(charselect, params)
end

-- creates the clickable buttons for selecting characters
function charselect:_createCharacterButtons()
	local stage = self.stage
	charselect.clicked = nil
	local end_x, end_y
	for i = 1, #charselect.selectable_chars do
		local char = charselect.selectable_chars[i]
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
		charselect._createButton(self, {
			name = char,
			image = image.charselect[char.."ring"],
			image_pushed = image.charselect[char.."ring"], -- need new pics!
			duration = 30,
			start_x = -0.05 * i,
			end_x = end_x,
			start_y = 0.1 * i,
			end_y = end_y,
			start_transparency = 195,
			easing = "inOutSine",
			pushed_sfx = "buttoncharacter",
			action = function() 
				if charselect.my_character ~= char then
					charselect.my_character = char
					charselect.displayed_character:newImage(image.charselect[char.."char"])
					charselect.displayed_character_text:newImage(image.charselect[char.."name"])
					charselect.displayed_character:reset()
					charselect.displayed_character_text:reset()
				end
			end,
		})
	end
end

-- creates the clickable UI objects
function charselect:_createUIButtons()
	local stage = self.stage

	-- start button
	charselect._createButton(self, {
		name = "start",
		image = image.button.start,
		image_pushed = image.button.startpush,
		duration = 15,
		end_x = stage.width * 0.15,
		start_y = stage.height + image.button.start:getHeight(),
		end_y = stage.height * 0.9,
		easing = "outQuad",
		action = function() 
			if charselect.my_character then
				local gametype = charselect.gametype
				local char1 = charselect.my_character
				local char2 = charselect.opponent_character
				local bkground = self.background:idx_to_str(charselect.game_background)
				charselect.my_character = nil
				self:start(gametype, char1, char2, bkground, nil, 1)
			end
		end,
	})

	-- details button
	charselect._createButton(self, {
		name = "details",
		image = image.button.details,
		image_pushed = image.button.detailspush,
		duration = 15,
		end_x = stage.width * 0.155 + image.button.details:getWidth(),
		start_y = stage.height + image.button.start:getHeight(),
		end_y = stage.height * 0.9,
		easing = "outQuad",
		action = function() 
			if charselect.my_character then
				print("Some details!")
			end
		end,
	})

	-- back button
	charselect._createButton(self, {
		name = "back",
		image = image.button.back,
		image_pushed = image.button.backpush,
		duration = 15,
		end_x = stage.width * 0.05,
		end_y = stage.height * 0.09,
		action = function()
			self.statemanager:switch(require "gs_title")
		end,
	})

	-- left arrow for background select
	charselect._createButton(self, {
		name = "backgroundleft",
		image = image.button.backgroundleft,
		image_pushed = image.button.backgroundleft,
		duration = 60,
		end_x = stage.width * 0.6,
		end_y = stage.height * 0.8,
		transparency = 127,
		easing = "linear",
		action = function()
			charselect.game_background = (charselect.game_background - 2) % self.background.total + 1
			local selected_background = self.background:idx_to_str(charselect.game_background)
			local new_image = image.background[selected_background].thumbnail
			charselect.game_background_image:newImage(new_image)
		end,
	})

	-- right arrow for background select
	charselect._createButton(self, {
		name = "backgroundright",
		image = image.button.backgroundright,
		image_pushed = image.button.backgroundright,
		duration = 60,
		end_x = stage.width * 0.9,
		end_y = stage.height * 0.8,
		transparency = 127,
		easing = "linear",
		action = function()
			charselect.game_background = charselect.game_background % self.background.total + 1
			local selected_background = self.background:idx_to_str(charselect.game_background)
			local new_image = image.background[selected_background].thumbnail
			charselect.game_background_image:newImage(new_image)
		end,
	})
end

-- creates the unclickable UI display images
function charselect:_createUIImages()
	local stage = self.stage

	-- large portrait with dummy pic
	charselect.displayed_character = charselect._createImage(self, {
		name = "maincharacter",
		image = image.dummy,
		duration = 6,
		start_x = stage.width * 0.25,
		end_x = stage.width * 0.3,
		end_y = stage.height * 0.45,
		transparency = 60,
		easing = "outQuart",
	})
	charselect.displayed_character.reset = function(c)
		c.x = stage.width * 0.25
		c.transparency = 60
		c:change{duration = 6, x = stage.width * 0.3, transparency = 255, easing = "outQuart"}
	end

	-- large portrait text with dummy pic
	charselect.displayed_character_text = charselect._createImage(self, {
		name = "maincharactertext",
		image = image.dummy,
		duration = 6,
		end_x = stage.width * 0.272,
		start_y = stage.height * 0.7,
		end_y = stage.height * 0.65,
		transparency = 60,
		easing = "outQuart",
	})
	charselect.displayed_character_text.reset = function(c)
		c.y = stage.height * 0.7
		c.transparency = 60
		c:change{duration = 6, y = stage.height * 0.65, transparency = 255, easing = "outQuart"}
	end

	-- background_image_frame
	charselect._createImage(self, {
		name = "backgroundframe",
		image = image.unclickable.select_stageborder,
		duration = 60,
		end_x = stage.width * 0.75,
		end_y = stage.height * 0.8,
		transparency = 127,
		easing = "linear",
	})

	local selected_background = self.background:idx_to_str(charselect.game_background)
	-- background_image
	charselect.game_background_image = charselect._createImage(self, {
		name = "backgroundimage",
		image = image.background[selected_background].thumbnail,
		duration = 60,
		end_x = stage.width * 0.75,
		end_y = stage.height * 0.8,
		transparency = 127,
		easing = "linear",
	})
end

function charselect:enter()
	charselect.clicked = nil
	if self.sound:getCurrentBGM() ~= "bgm_menu" then
		self.sound:stopBGM()
		self.sound:newBGM("bgm_menu", true)
	end

	charselect.current_background = common.instance(self.background.checkmate, self)
	charselect.game_background = 1 -- what's chosen for the maingame background
	charselect._createCharacterButtons(self)
	charselect._createUIButtons(self)
	charselect._createUIImages(self)
	charselect.my_character = nil -- selected character for gamestart
	charselect.gametype = "1P" -- can change this later to re-use for netplay
	charselect.opponent_character = math.random() < 0.5 and "walter" or "heath"-- ditto
end

function charselect:openSettingsMenu()
	self:_openSettingsMenu(charselect)
end

function charselect:closeSettingsMenu()
	self:_closeSettingsMenu(charselect)
end

function charselect:update(dt)
	charselect.current_background:update(dt)
	for _, tbl in pairs(charselect.ui) do
		for _, v in pairs(tbl) do v:update(dt) end
	end
end

function charselect:draw()
	local darkened = self.screen_darkened
	charselect.current_background:draw{darkened = darkened}
	for _, v in spairs(charselect.ui.static) do v:draw{darkened = darkened} end
	for _, v in pairs(charselect.ui.clickable) do v:draw{darkened = darkened} end
	self:_drawSettingsMenu(charselect)
end

function charselect:mousepressed(x, y)
	self:_mousepressed(x, y, charselect)
end

function charselect:mousereleased(x, y)
	self:_mousereleased(x, y, charselect)
end

function charselect:mousemoved(x, y)
	self:_mousemoved(x, y, charselect)
end

return charselect
