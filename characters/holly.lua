--[[ Color: green
Passive: For every match you make, a random gem in your basin gains a flower
mark. When the flower gem breaks (regardless of who breaks it, including grey
breaks) the Holly who made the flower heals one damage and the opponent takes
one damage.

Super: 8 random gems gain spore pods. Starting on the following turn, a spore
pod explodes and destroys the gem it is on. Any matches created from this
destruction are credited to Holly.
--]]

local love = _G.love
local common = require "class.commons"
local Character = require "character"
local images = require "images"

local Holly = {}

Holly.large_image = love.graphics.newImage('images/portraits/holly.png')
Holly.small_image = love.graphics.newImage('images/portraits/hollysmall.png')
Holly.character_id = "Holly"
Holly.meter_gain = {
	red = 4,
	blue = 4,
	green = 8,
	yellow = 4,
	none = 4,
	wild = 4,
}
Holly.super_images = {
	word = images.ui_super_text_green,
	empty = images.ui_super_empty_green,
	full = images.ui_super_full_green,
	glow = images.ui_super_glow_green,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Holly.burst_images = {
	partial = images.ui_burst_part_green,
	full = images.ui_burst_full_green,
	glow = {images.ui_burst_partglow_green, images.ui_burst_fullglow_green}
}

Holly.sounds = {
	bgm = "bgm_holly",
}

function Holly:init(...)
	Character.init(self, ...)
end

function Holly:beforeGravity()
	-- gain super spore pods
end

function Holly:beforeMatch()
	-- store a record of number of matches
end

function Holly:duringMatch()
	-- apply flower heal/damage
	-- depending on game logic, apply spore match damage here if spore gem was destroyed
end

function Holly:afterMatch()
	-- add a flower per match #
	-- set match # to 0
end

function Holly:afterAllMatches()
	-- spore pod explosion (once per turn)
	-- if explode, then return [delay, true] to go to gravity phase, otherwise [delay, false]
end

return common.class("Holly", Holly, Character)
