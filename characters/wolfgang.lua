local love = _G.love

local common = require "class.commons"
local Character = require "character"
local image = require 'image'

local Wolfgang = {}

Wolfgang.full_size_image = love.graphics.newImage('images/characters/wolfgang.png')
Wolfgang.small_image = love.graphics.newImage('images/characters/wolfgangsmall.png')
Wolfgang.character_id = "Wolfgang"
Wolfgang.meter_gain = {red = 4, blue = 8, green = 4, yellow = 4}

Wolfgang.super_images = {
	word = image.UI.super.blue_word,
	empty = image.UI.super.blue_empty,
	full = image.UI.super.blue_full,
	glow = image.UI.super.blue_glow,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Wolfgang.burst_images = {
	partial = image.UI.burst.blue_partial,
	full = image.UI.burst.blue_full,
	glow = {image.UI.burst.blue_glow1, image.UI.burst.blue_glow2}
}

Wolfgang.sounds = {
	bgm = "bgm_wolfgang",
}

return common.class("Wolfgang", Wolfgang, Character)
