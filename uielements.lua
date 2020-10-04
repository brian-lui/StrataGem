--[[
This module provides the UI elements and effects:
Timer, burst super - these are for the main gamestate.
On-press, on-move effect: these are the animation effects for mouse actions.
UI elements - these provide the gem helper images when placing a piece into
the basin.
--]]

local images = require "images"
local common = require "class.commons"
local Pic = require "pic"
local deepcpy = require "/helpers/utilities".deepcpy

-------------------------------------------------------------------------------
------------------------------- TIMER COMPONENT -------------------------------
-------------------------------------------------------------------------------
local Timer = {}

function Timer:init(game)
	local stage = game.stage
	self.game = game

	self.text_scaling = function(t)
		return math.max(1 / (t * 2 + 0.4), 1)
	end
	self.text_transparency = function(t)
		return math.min(2.5 * t, 1)
	end
	self.time_remaining_int = 0
	self.text_multiplier = 2 -- how much to speed up relative to a real second
	self.FADE_SPEED = 1/16 -- transparency/frame to fade out at timer end

	Pic:create{
		game = game,
		x = stage.timer.x,
		y = stage.timer.y,
		image = images.ui_timer_gauge,
		container = self,
		name = "timerbase",
	}

	Pic:create{
		game = game,
		x = stage.timer.x,
		y = stage.timer.y,
		image = images.ui_timer_bar,
		container = self,
		name = "timerbar",
	}

	Pic:create{
		game = game,
		x = stage.timertext.x,
		y = stage.timertext.y,
		image = images.dummy,
		container = self,
		name = "timertext",
	}
end

function Timer:update(dt)
	local game = self.game
	local phase = game.phase
	-- set percentage of timer to show
	local w = (phase.time_to_next / phase.INIT_ACTION_TIME) * self.timerbar.width
	local x_offset = (self.timerbar.width - w) * 0.5
	self.timerbar:setQuad(x_offset, 0, w, self.timerbar.height)

	if phase.time_to_next == 0 then -- fade out
		self.timerbar.transparency = math.max(self.timerbar.transparency - self.FADE_SPEED, 0)
	else -- fade in
		self.timerbar.transparency = math.min(self.timerbar.transparency + self.FADE_SPEED, 1)
	end
	self.timerbase.transparency = self.timerbar.transparency

	-- update the timer text (3/2/1 countdown)
	local previous_time_remaining_int = self.time_remaining_int
	local time_remaining = (phase.time_to_next * game.time_step)
	self.time_remaining_int = math.ceil(time_remaining * self.text_multiplier)

	if time_remaining <= (3 / self.text_multiplier) and time_remaining > 0 then
		local t = self.time_remaining_int - time_remaining * self.text_multiplier
		self.timertext.scaling = self.text_scaling(t)
		self.timertext.transparency = self.text_transparency(t)
		if self.time_remaining_int < previous_time_remaining_int then
			self.timertext:newImage(images["ui_timer_" .. self.time_remaining_int])
			game.sound:newSFX("countdown"..self.time_remaining_int)
		end
	else
		self.timertext.transparency = 0
	end
end

function Timer:draw()
	self.timerbase:draw()
	self.timerbar:draw()
	self.timertext:draw()
end

Timer = common.class("Timer", Timer)

-------------------------------------------------------------------------------
------------------------------- BURST COMPONENT -------------------------------
-------------------------------------------------------------------------------
local Burst = {}

-- gs_main:enter()
function Burst:init(game, character)
	local stage = game.stage
	self.game = game
	self.character = character
	self.player_num = character.player_num
	self.t = 0
	self.SEGMENTS = 2
	self.GLOW_PERIOD = 120 -- frames for complete glow cycle
	self.previous_burst = 0 -- for animations. we coded this bad lol

	local frame_image = self.player_num == 1 and
		images.ui_burst_gauge_gold or images.ui_burst_gauge_silver

	Pic:create{
		game = self.game,
		x = stage.burst[self.player_num].frame.x,
		y = stage.burst[self.player_num].frame.y,
		image = frame_image,
		container = self,
		name = "burst_frame",
	}
	self.burst_block, self.burst_partial, self.burst_glow = {}, {}, {}

	for i = 1, self.SEGMENTS do
		Pic:create{
			game = self.game,
			x = stage.burst[self.player_num][i].x,
			y = stage.burst[self.player_num][i].y,
			image = character.burst_images.full,
			container = self.burst_block,
			name = i,
		}

		Pic:create{
			game = self.game,
			x = stage.burst[self.player_num][i].x,
			y = stage.burst[self.player_num][i].y,
			image = character.burst_images.partial,
			container = self.burst_partial,
			name = i,
		}

		Pic:create{
			game = self.game,
			x = stage.burst[self.player_num][i].glow_x,
			y = stage.burst[self.player_num][i].glow_y,
			image = character.burst_images.glow[i],
			container = self.burst_glow,
			name = i,
		}
	end
end

function Burst.create(game, character)
	return common.instance(Burst, game, character)
end

-- animation when a burst segment gets full
function Burst:_gainBurstAnim(segment_index)
	if not segment_index then return end -- game deserialize hack
	local game = self.game
	local loc = game.stage.burst[self.player_num][segment_index]
	local color = self.character.primary_colors[1]

	for i = 0, 20, 10 do
		game.particles.dust.generateGarbageCircle{
			game = game,
			x = loc.x,
			y = loc.y,
			color = color,
			delay_frames = i,
		}
	end
end

-- animation when a burst segment is used
function Burst:_useBurstAnim(segment_index)
	if not segment_index then return end -- game deserialize hack
	
	local game = self.game
	local stage = game.stage
	local color = self.character.primary_colors[1]
	local x = stage.burst[self.player_num][segment_index].x
	local y = stage.burst[self.player_num][segment_index].y

	-- Make the pop glowy effect
	local pop = Pic:create{
		game = game,
		x = x,
		y = y,
		container = game.global_ui.fx,
		counter = "particle",
		name = "burst_pop",
		image = images["gems_pop_" .. color],
	}

	pop:change{duration = 15, transparency = 0, scaling = 2, remove = true}


	-- Make the starburst effect
	local starburst_image = images.lookup.smalldust(color, false)

	local starburst_end_xy = function(start_x, start_y)
		local dist = game.stage.width * 0.1
		local angle = math.random() * math.pi * 2
		local end_x = dist * math.cos(angle) + start_x
		local end_y = dist * math.sin(angle) + start_y
		return end_x, end_y
	end

	for _ = 1, math.random(2, 6) do
		local end_x, end_y = starburst_end_xy(x, y)

		local star = Pic:create{
			game = game,
			x = x,
			y = y,
			container = game.global_ui.fx,
			counter = "particle",
			name = "burst_star",
			image = starburst_image,
		}

		star:change{
			duration = 30,
			x = end_x,
			y = end_y,
			transparency = 0.5,
			easing = "outCubic",
			remove = true,
		}
	end
end

function Burst:_burstChanged()
	-- if full segment created, run the full segment function
	local idx = (self.character.cur_burst) / (self.character.MAX_BURST * 0.5)
	if idx % 1 == 0 and self.character.cur_burst > self.previous_burst then
		self:_gainBurstAnim(idx)
	end

	-- if burst decreased, run the burst used function
	if self.character.cur_burst < self.previous_burst then
		local i = math.floor(self.previous_burst / (self.character.MAX_BURST * 0.5))
		self:_useBurstAnim(i)
	end
end

function Burst:update(dt)
	self.t = self.t % self.GLOW_PERIOD + 1

	local full_segs = (self.character.cur_burst / self.character.MAX_BURST) * self.SEGMENTS
	local full_segs_int = math.floor(full_segs)
	local part_fill_percent = full_segs % 1

	-- partial fill block length
	if part_fill_percent > 0 then
		local part_fill_block = self.burst_partial[full_segs_int + 1]
		local width = part_fill_block.width * part_fill_percent
		local start = self.player_num == 2 and part_fill_block.width - width or 0
		part_fill_block:setQuad(start, 0, width, part_fill_block.height)
	end

	-- full segments
	for i = 1, self.SEGMENTS do
		if full_segs >= i then
			self.burst_block[i].transparency = 1
		else
			self.burst_block[i].transparency = 0
		end

		if full_segs < i and full_segs + 1 > i then
			self.burst_partial[i].transparency = 1
		else
			self.burst_partial[i].transparency = 0
		end
	end

	-- glow
	local glow_amount = math.sin(self.t * math.pi * 2 / self.GLOW_PERIOD) * 0.5 + 0.5
	for i = 1, self.SEGMENTS do
		self.burst_glow[i].transparency = full_segs_int == i and glow_amount or 0
	end

	-- triggers for segment-related
	if self.previous_burst ~= self.character.cur_burst then
		self:_burstChanged()
	end
	self.previous_burst = self.character.cur_burst
end


function Burst:draw(params)
	self.burst_frame:draw(params)
	for i = 1, self.SEGMENTS do
		self.burst_block[i]:draw(params)
		self.burst_partial[i]:draw(params)
		self.burst_glow[i]:draw(params)
	end
end

Burst = common.class("Burst", Burst)

-------------------------------------------------------------------------------
------------------------------- SUPER COMPONENT -------------------------------
-------------------------------------------------------------------------------
local Super = {}

function Super:_generateSingleTwinkle()
	local color_lookup = self.character.primary_colors
	local idx = math.random(#color_lookup)
	local image_color = color_lookup[idx]
	local image = images.lookup.stardust(image_color)

	local super_frame = self.super_frame
	local x = super_frame.x + super_frame.width * (math.random() - 0.5)
	local y = super_frame.y + super_frame.height * (math.random() - 0.5)
	local init_rotation = math.random() * math.pi * 2
	local appear_rotation = init_rotation + math.pi * 0.7
	local disappear_rotation = appear_rotation + math.pi * 0.7
	if math.random() > 0.5 then
		init_rotation = init_rotation * -1
		appear_rotation = appear_rotation * -1
		disappear_rotation = disappear_rotation * -1
	end

	local p = Pic:create{
		game = self.game,
		x = x,
		y = y,
		rotation = init_rotation,
		image = image,
	}
	p:change{duration = 0, scaling = 0}
	p:change{
		duration = 30,
		scaling = 1,
		rotation = appear_rotation,
	}
	p:change{
		duration = 30,
		scaling = 0,
		rotation = disappear_rotation,
		remove = true,
	}

	self.twinkles[#self.twinkles+1] = p
end

function Super:init(game, character, player_num)
	local stage = game.stage
	self.game = game
	self.character = character
	self.player_num = player_num
	self.t = 0
	self.GLOW_PERIOD = 120 -- frames for complete glow cycle
	self.TWINKLE_FREQUENCY = 9 -- frames per twinkle star generation
	self.twinkles = {}

	Pic:create{
		game = self.game,
		x = stage.super[self.player_num].x,
		y = stage.super[self.player_num].y,
		image = character.super_images.empty,
		container = self,
		name = "super_frame",
	}

	Pic:create{
		game = self.game,
		x = stage.super[self.player_num].x,
		y = stage.super[self.player_num].word_y,
		image = character.super_images.word,
		container = self,
		name = "super_word",
	}

	Pic:create{
		game = self.game,
		x = stage.super[self.player_num].x,
		y = stage.super[self.player_num].y,
		image = character.super_images.full,
		container = self,
		name = "super_meter_image",
	}

	Pic:create{
		game = self.game,
		x = stage.super[self.player_num].x,
		y = stage.super[self.player_num].y,
		image = character.super_images.glow,
		container = self,
		name = "super_glow",
	}

	Pic:create{
		game = self.game,
		x = stage.super[self.player_num].x,
		y = stage.super[self.player_num].y,
		image = character.super_images.overlay,
		container = self,
		name = "super_overlay",
	}
end

function Super:getRect()
	local image = self.super_frame
	return
		image.x - (image.width / 2),
		image.y - (image.height / 2),
		image.width,
		image.height
end

function Super:released()
end

function Super:action()
	local character = self.character
	if character:canUseSuper() then
		local word = self.super_word
		local is_supering = character:toggleSuper() -- state
		if is_supering then
			word:change{
				duration = 0,
				transparency = 0.5,
				scaling = 2,
			}
			word:change{
				duration = 15,
				transparency = 1,
				scaling = 1,
				easing = "inCubic",
			}
		else
			word:change{duration = 0, transparency = 0, scaling = 1}
		end

		character:updateFurtherAction()
	end
end

function Super.create(game, character, player_num)
	return common.instance(Super, game, character, player_num)
end

-- updates the super drawables for player based on player MP
-- shown super meter is less than actual meter when super particles are on screen
-- as particles disappear, they visually go into the super meter
function Super:update(dt)
	local game = self.game
	local character = self.character
	local meter = self.super_meter_image
	local glow = self.super_glow
	local word = self.super_word

	local onscreen_mp = game.particles:getCount("onscreen", "MP", self.player_num)
	local displayed_mp = math.min(character.MAX_MP, character.mp - onscreen_mp)
	local fill_percent = 0.12 + 0.76 * displayed_mp / character.MAX_MP

	self.t = self.t % self.GLOW_PERIOD + 1
	meter:setQuad(
		0,
		meter.height * (1 - fill_percent),
		meter.width,
		meter.height * fill_percent
	)

	if character.is_supering then
		glow.transparency = 1
	elseif character.mp >= character.SUPER_COST then
		glow.transparency = math.sin(self.t * math.pi * 2 / self.GLOW_PERIOD) * 0.5 + 0.5
	else
		glow.transparency = 0
		word.transparency = 0
	end

	-- adding twinkles
	if character.mp >= character.SUPER_COST and not character.is_supering then
		if self.t % self.TWINKLE_FREQUENCY == 0 then
			self:_generateSingleTwinkle()
		end
	end

	word:update(dt)
	for i = 1, #self.twinkles do self.twinkles[i]:update(dt) end
end

function Super:draw(params)
	self.super_frame:draw(params)
	self.super_meter_image:draw(params)
	self.super_glow:draw(params)
	self.super_overlay:draw(params)
	self.super_word:draw(params)
	for i = 1, #self.twinkles do self.twinkles[i]:draw(params) end
end

Super = common.class("Super", Super)

-------------------------------------------------------------------------------
---------------------------- DROP GEMS HERE IMAGES ----------------------------
-------------------------------------------------------------------------------
local Helptext = {}
function Helptext:init(game)
	assert(game.me_player, "Shouldn't initiate without a game.me_player!")

	local stage = game.stage
	local grid = game.grid
	local player = game.me_player
	local sign = player.player_num == 1 and -1 or 1
	local platform_width = player.hand[1].platform.width
	local APPEARANCE_WAIT_TIME = 135
	local APPEAR_TIME = 45

	self.game = game
	self.owner = player
	self.grab_shown = true
	self.drop_here_shown = false
	self.FADE_IN_TIME = 10
	self.FADE_OUT_TIME = 15

	local grab_end_x = player.hand[3].x + sign * platform_width
	local grab_start_x = grab_end_x + sign * platform_width * 3
	local grab_y = player.hand[3].y
	local grab_image = images["words_p" .. player.player_num .. "_grab"]

	Pic:create{
		game = game,
		x = grab_start_x,
		y = grab_y,
		image = grab_image,
		final_x = grab_end_x,
		container = self,
		name = "grab",
	}
	self.grab.transparency = 0
	self.grab:wait(APPEARANCE_WAIT_TIME)
	self.grab:change{duration = 0, transparency = 1}
	self.grab:change{
		duration = APPEAR_TIME,
		x = grab_end_x,
		easing = "outBounce",
	}

	local any_end_x = player.hand[4].x + sign * platform_width
	local any_start_x = any_end_x + sign * platform_width * 3
	local any_y = player.hand[4].y
	local any_image = images["words_p" .. player.player_num .. "_any"]

	Pic:create{
		game = game,
		x = any_start_x,
		y = any_y,
		image = any_image,
		final_x = any_end_x,
		container = self,
		name = "any",
	}
	self.any.transparency = 0
	self.any:wait(APPEARANCE_WAIT_TIME)
	self.any:change{duration = 0, transparency = 1}
	self.any:change{
		duration = APPEAR_TIME,
		x = any_end_x,
		easing = "outBounce",
	}

	local gem_end_x = player.hand[5].x + sign * platform_width
	local gem_start_x = gem_end_x + sign * platform_width * 3
	local gem_y = player.hand[5].y
	local gem_image = images["words_p" .. player.player_num .. "_gem"]

	Pic:create{
		game = game,
		x = gem_start_x,
		y = gem_y,
		image = gem_image,
		final_x = gem_end_x,
		container = self,
		name = "gem",
	}
	self.gem.transparency = 0
	self.gem:wait(APPEARANCE_WAIT_TIME)
	self.gem:change{duration = 0, transparency = 1}
	self.gem:change{
		duration = APPEAR_TIME,
		x = gem_end_x,
		easing = "outBounce",
	}

	local tap_x = player.hand[3].x + sign * platform_width * 2
	local tap_y = player.hand[3].y
	local tap_image = images.words_taptorotate

	Pic:create{
		game = game,
		x = tap_x,
		y = tap_y,
		image = tap_image,
		final_x = tap_x,
		container = self,
		name = "tap",
	}
	self.tap.transparency = 0
	self.tap:wait(APPEARANCE_WAIT_TIME + APPEAR_TIME)
	self.tap:change{
		duration = self.FADE_IN_TIME,
		transparency = 1,
	}

	local here_x = 0.5 * stage.width + sign * images.GEM_WIDTH * 2
	local here_y = (grid.y[grid.BASIN_START_ROW] + grid.y[grid.PENDING_END_ROW]) * 0.5
	local here_image = images["words_p" .. player.player_num .. "_dropgemshere"]

	Pic:create{
		game = game,
		x = here_x,
		y = here_y,
		image = here_image,
		transparency = 0,
		container = self,
		name = "here",
	}
end

function Helptext:update(dt)
	local game = self.game

	local any_items_remaining = false
	local items = {self.here, self.grab, self.any, self.gem, self.tap}
	for _, item in pairs(items) do
		if item then
			item:update(dt)
			any_items_remaining = true
		end
	end

	if game.current_phase == "Action" and any_items_remaining then
		if self.owner.dropped_piece then
			self:_removeGrabAndDropGems()
		elseif game.active_piece then
			self:_showDropGemsHere()
			self:_hideGrabAnyGem()
		else
			self:_hideDropGemsHere()
			self:_showGrabAnyGem()
		end

		if self:_isAnyGemRotated() then self:_removeTapToRotate() end

		if self.grab_and_drop_deleted and not self.tap_deleted then
			self:_relocateTapToRotate()
		end
	end
end

function Helptext:draw(params)
	local game = self.game

	if game and game.me_player then
			local items = {self.here, self.grab, self.any, self.gem, self.tap}
			for _, item in pairs(items) do
				if item then item:draw(params) end
			end

		if not self.tap_deleted and self.tap then self.tap:draw(params) end
	end
end

function Helptext:_isAnyGemRotated()
	if self.tap_deleted then return true end

	for piece in self.owner.hand:pieces() do
		if piece.rotation_index ~= 0 then return true end
	end

	return false
end

function Helptext:_removeGrabAndDropGems()
	if self.grab_and_drop_deleted then return end

	local items = {self.here, self.grab, self.any, self.gem}
	for _, item in ipairs(items) do
		item:clear()
		item:change{
			duration = self.FADE_OUT_TIME,
			transparency = 0,
			remove = true,
		}
	end

	self.grab_and_drop_deleted = true
end

function Helptext:_removeTapToRotate()
	if self.tap_deleted then return end

	self.tap:clear()
	self.tap:change{
		duration = self.FADE_OUT_TIME,
		transparency = 0,
		remove = true,
	}

	self.tap_deleted = true
end

-- If grab/any/gem is gone and tap to rotate exists, move it down
function Helptext:_relocateTapToRotate()
	if self.tap_relocated then return end

	local sign = self.owner.player_num == 1 and -1 or 1
	local hand_pos = self.owner.hand[4]

	self.tap:wait(45)
	self.tap:change{
		duration = 30,
		x = hand_pos.x + sign * hand_pos.platform.width,
		y = hand_pos.y,
		rotation = math.pi * 2,
		easing = "inOutCubic",
	}
	self.tap_relocated = true
end

function Helptext:_showDropGemsHere()
	if self.grab_and_drop_deleted then return end

	if not self.drop_here_shown then
		self.here:wait(15)
		self.here:change{duration = self.FADE_IN_TIME, transparency = 1}
		self.drop_here_shown = true
	end
end

function Helptext:_hideDropGemsHere()
	if self.grab_and_drop_deleted then return end

	if self.drop_here_shown then
		self.here:clear()
		self.here:change{duration = 0, transparency = 0}
		self.drop_here_shown = false
	end
end

function Helptext:_showGrabAnyGem()
	if self.grab_and_drop_deleted then return end

	if not self.grab_shown then
		local MIN_WIDTH = self.game.stage.width * 0.0078125
		local items = {self.grab, self.any, self.gem}

		for _, item in ipairs(items) do
			if item.final_x - item.x < MIN_WIDTH then item:clear() end
			item:change{duration = self.FADE_IN_TIME, transparency = 1}
		end

		self.grab_shown = true
	end
end

function Helptext:_hideGrabAnyGem()
	if self.grab_and_drop_deleted then return end

	if self.grab_shown then
		local MIN_WIDTH = self.game.stage.width * 0.0078125
		local items = {self.grab, self.any, self.gem}

		for _, item in ipairs(items) do
			if item.final_x - item.x < MIN_WIDTH then item:clear() end
			item:wait(15)
			item:change{duration = self.FADE_OUT_TIME, transparency = 0}
		end

		self.grab_shown = false
	end
end

Helptext = common.class("Helptext", Helptext)

-------------------------------------------------------------------------------
-------------------------- WARNING SIGN NEXT TO GEMS --------------------------
-------------------------------------------------------------------------------
local WarningSign = {}

function WarningSign:init(game)
	assert(game.me_player, "Shouldn't initiate without a game.me_player!")

	local player = game.me_player
	local image = images.ui_warning
	local sign = player.player_num == 1 and 1 or -1
	local platform_width = player.hand[1].platform.width

	self.game = game
	self.owner = player
	self.player_num = player.player_num
	self.FADE_IN_TIME = 30
	self.FADE_OUT_TIME = 20
	self.dangerous = false -- a gem is above no_rush line
	self.really_dangerous = false  -- 1 or 0 empty rows left

	local warn_x = {
		player.hand[1].x + sign * platform_width * 0.5,
		player.hand[2].x + sign * platform_width * 0.5,
		player.hand[3].x + sign * platform_width * 0.5,
	}
	local warn_y = {
		player.hand[1].y,
		player.hand[2].y,
		player.hand[3].y,
	}

	Pic:create{
		game = game,
		x = warn_x[1],
		y = warn_y[1],
		image = image,
		transparency = 0,
		platform_num = 1,
		visible = false,
		container = self,
		name = "warn1",
	}

	Pic:create{
		game = game,
		x = warn_x[2],
		y = warn_y[2],
		image = image,
		transparency = 0,
		platform_num = 2,
		visible = false,
		container = self,
		name = "warn2",
	}

	Pic:create{
		game = game,
		x = warn_x[3],
		y = warn_y[3],
		image = image,
		transparency = 0,
		platform_num = 3,
		visible = false,
		container = self,
		name = "warn3",
	}

end

function WarningSign:fadeIn(icon)
	if not icon.visible then
		icon:change{duration = self.FADE_IN_TIME, transparency = 1}
		icon.visible = true
	end
end

function WarningSign:fadeOut(icon)
	if icon.visible then
		icon:change{duration = self.FADE_OUT_TIME, transparency = 0}
		icon.visible = false
	end
end

function WarningSign:update(dt)
	local game = self.game
	local grid = game.grid
	local items = {self.warn1, self.warn2, self.warn3}

	if game.current_phase == "Action" then
		for col in grid:cols(self.player_num) do
			if not game.phase.no_rush[col] then
				self.dangerous = true
				if grid:getFirstEmptyRow(col) <= grid.BASIN_START_ROW then
					self.really_dangerous = true
				end
			end
		end

		for _, item in ipairs(items) do
			local platform = self.owner.hand[item.platform_num]
			if platform.piece and self.dangerous then
				self:fadeIn(item)
			else
				self:fadeOut(item)
			end
		end
	else
		for _, item in ipairs(items) do self:fadeOut(item) end
	end

	for _, item in ipairs(items) do item:update(dt) end
end

function WarningSign:draw(params)
	local items = {self.warn1, self.warn2, self.warn3}
	for _, item in ipairs(items) do
		item:draw(params)
		if self.really_dangerous then
			local extra_params = deepcpy(params)
			local sign = self.player_num == 1 and 1 or -1
			extra_params.x = item.x + sign * item.width * 0.5
			item:draw(extra_params)
		end
	end
end

WarningSign = common.class("WarningSign", WarningSign)


-------------------------------------------------------------------------------
---------------------------- ON-PRESS TOUCH EFFECT ----------------------------
-------------------------------------------------------------------------------
local ScreenPress = {}
function ScreenPress:init(game, gamestate, x, y)
	-- determine the color
	local rand_color = game.uielements.screen_ui_color
	if not rand_color then rand_color = {"red", "blue", "green", "yellow"} end
	local rand = math.random(#rand_color)
	local color = rand_color[rand]

	-- Make the pop glowy effect
	local pop_image = images["gems_pop_" .. color]
	local pop_params = {
		name = "screenpress_pop",
		container = game.global_ui.fx,
		counter = "particle",
		image = pop_image,
		end_x = x,
		end_y = y,
		duration = 15,
		end_transparency = 0,
		end_scaling = 2,
		remove = true,
	}
	game:_createImage(gamestate, pop_params)

	-- Make the starburst effect
	local starburst_image = images.lookup.smalldust(color, false)
	local starburst_end_xy = function(start_x, start_y)
		local dist = game.stage.width * 0.1
		local angle = math.random() * math.pi * 2
		local end_x = dist * math.cos(angle) + start_x
		local end_y = dist * math.sin(angle) + start_y
		return end_x, end_y
	end

	for _ = 1, math.random(2, 6) do
		local end_x, end_y = starburst_end_xy(x, y)
		local starburst_params = {
			name = "screenpress_starburst",
			container = game.global_ui.fx,
			duration = 30,
			counter = "particle",
			image = starburst_image,
			start_x = x,
			start_y = y,
			end_x = end_x,
			end_y = end_y,
			end_transparency = 0.5,
			easing = "outCubic",
			remove = true,
		}

		game:_createImage(gamestate, starburst_params)
	end
end

function ScreenPress.create(game, gamestate, x, y)
	common.instance(ScreenPress, game, gamestate, x, y)
end

ScreenPress = common.class("ScreenPress", ScreenPress)


-------------------------------------------------------------------------------
----------------------------- ON-MOVE DRAG EFFECT -----------------------------
-------------------------------------------------------------------------------
local ScreenDrag = {}
function ScreenDrag:init(game, gamestate, x, y)
	-- determine the color
	local rand_color = game.uielements.screen_ui_color
	if not rand_color then rand_color = {"red", "blue", "green", "yellow"} end
	local rand = math.random(#rand_color)
	local color = rand_color[rand]

	-- make a single trail image
	local trail_image = images["particles_trail_" .. color]
	local trail_params = {
		name = "screenmove_trail",
		container = game.global_ui.fx,
		counter = "particle",
		image = trail_image,
		end_x = x,
		end_y = y,
		duration = 30,
		start_scaling = 1.5,
		end_scaling = 0,
		remove = true,
	}
	return game:_createImage(gamestate, trail_params)
end

function ScreenDrag.create(game, gamestate, x, y)
	return common.instance(ScreenDrag, game, gamestate, x, y)
end

ScreenDrag = common.class("ScreenDrag", ScreenDrag)


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
local uielements = {}

function uielements:init(game)
	self.game = game
	self.superMeter = Super
	self.burstMeter = Burst
	self.screenPress = ScreenPress
	self.screenDrag = ScreenDrag
	self.screen_ui_color = nil
	self.screen_ui_trails = {}
	self.SCREEN_TRAILS_TIMER = 0.05 -- in seconds
	self.screen_trails_t = 0
	self.screenshake_frames = 0
	self.screenshake_vel = 0

	-- Red X shown on gems in invalid placement spots
	Pic:create{
		game = game,
		x = 0,
		y = 0,
		image = images.ui_redx,
		container = self,
		name = "redx",
	}
end

function uielements:reset()
	local game = self.game
	local NOP = function() end

	self.timer = common.instance(Timer, game)
	if game.me_player then
		self.helptext = common.instance(Helptext, game)
		self.warningSign = common.instance(WarningSign, game)
		self.screen_ui_color = game.me_player.primary_colors
	else
		self.helptext = {update = NOP, draw = NOP}
		self.warningSign = {update = NOP, draw = NOP}
	end
end

function uielements:clearScreenUIColor()
	self.screen_ui_color = nil
end

-- draws the shadow underneath the player's gem piece
-- called if gem is picked up
local function drawUnderGemShadow(self, piece)
	local stage = self.game.stage
	for i = 1, piece.size do
		local gem_shadow_x = piece.gems[i].x + 0.1 * images.GEM_WIDTH
		local gem_shadow_y = piece.gems[i].y + 0.1 * images.GEM_HEIGHT
		piece.gems[i]:draw{
			x = gem_shadow_x,
			y = gem_shadow_y,
			RGBTable = {0, 0, 0, 0.1},
		}
	end
end

-- Show the top shadow that indicates where piece will be placed upon release
local function drawPlacementShadow(self, piece, shift)
	local grid = self.game.grid
	local _, place_type = piece:isDropValid(shift)
	local row_adj = false
	if place_type == "normal" then row_adj = 0
	elseif place_type == "rush" then row_adj = 2
	elseif place_type == "double" then row_adj = 0
	end

	local show = {}
	local drop_cols = piece:getColumns(shift)
	for i = 1, piece.size do
		show[i] = {}
		show[i].x = grid.x[ drop_cols[i] ]
		if piece.is_horizontal then
			show[i].y = grid.y[1 + row_adj]
		else
			show[i].y = grid.y[i + row_adj]
		end
		if show[i].x and show[i].y then
			piece.gems[i]:draw{
				x = show[i].x,
				y = show[i].y,
				RGBTable = {0, 0, 0, 0.5},
			}
		end
	end
end

-- draws the gem shadows at the bottom indicating where the piece will land.
local function drawDestinationShadow(self, piece, shift, account_for_doublecast)
	local grid = self.game.grid
	local toshow = {}
	local drop_locs = grid:getDropLocations(piece, shift)
	if account_for_doublecast then
		local pending_gems = grid:getPendingGems(piece.player_num)

		-- also draw the previous gem's shadows
		for _, gem in pairs(pending_gems) do
			local first_empty_row = grid:getFirstEmptyRow(gem.column, true)
			-- shift needed is first_empty_row - (upper normal-placement-column - 1)
			-- this is bad code sorry
			local shift_needed = first_empty_row - (5 - 1)
			local row = gem.row + shift_needed
			gem:draw{
				RGBTable = {1, 1, 1, 0.6},
				displace_y = self.game.grid.y[row] - gem.y,
			}
		end
	end

	for i = 1, piece.size do
		toshow[i] = {}
		toshow[i].x = grid.x[ drop_locs[i][1] ] -- basin c column
		toshow[i].y = grid.y[ drop_locs[i][2] ] -- basin r row
		if toshow[i].x and toshow[i].y then
			piece.gems[i]:draw{
				x = toshow[i].x,
				y = toshow[i].y,
				RGBTable = {1, 1, 1, 0.6},
			}
		end
	end
end

-- show all the possible shadows!
function uielements:showShadows(piece)
	local midline, on_left = piece:isOnMidline()
	local shift = 0
	if midline then
		if on_left then shift = -1 else shift = 1 end
	end
	drawUnderGemShadow(self, piece)
	if piece:isDropValid(shift) then
		-- TODO: somehow account for variable piece size
		local pending_gems = self.game.grid:getPendingGems(piece.player_num)
		local account_for_doublecast = #pending_gems == 2

		drawPlacementShadow(self, piece, shift)
		drawDestinationShadow(self, piece, shift, account_for_doublecast)
	end
end

-- This is the red X shown on top of the active gem
function uielements:showX(piece)
	local legal = piece:isDropLegal()
	local midline, on_left = piece:isOnMidline()
	local shift = midline and (on_left and -1 or 1) or 0
	local valid = piece:isDropValid(shift)

	for i = piece.size, 1, -1 do
		if (legal or midline) and not valid then
			self.redx:draw{x = piece.gems[i].x, y = piece.gems[i].y}
		end
	end
end

-- sends screenshake data depending on how many gems matched, called on match
function uielements:screenshake(damage)
	self.screenshake_frames = self.screenshake_frames + math.max(0, damage * 5)
	self.screenshake_vel = self.screenshake_vel + math.max(0, damage)
end

local function pieceLandedInStagingArea(game, gems, place_type)
	local particles = game.particles
	local player_num = gems[1].player_num
	local sign = player_num == 1 and 1 or -1
	local y = game.stage.height * 0.3
	if place_type == "double" then
		particles.words.generateDoublecast(game, player_num)
		game.sound:newSFX("doublecast")
		game.sound:newSFX("fountaindoublecast")
		for i = 1, #gems do
			particles.dust.generateStarFountain{
				game = game,
				color = gems[i].color,
				x = game.stage.width * (0.5 - sign * 0.1),
				y = y,
			}
		end
	elseif place_type == "rush" then
		particles.words.generateRush(game, player_num)
		game.sound:newSFX("rush")
		game.sound:newSFX("fountainrush")
		for i = 1, #gems do
			particles.dust.generateStarFountain{
				game = game,
				color = gems[i].color,
				x = game.stage.width * (0.5 + sign * 0.2),
				y = y,
			}
		end
	end
end

-- animation: places pieces at top of basin, and tweens them down.
-- also calls the cloud effects and the words/star fountains.
function uielements:putPendingAtTop(delay)
	local game = self.game
	local pending = {
		p1 = game.grid:getPendingGems(1),
		p2 = game.grid:getPendingGems(2),
	}

	for _, player_gems in pairs(pending) do
		local doubles, rushes = {}, {}
		for i = 1, #player_gems do
			local gem = player_gems[i]
			local target_y = gem.y
			gem.y = game.stage.height * -0.1
			gem:change{
				duration = game.TWEEN_TO_LANDING_ZONE_DURATION,
				y = target_y,
				easing = "outQuart",
				remove = true,
			}

			if gem.place_type == "double" then
				doubles[#doubles+1] = gem
			elseif gem.place_type == "rush" then
				rushes[#rushes+1] = gem
			end
		end
		if #doubles == 2 then
			local is_horizontal = doubles[1].row == doubles[2].row
			game.particles.wordEffects.generateDoublecastCloud(
				game,
				doubles[1],
				doubles[2],
				is_horizontal
			)
			game.queue:add(
				game.TWEEN_TO_LANDING_ZONE_DURATION + delay,
				pieceLandedInStagingArea,
				game,
				doubles,
				"double"
			)
		end
		if #rushes == 2 then
			local is_horizontal = rushes[1].row == rushes[2].row
			game.particles.wordEffects.generateRushCloud(
				game,
				rushes[1],
				rushes[2],
				is_horizontal
			)
			game.queue:add(
				game.TWEEN_TO_LANDING_ZONE_DURATION + delay,
				pieceLandedInStagingArea,
				game,
				rushes,
				"rush"
			)
		end
	end
end

function uielements:setCameraScreenshake(current_frame)
	local game = self.game
	current_frame = current_frame or game.frame
	if self.screenshake_frames > 0 then
		game.camera:setScreenshake(current_frame, self.screenshake_vel)
	else
		game.camera:setPosition(0, 0)
	end
end

function uielements:updateScreenshake()
	self.screenshake_frames = math.max(0, self.screenshake_frames - 1)
end

-- generates dust for active piece, and calculates tweens for gem shadows
-- only called in main gamestate
function uielements:update(dt)
	local game = self.game
	local player = game.me_player
	local pending_gems = game.grid:getPendingGems(player.player_num)
	local valid = false
	local place_type
	local cloud = game.particles.wordEffects.cloudExists(game.particles)
	local active_piece = game.active_piece

	self.timer:update(dt)
	self.helptext:update(dt)
	self.warningSign:update(dt)
	self:updateScreenshake()

	if game.current_phase ~= "Action" then return end

	-- if piece is held, generate effects and check if it's valid
	if active_piece then
		active_piece:generateDust()
		local midline, on_left = active_piece:isOnMidline()
		local shift = 0
		if midline then
			if on_left then shift = -1 else shift = 1 end
		end
		valid, place_type = active_piece:isDropValid(shift)

		-- glow effects
		if not cloud then
			if valid and place_type == "double" then
				--TODO: support variable number of gems
				local gem1, gem2 = active_piece.gems[1], active_piece.gems[2]
				local h = active_piece.is_horizontal
				game.particles.wordEffects.generateDoublecastCloud(
					game,
					gem1,
					gem2,
					h
				)
			elseif valid and place_type == "rush" then
				local gem1, gem2 = active_piece.gems[1], active_piece.gems[2]
				local h = active_piece.is_horizontal
				game.particles.wordEffects.generateRushCloud(
					game,
					gem1,
					gem2,
					h
				)
			end
		elseif not valid or place_type == "normal" then
			game.particles.wordEffects.clear(game.particles)
		end
	elseif cloud then -- remove glow effects if piece not active
		game.particles.wordEffects.clear(game.particles)
	end

	-- tween the placedgem particles, if it's a doublecast
	if #pending_gems == 2 and valid then
		for _, v in pairs(game.particles.allParticles.PlacedGem) do
			v:tweenDown()
		end
	else
		for _, v in pairs(game.particles.allParticles.PlacedGem) do
			v:tweenUp()
		end
	end
end

-- updates the screenpress/screenmove functionality
-- always called from every gamestate
function uielements:screenUIupdate(dt)
	self.screen_trails_t = self.screen_trails_t + dt
	if self.screen_trails_t > self.SCREEN_TRAILS_TIMER then
		local game = self.game
		local gamestate = game.current_gamestate
		self.screen_trails_t = self.screen_trails_t - self.SCREEN_TRAILS_TIMER

		if game:_isPressedDown(gamestate) then
			local x, y = game:_getControllerPosition()
			self.screenDrag.create(game, gamestate, x, y)
		end
	end
end

return common.class("UIelements", uielements)
