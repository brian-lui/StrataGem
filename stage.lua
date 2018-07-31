--[[
This module mainly defines the locations of the objects that will be shown
on-screen in the main gamestate.
--]]

local love = _G.love
local common = require "class.commons"
local images = require "images"

local stage = {}

function stage:init(game)
	local HALF_SUPER_WIDTH = 0.07 * game.inits.drawspace.width
	local HALF_SUPER_HEIGHT = 0.09 * game.inits.drawspace.height
	self.width = game.inits.drawspace.width
	self.height = game.inits.drawspace.height
	images.GEM_WIDTH = images.gems_red:getWidth()
	images.GEM_HEIGHT = images.gems_red:getHeight()
	self.x_mid = self.width / 2
	self.y_mid = self.height / 2
	self.burst = {{}, {}}
	self.burst[1].frame = {
		x = self.x_mid - (9.5 * images.GEM_WIDTH),
		y = self.y_mid - 3 * images.GEM_HEIGHT,
	}
	self.burst[2].frame = {
		x = self.x_mid + (9.5 * images.GEM_WIDTH),
		y = self.y_mid - 3 * images.GEM_HEIGHT,
	}
	local burst_width = images.ui_burst_part_red:getWidth()

	for i = 1, 2 do
		self.burst[1][i] = {
			x = self.burst[1].frame.x + ((i - 1.5) * burst_width),
			y = self.burst[1].frame.y,
			glow_x = self.burst[1].frame.x + ((i * 0.5 - 1) * burst_width),
			glow_y = self.burst[1].frame.y
		}
		self.burst[2][i] = {
			x = self.burst[2].frame.x + ((1.5 - i) * burst_width),
			y = self.burst[2].frame.y,
			glow_x = self.burst[2].frame.x + ((1 - i * 0.5) * burst_width),
			glow_y = self.burst[2].frame.y
		}
	end

	self.super = {
		{
			x = self.x_mid - 9.5 * images.GEM_WIDTH,
			y = self.y_mid - images.GEM_HEIGHT,
			word_y = self.y_mid - images.GEM_HEIGHT
		},
		{
			x = self.x_mid + 9.5 * images.GEM_WIDTH,
			y = self.y_mid - images.GEM_HEIGHT,
			word_y = self.y_mid - images.GEM_HEIGHT
		},
	}
	self.super[1].rect = {
		self.super[1].x - HALF_SUPER_WIDTH,
		self.super[1].y - HALF_SUPER_HEIGHT,
		2 * HALF_SUPER_WIDTH,
		2 * HALF_SUPER_HEIGHT
	}

	self.super[2].rect = {
		self.super[2].x - HALF_SUPER_WIDTH,
		self.super[2].y - HALF_SUPER_HEIGHT,
		2 * HALF_SUPER_WIDTH,
		2 * HALF_SUPER_HEIGHT
	}

	self.character = {
		{
			x = self.x_mid - (8.2 * images.GEM_WIDTH),
			y = self.y_mid - (4.6 * images.GEM_HEIGHT),
		},
		{
			x = self.x_mid + (8.2 * images.GEM_WIDTH),
			y = self.y_mid - (4.6 * images.GEM_HEIGHT),
		},
	}

	self.timer = {x = self.x_mid, y = self.height * 0.3}
	self.timertext = {x = self.x_mid, y = self.height * 0.28}

	self.basin = {x = self.x_mid, y = self.height * 0.658}
	self.settings_button = {
		gs_main = {x = self.x_mid, y = self.height * 0.957},
		Title = {x = self.width * 0.92, y = self.height * 0.91},
		Lobby = {x = self.width * 0.92, y = self.height * 0.91}, -- now unused
	}
	self.settings_locations = {
		frame = {x = self.width * 0.5, y = self.height * 0.5},
		pause_text = {x = self.width * 0.5, y = self.height * 0.4},
		quit_button = {x = self.width * 0.43, y = self.height * 0.67},
		confirm_quit_text = {x = self.width * 0.5, y = self.height * 0.32},
		close_menu_button = {x = self.width * 0.63, y = self.height * 0.67},
		confirm_quit_button = {x = self.width * 0.5, y = self.height * 0.5},
		cancel_quit_button = {x = self.width * 0.5, y = self.height * 0.65},
	}
end

function stage:isOnLeft()
	return love.mouse.getX() < self.x_mid
end

return common.class("Stage", stage)
