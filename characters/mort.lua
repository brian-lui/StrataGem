local love = _G.love

local common = require "class.commons"
local Character = require "character"
local image = require 'image'

local Mort = {}

Mort.full_size_image = love.graphics.newImage('images/portraits/mort.png')
Mort.small_image = love.graphics.newImage('images/portraits/mortsmall.png')
Mort.character_id = "Mort"
Mort.meter_gain = {red = 4, blue = 4, green = 8, yellow = 4}
Mort.super_images = {
	word = image.UI.super.green_word,
	empty = image.UI.super.green_empty,
	full = image.UI.super.green_full,
	glow = image.UI.super.green_glow,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Mort.burst_images = {
	partial = image.UI.burst.green_partial,
	full = image.UI.burst.green_full,
	glow = {image.UI.burst.green_glow1, image.UI.burst.green_glow2}
}

Mort.sounds = {
	bgm = "bgm_mort",
}

return common.class("Mort", Mort, Character)
