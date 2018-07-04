local love = _G.love
local common = require "class.commons"
local Character = require "character"
local images = require "images"

local Joy = {}

Joy.large_image = love.graphics.newImage('images/portraits/joy.png')
Joy.small_image = love.graphics.newImage('images/portraits/joysmall.png')
Joy.character_id = "Joy"
Joy.meter_gain = {
	red = 8,
	blue = 4,
	green = 4,
	yellow = 4,
	none = 4,
	wild = 4,
}
Joy.super_images = {
	word = images.ui_super_text_red,
	empty = images.ui_super_empty_red,
	full = images.ui_super_full_red,
	glow = images.ui_super_glow_red,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Joy.burst_images = {
	partial = images.ui_burst_part_red,
	full = images.ui_burst_full_red,
	glow = {images.ui_burst_partglow_red, images.ui_burst_fullglow_red}
}

Joy.sounds = {
}

function Joy:init(...)
	Character.init(self, ...)
end

return common.class("Joy", Joy, Character)
