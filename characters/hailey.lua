--[[ Color: blue
Passive: Hailey can freeze a gem in her "hold zone". Gems in the hold zone stay
there until used. Placing a gem in the hold zone does not take up your turn,
but can only be done once per turn. You can also swap gems in the hold zone.
(The hold gem goes to the platform the other gem was on.) You cannot interact
with the hold zone after you've placed your gem in the basin.

Super: Activating super creates a 1x1 ice gem in a special platform that can be
rushed for free. The ice gem out prioritizes all other falling gems and freezes
gems in a 3x1 area with the gem that touches the ice gem in the middle space.
Frozen gems cannot be broken except by the casting Hailey. Lasts 3 turns before
thawing. Play this in place of your normal gems.
--]]

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


--[[
HoldZone class:
Hold zone initially appears WITHOUT holdzonewindow on top, with holdtext placed
below it. When a gem is dragged into it, holdzonewindow fades on top of the
holdzone, along with a SNOW POOF. holdtext stays on top. holdzonewindow fades
out when the gem is picked up again.

SnowDrift class:
"snowdust and snowflake periodically appear, much like dust falling from
grabbed gems. UNLIKE dust, it travels very slow, about 80 pixels before fading.
It also travels in a random direction, not just down. Also it should appear at
about 50% the rate of dust falling from grabbed gem. The ratio of dust to flake
should be 70 dust / 30 flake.

SnowPoof class:
Similar to snow drift, BUT all of the particles appear AT ONCE. The amount that
appears is "a handfull" and instead of about 80 pixels, it travels about 120
pixels.

SuperPlatform class
When you click super, the superplatform slides in from off screen from the left
(right for P2) and ends up in the position as seen in haileyui. It also rotates
just like the regular star platforms.
Superplatform has constant snowdrift.

IceGem class
Icegem rides on top of the platform (but doesn't rotate of course)  When you
grab the icegem, it should snow poof and begin to snow drift as you hold it.
FREE RUSH should appear on the opponent's side, in the same location as "drop
gems here" from the beginning of the game. When you drop it, the affected gems
snowpoof and iceblock fades on top.
--]]

function Hailey:init(...)
	Character.init(self, ...)

	-- Passive 1: create hold zone

	-- refer to Wolfgang:init(...) as a reference
end

function Hailey:actionPhase()
	-- Passive 2: check for interaction with hold zone
--[[
Passive: Hailey can freeze a gem in her "hold zone". Gems in the hold zone stay
there until used. Placing a gem in the hold zone does not take up your turn,
but can only be done once per turn. You can also swap gems in the hold zone.
(The hold gem goes to the platform the other gem was on.) You cannot interact
with the hold zone after you've placed your gem in the basin.
--]]
end

return common.class("Hailey", Hailey, Character)
