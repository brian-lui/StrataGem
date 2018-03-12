local love = _G.love
local FONT = _G.FONT
local common = require "class.commons"
local image = require 'image'
local Pic = require 'pic'
local pointIsInRect = require "utilities".pointIsInRect
local spairs = require "utilities".spairs

local gs_main = {name = "gs_main"}

function gs_main:init()
	self.camera = common.instance(require "camera")
	gs_main.ui = {clickable = {}, static = {}, popup_clickable = {}, popup_static = {}}
end

-- refer to game.lua for instructions for createButton and createImage
function gs_main:createButton(params)
	return self:_createButton(gs_main, params)
end

function gs_main:createImage(params)
	return self:_createImage(gs_main, params)
end

function gs_main:enter()
	local stage = self.stage

	local settings_image
	if self.type == "1P" then
		settings_image = image.button.pause
	elseif self.type == "Netplay" then
		settings_image = image.button.stop
	else
		print("invalid game type!")
	end

	self:_createSettingsMenu(gs_main, {
		exitstate = "gs_title",
		settings_icon = settings_image,
		settings_iconpush = settings_image,
	})

	self.sound:stopBGM()
	gs_main.clicked = nil
	gs_main.current_background = common.instance(self.background[self.current_background_name], self)
	self.settings_menu_open = false

	gs_main.createImage(self, {
		name = "tub",
		image = image.UI.tub,
		end_x = stage.tub.x,
		end_y = stage.tub.y,
	})

	local BURST_SEGMENTS = 2
	for player in self:players() do
		local ID = player.ID

		-- burst meter objects
		local burst_frame_img = ID == "P1" and image.UI.gauge_gold or image.UI.gauge_silver
		gs_main.createImage(self, {
			name = ID .. "burstframe",
			image = burst_frame_img,
			end_x = stage.burst[ID].frame.x,
			end_y = stage.burst[ID].frame.y,
		})

		for i = 1, BURST_SEGMENTS do
			gs_main.createImage(self, {
				name = ID .. "burstblock" .. i,
				image = player.burst_images.full,
				end_x = stage.burst[ID][i].x,
				end_y = stage.burst[ID][i].y,
			})
			gs_main.createImage(self, {
				name = ID .. "burstpartial" .. i,
				image = player.burst_images.partial,
				end_x = stage.burst[ID][i].x,
				end_y = stage.burst[ID][i].y,
			})
			gs_main.createImage(self, {
				name = ID .. "burstglow" .. i,
				image = player.burst_images.glow[i],
				end_x = stage.burst[ID][i].glow_x,
				end_y = stage.burst[ID][i].glow_y,
			})
		end

		-- super meter objects
		local super_function = function() print("opposite guy button pushed!") end
		if self.me_player.ID == ID then
			super_function = function() player:toggleSuper() end
 		end

		gs_main.createButton(self, {
			name = ID .. "super",
			image = player.super_images.empty,
			image_pushed = player.super_images.empty,
			end_x = stage.super[ID].x,
			end_y = stage.super[ID].y,
			pushed_sfx = "dummy",
			action = super_function,
		})
		gs_main.createImage(self, {
			name = ID .. "superword",
			image = player.super_images.word,
			end_x = stage.super[ID].x,
			end_y = stage.super[ID].word_y,
		})
		gs_main.createImage(self, {
			name = ID .. "supermeter",
			image = player.super_images.full,
			end_x = stage.super[ID].x,
			end_y = stage.super[ID].y,
		})
		gs_main.createImage(self, {
			name = ID .. "superglow",
			image = player.super_images.glow,
			end_x = stage.super[ID].x,
			end_y = stage.super[ID].y,
		})
		gs_main.createImage(self, {
			name = ID .. "superoverlay",
			image = player.super_images.overlay,
			end_x = stage.super[ID].x,
			end_y = stage.super[ID].y,
		})
	end
end

function gs_main:openSettingsMenu()
	if self.type == "1P" then self.paused = true end
	self:_openSettingsMenu(gs_main)
end

function gs_main:closeSettingsMenu()
	if self.type == "1P" then self.paused = false end
	self:_closeSettingsMenu(gs_main)
end

local function timeDip(self, logic_function, ...)
--[[ This is a wrapper to do stuff at 60hz. We want the logic stuff to be at
	60hz, but the drawing can be at whatever! So each love.update runs at
	unbounded speed, and then adds dt to bucket. When bucket is larger
	than 1/60, it runs the logic functions until bucket is less than 1/60,
	or we reached the maximum number of times to run the logic this cycle. --]]
	for _ = 1, 4 do -- run a maximum of 4 logic cycles per love.update cycle
		if self.timeBucket >= self.timeStep then
			logic_function(...)
			self.frame = self.frame + 1
			self.timeBucket = self.timeBucket - self.timeStep
		end
	end
end

function gs_main:update(dt)
	if not self.paused then
		timeDip(self, function() self.phase:run(self.timeStep) end)
		self.particles:update(dt) -- variable fps
		gs_main.current_background:update(dt) -- variable fps
		self.ui.timer:update(dt)
		self.ui:updateBursts(gs_main)
		self.ui:updateSupers(gs_main)
		self.animations:updateAll(dt)
		self.screenshake_frames = math.max(0, self.screenshake_frames - 1)
		self.timeBucket = self.timeBucket + dt
	end

	for _, tbl in pairs(gs_main.ui) do
		for _, v in pairs(tbl) do v:update(dt) end
	end
end

-- draw all the non-gem screen elements: super bar, sprite
function gs_main:drawScreenElements(params)
	-- under-platform trails
	for _, v in pairs(self.particles.allParticles.PlatformTinyStar) do v:draw(params) end
	for _, v in pairs(self.particles.allParticles.PlatformStar) do v:draw(params) end
	gs_main.ui.static.tub:draw(params)
	self.ui.timer:draw(params)	-- timer bar

	for player in self:players() do
		player.animation:draw{h_flip = player.ID == "P2"} -- sprite
	end
end

-- screenshake effect
function gs_main.screenshake(self, shake)
	local frame = self.frame
	shake = math.min(shake or 6, 6)
	local h_displacement = shake * (frame % 7 * 0.5 + frame % 13 * 0.25 + frame % 23 / 6 - 5)
	local v_displacement = shake * (frame % 5 * 2/3 + frame % 11 * 0.25 + frame % 17 / 6 - 5)
	self.camera:setPosition(h_displacement, v_displacement)
end

-- draw gems and related objects (platforms, particles)
function gs_main:drawGems(params)
	local allParticles = self.particles.allParticles

	-- cache CharEffects draw order to save CPU
	local char_effect_draws = {}
	for i = -4, 5 do char_effect_draws[i] = {n = 0} end
	for _, v in spairs(allParticles.CharEffects) do
		local draw_order = v.draw_order or 1
		local group = char_effect_draws[draw_order]
		group.n = group.n + 1
		group[group.n] = v
	end

	-- gem platforms
	for player in self:players() do
		for i = 0, #player.hand do
			if player.hand[i].platform then
				player.hand[i].platform:draw(params)
			end
		end
	end

	-- under-gem particles
	for _, instance in pairs(allParticles.WordEffects) do instance:draw(params) end
	for _, instance in pairs(allParticles.Dust) do instance:draw(params) end
	for _, instance in pairs(allParticles.PopParticles) do instance:draw(params) end
	for i = -4, 0 do
		local char_effects = char_effect_draws[i]
		for j = 1, char_effects.n do char_effects[j]:draw() end
	end

	-- hand gems and pending-garbage gems
	for player in self:players() do
		for i = 1, player.hand_size do
			if player.hand[i].piece and player.hand[i].piece ~= self.active_piece then
				for _ = 1, player.hand[i].piece.size do
						player.hand[i].piece:draw(params)
				end
			end
		end
		for i = 1, #player.hand.garbage do
			player.hand.garbage[i]:draw(params)
		end
	end

	for gem, r in self.grid:gems() do
		if self.current_phase == "Action" and r <= 6 then
			gem:draw{RGBTable = {255, 255, 255, 192}}
		else
			gem:draw(params)
		end
	end

	-- over-gem particles
	for _, v in pairs(allParticles.GemImage) do v:draw(params) end
	for _, v in pairs(allParticles.SuperParticles) do v:draw(params) end
	for _, v in pairs(allParticles.DamageTrail) do v:draw(params) end
	for _, v in pairs(allParticles.HealingTrail) do v:draw(params) end
	for _, v in pairs(allParticles.GarbageParticles) do v:draw(params) end
	for _, v in pairs(allParticles.Healing) do v:draw(params) end
	for _, v in pairs(allParticles.Damage) do v:draw(params) end
	for _, v in pairs(allParticles.ExplodingGem) do v:draw(params) end
	for i = 1, 5 do
		local char_effects = char_effect_draws[i]
		for j = 1, char_effects.n do char_effects[j]:draw() end
	end
	for i = 1, 3 do
		for _, v in pairs(allParticles.SuperFreezeEffects) do
			if v.draw_order == i then v:draw(params) end
		end
	end

	-- draw the gem when it's been grabbed by the player
	if self.active_piece then
		self.ui:showShadows(self.active_piece)
		self.active_piece:draw(params)
		self.ui:showX(self.active_piece)
	end

	-- more over-gem particles
	for _, v in pairs(allParticles.OverDust) do v:draw(params) end
	for _, v in pairs(allParticles.ExplodingPlatform) do v:draw(params) end
	for _, v in pairs(allParticles.UpGem) do v:draw(params) end
	for _, v in pairs(allParticles.PlacedGem) do v:draw(params) end
end

-- draw text items
function gs_main:drawText(params)
	local grid = self.grid
	-- words
	for _, v in pairs(self.particles.allParticles.Words) do
		v:draw(params)
	end

	-- debug: row/column display
	if self.debug_drawGrid then
		love.graphics.push("all")
			love.graphics.setColor(0, 255, 0)
			for r = 1, grid.ROWS + 1 do
				love.graphics.print(r, 200, grid.y[r])
			end
			for c = 0, grid.COLUMNS + 1 do
				love.graphics.print(c, grid.x[c], 200)
			end
		love.graphics.pop()
	end

	-- debug: top right HUD
	if self.debug_overlay then
		love.graphics.push("all")
			love.graphics.setFont(FONT.SLIGHTLY_BIGGER)
			love.graphics.setColor(255, 255, 255)
			love.graphics.printf(self.debug_overlay(), 0, 40, self.stage.width, "center")
		love.graphics.pop()
	end

	-- debug: overlays
	love.graphics.push("all")
		love.graphics.setColor(0, 0, 0)
		love.graphics.setFont(FONT.REGULAR)
		if self.debug_drawGemOwners then
			for gem in grid:gems() do
				love.graphics.print("OWN:" .. gem.owner, gem.x - gem.width * 0.4, gem.y - gem.height * 0.3)
				love.graphics.print("ROW:" .. gem.row, gem.x - gem.width * 0.4, gem.y - gem.height * 0.1)
				love.graphics.print("COL:" .. gem.column, gem.x - gem.width * 0.4, gem.y + gem.height * 0.1)
				if gem.is_in_a_horizontal_match then
					love.graphics.print("H", gem.x - gem.width * 0.2, gem.y + gem.height * 0.3)
				end
				if gem.is_in_a_vertical_match then
					love.graphics.print("V", gem.x + gem.width * 0.2, gem.y + gem.height * 0.3)
				end
			end

		end
		if self.debug_drawParticleDestinations then
			for _, p in pairs(self.particles.allParticles.Damage) do
				love.graphics.print(p.final_loc_idx, p.x, p.y)
			end
		end
		if self.debug_drawGamestate then
			local toprint = {}
			local i = 1
			local colors = {red = "R", blue = "B", green = "G", yellow = "Y"}
			for row = grid.PENDING_START_ROW, grid.BASIN_END_ROW do
				for col = 1, 8 do
					toprint[i] = grid[row][col].gem and colors[grid[row][col].gem.color] or " "
					i = i + 1
				end
				toprint[i] = "\n"
				i = i + 1
			end

			love.graphics.print(table.concat(toprint), 50, 400)
		end
		if self.debug_drawDamage then
			local p1hand, p2hand = self.p1.hand, self.p2.hand

			local p1_destroyed_damage_particles = self.particles:getCount("destroyed", "Damage", 2)
			local p1_destroyed_healing_particles = self.particles:getCount("destroyed", "Healing", 1)
			local p1_displayed_damage = (self.p1.hand.turn_start_damage + p1_destroyed_damage_particles/3 - p1_destroyed_healing_particles/5)

			local p2_destroyed_damage_particles = self.particles:getCount("destroyed", "Damage", 1)
			local p2_destroyed_healing_particles = self.particles:getCount("destroyed", "Healing", 2)
			local p2_displayed_damage = (self.p2.hand.turn_start_damage + p2_destroyed_damage_particles/3 - p2_destroyed_healing_particles/5)

			local p1print = "Actual damage " .. p1hand.damage .. "\nShown damage " .. p1_displayed_damage
			local p2print = "Actual damage " .. p2hand.damage .. "\nShown damage " .. p2_displayed_damage
			
			love.graphics.setFont(FONT.SLIGHTLY_BIGGER)
			love.graphics.print(p1print, p1hand[2].x - 120, 150)
			love.graphics.print(p2print, p2hand[2].x - 180, 150)
		end
	love.graphics.pop()
end

function gs_main:drawButtons(params)
	gs_main.ui.clickable.settings:draw(params)
	self:_drawSettingsMenu(gs_main, params)
end

function gs_main:drawUI(params)
	local draws = {"tub", "P1burstframe", "P2burstframe", "P1burstblock1",
		"P1burstblock2", "P2burstblock1", "P2burstblock2", "P1burstpartial1",
		"P1burstpartial2", "P2burstpartial1", "P2burstpartial2", "P1burstglow1",
		"P1burstglow2", "P2burstglow1", "P2burstglow2", "P1superword", "P2superword",
		"P1supermeter", "P2supermeter", "P1superglow", "P2superglow", 
		"P1superoverlay", "P2superoverlay",}

	gs_main.ui.clickable.P1super:draw(params)
	gs_main.ui.clickable.P2super:draw(params)
	for i = 1, #draws do gs_main.ui.static[ draws[i] ]:draw(params) end
	gs_main.ui.clickable.settings:draw(params)
end

function gs_main:draw()
	local darkened = self.screen_darkened
	gs_main.current_background:draw{darkened = darkened}
	self.camera:set(1, 1)
		if self.screenshake_frames > 0 then
			gs_main.screenshake(self, self.screenshake_vel)
		else
			self.camera:setPosition(0, 0)
		end

		gs_main.drawUI(self, {darkened = darkened})
		gs_main.drawScreenElements(self, {darkened = darkened})
		gs_main.drawGems(self, {darkened = darkened})
		--gs_main.drawAnimations(self, {darkened = darkened})
	self.camera:unset()
	gs_main.drawText(self, {darkened = darkened})
	gs_main.drawButtons(self)
end

function gs_main:mousepressed(x, y)
	self.lastClickedFrame = self.frame
	self.lastClickedX, self.lastClickedY = x, y

	local player = self.me_player
	if not self.paused then
		for i = 1, player.hand_size do
			if player.hand[i].piece and pointIsInRect(x, y, player.hand[i].piece:getRect()) then
				if self.current_phase == "Action" then
					player.hand[i].piece:select()
				else
					self.active_piece = player.hand[i].piece
				end
			end
		end
	end

	self:_mousepressed(x, y, gs_main)
end

local QUICKCLICK_FRAMES = 15
local QUICKCLICK_MAX_MOVE = 0.05

function gs_main:mousereleased(x, y)
	local player = self.me_player
	if self.active_piece then
		local quickclick = self.frame - self.lastClickedFrame < QUICKCLICK_FRAMES
		local nomove = math.abs(x - self.lastClickedX) < self.stage.width * QUICKCLICK_MAX_MOVE and
			math.abs(y - self.lastClickedY) < self.stage.height * QUICKCLICK_MAX_MOVE
		if quickclick and nomove then self.active_piece:rotate() end
		if self.current_phase == "Action" then self.active_piece:deselect() end
		self.active_piece = false
	end

	self:_mousereleased(x, y, gs_main)
end

function gs_main:mousemoved(x, y)
	if self.active_piece and self.current_phase == "Action" then
		self.active_piece:change{x = x, y = y}
	end

	self:_mousemoved(x, y, gs_main)
end

return gs_main
