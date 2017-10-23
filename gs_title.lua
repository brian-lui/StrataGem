local love = _G.love

local common = require "class.commons"
local image = require 'image'
local Pic = require 'pic'
local tween = require 'tween'

local title = {}

function title:init()
	self.timeStep, self.timeBucket = 1/60, 0
end

--[[ create a clickable object
	mandatory parameters: name, image, image_pushed, end_x, end_y
	optional parameters: duration, transparency, start_x, start_y, easing, exit
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
		container = self.ui_clickable,
		counter = "background_particle",
	})
	button:moveTo{duration = params.duration, x = params.end_x, y = params.end_y,
		transparency = params.end_transparency or 255,
		easing = params.easing or "linear", exit = params.exit}

	button.pushed = function()
		self.sound:newSFX("button")
		button:newImage(params.image_pushed)
	end
	button.released = function()
		button:newImage(params.image)
	end

	button.action = params.action
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
		container = self.ui_static,
		counter = "background_particle",
	})
	button:moveTo{duration = params.duration, x = params.end_x, y = params.end_y,
		transparency = params.transparency, easing = params.easing, exit = params.exit}
end

function title:enter()
	local stage = self.stage
	self.clicked = nil
	if self.sound:getCurrentBGM() ~= "bgm_menu" then self.sound:stopBGM() end
	self.current_background = common.instance(self.background.RabbitInASnowstorm, self)
	self.ui_clickable = {}
	self.ui_static = {}

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

function title:update(dt)
	self.current_background:update(dt)
	for _, v in pairs(self.ui_clickable) do v:update(dt) end
	for _, v in pairs(self.ui_static) do v:update(dt) end
end

function title:draw()
	self.current_background:draw()
	for _, v in pairs(self.ui_static) do v:draw() end
	for _, v in pairs(self.ui_clickable) do v:draw() end
end

local pointIsInRect = require "utilities".pointIsInRect
function title:mousepressed(x, y)
	for _, button in pairs(self.ui_clickable) do
		if pointIsInRect(x, y, button:getRect()) then
			self.clicked = button
			button.pushed()
			return
		end
	end
	self.clicked = false
end

function title:mousereleased(x, y)
	for _, button in pairs(self.ui_clickable) do
		button.released()
		if pointIsInRect(x, y, button:getRect()) and self.clicked == button then
			button.action()
			break
		end
	end
	self.clicked = false
end

function title:mousemoved(x, y)
	if self.clicked then
		if not pointIsInRect(x, y, self.clicked:getRect()) then
			self.clicked.released()
			self.clicked = false
		end
	end
end

return title
