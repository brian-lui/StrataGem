local love = _G.love
require 'utilities'
require 'inits'
local common = require "class.commons"
local image = require 'image'

local stage = {}

local HALF_SUPER_WIDTH = 0.07 * canvas.width
local HALF_SUPER_HEIGHT = 0.09 * canvas.height

function stage:init(game)
	self.width = canvas.width
	self.height = canvas.height
	self.gem_width = image.red_gem:getWidth()
	self.gem_height = image.red_gem:getHeight()
	self.x_mid = self.width / 2
	self.y_mid = self.height / 2
	self.super_click = {
		P1 = {0, 0, self.width * 0.2, self.height * 0.3}, -- rx, ry, rw, rh
		P2 = {self.width * 0.8, 0, self.width * 0.2, self.height * 0.3},
	}
	self.burst = {P1 = {}, P2 = {}}
	self.burst.P1.frame = {x = self.x_mid - (9.5 * self.gem_width), y = self.y_mid - 3 * self.gem_height}
	self.burst.P2.frame = {x = self.x_mid + (9.5 * self.gem_width), y = self.y_mid - 3 * self.gem_height}
	local burst_width = image.UI.burst.red_partial:getWidth()

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
		P1 = {
			x = self.x_mid - 9.5 * self.gem_width,
			y = self.y_mid - self.gem_height,
			word_y = self.y_mid + 0.5 * self.gem_height
		},
		P2 = {
			x = self.x_mid + 9.5 * self.gem_width,
			y = self.y_mid - self.gem_height,
			word_y = self.y_mid + 0.5 * self.gem_height
		}
	}
	self.super.P1.rect = {
		self.super.P1.x - HALF_SUPER_WIDTH,
		self.super.P1.y - HALF_SUPER_HEIGHT,
		2 * HALF_SUPER_WIDTH,
		2 * HALF_SUPER_HEIGHT
	}

	self.super.P2.rect = {
		self.super.P2.x - HALF_SUPER_WIDTH,
		self.super.P2.y - HALF_SUPER_HEIGHT,
		2 * HALF_SUPER_WIDTH,
		2 * HALF_SUPER_HEIGHT
	}

	self.character = {
		P1 = {x = self.x_mid - (8.2 * self.gem_width), y = self.y_mid - (4.6 * self.gem_height)},
		P2 = {x = self.x_mid + (8.2 * self.gem_width), y = self.y_mid - (4.6 * self.gem_height)}
	}

	self.timer = {x = self.x_mid, y = self.height * 0.3}
	self.timertext = {x = self.x_mid, y = self.height * 0.28}

	self.tub = {x = self.x_mid, y = self.height * 0.646}
	self.settings_button = {
		gs_main = {x = self.x_mid, y = self.height * 0.957},
		title = {x = self.width * 0.92, y = self.height * 0.92},
		charselect = {x = self.width * 0.05, y = self.height * 0.08},
		lobby = {x = self.width * 0.05, y = self.height * 0.08},
	}
end

function stage:isOnLeft()
	return love.mouse.getX() < self.x_mid -- maybe we need to adjust this for stage resizing too haha
end

return common.class("Stage", stage)
