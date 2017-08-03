local love = _G.love
local common = require "class.commons"
local Character = require "character"
local image = require 'image'

local Gail = {}

Gail.full_size_image = love.graphics.newImage('images/characters/gail.png')
Gail.small_image = love.graphics.newImage('images/characters/gailsmall.png')
Gail.character_id = "Gail"
Gail.meter_gain = {RED = 4, BLUE = 4, GREEN = 4, YELLOW = 8}
Gail.super_images = {
	word = image.UI.super.yellow_word,
	partial = image.UI.super.yellow_partial,
	full = image.UI.super.yellow_full,
	glow = {image.UI.super.yellow_glow1, image.UI.super.yellow_glow2, image.UI.super.yellow_glow3, image.UI.super.yellow_glow4}
}

return common.class("Gail", Gail, Character)
