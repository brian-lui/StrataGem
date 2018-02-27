local love = _G.love

local common = require "class.commons"
local Character = require "character"
local image = require 'image'

local Hailey = {}

Hailey.full_size_image = love.graphics.newImage('images/portraits/hailey.png')
Hailey.small_image = love.graphics.newImage('images/portraits/haileysmall.png')
Hailey.character_id = "Hailey"
Hailey.meter_gain = {red = 4, blue = 8, green = 4, yellow = 4}
Hailey.super_images = {
	word = image.UI.super.blue_word,
	empty = image.UI.super.blue_empty,
	full = image.UI.super.blue_full,
	glow = image.UI.super.blue_glow,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Hailey.burst_images = {
	partial = image.UI.burst.blue_partial,
	full = image.UI.burst.blue_full,
	glow = {image.UI.burst.blue_glow1, image.UI.burst.blue_glow2}
}

Hailey.sounds = {
	bgm = "bgm_hailey",
}
return common.class("Hailey", Hailey, Character)
