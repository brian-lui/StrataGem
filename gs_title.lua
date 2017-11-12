--[[
	Note to coders and code readers!
	You can't call title.createButton by doing title:createButton(...)
	That will call it by passing in an instance of title, which doesn't work (?)
	You have to call it with title.createButton(self, ...)
	That passes in an instance of self, which works (???)
	Look I didn't code this I just know how to use it, ok
--]]

local common = require "class.commons"
local image = require 'image'
local Pic = require 'pic'
local tween = require 'tween'

local title = {}

-- refer to game.lua for instructions for createButton and createImage
function title:createButton(params)
	return self:_createButton(params, title)
end

function title:createImage(params)
	return self:_createImage(params, title)
end

-- After the initial tween, we keep the icons here if returning to title screen
-- So we put it in init(), not enter() like in the other states
function title:init()
	local stage = self.stage	
	self.timeStep, self.timeBucket = 1/60, 0
	title.ui = {clickable = {}, static = {}, popup_clickable = {}, popup_static = {}}

	title.createButton(self, {
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
	title.createButton(self, {
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
	title.createImage(self, {
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

	title.createButton(self, {
		name = "settings",
		image = image.button.settings,
		image_pushed = image.button.settingspush,
		end_x = stage.width - image.button.settings:getWidth() * 0.5,
		end_y = stage.height - image.button.settings:getHeight() * 0.5,
		action = function()
			if not title.settings_menu_open then title.openSettings(self) end
		end,
	})

	title.createImage(self, {
		name = "quitgameconfirm",
		container = title.ui.popup_static,
		image = image.unclickable.main_quitconfirm,
		end_x = stage.width * 0.5,
		end_y = stage.height * 0.4,
		end_transparency = 0,
	})

	title.createImage(self, {
		name = "quitgameframe",
		container = title.ui.popup_static,
		image = image.unclickable.main_quitframe,
		end_x = stage.width * 0.5,
		end_y = stage.height * 0.5,
		end_transparency = 0,
	})

	title.createButton(self, {
		name = "quitgameyes",
		container = title.ui.popup_clickable,
		image = image.button.quitgameyes,
		image_pushed = image.button.quitgameyespush,
		end_x = -stage.width,
		end_y = -stage.height,
		end_transparency = 0,
		action = function()
			if title.settings_menu_open then love.event.quit() end
		end,
	})

	title.createButton(self, {
		name = "quitgameno",
		container = title.ui.popup_clickable,
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

	title.ui.popup_clickable.quitgameyes:change{x = stage.width * 0.45, y = stage.height * 0.6}
	title.ui.popup_clickable.quitgameyes:change{duration = 15, transparency = 255}
	title.ui.popup_clickable.quitgameno:change{x = stage.width * 0.55, y = stage.height * 0.6}
	title.ui.popup_clickable.quitgameno:change{duration = 15, transparency = 255}
	title.ui.popup_static.quitgameconfirm:change{duration = 15, transparency = 255}
	title.ui.popup_static.quitgameframe:change{duration = 15, transparency = 255}
end

function title:openSettingsCancel()
	local stage = self.stage
	title.settings_menu_open = false

	title.ui.popup_clickable.quitgameyes:change{duration = 10, transparency = 0}
	title.ui.popup_clickable.quitgameyes:change{x = -stage.width, y = -stage.height}
	title.ui.popup_clickable.quitgameno:change{duration = 10, transparency = 0}
	title.ui.popup_clickable.quitgameno:change{x = -stage.width, y = -stage.height}
	title.ui.popup_static.quitgameconfirm:change{duration = 10, transparency = 0}
	title.ui.popup_static.quitgameframe:change{duration = 10, transparency = 0}
end

function title:update(dt)
	title.current_background:update(dt)
	for _, tbl in pairs(title.ui) do
		for _, v in pairs(tbl) do v:update(dt) end
	end
end

function title:draw()
	title.current_background:draw()
	for _, v in pairs(title.ui.static) do v:draw() end
	for _, v in pairs(title.ui.clickable) do v:draw() end
	title.ui.popup_static.quitgameframe:draw()
	title.ui.popup_static.quitgameconfirm:draw()
	for _, v in pairs(title.ui.popup_clickable) do v:draw() end
end

function title:mousepressed(x, y)
	self:_mousepressed(x, y, title)
end

function title:mousereleased(x, y)
	self:_mousereleased(x, y, title)
end

function title:mousemoved(x, y)
	self:_mousemoved(x, y, title)
end

return title
