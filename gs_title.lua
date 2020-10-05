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
		start_x = stage.width * -0.2,
		end_x = stage.width * 0.5,
		end_y = stage.height * 0.55,
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
		start_x = stage.width * -0.2,
		end_x = stage.width * 0.5,
		end_y = stage.height * 0.725,
		start_transparency = 0,
		easing = "inQuart",
		action = function()
			self:switchState("gs_multiplayerselect")
		end,
	})
	Title.createButton(self, {
		name = "tutorial",
		image = images.buttons_tutorial,
		image_pushed = images.buttons_tutorialpush,
		duration = 60,
		start_x = stage.width * -0.2,
		end_x = stage.width * 0.5,
		end_y = stage.height * 0.9,
		start_transparency = 0,
		easing = "inQuart",
		action = function()
			self:switchState("gs_tutorial")
		end,
	})
	Title.createImage(self, {
		name = "logo",
		image = images.unclickables_titlelogo,
		duration = 30,
		end_x = stage.width * 0.5,
		start_y = 0,
		end_y = stage.height * 0.25,
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

-- add custom things to these three functions
function Title:_pressed(x, y)
	self:_controllerPressed(x, y, Title)
end

function Title:_released(x, y)
	self:_controllerReleased(x, y, Title)
end

function Title:_moved(x, y)
	self:_controllerMoved(x, y, Title)
end

function Title:mousepressed(x, y) Title._pressed(self, x, y) end
function Title:touchpressed(_, x, y) Title._pressed(self, x, y) end

function Title:mousereleased(x, y) Title._released(self, x, y) end
function Title:touchreleased(_, x, y) Title._released(self, x, y) end

function Title:mousemoved(x, y) Title._moved(self, x, y) end
function Title:touchmoved(_, x, y) Title._moved(self, x, y) end

return Title
