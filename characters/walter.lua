--[[ Color: blue
Passive: Vertical matches create a rain cloud. Gems matched in the rain cloud
	(including opponent matches) heal Walter for 1 damage.

Super: Clear the tallest friendly vertical column. In case of a tie, clear the
	column nearest the edge of the basin.  --]]

local love = _G.love
local common = require "class.commons"
local image = require 'image'
local Pic = require 'pic'
local Character = require "character"

local Walter = {}
Walter.character_id = "Walter"
Walter.meter_gain = {red = 4, blue = 8, green = 4, yellow = 4}

Walter.full_size_image = love.graphics.newImage('images/characters/walter.png')
Walter.small_image = love.graphics.newImage('images/characters/waltersmall.png')
Walter.action_image = love.graphics.newImage('images/characters/walteraction.png')
Walter.shadow_image = love.graphics.newImage('images/characters/waltershadow.png')

Walter.super_images = {
	word = image.UI.super.blue_word,
	empty = image.UI.super.blue_empty,
	full = image.UI.super.blue_full,
	glow = image.UI.super.blue_glow,
	overlay = love.graphics.newImage('images/specials/walter/walterlogo.png'),
}

Walter.burst_images = {
	partial = image.UI.burst.blue_partial,
	full = image.UI.burst.blue_full,
	glow = {image.UI.burst.blue_glow1, image.UI.burst.blue_glow2}
}

Walter.special_images = {
	cloud = love.graphics.newImage('images/specials/walter/cloud.png'),
	foam = love.graphics.newImage('images/specials/walter/foam.png'),
	spout = love.graphics.newImage('images/specials/walter/spout.png'),
	drop1 = love.graphics.newImage('images/specials/walter/drop1.png'),
	drop2 = love.graphics.newImage('images/specials/walter/drop2.png'),
	drop3 = love.graphics.newImage('images/specials/walter/drop3.png'),
}

Walter.sounds = {
	bgm = "bgm_walter",
}

function Walter:init(...)
	Character.init(self, ...)

	self.CLOUD_SLIDE_DURATION = 45 -- how long for the cloud incoming tween


	self.pending_clouds = {} -- clouds for vertical matches generates at t0
	self.ready_clouds = {} -- clouds at t1, gives healing
	self.pending_gem_cols = {} -- pending gems, for calculating healing columns

end

-------------------------------------------------------------------------------
--[[
Passive description:
After garbage phase, before the new turn starts.
cloud.png should slide in horizontally from the casting Walter's side. it should
start fast and then decelerate as it reaches the appropriate column. once it
reaches its location, drop1 drop2 and drop3 should fall from the cloud in a ratio
of drop 1 70%, drop2 20%, drop3 10%

When a match is made inside a raining column, it should also generate pink healing
particles that fly back to the casting Walter's stars. instead of the attacking
particles, which cause the star to shake, these should just generate additional 
sparkles around the star when they reach it.

Passive pseudocode:

update self.pending_clouds: [refer to heath]

during match, check vertical matches against self.pending_clouds columns
if any matches made:
	hand:healDamage(1)
	game.particles.healing.generate{game = game, x = cloud_x, y = cloud_y, owner = me, delay = match delay time}

getEndOfTurnDelay() returns self.CLOUD_SLIDE_DURATION if any non-zero in self.pending_clouds, otherwise 0

before end of turn:
	if any non-zero in self.pending_clouds:
		create HealingCloud instance(s)

cleanup:
	update self.pending_clouds
	remove any expired pending_clouds

HealingCloud class:
	y = grid.y[11] (?)
	dest_x = self.pending_clouds column
	init_x = dest_x +/- stage.width * 0.5
	create cloud instance, outQuart tween with duration self.CLOUD_SLIDE_DURATION, exit: self.create_droplet = true

	const droplet_frequency = 20
	self.droplet_timer = 0
	if self.create_droplet:
		if self.droplet_timer > 0:
			self.droplet_timer -= 1
		else:
			self.droplet_timer = self.droplet_frequency
			create newDroplet instance
HealingCloud remove: fades out

NewDroplet class:
	const duration = 90
	random from {7x drop1, 2x drop2, 1x drop3}
	create droplet instance, linear tween to stage.height * 1.1, exit = true





Super description:
On the turn you activate super, the gems should light up BUT not explode immediately.
Instead, foam.png should appear on the bottom of the column(s) where the match(es)
were made, and it should expand and shrink to about 105% and 95%. Then, spout.png
should quickly shoot out from the bottom of the column until the top of spout.png
reaches the top of the column. As the spout hits gems, they should explode.
ONLY THE PORTION OF SPOUT ABOVE THE FOAM SHOULD BE VISIBLE. Once it reaches the top,
it should bob up and down by about 40 pixels above and below the top of the basin.
After three bobs everything should fade.

While this is all going on, drop1 2 and 3 should be shooting out from the foam in 
tight parabolic arcs. (they shouldn't go more than an 2 columns horizontally, but
should reach all the way to the top of the column vertically.) they should again be
in the ratio of 70% 20% 10% and also they need to rotate such that the bottom of the
image is facing the current trajectory. (think about how an arrow flies)

Super pseudocode:
--]]

return common.class("Walter", Walter, Character)
