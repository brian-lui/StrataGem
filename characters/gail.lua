local image = require 'image'

local gail = {
	full_size_image = love.graphics.newImage('images/Characters/gail.png'),
	small_image = love.graphics.newImage('images/Characters/gailsmall.png'),
	character_id = "Gail",
	meter_gain = {RED = 4, BLUE = 4, GREEN = 4, YELLOW = 8},
	super_images = {
		word = image.UI.super.yellow_word,
		partial = image.UI.super.yellow_partial,
		full = image.UI.super.yellow_full,
		glow = {image.UI.super.yellow_glow1, image.UI.super.yellow_glow2, image.UI.super.yellow_glow3, image.UI.super.yellow_glow4} 
	},
}

return gail

