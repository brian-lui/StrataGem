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
local Pic = require "pic"

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
		pages = {},
	}

	self:_createSettingsMenu(Tutorial)

	Tutorial.ANIMATION_CYCLE_TIME = 360

	Tutorial.animationReset = function()
		Tutorial.current_animation_time = 0
		Tutorial.moving_images = {}
		if Tutorial.actionsOnPageEnter[Tutorial.current_page] then
			Tutorial.actionsOnPageEnter[Tutorial.current_page](self)
		end
	end

	Tutorial.total_pages = 6
	for i = 1, Tutorial.total_pages do
		Tutorial.ui.pages[i] = Tutorial.createImage(self, {
			name = "tutorial" .. i,
			duration = 0,
			image = images["tutorial_page" .. i],
			end_x = stage.width * 0.5,
			end_y = stage.height * 0.5,
			end_transparency = 0,
		})
	end

	-- animations for tutorial pages
	Tutorial.moving_images = {}
	Tutorial.actionsOnPageEnter = {}

	Tutorial.actionsOnPageEnter[3] = function()
		Tutorial.moving_images.red_gem = Pic:create{
			game = self,
			x = stage.width * 0.4,
			y = stage.width * 0.3,
			image = images.gems_red,
		}
		Tutorial.moving_images.green_gem = Pic:create{
			game = self,
			x = stage.width * 0.4 + images.GEM_WIDTH,
			y = stage.width * 0.3,
			image = images.gems_green,
		}

		Tutorial.moving_images.red_gem:wait(40)
		Tutorial.moving_images.green_gem:wait(40)

		Tutorial.moving_images.red_gem:change{
			duration = 60,
			x = stage.width * 0.5,
			y = stage.width * 0.1,
		}
		Tutorial.moving_images.green_gem:change{
			duration = 60,
			x = stage.width * 0.5 + images.GEM_WIDTH,
			y = stage.width * 0.1,
		}

		Tutorial.moving_images.red_gem:wait(40)
		Tutorial.moving_images.green_gem:wait(40)

		Tutorial.moving_images.red_gem:change{
			duration = 80,
			y = stage.width * 0.3,
		}
		Tutorial.moving_images.green_gem:change{
			duration = 80,
			y = stage.width * 0.3,
		}

		Tutorial.moving_images.green_gem:change{
			duration = 15,
			y = stage.width * 0.3 + images.GEM_HEIGHT,
		}

	end

	Tutorial.createButton(self, {
		name = "left_button",
		image = images.buttons_tutorialleft,
		image_pushed = images.buttons_tutorialleftpush,
		end_x = stage.tutorial_locations.left_button.x,
		end_y = stage.tutorial_locations.left_button.y,
		pushed_sfx = "buttonback",
		easing = "inQuart",
		action = function()
			if Tutorial.current_page == 1 then return end

			local previous_page = Tutorial.current_page
			Tutorial.current_page = Tutorial.current_page - 1

			Tutorial.ui.clickable.right_button:change{
				x = stage.tutorial_locations.right_button.x
			}

			if Tutorial.current_page == 1 then
				Tutorial.ui.clickable.left_button:change{x = stage.width * -1}
			end

			Tutorial.ui.pages[previous_page]:change{transparency = 0}
			Tutorial.ui.pages[Tutorial.current_page]:change{transparency = 1}
			Tutorial.animationReset()
		end,
	})

	Tutorial.createButton(self, {
		name = "right_button",
		image = images.buttons_tutorialright,
		image_pushed = images.buttons_tutorialrightpush,
		end_x = stage.tutorial_locations.right_button.x,
		end_y = stage.tutorial_locations.right_button.y,
		pushed_sfx = "buttonback",
		action = function()
			if Tutorial.current_page == Tutorial.total_pages then return end

			local previous_page = Tutorial.current_page
			Tutorial.current_page = Tutorial.current_page + 1

			Tutorial.ui.clickable.left_button:change{
				x = stage.tutorial_locations.left_button.x
			}

			if Tutorial.current_page == Tutorial.total_pages then
				Tutorial.ui.clickable.right_button:change{x = stage.width * -1}
			end

			Tutorial.ui.pages[previous_page]:change{transparency = 0}
			Tutorial.ui.pages[Tutorial.current_page]:change{transparency = 1}
			Tutorial.animationReset()
		end,
	})

	-- back button
	Tutorial.createButton(self, {
		name = "back",
		image = images.buttons_back,
		image_pushed = images.buttons_backpush,
		end_x = stage.width * 0.05,
		end_y = stage.height * 0.09,
		pushed_sfx = "buttonback",
		action = function()
			self:switchState("gs_title")
		end,
	})

	Tutorial.current_page = 1
	Tutorial.ui.pages[1]:change{transparency = 1}
	Tutorial.ui.clickable.left_button:change{x = stage.width * -1}
end

function Tutorial:enter()
	Tutorial.clicked = nil
	Tutorial.animationReset()

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

	for _, v in pairs(Tutorial.moving_images) do v:update(dt) end

	Tutorial.current_animation_time = Tutorial.current_animation_time + 1
	if Tutorial.current_animation_time >= Tutorial.ANIMATION_CYCLE_TIME then
		Tutorial.animationReset()
	end
end

function Tutorial:draw()
	local darkened = self:isScreenDark()
	Tutorial.current_background:draw{darkened = darkened}
	for _, v in pairs(Tutorial.ui.static) do v:draw{darkened = darkened} end
	for _, v in pairs(Tutorial.ui.clickable) do v:draw{darkened = darkened} end
	for _, v in pairs(Tutorial.moving_images) do v:draw{darkened = darkened} end
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
