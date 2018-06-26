local love = _G.love
local common = require "class.commons"
local Character = require "character"
local images = require "images"

local Ivy = {}

Ivy.large_image = love.graphics.newImage('images/portraits/ivy.png')
Ivy.small_image = love.graphics.newImage('images/portraits/ivysmall.png')
Ivy.character_id = "Ivy"
Ivy.meter_gain = {
	red = 4,
	blue = 4,
	green = 8,
	yellow = 4,
	none = 4,
	wild = 4,
}

Ivy.super_images = {
	word = images.ui_super_text_green,
	empty = images.ui_super_empty_green,
	full = images.ui_super_full_green,
	glow = images.ui_super_glow_green,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Ivy.burst_images = {
	partial = images.ui_burst_part_green,
	full = images.ui_burst_full_green,
	glow = {images.ui_burst_partglow_green, images.ui_burst_fullglow_green}
}

Ivy.sounds = {
	bgm = "bgm_ivy",
}

return common.class("Ivy", Ivy, Character)
