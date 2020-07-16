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
	self.should_activate_passive = true

	--[[
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
	local delay = 0
	local go_to_gravity_phase = false

	-- activate passive wind blow
	if self.should_activate_passive then
		local grid = self.game.grid
		local columns = {}

		-- get column with highest gem
		local top_row = 1000
		for i = 1, grid.COLUMNS do
			columns[i] = grid:getFirstEmptyRow(i)
			if columns[i] < top_row then top_row = columns[i] end
		end

		-- check whether there's more than one column with the highest gem row
		local num_top_gem_cols = 0
		for i = 1, #columns do
			if columns[i] == top_row then
				num_top_gem_cols = num_top_gem_cols + 1
			end
		end

		if num_top_gem_cols == 1 and top_row < grid.BOTTOM_ROW then
			local to_move_gem

			-- locate the gem
			for i = 1, #columns do
				if columns[i] == top_row then
					to_move_gem = grid[top_row + 1][i].gem
					break
				end
			end

			local sign
			if self.player_num == 1 then
				sign = 1
			elseif self.player_num == 2 then
				sign = -1
			else
				error("Gail has an invalid player_num. Sad!")
			end

			local dest_row = to_move_gem.row
			local dest_col = to_move_gem.column + (1 * sign)

			-- only move gem if there's no gem already there,
			-- and if it won't go out of bounds
			local empty_move_spot = not grid[dest_row][dest_col].gem
			local in_bounds
			if self.player_num == 1 then
				in_bounds = to_move_gem.column ~= grid.COLUMNS
			elseif self.player_num == 2 then
				in_bounds = to_move_gem.column ~= 1
			end

			-- flag and move the gem
			if empty_move_spot and in_bounds then
				to_move_gem:setOwner(self.player_num, false)

				local move_delay
				grid:moveGem(to_move_gem, dest_row, dest_col)
				move_delay = grid:moveGemAnim(to_move_gem, dest_row, dest_col)
				delay = delay + move_delay
				go_to_gravity_phase = true
			end
		end

		self.should_activate_passive = false
	end

	return delay, go_to_gravity_phase
end

function Gail:cleanup()
	self.should_activate_passive = true
	--[[
	self.should_activate_tornado
	--]]
end
return common.class("Gail", Gail, Character)
