local love = _G.love
local common = require "class.commons"
local Character = require "character"
local images = require "images"

local Hailey = {}

Hailey.large_image = love.graphics.newImage('images/portraits/hailey.png')
Hailey.small_image = love.graphics.newImage('images/portraits/haileysmall.png')
Hailey.action_image = love.graphics.newImage('images/portraits/action_hailey.png')
Hailey.shadow_image = love.graphics.newImage('images/portraits/shadow_hailey.png')
Hailey.super_fuzz_image = love.graphics.newImage('images/ui/superfuzzblue.png')

Hailey.character_name = "Hailey"
Hailey.meter_gain = {
	red = 4,
	blue = 8,
	green = 4,
	yellow = 4,
	none = 4,
	wild = 4,
}
Hailey.primary_colors = {"blue"}

Hailey.super_images = {
	word = images.ui_super_text_blue,
	empty = images.ui_super_empty_blue,
	full = images.ui_super_full_blue,
	glow = images.ui_super_glow_blue,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Hailey.burst_images = {
	partial = images.ui_burst_part_blue,
	full = images.ui_burst_full_blue,
	glow = {images.ui_burst_partglow_blue, images.ui_burst_fullglow_blue}
}

Hailey.special_images = {
	free_rush = love.graphics.newImage('images/characters/hailey/freerush.png'),
	hold_text = love.graphics.newImage('images/characters/hailey/holdtext.png'),
	hold_zone = love.graphics.newImage('images/characters/hailey/holdzone.png'),
	hold_zone_window = love.graphics.newImage('images/characters/hailey/holdzonewindow.png'),
	ice_block = love.graphics.newImage('images/characters/hailey/iceblock.png'),
	ice_gem = love.graphics.newImage('images/characters/hailey/icegem.png'),
	snow_dust = love.graphics.newImage('images/characters/hailey/snowdust.png'),
	snowflake = love.graphics.newImage('images/characters/hailey/snowflake.png'),
	super_platform = love.graphics.newImage('images/characters/hailey/superplatform.png'),
}

Hailey.sounds = {
	bgm = "bgm_hailey",
}

function Hailey:init(...)
	Character.init(self, ...)
end

return common.class("Hailey", Hailey, Character)
