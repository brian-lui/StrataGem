--[[
	Note to coders and code readers!
	You can't call title._createButton by doing title:_createButton(...)
	That will call it by passing in an instance of title, which doesn't work (?)
	You have to call it with title._createButton(self, ...)
	That passes in an instance of self, which works (???)
	Look I didn't code this I just know how to use it, ok
--]]

local common = require "class.commons"
local image = require 'image'
local Pic = require 'pic'
local tween = require 'tween'

local title = {}

--[[ create a clickable object
	mandatory parameters: name, image, image_pushed, end_x, end_y, action
	optional parameters: duration, transparency, start_x, start_y, easing,
		exit, pushed, pushed_sfx, released, released_sfx
--]]
function title:_createButton(params)
	if params.name == nil then print("No object name received!") end
	if params.image_pushed == nil then print("No push image received!") end
	local stage = self.stage
	local button = common.instance(Pic, self, {
		name = params.name,
		x = params.start_x or params.end_x,
		y = params.start_y or params.end_y,
		transparency = params.start_transparency or 255,
		image = params.image,
		container = title.ui_clickable,
		counter = "ui_element",
	})
	button:moveTo{duration = params.duration, x = params.end_x, y = params.end_y,
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
	optional parameters: duration, transparency, start_x, start_y, easing, exit
--]]
function title:_createImage(params)
	if params.name == nil then print("No object name received!") end
	local stage = self.stage
	local button = common.instance(Pic, self, {
		name = params.name,
		x = params.start_x or params.end_x,
		y = params.start_y or params.end_y,
		transparency = params.transparency or 255,
		image = params.image,
		container = title.ui_static,
		counter = "ui_element",
	})
	button:moveTo{duration = params.duration, x = params.end_x, y = params.end_y,
		transparency = params.transparency, easing = params.easing, exit = params.exit}
	return button
end

-- After the initial tween, we keep the icons here if returning to title screen
-- So we put it in init(), not enter() like in the other states
function title:init()
	local stage = self.stage	
	self.timeStep, self.timeBucket = 1/60, 0
	title.ui_clickable = {}
	title.ui_static = {}
	title._createButton(self, {
		name = "vscpu",
		image = image.title.vscpu,
		image_pushed = image.title.vscpupush,
		duration = 60,
		end_x = stage.width * 0.35,
		start_y = stage.height * 1.2,
		end_y = stage.height * 0.8,
		start_transparency = 0,
		easing = "inQuart",
		action = function() 
			self.statemanager:switch(require "gs_charselect")
		end,
	})
	title._createButton(self, {
		name = "online",
		image = image.title.online,
		image_pushed = image.title.onlinepush,
		duration = 60,
		end_x = stage.width * 0.65,
		start_y = stage.height * 1.2,
		end_y = stage.height * 0.8,
		start_transparency = 0, 
		easing = "inQuart",
		action = function()
			self.statemanager:switch(require "gs_lobby") self.client:connect()
		end,
	})
	title._createImage(self, {
		name = "logo",
		image = image.title.logo,
		duration = 45,
		end_x = stage.width * 0.5,
		start_y = 0,
		end_y = stage.height * 0.35,
		start_transparency = 0,
		easing = "linear",
		exit = {function() 
			if self.sound:getCurrentBGM() ~= "bgm_menu" then 
				self.sound:newBGM("bgm_menu", true)
			end
		end},
	})	
end

function title:enter()
	title.clicked = nil
	if self.sound:getCurrentBGM() ~= "bgm_menu" then self.sound:stopBGM() end
	title.current_background = common.instance(self.background.rabbitsnowstorm, self)
end

function title:update(dt)
	title.current_background:update(dt)
	for _, v in pairs(title.ui_clickable) do v:update(dt) end
	for _, v in pairs(title.ui_static) do v:update(dt) end
end

function title:draw()
	title.current_background:draw()
	for _, v in pairs(title.ui_static) do v:draw() end
	for _, v in pairs(title.ui_clickable) do v:draw() end
end

local pointIsInRect = require "utilities".pointIsInRect
function title:mousepressed(x, y)
	for _, button in pairs(title.ui_clickable) do
		if pointIsInRect(x, y, button:getRect()) then
			title.clicked = button
			button.pushed()
			return
		end
	end
	title.clicked = false
end

function title:mousereleased(x, y)
	for _, button in pairs(title.ui_clickable) do
		button.released()
		if pointIsInRect(x, y, button:getRect()) and title.clicked == button then
			button.action()
			break
		end
	end
	title.clicked = false
end

function title:mousemoved(x, y)
	if title.clicked then
		if not pointIsInRect(x, y, title.clicked:getRect()) then
			title.clicked.released()
			title.clicked = false
		end
	end
end

return title
