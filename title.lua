local image = require 'image'
local stage = require 'stage'
local pic = require 'pic'
local client = require 'client'
local tween = require 'tween'

local title = {}
local clicked = false

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
	objects[item] = pic:new{x = obj.x, y = obj.start_y, image = obj.image}
	objects[item].transparency = obj.start_transparency
	objects[item].tweening = tween.new(obj.tween_dur, objects[item],
		{y = obj.y, transparency = obj.transparency}, obj.tween_type)
end

local buttons = {
	vscpu = {
		item = objects.vscpu,
		action = function() game.current_screen = "charselect" end,
		pushed = function() objects.vscpu.image = image.title.vscpupush end,
		released = function() objects.vscpu.image = image.title.vscpu end,
	},
	online ={
		item = objects.online,
		action = function() game.current_screen = "lobby" client.connect() end,
		pushed = function() objects.online.image = image.title.onlinepush end,
		released = function() objects.online.image = image.title.online end,
	},
}

function title.drawBackground()
	love.graphics.clear()
	Background.Seasons.drawImages()
end

function title.drawScreenElements()
	love.graphics.clear()
	for _, v in pairs(objects) do
		v:draw()
	end
end

function title.handleClick(x, y)
	for _, button in pairs(buttons) do
		if pointIsInRect(x, y, button.item:getRect()) then
			clicked = button
			button.pushed()
			return
		end
	end
	clicked = false
end

function title.handleRelease(x, y)
	for _, button in pairs(buttons) do button.released() end
	for _, button in pairs(buttons) do
		if pointIsInRect(x, y, button.item:getRect()) and clicked == button then
			button.action()
			break
		end
	end
	clicked = false
end

function title.handleMove(x, y)
	if clicked then
		if pointIsInRect(x, y, clicked.item:getRect()) then
			clicked.pushed()
		else
			clicked.released()
		end
	end
end

function title.update(dt)
	Background.Seasons.update()
	for _, v in pairs(objects) do
		if v.tweening then 
			if v.tweening:update(dt) then v.tweening = nil end
		end
	end
end

return title