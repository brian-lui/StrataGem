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

local title = {name = "title"}

-- refer to game.lua for instructions for createButton and createImage
function title:createButton(params)
	return self:_createButton(title, params)
end

function title:createImage(params)
	return self:_createImage(title, params)
end

-- After the initial tween, we keep the icons here if returning to title screen
-- So we put it in init(), not enter() like in the other states
function title:init()
	local stage = self.stage
	self.timeStep, self.timeBucket = 1/60, 0
	title.ui = {
		clickable = {},
		static = {},
		fades = {},
		popup_clickable = {},
		popup_static = {},
	}
	self:_createSettingsMenu(title)

	title.createButton(self, {
		name = "vscpu",
		image = image.buttons_vscpu,
		image_pushed = image.buttons_vscpupush,
		duration = 60,
		end_x = stage.width * 0.35,
		start_y = stage.height * 1.2,
		end_y = stage.height * 0.8,
		start_transparency = 0,
		easing = "inQuart",
		action = function()
			self.statemanager:switch(require "gs_singleplayerselect")
		end,
	})
	title.createButton(self, {
		name = "netplay",
		image = image.buttons_netplay,
		image_pushed = image.buttons_netplaypush,
		duration = 60,
		end_x = stage.width * 0.65,
		start_y = stage.height * 1.2,
		end_y = stage.height * 0.8,
		start_transparency = 0,
		easing = "inQuart",
		action = function()
			self.statemanager:switch(require "gs_multiplayerselect")
		end,
	})
	title.createImage(self, {
		name = "logo",
		image = image.unclickables_titlelogo,
		duration = 45,
		end_x = stage.width * 0.5,
		start_y = 0,
		end_y = stage.height * 0.35,
		start_transparency = 0,
		easing = "linear",
		exit_func = function()
			if self.sound:getCurrentBGM() ~= "bgm_menu" then
				self.sound:newBGM("bgm_menu", true)
			end
		end,
	})
end

function title:enter()
	title.clicked = nil
	self.settings_menu_open = false
	if self.sound:getCurrentBGM() ~= "bgm_menu" then
		self.sound:stopBGM()
		title.ui.static.logo:change{
			duration = 45,
			exit_func = function()
				if self.sound:getCurrentBGM() ~= "bgm_menu" then
					self.sound:newBGM("bgm_menu", true)
				end
			end,
		}
	end
	title.current_background = common.instance(self.background.checkmate, self)

	title.createImage(self, {
		name = "fadein",
		container = title.ui.fades,
		image = image.unclickables_fadein,
		duration = 30,
		end_x = self.stage.width * 0.5,
		end_y = self.stage.height * 0.5,
		end_transparency = 0,
		easing = "linear",
		remove = true,
	})
end

function title:openSettingsMenu()
	self:_openSettingsMenu(title)
end

function title:closeSettingsMenu()
	self:_closeSettingsMenu(title)
end

function title:update(dt)
	title.current_background:update(dt)
	for _, tbl in pairs(title.ui) do
		for _, v in pairs(tbl) do v:update(dt) end
	end
end

function title:draw()
	local darkened = self:isScreenDark()
	title.current_background:draw{darkened = darkened}
	for _, v in pairs(title.ui.static) do v:draw{darkened = darkened} end
	for _, v in pairs(title.ui.clickable) do v:draw{darkened = darkened} end
	for _, v in pairs(title.ui.fades) do v:draw{darkened = darkened} end
	self:_drawSettingsMenu(title)
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
