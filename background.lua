local love = _G.love
--[[
	Every background should have:
	ID_number - used for the ordering of the backgrounds
	init(game)
	update(dt)
	draw()
	The background class needs to be added, near the end of this file
--]]

local common = require "class.commons"
local image = require 'image'
local Pic = require 'pic'
local spairs = require "utilities".spairs

-------------------------------------------------------------------------------
---------------------------- RABBIT IN A SNOWSTORM ----------------------------
-------------------------------------------------------------------------------
local RabbitInASnowstorm = {ID_number = 5}
function RabbitInASnowstorm:init(game)
	self.game = game
	self.background = Pic:create{
		game = game,
		x = game.stage.x_mid,
		y = game.stage.y_mid,
		image = love.graphics.newImage('images/backgrounds/rabbitsnowstorm/rabbitsnowstorm.png'),
	}
	ID.background_particle = 0
end

function RabbitInASnowstorm:update(dt)
end

function RabbitInASnowstorm:draw(params)
	self.background:draw(params)
end

RabbitInASnowstorm = common.class("RabbitInASnowstorm", RabbitInASnowstorm)


-------------------------------------------------------------------------------
---------------------------------- CHECKMATE ----------------------------------
-------------------------------------------------------------------------------
-- temporary holder, will put into pre-loader later
local checkmate_images = {}
for i = 0, 9 do
	checkmate_images[i] = love.graphics.newImage('images/backgrounds/checkmate/checkmate'..i..'.png')
end

local Checkmate = {ID_number = 1}
function Checkmate:init(game)
	self.game = game
	self.IMAGE_WIDTH = checkmate_images[0]:getWidth()
	self.IMAGE_HEIGHT = checkmate_images[0]:getHeight()
	self.SCROLL_RATE = 220 -- pixels per second
	self.OVERLAY_RATE = 220 -- pixels per second
	self.OVERLAY_DURATION = (self.IMAGE_HEIGHT / self.OVERLAY_RATE) / game.time_step
	self.NEXT_SWAP_TIME = 6.5 -- seconds until next picture swap
	self.swap_time = self.NEXT_SWAP_TIME
	self.images = {}
	ID.background_particle = 0
	self.background = Pic:create{
		game = game,
		x = self.IMAGE_WIDTH * 0.5,
		y = self.IMAGE_HEIGHT * 0.5,
		image = checkmate_images[0],
		container = self.images,
		counter = "background_particle",
	}
	self.image_idx = 0
end

function Checkmate:update(dt)
	local bk = self.background

	-- scroll to the left
	bk.x = bk.x - (dt * self.SCROLL_RATE)
	if bk.x <= self.IMAGE_WIDTH * -0.5 then bk.x = self.IMAGE_WIDTH * 0.5 end

	if self.overlay then
		self.overlay.x = self.overlay.x - (dt * self.SCROLL_RATE)
		if self.overlay.x <= self.IMAGE_WIDTH * -0.5 then
			self.overlay.x = self.IMAGE_WIDTH * 0.5
		end
	end

	-- swap images
	self.swap_time = self.swap_time - dt
	if self.swap_time <= 0 then
		self.background:newImage(checkmate_images[self.image_idx])

		self.swap_time = self.NEXT_SWAP_TIME
		self.image_idx = (self.image_idx + 1) % 10
		local new_bk = checkmate_images[self.image_idx]
		self.overlay = Pic:create{
			game = self.game,
			x = bk.x,
			y = bk.y,
			image = new_bk,
			container = self.images,
			counter = "background_particle",
		}
		self.overlay:change{
			duration = self.OVERLAY_DURATION,
			quad = {y = true, y_percentage = 1, y_anchor = 0},
			exit_func = {
				{self.background.newImage, self.background, new_bk},
				{self.overlay.remove, self.overlay}
			}
		}
	end

	bk:update(dt)
	if self.overlay then self.overlay:update(dt) end
end

function Checkmate:draw(params)
	local draw_params = params or {}
	self.background:draw(draw_params)
	if self.overlay then self.overlay:draw(draw_params) end

	draw_params.x = self.background.x + self.IMAGE_WIDTH
	self.background:draw(draw_params)
	if self.overlay then self.overlay:draw(draw_params) end

	draw_params.x = self.background.x + self.IMAGE_WIDTH * 2
	self.background:draw(draw_params)
	if self.overlay then self.overlay:draw(draw_params) end
end

Checkmate = common.class("Checkmate", Checkmate)


-------------------------------------------------------------------------------
------------------------------------ CLOUD ------------------------------------
-------------------------------------------------------------------------------
local Clouds = {ID_number = 2}
function Clouds:init(game)
	self.game = game
	self.background = Pic:create{
		game = game,
		x = game.stage.x_mid,
		y = game.stage.y_mid,
		image = love.graphics.newImage('images/backgrounds/cloud/sky.png'),
	}
	self.big_clouds, self.medium_clouds, self.small_clouds = {}, {}, {}
	self.big_timer_func = function() return math.random(300, 400) end
	self.medium_timer_func = function() return math.random(450, 550) end
	self.small_timer_func = function() return math.random(700, 800) end
	self.big_timer = math.ceil(self.big_timer_func() * 0.5)
	self.medium_timer = math.ceil(self.medium_timer_func() * 0.5)
	self.small_timer = math.ceil(self.small_timer_func() * 0.5)
	self.big_cloud_images = {
		love.graphics.newImage('images/backgrounds/cloud/bigcloud1.png'),
		love.graphics.newImage('images/backgrounds/cloud/bigcloud2.png'),
		love.graphics.newImage('images/backgrounds/cloud/bigcloud3.png'),
		love.graphics.newImage('images/backgrounds/cloud/bigcloud4.png'),
		love.graphics.newImage('images/backgrounds/cloud/bigcloud5.png'),
		love.graphics.newImage('images/backgrounds/cloud/bigcloud6.png'),
	}
	self.medium_cloud_images = {
		love.graphics.newImage('images/backgrounds/cloud/medcloud1.png'),
		love.graphics.newImage('images/backgrounds/cloud/medcloud2.png'),
		love.graphics.newImage('images/backgrounds/cloud/medcloud3.png'),
		love.graphics.newImage('images/backgrounds/cloud/medcloud4.png'),
		love.graphics.newImage('images/backgrounds/cloud/medcloud5.png'),
		love.graphics.newImage('images/backgrounds/cloud/medcloud6.png'),
	}
	self.small_cloud_images = {
		love.graphics.newImage('images/backgrounds/cloud/smallcloud1.png'),
		love.graphics.newImage('images/backgrounds/cloud/smallcloud2.png'),
		love.graphics.newImage('images/backgrounds/cloud/smallcloud3.png'),
		love.graphics.newImage('images/backgrounds/cloud/smallcloud4.png'),
		love.graphics.newImage('images/backgrounds/cloud/smallcloud5.png'),
		love.graphics.newImage('images/backgrounds/cloud/smallcloud6.png'),
	}
	ID.background_particle = 0

	self:_initClouds()
end

function Clouds:_newCloud(size, starting_x)
	local stage = self.game.stage
	local img, y, container, duration
	if size == "big" then
		img = self.big_cloud_images[math.random(1, #self.big_cloud_images)]
		y = math.random(stage.height * 0.375, stage.height * 0.5)
		container = self.big_clouds
		duration = math.random(200, 280) * (starting_x and 1 - (starting_x / stage.width) or 1)
	elseif size == "medium" then
		img = self.medium_cloud_images[math.random(1, #self.medium_cloud_images)]
		y = math.random(stage.height * 0.25, stage.height * 0.375)
		container = self.medium_clouds
		duration = math.random(300, 420) * (starting_x and 1 - (starting_x / stage.width) or 1)
	elseif size == "small" then
		img = self.small_cloud_images[math.random(1, #self.small_cloud_images)]
		y = math.random(stage.height * 0.1, stage.height * 0.25)
		container = self.small_clouds
		duration = math.random(400, 560) * (starting_x and 1 - (starting_x / stage.width) or 1)
	else
		print("invalid cloud size specified")
	end
	local x = starting_x or -img:getWidth()

	local cloud = Pic:create{
		game = self.game,
		x = x,
		y = y,
		image = img,
		container = container,
		counter = "background_particle"
	}
	cloud:change{
		duration = duration,
		x = stage.width + cloud.width,
		remove = true,
	}
end

function Clouds:_initClouds()
	local init_clouds = {"small", "small", "small", "medium", "medium", "big"}
	for _, size in pairs(init_clouds) do
		self:_newCloud(size, math.random(0, self.game.stage.width * 0.7))
	end

end

function Clouds:update(dt)
	for _, v in pairs(self.big_clouds) do v:update(dt) end
	for _, v in pairs(self.medium_clouds) do v:update(dt) end
	for _, v in pairs(self.small_clouds) do v:update(dt) end

	if self.big_timer <= 0 then
		self:_newCloud("big")
		self.big_timer = self.big_timer_func()
	else
		self.big_timer = self.big_timer - 1
	end

	if self.medium_timer <= 0 then
		self:_newCloud("medium")
		self.medium_timer = self.medium_timer_func()
	else
		self.medium_timer = self.medium_timer - 1
	end

	if self.small_timer <= 0 then
		self:_newCloud("small")
		self.small_timer = self.small_timer_func()
		local c = 0
		for _ in pairs(self.small_clouds) do c = c + 1 end
	else
		self.small_timer = self.small_timer - 1
	end
end

function Clouds:draw(params)
	self.background:draw(params)
	for _, v in spairs(self.small_clouds) do v:draw(params) end
	for _, v in spairs(self.medium_clouds) do v:draw(params) end
	for _, v in spairs(self.big_clouds) do v:draw(params) end
end

Clouds = common.class("Clouds", Clouds)


-------------------------------------------------------------------------------
---------------------------------- STARFALL -----------------------------------
-------------------------------------------------------------------------------
local Starfall = {ID_number = 3}
function Starfall:init(game)
	self.game = game
	self.background = Pic:create{
		game = game,
		x = game.stage.x_mid,
		y = game.stage.y_mid,
		image = love.graphics.newImage('images/backgrounds/starfall/starfall.png'),
	}
	self.star_timer_func = function() return math.random(70, 100) end
	self.star_timer = self.star_timer_func()
	self.stars = {} -- container for stars
	ID.background_particle = 0
end

function Starfall:_generateStar()
	local stage = self.game.stage

	local image_table = {
		love.graphics.newImage('images/backgrounds/starfall/star1.png'),
		love.graphics.newImage('images/backgrounds/starfall/star2.png'),
		love.graphics.newImage('images/backgrounds/starfall/star3.png'),
		love.graphics.newImage('images/backgrounds/starfall/star4.png'),
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

	local star = Pic:create{
		game = self.game,
		x = start_x,
		y = start_y,
		image = img,
		container = self.stars,
		counter = "background_particle",
	}
	star:change{
		duration = duration,
		x = end_x,
		y = end_y,
		rotation = rotation,
		remove = true,
	}
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

function Starfall:draw(params)
	self.background:draw(params)
	for _, v in spairs(self.stars) do v:draw(params) end
end
Starfall = common.class("Starfall", Starfall)


-------------------------------------------------------------------------------
----------------------------------- COLORS -----------------------------------
-------------------------------------------------------------------------------
local Colors = {ID_number = 4}
function Colors:init(game)
	self.game = game
	self.t = 0
	self.current_color = Pic:create{
		game = self.game,
		x = game.stage.x_mid,
		y = game.stage.y_mid,
		image = love.graphics.newImage('images/backgrounds/colors/white.png'),
	}
	self.previous_color = nil
	self.timing_full_cycle = 1800
	self.timings = {
		[0] = love.graphics.newImage('images/backgrounds/colors/white.png'),
		[360] = love.graphics.newImage('images/backgrounds/colors/blue.png'),
		[720] = love.graphics.newImage('images/backgrounds/colors/red.png'),
		[1080] = love.graphics.newImage('images/backgrounds/colors/green.png'),
		[1440] =  love.graphics.newImage('images/backgrounds/colors/yellow.png'),
	}
	ID.background_particle = 0
end

function Colors:_newColor(img)
	local stage = self.game.stage
	self.previous_color = self.current_color
	self.previous_color:change{duration = 180, transparency = 0,
		exit_func = function() self.previous_color = nil end}
	self.current_color = Pic:create{
		game = self.game,
		x = stage.x_mid,
		y = stage.y_mid,
		image = img,
		transparency = 0,
	}
	self.current_color:change{duration = 90, transparency = 255}
end

function Colors:update(dt)
	self.t = (self.t + 1) % self.timing_full_cycle
	self.current_color:update(dt)
	if self.previous_color then self.previous_color:update(dt) end
	local new = self.timings[self.t]
	if new then self:_newColor(new) end
end

function Colors:draw(params)
	if self.previous_color then self.previous_color:draw(params) end
	self.current_color:draw(params)
end
Colors = common.class("Colors", Colors)


-------------------------------------------------------------------------------
local background = {}
background.checkmate = Checkmate
background.cloud = Clouds
background.rabbitsnowstorm = RabbitInASnowstorm
background.starfall = Starfall
background.colors = Colors

local bk_list, total = {}, 0
for k in pairs(background) do
	bk_list[#bk_list+1] = k
	total = total + 1
end
background.total = total

function background:idx_to_str(idx)
	for _, v in pairs(bk_list) do
		if self[v].ID_number == idx then return v end
	end
	return "no background"
end

return common.class("background", background)
