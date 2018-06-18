local love = _G.love
local common = require "class.commons"
local Character = require "character"
local image = require 'image'

local Damon = {}

Damon.large_image = love.graphics.newImage('images/portraits/damon.png')
Damon.small_image = love.graphics.newImage('images/portraits/damonsmall.png')
Damon.character_id = "Damon"
Damon.meter_gain = {
	red = 4,
	blue = 4,
	green = 8,
	yellow = 4,
	none = 4,
	wild = 4,
}
Damon.super_images = {
	word = image.ui_super_text_green,
	empty = image.ui_super_empty_green,
	full = image.ui_super_full_green,
	glow = image.ui_super_glow_green,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Damon.burst_images = {
	partial = image.ui_burst_part_green,
	full = image.ui_burst_full_green,
	glow = {image.ui_burst_partglow_green, image.ui_burst_fullglow_green}
}

Damon.sounds = {
	bgm = "bgm_holly",
}

return common.class("Damon", Damon, Character)
