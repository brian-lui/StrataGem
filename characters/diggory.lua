--[[ Color: yellow
Passive: Yellow gems cast by Diggory destroy the gem below them, dealing one
damage. This ability can't destroy other yellows or indestructible gems.

Super: The bottom two rows of your basin break. If any yellows are broken, they
deal double damage.

Implementation notes:

When a yellow gem lands on another gem, there is a brief pause, and then it
SLAMS down and crushes the gem. In addition to the regular gem break animation,
2 dust clouds should appear with exactly the same animation as heath's smoke
when the fire gets extinguished. Don't forget to randomly x and y flip the dust
cloud. Also, 2-5 clods (randomly selected, randomly x and y flipped)
should parabola out.

Super

The entire screen shakes.

Lots of dust clouds appear at the bottom of the basin (x and y flipped) similar
to Walter's water.

clods randomly parabola out from the dust clouds similar to the walter water
(but not as high and not quite as high a rate. They should only go about 1 and
a half gem heights upward) don't forget to randomly x and y flip those too.

As the shaking and clodding is happening, the gems sink into the clouds and
break.
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
Diggory.primary_colors = {"yellow"}

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

	self.slammy_gems = {}
	self.slammed_this_turn = false
end

function Diggory:beforeGravity()
	local game = self.game
	local grid = game.grid
	local delay = 0

	local pending_gems = grid:getPendingGems()
	for _, gem in pairs(pending_gems) do
		if gem.player_num == self.player_num and gem.color == "yellow" then
			self.slammy_gems[#self.slammy_gems + 1] = gem
		end
	end

	-- destroy last two rows of basin
	if self.is_supering then
		self.can_gain_super = false

		for col in grid:cols(self.player_num) do
			local last_gem = grid[grid.BASIN_END_ROW][col].gem
			local second_last_gem = grid[grid.BASIN_END_ROW - 1][col].gem
			
			if last_gem then
				local time_to_explode, particle_time = grid:destroyGem{
					gem = last_gem,
					credit_to = self.player_num,
					force_max_alpha = true,
					extra_damage = last_gem.color == "yellow" and 1 or 0,
				}
				delay = math.max(delay, time_to_explode + particle_time)
			end

			if second_last_gem then
				local time_to_explode, particle_time = grid:destroyGem{
					gem = second_last_gem,
					credit_to = self.player_num,
					force_max_alpha = true,
					extra_damage = second_last_gem.color == "yellow" and 1 or 0,
				}
				delay = math.max(delay, time_to_explode + particle_time)
			end
		end

		self:emptyMP()
		self.is_supering = false
	end

	return delay
end

function Diggory:beforeTween()
	self.game:brightenScreen(self.player_num)
end

function Diggory:afterGravity()
	local game = self.game
	local grid = game.grid
	local delay = 0
	local go_to_gravity

	if not self.slammed_this_turn then
		for _, gem in pairs(self.slammy_gems) do
			local below_gem = grid[gem.row + 1][gem.column].gem
			if below_gem then
				if below_gem.color ~= "yellow" then
					local time_to_explode = grid:destroyGem{
						gem = below_gem,
						credit_to = self.player_num,
					}
					delay = math.max(delay, time_to_explode)
					go_to_gravity = true
				end
			end
		end

		self.slammy_gems = {}
		self.slammed_this_turn = true
	end

	return delay, go_to_gravity
end

function Diggory:afterAllMatches()
	self.can_gain_super = true
end

function Diggory:cleanup()
	self.slammed_this_turn = false
	Character.cleanup(self)
end


return common.class("Diggory", Diggory, Character)
