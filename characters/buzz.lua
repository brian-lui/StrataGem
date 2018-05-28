local love = _G.love

local common = require "class.commons"
local Character = require "character"
local image = require 'image'

local Buzz = {}

Buzz.full_size_image = love.graphics.newImage('images/portraits/buzz.png')
Buzz.small_image = love.graphics.newImage('images/portraits/buzzsmall.png')
Buzz.character_id = "Buzz"
Buzz.meter_gain = {red = 4, blue = 4, green = 4, yellow = 8, none = 4, wild = 4}
Buzz.super_images = {
	word = image.UI.super.yellow_word,
	empty = image.UI.super.yellow_empty,
	full = image.UI.super.yellow_full,
	glow = image.UI.super.yellow_glow,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Buzz.burst_images = {
	partial = image.UI.burst.yellow_partial,
	full = image.UI.burst.yellow_full,
	glow = {image.UI.burst.yellow_glow1, image.UI.burst.yellow_glow2}
}

Buzz.sounds = {
	bgm = "bgm_buzz",
}
return common.class("Buzz", Buzz, Character)
