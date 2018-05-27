local love = _G.love

local common = require "class.commons"
local Character = require "character"
local image = require 'image'

local Holly = {}

Holly.full_size_image = love.graphics.newImage('images/portraits/holly.png')
Holly.small_image = love.graphics.newImage('images/portraits/hollysmall.png')
Holly.character_id = "Holly"
Holly.meter_gain = {red = 4, blue = 8, green = 4, yellow = 4, wild = 4}
Holly.super_images = {
	word = image.UI.super.blue_word,
	empty = image.UI.super.blue_empty,
	full = image.UI.super.blue_full,
	glow = image.UI.super.blue_glow,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Holly.burst_images = {
	partial = image.UI.burst.blue_partial,
	full = image.UI.burst.blue_full,
	glow = {image.UI.burst.blue_glow1, image.UI.burst.blue_glow2}
}

Holly.sounds = {
	bgm = "bgm_holly",
}

return common.class("Holly", Holly, Character)
