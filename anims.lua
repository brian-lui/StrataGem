--[[
  This module provides methods to calculate the UI images to draw onto the screen.
  Uses piece and grid functions, which are required in main.lua
--]]

require 'inits'
local stage = game.stage
local particles = game.particles
local UI = require 'uielements'
local anims = {}

-- returns the super drawables for player based on player MP, called every dt
-- shown super meter is less than the actual super meter when super particles are on screen
-- as particles disappear, they visually go into the super meter
-- TODO: maybe can refactor this to remove old_mp
function anims.drawSuper(player)
	local super_particles = particles.getNumber("SuperParticles", player)
	local actual_mp = math.max(player.cur_mp, 0)
	local displayed_mp = math.max(actual_mp - super_particles, 0)
	if player.old_mp + super_particles > player.MAX_MP then 
		displayed_mp = math.max(displayed_mp, player.old_mp)
	end
	local fill_percent = displayed_mp / player.MAX_MP
	local img = player.super_meter_image
	img:changeQuad(0, img.height * (1 - fill_percent), img.width, img.height * fill_percent)
	img.y = stage.super[player.ID].y + img.height * (1 - fill_percent)

	player.super_frame:draw() -- super frame
	img:draw() -- super meter
	---[[
	-- glow
	if player.supering then
		player.super_glow.transparency = 255
		player.super_glow:draw()
		player.super_word:draw()
	elseif player.cur_mp >= player.SUPER_COST then
		player.super_glow.transparency = math.ceil(math.sin(frame / 30) * 127.5 + 127.5)
		player.super_glow:draw()
	end
	--]]
	-- super word, if active
	--[[
	if player.supering then
		player.super_word:draw()
	end
	--]]
end

-- returns the burst drawables for player based on player burst, called every dt
function anims.drawBurst(player)
	local max_segs = 2
	local segment_width = player.MAX_BURST / max_segs
	local full_segs = math.min(player.cur_burst / segment_width, max_segs)
	local part_fill_percent = full_segs % 1

	local flip = player.ID == "P2"
	-- update partial fill block length
	if part_fill_percent > 0 then
		local part_fill_block = player.burst_partial[math.floor(full_segs) + 1]
		local width = math.floor(part_fill_block.width * part_fill_percent)
		part_fill_block:changeQuad(0, 0, width, part_fill_block.height)
	end

	player.burst_frame:draw() -- frame

	-- super meter
	for i = 1, max_segs do
		if full_segs >= i then
			player.burst_block[i]:draw(flip)
		elseif full_segs + 1 > i then -- partial fill
			player.burst_partial[i]:draw(flip, player.burst_block[i].quad_x, player.burst_block[i].quad_y)
		end
	end

	-- glow
	if full_segs >= 1 then
		player.burst_glow[math.floor(full_segs)].transparency = math.ceil(math.sin(frame / 30) * 127.5 + 127.5)
		player.burst_glow[math.floor(full_segs)]:draw()
	end
end

-- draws the shadow underneath the player's gem piece, called if gem is picked up
local function drawUnderGemShadow(piece)
	for i = 1, piece.size do
		local gem_shadow_x = piece.gems[i].x + 0.1 * stage.gem_width
		local gem_shadow_y = piece.gems[i].y + 0.1 * stage.gem_height
		piece.gems[i]:draw(gem_shadow_x, gem_shadow_y, {0, 0, 0, 24})
	end
end

-- show the shadow at the top that indicates where the piece will be placed
local function drawPlacementShadow(piece, shift)
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
		show[i].x = stage.grid.x[ drop_cols[i] ]
		if piece.horizontal then
			show[i].y = stage.grid.y[1 + row_adj]
		else
			show[i].y = stage.grid.y[i + row_adj]
		end
		if show[i].x and show[i].y then
			piece.gems[i]:draw(show[i].x, show[i].y, {0, 0, 0, 128})
		end
	end
end

-- draws the gem shadows indicating where the piece will land.
local function drawDoublecastGemShadow(gem)
	local dropped_row = stage.grid:getFirstEmptyRow(gem.column)
	-- gem:draw takes a y value relative to the gem's y-value
	local dropped_y = stage.grid.y[dropped_row] - gem.y
	gem:draw(nil, nil, {255, 255, 255, 160}, nil, 0, dropped_y)
end

-- draws the gem shadows indicating where the piece will land.
local function drawDestinationShadow(piece, shift, account_for_doublecast)
	local toshow = {}
	local drop_locs = stage.grid:getDropLocations(piece, shift)
	if account_for_doublecast then
		local pending_gems = stage.grid:getPendingGems(piece.owner)
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
		toshow[i].x = stage.grid.x[ drop_locs[i][1] ] -- tub c column
		toshow[i].y = stage.grid.y[ drop_locs[i][2] ] -- tub r row
		if toshow[i].x and toshow[i].y then
			piece.gems[i]:draw(toshow[i].x, toshow[i].y, {255, 255, 255, 160})
		end
	end
end

-- show all the possible shadows!
function anims.showShadows(piece)
	local midline, on_left = piece:isOnMidline()
	local shift = 0
	if midline then
		if on_left then shift = -1 else shift = 1 end
	end
	local valid = piece:isDropValid(shift)
	-- TODO: somehow account for variable piece size
	local pending_gems = stage.grid:getPendingGems(piece.owner)
	local account_for_doublecast = #pending_gems == 2
	drawUnderGemShadow(piece)
	if valid then
		drawPlacementShadow(piece, shift)
		if account_for_doublecast then
			drawDoublecastGemShadow(pending_gems[1])
			drawDoublecastGemShadow(pending_gems[2])
		end
		drawDestinationShadow(piece, shift, account_for_doublecast)
	end
end

-- This is the red X shown on top of the active gem
function anims.showX(piece)
	local legal = piece:isDropLegal()
	local midline, on_left = piece:isOnMidline()
	local shift = 0
	if midline then
		if on_left then shift = -1 else shift = 1 end
	end
	local valid = piece:isDropValid(shift)

	for i = piece.size, 1, -1 do
		if (legal or midline) and not valid then
			UI.redX:draw(nil, piece.gems[i].x, piece.gems[i].y)
		end
	end
end

-- sends screenshake data depending on how many gems matched, called on match
function anims.screenshake(damage)
	game.screenshake_frames = game.screenshake_frames + math.max(0, damage * 5)
	game.screenshake_vel = math.max(0, damage)
end

-- at turn end, move the gems to the top of the screen so they fall down nicely
function anims.putPendingAtTop()
	local own_tbl = {p1, p2}
	local pending = {
		{gems = stage.grid:getPendingGems(p1), me = 1, foe = 2},
		{gems = stage.grid:getPendingGems(p2), me = 2, foe = 1},
	}
	for _, piece in pairs(pending) do
		local effect = {}
		for i = 1, #piece.gems do
			local gem = piece.gems[i]
			local owner = own_tbl[piece.me]
			local exit
			local target_y = gem.y
			if owner.place_type == "double" and (gem.row == 1 or gem.row == 2) then
				effect[#effect+1] = gem
				effect.func = particles.wordEffects.generateDoublecastCloud
				exit = {gem.landedInStagingArea, gem, "double", owner}
			elseif gem.row == 3 or gem.row == 4 and gem.owner == piece.foe then
				effect[#effect+1] = gem
				effect.func = particles.wordEffects.generateRushCloud
				exit = {gem.landedInStagingArea, gem, "rush", own_tbl[piece.foe]}
			end
			gem:moveTo{y = stage.height * -0.1}
			gem:moveTo{y = target_y, duration = 24, easing = "outQuart", exit = exit}
		end
		if #effect > 0 then
			local h = effect[1].row == effect[2].row
			effect.func(particles.wordEffects, effect[1], effect[2], h)
		end
	end
end


-- generates dust for active piece, and calculates tweens for gem shadows
-- only called during active phase
function anims.update(dt)
	local player = game.me_player
	local pending_gems = stage.grid:getPendingGems(player)
	local valid = false
	local place_type
	local cloud = particles.wordEffects:cloudExists()

	-- if piece is held, generate effects and check if it's valid
	if game.active_piece then
		game.active_piece:generateDust()
		local legal = game.active_piece:isDropLegal()
		local midline, on_left = game.active_piece:isOnMidline()
		local shift = 0
		if midline then
			if on_left then shift = -1 else shift = 1 end
		end
		valid, place_type = game.active_piece:isDropValid(shift)

		-- glow effects
		if not cloud then
			if valid and place_type == "double" then
				--TODO: support variable number of gems
				local gem1, gem2 = game.active_piece.gems[1], game.active_piece.gems[2]
				local h = game.active_piece.horizontal
				particles.wordEffects:generateDoublecastCloud(gem1, gem2, h)
			elseif valid and place_type == "rush" then
				local gem1, gem2 = game.active_piece.gems[1], game.active_piece.gems[2]
				local h = game.active_piece.horizontal
				particles.wordEffects:generateRushCloud(gem1, gem2, h)
			end
		elseif not valid or place_type == "normal" then
			particles.wordEffects:clear()
		end
	elseif cloud then -- remove glow effects if piece not active
		particles.wordEffects:clear()
	end

	-- tween gem particles
	if #pending_gems == 2 and valid then
		for i = 1, #pending_gems do	pending_gems[i].tweening:update(dt)	end
	else
		for i = 1, #pending_gems do pending_gems[i].tweening:reset() end
	end
end

return anims
