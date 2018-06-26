local love = _G.love
local common = require "class.commons"
local Character = require "character"
local images = require "images"

local Mort = {}

Mort.large_image = love.graphics.newImage('images/portraits/mort.png')
Mort.small_image = love.graphics.newImage('images/portraits/mortsmall.png')
Mort.character_id = "Mort"
Mort.meter_gain = {
	red = 4,
	blue = 8,
	green = 4,
	yellow = 4,
	none = 4,
	wild = 4,
}
Mort.super_images = {
	word = images.ui_super_text_blue,
	empty = images.ui_super_empty_blue,
	full = images.ui_super_full_blue,
	glow = images.ui_super_glow_blue,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Mort.burst_images = {
	partial = images.ui_burst_part_blue,
	full = images.ui_burst_full_blue,
	glow = {images.ui_burst_partglow_blue, images.ui_burst_fullglow_blue}
}

Mort.sounds = {
	bgm = "bgm_mort",
}

return common.class("Mort", Mort, Character)
