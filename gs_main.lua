local love = _G.love
local FONT = _G.FONT
local common = require "class.commons"
local image = require 'image'
local Pic = require 'pic'
local pointIsInRect = require "utilities".pointIsInRect

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
	self.dying_gems = {} -- this creates the dying_gems table in Game. Sad!
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
			pushed_sfx = "sfx_dummy",
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


--]]
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
	timeDip(self, function() self.phaseManager:run(self.timeStep) end)
	self.particles:update(dt) -- variable fps
	gs_main.current_background:update(dt) -- variable fps
	self.ui.timer:update(dt)
	self.ui:updateBursts(gs_main)
	self.ui:updateSupers(gs_main)	
	self.animations:updateAll(dt)
	self.screenshake_frames = math.max(0, self.screenshake_frames - 1)
	self.timeBucket = self.timeBucket + dt

	for _, tbl in pairs(gs_main.ui) do
		for _, v in pairs(tbl) do v:update(dt) end
	end
end

-- draw all the non-gem screen elements: super bar, sprite
function gs_main:drawScreenElements(...)
	-- under-platform trails
	for _, v in pairs(self.particles.allParticles.PlatformTinyStar) do v:draw(...) end
	for _, v in pairs(self.particles.allParticles.PlatformStar) do v:draw(...) end
	gs_main.ui.static.tub:draw(...)
	self.ui.timer:draw(...)	-- timer bar

	for player in self:players() do
		player.animation:draw{h_flip = player.ID == "P2"} -- sprite
	end
end

-- screenshake effect
function gs_main.screenshake(self, shake)
	local frame = self.frame
	shake = shake or 6
	local h_displacement = shake * (frame % 7 * 0.5 + frame % 13 * 0.25 + frame % 23 / 6 - 5)
	local v_displacement = shake * (frame % 5 * 2/3 + frame % 11 * 0.25 + frame % 17 / 6 - 5)
	self.camera:setPosition(h_displacement, v_displacement)
end

-- draw gems and related objects (platforms, particles)
function gs_main:drawGems(...)
	local allParticles = self.particles.allParticles
	-- gem platforms
	for player in self:players() do
		for i = 0, #player.hand do
			if player.hand[i].platform then
				player.hand[i].platform:draw(...)
			end
		end
	end

	-- under-gem particles
	for _, instance in pairs(allParticles.WordEffects) do instance:draw(...) end
	for _, instance in pairs(allParticles.Dust) do instance:draw(...) end
	for _, instance in pairs(allParticles.Pop) do instance:draw(...) end


	-- hand gems and pending-garbage gems
	for player in self:players() do
		for i = 1, player.hand_size do
			if player.hand[i].piece and player.hand[i].piece ~= self.active_piece then
				for _ = 1, player.hand[i].piece.size do
						player.hand[i].piece:draw(...)
				end
			end
		end
		for i = 1, #player.hand.garbage do
			player.hand.garbage[i]:draw(...)
		end
	end

	-- for i = 1, #game.dying_gems do blah blah

	local function blockBottomGemRow()
		local stage = self.stage
		local grid = self.grid
	-- stencil function to hide gems in bottom row
	-- makes it look nicer when gems are generated and push up from the bottom
		local x = 0.5 * (grid.x[0] + grid.x[1])
		local y = 0.5 * (grid.y[grid.rows] + grid.y[grid.rows + 1])
		local width = grid.x[grid.columns] - grid.x[0]
		local height = stage.gem_width
		love.graphics.rectangle("fill", x, y, width, height)
	end

	-- grid gems
	love.graphics.push("all")
		love.graphics.stencil(blockBottomGemRow, "replace", 1)
		love.graphics.setStencilTest("equal", 0)
		for gem, r in self.grid:gems() do
			if self.phase == "Action" and r <= 6 then
				gem:draw{RGBTable = {255, 255, 255, 192}} -- TODO: make this darkened too
			else
				gem:draw(...)
			end
		end
		love.graphics.setStencilTest()
	love.graphics.pop()

	-- over-gem particles
	for _, v in pairs(allParticles.SuperParticles) do v:draw(...) end
	for _, v in pairs(allParticles.DamageTrail) do v:draw(...) end
	for _, v in pairs(allParticles.GarbageParticles) do v:draw(...) end
	for _, v in pairs(allParticles.Damage) do v:draw(...) end
	for _, v in pairs(allParticles.ExplodingGem) do v:draw(...) end
	for _, v in pairs(allParticles.PieEffects) do v:draw(...) end
	for _, v in pairs(allParticles.CharEffects) do v:draw(...) end
	for i = 1, 3 do
		for _, v in pairs(allParticles.SuperFreezeEffects) do
			if v.draw_order == i then
				v:draw(...)
			end
		end
	end

	-- draw the gem when it's been grabbed by the player
	if self.active_piece then
		self.ui:showShadows(self.active_piece)
		self.active_piece:draw(...)
		self.ui:showX(self.active_piece)
	end

	-- over-dust
	for _, v in pairs(allParticles.OverDust) do v:draw(...) end

	-- exploded platform pieces
	for _, v in pairs(allParticles.ExplodingPlatform) do v:draw(...) end

	-- uptween gems
	for _, v in pairs(allParticles.UpGem) do v:draw(...) end
end

-- draw text items
function gs_main:drawText(...)
	local grid = self.grid
	-- words
	for _, v in pairs(self.particles.allParticles.Words) do
		v:draw(...)
	end

	-- debug: row/column display
	if self.debug_drawGrid then
		love.graphics.push("all")
			love.graphics.setColor(0, 255, 0)
			for r = 0, grid.rows + 1 do
				love.graphics.print(r, 200, grid.y[r])
			end
			for c = 0, grid.columns + 1 do
				love.graphics.print(c, grid.x[c], 200)
			end
		love.graphics.pop()
	end

	-- debug: top right HUD
	if self.debug_overlay then
		love.graphics.push("all")
			love.graphics.setColor(255, 255, 255)
			love.graphics.printf(self.debug_overlay(), 0, 40, 1000, "right")
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
			for row = 0, 14 do
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
			love.graphics.print(p1hand.damage, p1hand[2].x - 60, p1hand[2].y)
			love.graphics.print(p2hand.damage, p2hand[2].x + 60, p2hand[2].y)
		end
	love.graphics.pop()
end

function gs_main:drawButtons(...)
	gs_main.ui.popup_static.settingsframe:draw(...)
	gs_main.ui.popup_static.settingstext:draw(...)
	gs_main.ui.popup_clickable.confirm:draw(...)
	gs_main.ui.popup_clickable.cancel:draw(...)
	gs_main.ui.clickable.settings:draw(...)
end
function gs_main:drawUI(...)
	local draws = {"tub", "P1burstframe", "P2burstframe", "P1burstblock1",
		"P1burstblock2", "P2burstblock1", "P2burstblock2", "P1burstpartial1",
		"P1burstpartial2", "P2burstpartial1", "P2burstpartial2", "P1burstglow1",
		"P1burstglow2", "P2burstglow1", "P2burstglow2", "P1superword", "P2superword",
		"P1supermeter", "P2supermeter", "P1superoverlay", "P2superoverlay",
		"P1superglow", "P2superglow"}

	gs_main.ui.clickable.P1super:draw(...)
	gs_main.ui.clickable.P2super:draw(...)
	for i = 1, #draws do gs_main.ui.static[ draws[i] ]:draw(...) end
	gs_main.ui.clickable.settings:draw(...)
end

function gs_main:draw()
	local darkened = self.settings_menu_open
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
	self.lastClickedX = x
	self.lastClickedY = y
	local player = self.me_player

	for i = 1, player.hand_size do
		if player.hand[i].piece and pointIsInRect(x, y, player.hand[i].piece:getRect()) then
			if self.phase == "Action" then
				player.hand[i].piece:select()
			else
				self.active_piece = player.hand[i].piece
			end
		end
	end

	if pointIsInRect(x, y, table.unpack(self.stage.super[player.ID].rect)) then
		player.super_clicked = true
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
		if self.phase == "Action" then print("deselect now") self.active_piece:deselect() end
	end

	player.super_clicked = false
	self.active_piece = false

	self:_mousereleased(x, y, gs_main)
end

function gs_main:mousemoved(x, y)
	if self.active_piece and self.phase == "Action" then
		self.active_piece:change{x = x, y = y}
	end

	self:_mousemoved(x, y, gs_main)
end

return gs_main
