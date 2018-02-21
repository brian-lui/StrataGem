local love = _G.love

local common = require "class.commons"
local Character = require "character"
local image = require 'image'

local Damon = {}

Damon.full_size_image = love.graphics.newImage('images/characters/damon.png')
Damon.small_image = love.graphics.newImage('images/characters/damonsmall.png')
Damon.character_id = "Damon"
Damon.meter_gain = {red = 4, blue = 4, green = 8, yellow = 4}
Damon.super_images = {
	word = image.UI.super.green_word,
	empty = image.UI.super.green_empty,
	full = image.UI.super.green_full,
	glow = image.UI.super.green_glow,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Damon.burst_images = {
	partial = image.UI.burst.green_partial,
	full = image.UI.burst.green_full,
	glow = {image.UI.burst.green_glow1, image.UI.burst.green_glow2}
}

Damon.sounds = {
	bgm = "bgm_holly",
}

return common.class("Damon", Damon, Character)
