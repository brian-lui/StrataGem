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
	self.gem_width = images.gems_red:getWidth()
	self.gem_height = images.gems_red:getHeight()
	self.x_mid = self.width / 2
	self.y_mid = self.height / 2
	self.super_click = {
		P1 = {0, 0, self.width * 0.2, self.height * 0.3}, -- rx, ry, rw, rh
		P2 = {self.width * 0.8, 0, self.width * 0.2, self.height * 0.3},
	}
	self.burst = {P1 = {}, P2 = {}}
	self.burst.P1.frame = {
		x = self.x_mid - (9.5 * self.gem_width),
		y = self.y_mid - 3 * self.gem_height,
	}
	self.burst.P2.frame = {
		x = self.x_mid + (9.5 * self.gem_width),
		y = self.y_mid - 3 * self.gem_height,
	}
	local burst_width = images.ui_burst_part_red:getWidth()

	for i = 1, 2 do
		self.burst.P1[i] = {
			x = self.burst.P1.frame.x + ((i - 1.5) * burst_width),
			y = self.burst.P1.frame.y,
			glow_x = self.burst.P1.frame.x + ((i * 0.5 - 1) * burst_width),
			glow_y = self.burst.P1.frame.y
		}
		self.burst.P2[i] = {
			x = self.burst.P2.frame.x + ((1.5 - i) * burst_width),
			y = self.burst.P2.frame.y,
			glow_x = self.burst.P2.frame.x + ((1 - i * 0.5) * burst_width),
			glow_y = self.burst.P2.frame.y
		}
	end

	self.super = {
		{
			x = self.x_mid - 9.5 * self.gem_width,
			y = self.y_mid - self.gem_height,
			word_y = self.y_mid - self.gem_height
		},
		{
			x = self.x_mid + 9.5 * self.gem_width,
			y = self.y_mid - self.gem_height,
			word_y = self.y_mid - self.gem_height
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
		P1 = {
			x = self.x_mid - (8.2 * self.gem_width),
			y = self.y_mid - (4.6 * self.gem_height),
		},
		P2 = {
			x = self.x_mid + (8.2 * self.gem_width),
			y = self.y_mid - (4.6 * self.gem_height),
		}
	}

	self.timer = {x = self.x_mid, y = self.height * 0.3}
	self.timertext = {x = self.x_mid, y = self.height * 0.28}

	self.basin = {x = self.x_mid, y = self.height * 0.646}
	self.settings_button = {
		gs_main = {x = self.x_mid, y = self.height * 0.957},
		title = {x = self.width * 0.92, y = self.height * 0.91},
		lobby = {x = self.width * 0.92, y = self.height * 0.91},
		charselect_netplay = {x = self.width * 0.92, y = self.height * 0.91},
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
