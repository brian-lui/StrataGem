local love = _G.love

local common = require "class.commons"
local image = require 'image'
local Pic = require 'pic'
local tween = require 'tween'

local title = {}

function title:enter()
	self.clicked = nil
	if self.sound:getCurrentBGM() ~= "bgm_menu" then self.sound:stopBGM() end
	self.current_background = common.instance(self.background.RabbitInASnowstorm, self)

	local stage = self.stage
	local data = {
		logo = {
			x = stage.width * 0.5,
			start_y = stage.height * -0.5,
			y = stage.height * 0.35,
			start_transparency = 0,
			transparency = 255,
			image = image.title.logo,
			tween_dur = 1.5,
			tween_type = "linear",
		},
		vscpu = {
			x = stage.width * 0.35,
			start_y = stage.height * 1.2,
			y = stage.height * 0.8,
			start_transparency = 0,
			transparency = 255,
			image = image.title.vscpu,
			tween_dur = 2.25,
			tween_type = "inQuart",
		},
		online = {
			x = stage.width * 0.65,
			start_y = stage.height * 1.2,
			y = stage.height * 0.8,
			start_transparency = 0,
			transparency = 255,
			image = image.title.online,
			tween_dur = 2.25,
			tween_type = "inQuart",
		},
	}

	local objects = {}

	for item, obj in pairs(data) do
		objects[item] = common.instance(Pic, self, {x = obj.x, y = obj.start_y, image = obj.image})
		objects[item].transparency = obj.start_transparency
		objects[item].tweening = tween.new(obj.tween_dur, objects[item],
			{y = obj.y, transparency = obj.transparency}, obj.tween_type)
	end
	self.objects = objects

	local buttons = {
		vscpu = {
			item = objects.vscpu,
			action = function()
				self.statemanager:switch(require "gs_charselect")
			end,
			pushed = function()
				self.sound:newSFX("button")
				objects.vscpu.image = image.title.vscpupush
			end,
			released = function() objects.vscpu.image = image.title.vscpu end,
		},
		online ={
			item = objects.online,
			action = function() 
				self.statemanager:switch(require "gs_lobby") self.client:connect()
			end,
			pushed = function()
				self.sound:newSFX("button")
				objects.online.image = image.title.onlinepush
			end,
			released = function() objects.online.image = image.title.online end,
		},
	}
	self.buttons = buttons
end

function title:update(dt)
	self.current_background:update(dt)
	for name, v in pairs(self.objects) do
		if v.tweening then
			if v.tweening:update(dt) then
				v.tweening = nil
				if name == "logo" then
					if self.sound:getCurrentBGM() ~= "bgm_menu" then
						self.sound:newBGM("bgm_menu", true)
					end
				end
			end
		end
	end
end

function title:draw()
	self.current_background:draw()
	for _, v in pairs(self.objects) do v:draw() end
end

local pointIsInRect = require "utilities".pointIsInRect
function title:mousepressed(x, y)
	for _, button in pairs(self.buttons) do
		if pointIsInRect(x, y, button.item:getRect()) then
			self.clicked = button
			button.pushed()
			return
		end
	end
	self.clicked = false
end

function title:mousereleased(x, y)
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

function title:mousemoved(x, y)
	if self.clicked then
		if not pointIsInRect(x, y, self.clicked.item:getRect()) then
			self.clicked.released()
			self.clicked = false
		end
	end
end

return title
