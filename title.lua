local love = _G.love

local common = require "class.commons"
local image = require 'image'
local pic = require 'pic'
local client = require 'client'
local tween = require 'tween'

local title = {}

function title:enter()
	self.clicked = nil
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
		objects[item] = common.instance(pic, {x = obj.x, y = obj.start_y, image = obj.image})
		objects[item].transparency = obj.start_transparency
		objects[item].tweening = tween.new(obj.tween_dur, objects[item],
			{y = obj.y, transparency = obj.transparency}, obj.tween_type)
	end
	self.objects = objects

	local buttons = {
		vscpu = {
			item = objects.vscpu,
			action = function() self.statemanager:switch(require "charselect") end,
			pushed = function() objects.vscpu.image = image.title.vscpupush end,
			released = function() objects.vscpu.image = image.title.vscpu end,
		},
		online ={
			item = objects.online,
			action = function() self.statemanager:switch(require "lobby") self.client:connect() end,
			pushed = function() objects.online.image = image.title.onlinepush end,
			released = function() objects.online.image = image.title.online end,
		},
	}
	self.buttons = buttons
end

function title:update(dt)
	--self:drawBackground()	-- TODO: Shouldn't this be in draw()?
	self.background.seasons.update(self.background)
	for _, v in pairs(self.objects) do
		if v.tweening then
			if v.tweening:update(dt) then
				v.tweening = nil
			end
		end
	end
end

function title:draw()
	title.drawBackground(self)
	title.drawScreenElements(self)
end

function title:drawScreenElements()
	--love.graphics.clear()
	for _, v in pairs(self.objects) do
		v:draw()
	end
end

function title:drawBackground()
	--love.graphics.clear()
	self.background.seasons.drawImages(self.background)
end

local pointIsInRect = require("utilities").pointIsInRect

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
		if pointIsInRect(x, y, self.clicked.item:getRect()) then
			self.clicked.pushed()
		else
			self.clicked.released()
		end
	end
end

return title
