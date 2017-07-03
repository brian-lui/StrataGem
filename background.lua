--[[
	Draws the background, including animations.
	Every background should have:
	Background.XYZ.update()
	Background.XYZ.drawImages()
	Background.XYZ.reset()
--]]

local class = require 'middleclass'
require 'inits'
local image = require 'image'
local particles = game.particles
local pic = require 'pic'
local stage = game.stage

local BackgroundParticles = {}
Background = {}


-------------------------------------------------------------------------------
------------------------------------ CLOUD ------------------------------------
-------------------------------------------------------------------------------

Background.Cloud = {
	Background_ID = "Cloud",
	background_image = pic:new{x = stage.x_mid, y = stage.y_mid,
		image = image.background.cloud.background},
	big_cloud_speed = function() return 0.25 * (math.random() + 1) end,
	med_cloud_speed = function() return 0.35 * (math.random() + 1) end,
	small_cloud_speed = function() return 0.6 * (math.random() + 1) end,
	daycount = 0
}

Background.Cloud.Cloud = class('Background.Cloud.Cloud', pic)
function Background.Cloud.Cloud:initialize(x, y, image, speed, classification)
  ID.background = ID.background + 1
  self.x = x
  self.y = y
  self.speed_x = speed
  self.image = image
  self.width = image:getWidth()
  self.height = image:getHeight()
  self.quad = love.graphics.newQuad(0, 0, self.width, self.height, self.width, self.height)
  self.classification = classification
  self.ID = ID.background
  BackgroundParticles[ID.background] = self
end

local function Cloud_generateBigCloud(starting_x)
	local x = starting_x or image.background.cloud.bigcloud1:getWidth() * -1
	local y = math.random(0, stage.height / 4)
	local speed = Background.Cloud.big_cloud_speed()
	local image = {
		image.background.cloud.bigcloud1,
		image.background.cloud.bigcloud2,
		image.background.cloud.bigcloud3,
		image.background.cloud.bigcloud4,
		image.background.cloud.bigcloud5,
		image.background.cloud.bigcloud6
	}
	local image_index = math.random(1, #image)

	Background.Cloud.Cloud:new(x, y, image[image_index], speed, "Bigcloud")
end

local function Cloud_generateMedCloud(starting_x)
	local x = starting_x or image.background.cloud.medcloud1:getWidth() * -1
	local y = math.random(stage.height / 4, stage.height * 3/8)
	local speed = Background.Cloud.med_cloud_speed()
	local image = {
		image.background.cloud.medcloud1,
		image.background.cloud.medcloud2,
		image.background.cloud.medcloud3,
		image.background.cloud.medcloud4,
		image.background.cloud.medcloud5,
		image.background.cloud.medcloud6
	}
	local image_index = math.random(1, #image)

	Background.Cloud.Cloud:new(x, y, image[image_index], speed, "Medcloud")
end

local function Cloud_generateSmallCloud(starting_x)
	local x = starting_x or image.background.cloud.smallcloud1:getWidth() * -1
	local y = math.random(stage.height * 3/8, stage.height / 2)
	local speed = Background.Cloud.small_cloud_speed()
	local image = {
		image.background.cloud.smallcloud1,
		image.background.cloud.smallcloud2,
		image.background.cloud.smallcloud3,
		image.background.cloud.smallcloud4,
		image.background.cloud.smallcloud5,
		image.background.cloud.smallcloud6
	}
	local image_index = math.random(1, #image)

	Background.Cloud.Cloud:new(x, y, image[image_index], speed, "Smallcloud")
end

local function Cloud_initClouds()
	local starting_x = function()	return math.random(0, math.ceil(stage.width * 0.7)) end

	Cloud_generateBigCloud(starting_x())
	for i = 1, 2 do Cloud_generateMedCloud(starting_x()) end
	for i = 1, 3 do Cloud_generateSmallCloud(starting_x()) end
end

function Background.Cloud.drawImages()
	Background.Cloud.background_image:draw()

  for ID, instance in spairs(BackgroundParticles) do
    if instance.classification == "Smallcloud" then
      instance:draw()
  	end
  end

  for ID, instance in spairs(BackgroundParticles) do
    if instance.classification == "Medcloud" then
      instance:draw()
  	end
  end

  for ID, instance in spairs(BackgroundParticles) do
    if instance.classification == "Bigcloud" then
      instance:draw()
  	end
  end
end

function Background.Cloud.update()
	Background.Cloud.daycount = Background.Cloud.daycount + 1
	if #BackgroundParticles == 0 and Background.Cloud.daycount < 100 then
		Cloud_initClouds()
	end

	for ID, instance in pairs(BackgroundParticles) do
		instance.x = instance.x + instance.speed_x
		if instance.x > stage.width + instance.width then BackgroundParticles[instance.ID] = nil end
	end

	if Background.Cloud.daycount % 721 == 0 then Cloud_generateBigCloud() end
	if Background.Cloud.daycount % 487 == 0 then Cloud_generateMedCloud()	end
	if Background.Cloud.daycount % 361 == 0 then Cloud_generateSmallCloud()	end
end

function Background.Cloud.reset()
	BackgroundParticles = {}
	Cloud_initClouds()
end

-------------------------------------------------------------------------------
---------------------------------- STARFALL -----------------------------------
-------------------------------------------------------------------------------

Background.Starfall = {
	Background_ID = "Starfall",
	background_image = pic:new{x = stage.x_mid, y = stage.y_mid,
		image = image.background.starfall.background},
	star_speed_x = function(height) return (stage.height / height) * 0.1 end,
	star_speed_y = function(height) return (stage.height / height) * 0.15 end,
	star_rotation = function(height) return (stage.height / height) * 0.005 end,
	star_freq = function() return math.random(70, 100) end,
	time_to_next = 30
}

Background.Starfall.Star = class('Background.Starfall.Star', pic)
function Background.Starfall.Star:initialize(x, y, image, speed_x, speed_y, rotation)
  ID.background = ID.background + 1
  self.x = x
  self.y = y
  self.speed_x = speed_x
  self.speed_y = speed_y
  self.rotation = rotation
  self.speed_rotation = rotation
  self.image = image
  self.width = image:getWidth()
  self.height = image:getHeight()
  self.quad = love.graphics.newQuad(0, 0, self.width, self.height, self.width, self.height)
  self.ID = ID.background
  BackgroundParticles[ID.background] = self
end

local function Starfall_generateStar()
	local image_table = {image.background.starfall.star1, image.background.starfall.star2, image.background.starfall.star3, image.background.starfall.star4}
	local image_index = math.random(1, #image_table)
	local image = image_table[image_index]
	local height = image:getHeight()

	local min_x = math.ceil(stage.height * -0.5)
	local max_x = stage.width - math.ceil(stage.height * 0.2)
	local x = math.random(min_x, max_x)
	local y = height * -0.5
	local speed_x = Background.Starfall.star_speed_x(height)
	local speed_y = Background.Starfall.star_speed_y(height)
	local rotation = Background.Starfall.star_rotation(height)

	Background.Starfall.Star:new(x, y, image, speed_x, speed_y, rotation)
end

function Background.Starfall.drawImages()
	Background.Starfall.background_image:draw()

  for ID, instance in spairs(BackgroundParticles) do
    instance:draw()
  end
end

function Background.Starfall.update()
	for ID, instance in pairs(BackgroundParticles) do
		instance.x = instance.x + instance.speed_x
		instance.y = instance.y + instance.speed_y
		instance.rotation = instance.rotation + instance.speed_rotation

		if instance.y > stage.height + instance.height then BackgroundParticles[instance.ID] = nil end
	end

	Background.Starfall.time_to_next = Background.Starfall.time_to_next - 1

	if Background.Starfall.time_to_next == 0 then
		Starfall_generateStar()
		Background.Starfall.time_to_next = Background.Starfall.star_freq()
	end
end

function Background.Starfall.reset()
	Background.Starfall.time_to_next = 30
	BackgroundParticles = {}
end


-------------------------------------------------------------------------------
----------------------------------- SEASONS -----------------------------------
-------------------------------------------------------------------------------

Background.Seasons = {
	Background_ID = "Seasons",
	background_image = pic:new{x = stage.x_mid, y = stage.y_mid,
		image = image.seasons_background},
	background_image2 = pic:new{x = stage.x_mid, y = stage.y_mid,
		image = image.seasons_background2},

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

	sakura_speed_x = function(height) return (stage.height / height) * 0.4 end,
	sakura_speed_y = function(height) return (stage.height / height) * 0.6 end,
	sakura_rotation = function(height) return (stage.height / height) * 0.0004 end,
	sakura_freq = function() return math.random(70, 100) end,
	sakura_time_to_next = 10,
	sakura_sine_period = 180, -- frames per sine wave
	sakura_sine_multiple = 3, -- multiple sine_period by this to get the total displacement

	tinysakura_speed_x = function(height) return (stage.height / height) * 0.02 end,
	tinysakura_speed_y = function(height) return (stage.height / height) * 0.03 end,
	tinysakura_rotation = function(height) return (stage.height / height) * 0.0002 end,
	tinysakura_freq = function() return math.random(70, 100) end,
	tinysakura_time_to_next = 3,
	tinysakura_sine_period = 180,
	tinysakura_sine_multiple = 1.5,

	leaf_speed_x = function(height) return math.ceil((stage.height / height) * (math.random() - 0.5) * 4) end,
	leaf_speed_y = function(height) return (stage.height / height) * 2 end,
	leaf_rotation = function(height) return (stage.height / height) * 0.002 end,
	greenleaf_fadein_time = 300,
	newcolor_fadein_time = 450, -- double this too later
	newcolor_fadein_freq = function() return math.random(120, 180) end,
	newcolor_time_to_next = 30,
	oldleaf_time_to_falloff = function() return math.random(1200, 1500) end,
	leaf_freq = function() return math.random(70, 100) end,
	leaf_time_to_next = 60,

	snow_speed_x = function(height) return (stage.height / height^0.5) / 15 end,
	snow_speed_y = function(height) return (stage.height / height^0.5) / 10 end,
	snow_rotation = function(height) return (stage.height / height^0.5) / 1000 end,
	snow_freq = function() return math.random(30, 50) end,
	snow_time_to_next = 12,
}

Background.Seasons.winter_background_fadein_time_init = Background.Seasons.winter_background_fadein_time
Background.Seasons.winter_background_fadeout_time_init = Background.Seasons.winter_background_fadeout_time

Background.Seasons.Sakura = class('Background.Seasons.Sakura', pic)
function Background.Seasons.Sakura:initialize(x, y, image, speed_x, speed_y, rotation, sine_period, sine_multiple)
  ID.background = ID.background + 1
  self.x = x
  self.y = y
  self.speed_x = speed_x
  self.speed_y = speed_y
  self.rotation = math.random() * math.pi * 2
  self.speed_rotation = rotation
  self.image = image
  self.width = image:getWidth()
  self.height = image:getHeight()
  self.quad = love.graphics.newQuad(0, 0, self.width, self.height, self.width, self.height)
  self.ID = ID.background
  self.sine_period = sine_period
  self.sine_multiple = sine_multiple
  self.classification = "Sakura"
  BackgroundParticles[ID.background] = self
end

function Background.Seasons._generateSakura()
	local image = image.seasons_sakura
	local height = image:getHeight()
	local min_x = math.ceil(stage.height * -0.5)
	local max_x = stage.width - math.ceil(stage.height * 0.2)
	local x = math.random(min_x, max_x)
	local y = height * -0.5
	local speed_x = Background.Seasons.sakura_speed_x(height)
	local speed_y = Background.Seasons.sakura_speed_y(height)
	local rotation = Background.Seasons.sakura_rotation(height)
	local sine_period = Background.Seasons.sakura_sine_period
	local sine_multiple = Background.Seasons.sakura_sine_multiple

	Background.Seasons.Sakura:new(x, y, image, speed_x, speed_y, rotation, sine_period, sine_multiple)
end

function Background.Seasons._generateTinySakura()
	local image = image.seasons_tinysakura
	local height = image:getHeight()
	local min_x = math.ceil(stage.height * -0.5)
	local max_x = stage.width - math.ceil(stage.height * 0.2)
	local x = math.random(min_x, max_x)
	local y = height * -0.5
	local speed_x = Background.Seasons.tinysakura_speed_x(height)
	local speed_y = Background.Seasons.tinysakura_speed_y(height)
	local rotation = Background.Seasons.tinysakura_rotation(height)
	local sine_period = Background.Seasons.tinysakura_sine_period
	local sine_multiple = Background.Seasons.tinysakura_sine_multiple

	Background.Seasons.Sakura:new(x, y, image, speed_x, speed_y, rotation, sine_period, sine_multiple)
end


function Background.Seasons._updateSpring(transitioning)
	Background.Seasons.sakura_time_to_next = Background.Seasons.sakura_time_to_next - 1
	Background.Seasons.tinysakura_time_to_next = Background.Seasons.tinysakura_time_to_next - 1

	if Background.Seasons.sakura_time_to_next == 0 then
		Background.Seasons._generateSakura()
		if not transitioning then
			Background.Seasons.sakura_time_to_next = Background.Seasons.sakura_freq()
		else
			Background.Seasons.sakura_time_to_next = Background.Seasons.sakura_freq() * 2
		end
	end

	if Background.Seasons.tinysakura_time_to_next == 0 then
		Background.Seasons._generateTinySakura()
		if not transitioning then
			Background.Seasons.tinysakura_time_to_next = Background.Seasons.tinysakura_freq()
		else
			Background.Seasons.tinysakura_time_to_next = Background.Seasons.tinysakura_freq() * 2
		end
	end
end

Background.Seasons.Leaf = class('Background.Seasons.Leaf', pic)
function Background.Seasons.Leaf:initialize(x, y, image, speed_x, speed_y, rotation)
  ID.background = ID.background + 1
  self.x = x
  self.y = y
  self.speed_x = speed_x
  self.speed_y = speed_y
  self.rotation = math.random() * math.pi * 2
  self.speed_rotation = rotation
  self.image = image
  self.width = image:getWidth()
  self.height = image:getHeight()
  self.quad = love.graphics.newQuad(0, 0, self.width, self.height, self.width, self.height)
  self.ID = ID.background
  self.classification = "GreenLeaf"
  self.fade_in = Background.Seasons.greenleaf_fadein_time
  self.RGBTable = {255, 255, 255, 0}
  self.time_to_falloff = Background.Seasons.oldleaf_time_to_falloff()
  BackgroundParticles[ID.background] = self
end

function Background.Seasons._generateLeaf()
	local image = image.seasons_greenleaf
	local height = image:getHeight()
	local width = image:getWidth()
	local x = math.random(0, stage.width)
	local y = math.random(0, stage.height)
	local speed_x = Background.Seasons.leaf_speed_x(height)
	local speed_y = Background.Seasons.leaf_speed_y(height)
	local rotation = Background.Seasons.leaf_rotation(height)

	Background.Seasons.Leaf:new(x, y, image, speed_x, speed_y, rotation)
end

function Background.Seasons._updateSummer(fading_in)
	if not fading_in then
		Background.Seasons.leaf_time_to_next = Background.Seasons.leaf_time_to_next - 1
	end

	if Background.Seasons.leaf_time_to_next == 0 then
		Background.Seasons._generateLeaf()
		if not fading_in then
			Background.Seasons.leaf_time_to_next = Background.Seasons.leaf_freq()
		else
			Background.Seasons.leaf_time_to_next = Background.Seasons.leaf_freq() * 2
		end
	end

	for ID, instance in pairs(BackgroundParticles) do
		if instance.classification == "GreenLeaf" and instance.fade_in > 0 then
			local transparency = math.floor(255 * (1 - (instance.fade_in / Background.Seasons.greenleaf_fadein_time)))
			instance.RGBTable = {255, 255, 255, transparency}
			instance.fade_in = instance.fade_in - 1
		end
	end
end

function Background.Seasons._getNewLeafColor()
	local green_leaves = {}
	for ID, instance in pairs(BackgroundParticles) do
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
		chosen_leaf.new_fade = Background.Seasons.newcolor_fadein_time
	end
end

function Background.Seasons._updateFall()
	for ID, instance in pairs(BackgroundParticles) do
		if instance.classification == "GreenLeaf" and instance.fade_in > 0 then -- refactor later
			local transparency = math.floor(255 * (1 - (instance.fade_in / Background.Seasons.greenleaf_fadein_time)))
			instance.RGBTable = {255, 255, 255, transparency}
			instance.fade_in = instance.fade_in - 1
		end

		Background.Seasons.newcolor_time_to_next = Background.Seasons.newcolor_time_to_next - 1

		if Background.Seasons.newcolor_time_to_next == 0 then
			Background.Seasons._getNewLeafColor()
			Background.Seasons.newcolor_time_to_next = Background.Seasons.newcolor_fadein_freq()
		end
	end
end

Background.Seasons.Snow = class('Background.Seasons.Snow', pic)
function Background.Seasons.Snow:initialize(x, y, image, speed_x, speed_y, rotation)
  ID.background = ID.background + 1
  self.x = x
  self.y = y
  self.speed_x = speed_x
  self.speed_y = speed_y
  self.rotation = math.random() * math.pi * 2
  self.speed_rotation = rotation
  self.image = image
  self.width = image:getWidth()
  self.height = image:getHeight()
  self.quad = love.graphics.newQuad(0, 0, self.width, self.height, self.width, self.height)
  self.ID = ID.background
  self.classification = "Snow"
  BackgroundParticles[ID.background] = self
end

function Background.Seasons._generateSnow()
	local image_table = {image.seasons_snow1, image.seasons_snow2, image.seasons_snow3, image.seasons_snow4}
	for i = 5, 18 do
		image_table[i] = image.seasons_snow4
	end
	local image_index = math.random(1, #image_table)
	local image = image_table[image_index]
	local height = image:getHeight()

	local min_x = math.ceil(stage.height * -0.5)
	local max_x = stage.width - math.ceil(stage.height * 0.2)
	local x = math.random(min_x, max_x)
	local y = height * -0.5
	local speed_x = Background.Seasons.snow_speed_x(height)
	local speed_y = Background.Seasons.snow_speed_y(height)
	local rotation = Background.Seasons.snow_rotation(height)

	Background.Seasons.Snow:new(x, y, image, speed_x, speed_y, rotation)
end

function Background.Seasons._updateWinter(transitioning)
	Background.Seasons.snow_time_to_next = Background.Seasons.snow_time_to_next - 1
	if not transitioning then
		Background.Seasons.winter_background_fadein_time = math.max(0, Background.Seasons.winter_background_fadein_time - 1)
	else
		Background.Seasons.winter_background_fadeout_time = math.max(0, Background.Seasons.winter_background_fadeout_time - 1)
	end

	if Background.Seasons.snow_time_to_next == 0 then
		Background.Seasons._generateSnow()
		if not transitioning then
			Background.Seasons.snow_time_to_next = Background.Seasons.snow_freq()
		else
			Background.Seasons.snow_time_to_next = Background.Seasons.snow_freq() * 2
		end
	end
end

function Background.Seasons._moveThings()
	for ID, instance in pairs(BackgroundParticles) do
		if instance.classification == "Sakura" or instance.classification == "FallingLeaf" or instance.classification == "Snow" then
			instance.x = instance.x + instance.speed_x
			instance.y = instance.y + instance.speed_y
			instance.rotation = instance.rotation + instance.speed_rotation
		end

		if instance.classification == "Sakura" then -- variable falling sakuras
			local current_displacement = math.sin((((frame + ID * 997) % instance.sine_period)
				/ instance.sine_period) * math.pi * 2) * instance.sine_multiple
			instance.x = instance.x + current_displacement
		end

		if instance.classification == "GreenLeaf" and instance.new_fade and instance.new_fade > 0 then
			local transparency = math.floor(255 * (1 - (instance.new_fade / Background.Seasons.newcolor_fadein_time)))
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

		if instance.y > stage.height + instance.height then BackgroundParticles[instance.ID] = nil end
	end
end

function Background.Seasons.drawImages()
	Background.Seasons.background_image:draw()

	if Background.Seasons.winter_background then
		local transparency = {}
		if Background.Seasons.daycount >= Background.Seasons.end_of_fall and Background.Seasons.daycount < Background.Seasons.end_of_winter then
			transparency = math.floor(255 * (1 - (Background.Seasons.winter_background_fadein_time / Background.Seasons.winter_background_fadein_time_init)))
		else
			transparency = math.floor(255 * (Background.Seasons.winter_background_fadeout_time / Background.Seasons.winter_background_fadeout_time_init))
		end
		local RGBTable = {255, 255, 255, transparency}

		Background.Seasons.background_image2:draw(false, nil, nil, nil, nil, RGBTable)
	end

  for ID, instance in spairs(BackgroundParticles) do
  	if (instance.classification == "GreenLeaf" or instance.classification == "OldLeaf" or instance.classification == "FallingLeaf")
  	and not (instance.new_image and Background.Seasons.winter_background_fadeout_time == 0) then
  		instance:draw(false, nil, nil, nil, nil, instance.RGBTable)
  		if instance.new_image then
  			instance:draw(false, nil, nil, nil, nil, instance.new_RGBTable, instance.new_image)
  		end
  	end
  end

  for ID, instance in spairs(BackgroundParticles) do
  	if instance.classification == "Sakura" or instance.classification == "Snow" then instance:draw() end
  end
end

function Background.Seasons.update()
	Background.Seasons._moveThings()

	if Background.Seasons.daycount < Background.Seasons.end_of_spring then
		Background.Seasons._updateSpring()

	elseif Background.Seasons.daycount < Background.Seasons.start_of_summer then
		Background.Seasons._updateSpring(true)
		Background.Seasons._updateSummer(true)

	elseif Background.Seasons.daycount < Background.Seasons.end_of_summer then
		Background.Seasons._updateSummer()

	elseif Background.Seasons.daycount < Background.Seasons.end_of_fall then
		Background.Seasons._updateFall()

	elseif Background.Seasons.daycount < Background.Seasons.end_of_winter then
		Background.Seasons.winter_background = true
		Background.Seasons._updateWinter()

	elseif Background.Seasons.daycount < Background.Seasons.start_of_spring then
		Background.Seasons._updateWinter(true)

	else
		Background.Seasons.winter_background = false
		Background.Seasons.winter_background_fadein_time = Background.Seasons.winter_background_fadein_time_init
		Background.Seasons.winter_background_fadeout_time = Background.Seasons.winter_background_fadeout_time_init
	end
	Background.Seasons.daycount = (Background.Seasons.daycount + 1) % Background.Seasons.end_of_cycle
end

function Background.Seasons.reset()
	Background.Seasons.winter_background = false
	Background.Seasons.winter_background_fadein_time = 180
	Background.Seasons.winter_background_fadeout_time = 180
	Background.Seasons.daycount = 0
	Background.Seasons.sakura_time_to_next = 10
	Background.Seasons.tinysakura_time_to_next = 3
	Background.Seasons.newcolor_time_to_next = 30
	Background.Seasons.leaf_time_to_next = 60
	Background.Seasons.snow_time_to_next = 12
end


-------------------------------------------------------------------------------
----------------------------------- COLORS -----------------------------------
-------------------------------------------------------------------------------

Background.Colors = {
	Background_ID = "Colors",
	background_image1 = pic:new{x = stage.x_mid, y = stage.y_mid, image = image.background.colors.white},
	background_image2 = pic:new{x = stage.x_mid, y = stage.y_mid, image = image.background.colors.blue},
	background_image3 = pic:new{x = stage.x_mid, y = stage.y_mid, image = image.background.colors.red},
	background_image4 = pic:new{x = stage.x_mid, y = stage.y_mid, image = image.background.colors.green},
	background_image5 = pic:new{x = stage.x_mid, y = stage.y_mid, image = image.background.colors.yellow},

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
Background.Colors.solid_draw = Background.Colors.background_image1

function Background.Colors.drawImages()
	Background.Colors.solid_draw:draw()

	if Background.Colors.fade_draw then
		local transparency = (Background.Colors.fadein_amount - Background.Colors.fadein_count) * (255 / Background.Colors.fadein_amount)
		Background.Colors.fade_draw:draw(nil, nil, nil, nil, nil, {255, 255, 255, transparency})
	end
end

function Background.Colors.update()
	Background.Colors.daycount = Background.Colors.daycount + 1
	Background.Colors.fadein_count = math.max(0, Background.Colors.fadein_count - 1)

	if Background.Colors.daycount == Background.Colors.blue_fadein_start then
		Background.Colors.fade_draw = Background.Colors.background_image2
		Background.Colors.fadein_count = Background.Colors.fadein_amount

	elseif Background.Colors.daycount == Background.Colors.red_fadein_start then
		Background.Colors.fade_draw = Background.Colors.background_image3
		Background.Colors.fadein_count = Background.Colors.fadein_amount

	elseif Background.Colors.daycount == Background.Colors.green_fadein_start then
		Background.Colors.fade_draw = Background.Colors.background_image4
		Background.Colors.fadein_count = Background.Colors.fadein_amount

	elseif Background.Colors.daycount == Background.Colors.yellow_fadein_start then
		Background.Colors.fade_draw = Background.Colors.background_image5
		Background.Colors.fadein_count = Background.Colors.fadein_amount

	elseif Background.Colors.daycount == Background.Colors.end_of_cycle then
		Background.Colors.fade_draw = false
		Background.Colors.daycount = Background.Colors.blue_fadein_start - 1
	end

	if Background.Colors.fadein_count == 0 and Background.Colors.fade_draw then
		Background.Colors.solid_draw = Background.Colors.fade_draw
		Background.Colors.fade_draw = false
	end
end

function Background.Colors.reset()
	Background.Colors.daycount = 0
	Background.Colors.fadein_count = 0
	Background.Colors.fade_draw = false
	Background.Colors.solid_draw = Background.Colors.background_image1
end

Background.list = {
	{background = Background.Colors, thumbnail = image.background.colors.thumbnail, full = image.background.colors.white},
	{background = Background.Cloud, thumbnail = image.background.cloud.thumbnail, full = image.background.cloud.background},
	{background = Background.Starfall, thumbnail = image.background.starfall.thumbnail, full = image.background.starfall.background},
	{background = Background.Seasons, thumbnail = image.seasons_background_thumbnail, full = image.seasons_background},
}

Background.current = Background.Colors


return Background
