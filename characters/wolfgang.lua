--[[ Color: blue
Passive: Wolfgang has a BARK meter. Every time you make a match of a certain color,
the BARK meter gains a letter. (Blue, Amarillo, Red, Kreen). When the Bark meter
is filled, your next gem cluster you gain will contain a Dog piece. Dogs placed
in your basin are good dogs. Good dogs are wild and last until matched. Basins
placed in the opponent's basin (rush) are bad dogs. Bad dogs do not listen and
do nothing. They last for 3 turns and then go home.

Passive animation:
BARK meter (unlit) appears below the super meter. Whenever a match happens, the
appropriate letter lights up with the usual sort of dust explosion. (similar to
the dust explosion when you double cast.) Also, when the match happens, the
appropriate words (BLUE! AMARILLO! etc) associated with the color appear at the
location of the match, slightly rotated (from -20 to 20 degrees) and float up in
the air like Final Fantasy damage numbers. (float up about 78 pixels, decelerating,
linger for .5 second once they reach the final location, and then fade out).

When the BARK meter is lit entirely, a good dog piece (Random) appears in the next
set of gems on the stars when it moves again.

When you drag a piece to the opponent's side (rush), the good dog should change to
a bad dog as soon as you hover to the other side, and return to good dog if you
bring the piece back.

Super: The bottom most platform in your hand gains a double Dog (or becomes a
double dog), and the next 4 clusters that come through your conveyor belt also
contain dogs.
--]]

local love = _G.love
local common = require "class.commons"
local Character = require "character"
local image = require 'image'
local Pic = require 'pic'
local Wolfgang = {}

Wolfgang.full_size_image = love.graphics.newImage('images/portraits/wolfgang.png')
Wolfgang.small_image = love.graphics.newImage('images/portraits/wolfgangsmall.png')
Wolfgang.character_id = "Wolfgang"
Wolfgang.meter_gain = {red = 4, blue = 8, green = 4, yellow = 4}

Wolfgang.super_images = {
	word = image.UI.super.blue_word,
	empty = image.UI.super.blue_empty,
	full = image.UI.super.blue_full,
	glow = image.UI.super.blue_glow,
	overlay = love.graphics.newImage('images/characters/wolfgang/wolfganglogo.png'),
}
Wolfgang.burst_images = {
	partial = image.UI.burst.blue_partial,
	full = image.UI.burst.blue_full,
	glow = {image.UI.burst.blue_glow1, image.UI.burst.blue_glow2}
}

Wolfgang.special_images = {
	good_dog = {
		love.graphics.newImage('images/characters/wolfgang/goodblacklab.png'),
		love.graphics.newImage('images/characters/wolfgang/goodgoldenlab.png'),
		love.graphics.newImage('images/characters/wolfgang/goodrussel.png'),
	},
	bad_dog = {
		love.graphics.newImage('images/characters/wolfgang/badblacklab.png'),
		love.graphics.newImage('images/characters/wolfgang/badgoldenlab.png'),
		love.graphics.newImage('images/characters/wolfgang/badrussel.png'),
	},
	red = {
		dark = love.graphics.newImage('images/characters/wolfgang/r.png'),
		glow = love.graphics.newImage('images/characters/wolfgang/rglow.png'),
		word = love.graphics.newImage('images/characters/wolfgang/red.png'),
	},
	blue = {
		dark = love.graphics.newImage('images/characters/wolfgang/b.png'),
		glow = love.graphics.newImage('images/characters/wolfgang/bglow.png'),
		word = love.graphics.newImage('images/characters/wolfgang/blue.png'),
	},
	green = {
		dark = love.graphics.newImage('images/characters/wolfgang/k.png'),
		glow = love.graphics.newImage('images/characters/wolfgang/kglow.png'),
		word = love.graphics.newImage('images/characters/wolfgang/kreen.png'),
	},
	yellow = {
		dark = love.graphics.newImage('images/characters/wolfgang/a.png'),
		glow = love.graphics.newImage('images/characters/wolfgang/aglow.png'),
		word = love.graphics.newImage('images/characters/wolfgang/amarillo.png'),
	},
}

Wolfgang.sounds = {
	bgm = "bgm_wolfgang",
}

function Wolfgang:init(...)
	Character.init(self, ...)

	-- init BARK

end
-------------------------------------------------------------------------------
-- These are the BARK letter classes
local ColorLetter = {}
function ColorLetter:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	manager.allParticles.CharEffects[ID.particle] = self
	self.manager = manager
end

function ColorLetter:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

-- BARK meter appears below the super meter. 
function ColorLetter.generate(game, owner, x, y, color)
	self.color = blahblah
	self.lighted = false
end

function ColorLetter:lightUp()
	-- fade in new image
	-- effects
	self.lighted = true
end

function ColorLetter:darken()
	-- fade in original image
	-- effects
	self.lighted = false
end

ColorLetter = common.class("ColorLetter", ColorLetter, Pic)
-------------------------------------------------------------------------------
--[[ When a match happens, the appropriate words (BLUE! AMARILLO! etc)
associated with the color appear at the location of the match, slightly rotated
(from -20 to 20 degrees) and float up in the air like Final Fantasy damage
numbers. (float up about 78 pixels, decelerating, linger for .5 second once
they reach the final location, and then fade out).]]
local ColorWord = {}


-------------------------------------------------------------------------------

function Wolfgang:serializeSpecials()
	local ret = ""
	return ret
end

function Wolfgang:deserializeSpecials(str)
end

return common.class("Wolfgang", Wolfgang, Character)
