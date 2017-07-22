local love = _G.love
local class = require "middleclass"
local Character = require "character"
local image = require 'image'

local walter = class("Walter", Character)

walter.full_size_image = love.graphics.newImage('images/characters/walter.png')
walter.small_image = love.graphics.newImage('images/characters/waltersmall.png')
walter.character_id = "Walter"
walter.meter_gain = {RED = 4, BLUE = 8, GREEN = 4, YELLOW = 4}

--[[
walter.super_images = {
	word = image.UI.super.blue_word,
	partial = image.UI.super.blue_partial,
	full = image.UI.super.blue_full,
	glow = {image.UI.super.blue_glow1, image.UI.super.blue_glow2, image.UI.super.blue_glow3, image.UI.super.blue_glow4}
}
--]]
walter.burst_images = {
	word = image.UI.burst.blue_word,
	partial = image.UI.burst.blue_partial,
	full = image.UI.burst.blue_full,
	glow = {image.UI.burst.blue_glow1, image.UI.burst.blue_glow2}
}

return walter
