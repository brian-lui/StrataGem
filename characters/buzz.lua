local love = _G.love

local common = require "class.commons"
local Character = require "character"
local image = require 'image'

local Buzz = {}

Buzz.full_size_image = love.graphics.newImage('images/portraits/buzz.png')
Buzz.small_image = love.graphics.newImage('images/portraits/buzzsmall.png')
Buzz.character_id = "Buzz"
Buzz.meter_gain = {red = 4, blue = 8, green = 4, yellow = 4, wild = 4}
Buzz.super_images = {
	word = image.UI.super.blue_word,
	empty = image.UI.super.blue_empty,
	full = image.UI.super.blue_full,
	glow = image.UI.super.blue_glow,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Buzz.burst_images = {
	partial = image.UI.burst.blue_partial,
	full = image.UI.burst.blue_full,
	glow = {image.UI.burst.blue_glow1, image.UI.burst.blue_glow2}
}

Buzz.sounds = {
	bgm = "bgm_buzz",
}
return common.class("Buzz", Buzz, Character)
