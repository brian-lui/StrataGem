local love = _G.love
--[[
	Draws the background, including animations.
	Every background should have:
	Background.XYZ:update()
	Background.XYZ:drawImages()
	Background.XYZ:reset()
	Note that the "self" passed to these functions is Background, not Background.XYZ
--]]

local common = require 'class.commons'
require 'inits'
local image = require 'image'
local pic = require 'pic'

local spairs = require("utilities").spairs

local Background = {}

function Background:init(game)
	self.game = game
	local stage = game.stage

	self.backgroundParticles = {}

	self.cloud.background_image = common.instance(pic, {x = stage.x_mid, y = stage.y_mid, image = image.background.cloud.background})

	self.starfall.background_image = common.instance(pic, {x = stage.x_mid, y = stage.y_mid, image = image.background.starfall.background})
	self.starfallstar_speed_x = function(height) return (stage.height / height) * 0.1 end
	self.starfallstar_speed_y = function(height) return (stage.height / height) * 0.15 end
	self.starfallstar_rotation = function(height) return (stage.height / height) * 0.005 end

	self.seasons.background_image = common.instance(pic, {x = stage.x_mid, y = stage.y_mid, image = image.seasons_background})
	self.seasons.background_image2 = common.instance(pic, {x = stage.x_mid, y = stage.y_mid, image = image.seasons_background2})
	self.seasons.sakura_speed_x = function(height) return (stage.height / height) * 0.4 end
	self.seasons.sakura_speed_y = function(height) return (stage.height / height) * 0.6 end
	self.seasons.sakura_rotation = function(height) return (stage.height / height) * 0.0004 end
	self.seasons.tinysakura_speed_x = function(height) return (stage.height / height) * 0.02 end
	self.seasons.tinysakura_speed_y = function(height) return (stage.height / height) * 0.03 end
	self.seasons.tinysakura_rotation = function(height) return (stage.height / height) * 0.0002 end
	self.seasons.leaf_speed_x = function(height) return math.ceil((stage.height / height) * (math.random() - 0.5) * 4) end
	self.seasons.leaf_speed_y = function(height) return (stage.height / height) * 2 end
	self.seasons.leaf_rotation = function(height) return (stage.height / height) * 0.002 end
	self.seasons.snow_speed_x = function(height) return (stage.height / height^0.5) / 15 end
	self.seasons.snow_speed_y = function(height) return (stage.height / height^0.5) / 10 end
	self.seasons.snow_rotation = function(height) return (stage.height / height^0.5) / 1000 end

	self.colors.background_image1 = common.instance(pic, {x = stage.x_mid, y = stage.y_mid, image = image.background.colors.white})
	self.colors.background_image2 = common.instance(pic, {x = stage.x_mid, y = stage.y_mid, image = image.background.colors.blue})
	self.colors.background_image3 = common.instance(pic, {x = stage.x_mid, y = stage.y_mid, image = image.background.colors.red})
	self.colors.background_image4 = common.instance(pic, {x = stage.x_mid, y = stage.y_mid, image = image.background.colors.green})
	self.colors.background_image5 = common.instance(pic, {x = stage.x_mid, y = stage.y_mid, image = image.background.colors.yellow})
	self.colors.solid_draw = Background.colors.background_image1
end

-------------------------------------------------------------------------------
------------------------------------ CLOUD ------------------------------------
-------------------------------------------------------------------------------

Background.cloud = {
	Background_ID = "Cloud",
	big_cloud_speed = function() return 0.25 * (math.random() + 1) end,
	med_cloud_speed = function() return 0.35 * (math.random() + 1) end,
	small_cloud_speed = function() return 0.6 * (math.random() + 1) end,
	daycount = 0
}

Background.cloud.Cloud = {}
function Background.cloud.Cloud:init(background, x, y, img, speed, classification)
  ID.background = ID.background + 1
  self.x = x
  self.y = y
  self.speed_x = speed
  self.image = img
  self.width = img:getWidth()
  self.height = img:getHeight()
  self.quad = love.graphics.newQuad(0, 0, self.width, self.height, self.width, self.height)
  self.classification = classification
  self.ID = ID.background
  background.backgroundParticles[ID.background] = self
end

Background.cloud.Cloud = common.class("Background.cloud.Cloud", Background.cloud.Cloud, pic)

local function Cloud_generateBigCloud(self, starting_x)
	local x = starting_x or image.background.cloud.bigcloud1:getWidth() * -1
	local y = math.random(0, self.game.stage.height / 4)
	local speed = self.cloud.big_cloud_speed()
	local img = {
		image.background.cloud.bigcloud1,
		image.background.cloud.bigcloud2,
		image.background.cloud.bigcloud3,
		image.background.cloud.bigcloud4,
		image.background.cloud.bigcloud5,
		image.background.cloud.bigcloud6
	}
	local image_index = math.random(1, #img)

	common.instance(self.cloud.Cloud, self, x, y, img[image_index], speed, "Bigcloud")
end

local function Cloud_generateMedCloud(self, starting_x)
	local x = starting_x or image.background.cloud.medcloud1:getWidth() * -1
	local y = math.random(self.game.stage.height / 4, self.game.stage.height * 3/8)
	local speed = self.cloud.med_cloud_speed()
	local img = {
		image.background.cloud.medcloud1,
		image.background.cloud.medcloud2,
		image.background.cloud.medcloud3,
		image.background.cloud.medcloud4,
		image.background.cloud.medcloud5,
		image.background.cloud.medcloud6
	}
	local image_index = math.random(1, #img)

	common.instance(self.cloud.Cloud, self, x, y, img[image_index], speed, "Medcloud")
end

local function Cloud_generateSmallCloud(self, starting_x)
	local x = starting_x or image.background.cloud.smallcloud1:getWidth() * -1
	local y = math.random(self.game.stage.height * 3/8, self.game.stage.height / 2)
	local speed = self.cloud.small_cloud_speed()
	local img = {
		image.background.cloud.smallcloud1,
		image.background.cloud.smallcloud2,
		image.background.cloud.smallcloud3,
		image.background.cloud.smallcloud4,
		image.background.cloud.smallcloud5,
		image.background.cloud.smallcloud6
	}
	local image_index = math.random(1, #img)

	common.instance(self.cloud.Cloud, self, x, y, img[image_index], speed, "Smallcloud")
end

local function Cloud_initClouds(self)
	local function starting_x()
		return math.random(0, math.ceil(self.game.stage.width * 0.7))
	end

	Cloud_generateBigCloud(self, starting_x())
	for _ = 1, 2 do
		Cloud_generateMedCloud(self, starting_x())
	end
	for _ = 1, 3 do
		Cloud_generateSmallCloud(self, starting_x())
	end
end

function Background.cloud:drawImages()
	self.cloud.background_image:draw()

  for _, instance in spairs(self.backgroundParticles) do
    if instance.classification == "Smallcloud" then
      instance:draw()
  	end
  end

  for _, instance in spairs(self.backgroundParticles) do
    if instance.classification == "Medcloud" then
      instance:draw()
  	end
  end

  for _, instance in spairs(self.backgroundParticles) do
    if instance.classification == "Bigcloud" then
      instance:draw()
  	end
  end
end

function Background.cloud:update()
	self.cloud.daycount = self.cloud.daycount + 1
	if #self.backgroundParticles == 0 and self.cloud.daycount < 100 then
		Cloud_initClouds()
	end

	for _, instance in pairs(self.backgroundParticles) do
		instance.x = instance.x + instance.speed_x
		if instance.x > self.game.stage.width + instance.width then self.backgroundParticles[instance.ID] = nil end
	end

	if self.cloud.daycount % 721 == 0 then Cloud_generateBigCloud(self) end
	if self.cloud.daycount % 487 == 0 then Cloud_generateMedCloud(self)	end
	if self.cloud.daycount % 361 == 0 then Cloud_generateSmallCloud(self)	end
end

function Background.cloud:reset()
	self.backgroundParticles = {}
	Cloud_initClouds()
end

-------------------------------------------------------------------------------
---------------------------------- STARFALL -----------------------------------
-------------------------------------------------------------------------------

Background.starfall = {
	Background_ID = "Starfall",
	star_freq = function() return math.random(70, 100) end,
	time_to_next = 30
}

Background.starfall.Star = {}
function Background.starfall.Star:init(background, x, y, img, speed_x, speed_y, rotation)
  ID.background = ID.background + 1
  self.x = x
  self.y = y
  self.speed_x = speed_x
  self.speed_y = speed_y
  self.rotation = rotation
  self.speed_rotation = rotation
  self.image = img
  self.width = img:getWidth()
  self.height = img:getHeight()
  self.quad = love.graphics.newQuad(0, 0, self.width, self.height, self.width, self.height)
  self.ID = ID.background
  background.backgroundParticles[ID.background] = self
end

Background.starfall.Star = common.class("Background.starfall.Star", Background.starfall.Star, pic)

local function Starfall_generateStar(self)
	local image_table = {image.background.starfall.star1, image.background.starfall.star2, image.background.starfall.star3, image.background.starfall.star4}
	local image_index = math.random(1, #image_table)
	local img = image_table[image_index]
	local height = img:getHeight()

	local min_x = math.ceil(self.game.stage.height * -0.5)
	local max_x = self.game.stage.width - math.ceil(self.game.stage.height * 0.2)
	local x = math.random(min_x, max_x)
	local y = height * -0.5
	local speed_x = self.starfall.star_speed_x(height)
	local speed_y = self.starfall.star_speed_y(height)
	local rotation = self.starfall.star_rotation(height)

	common.instance(self.starfall.Star, self, x, y, img, speed_x, speed_y, rotation)
end

function Background.starfall:drawImages()
	self.starfall.background_image:draw()

  for ID, instance in spairs(self.backgroundParticles) do
    instance:draw()
  end
end

function Background.starfall:update()
	for ID, instance in pairs(self.backgroundParticles) do
		instance.x = instance.x + instance.speed_x
		instance.y = instance.y + instance.speed_y
		instance.rotation = instance.rotation + instance.speed_rotation

		if instance.y > self.game.stage.height + instance.height then self.backgroundParticles[instance.ID] = nil end
	end

	self.starfall.time_to_next = self.starfall.time_to_next - 1

	if self.starfall.time_to_next == 0 then
		Starfall_generateStar(self)
		self.starfall.time_to_next = self.starfall.star_freq()
	end
end

function Background.starfall:reset()
	self.starfall.time_to_next = 30
	self.backgroundParticles = {}
end


-------------------------------------------------------------------------------
----------------------------------- SEASONS -----------------------------------
-------------------------------------------------------------------------------

Background.seasons = {
	Background_ID = "Seasons",

	winter_background = false,

	winter_background_fadein_time = 180,
	winter_background_fadeout_time = 180,

	daycount = 0,
	end_of_spring = 1800,
	start_of_summer = 2800,
	end_of_summer = 4600,
	end_of_fall = 7000,
	end_of_winter = 9000,
	start_of_spring = 9900,
	end_of_cycle = 9901,

	sakura_freq = function() return math.random(70, 100) end,
	sakura_time_to_next = 10,
	sakura_sine_period = 180, -- frames per sine wave
	sakura_sine_multiple = 3, -- multiple sine_period by this to get the total displacement


	tinysakura_freq = function() return math.random(70, 100) end,
	tinysakura_time_to_next = 3,
	tinysakura_sine_period = 180,
	tinysakura_sine_multiple = 1.5,

	greenleaf_fadein_time = 300,
	newcolor_fadein_time = 450, -- double this too later
	newcolor_fadein_freq = function() return math.random(120, 180) end,
	newcolor_time_to_next = 30,
	oldleaf_time_to_falloff = function() return math.random(1200, 1500) end,
	leaf_freq = function() return math.random(70, 100) end,
	leaf_time_to_next = 60,

	snow_freq = function() return math.random(30, 50) end,
	snow_time_to_next = 12,
}

Background.seasons.winter_background_fadein_time_init = Background.seasons.winter_background_fadein_time
Background.seasons.winter_background_fadeout_time_init = Background.seasons.winter_background_fadeout_time

Background.seasons.Sakura = {}
function Background.seasons.Sakura:init(background, x, y, img, speed_x, speed_y, rotation, sine_period, sine_multiple)
	if not img then
		love.errhand("No image to draw??")
	end

  ID.background = ID.background + 1
  self.x = x
  self.y = y
  self.speed_x = speed_x
  self.speed_y = speed_y
  self.rotation = math.random() * math.pi * 2
  self.speed_rotation = rotation
  self.image = img
  self.width = img:getWidth()
  self.height = img:getHeight()
  self.quad = love.graphics.newQuad(0, 0, self.width, self.height, self.width, self.height)
  self.ID = ID.background
  self.sine_period = sine_period
  self.sine_multiple = sine_multiple
  self.classification = "Sakura"
  background.backgroundParticles[ID.background] = self
end

Background.seasons.Sakura = common.class("Background.seasons.Sakura", Background.seasons.Sakura, pic)

function Background.seasons:_generateSakura()
	local img = image.seasons_sakura
	local height = img:getHeight()
	local min_x = math.ceil(self.game.stage.height * -0.5)
	local max_x = self.game.stage.width - math.ceil(self.game.stage.height * 0.2)
	local x = math.random(min_x, max_x)
	local y = height * -0.5
	local speed_x = self.seasons.sakura_speed_x(height)
	local speed_y = self.seasons.sakura_speed_y(height)
	local rotation = self.seasons.sakura_rotation(height)
	local sine_period = self.seasons.sakura_sine_period
	local sine_multiple = self.seasons.sakura_sine_multiple

	common.instance(self.seasons.Sakura, self, x, y, img, speed_x, speed_y, rotation, sine_period, sine_multiple)
end

function Background.seasons:_generateTinySakura()
	local img = image.seasons_tinysakura
	local height = img:getHeight()
	local min_x = math.ceil(self.game.stage.height * -0.5)
	local max_x = self.game.stage.width - math.ceil(self.game.stage.height * 0.2)
	local x = math.random(min_x, max_x)
	local y = height * -0.5
	local speed_x = self.seasons.tinysakura_speed_x(height)
	local speed_y = self.seasons.tinysakura_speed_y(height)
	local rotation = self.seasons.tinysakura_rotation(height)
	local sine_period = self.seasons.tinysakura_sine_period
	local sine_multiple = self.seasons.tinysakura_sine_multiple

	common.instance(self.seasons.Sakura, self, x, y, img, speed_x, speed_y, rotation, sine_period, sine_multiple)
end


function Background.seasons:_updateSpring(transitioning)
	self.seasons.sakura_time_to_next = self.seasons.sakura_time_to_next - 1
	self.seasons.tinysakura_time_to_next = self.seasons.tinysakura_time_to_next - 1

	if self.seasons.sakura_time_to_next == 0 then
		self.seasons._generateSakura(self)
		if not transitioning then
			self.seasons.sakura_time_to_next = self.seasons.sakura_freq()
		else
			self.seasons.sakura_time_to_next = self.seasons.sakura_freq() * 2
		end
	end

	if self.seasons.tinysakura_time_to_next == 0 then
		self.seasons._generateTinySakura(self)
		if not transitioning then
			self.seasons.tinysakura_time_to_next = self.seasons.tinysakura_freq()
		else
			self.seasons.tinysakura_time_to_next = self.seasons.tinysakura_freq() * 2
		end
	end
end

Background.seasons.Leaf = {}
function Background.seasons.Leaf:init(background, x, y, img, speed_x, speed_y, rotation)
  ID.background = ID.background + 1
  self.x = x
  self.y = y
  self.speed_x = speed_x
  self.speed_y = speed_y
  self.rotation = math.random() * math.pi * 2
  self.speed_rotation = rotation
  self.image = img
  self.width = img:getWidth()
  self.height = img:getHeight()
  self.quad = love.graphics.newQuad(0, 0, self.width, self.height, self.width, self.height)
  self.ID = ID.background
  self.classification = "GreenLeaf"
  self.fade_in = Background.seasons.greenleaf_fadein_time
  self.RGBTable = {255, 255, 255, 0}
  self.time_to_falloff = Background.seasons.oldleaf_time_to_falloff()
  background.backgroundParticles[ID.background] = self
end

Background.seasons.Leaf = common.class("Background.seasons.Leaf", Background.seasons.Leaf, pic)

function Background.seasons:_generateLeaf()
	local img = image.seasons_greenleaf
	local height = img:getHeight()
	local x = math.random(0, self.game.stage.width)
	local y = math.random(0, self.game.stage.height)
	local speed_x = self.seasons.leaf_speed_x(height)
	local speed_y = self.seasons.leaf_speed_y(height)
	local rotation = self.seasons.leaf_rotation(height)

	common.instance(self.seasons.Leaf, self, x, y, img, speed_x, speed_y, rotation)
end

function Background.seasons:_updateSummer(fading_in)
	if not fading_in then
		self.seasons.leaf_time_to_next = self.seasons.leaf_time_to_next - 1
	end

	if self.seasons.leaf_time_to_next == 0 then
		self.seasons._generateLeaf(self)
		if not fading_in then
			self.seasons.leaf_time_to_next = self.seasons.leaf_freq()
		else
			self.seasons.leaf_time_to_next = self.seasons.leaf_freq() * 2
		end
	end

	for _, instance in pairs(self.backgroundParticles) do
		if instance.classification == "GreenLeaf" and instance.fade_in > 0 then
			local transparency = math.floor(255 * (1 - (instance.fade_in / self.seasons.greenleaf_fadein_time)))
			instance.RGBTable = {255, 255, 255, transparency}
			instance.fade_in = instance.fade_in - 1
		end
	end
end

function Background.seasons:_getNewLeafColor()
	local green_leaves = {}
	for _, instance in pairs(self.backgroundParticles) do
		if instance.classification == "GreenLeaf" and instance.fade_in == 0 and not instance.new_image then
			green_leaves[#green_leaves+1] = instance
		end
	end

	if #green_leaves > 0 then
		local rand_leaf = math.random(#green_leaves)
		local chosen_leaf = green_leaves[rand_leaf]

		local to_image = {image.seasons_orangeleaf, image.seasons_redleaf, image.seasons_yellowleaf}
		local idx = math.random(#to_image)
		chosen_leaf.new_image = to_image[idx]
		chosen_leaf.new_RGBTable = {255, 255, 255, 0}
		chosen_leaf.new_fade = Background.seasons.newcolor_fadein_time
	end
end

function Background.seasons:_updateFall()
	for _, instance in pairs(self.backgroundParticles) do
		if instance.classification == "GreenLeaf" and instance.fade_in > 0 then -- refactor later
			local transparency = math.floor(255 * (1 - (instance.fade_in / self.seasons.greenleaf_fadein_time)))
			instance.RGBTable = {255, 255, 255, transparency}
			instance.fade_in = instance.fade_in - 1
		end

		self.seasons.newcolor_time_to_next = self.seasons.newcolor_time_to_next - 1

		if self.seasons.newcolor_time_to_next == 0 then
			self.seasons._getNewLeafColor(self)
			self.seasons.newcolor_time_to_next = self.seasons.newcolor_fadein_freq()
		end
	end
end

Background.seasons.Snow = {}
function Background.seasons.Snow:init(background, x, y, img, speed_x, speed_y, rotation)
  ID.background = ID.background + 1
  self.x = x
  self.y = y
  self.speed_x = speed_x
  self.speed_y = speed_y
  self.rotation = math.random() * math.pi * 2
  self.speed_rotation = rotation
  self.image = img
  self.width = img:getWidth()
  self.height = img:getHeight()
  self.quad = love.graphics.newQuad(0, 0, self.width, self.height, self.width, self.height)
  self.ID = ID.background
  self.classification = "Snow"
  background.backgroundParticles[ID.background] = self
end

Background.seasons.Snow = common.class("Background.seasons.Snow", Background.seasons.Snow, pic)

function Background.seasons:_generateSnow()
	local image_table = {image.seasons_snow1, image.seasons_snow2, image.seasons_snow3, image.seasons_snow4}
	for i = 5, 18 do
		image_table[i] = image.seasons_snow4
	end
	local image_index = math.random(1, #image_table)
	local img = image_table[image_index]
	local height = img:getHeight()

	local min_x = math.ceil(self.game.stage.height * -0.5)
	local max_x = self.game.stage.width - math.ceil(self.game.stage.height * 0.2)
	local x = math.random(min_x, max_x)
	local y = height * -0.5
	local speed_x = self.seasons.snow_speed_x(height)
	local speed_y = self.seasons.snow_speed_y(height)
	local rotation = self.seasons.snow_rotation(height)

	common.instance(self.seasons.Snow, self, x, y, img, speed_x, speed_y, rotation)
end

function Background.seasons:_updateWinter(transitioning)
	self.seasons.snow_time_to_next = self.seasons.snow_time_to_next - 1
	if not transitioning then
		self.seasons.winter_background_fadein_time = math.max(0, self.seasons.winter_background_fadein_time - 1)
	else
		self.seasons.winter_background_fadeout_time = math.max(0, self.seasons.winter_background_fadeout_time - 1)
	end

	if self.seasons.snow_time_to_next == 0 then
		self.seasons._generateSnow(self)
		if not transitioning then
			self.seasons.snow_time_to_next = self.seasons.snow_freq(self)
		else
			self.seasons.snow_time_to_next = self.seasons.snow_freq(self) * 2
		end
	end
end

function Background.seasons:_moveThings()
	for ID, instance in pairs(self.backgroundParticles) do
		if instance.classification == "Sakura" or instance.classification == "FallingLeaf" or instance.classification == "Snow" then
			instance.x = instance.x + instance.speed_x
			instance.y = instance.y + instance.speed_y
			instance.rotation = instance.rotation + instance.speed_rotation
		end

		if instance.classification == "Sakura" then -- variable falling sakuras
			local current_displacement = math.sin((((self.game.frame + ID * 997) % instance.sine_period)
				/ instance.sine_period) * math.pi * 2) * instance.sine_multiple
			instance.x = instance.x + current_displacement
		end

		if instance.classification == "GreenLeaf" and instance.new_fade and instance.new_fade > 0 then
			local transparency = math.floor(255 * (1 - (instance.new_fade / self.seasons.newcolor_fadein_time)))
			instance.new_RGBTable = {255, 255, 255, transparency}
			instance.new_fade = instance.new_fade - 1

			if instance.new_fade == 0 then
				instance.classification = "OldLeaf"
			end
		end

		if instance.classification == "OldLeaf" then
			instance.time_to_falloff = instance.time_to_falloff - 1

			if instance.time_to_falloff == 0 then
				instance.classification = "FallingLeaf"
			end
		end

		if instance.y > self.game.stage.height + instance.height then
			self.backgroundParticles[instance.ID] = nil
		end
	end
end

function Background.seasons:drawImages()
	self.seasons.background_image:draw()

	if self.seasons.winter_background then
		local transparency
		if self.seasons.daycount >= self.seasons.end_of_fall and self.seasons.daycount < self.seasons.end_of_winter then
			transparency = math.floor(255 * (1 - (self.seasons.winter_background_fadein_time / self.seasons.winter_background_fadein_time_init)))
		else
			transparency = math.floor(255 * (self.seasons.winter_background_fadeout_time / self.seasons.winter_background_fadeout_time_init))
		end
		local RGBTable = {255, 255, 255, transparency}

		self.seasons.background_image2:draw(false, nil, nil, nil, nil, RGBTable)
	end

  for _, instance in spairs(self.backgroundParticles) do
  	if (instance.classification == "GreenLeaf" or instance.classification == "OldLeaf" or instance.classification == "FallingLeaf")
  	and not (instance.new_image and self.seasons.winter_background_fadeout_time == 0) then
  		instance:draw(false, nil, nil, nil, nil, instance.RGBTable)
  		if instance.new_image then
  			instance:draw(false, nil, nil, nil, nil, instance.new_RGBTable, instance.new_image)
  		end
  	end
  end

  for _, instance in spairs(self.backgroundParticles) do
  	if instance.classification == "Sakura" or instance.classification == "Snow" then
			instance:draw()
		end
  end
end

function Background.seasons:update()
	self.seasons._moveThings(self)

	if self.seasons.daycount < self.seasons.end_of_spring then
		self.seasons._updateSpring(self)

	elseif self.seasons.daycount < self.seasons.start_of_summer then
		self.seasons._updateSpring(self, true)
		self.seasons._updateSummer(self, true)

	elseif self.seasons.daycount < self.seasons.end_of_summer then
		self.seasons._updateSummer(self)

	elseif self.seasons.daycount < self.seasons.end_of_fall then
		self.seasons._updateFall(self)

	elseif self.seasons.daycount < self.seasons.end_of_winter then
		self.seasons.winter_background = true
		self.seasons._updateWinter(self)

	elseif self.seasons.daycount < self.seasons.start_of_spring then
		self.seasons._updateWinter(self, true)

	else
		self.seasons.winter_background = false
		self.seasons.winter_background_fadein_time = self.seasons.winter_background_fadein_time_init
		self.seasons.winter_background_fadeout_time = self.seasons.winter_background_fadeout_time_init
	end
	self.seasons.daycount = (self.seasons.daycount + 1) % self.seasons.end_of_cycle
end

function Background.seasons:reset()
	self.seasons.winter_background = false
	self.seasons.winter_background_fadein_time = 180
	self.seasons.winter_background_fadeout_time = 180
	self.seasons.daycount = 0
	self.seasons.sakura_time_to_next = 10
	self.seasons.tinysakura_time_to_next = 3
	self.seasons.newcolor_time_to_next = 30
	self.seasons.leaf_time_to_next = 60
	self.seasons.snow_time_to_next = 12
end


-------------------------------------------------------------------------------
----------------------------------- COLORS -----------------------------------
-------------------------------------------------------------------------------

Background.colors = {
	Background_ID = "Colors",

	daycount = 0,
	blue_fadein_start = 360,
	red_fadein_start = 900,
	green_fadein_start = 1440,
	yellow_fadein_start = 1980,
	end_of_cycle = 2520,
	fadein_count = 0,
	fadein_amount = 180,
	fade_draw = false,
}

function Background.colors:drawImages()
	self.colors.solid_draw:draw()

	if self.colors.fade_draw then
		local transparency = (self.colors.fadein_amount - self.colors.fadein_count) * (255 / self.colors.fadein_amount)
		self.colors.fade_draw:draw(nil, nil, nil, nil, nil, {255, 255, 255, transparency})
	end
end

function Background.colors:update()
	self.colors.daycount = self.colors.daycount + 1
	self.colors.fadein_count = math.max(0, self.colors.fadein_count - 1)

	if self.colors.daycount == self.colors.blue_fadein_start then
		self.colors.fade_draw = self.colors.background_image2
		self.colors.fadein_count = self.colors.fadein_amount

	elseif self.colors.daycount == self.colors.red_fadein_start then
		self.colors.fade_draw = self.colors.background_image3
		self.colors.fadein_count = self.colors.fadein_amount

	elseif self.colors.daycount == self.colors.green_fadein_start then
		self.colors.fade_draw = self.colors.background_image4
		self.colors.fadein_count = self.colors.fadein_amount

	elseif self.colors.daycount == self.colors.yellow_fadein_start then
		self.colors.fade_draw = self.colors.background_image5
		self.colors.fadein_count = self.colors.fadein_amount

	elseif self.colors.daycount == self.colors.end_of_cycle then
		self.colors.fade_draw = false
		self.colors.daycount = self.colors.blue_fadein_start - 1
	end

	if self.colors.fadein_count == 0 and self.colors.fade_draw then
		self.colors.solid_draw = self.colors.fade_draw
		self.colors.fade_draw = false
	end
end

function Background.colors:reset()
	self.colors.daycount = 0
	self.colors.fadein_count = 0
	self.colors.fade_draw = false
	self.colors.solid_draw = self.colors.background_image1
end

Background.list = {
	{background = Background.colors, thumbnail = image.background.colors.thumbnail, full = image.background.colors.white},
	{background = Background.cloud, thumbnail = image.background.cloud.thumbnail, full = image.background.cloud.background},
	{background = Background.starfall, thumbnail = image.background.starfall.thumbnail, full = image.background.starfall.background},
	{background = Background.seasons, thumbnail = image.seasons_background_thumbnail, full = image.seasons_background},
}

Background.current = Background.colors


return common.class("Background", Background)
