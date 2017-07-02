local image = require 'image'

local walter = {
	full_size_image = love.graphics.newImage('images/Characters/walter.png'),
	small_image = love.graphics.newImage('images/Characters/waltersmall.png'),
	character_id = "Walter",
	meter_gain = {RED = 4, BLUE = 8, GREEN = 4, YELLOW = 4},
	super_images = {
		word = image.UI.super.blue_word,
		partial = image.UI.super.blue_partial,
		full = image.UI.super.blue_full,
		glow = {image.UI.super.blue_glow1, image.UI.super.blue_glow2, image.UI.super.blue_glow3, image.UI.super.blue_glow4}
	},
}

return walter

