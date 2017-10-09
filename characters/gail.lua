local love = _G.love

local common = require "class.commons"
local Character = require "character"
local image = require 'image'

local Gail = {}

Gail.full_size_image = love.graphics.newImage('images/characters/gail.png')
Gail.small_image = love.graphics.newImage('images/characters/gailsmall.png')
Gail.character_id = "Gail"
Gail.meter_gain = {red = 4, blue = 4, green = 4, yellow = 8}
Gail.super_images = {
	word = image.UI.super.yellow_word,
	empty = image.UI.super.yellow_empty,
	full = image.UI.super.yellow_full,
	glow = image.UI.super.yellow_glow,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Gail.burst_images = {
	partial = image.UI.burst.yellow_partial,
	full = image.UI.burst.yellow_full,
	glow = {image.UI.burst.yellow_glow1, image.UI.burst.yellow_glow2}
}

return common.class("Gail", Gail, Character)
