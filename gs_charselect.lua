local common = require "class.commons"
local image = require 'image'
local Pic = require 'pic'
local tween = require 'tween'

local charselect = {}

function charselect:enter()
	if self.sound:getCurrentBGM() ~= "bgm_menu" then
		self.sound:stopBGM()
		self.sound:newBGM("bgm_menu", true)
	end
		
	self.current_char = nil
	self.background_idx = 1

	local stage = self.stage
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
			image = self.background.list[self.background_idx].thumbnail,
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

	self.objects = {}
	for item, obj in pairs(data) do
		self.objects[item] = common.instance(Pic, self, {x = obj.start_x, y = obj.start_y, image = obj.image})
		self.objects[item].transparency = obj.start_transparency
		self.objects[item].tweening = tween.new(obj.tween_dur, self.objects[item],
			{x = obj.x, y = obj.y, transparency = obj.transparency}, obj.tween_type)
		self.objects[item].name = obj.name
	end

	local function resetScreen()
		self.current_char = nil
		self.clicked = nil
		self.objects.char:newImage(image.dummy)
		self.objects.char_text:newImage(image.dummy)
		for _, obj in pairs(self.objects) do
			obj.tweening:reset()
		end
	end
	self.buttons = {
		start = {
			item = self.objects.start,
			action = function()
				if self.current_char then
					local gametype = "1P"
					local char1 = self.current_char
					local char2 = "walter"
					local bkground = self.background.list[self.background_idx].background
					self.current_char = nil
					resetScreen()
					self:start(gametype, char1, char2, bkground, nil, 1)
				end
			end,
			pushed = function()
				self.sound:newSFX("button")
				self.objects.start:newImage(image.charselect.startpush)
			end,
			released = function() self.objects.start:newImage(image.charselect.start) end,
		},
		back = {
			item = self.objects.back,
			action = function()
				resetScreen()
				self.statemanager:switch(require "gs_title")
			end,
			pushed = function()
				self.sound:newSFX("button_back")
				self.objects.back:newImage(image.charselect.backpush)
			end,
			released = function() self.objects.back:newImage(image.charselect.back) end,
		},
		left_arrow = {
			item = self.objects.left_arrow,
			action = function()
				self.background_idx = (self.background_idx - 2) % #self.background.list + 1
				self.objects.bkground:newImage(self.background.list[self.background_idx].thumbnail)
			 end,
			pushed = function()
				self.sound:newSFX("button")
				self.objects.left_arrow:newImage(image.charselect.left_arrow_push)
			end,
			released = function() self.objects.left_arrow:newImage(image.charselect.left_arrow) end,
		},
		right_arrow = {
			item = self.objects.right_arrow,
			action = function()
				self.background_idx = self.background_idx % #self.background.list + 1
				self.objects.bkground:newImage(self.background.list[self.background_idx].thumbnail)
			end,
			pushed = function()
				self.sound:newSFX("button")
				self.objects.right_arrow:newImage(image.charselect.right_arrow_push)
			end,
			released = function() self.objects.right_arrow:newImage(image.charselect.right_arrow) end,
		},
	}

	for i = 1, #selectable_chars do
		self.buttons[i] = {
			item = self.objects[i],
			action = function()
				if self.current_char ~= selectable_chars[i] then
					self.objects.char:newImage(image.charselect[selectable_chars[i].."char"])
					self.objects.char.tweening:reset()
					self.objects.char_text:newImage(image.charselect[selectable_chars[i].."name"])
					self.objects.char_text.tweening:reset()
					self.current_char = selectable_chars[i]
				end
			end,
			pushed = function()
				self.sound:newSFX("button")
				self.objects[i]:newImage(image.charselect[selectable_chars[i].."ring"])
			end,
			released = function() self.objects[i]:newImage(image.charselect[selectable_chars[i].."ring"]) end,
		}
	end
end

function charselect:draw()
	charselect.drawBackground(self)
	charselect.drawScreenElements(self)
end

function charselect:drawBackground()
	self.background.colors.drawImages(self.background)
end

function charselect:drawScreenElements()
	local draw_order = {"Character", "CharacterText", "Background", "Portrait", "Button"}
	for i = 1, #draw_order do
		for _, v in pairs(self.objects) do
			if v.name == draw_order[i] then v:draw() end
		end
	end
end

local pointIsInRect = require "utilities".pointIsInRect

function charselect:mousepressed(x, y)
	for _, button in pairs(self.buttons) do
		if pointIsInRect(x, y, button.item:getRect()) and not self.clicked then
			self.clicked = button
			button.pushed()
			return
		end
	end
	self.clicked = nil
end

function charselect:mousereleased(x, y)
	for _, button in pairs(self.buttons) do
		button.released()
	end
	for _, button in pairs(self.buttons) do
		if pointIsInRect(x, y, button.item:getRect()) and self.clicked == button then
			button.action()
			break
		end
	end
	self.clicked = false
end

function charselect:mousemoved(x, y)
	if self.clicked then
		if not pointIsInRect(x, y, self.clicked.item:getRect()) then
			self.clicked.released()
			self.clicked = false
		end
	end
end

function charselect:update(dt)
	self.background.colors.update(self.background)
	for _, v in pairs(self.objects) do
		v.tweening:update(dt)
	end
end

return charselect
