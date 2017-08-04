local love = _G.love
local common = require "class.commons"
local Character = require "character"
local image = require 'image'

local Walter = {}

Walter.full_size_image = love.graphics.newImage('images/characters/walter.png')
Walter.small_image = love.graphics.newImage('images/characters/waltersmall.png')
Walter.character_id = "Walter"
Walter.meter_gain = {red = 4, blue = 8, green = 4, yellow = 4}
Walter.super_images = {
	word = image.UI.super.blue_word,
	partial = image.UI.super.blue_partial,
	full = image.UI.super.blue_full,
	glow = {image.UI.super.blue_glow1, image.UI.super.blue_glow2, image.UI.super.blue_glow3, image.UI.super.blue_glow4}
}

return common.class("Walter", Walter, Character)
