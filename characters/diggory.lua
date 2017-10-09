local love = _G.love

local common = require "class.commons"
local Character = require "character"
local image = require 'image'

local Diggory = {}

Diggory.full_size_image = love.graphics.newImage('images/characters/diggory.png')
Diggory.small_image = love.graphics.newImage('images/characters/diggorysmall.png')
Diggory.character_id = "Diggory"
Diggory.meter_gain = {red = 4, blue = 8, green = 4, yellow = 4}
Diggory.super_images = {
	word = image.UI.super.blue_word,
	empty = image.UI.super.blue_empty,
	full = image.UI.super.blue_full,
	glow = image.UI.super.blue_glow,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Diggory.burst_images = {
	partial = image.UI.burst.blue_partial,
	full = image.UI.burst.blue_full,
	glow = {image.UI.burst.blue_glow1, image.UI.burst.blue_glow2}
}

return common.class("Diggory", Diggory, Character)
