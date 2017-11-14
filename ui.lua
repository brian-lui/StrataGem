local love = _G.love

local image = require 'image'
local common = require 'class.commons'
local Pic = require 'pic'

--[==================[
TIMER COMPONENT
--]==================]

local Timer = {}

function Timer:init(game)
	local stage = game.stage
	self.game = game

	self.text_scaling = function(t) return math.max(1 / (t * 2 + 0.4), 1) end
	self.text_transparency = function(t) return math.min(255 * 2.5 * t, 255) end
	self.time_remaining_int = 0
	self.text_multiplier = 2 -- how much to speed it up relative to an actual second
	self.FADE_SPEED = 15 -- transparency/frame to fade out at timer end
	self.timerbase = common.instance(Pic, game,
		{x = stage.timer.x, y = stage.timer.y, image = image.UI.timer_gauge})
	self.timerbar = common.instance(Pic, game,
		{x = stage.timer.x, y = stage.timer.y, image = image.UI.timer_bar})
	self.timertext = common.instance(Pic, game,
		{x = stage.timertext.x, y = stage.timertext.y, image = image.dummy})
end

function Timer:update(dt)
	-- set percentage of timer to show
	local w = (self.game.time_to_next / self.game.INIT_TIME_TO_NEXT) * self.timerbar.width
	local x_offset = (self.timerbar.width - w) * 0.5
	self.timerbar:setQuad(x_offset, 0, w, self.timerbar.height)

	if self.game.time_to_next == 0 then -- fade out
		self.timerbar.transparency = math.max(self.timerbar.transparency - self.FADE_SPEED, 0)
	else -- fade in
		self.timerbar.transparency = math.min(self.timerbar.transparency + self.FADE_SPEED, 255)
	end
	self.timerbase.transparency = self.timerbar.transparency

	-- update the timer text (3/2/1 countdown)
	local previous_time_remaining_int = self.time_remaining_int
	local time_remaining = (self.game.time_to_next * self.game.timeStep)
	self.time_remaining_int = math.ceil(time_remaining * self.text_multiplier)

	if time_remaining <= (3 / self.text_multiplier) and time_remaining > 0 then
		local t = self.time_remaining_int - time_remaining * self.text_multiplier
		self.timertext.scaling = self.text_scaling(t)
		self.timertext.transparency = self.text_transparency(t)
		if self.time_remaining_int < previous_time_remaining_int then
			self.timertext:newImage(image.UI.timer[self.time_remaining_int])
			self.game.sound:newSFX("sfx_countdown"..self.time_remaining_int)
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

--[==================[
END TIMER COMPONENT
--]==================]

local ui = {}

function ui:init(game)
	self.game = game

	self.timer = common.instance(Timer, game)

	-- Red X shown on gems in invalid placement spots
	self.redX = common.instance(Pic, game, {x = 0, y = 0, image = image.UI.redX})

end

-- returns the super drawables for player based on player MP, called every dt
-- shown super meter is less than the actual super meter when super particles are on screen
-- as particles disappear, they visually go into the super meter

function ui:drawSuper(player)
	local destroyedParticles = self.game.particles:getCount("destroyed", "MP", player.playerNum)

	local displayed_mp = math.min(player.MAX_MP, player.turn_start_mp + destroyedParticles)
	local fill_percent = 0.12 + 0.76 * displayed_mp / player.MAX_MP
	local img = player.super_meter_image
	img:setQuad(0, img.height * (1 - fill_percent), img.width, img.height * fill_percent)

	player.super_frame:draw()	-- super frame
	img:draw()	-- super meter

	if player.supering then
		player.super_glow.transparency = 255
		player.super_glow:draw()
		player.super_word:draw()
	elseif displayed_mp >= player.SUPER_COST then
		player.super_glow.transparency = math.ceil(math.sin(self.game.frame / 30) * 127.5 + 127.5)
		player.super_glow:draw()
	end

	player.super_overlay:draw()
end

function ui:drawBurst(player)
	local max_segs = 2
	local full_segs = (player.cur_burst / player.MAX_BURST) * max_segs
	local full_segs_int = math.floor(full_segs)
	local part_fill_percent = full_segs % 1

	-- update partial fill block length
	if part_fill_percent > 0 then
		local part_fill_block = player.burst_partial[full_segs_int + 1]
		local width = part_fill_block.width * part_fill_percent
		local start = player.ID == "P2" and part_fill_block.width - width or 0
		part_fill_block:setQuad(start, 0, width, part_fill_block.height)
	end

	player.burst_frame:draw()

	-- super meter
	for i = 1, max_segs do
		if full_segs >= i then
			player.burst_block[i]:draw()
		elseif full_segs + 1 > i then
			player.burst_partial[i]:draw()
		end
	end

	-- glow
	if full_segs >= 1 then
		player.burst_glow[full_segs_int].transparency = math.sin(self.game.frame / 30) * 127.5 + 127.5
		player.burst_glow[full_segs_int]:draw()
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
		if piece.horizontal then
			show[i].y = grid.y[1 + row_adj]
		else
			show[i].y = grid.y[i + row_adj]
		end
		if show[i].x and show[i].y then
			piece.gems[i]:draw{pivot_x = show[i].x, pivot_y = show[i].y, RGBTable = {0, 0, 0, 128}}
		end
	end
end

-- draws the gem shadows indicating where the piece will land.
local function drawDestinationShadow(self, piece, shift, account_for_doublecast)
	local grid = self.game.grid
	local toshow = {}
	local drop_locs = grid:getDropLocations(piece, shift)
	if account_for_doublecast then
		local pending_gems = grid:getPendingGems(piece.owner)
		for i = 1, piece.size do
			for _, gem in pairs(pending_gems) do
				if drop_locs[i][1] == gem.column then
					drop_locs[i][2] = drop_locs[i][2] - 1
				end
			end
		end
	end

	for i = 1, piece.size do
		-- shadow at bottom
		toshow[i] = {}
		toshow[i].x = grid.x[ drop_locs[i][1] ] -- tub c column
		toshow[i].y = grid.y[ drop_locs[i][2] ] -- tub r row
		if toshow[i].x and toshow[i].y then
			piece.gems[i]:draw{pivot_x = toshow[i].x, pivot_y = toshow[i].y, RGBTable = {255, 255, 255, 160}}
		end
	end
end

-- draws the gem shadows indicating where the piece will land.
local function drawDoublecastGemShadow(self, gem, row)
	gem:draw{RGBTable = {255, 255, 255, 160}, displace_y = self.game.grid.y[row] - gem.y}
end

-- show all the possible shadows!
function ui:showShadows(piece)
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
		if account_for_doublecast then
			local row1, row2 = self.game.grid:getFirstEmptyRow(pending_gems[1].column), self.game.grid:getFirstEmptyRow(pending_gems[2].column)
			if pending_gems[1].column == pending_gems[2].column then
				drawDoublecastGemShadow(self, pending_gems[1], row2 - 1)	-- except up 1
			else
				drawDoublecastGemShadow(self, pending_gems[1], row2)
			end
			drawDoublecastGemShadow(self, pending_gems[2], row2)
		end
		drawDestinationShadow(self, piece, shift, account_for_doublecast)
	end
end

-- This is the red X shown on top of the active gem
function ui:showX(piece)
	local legal = piece:isDropLegal()
	local midline, on_left = piece:isOnMidline()
	local shift = midline and (on_left and -1 or 1) or 0
	local valid = piece:isDropValid(shift)

	for i = piece.size, 1, -1 do
		if (legal or midline) and not valid then
			self.redX:draw{x = piece.gems[i].x, y = piece.gems[i].y}
		end
	end
end

-- sends screenshake data depending on how many gems matched, called on match
function ui:screenshake(damage)
	self.game.screenshake_frames = self.game.screenshake_frames + math.max(0, damage * 5)
	self.game.screenshake_vel = math.max(0, damage)
end

-- at turn end, move the gems to the top of the screen so they fall down nicely
function ui:putPendingAtTop()
	local pending = {
		{gems = self.game.grid:getPendingGems(self.game.p1), me = 1, foe = 2},
		{gems = self.game.grid:getPendingGems(self.game.p2), me = 2, foe = 1},
	}
	for _, piece in pairs(pending) do
		local effect = {}
		for i = 1, #piece.gems do
			local gem = piece.gems[i]
			local owner = self.game:playerByIndex(piece.me)
			local exit
			local target_y = gem.y
			if owner.place_type == "double" and (gem.row == 1 or gem.row == 2) then
				effect[#effect+1] = gem
				effect.func = self.game.particles.wordEffects.generateDoublecastCloud
				exit = {gem.landedInStagingArea, gem, "double", owner}
			elseif gem.row == 3 or gem.row == 4 and gem.owner == piece.foe then
				effect[#effect+1] = gem
				effect.func = self.game.particles.wordEffects.generateRushCloud
				exit = {gem.landedInStagingArea, gem, "rush", self.game:playerByIndex(piece.foe)}
			end
			gem:change{y = self.game.stage.height * -0.1}
			gem:change{y = target_y, duration = 24, easing = "outQuart", exit = exit}
		end
		if #effect > 0 then
			local h = effect[1].row == effect[2].row
			effect.func(self.game, effect[1], effect[2], h)
		end
	end
end


-- generates dust for active piece, and calculates tweens for gem shadows
-- only called during active phase
function ui:update(dt)
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
		--local legal = game.active_piece:isDropLegal()
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
				local h = active_piece.horizontal
				game.particles.wordEffects.generateDoublecastCloud(game, gem1, gem2, h)
			elseif valid and place_type == "rush" then
				local gem1, gem2 = game.active_piece.gems[1], active_piece.gems[2]
				local h = active_piece.horizontal
				game.particles.wordEffects.generateRushCloud(game, gem1, gem2, h)
			end
		elseif not valid or place_type == "normal" then
			game.particles.wordEffects.clear(game.particles)
		end
	elseif cloud then -- remove glow effects if piece not active
		game.particles.wordEffects.clear(game.particles)
	end

	-- tween gem particles
	if #pending_gems == 2 and valid then
		for i = 1, #pending_gems do
			pending_gems[i].tweening:update(dt)
		end
	else
		for i = 1, #pending_gems do
			pending_gems[i].tweening:reset()
		end
	end
end

return common.class("UI", ui)
