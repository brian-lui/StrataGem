local love = _G.love

local image = require 'image'
local common = require 'class.commons'
local Pic = require 'pic'

-------------------------------------------------------------------------------
------------------------------- TIMER COMPONENT -------------------------------
-------------------------------------------------------------------------------

local Timer = {}

function Timer:init(game)
	local stage = game.stage
	self.game = game

	self.text_scaling = function(t) return math.max(1 / (t * 2 + 0.4), 1) end
	self.text_transparency = function(t) return math.min(255 * 2.5 * t, 255) end
	self.time_remaining_int = 0
	self.text_multiplier = 2 -- how much to speed it up relative to an actual second
	self.FADE_SPEED = 15 -- transparency/frame to fade out at timer end
	self.timerbase = Pic:create{
		game = game,
		x = stage.timer.x,
		y = stage.timer.y,
		image = image.ui_timer_gauge,
	}
	self.timerbar = Pic:create{
		game = game,
		x = stage.timer.x,
		y = stage.timer.y,
		image = image.ui_timer_bar,
	}
	self.timertext = Pic:create{
		game = game,
		x = stage.timertext.x,
		y = stage.timertext.y,
		image = image.dummy,
	}
end

function Timer:update(dt)
	-- set percentage of timer to show
	local w = (self.game.phase.time_to_next / self.game.phase.INIT_TIME_TO_NEXT) * self.timerbar.width
	local x_offset = (self.timerbar.width - w) * 0.5
	self.timerbar:setQuad(x_offset, 0, w, self.timerbar.height)

	if self.game.phase.time_to_next == 0 then -- fade out
		self.timerbar.transparency = math.max(self.timerbar.transparency - self.FADE_SPEED, 0)
	else -- fade in
		self.timerbar.transparency = math.min(self.timerbar.transparency + self.FADE_SPEED, 255)
	end
	self.timerbase.transparency = self.timerbar.transparency

	-- update the timer text (3/2/1 countdown)
	local previous_time_remaining_int = self.time_remaining_int
	local time_remaining = (self.game.phase.time_to_next * self.game.timeStep)
	self.time_remaining_int = math.ceil(time_remaining * self.text_multiplier)

	if time_remaining <= (3 / self.text_multiplier) and time_remaining > 0 then
		local t = self.time_remaining_int - time_remaining * self.text_multiplier
		self.timertext.scaling = self.text_scaling(t)
		self.timertext.transparency = self.text_transparency(t)
		if self.time_remaining_int < previous_time_remaining_int then
			self.timertext:newImage(image["ui_timer_" .. self.time_remaining_int])
			self.game.sound:newSFX("countdown"..self.time_remaining_int)
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

	local ID
	if self.player_num == 1 then
		ID = "P1"
	elseif self.player_num == 2 then
		ID = "P2"
	else
		print("invalid player_num provided")
	end

	local frame_img = self.player_num == 1 and image.ui_burst_gauge_gold or image.ui_burst_gauge_silver
	self.burst_frame = Pic:create{
		game = self.game,
		x = stage.burst[ID].frame.x,
		y = stage.burst[ID].frame.y,
		image = frame_img,
	}
	self.burst_block, self.burst_partial, self.burst_glow = {}, {}, {}

	for i = 1, self.SEGMENTS do
		self.burst_block[i] = Pic:create{
			game = self.game,
			x = stage.burst[ID][i].x,
			y = stage.burst[ID][i].y,
			image = character.burst_images.full,
		}
		self.burst_partial[i] = Pic:create{
			game = self.game,
			x = stage.burst[ID][i].x,
			y = stage.burst[ID][i].y,
			image = character.burst_images.partial,
		}
		self.burst_glow[i] = Pic:create{
			game = self.game,
			x = stage.burst[ID][i].glow_x,
			y = stage.burst[ID][i].glow_y,
			image = character.burst_images.glow[i],
		}
	end
end

function Burst.create(game, character)
	return common.instance(Burst, game, character)
end

function Burst:update(dt)
	self.t = self.t + dt

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
			self.burst_block[i].transparency = 255
		else
			self.burst_block[i].transparency = 0
		end

		if full_segs < i and full_segs + 1 > i then
			self.burst_partial[i].transparency = 255
		else
			self.burst_partial[i].transparency = 0
		end
	end

	-- glow
	local glow_amount = math.sin(self.t * 2) * 127.5 + 127.5
	for i = 1, self.SEGMENTS do
		self.burst_glow[i].transparency = full_segs_int == i and glow_amount or 0
	end
end

-- gs_main:drawUI()
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
	local img = image.lookup.stardust(image_color)

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

	local p = Pic:create{game = self.game, x = x, y = y, rotation = init_rotation, image = img}
	p:change{duration = 0, scaling = 0}
	p:change{duration = 30, scaling = 1, rotation = appear_rotation}
	p:change{duration = 30, scaling = 0, rotation = disappear_rotation, remove = true}

	self.twinkles[#self.twinkles+1] = p
end

function Super:init(game, character, player_num)
	local stage = game.stage
	self.game = game
	self.character = character
	self.player_num = player_num
	self.t = 0
	self.twinkle_t = 0
	self.TWINKLE_FREQ = 0.15 -- this is in seconds, not frames
	self.twinkles = {}

	self.super_frame = Pic:create{
		game = self.game,
		x = stage.super[self.player_num].x,
		y = stage.super[self.player_num].y,
		image = character.super_images.empty,
	}
	self.super_word = Pic:create{
		game = self.game,
		x = stage.super[self.player_num].x,
		y = stage.super[self.player_num].word_y,
		image = character.super_images.word,
	}
	self.super_meter_image = Pic:create{
		game = self.game,
		x = stage.super[self.player_num].x,
		y = stage.super[self.player_num].y,
		image = character.super_images.full,
	}
	self.super_glow = Pic:create{
		game = self.game,
		x = stage.super[self.player_num].x,
		y = stage.super[self.player_num].y,
		image = character.super_images.glow,
	}
	self.super_overlay = Pic:create{
		game = self.game,
		x = stage.super[self.player_num].x,
		y = stage.super[self.player_num].y,
		image = character.super_images.overlay,
}
end

function Super:getRect()
	local img = self.super_frame
	return img.x - (img.width / 2), img.y - (img.height / 2), img.width, img.height
end

function Super:released()
end

function Super:action()
	local character = self.character
	if character:canUseSuper() then
		local word = self.super_word
		local supering = character:toggleSuper() -- state
		if supering then
			word:change{duration = 0, transparency = 128, scaling = 2}
			word:change{duration = 15, transparency = 255, scaling = 1, easing = "inCubic"}
		else
			word:change{duration = 0, transparency = 0, scaling = 1}
		end
	end
end

function Super.create(game, character, player_num)
	return common.instance(Super, game, character, player_num)
end

function Super:update(dt)
	local game = self.game
	local character = self.character
	local meter = self.super_meter_image
	local glow = self.super_glow
	local word = self.super_word

	local onscreen_mp = game.particles:getCount("onscreen", "MP", self.player_num)
	local displayed_mp = math.min(character.MAX_MP, character.mp - onscreen_mp)
	local fill_percent = 0.12 + 0.76 * displayed_mp / character.MAX_MP

	self.t = self.t + dt
	meter:setQuad(0, meter.height * (1 - fill_percent), meter.width, meter.height * fill_percent)

	if character.supering then
		glow.transparency = 255
	elseif character:canUseSuper() then
		glow.transparency = math.sin(self.t * 2) * 127.5 + 127.5
	else
		glow.transparency = 0
		word.transparency = 0
	end

	-- adding twinkles
	if character.mp >= character.SUPER_COST and not character.supering then
		self.twinkle_t = self.twinkle_t + dt
		if self.twinkle_t >= self.TWINKLE_FREQ then
			self.twinkle_t = self.twinkle_t - self.TWINKLE_FREQ
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
local components = {
	timer = Timer, -- TODO: this is not implemented yet, still in ui.timer
	super = Super,
	burst = Burst,
}


local uielements = {}

function uielements:init(game)
	self.game = game
	self.timer = common.instance(Timer, game)
	-- Red X shown on gems in invalid placement spots
	self.redx = Pic:create{game = game, x = 0, y = 0, image = image.ui_redx}
	self.components = components
end

-- updates the super drawables for player based on player MP
-- shown super meter is less than the actual super meter when super particles are on screen
-- as particles disappear, they visually go into the super meter
function uielements:updateSupers(gamestate)
	local game = self.game
	for player in game:players() do
		local onscreen_mp = game.particles:getCount("onscreen", "MP", player.player_num)
		local displayed_mp = math.min(player.MAX_MP, player.mp - onscreen_mp)
		local fill_percent = 0.12 + 0.76 * displayed_mp / player.MAX_MP
		local meter = gamestate.ui.static[player.ID .. "supermeter"]
		meter:setQuad(0, meter.height * (1 - fill_percent), meter.width, meter.height * fill_percent)

		local superglow = gamestate.ui.static[player.ID .. "superglow"]
		if player.supering then
			superglow.transparency = 255
		elseif player:canUseSuper() then
			superglow.transparency = math.sin(game.frame / 30) * 127.5 + 127.5
		else
			superglow.transparency = 0
			gamestate.ui.static[player.ID .. "superword"].transparency = 0
		end
	end
end

-- draws the shadow underneath the player's gem piece, called if gem is picked up
local function drawUnderGemShadow(self, piece)
	local stage = self.game.stage
	for i = 1, piece.size do
		local gem_shadow_x = piece.gems[i].x + 0.1 * stage.gem_width
		local gem_shadow_y = piece.gems[i].y + 0.1 * stage.gem_height
		piece.gems[i]:draw{pivot_x = gem_shadow_x, pivot_y = gem_shadow_y, RGBTable = {0, 0, 0, 24}}
	end
end

-- Show the shadow at the top that indicates where the piece will be placed upon mouse release.
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
			piece.gems[i]:draw{pivot_x = show[i].x, pivot_y = show[i].y, RGBTable = {0, 0, 0, 128}}
		end
	end
end

-- draws the gem shadows at the bottom indicating where the piece will land.
local function drawDestinationShadow(self, piece, shift, account_for_doublecast)
	local grid = self.game.grid
	local toshow = {}
	local drop_locs = grid:getDropLocations(piece, shift)
	if account_for_doublecast then
		local pending_gems = grid:getPendingGems(piece.owner)

		-- also draw the previous gem's shadows
		for _, gem in pairs(pending_gems) do
			local first_empty_row = grid:getFirstEmptyRow(gem.column)
			-- shift needed is first_empty_row - (upper normal-placement-column - 1)
			-- this is bad code sorry
			local shift_needed = first_empty_row - (5 - 1)
			local row = gem.row + shift_needed
			gem:draw{RGBTable = {255, 255, 255, 160}, displace_y = self.game.grid.y[row] - gem.y}
		end
	end

	for i = 1, piece.size do
		toshow[i] = {}
		toshow[i].x = grid.x[ drop_locs[i][1] ] -- basin c column
		toshow[i].y = grid.y[ drop_locs[i][2] ] -- basin r row
		if toshow[i].x and toshow[i].y then
			piece.gems[i]:draw{pivot_x = toshow[i].x, pivot_y = toshow[i].y, RGBTable = {255, 255, 255, 160}}
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
		local pending_gems = self.game.grid:getPendingGems(piece.owner)
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
	self.game.screenshake_frames = self.game.screenshake_frames + math.max(0, damage * 5)
	self.game.screenshake_vel = self.game.screenshake_vel + math.max(0, damage)
end

local function pieceLandedInStagingArea(game, gems, place_type)
	local particles = game.particles
	local player_num = gems[1].owner
	local sign = player_num == 1 and 1 or -1
	local y = game.stage.height * 0.3
	if place_type == "double" then
		particles.words.generateDoublecast(game, player_num)
		game.sound:newSFX("doublecast")
		game.sound:newSFX("fountaindoublecast")
		for i = 1, #gems do
			particles.dust.generateStarFountain{game = game, color = gems[i].color,
				x = game.stage.width * (0.5 - sign * 0.1), y = y}
		end
	elseif place_type == "rush" then
		particles.words.generateRush(game, player_num)
		game.sound:newSFX("rush")
		game.sound:newSFX("fountainrush")
		for i = 1, #gems do
			particles.dust.generateStarFountain{game = game, color = gems[i].color,
				x = game.stage.width * (0.5 + sign * 0.2), y = y}
		end
	end
end

-- animation: places pieces at top of basin, and tweens them down.
-- also calls the cloud effects and the words/star fountains.
function uielements:putPendingAtTop(delay)
	local game = self.game
	local pending = {
		p1 = game.grid:getPendingGems(game.p1),
		p2 = game.grid:getPendingGems(game.p2),
	}

	for _, player_gems in pairs(pending) do
		local doubles, rushes = {}, {}
		for i = 1, #player_gems do
			local gem = player_gems[i]
			local target_y = gem.y
			gem.y = game.stage.height * -0.1
			gem:change{y = target_y, duration = game.TWEEN_TO_LANDING_ZONE_DURATION, easing = "outQuart", remove = true}

			if gem.place_type == "double" then
				doubles[#doubles+1] = gem
			elseif gem.place_type == "rush" then
				rushes[#rushes+1] = gem
			end
		end
		if #doubles == 2 then
			local is_horizontal = doubles[1].row == doubles[2].row
			game.particles.wordEffects.generateDoublecastCloud(game, doubles[1], doubles[2], is_horizontal)
			game.queue:add(game.TWEEN_TO_LANDING_ZONE_DURATION + delay, pieceLandedInStagingArea, game, doubles, "double")
		end
		if #rushes == 2 then
			local is_horizontal = rushes[1].row == rushes[2].row
			game.particles.wordEffects.generateRushCloud(game, rushes[1], rushes[2], is_horizontal)
			game.queue:add(game.TWEEN_TO_LANDING_ZONE_DURATION + delay, pieceLandedInStagingArea, game, rushes, "rush")
		end
	end
end

-- generates dust for active piece, and calculates tweens for gem shadows
-- only called during active phase
function uielements:update(dt)
	local game = self.game
	local player = game.me_player
	local pending_gems = game.grid:getPendingGems(player)
	local valid = false
	local place_type
	local cloud = game.particles.wordEffects.cloudExists(game.particles)

	-- if piece is held, generate effects and check if it's valid
	local active_piece = game.active_piece
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
				game.particles.wordEffects.generateDoublecastCloud(game, gem1, gem2, h)
			elseif valid and place_type == "rush" then
				local gem1, gem2 = game.active_piece.gems[1], active_piece.gems[2]
				local h = active_piece.is_horizontal
				game.particles.wordEffects.generateRushCloud(game, gem1, gem2, h)
			end
		elseif not valid or place_type == "normal" then
			game.particles.wordEffects.clear(game.particles)
		end
	elseif cloud then -- remove glow effects if piece not active
		game.particles.wordEffects.clear(game.particles)
	end

	-- tween the placedgem particles, if it's a doublecast
	if #pending_gems == 2 and valid then
		for _, v in pairs(game.particles.allParticles.PlacedGem) do v:tweenDown() end
	else
		for _, v in pairs(game.particles.allParticles.PlacedGem) do v:tweenUp() end
	end
end

return common.class("UIelements", uielements)
