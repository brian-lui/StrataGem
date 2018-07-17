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
	self.QUOTE_WIDTH = p1_bubble_image:getWidth() * 0.92
	self.QUOTE_HEIGHT = p1_bubble_image:getHeight() * 0.7

	local p1_all_quotes = self.quotes.vs_quotes[self.p1.character_name:lower()]
	local p1_quote = p1_all_quotes[math.random(#p1_all_quotes)]
	local p1_x = p1_bubble_x
	local p1_y = stage.height - p1_bubble_image:getHeight() * 0.9

	local p2_all_quotes = self.quotes.vs_quotes[self.p2.character_name:lower()]
	local p2_quote = p2_all_quotes[math.random(#p2_all_quotes)]
	local p2_x = p2_bubble_x
	local p2_y = p2_bubble_image:getHeight() * 0.1

	self.FORMATTED_QUOTE = {
		VersusSplash.convertQuoteToRows(self, p1_quote, p1_x, p1_y),
		VersusSplash.convertQuoteToRows(self, p2_quote, p2_x, p2_y),
	}

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

function VersusSplash:convertQuoteToRows(quote, x_start, y_start)
	local small_font = self.inits.FONT.CARTOON_SMALL
	local medium_font = self.inits.FONT.CARTOON_MEDIUM
	local big_font = self.inits.FONT.CARTOON_BIG

	local row_count = 0
	local cumulative_length = 0
	local rows = {}

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

		local total_width, wrapped_rows = font:getWrap(text, self.QUOTE_WIDTH)
		for _, row in ipairs(wrapped_rows) do
			local width = font:getWidth(row)
			local x = x_start - width * 0.5
			rows[#rows+1] = {
				font = font,
				size = data.size,
				text = row,
				x = x,
				start_pos = cumulative_length,
				end_pos = cumulative_length + #row * row_multiplier,
				speed = 1 / row_multiplier,
			}
			row_count = row_count + row_multiplier
			cumulative_length = cumulative_length + #row * row_multiplier + 1
		end
	end

	-- Find the y-locations of where to draw the text
	local y_values = {}
	for i = 1, row_count do
		y_values[i] = y_start + self.QUOTE_HEIGHT * (i / (row_count + 1))
	end

	-- add y-locations to the rows
	local current_row = 0
	for _, row in ipairs(rows) do
		if row.size == "small" then
			current_row = current_row + 1
			row.y = y_values[current_row] + self.inits.FONT.CARTOON_SMALL_ROWADJUST
		elseif row.size == "medium" then
			current_row = current_row + 2
			row.y = (y_values[current_row-1] + y_values[current_row]) * 0.5
				+ self.inits.FONT.CARTOON_MEDIUM_ROWADJUST
		elseif row.size == "big" then
			current_row = current_row + 3
			row.y = y_values[current_row-1] + self.inits.FONT.CARTOON_BIG_ROWADJUST
		else
			error("Invalid row size " .. row.size)
		end
	end

	return rows
end

function VersusSplash:_drawText()
	if self.private_framecount < self.TEXT_WAIT_TIME then return end

	local SCROLL_SPEED = 1
	local pos = (self.private_framecount - self.TEXT_WAIT_TIME) * SCROLL_SPEED

	for player_num = 1, 2 do
		local rows = self.FORMATTED_QUOTE[player_num]
		for _, row in ipairs(rows) do
			if pos >= row.end_pos then
				love.graphics.push("all")
					love.graphics.setFont(row.font)
					love.graphics.setColor(0, 0, 0)
					love.graphics.print(row.text, row.x, row.y)
				love.graphics.pop()
			elseif pos >= row.start_pos then
				local print_to = math.floor((pos - row.start_pos) * row.speed) + 1
				local text = row.text:sub(1, print_to)
				love.graphics.push("all")
					love.graphics.setFont(row.font)
					love.graphics.setColor(0, 0, 0)
					love.graphics.print(text, row.x, row.y)
				love.graphics.pop()
			end
		end
	end
end

function VersusSplash:update(dt)
	self:timeDip(function()
		self.uielements:updateScreenshake()
		self.private_framecount = self.private_framecount + 1

		VersusSplash.current_background:update(dt)
		for _, tbl in pairs(VersusSplash.ui) do
			for _, v in pairs(tbl) do v:update(dt) end
		end
	end)

	self.timeBucket = self.timeBucket + dt
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

		VersusSplash._drawText(self)

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
