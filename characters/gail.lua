--[[ Color: yellow
Passive: At end of turn, the highest gem "blows" one column over away from the
casting Gail. Matches made in this way are attributed to the blowing Gail. If
there is no clear highest gem, nothing is blown.

Super: A tornado grabs up to the top 4 gems of Gail's lowest column (random on
tie) and then drops the gems into the opponent's lowest column at a rate of one
gem per turn for (up to) 4 turns. (The order of gems dropped should be the
topmost grabbed gem to the bottommost).


Passive Animations:
When the wind blows, 12 (poof or leaf) should appear somewhere on the upper
half of the gail side of the screen, and travel across the screen in a slight
upside down arch. (see image) every 10 frames for 120 frames. FOR POOF,
randomly switch Y or X axis, no other animation. For leaf, do the leaf
animation. The ratio is 4:1 poof to leaf.

AFFECTED GEMS should have 2 to 4 poofs (randomly swapped x and y axis) appear
along the border of the gem, with some poofs appearing in front of the gem,
and some appearing in front.

Super Animations:
Tornado fades between Tornado 1 and 2, just like Walter fountain. Poofs (random
x and y) constantly appear and follow SWIRL PATTERN (see attached image)

Tornado slides in from the bottom, along the column it initially affects, and
the affected gems follow SWIRL PATTERN, but disappear behind the tornado rather
than fade out. When it reaches the top it slides (smooth slide, not a linear
slide AND NOT A FUCKING BOUNCE) to the column it's going to attack. If it ever
changes columns, it smooth slides again. (NO BOUNCE)

Gems just drop from the tornado the way gems drop.
--]]

local love = _G.love
local common = require "class.commons"
local Character = require "character"
local images = require "images"
local Pic = require "pic"

local Gail = {}

Gail.large_image = love.graphics.newImage('images/portraits/gail.png')
Gail.small_image = love.graphics.newImage('images/portraits/gailsmall.png')
Gail.action_image = love.graphics.newImage('images/portraits/action_gail.png')
Gail.shadow_image = love.graphics.newImage('images/portraits/shadow_gail.png')
Gail.super_fuzz_image = love.graphics.newImage('images/ui/superfuzzyellow.png')

Gail.character_name = "Gail"
Gail.meter_gain = {
	red = 4,
	blue = 4,
	green = 4,
	yellow = 8,
	none = 4,
	wild = 4,
}
Gail.primary_colors = {"yellow"}

Gail.super_images = {
	word = images.ui_super_text_yellow,
	empty = images.ui_super_empty_yellow,
	full = images.ui_super_full_yellow,
	glow = images.ui_super_glow_yellow,
	overlay = love.graphics.newImage('images/characters/gail/gaillogo.png'),
}
Gail.burst_images = {
	partial = images.ui_burst_part_yellow,
	full = images.ui_burst_full_yellow,
	glow = {images.ui_burst_partglow_yellow, images.ui_burst_fullglow_yellow}
}

Gail.special_images = {
	leaf1 = love.graphics.newImage('images/characters/gail/leaf1.png'),
	leaf2 = love.graphics.newImage('images/characters/gail/leaf2.png'),
	poof = love.graphics.newImage('images/characters/gail/poof.png'),
	tornado1 = love.graphics.newImage('images/characters/gail/tornado1.png'),
	tornado2 = love.graphics.newImage('images/characters/gail/tornado2.png'),
}

Gail.sounds = {
	bgm = "bgm_gail",
}

function Gail:init(...)
	Character.init(self, ...)

	--[[
	self.should_activate_passive = true
	self.should_activate_tornado = true
	self.tornado_gems = {}
	--]]
end

--[[ Super 1
	Find lowest column in all own columns
	If more than one: select randomly

	Select up to 4 of the top gems in that column
	Move them to the tornado, starting from the top gem
--]]
function Gail:beforeGravity()
--[[

	Super: A tornado grabs up to the top 4 gems of Gail's lowest column (random on
tie) and then drops the gems into the opponent's lowest column at a rate of one
gem per turn for (up to) 4 turns. (The order of gems dropped should be the
topmost grabbed gem to the bottommost). The tornado drop happens before the
regular gems are dropped. Any matches made are credited to the casting Gail.

The drop from tornado gems are flagged as owned by Gail
The drop from tornado happens in AfterAllMatches phase.
--]]
end

--[[ Super 2
if self.should_activate_tornado:
	Determine lowest column in all enemy columns
	If more than one: select randomly
	if tornado[1]:
		Pop tornado[1] gem
		Flag gem as owned by Gail
		Move gem into enemy's lowest column
self.should_activate_tornado = false
--]]
function Gail:afterAllMatches()

end

function Gail:beforeCleanup()
--[[ Passive 1
if self.should_activate_passive:
	find highest gem in all enemy columns
	if #highest gems == 1:
		flag gem as owned by self
		if next column over is valid:
			move gem one column over
			go_to_gravity_phase = true

self.should_activate_passive = false
--]]
end

function Gail:cleanup()
	--[[
	self.should_activate_passive, self.should_activate_tornado = false, false
	--]]
end
return common.class("Gail", Gail, Character)
