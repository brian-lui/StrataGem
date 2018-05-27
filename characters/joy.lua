local love = _G.love

local common = require "class.commons"
local Character = require "character"
local image = require 'image'

local Joy = {}

Joy.full_size_image = love.graphics.newImage('images/portraits/joy.png')
Joy.small_image = love.graphics.newImage('images/portraits/joysmall.png')
Joy.character_id = "Joy"
Joy.meter_gain = {red = 4, blue = 8, green = 4, yellow = 4, wild = 4}
Joy.super_images = {
	word = image.UI.super.blue_word,
	empty = image.UI.super.blue_empty,
	full = image.UI.super.blue_full,
	glow = image.UI.super.blue_glow,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Joy.burst_images = {
	partial = image.UI.burst.blue_partial,
	full = image.UI.burst.blue_full,
	glow = {image.UI.burst.blue_glow1, image.UI.burst.blue_glow2}
}


return common.class("Joy", Joy, Character)
