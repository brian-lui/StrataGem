--[[
A small module to handle the platforms underneath the gems in the player's hand.
It's separated into its own class because the platforms have to move and spin
and turn red and break up and all that.
--]]

local images = require "images"
local common = require "class.commons" -- class support
local Pic = require "pic"

-- gem platforms are generated through the Hand class
local GemPlatform = {}

function GemPlatform:init(params)
	self.game = params.game
	self.hand_idx = params.hand_idx
	self.owner = params.owner
	self.getx = self.owner.hand.getx
	self.redness = 0
	self.spin = 0	-- radians per frame
	self.pic = Pic:create{
		game = self.game,
		x = self.owner.hand[self.hand_idx].x,
		y = self.owner.hand[self.hand_idx].y,
		image = self.owner.ID == "P1" and images.ui_platform_gold or images.ui_platform_silver,
	}
	self.width = self.pic.width
	self.height = self.pic.height
	self.REDNESS_PER_FRAME = 0.0625
end

function GemPlatform:create(params)
	assert(params.game, "Game object not received!")
	assert(params.owner, "Owner object not received!")
	assert(params.hand_idx, "Hand index not received!")

	return common.instance(self, params)
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
		p.RGBTable = {1, 1, 1, self.redness}
		p.image = images.ui_platform_red
		self.pic:draw(p)
	end
end

-- Called when platform takes damage, shakes the platform
function GemPlatform:screenshake(frames)
	frames = frames or 6
	self.shake = frames
	if self.owner.hand[self.hand_idx].piece then
		self.owner.hand[self.hand_idx].piece:screenshake(frames)
	end
end

-- Called when platform heals damage, makes twinkling stars
function GemPlatform:healingGlow()
	self.game.particles.healing.generateTwinkle(self.game, self)
	self.game.sound:newSFX("healing", true)
end

function GemPlatform:setSpin(angle)
	local direction = self.owner.ID == "P1" and 1 or -1
	self.spin = angle * direction
end

function GemPlatform:setFastSpin(bool)
	self.fastspin = bool
end

function GemPlatform:destroy(delay)
	self.frames_until_destruction = delay or 0
end

function GemPlatform:update(dt)
	local game = self.game
	self.pic:update(dt)
	local player = self.owner
	local loc = self.hand_idx

	-- set spin and redness
	local destroyed_damage_particles = game.particles:getCount("destroyed", "Damage", player.enemy.player_num)
	local destroyed_healing_particles = game.particles:getCount("destroyed", "Healing", player.player_num)
	local displayed_damage = (player.hand.turn_start_damage +
		destroyed_damage_particles / 3 - destroyed_healing_particles / 5) * 0.25

	if displayed_damage >= loc then	-- fully red, full spin
		self.redness = math.min(self.redness + self.REDNESS_PER_FRAME, 1)
		if self.redness == 1 and not self.glow_startframe then
			self.glow_startframe = game.frame
		end
		self:setSpin(0.02)
	elseif displayed_damage > (loc - 1) and displayed_damage < loc then
		self.redness = math.min(self.redness + self.REDNESS_PER_FRAME, 0.8 * (displayed_damage % 1))
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
		game.particles.dust.generatePlatformSpin(
			game,
			self.pic.x + x_adj,
			self.pic.y + y_adj,
			math.abs(current_spin)
		)
	end

	self.pic.rotation = self.pic.rotation + current_spin

	if self.shake then
		self.shake = self.shake - 1
		if self.shake == 0 then self.shake = nil end
	end

	-- queue for self destruction
	if self.frames_until_destruction then
		if self.frames_until_destruction <= 0 then
			self.owner.hand[self.hand_idx].platform = nil
		else
			self.frames_until_destruction = self.frames_until_destruction - 1
		end
	end
end

return common.class("GemPlatform", GemPlatform, Pic)
