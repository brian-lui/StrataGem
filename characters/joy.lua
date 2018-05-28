local love = _G.love

local common = require "class.commons"
local Character = require "character"
local image = require 'image'

local Joy = {}

Joy.full_size_image = love.graphics.newImage('images/portraits/joy.png')
Joy.small_image = love.graphics.newImage('images/portraits/joysmall.png')
Joy.character_id = "Joy"
Joy.meter_gain = {red = 8, blue = 4, green = 4, yellow = 4, none = 4, wild = 4}
Joy.super_images = {
	word = image.UI.super.red_word,
	empty = image.UI.super.red_empty,
	full = image.UI.super.red_full,
	glow = image.UI.super.red_glow,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Joy.burst_images = {
	partial = image.UI.burst.red_partial,
	full = image.UI.burst.red_full,
	glow = {image.UI.burst.red_glow1, image.UI.burst.red_glow2}
}


return common.class("Joy", Joy, Character)
