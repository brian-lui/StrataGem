--[[
	This is the gamestate module for the Title screen.

	Note to coders and code readers!
	You can't call Title.createButton by doing Title:createButton(...)
	That will call it by passing in an instance of Title, which doesn't work
	You have to call it with Title.createButton(self, ...)
	That passes in an instance of self, which works (???)
	Look I didn't code this I just know how to use it, ok
--]]

local common = require "class.commons"
local images = require "images"

local Title = {name = "Title"}

-- refer to game.lua for instructions for createButton and createImage
function Title:createButton(params)
	return self:_createButton(Title, params)
end

function Title:createImage(params)
	return self:_createImage(Title, params)
end

-- After the initial tween, we keep the icons here if returning to Title screen
-- So we put it in init(), not enter() like in the other states
function Title:init()
	local stage = self.stage
	Title.ui = {
		clickable = {},
		static = {},
		popup_clickable = {},
		popup_static = {},
	}
	self:_createSettingsMenu(Title)

	Title.createButton(self, {
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
	Title.createButton(self, {
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
	Title.createImage(self, {
		name = "logo",
		image = images.unclickables_titlelogo,
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

function Title:enter()
	Title.clicked = nil
	self.uielements:clearScreenUIColor()
	self.settings_menu_open = false
	if self.sound:getCurrentBGM() ~= "bgm_menu" then
		self.sound:stopBGM()
		Title.ui.static.logo:change{
			duration = 45,
			exit_func = function()
				if self.sound:getCurrentBGM() ~= "bgm_menu" then
					self.sound:newBGM("bgm_menu", true)
				end
			end,
		}
	end
	Title.current_background = common.instance(self.background.checkmate, self)

	Title.createImage(self, {
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

function Title:openSettingsMenu()
	self:_openSettingsMenu(Title)
end

function Title:closeSettingsMenu()
	self:_closeSettingsMenu(Title)
end

function Title:update(dt)
	Title.current_background:update(dt)
	for _, tbl in pairs(Title.ui) do
		for _, v in pairs(tbl) do v:update(dt) end
	end
end

function Title:draw()
	local darkened = self:isScreenDark()
	Title.current_background:draw{darkened = darkened}
	for _, v in pairs(Title.ui.static) do v:draw{darkened = darkened} end
	for _, v in pairs(Title.ui.clickable) do v:draw{darkened = darkened} end
	self:_drawSettingsMenu(Title)
	self:_drawGlobals()
end

function Title:mousepressed(x, y)
	self:_mousepressed(x, y, Title)
end

function Title:mousereleased(x, y)
	self:_mousereleased(x, y, Title)
end

function Title:mousemoved(x, y)
	self:_mousemoved(x, y, Title)
end

return Title
