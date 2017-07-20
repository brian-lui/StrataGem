require 'utilities' -- move
local image = require 'image'
local class = require 'middleclass' -- class support
local particles = game.particles
local pic = require 'pic'

-- gem platforms are generated through the Hand class
local GemPlatform = class('GemPlatform', pic)
GemPlatform.PLATFORM_ROTATION_SPEED = 0.02
GemPlatform.GEM_PLATFORM_TURN_RED_SPEED = 8
--GemPlatform.PLATFORM_FADE = 8

function GemPlatform:initialize(owner, location)
	local img = owner.ID == "P1" and image.UI.platform_gold or image.UI.platform_silver
	pic.initialize(self, {x = owner.hand[location].x, y = owner.hand[location].y, image = img})
	self.hand_idx = location
	self.x, self.y = owner.hand[location].x, owner.hand[location].y
	self.owner = owner
	self.getx = owner.hand.getx
	self.transparency, self.redness, self.rotation = 255, 0, 0
	self.spin = 0 -- radians per frame
	self.rotation_speed = owner.ID == "P1" and self.PLATFORM_ROTATION_SPEED or -self.PLATFORM_ROTATION_SPEED
end

function GemPlatform:draw()
	--screen shake translation
	local h_shake, v_shake = 0, 0
	if self.shake then
		h_shake = math.floor(self.shake * (frame % 7 / 2 + frame % 13 / 4 + frame % 23 / 6 - 5))
		v_shake = math.floor(self.shake * (frame % 5 * 2/3 + frame % 11 / 4 + frame % 17 / 6 - 5))
	end

	love.graphics.push("all")
		love.graphics.translate(h_shake, v_shake)
		pic.draw(self)
		if self.redness > 0 then
			local redRGB = {255, 255, 255, math.min(self.redness, self.transparency)}
			pic.draw(self, nil, nil, nil, nil, nil, redRGB, image.UI.platform_red)
		end
		if self.redness == 255 and self.owner.hand[self.hand_idx].piece then
			local fr = frame - self.glow_startframe
			local glowRGB = {255, 255, 255, math.sin(fr/20) * 255}
			pic.draw(self, nil, nil, nil, nil, nil, glowRGB, image.UI.platform_red_glow)
		end
	love.graphics.pop()
end

function GemPlatform:removeAnim()
	print("(Placeholder) remove Gem platform animation plays")
	--self.transparency = math.max(self.transparency - self.PLATFORM_FADE, 0)
	--if self.transparency == 0 then remove_particle end
end

function GemPlatform:screenshake(frames)
	frames = frames or 6
	self.shake = frames
	if self.owner.hand[self.hand_idx].piece then
		self.owner.hand[self.hand_idx].piece:screenshake(frames)
	end
end

function GemPlatform:setSpin(angle)
	local direction = self.owner.ID == "P1" and 1 or -1
	self.spin = angle * direction
end

function GemPlatform:setFastSpin(bool)
	self.fastspin = bool
end

function GemPlatform:update(dt)
	pic.update(self, dt)
	local player = self.owner
	local loc = self.hand_idx

	-- set spin and redness
	local particle_delayed_damage = particles.getNumber("Damage", player) / 3
	local displayed_damage = (player.hand.damage - particle_delayed_damage) / 4

	if displayed_damage >= loc then -- fully red, full spin
		self.redness = math.min(self.redness + self.GEM_PLATFORM_TURN_RED_SPEED, 255)
		if self.redness == 255 and not self.glow_startframe then
			self.glow_startframe = frame
		end
		self:setSpin(0.02)
	elseif displayed_damage > (loc - 1) and displayed_damage < loc then
		self.redness = math.min(self.redness + self.GEM_PLATFORM_TURN_RED_SPEED, 200 * (displayed_damage % 1))
		self:setSpin((displayed_damage % 1) * 0.02) -- partial spin
	end

	-- generate particles regularly during spin
	local current_spin = self.fastspin and self.spin * 10 or self.spin
	if math.floor((self.rotation + current_spin) * 5) - math.floor(self.rotation * 5) ~= 0 then
		local x_adj = (math.random() - 0.5) * self.width * 0.2
		local y_adj = (math.random() - 0.5) * self.height * 0.2
		particles.dust:generatePlatformSpin(self.x + x_adj, self.y + y_adj, math.abs(current_spin))
	end
	self.rotation = self.rotation + current_spin

	--[[
	if loc == 0 and self.y == player.hand[0].y then
	-- fade out top gem platform
		self:remove()
		--instance.transparency = math.max(instance.transparency - self.PLATFORM_FADE, 0)
		--if instance.transparency == 0 then instance:remove() end
	elseif loc <= 5 and (loc <= player.hand.damage / 4) and game.phase == "Action" then
		self.redness = math.min(self.redness + self.GEM_PLATFORM_TURN_RED_SPEED, 255)
		if self.redness == 255 and not self.glow_startframe then
			self.glow_startframe = frame
		end
	end
	--]]

	if self.shake then
		self.shake = self.shake - 1
		if self.shake == 0 then self.shake = nil end
	end
end

return GemPlatform
