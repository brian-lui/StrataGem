local love = _G.love
require 'utilities' -- move
local image = require 'image'
local common = require "class.commons" -- class support
local Pic = require 'pic'

-- gem platforms are generated through the Hand class
local GemPlatform = {}

function GemPlatform:init(game, owner, location)
	self.game = game
	local img = owner.ID == "P1" and image.UI.platform_gold or image.UI.platform_silver
	Pic.init(self, game, {x = owner.hand[location].x, y = owner.hand[location].y, image = img})
	self.hand_idx = location
	self.x, self.y = owner.hand[location].x, owner.hand[location].y
	self.owner = owner
	self.getx = owner.hand.getx
	self.transparency, self.redness, self.rotation = 255, 0, 0
	self.spin = 0	-- radians per frame
	self.h_shake, self.v_shake = 0, 0 -- screenshake from particles hitting platform
end

function GemPlatform:draw()
	local frame = self.game.frame
	--screen shake translation
	local h_shake, v_shake = 0, 0
	if self.shake then
		h_shake = math.floor(self.shake * (frame % 7 * 0.5 + frame % 13 * 0.25 + frame % 23 / 6 - 5))
		v_shake = math.floor(self.shake * (frame % 5 * 2/3 + frame % 11 * 0.25 + frame % 17 / 6 - 5))
	end

	love.graphics.push("all")
		love.graphics.translate(h_shake, v_shake)
		Pic.draw(self)
		if self.redness > 0 then
			local redRGB = {255, 255, 255, math.min(self.redness, self.transparency)}
			Pic.draw(self, {RGBTable = redRGB, img = image.UI.platform_red})
		end
	love.graphics.pop()
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
	Pic.update(self, dt)
	local player = self.owner
	local loc = self.hand_idx

	-- set spin and redness
	local destroyed_particles = self.game.particles:getCount("destroyed", "Damage", player.enemy.playerNum)
	local displayed_damage = (player.hand.turn_start_damage + destroyed_particles/3) * 0.25

	if displayed_damage >= loc then	-- fully red, full spin
		self.redness = math.min(self.redness + 16, 255)
		if self.redness == 255 and not self.glow_startframe then
			self.glow_startframe = self.game.frame
		end
		self:setSpin(0.02)
	elseif displayed_damage > (loc - 1) and displayed_damage < loc then
		self.redness = math.min(self.redness + 16, 200 * (displayed_damage % 1))
		self:setSpin((displayed_damage % 1) * 0.02)	-- partial spin
	else
		self.redness = 0
		self:setSpin(0)
	end

	-- generate particles regularly during spin, except for top platform
	local current_spin = self.spin
	if self.fastspin and displayed_damage >= loc then
		current_spin = self.spin * 5
	end
	local make_a_dust = math.floor((self.rotation + current_spin) * 5) - math.floor(self.rotation * 5) ~= 0
	if make_a_dust and loc ~= 1 then
		local x_adj = (math.random() - 0.5) * self.width * 0.2
		local y_adj = (math.random() - 0.5) * self.height * 0.2
		self.game.particles.dust.generatePlatformSpin(self.game, self.x + x_adj, self.y + y_adj, math.abs(current_spin))
	end
	self.rotation = self.rotation + current_spin

	if self.shake then
		self.shake = self.shake - 1
		if self.shake == 0 then self.shake = nil end
	end
end

return common.class("GemPlatform", GemPlatform, Pic)
