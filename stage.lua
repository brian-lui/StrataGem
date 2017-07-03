require 'inits'
require 'utilities'
local image = require 'image'
local Grid = require "grid"

local stage = {}
stage.width = 1024
stage.height = 768
stage.gem_width = image.red_gem:getWidth()
stage.gem_height = image.red_gem:getHeight()
stage.x_mid = stage.width / 2
stage.y_mid = stage.height / 2
stage.grid = Grid(stage, game)

-- this describes the shape of the curve for the hands.
stage.getx = {
	P1 = function(y)
		if y <= stage.height * 0.6 then
			return stage.x_mid - (5.5 * stage.gem_width)
		else
			local start_x = stage.x_mid + (5.5 * stage.gem_width) * -1
			local additional = (((y - stage.height * 0.6) / stage.height) ^ 2) * stage.height
			return start_x + additional * -1
		end
	end,
	P2 = function(y)
		if y <= stage.height * 0.6 then
			return stage.x_mid + (5.5 * stage.gem_width)
		else
			local start_x = stage.x_mid + (5.5 * stage.gem_width) * 1
			local additional = (((y - stage.height * 0.6) / stage.height) ^ 2) * stage.height
			return start_x + additional * 1
		end
	end,
}

stage.super_click = {
	P1 = {0, 0, stage.width * 0.2, stage.height * 0.3}, -- rx, ry, rw, rh
	P2 = {stage.width * 0.8, 0, stage.width * 0.2, stage.height * 0.3},
}

stage.super = {[p1] = {}, [p2] = {}}
stage.super[p1].frame = {x = stage.x_mid - (8.5 * stage.gem_width), y = stage.y_mid - (3 * stage.gem_height)}
stage.super[p2].frame = {x = stage.x_mid + (8.5 * stage.gem_width), y = stage.y_mid - (3 * stage.gem_height)}
local super_width = image.UI.super.red_partial:getWidth()

for i = 1, 4 do
	stage.super[p1][i] = {
		x = stage.super[p1].frame.x + ((i - 2.5) * super_width),
		y = stage.super[p1].frame.y,
		glow_x = stage.super[p1].frame.x + ((i * 0.5 - 2) * super_width),
		glow_y = stage.super[p1].frame.y,
	}
	stage.super[p2][i] = {
		x = stage.super[p2].frame.x + ((2.5 - i) * super_width),
		y = stage.super[p2].frame.y,
		glow_x = stage.super[p2].frame.x + ((2 - i * 0.5) * super_width),
		glow_y = stage.super[p2].frame.y,
	}
end

stage.character = {
	P1 = {x = stage.x_mid - (8 * stage.gem_width), y = stage.y_mid - (5.5 * stage.gem_height)},
	P2 = {x = stage.x_mid + (8 * stage.gem_width), y = stage.y_mid - (5.5 * stage.gem_height)}
}

stage.timer = {x = stage.x_mid, y = stage.height * 0.1}

return stage
