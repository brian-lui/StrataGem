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
	optional parameters: duration, start_transparency, end_transparency, container,
		start_x, start_y, easing, exit, pushed, pushed_sfx, released, released_sfx
--]]
function title:_createButton(params)
	self:_createButton(params, title)
end

--[[ creates an object that can be tweened but not clicked
	mandatory parameters: name, image, end_x, end_y
	optional parameters: duration, start_transparency, end_transparency,
		container, start_x, start_y, easing, exit
--]]
function title:_createImage(params)
	self:_createImage(params, title)
end

-- After the initial tween, we keep the icons here if returning to title screen
-- So we put it in init(), not enter() like in the other states
function title:init()
	local stage = self.stage	
	self.timeStep, self.timeBucket = 1/60, 0
	title.ui_clickable = {}
	title.ui_static = {}
	title.ui_overlay_clickable = {}
	title.ui_overlay_static = {}

	title._createButton(self, {
		name = "vscpu",
		image = image.button.vscpu,
		image_pushed = image.button.vscpupush,
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
		name = "netplay",
		image = image.button.netplay,
		image_pushed = image.button.netplaypush,
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
		image = image.unclickable.title_logo,
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

	title._createButton(self, {
		name = "settings",
		image = image.button.settings,
		image_pushed = image.button.settingspush,
		end_x = stage.width - image.button.settings:getWidth() * 0.5,
		end_y = stage.height - image.button.settings:getHeight() * 0.5,
		action = function()
			if not title.settings_menu_open then title.openSettings(self) end
		end,
	})

	title._createImage(self, {
		name = "quitgameconfirm",
		container = title.ui_overlay_static,
		image = image.unclickable.main_quitconfirm,
		end_x = stage.width * 0.5,
		end_y = stage.height * 0.4,
		end_transparency = 0,
	})

	title._createImage(self, {
		name = "quitgameframe",
		container = title.ui_overlay_static,
		image = image.unclickable.main_quitframe,
		end_x = stage.width * 0.5,
		end_y = stage.height * 0.5,
		end_transparency = 0,
	})

	title._createButton(self, {
		name = "quitgameyes",
		container = title.ui_overlay_clickable,
		image = image.button.quitgameyes,
		image_pushed = image.button.quitgameyespush,
		end_x = -stage.width,
		end_y = -stage.height,
		end_transparency = 0,
		action = function()
			if title.settings_menu_open then love.event.quit() end
		end,
	})

	title._createButton(self, {
		name = "quitgameno",
		container = title.ui_overlay_clickable,
		image = image.button.quitgameno,
		image_pushed = image.button.quitgamenopush,
		end_x = -stage.width,
		end_y = -stage.height,
		end_transparency = 0,
		action = function()
			if title.settings_menu_open then title.openSettingsCancel(self) end
		end,
	})

end

function title:enter()
	title.clicked = nil
	title.settings_menu_open = false
	if self.sound:getCurrentBGM() ~= "bgm_menu" then self.sound:stopBGM() end
	title.current_background = common.instance(self.background.rabbitsnowstorm, self)
end

function title:openSettings()
	local stage = self.stage
	title.settings_menu_open = true

	title.ui_overlay_clickable.quitgameyes:change{x = stage.width * 0.45, y = stage.height * 0.6}
	title.ui_overlay_clickable.quitgameyes:change{duration = 15, transparency = 255}
	title.ui_overlay_clickable.quitgameno:change{x = stage.width * 0.55, y = stage.height * 0.6}
	title.ui_overlay_clickable.quitgameno:change{duration = 15, transparency = 255}
	title.ui_overlay_static.quitgameconfirm:change{duration = 15, transparency = 255}
	title.ui_overlay_static.quitgameframe:change{duration = 15, transparency = 255}
end

function title:openSettingsCancel()
	local stage = self.stage
	title.settings_menu_open = false

	title.ui_overlay_clickable.quitgameyes:change{duration = 10, transparency = 0}
	title.ui_overlay_clickable.quitgameyes:change{x = -stage.width, y = -stage.height}
	title.ui_overlay_clickable.quitgameno:change{duration = 10, transparency = 0}
	title.ui_overlay_clickable.quitgameno:change{x = -stage.width, y = -stage.height}
	title.ui_overlay_static.quitgameconfirm:change{duration = 10, transparency = 0}
	title.ui_overlay_static.quitgameframe:change{duration = 10, transparency = 0}
end

function title:update(dt)
	title.current_background:update(dt)
	for _, v in pairs(title.ui_static) do v:update(dt) end
	for _, v in pairs(title.ui_clickable) do v:update(dt) end
	for _, v in pairs(title.ui_overlay_static) do v:update(dt) end
	for _, v in pairs(title.ui_overlay_clickable) do v:update(dt) end
end

function title:draw()
	title.current_background:draw()
	for _, v in pairs(title.ui_static) do v:draw() end
	for _, v in pairs(title.ui_clickable) do v:draw() end
	title.ui_overlay_static.quitgameframe:draw()
	title.ui_overlay_static.quitgameconfirm:draw()
	for _, v in pairs(title.ui_overlay_clickable) do v:draw() end
end

local pointIsInRect = require "utilities".pointIsInRect
function title:mousepressed(x, y)
	if title.settings_menu_open then
		for _, button in pairs(title.ui_overlay_clickable) do
			if pointIsInRect(x, y, button:getRect()) then
				title.clicked = button
				button.pushed()
				return
			end
		end
	else
		for _, button in pairs(title.ui_clickable) do
			if pointIsInRect(x, y, button:getRect()) then
				title.clicked = button
				button.pushed()
				return
			end
		end
	end
	title.clicked = false
end

function title:mousereleased(x, y)
	if title.settings_menu_open then
		for _, button in pairs(title.ui_overlay_clickable) do
			button.released()
			if pointIsInRect(x, y, button:getRect()) and title.clicked == button then
				button.action()
				break
			end
		end
	else
		for _, button in pairs(title.ui_clickable) do
			button.released()
			if pointIsInRect(x, y, button:getRect()) and title.clicked == button then
				button.action()
				break
			end
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
