local love = _G.love

local common = require "class.commons"
local Character = require "character"
local image = require 'image'

local Diggory = {}

Diggory.full_size_image = love.graphics.newImage('images/portraits/diggory.png')
Diggory.small_image = love.graphics.newImage('images/portraits/diggorysmall.png')
Diggory.character_id = "Diggory"
Diggory.meter_gain = {red = 4, blue = 4, green = 4, yellow = 8, none = 4, wild = 4}
Diggory.super_images = {
	word = image.UI.super.yellow_word,
	empty = image.UI.super.yellow_empty,
	full = image.UI.super.yellow_full,
	glow = image.UI.super.yellow_glow,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Diggory.burst_images = {
	partial = image.UI.burst.yellow_partial,
	full = image.UI.burst.yellow_full,
	glow = {image.UI.burst.yellow_glow1, image.UI.burst.yellow_glow2}
}

Diggory.sounds = {
	bgm = "bgm_diggory",
}
return common.class("Diggory", Diggory, Character)
