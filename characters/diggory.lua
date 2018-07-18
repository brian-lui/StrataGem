--[[ Color: yellow
Passive: Yellow gems cast by Diggory destroy the gem below them, dealing one
damage. This ability can't destroy other yellows or indestructible gems.

Super: The bottom two rows of your basin break. If any yellows are broken, they
deal double damage.

Implementation notes:

passive happens once per turn in afterGravity phase, and gives super
Implementation:
beforegravity, get all pending yellow gems that belong to self:
	grid:getPendingGems() => gem.player_num == self.player_num & gem.color == "yellow"
	store gems in destructo_table
aftergravity,
	for all gems in destructo_table
		check if row + 1 has a gem
		if so, check if it's not yellow and not indestructible
			if so, destroy it

Super and combos from super do not give meter
Implementation:
	in beforegravity phase:
		set self.can_gain_super to false
		check bottom two rows for gems
		destroy all non-indestructible gems

	in beforetween phase:
		self.game:brightenScreen(self.player_num)

	in afterallmatches phase:
		self.can_gain_super to true
--]]

local love = _G.love
local common = require "class.commons"
local Character = require "character"
local images = require "images"

local Diggory = {}

Diggory.large_image = love.graphics.newImage('images/portraits/diggory.png')
Diggory.small_image = love.graphics.newImage('images/portraits/diggorysmall.png')
Diggory.character_name = "Diggory"
Diggory.meter_gain = {
	red = 4,
	blue = 4,
	green = 4,
	yellow = 8,
	none = 4,
	wild = 4,
}
Diggory.super_images = {
	word = images.ui_super_text_yellow,
	empty = images.ui_super_empty_yellow,
	full = images.ui_super_full_yellow,
	glow = images.ui_super_glow_yellow,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Diggory.burst_images = {
	partial = images.ui_burst_part_yellow,
	full = images.ui_burst_full_yellow,
	glow = {images.ui_burst_partglow_yellow, images.ui_burst_fullglow_yellow}
}

Diggory.sounds = {
	bgm = "bgm_diggory",
}

function Diggory:init(...)
	Character.init(self, ...)
end

return common.class("Diggory", Diggory, Character)
