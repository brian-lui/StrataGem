local love = _G.love
--[[
	Draws the background, including animations.
	Every background should have init(stage), draw(), update() methods.
--]]

local common = require "class.commons"
local image = require 'image'
local Pic = require 'pic'

local spairs = require "utilities".spairs

local Background = {}

function Background:init(game)
	self.game = game
	local stage = game.stage
	self.backgroundParticles = {}
	self.cloud.background_image = common.instance(Pic, game, {x = stage.x_mid, y = stage.y_mid, image = image.background.cloud.background})
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

Background.cloud.Cloud = common.class("Background.cloud.Cloud", Background.cloud.Cloud, Pic)

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
---------------------------- RABBIT IN A SNOWSTORM ----------------------------
-------------------------------------------------------------------------------
local RabbitInASnowstorm = {}
function RabbitInASnowstorm:init(game)
	self.game = game
	self.background = common.instance(Pic, game, {
		x = game.stage.x_mid,
		y = game.stage.y_mid,
		image = image.background.rabbitsnowstorm.background,
	})
	ID.background_particle = 0
end

function RabbitInASnowstorm:update(dt)
end

function RabbitInASnowstorm:draw()
	self.background:draw()
end
RabbitInASnowstorm = common.class("RabbitInASnowstorm", RabbitInASnowstorm)

-------------------------------------------------------------------------------
---------------------------------- STARFALL -----------------------------------
-------------------------------------------------------------------------------
local Starfall = {}
function Starfall:init(game)
	self.game = game
	self.background = common.instance(Pic, game, {
		x = game.stage.x_mid,
		y = game.stage.y_mid,
		image = image.background.starfall.background
	})
	self.star_timer_func = function() return math.random(70, 100) end
	self.star_timer = self.star_timer_func()
	self.stars = {} -- container for stars
	ID.background_particle = 0
end

function Starfall:_generateStar()
	local stage = self.game.stage

	local image_table = {
		image.background.starfall.star1,
		image.background.starfall.star2,
		image.background.starfall.star3,
		image.background.starfall.star4
	}
	local image_index = math.random(1, #image_table)
	local img = image_table[image_index]
	local height = img:getHeight()

	local duration = (stage.height / height) * 30
	local rotation = (stage.height / height)
	local start_x = math.random(0.1 * stage.width, 0.8 * stage.width)
	local start_y = -height
	local end_x = start_x + stage.width * math.random(0.15, 0.15)
	local end_y = stage.height + height

	local star = common.instance(Pic, self.game,
		{x = start_x, y = start_y, image = img, container = self.stars, counter = "background_particle"})
	star:moveTo{duration = duration, x = end_x, y = end_y, rotation = rotation, exit = true}
end

function Starfall:update(dt)
	for _, v in pairs(self.stars) do v:update(dt) end
	if self.star_timer <= 0 then 
		self:_generateStar()
		self.star_timer = self.star_timer_func()
	else
		self.star_timer = self.star_timer - 1
	end
end

function Starfall:draw()
	self.background:draw()
	for _, v in pairs(self.stars) do v:draw() end
end
Starfall = common.class("Starfall", Starfall)


-------------------------------------------------------------------------------
----------------------------------- COLORS -----------------------------------
-------------------------------------------------------------------------------
local Colors = {}
function Colors:init(game)
	self.game = game
	self.t = 0
	self.colors = {} -- container for stars
	self.current_color = common.instance(Pic, self.game, 
		{x = game.stage.x_mid, y = game.stage.y_mid, image = image.background.colors.white})
	self.previous_color = nil
	ID.background_particle = 0
end

function Colors:_newColor(image)
	local stage = self.game.stage
	self.previous_color = self.current_color
	self.previous_color:moveTo{duration = 180, transparency = 0,
		exit = {function() self.previous_color = nil end}}
	self.current_color = common.instance(Pic, self.game, 
		{x = stage.x_mid, y = stage.y_mid, image = image, transparency = 0})
	self.current_color:moveTo{duration = 90, transparency = 255}
end

function Colors:update(dt)
	self.t = (self.t + 1) % 1800
	self.current_color:update(dt)
	if self.previous_color then self.previous_color:update(dt) end

	if self.t % 1800 == 360 then
		self:_newColor(image.background.colors.blue)
	elseif self.t % 1800 == 720 then
		self:_newColor(image.background.colors.red)
	elseif self.t % 1800 == 1080 then
		self:_newColor(image.background.colors.green)
	elseif self.t % 1800 == 1440 then
		self:_newColor(image.background.colors.yellow)
	elseif self.t % 1800 == 0 then
		self:_newColor(image.background.colors.white)
	end
end

function Colors:draw()
	if self.previous_color then self.previous_color:draw() end
	self.current_color:draw()
end
Colors = common.class("Colors", Colors)

-- Change this to key = name, value = table later
Background.list = {
	{background = "RabbitInASnowstorm", thumbnail = image.background.colors.thumbnail, full = image.background.colors.white},
	{background = "Colors", thumbnail = image.background.colors.thumbnail, full = image.background.colors.white},
	{background = Background.cloud, thumbnail = image.background.cloud.thumbnail, full = image.background.cloud.background},
	{background = "Starfall", thumbnail = image.background.starfall.thumbnail, full = image.background.starfall.background},
}

--]]

Background.RabbitInASnowstorm = RabbitInASnowstorm
Background.Starfall = Starfall
Background.Colors = Colors

return common.class("Background", Background)
