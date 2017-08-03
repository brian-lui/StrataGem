local love = _G.love

local pointIsInRect = require("utilities").pointIsInRect

local gs_main = {}

function gs_main:init()
	self.timeStep, self.timeBucket = 1/60, 0
end

function gs_main:enter()
	local canvas = {}
	for i = 1, 5 do
		canvas[i] = love.graphics.newCanvas()
	end
	self.canvas = canvas
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
	self.background.update() -- variable fps
	self.ui.timer:update()
	self.animations:updateAll(dt)
	self.screenshake_frames = math.max(0, self.screenshake_frames - 1)
	self.timeBucket = self.timeBucket + dt

	-- Testing trail stars
	-- TODO: put this in the right place
	if self.frame % 10 == 0 then
		self.particles.platformStar:generate(self.p1, "TinyStar", 0.05, 0.2, 0.29)
		self.particles.platformStar:generate(self.p2, "TinyStar", 0.95, 0.8, 0.71)
	end
	if self.frame % 42 == 0 then
		self.particles.platformStar:generate(self.p1, "Star", 0.05, 0.21, 0.28)
		self.particles.platformStar:generate(self.p2, "Star", 0.95, 0.79, 0.72)
	end
end

local draw = require "draw"

-- background and background effects
function gs_main:drawBackground()
	love.graphics.clear()
	self.background.current.drawImages()
end

-- draw all the non-gem screen elements: super bar, sprite
function gs_main:drawScreenElements()
	love.graphics.clear()

	-- under-platform trails
	for _, v in pairs(self.particles.allParticles.PlatformTinyStar) do v:draw() end
	for _, v in pairs(self.particles.allParticles.PlatformStar) do v:draw() end

	self.ui.tub_img:draw() -- tub
	self.ui.timer:draw()	-- timer bar

	for player in self:players() do
		self.ui:drawSuper(player) -- super meter
		player.animation:draw(player.ID == "P2") -- sprite
	end
end

function gs_main:draw()
	self:drawGems()

	draw.camera:set(1, 1)
		if self.screenshake_frames > 0 then
			draw.screenshake(self.screenshake_vel)
		else
			draw.camera:setPosition(0, 0)
		end

		self:drawScreenElements()
		self:drawGems()
		--self:drawAnimations()
	draw.camera:unset()

	self:drawText()
end

-- draw gems and related objects (platforms, particles)
function gs_main:drawGems()
	local allParticles = self.particles.allParticles
	-- gem platforms
	for player in self:players() do
		for i = 0, #player.hand do
			if player.hand[i].platform then
				player.hand[i].platform:draw()
			end
		end
	end

	-- under-gem particles
	for _, instance in pairs(allParticles.WordEffects) do instance:draw() end
	for _, instance in pairs(allParticles.Dust) do instance:draw() end
	for _, instance in pairs(allParticles.Pop) do instance:draw() end


	-- hand gems and pending-garbage gems
	for player in self:players() do
		for i = 1, player.hand_size do
			if player.hand[i].piece and player.hand[i].piece ~= self.active_piece then
				for _ = 1, player.hand[i].piece.size do
						player.hand[i].piece:draw()
				end
			end
		end
		for i = 1, #player.hand.garbage do player.hand.garbage[i]:draw() end
	end

	local function blockBottomGemRow()
	-- stencil function to hide gems in bottom row
	-- makes it look nicer when gems are generated and push up from the bottom
		local x = (self.stage.grid.x[0] + self.stage.grid.x[1]) / 2
		local y = (self.stage.grid.y[self.stage.grid.rows] + self.stage.grid.y[self.stage.grid.rows + 1]) / 2
		local width = self.stage.grid.x[self.stage.grid.columns] - self.stage.grid.x[0]
		local height = self.stage.gem_width
		love.graphics.rectangle("fill", x, y, width, height)
	end

	-- grid gems
	love.graphics.push("all")
		love.graphics.stencil(blockBottomGemRow, "replace", 1)
		love.graphics.setStencilTest("equal", 0)
		for gem, r in self.stage.grid:gems() do
			if self.phase == "Action" and r <= 6 then
				gem:draw(nil, nil, {255, 255, 255, 192})
			else
				gem:draw()
			end
		end
		love.graphics.setStencilTest()
	love.graphics.pop()

	-- damage bar
	for player in self:players() do
		player.hand.damage_bar:draw()
	end
	-- over-gem particles
	for _, v in pairs(allParticles.Super) do v:draw() end
	for _, v in pairs(allParticles.DamageTrail) do v:draw() end
	for _, v in pairs(allParticles.Damage) do v:draw() end
	for _, v in pairs(allParticles.ExplodingGem) do v:draw() end
	for _, v in pairs(allParticles.PieEffects) do v:draw() end
	for _, v in pairs(allParticles.CharEffects) do v:draw() end
	for _, v in pairs(allParticles.SuperEffects1) do v:draw() end
	for _, v in pairs(allParticles.SuperEffects2) do v:draw() end
	for _, v in pairs(allParticles.SuperEffects3) do v:draw() end

	-- draw the gem when it's been grabbed by the player
	if self.active_piece then
		self.ui:showShadows(self.active_piece)
		self.active_piece:draw()
		self.ui:showX(self.active_piece)
	end

	-- over-dust
	for _, v in pairs(allParticles.OverDust) do v:draw() end

	-- uptween gems
	for _, v in pairs(allParticles.UpGem) do v:draw() end

end

-- draw text items
function gs_main:drawText()
	love.graphics.clear()

	-- words
	for _, v in pairs(self.particles.allParticles.Words) do v:draw() end

	-- debug row/column display
	love.graphics.push("all")
		love.graphics.setColor(0, 255, 0)
		for r = 0, self.stage.grid.rows + 1 do
			love.graphics.print(r, 200, self.stage.grid.y[r])
		end
		for c = 0, self.stage.grid.columns + 1 do
			love.graphics.print(c, self.stage.grid.x[c], 200)
		end
	love.graphics.pop()
end

function gs_main:mousepressed(x, y)
	if self.phase == "Action" then
		self.lastClickedFrame = self.frame
		self.lastClickedX = x
		self.lastClickedY = y

		local player = self.me_player

		for i = 1, player.hand_size do
			if player.hand[i].piece and pointIsInRect(x, y, player.hand[i].piece:getRect()) then
				player.hand[i].piece:select()
			end
		end

		if pointIsInRect(x, y, table.unpack(self.stage.super_click[player.ID])) then
			player.super_clicked = true
		end
	end
end

local QUICKCLICK_FRAMES = 15
local QUICKCLICK_MAX_MOVE = 0.05

function gs_main:mousereleased(x, y)
	local player = self.me_player

	if self.active_piece then
		local quickclick = self.frame - self.lastClickedFrame < QUICKCLICK_FRAMES
		local nomove = math.abs(x - self.lastClickedX) < self.stage.width * QUICKCLICK_MAX_MOVE and
			math.abs(y - self.lastClickedY) < self.stage.height * QUICKCLICK_MAX_MOVE
		self.active_piece:deselect()
		if quickclick and nomove then
			self.active_piece:rotate()
		end

	elseif player.super_clicked and pointIsInRect(x, y, table.unpack(self.stage.super_click[player.ID])) then
		player:super()
	end

	player.super_clicked = false
	self.active_piece = false
end

function gs_main:mousemoved(x, y)
	if self.active_piece and self.phase == "Action" then
		self.active_piece:moveTo{x = x, y = y}
	end
end

return gs_main
