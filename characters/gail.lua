local love = _G.love
local class = require "middleclass"
local Character = require "character"
local image = require 'image'

local gail = class("Gail", Character)

gail.full_size_image = love.graphics.newImage('images/characters/gail.png')
gail.small_image = love.graphics.newImage('images/characters/gailsmall.png')
gail.character_id = "Gail"
gail.meter_gain = {RED = 4, BLUE = 4, GREEN = 4, YELLOW = 8}
gail.super_images = {
	word = image.UI.super.yellow_word,
	partial = image.UI.super.yellow_partial,
	full = image.UI.super.yellow_full,
	glow = {image.UI.super.yellow_glow1, image.UI.super.yellow_glow2, image.UI.super.yellow_glow3, image.UI.super.yellow_glow4}
}

return gail
