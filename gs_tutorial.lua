--[[
	This is the gamestate module for the Tutorial screen.

	Note to coders and code readers!
	You can't call Tutorial.createButton by doing Tutorial:createButton(...)
	That will call it by passing in an instance of Tutorial, which doesn't work
	You have to call it with Tutorial.createButton(self, ...)
	That passes in an instance of self, which works (???)
	Look I didn't code this I just know how to use it, ok
--]]

local common = require "class.commons"
local images = require "images"

local Tutorial = {name = "Tutorial"}

-- refer to game.lua for instructions for createButton and createImage
function Tutorial:createButton(params)
	return self:_createButton(Tutorial, params)
end

function Tutorial:createImage(params)
	return self:_createImage(Tutorial, params)
end

function Tutorial:init()
	local stage = self.stage
	Tutorial.ui = {
		clickable = {},
		static = {},
		popup_clickable = {},
		popup_static = {},
	}
	self:_createSettingsMenu(Tutorial)

	Tutorial.createButton(self, {
		name = "vscpu",
		image = images.buttons_vscpu,
		image_pushed = images.buttons_vscpupush,
		duration = 60,
		end_x = stage.width * 0.35,
		start_y = stage.height * 1.2,
		end_y = stage.height * 0.8,
		start_transparency = 0,
		easing = "inQuart",
		action = function()
			self:switchState("gs_singleplayerselect")
		end,
	})
	Tutorial.createButton(self, {
		name = "netplay",
		image = images.buttons_netplay,
		image_pushed = images.buttons_netplaypush,
		duration = 60,
		end_x = stage.width * 0.65,
		start_y = stage.height * 1.2,
		end_y = stage.height * 0.8,
		start_transparency = 0,
		easing = "inQuart",
		action = function()
			self:switchState("gs_multiplayerselect")
		end,
	})
	Tutorial.createImage(self, {
		name = "logo",
		image = images.unclickables_Tutoriallogo,
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

function Tutorial:enter()
	Tutorial.clicked = nil
	self.uielements:clearScreenUIColor()
	self.settings_menu_open = false
	if self.sound:getCurrentBGM() ~= "bgm_menu" then
		self.sound:stopBGM()
		Tutorial.ui.static.logo:change{
			duration = 45,
			exit_func = function()
				if self.sound:getCurrentBGM() ~= "bgm_menu" then
					self.sound:newBGM("bgm_menu", true)
				end
			end,
		}
	end
	Tutorial.current_background = common.instance(self.background.checkmate, self)

	Tutorial.createImage(self, {
		name = "fadein",
		container = self.global_ui.fades,
		image = images.unclickables_fadein,
		duration = 30,
		end_x = self.stage.width * 0.5,
		end_y = self.stage.height * 0.5,
		end_transparency = 0,
		easing = "linear",
		remove = true,
	})
end

function Tutorial:openSettingsMenu()
	self:_openSettingsMenu(Tutorial)
end

function Tutorial:closeSettingsMenu()
	self:_closeSettingsMenu(Tutorial)
end

function Tutorial:update(dt)
	Tutorial.current_background:update(dt)
	for _, tbl in pairs(Tutorial.ui) do
		for _, v in pairs(tbl) do v:update(dt) end
	end
end

function Tutorial:draw()
	local darkened = self:isScreenDark()
	Tutorial.current_background:draw{darkened = darkened}
	for _, v in pairs(Tutorial.ui.static) do v:draw{darkened = darkened} end
	for _, v in pairs(Tutorial.ui.clickable) do v:draw{darkened = darkened} end
	self:_drawSettingsMenu(Tutorial)
	self:_drawGlobals()
end

function Tutorial:mousepressed(x, y)
	self:_mousepressed(x, y, Tutorial)
end

function Tutorial:mousereleased(x, y)
	self:_mousereleased(x, y, Tutorial)
end

function Tutorial:mousemoved(x, y)
	self:_mousemoved(x, y, Tutorial)
end

return Tutorial
