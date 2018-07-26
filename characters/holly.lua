--[[ Color: green
Passive: For every match you make, a random gem in your basin gains a flower
mark. When the flower gem breaks (regardless of who breaks it, including grey
breaks) the Holly who made the flower heals one damage and the opponent takes
one damage.

Super: 2 spores appear randomly in either the topmost row or second top most
row of any of the opponent’s columns. (So 2 spores randomly appearing in 2 of 8
possible spaces.) If the opponent breaks a spore through matching, all
the damage (including combo damage) is reflected. Spores disappear after three
turns.
--]]

local love = _G.love
local common = require "class.commons"
local Character = require "character"
local images = require "images"

local Holly = {}

Holly.large_image = love.graphics.newImage('images/portraits/holly.png')
Holly.small_image = love.graphics.newImage('images/portraits/hollysmall.png')
Holly.character_name = "Holly"
Holly.meter_gain = {
	red = 4,
	blue = 4,
	green = 8,
	yellow = 4,
	none = 4,
	wild = 4,
}
Holly.primary_colors = {"green"}

Holly.super_images = {
	word = images.ui_super_text_green,
	empty = images.ui_super_empty_green,
	full = images.ui_super_full_green,
	glow = images.ui_super_glow_green,
	overlay = love.graphics.newImage('images/characters/holly/hollylogo.png'),
}
Holly.burst_images = {
	partial = images.ui_burst_part_green,
	full = images.ui_burst_full_green,
	glow = {images.ui_burst_partglow_green, images.ui_burst_fullglow_green}
}

Holly.special_images = {
	red = {
		flower = love.graphics.newImage('images/characters/holly/redflower.png'),
		petala = love.graphics.newImage('images/characters/holly/redpetala.png'),
		petalb = love.graphics.newImage('images/characters/holly/redpetalb.png'),
		rage = love.graphics.newImage('images/characters/holly/redrage.png'),
	},
	blue = {
		flower = love.graphics.newImage('images/characters/holly/blueflower.png'),
		petala = love.graphics.newImage('images/characters/holly/bluepetala.png'),
		petalb = love.graphics.newImage('images/characters/holly/bluepetalb.png'),
		rage = love.graphics.newImage('images/characters/holly/bluerage.png'),
	},
	green = {
		flower = love.graphics.newImage('images/characters/holly/greenflower.png'),
		petala = love.graphics.newImage('images/characters/holly/greenpetala.png'),
		petalb = love.graphics.newImage('images/characters/holly/greenpetalb.png'),
		rage = love.graphics.newImage('images/characters/holly/greenrage.png'),
	},
	yellow = {
		flower = love.graphics.newImage('images/characters/holly/yellowflower.png'),
		petala = love.graphics.newImage('images/characters/holly/yellowpetala.png'),
		petalb = love.graphics.newImage('images/characters/holly/yellowpetalb.png'),
		rage = love.graphics.newImage('images/characters/holly/yellowrage.png'),
	},
	spore_pod = love.graphics.newImage('images/characters/holly/sporepod.png'),
	stem = love.graphics.newImage('images/characters/holly/stem.png'),
}

Holly.sounds = {
	bgm = "bgm_holly",
}

function Holly:init(...)
	Character.init(self, ...)

	self.flower_images = {}
	self.spore_images = {}
end

function Holly:beforeGravity()
	-- Super 1
	-- gain super spore pods
	--[[
		spore is set to the gem as gem.holly_spore = self.player_num
		spore image referenced in self.spore_images
		spore class remove method has self.owner.spore_images[self.gem] = nil
	--]]
end


function Holly:beforeMatch()
	-- Passive 1
	-- store a record of number of matches
end

function Holly:duringMatch()
	-- Passive 4
	-- apply flower heal/damage

	-- Super 3
	--[[ if a match contains both player's spores, grey match. otherwise,
	if a match contains a spore, force it to be flagged for the opponent]]
end

function Holly:afterMatch()
	-- Passive 2
	-- add a flower per match #:
	--[[
		flower is set to the gem as gem.holly_flower = self.player_num
		flower image referenced in self.flower_images
		flower class remove method has self.owner.flower_images[self.gem] = nil
	--]]

	-- Passive 3
	-- set match # to 0
end

function Holly:cleanup()
	-- Super 2
	-- countdown spores and disappear ones that reach 0 turns remaining
	Character.cleanup(self)
end

return common.class("Holly", Holly, Character)
