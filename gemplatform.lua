local love = _G.love
require 'utilities' -- move
local image = require 'image'
local common = require "class.commons" -- class support
local Pic = require 'pic'

-- gem platforms are generated through the Hand class
local GemPlatform = {}

function GemPlatform:init(game, owner, location)
	self.game = game
	self.hand_idx = location
	self.owner = owner
	self.getx = owner.hand.getx
	self.redness = 0
	self.spin = 0	-- radians per frame

	self.pic = common.instance(Pic, game, {
		x = owner.hand[location].x,
		y = owner.hand[location].y,
		image = owner.ID == "P1" and image.UI.platform_gold or image.UI.platform_silver,
	})
end

function GemPlatform:draw(params) 
	local p = {} -- need to create a copy of params or else it will modify params
	for k, v in pairs(params) do p[k] = v end

	if self.shake then
		local f = self.game.frame
		p.x = self.pic.x + self.shake * (f % 7 * 0.5 + f % 13 * 0.25 + f % 23 / 6 - 5)
		p.y = self.pic.y + self.shake * (f % 5 * 2/3 + f % 11 * 0.25 + f % 17 / 6 - 5)
	end
	self.pic:draw(p)

	if self.redness > 0 then
		p.RGBTable = {255, 255, 255, self.redness}
		p.image = image.UI.platform_red
		self.pic:draw(p)		
	end
end

-- Called when platform takes damage
function GemPlatform:screenshake(frames)
	frames = frames or 6
	self.shake = frames
	if self.owner.hand[self.hand_idx].piece then
		self.owner.hand[self.hand_idx].piece:screenshake(frames)
	end
end

-- Called when platform heals damage
function GemPlatform:healingGlow(frames)
	frames = frames or 6
	print("healing glow function called for platform")
end

function GemPlatform:setSpin(angle)
	local direction = self.owner.ID == "P1" and 1 or -1
	self.spin = angle * direction
end

function GemPlatform:setFastSpin(bool)
	self.fastspin = bool
end

function GemPlatform:update(dt)
	self.pic:update(dt)
	local player = self.owner
	local loc = self.hand_idx

	-- set spin and redness
	local destroyed_particles = self.game.particles:getCount("destroyed", "Damage", player.enemy.player_num)
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
	local make_a_dust = math.floor((self.pic.rotation + current_spin) * 5) - math.floor(self.pic.rotation * 5) ~= 0
	if make_a_dust and loc ~= 1 then
		local x_adj = (math.random() - 0.5) * self.pic.width * 0.2
		local y_adj = (math.random() - 0.5) * self.pic.height * 0.2
		self.game.particles.dust.generatePlatformSpin(self.game, self.pic.x + x_adj, self.pic.y + y_adj, math.abs(current_spin))
	end

	self.pic.rotation = self.pic.rotation + current_spin

	if self.shake then
		self.shake = self.shake - 1
		if self.shake == 0 then self.shake = nil end
	end
end

return common.class("GemPlatform", GemPlatform, Pic)
