local love = _G.love
local common = require "class.commons"
local Character = require "character"
local image = require 'image'
local Pic = require 'pic'

local Gail = {}

Gail.full_size_image = love.graphics.newImage('images/portraits/gail.png')
Gail.small_image = love.graphics.newImage('images/portraits/gailsmall.png')
Gail.character_id = "Gail"
Gail.meter_gain = {red = 4, blue = 4, green = 4, yellow = 8, wild = 4}
Gail.super_images = {
	word = image.UI.super.yellow_word,
	empty = image.UI.super.yellow_empty,
	full = image.UI.super.yellow_full,
	glow = image.UI.super.yellow_glow,
	overlay = love.graphics.newImage('images/dummy.png'),
}
Gail.burst_images = {
	partial = image.UI.burst.yellow_partial,
	full = image.UI.burst.yellow_full,
	glow = {image.UI.burst.yellow_glow1, image.UI.burst.yellow_glow2}
}

Gail.special_images = {
	petal1 = love.graphics.newImage('images/characters/gail/testpetal1.png'),
	petal2 = love.graphics.newImage('images/characters/gail/testpetal2.png'),
}

Gail.sounds = {
	bgm = "bgm_gail",
}


local TestPetal = {}
function TestPetal:init(manager, tbl)
	Pic.init(self, manager.game, tbl)
	manager.allParticles.CharEffects[ID.particle] = self
	self.manager = manager
end

function TestPetal:remove()
	self.manager.allParticles.CharEffects[self.ID] = nil
end

function TestPetal.generate(game, owner)
	local grid = game.grid
	local stage = game.stage
	local params = {
		x = stage.width * 0.5,
		y = stage.height * 0.25,
		scaling = 1,
		image = Gail.special_images.petal1,
		owner = owner,
		player_num = owner.player_num,
		name = "TestPetal",
	}

	local p = common.instance(TestPetal, game.particles, params)
	local the_next_image = Gail.special_images.petal2
	for i = 1, 5 do
		p:change{duration = 30, y_scaling = 0.01}
		p:newImage(the_next_image, true)
		if the_next_image == Gail.special_images.petal1 then
			the_next_image = Gail.special_images.petal2
		else
			the_next_image = Gail.special_images.petal1
		end
		p:change{duration = 30, y_scaling = 1}
	end
	p:change{duration = 0, remove = true}
end
TestPetal = common.class("TestPetal", TestPetal, Pic)

Gail.fx = {
	testPetal = TestPetal,
}


return common.class("Gail", Gail, Character)
