local love = _G.love

local common = require "class.commons"
local Character = require "character"
local image = require 'image'

local Ivy = {}

Ivy.full_size_image = love.graphics.newImage('images/portraits/ivy.png')
Ivy.small_image = love.graphics.newImage('images/portraits/ivysmall.png')
Ivy.character_id = "Ivy"
Ivy.meter_gain = {red = 4, blue = 4, green = 8, yellow = 4, none = 4, wild = 4}

Ivy.super_images = {
	word = image.UI.super.green_word,
	empty = image.UI.super.green_empty,
	full = image.UI.super.green_full,
	glow = image.UI.super.green_glow,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Ivy.burst_images = {
	partial = image.UI.burst.green_partial,
	full = image.UI.burst.green_full,
	glow = {image.UI.burst.green_glow1, image.UI.burst.green_glow2}
}

Ivy.sounds = {
	bgm = "bgm_ivy",
}

return common.class("Ivy", Ivy, Character)
