--[[
This is the gamestate module for the main gameplay screen.
--]]

local common = require "class.commons"
local images = require "images"
local pointIsInRect = require "/helpers/utilities".pointIsInRect
local spairs = require "/helpers/utilities".spairs

local gs_main = {name = "gs_main"}

function gs_main:init()
	gs_main.ui = {
		clickable = {},
		static = {},
		popup_clickable = {},
		popup_static = {},
	}
	gs_main.ui.static.burst = {update = function() end}
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
	if self.type == "Singleplayer" or self.type == "Replay" then
		settings_image = images.buttons_pause
	elseif self.type == "Netplay" then
		settings_image = images.buttons_stop
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
	gs_main.pressedDown = 0

	gs_main.current_background = common.instance(self.background[self.current_background_name], self)
	self.settings_menu_open = false

	gs_main.createImage(self, {
		name = "basin",
		image = images.ui_basin,
		end_x = stage.basin.x,
		end_y = stage.basin.y,
	})

	for player in self:players() do
		gs_main.ui.static.burst[player.player_num] = self.uielements.burstMeter.create(self, player)
	end

	gs_main.createImage(self, {
		name = "fadein",
		container = self.global_ui.fades,
		image = images.unclickables_fadein,
		duration = 30,
		end_x = self.stage.width * 0.5,
		end_y = self.stage.height * 0.5,
		end_transparency = 0,
		easing = "linear",
		remove = true,
	})
end

function gs_main:openSettingsMenu()
	if self.type == "Singleplayer" or self.type == "Replay" then
		self.paused = true
	end
	self:_openSettingsMenu(gs_main)
end

function gs_main:closeSettingsMenu()
	if self.type == "Singleplayer" or self.type == "Replay" then
		self.paused = false
	end
	self:_closeSettingsMenu(gs_main)
end

function gs_main:update(dt)
	if not self.paused then
		self:timeDip(function()
			self.phase:run(self.time_step)

			for player in self:players() do
				gs_main.ui.static.burst[player.player_num]:update(dt)
				player.super_button:update(dt)
			end
			self.animations:updateAll(dt)
		end)

		self.particles:update(dt)
		gs_main.current_background:update(dt)
		self.timeBucket = self.timeBucket + dt
	end

	for _, tbl in pairs(gs_main.ui) do
		for _, v in pairs(tbl) do v:update(dt) end
	end
end

-- draw all the non-gem screen elements: super bar, sprite
function gs_main:drawScreenElements(params)
	local particles = self.particles
	-- under-platform trails
	for _, v in pairs(particles.allParticles.PlatformTinyStar) do
		v:draw(params)
	end

	for _, v in pairs(particles.allParticles.PlatformStar) do
		v:draw(params)
	end

	-- ui elements
	gs_main.ui.static.basin:draw(params)
	self.uielements.timer:draw(params)

	-- player sprite
	for player in self:players() do
		player.animation:draw{h_flip = player.player_num == 2} -- sprite
	end
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
	for _, v in pairs(allParticles.WordEffects) do v:draw(params) end
	for _, v in pairs(allParticles.Dust) do v:draw(params) end
	for _, v in pairs(allParticles.PopParticles) do v:draw(params) end
	for i = -4, 0 do
		local char_effects = char_effect_draws[i]
		for j = 1, char_effects.n do char_effects[j]:draw() end
	end

	-- hand gems and pending-garbage gems
	for player in self:players() do
		for i = 1, player.hand_size do
			local pc = player.hand[i].piece
			if pc and pc ~= self.active_piece then
				for _ = 1, pc.size do pc:draw(params) end
			end
		end
		for i = 1, #player.hand.garbage do
			player.hand.garbage[i]:draw(params)
		end
	end

	for gem, r in self.grid:gems() do
		if self.current_phase == "Action" and r <= 6 then
			gem:draw{RGBTable = {1, 1, 1, 0.75}}
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
		self.uielements:showShadows(self.active_piece)
		self.active_piece:draw(params)
		self.uielements:showX(self.active_piece)
	end

	-- more over-gem particles
	for _, v in pairs(allParticles.OverDust) do v:draw(params) end
	for _, v in pairs(allParticles.ExplodingPlatform) do v:draw(params) end
	for _, v in pairs(allParticles.UpGem) do v:draw(params) end
	for _, v in pairs(allParticles.PlacedGem) do v:draw(params) end
end

-- draw word particles and debug items
function gs_main:drawText(params)
	for _, v in pairs(self.particles.allParticles.Words) do
		v:draw(params)
	end
	self.uielements.helptext:draw(params)
	self.uielements.warningSign:draw(params)
	self.debugconsole:draw()
end

function gs_main:drawButtons()
	gs_main.ui.clickable.settings:draw()
	self:_drawSettingsMenu(gs_main)
end

function gs_main:drawUI(params)
	gs_main.ui.static.basin:draw(params)
	for player in self:players() do
		player.super_button:draw(params)
		gs_main.ui.static.burst[player.player_num]:draw(params)
	end
	gs_main.ui.clickable.settings:draw(params)
end

function gs_main:draw()
	local darkened = self:isScreenDark()
	gs_main.current_background:draw{darkened = darkened}
	self.camera:set(1, 1)
		self.uielements:setCameraScreenshake()

		gs_main.drawUI(self, {darkened = darkened})
		gs_main.drawScreenElements(self, {darkened = darkened})
		gs_main.drawGems(self, {darkened = darkened})
		--gs_main.drawAnimations(self, {darkened = darkened})
	self.camera:unset()
	gs_main.drawText(self, {darkened = darkened})
	gs_main.drawButtons(self)
	self:_drawGlobals()
end


function gs_main:_pressed(x, y)
	self.lastClickedFrame = self.frame
	self.lastClickedX, self.lastClickedY = x, y

	if self.type ~= "Replay" then
		local player = self.me_player
		if not self.paused then
			for i = 1, player.hand_size do
				if player.hand[i].piece
				and pointIsInRect(x, y, player.hand[i].piece:getRect()) then
					if self.current_phase == "Action"
					and player:canPlacePiece() then
						player.hand[i].piece:select()
					else
						self.active_piece = player.hand[i].piece
					end
				end
			end
		end

		if self.debugconsole.is_pause_mode_on then
			self.debugconsole:swapGridGem(x, y)
		end
	end
	self:_controllerPressed(x, y, gs_main)

	if self.type ~= "Replay" then
		local my_super = self.me_player.super_button
		if pointIsInRect(x, y, my_super:getRect()) then
			gs_main.clicked = my_super
		end
	end
end

local QUICKCLICK_FRAMES = 15
local QUICKCLICK_MAX_MOVE = 0.05

function gs_main:_released(x, y)
	if self.type ~= "Replay" then
		local player = self.me_player
		if self.active_piece then
			local quickclick = self.frame - self.lastClickedFrame < QUICKCLICK_FRAMES
			local nomove = math.abs(x - self.lastClickedX) < self.stage.width * QUICKCLICK_MAX_MOVE and
				math.abs(y - self.lastClickedY) < self.stage.height * QUICKCLICK_MAX_MOVE

			if quickclick and nomove then self.active_piece:rotate() end
			if self.current_phase == "Action" and player:canPlacePiece() then
				self.active_piece:deselect()
			end

			self.active_piece = false
		end

		local my_super = self.me_player.super_button
		if pointIsInRect(x, y, my_super:getRect())
		and gs_main.clicked == my_super then
			my_super:action()
		end
	end
	self:_controllerReleased(x, y, gs_main)
end

function gs_main:_moved(x, y)
	if self.type ~= "Replay" then
		local player = self.me_player
		if self.active_piece
		and self.current_phase == "Action"
		and player:canPlacePiece() then
			self.active_piece:change{x = x, y = y}
		end
	end

	self:_controllerMoved(x, y, gs_main)
end

function gs_main:mousepressed(x, y) gs_main._pressed(self, x, y) end
function gs_main:touchpressed(_, x, y) gs_main._pressed(self, x, y) end

function gs_main:mousereleased(x, y) gs_main._released(self, x, y) end
function gs_main:touchreleased(_, x, y) gs_main._released(self, x, y) end

function gs_main:mousemoved(x, y) gs_main._moved(self, x, y) end
function gs_main:touchmoved(_, x, y) gs_main._moved(self, x, y) end


return gs_main
