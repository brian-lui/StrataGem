local common = require "class.commons"
local image = require 'image'
local Pic = require 'pic'
local pointIsInRect = require "utilities".pointIsInRect

local charselect = {}
function charselect:init()
	charselect.selectable_chars = {"heath", "walter", "gail", "holly",
		"wolfgang", "hailey", "diggory", "buzz", "ivy", "joy"}	
end

--[[ create a clickable object
	mandatory parameters: name, image, image_pushed, end_x, end_y, action
	optional parameters: duration, start_transparency, end_transparency,
		start_x, start_y, easing, exit, pushed, pushed_sfx, released, released_sfx
--]]
function charselect:_createButton(params)
	if params.name == nil then print("No object name received!") end
	if params.image_pushed == nil then print("No push image received for " .. params.name .. "!") end
	local stage = self.stage
	local button = common.instance(Pic, self, {
		name = params.name,
		x = params.start_x or params.end_x,
		y = params.start_y or params.end_y,
		transparency = params.start_transparency or 255,
		image = params.image,
		container = charselect.ui_clickable,
	})
	button:change{duration = params.duration, x = params.end_x, y = params.end_y,
		transparency = params.end_transparency or 255,
		easing = params.easing or "linear", exit = params.exit}
	button.pushed = params.pushed or function()
		self.sound:newSFX(pushed_sfx or "button")
		button:newImage(params.image_pushed)
	end
	button.released = params.released or function()
		if released_sfx then self.sound:newSFX(released_sfx) end
		button:newImage(params.image)
	end
	button.action = params.action
	return button
end

--[[ creates an object that can be tweened but not clicked
	mandatory parameters: name, image, end_x, end_y
	optional parameters: duration, start_transparency, end_transparency, start_x, start_y, easing, exit
--]]
function charselect:_createImage(params)
	if params.name == nil then print("No object name received!") end
	local stage = self.stage
	local button = common.instance(Pic, self, {
		name = params.name,
		x = params.start_x or params.end_x,
		y = params.start_y or params.end_y,
		transparency = params.start_transparency or 255,
		image = params.image,
		container = charselect.ui_static,
	})
	button:change{duration = params.duration, x = params.end_x, y = params.end_y,
		transparency = params.end_transparency or 255, easing = params.easing, exit = params.exit}
	return button
end

-- creates the clickable buttons for selecting characters
function charselect:_createCharacterButtons()
	local stage = self.stage
	local end_x, end_y
	for i = 1, #charselect.selectable_chars do
		local char = charselect.selectable_chars[i]
		if i >= 1 and i < 4 then
			end_x = stage.width * (0.125 * i + 0.5)
			end_y = stage.height * 0.2
		elseif i >= 4 and i < 8 then
			end_x = stage.width * (0.125 * i + 0.0625)
			end_y = stage.height * 0.4
		elseif i >= 8 and i < 11 then
			end_x = stage.width * (0.125 * i - 0.375)
			end_y = stage.height * 0.6
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
		end_x = stage.width * 0.25,
		start_y = stage.height + image.button.start:getHeight(),
		end_y = stage.height * 0.8,
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

	-- back button
	charselect._createButton(self, {
		name = "back",
		image = image.button.back,
		image_pushed = image.button.backpush,
		duration = 15,
		start_x = -image.button.back:getWidth(),
		end_x = image.button.back:getWidth() * 0.6,
		end_y = image.button.back:getHeight() * 0.6,
		easing = "outQuad",
		pushed_sfx = "button_back",
		action = function() self.statemanager:switch(require "gs_title") end,
	})

	-- left arrow for background select
	charselect._createButton(self, {
		name = "leftarrow",
		image = image.button.leftarrow,
		image_pushed = image.button.leftarrow,
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
		name = "rightarrow",
		image = image.button.rightarrow,
		image_pushed = image.button.rightarrow,
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
		start_x = stage.width * 0.20,
		end_x = stage.width * 0.25,
		end_y = stage.height * 0.5,
		transparency = 60,
		easing = "outQuart",
	})
	charselect.displayed_character.reset = function(c)
		c.x = stage.width * 0.20
		c.transparency = 60
		c:change{duration = 6, x = stage.width * 0.25, transparency = 255, easing = "outQuart"}
	end

	-- large portrait text with dummy pic
	charselect.displayed_character_text = charselect._createImage(self, {
		name = "maincharactertext",
		image = image.dummy,
		duration = 6,
		end_x = stage.width * 0.25,
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
	charselect.ui_clickable = {}
	charselect.ui_static = {}
	charselect.current_background = common.instance(self.background.rabbitsnowstorm, self)
	charselect.game_background = 1 -- what's chosen for the maingame background
	charselect._createCharacterButtons(self)
	charselect._createUIButtons(self)
	charselect._createUIImages(self)
	charselect.my_character = nil -- selected character for gamestart
	charselect.gametype = "1P" -- can change this later to re-use for netplay
	charselect.opponent_character = "walter" -- ditto
end


function charselect:update(dt)
	charselect.current_background:update(dt)
	for _, v in pairs(charselect.ui_clickable) do v:update(dt) end
	for _, v in pairs(charselect.ui_static) do v:update(dt) end
end

function charselect:draw()
	charselect.current_background:draw()
	for _, v in pairs(charselect.ui_static) do v:draw() end
	for _, v in pairs(charselect.ui_clickable) do v:draw() end
end

function charselect:mousepressed(x, y)
	for _, button in pairs(charselect.ui_clickable) do
		if pointIsInRect(x, y, button:getRect()) then
			charselect.clicked = button
			button.pushed()
			return
		end
	end
	charselect.clicked = false
end

function charselect:mousereleased(x, y)
	for _, button in pairs(charselect.ui_clickable) do
		button.released()
		if pointIsInRect(x, y, button:getRect()) and charselect.clicked == button then
			button.action()
			break
		end
	end
	charselect.clicked = false
end

function charselect:mousemoved(x, y)
	if charselect.clicked then
		if not pointIsInRect(x, y, charselect.clicked:getRect()) then
			charselect.clicked.released()
			charselect.clicked = false
		end
	end
end

return charselect
