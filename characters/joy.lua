local love = _G.love
local common = require "class.commons"
local Character = require "character"
local image = require 'image'

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
	word = image.ui_super_text_red,
	empty = image.ui_super_empty_red,
	full = image.ui_super_full_red,
	glow = image.ui_super_glow_red,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Joy.burst_images = {
	partial = image.ui_burst_part_red,
	full = image.ui_burst_full_red,
	glow = {image.ui_burst_partglow_red, image.ui_burst_fullglow_red}
}

return common.class("Joy", Joy, Character)
