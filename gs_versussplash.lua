--[[
	This is the gamestate module for the pre-game versus splash screen.
	TODO: this can multithread-load images 
--]]

local common = require "class.commons"
local images = require "images"
local spairs = require "/helpers/utilities".spairs

local VersusSplash = {name = "VersusSplash"}

-- refer to game.lua for instructions for createButton and createImage
function VersusSplash:createButton(params)
	return self:_createButton(VersusSplash, params)
end

function VersusSplash:createImage(params)
	return self:_createImage(VersusSplash, params)
end

function VersusSplash:init()
	VersusSplash.ui = {
		clickable = {},
		static = {},
		popup_clickable = {},
		popup_static = {},
	}

	-- timings
	self.POSE_WAIT_TIME = 10 -- time before poses appear
	self.POSE_APPEAR_TIME = 30 -- time for action pose tween
	self.POSE_SHADOW_TIME = 50 -- time for pose shadow tween
	self.VS_WAIT_TIME = 40 -- time before vs icon appears
	self.NAMES_WAIT_TIME = 50 -- time before vs character names appear
	self.WORDS_APPEAR_TIME = 20 -- time for vs icon/character name tween
	self.WORDBUBBLE_WAIT_TIME = 90 -- time before word bubbles appear
	self.WORDBUBBLE_APPEAR_TIME = 45 -- time for word bubbles tween
	self.TEXT_WAIT_TIME = 150 -- time before text appears
	self.NEXT_SCREEN_TIME = 300 -- time before going to next screen
end

function VersusSplash:enter()
	self.uielements:clearScreenUIColor()
	self.private_framecount = 0 -- screenshake and text depends on framecount

	VersusSplash.current_background = common.instance(self.background[self.current_background_name], self)

	local stage = self.stage
	local p1char = self.p1.character_name:lower()
	local p2char = self.p2.character_name:lower()
	local p1_action_image = images["portraits_action_" .. p1char]
	local p2_action_image = images["portraits_action_" .. p2char]

	-- action poses and associated shadow
	self.p1_action_pose = VersusSplash.createImage(self, {
		name = "p1_action_pose",
		image = p1_action_image,
		duration = 0,
		end_x = -p1_action_image:getWidth() * 0.5,
		end_y = p1_action_image:getHeight() * 0.5,
	})
	self.p1_action_pose:wait(self.POSE_WAIT_TIME)
	self.p1_action_pose:change{
		duration = self.POSE_APPEAR_TIME,
		x = p1_action_image:getWidth() * 0.5,
		easing = "outQuart",
	}

	self.p1_shadow_pose = VersusSplash.createImage(self, {
		name = "p1_shadow_pose",
		image = images["portraits_shadow_" .. p1char],
		duration = 0,
		end_x = p1_action_image:getWidth() * -0.5,
		end_y = p1_action_image:getHeight() * 0.5,
	})
	self.p1_shadow_pose:wait(self.POSE_WAIT_TIME)
	self.p1_shadow_pose:change{
		duration = self.POSE_APPEAR_TIME,
		x = stage.width * 0.025 + p1_action_image:getWidth() * 0.5,
		easing = "outQuart",
	}

	self.p2_action_pose = VersusSplash.createImage(self, {
		name = "p2_action_pose",
		image = p2_action_image,
		duration = 0,
		end_x = stage.width + p2_action_image:getWidth() * 0.5,
		end_y = stage.height - p2_action_image:getHeight() * 0.5,
		h_flip = true,
	})
	self.p2_action_pose:wait(self.POSE_WAIT_TIME)
	self.p2_action_pose:change{
		duration = self.POSE_APPEAR_TIME,
		x = stage.width - p2_action_image:getWidth() * 0.5,
		easing = "outQuart",
	}

	self.p2_shadow_pose = VersusSplash.createImage(self, {
		name = "p2_shadow_pose",
		image = images["portraits_shadow_" .. p2char],
		duration = 0,
		end_x = stage.width + p2_action_image:getWidth() * 0.5,
		end_y = stage.height - p2_action_image:getHeight() * 0.5,
		h_flip = true,
	})
	self.p2_shadow_pose:wait(self.POSE_WAIT_TIME)
	self.p2_shadow_pose:change{
		duration = self.POSE_APPEAR_TIME,
		x = stage.width * 0.975 - p2_action_image:getWidth() * 0.5,
		easing = "outQuart",
	}

	-- vs icon and small names
	self.vs_icon = VersusSplash.createImage(self, {
		name = "vs_icon",
		image = images.vs_vs,
		duration = 0,
		end_x = stage.width * 0.5,
		end_y = stage.height * 0.5,
		end_scaling = 5,
		end_transparency = 0,
	})
	self.vs_icon:wait(self.VS_WAIT_TIME)
	self.vs_icon:change{duration = 0, transparency = 1}
	self.vs_icon:change{
		duration = self.WORDS_APPEAR_TIME,
		scaling = 1,
		easing = "outCubic",
		exit_func = {self.uielements.screenshake, self.uielements, 2}
	}

	self.p1_name = VersusSplash.createImage(self, {
		name = "p1_name",
		image = images["vs_smallword_" .. p1char],
		duration = 0,
		end_x = p1_action_image:getWidth() * 0.5,
		end_y = p1_action_image:getHeight() * 0.65,
		end_scaling = 5,
		end_transparency = 0,
	})
	self.p1_name:wait(self.NAMES_WAIT_TIME)
	self.p1_name:change{duration = 0, transparency = 1}
	self.p1_name:change{
		duration = self.WORDS_APPEAR_TIME,
		scaling = 1,
		easing = "outCubic",
		exit_func = {self.uielements.screenshake, self.uielements, 1}
	}

	self.p2_name = VersusSplash.createImage(self, {
		name = "p2_name",
		image = images["vs_smallword_" .. p2char],
		duration = 0,
		end_x = stage.width - p2_action_image:getWidth() * 0.5,
		end_y = stage.height - p2_action_image:getHeight() * 0.35,
		end_scaling = 5,
		end_transparency = 0,
	})
	self.p2_name:wait(self.NAMES_WAIT_TIME)
	self.p2_name:change{duration = 0, transparency = 1}
	self.p2_name:change{
		duration = self.WORDS_APPEAR_TIME,
		scaling = 1,
		easing = "outCubic",
		exit_func = {self.uielements.screenshake, self.uielements, 1}
	}

	-- word bubbles
	local p1_bubble_image = images["vs_bubble_" .. self.p1.primary_colors[1]]
	local p2_bubble_image = images["vs_bubble_" .. self.p2.primary_colors[1]]
	local p1_bubble_x = stage.width * 0.5 + images.vs_vs:getWidth() * 0.5 - p1_bubble_image:getWidth() * 0.5
	local p1_bubble_y = stage.height - p1_bubble_image:getHeight() * 0.5
	local p2_bubble_x = stage.width * 0.5 - images.vs_vs:getWidth() * 0.5 + p2_bubble_image:getWidth() * 0.5
	local p2_bubble_y = p2_bubble_image:getHeight() * 0.5

	self.p1_bubble = VersusSplash.createImage(self, {
		name = "p1_bubble",
		image = p1_bubble_image,
		duration = 0,
		end_x = p1_bubble_x,
		end_y = p1_bubble_y,
		end_transparency = 0,
	})
	self.p1_bubble:wait(self.WORDBUBBLE_WAIT_TIME)
	self.p1_bubble:change{
		duration = self.WORDBUBBLE_APPEAR_TIME,
		transparency = 1
	}

	self.p2_bubble = VersusSplash.createImage(self, {
		name = "p2_bubble",
		image = p2_bubble_image,
		duration = 0,
		end_x = p2_bubble_x,
		end_y = p2_bubble_y,
		end_transparency = 0,
	})
	self.p2_bubble:wait(self.WORDBUBBLE_WAIT_TIME)
	self.p2_bubble:change{
		duration = self.WORDBUBBLE_APPEAR_TIME,
		transparency = 1
	}

	-- load quotes and positionings
	self.QUOTE_P1 = self.p1.vs_quotes[math.random(#self.p1.vs_quotes)]
	self.QUOTE_P2 = self.p2.vs_quotes[math.random(#self.p2.vs_quotes)]

	self.QUOTE_P1_X = p1_bubble_x - p1_bubble_image:getWidth() * 0.46
	self.QUOTE_P2_X = p2_bubble_x - p2_bubble_image:getWidth() * 0.46
	self.QUOTE_WIDTH = p1_bubble_image:getWidth() * 0.92

	self.QUOTE_P1_Y = stage.height - p1_bubble_image:getHeight() * 0.9
	self.QUOTE_P2_Y = p2_bubble_image:getHeight() * 0.1
	self.QUOTE_HEIGHT = p1_bubble_image:getHeight() * 0.7

	-- timer to goto next screen. lazy coding to avoid using queue:add
	self.dummy_timer = VersusSplash.createImage(self, {
		name = "dummy_timer",
		image = images.dummy,
		duration = self.NEXT_SCREEN_TIME,
		end_x = -stage.width,
		end_y = -stage.height,
		exit_func = function() self:switchState("gs_main") end,
	})
end

function VersusSplash:_drawText(quote, x_start, y_start)
	if self.private_framecount < self.TEXT_WAIT_TIME then return end

	local small_font = self.inits.FONT.CARTOON_SMALL
	local medium_font = self.inits.FONT.CARTOON_MEDIUM
	local big_font = self.inits.FONT.CARTOON_BIG

	-- get how many rows of text to draw
	local row_count, rows = 0, {}
	for _, data in ipairs(quote) do
		assert(data.text, "No text provided for quote")
		local text = data.text:upper()
		local font, row_multiplier
		if data.size == "small" then
			font = small_font
			row_multiplier = 1
		elseif data.size == "medium" then
			font = medium_font
			row_multiplier = 2
		elseif data.size == "big" then
			font = big_font
			row_multiplier = 3
		else
			error("Size not provided for quote")
		end

		local width, wrapped_rows = font:getWrap(text, self.QUOTE_WIDTH)
		for _, row in ipairs(wrapped_rows) do
			rows[#rows+1] = {
				font = font,
				size = data.size,
				text = row,
				width = small_font:getWidth(row),
			}

			row_count = row_count + row_multiplier
		end
	end

	-- Find the y-locations of where to draw the text
	local rows_y = {}
	for i = 1, row_count do
		rows_y[i] = y_start + self.QUOTE_HEIGHT * (i / (row_count + 1))
	end

	-- draw text
	local current_row = 0
	for _, row in ipairs(rows) do
		if row.size == "small" then
			current_row = current_row + 1
			draw_y = rows_y[current_row] + self.inits.FONT.CARTOON_SMALL_ROWADJUST
		elseif row.size == "medium" then
			current_row = current_row + 2
			draw_y = (rows_y[current_row - 1] + rows_y[current_row]) * 0.5
				+ self.inits.FONT.CARTOON_MEDIUM_ROWADJUST
		elseif row.size == "big" then
			current_row = current_row + 3
			draw_y = rows_y[current_row - 1] + self.inits.FONT.CARTOON_BIG_ROWADJUST
		else
			error("Invalid row size " .. row.size)
		end

		love.graphics.push("all")
			love.graphics.setFont(row.font)
			love.graphics.setColor(0, 0, 0)
			love.graphics.printf(
				row.text,
				x_start,
				draw_y,
				self.QUOTE_WIDTH,
				"center"
			)
		love.graphics.pop()
	end

--[[
	local current_row = 0
	for _, data in ipairs(quote) do
		local draw_y, font
		if data.size == "small" then
			font = small_font
			current_row = current_row + 1
			draw_y = rows_y[current_row] + self.inits.FONT.CARTOON_SMALL_ROWADJUST
		elseif data.size == "medium" then
			font = medium_font
			current_row = current_row + 2
			draw_y = (rows_y[current_row - 1] + rows_y[current_row]) * 0.5
				+ self.inits.FONT.CARTOON_MEDIUM_ROWADJUST
		elseif data.size == "big" then
			font = big_font
			current_row = current_row + 3
			draw_y = rows_y[current_row - 1] + self.inits.FONT.CARTOON_BIG_ROWADJUST
		end

		love.graphics.push("all")
			love.graphics.setFont(font)
			love.graphics.setColor(0, 0, 0)
			love.graphics.printf(
				data.text:upper(),
				x_start,
				draw_y,
				self.QUOTE_WIDTH,
				"center"
			)
		love.graphics.pop()
	end
	--]]
end

function VersusSplash:update(dt)
	self.uielements:updateScreenshake()
	self.private_framecount = self.private_framecount + 1

	VersusSplash.current_background:update(dt)
	for _, tbl in pairs(VersusSplash.ui) do
		for _, v in pairs(tbl) do v:update(dt) end
	end
end

function VersusSplash:draw()
	self.camera:set(1, 1)
		self.uielements:setCameraScreenshake(self.private_framecount)
		local darkened = self:isScreenDark()

		VersusSplash.current_background:draw{darkened = darkened}

		local todraw = {
			self.p1_shadow_pose, self.p2_shadow_pose,
			self.p1_action_pose, self.p2_action_pose,
			self.vs_icon,
			self.p1_name, self.p2_name,
			self.p1_bubble, self.p2_bubble,
		}
		for _, item in ipairs(todraw) do item:draw{darkened = darkened} end

		VersusSplash._drawText(self, self.QUOTE_P1, self.QUOTE_P1_X, self.QUOTE_P1_Y)
		VersusSplash._drawText(self, self.QUOTE_P2, self.QUOTE_P2_X, self.QUOTE_P2_Y)

		for _, v in pairs(VersusSplash.ui.clickable) do
			v:draw{darkened = darkened}
		end
		self:_drawSettingsMenu(VersusSplash)
		self:_drawGlobals()
	self.camera:unset()
end

function VersusSplash:mousepressed(x, y)
	self.uielements:screenshake(1)
	self:_mousepressed(x, y, VersusSplash)
end

function VersusSplash:mousereleased(x, y)
	self:_mousereleased(x, y, VersusSplash)
end

function VersusSplash:mousemoved(x, y)
	self:_mousemoved(x, y, VersusSplash)
end

return VersusSplash
