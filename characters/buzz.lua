local love = _G.love

local common = require "class.commons"
local Character = require "character"
local image = require 'image'

local Buzz = {}

Buzz.large_image = love.graphics.newImage('images/portraits/buzz.png')
Buzz.small_image = love.graphics.newImage('images/portraits/buzzsmall.png')
Buzz.character_id = "Buzz"
Buzz.meter_gain = {
	red = 4,
	blue = 4,
	green = 4,
	yellow = 8,
	none = 4,
	wild = 4,
}
Buzz.super_images = {
	word = image.ui_super_text_yellow,
	empty = image.ui_super_empty_yellow,
	full = image.ui_super_full_yellow,
	glow = image.ui_super_glow_yellow,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Buzz.burst_images = {
	partial = image.ui_burst_part_yellow,
	full = image.ui_burst_full_yellow,
	glow = {image.ui_burst_partglow_yellow, image.ui_burst_fullglow_yellow}
}

Buzz.sounds = {
	bgm = "bgm_buzz",
}
return common.class("Buzz", Buzz, Character)
