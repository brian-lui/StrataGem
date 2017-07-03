require 'inits'
require 'utilities'
local class = require "middleclass"
local image = require 'image'
local Grid = require "grid"

local stage = class("Stage")

function stage:initialize()
	self.width = 1024
	self.height = 768
	self.gem_width = image.red_gem:getWidth()
	self.gem_height = image.red_gem:getHeight()
	self.x_mid = self.width / 2
	self.y_mid = self.height / 2
	self.grid = Grid(self, game)

	-- this describes the shape of the curve for the hands.
	self.getx = {
		P1 = function(y)
			if y <= self.height * 0.6 then
				return self.x_mid - (5.5 * self.gem_width)
			else
				local start_x = self.x_mid + (5.5 * self.gem_width) * -1
				local additional = (((y - self.height * 0.6) / self.height) ^ 2) * self.height
				return start_x + additional * -1
			end
		end,
		P2 = function(y)
			if y <= self.height * 0.6 then
				return self.x_mid + (5.5 * self.gem_width)
			else
				local start_x = self.x_mid + (5.5 * self.gem_width) * 1
				local additional = (((y - self.height * 0.6) / self.height) ^ 2) * self.height
				return start_x + additional * 1
			end
		end,
	}

	self.super_click = {
		P1 = {0, 0, self.width * 0.2, self.height * 0.3}, -- rx, ry, rw, rh
		P2 = {self.width * 0.8, 0, self.width * 0.2, self.height * 0.3},
	}

	self.super = {[p1] = {}, [p2] = {}}
	self.super[p1].frame = {x = self.x_mid - (8.5 * self.gem_width), y = self.y_mid - (3 * self.gem_height)}
	self.super[p2].frame = {x = self.x_mid + (8.5 * self.gem_width), y = self.y_mid - (3 * self.gem_height)}
	local super_width = image.UI.super.red_partial:getWidth()

	for i = 1, 4 do
		self.super[p1][i] = {
			x = self.super[p1].frame.x + ((i - 2.5) * super_width),
			y = self.super[p1].frame.y,
			glow_x = self.super[p1].frame.x + ((i * 0.5 - 2) * super_width),
			glow_y = self.super[p1].frame.y,
		}
		self.super[p2][i] = {
			x = self.super[p2].frame.x + ((2.5 - i) * super_width),
			y = self.super[p2].frame.y,
			glow_x = self.super[p2].frame.x + ((2 - i * 0.5) * super_width),
			glow_y = self.super[p2].frame.y,
		}
	end

	self.character = {
		P1 = {x = self.x_mid - (8 * self.gem_width), y = self.y_mid - (5.5 * self.gem_height)},
		P2 = {x = self.x_mid + (8 * self.gem_width), y = self.y_mid - (5.5 * self.gem_height)}
	}

	self.timer = {x = self.x_mid, y = self.height * 0.1}
end

return stage
