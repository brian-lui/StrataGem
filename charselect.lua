local image = require 'image'
local stage = game.stage
local pic = require 'pic'
local tween = require 'tween'
local background = require 'background'

local charselect = {}
local clicked = false
local current_char = nil
local background_idx = 1

local selectable_chars = {"heath", "walter", "gail", "gail", "gail", "hailey", "gail", "buzz", "gail", "gail"}
--local selectable_chars = {"heath", "walter", "gail", "holly", "wolfgang", "hailey", "diggory", "buzz", "ivy", "joy"}
local data = {
	start = {
		start_x = stage.width * 0.25,
		x = stage.width * 0.25,
		start_y = stage.height + image.charselect.start:getHeight(),
		y = stage.height * 0.8,
		start_transparency = 255,
		transparency = 255,
		image = image.charselect.start,
		tween_dur = 0.25,
		tween_type = "outQuad",
		name = "Button",
	},
	back = {
		start_x = -image.charselect.back:getWidth(),
		x = image.charselect.back:getWidth() * 0.5,
		start_y = image.charselect.back:getHeight() * 0.5,
		y = image.charselect.back:getHeight() * 0.5,
		start_transparency = 255,
		transparency = 255,
		image = image.charselect.back,
		tween_dur = 0.25,
		tween_type = "outQuad",
		name = "Button",
	},
	char = {
		start_x = stage.width * 0.20,
		x = stage.width * 0.25,
		start_y = stage.height * 0.5,
		y = stage.height * 0.5,
		start_transparency = 60,
		transparency = 255,
		image = image.dummy,
		tween_dur = 0.1,
		tween_type = "outQuart",
		name = "Character"
	},
	char_text = {
		start_x = stage.width * 0.25,
		x = stage.width * 0.25,
		start_y = stage.height * 0.7,
		y = stage.height * 0.65,
		start_transparency = 60,
		transparency = 255,
		image = image.dummy,
		tween_dur = 0.1,
		tween_type = "outQuart",
		name = "CharacterText"
	},
	left_arrow = {
		start_x = stage.width * 0.6,
		x = stage.width * 0.6,
		start_y = stage.height * 0.8,
		y = stage.height * 0.8,
		start_transparency = 127,
		transparency = 255,
		image = image.charselect.left_arrow,
		tween_dur = 1,
		tween_type = "linear",
		name = "Background",
	},
	right_arrow = {
		start_x = stage.width * 0.9,
		x = stage.width * 0.9,
		start_y = stage.height * 0.8,
		y = stage.height * 0.8,
		start_transparency = 127,
		transparency = 255,
		image = image.charselect.right_arrow,
		tween_dur = 1,
		tween_type = "linear",
		name = "Background",
	},
	bk_frame = {
		start_x = stage.width * 0.75,
		x = stage.width * 0.75,
		start_y = stage.height * 0.8,
		y = stage.height * 0.8,
		start_transparency = 127,
		transparency = 255,
		image = image.charselect.bk_frame,
		tween_dur = 1,
		tween_type = "linear",
		name = "Background",
	},
	bkground = {
		start_x = stage.width * 0.75,
		x = stage.width * 0.75,
		start_y = stage.height * 0.8,
		y = stage.height * 0.8,
		start_transparency = 127,
		transparency = 255,
		image = background.list[background_idx].thumbnail,
		tween_dur = 1,
		tween_type = "linear",
		name = "Background",
	},
}
for i = 1, #selectable_chars do
	local x_pos, y_pos
	if i >= 1 and i < 4 then
		x_pos = stage.width * (0.125*i + 0.5)
		y_pos = stage.height * 0.2
	elseif i >= 4 and i < 8 then
		x_pos = stage.width * (0.125*i + 0.0625)
		y_pos = stage.height * 0.4
	elseif i >= 8 and i < 11 then
		x_pos = stage.width * (0.125*i - 0.375)
		y_pos = stage.height * 0.6
	else
		print("poops")
	end

	data[i] = {
		start_x = -0.05 * i,
		x = x_pos,
		start_y = 0.1 * i,
		y = y_pos,
		start_transparency = 195,
		transparency = 255,
		image = image.charselect[selectable_chars[i].."ring"],
		tween_dur = 0.7,
		tween_type = "inOutSine",
		name = "Portrait"
	}
end

local objects = {}
for item, obj in pairs(data) do
	objects[item] = pic:new{x = obj.start_x, y = obj.start_y, image = obj.image}
	objects[item].transparency = obj.start_transparency
	objects[item].tweening = tween.new(obj.tween_dur, objects[item],
		{x = obj.x, y = obj.y, transparency = obj.transparency}, obj.tween_type)
	objects[item].name = obj.name
end

local function resetScreen()
	current_char = nil
	clicked = false
	objects.char:newImage(image.dummy)
	objects.char_text:newImage(image.dummy)
	for _, obj in pairs(objects) do
		obj.tweening:reset()
	end
end
local buttons = {
	start = {
		item = objects.start,
		action = function()
			if current_char then
				local gametype = "1P"
				local char1 = current_char
				local char2 = "walter"
				local bkground = background.list[background_idx].background
				current_char = false
				startGame(gametype, char1, char2, bkground, nil, 1)
				resetScreen()
			end
		end,
		pushed = function() objects.start:newImage(image.charselect.startpush) end,
		released = function() objects.start:newImage(image.charselect.start) end,
	},
	back = {
		item = objects.back,
		action = function()
			game.current_screen = "title"
			resetScreen()
		end,
		pushed = function() objects.back:newImage(image.charselect.backpush) end,
		released = function() objects.back:newImage(image.charselect.back) end,
	},
	left_arrow = {
		item = objects.left_arrow,
		action = function()
			background_idx = (background_idx - 2) % #background.list + 1
			objects.bkground:newImage(background.list[background_idx].thumbnail)
		 end,
		pushed = function() objects.left_arrow:newImage(image.charselect.left_arrow_push) end,
		released = function() objects.left_arrow:newImage(image.charselect.left_arrow) end,
	},
	right_arrow = {
		item = objects.right_arrow,
		action = function()
			background_idx = background_idx % #background.list + 1
			objects.bkground:newImage(background.list[background_idx].thumbnail)
		end,
		pushed = function() objects.right_arrow:newImage(image.charselect.right_arrow_push) end,
		released = function() objects.right_arrow:newImage(image.charselect.right_arrow) end,
	},
}

for i = 1, #selectable_chars do
	buttons[i] = {
		item = objects[i],
		action = function()
			if current_char ~= selectable_chars[i] then
				objects.char:newImage(image.charselect[selectable_chars[i].."char"])
				objects.char.tweening:reset()
				objects.char_text:newImage(image.charselect[selectable_chars[i].."name"])
				objects.char_text.tweening:reset()
				current_char = selectable_chars[i]
			end
		end,
		pushed = function() objects[i]:newImage(image.charselect[selectable_chars[i].."ring"]) end,
		released = function() objects[i]:newImage(image.charselect[selectable_chars[i].."ring"]) end,
	}
end

function charselect.drawBackground()
	love.graphics.clear()
	Background.Colors.drawImages()
end

function charselect.drawScreenElements()
	love.graphics.clear()
	local draw_order = {"Character", "CharacterText", "Background", "Portrait", "Button"}
	for i = 1, #draw_order do
		for _, v in pairs(objects) do
			if v.name == draw_order[i] then v:draw() end
		end
	end
end

function charselect.handleClick(x, y)
	for _, button in pairs(buttons) do
		if pointIsInRect(x, y, button.item:getRect()) then
			clicked = button
			button.pushed()
			return
		end
	end
	clicked = false
end

function charselect.handleRelease(x, y)
	for _, button in pairs(buttons) do button.released() end
	for _, button in pairs(buttons) do
		if pointIsInRect(x, y, button.item:getRect()) and clicked == button then
			button.action()
			break
		end
	end
	clicked = false
end

function charselect.handleMove(x, y)
	if clicked then
		if pointIsInRect(x, y, clicked.item:getRect()) then
			clicked.pushed()
		else
			clicked.released()
		end
	end
end

function charselect.update(dt)
	Background.Colors.update()
	for _, v in pairs(objects) do
		v.tweening:update(dt)
	end
end

return charselect
