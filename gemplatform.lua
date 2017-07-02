require 'inits' -- for AllGemPlatforms. SPEED
require 'utilities' -- move
local image = require 'image'
local class = require 'middleclass' -- class support
local pic = require 'pic'

-- gem platforms are generated through the Hand class
local GemPlatform = class('GemPlatform', pic)
function GemPlatform:initialize(owner, location)
	local img = owner == p1 and image.UI.platform_gold or image.UI.platform_silver
	pic.initialize(self, {x = owner.hand[location].x, y = owner.hand[location].y, image = img})
	self.hand_idx = location
	self.x, self.y = owner.hand[location].x, owner.hand[location].y
	self.owner = owner
	self.getx = owner.hand.getx
	self.transparency, self.redness, self.rotation = 255, 0, 0
	self.rotation_speed = SPEED.PLATFORM_ROTATION
	if player == p2 then self.rotation_speed = -self.rotation_speed end
	AllGemPlatforms[ID.particle] = self
end

function GemPlatform:draw()
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
end

function GemPlatform:removeAnim()
	print("(Placeholder) remove Gem platform animation plays")
	--self.transparency = math.max(self.transparency - SPEED.PLATFORM_FADE, 0)
	--if self.transparency == 0 then remove_particle end
end

function GemPlatform:update(dt)
	pic.update(self, dt)
	local player = self.owner
	local loc = self.hand_idx
	--[[
	if loc == 0 and self.y == player.hand[0].y then
	-- fade out top gem platform
		self:remove()
		--instance.transparency = math.max(instance.transparency - SPEED.PLATFORM_FADE, 0)
		--if instance.transparency == 0 then instance:remove() end
	elseif loc <= 5 and (loc == 1 or player.pie[loc].damage == 4) and game.phase == "Action" then
		self.redness = math.min(self.redness + SPEED.GEM_PLATFORM_TURN_RED, 255)
		if self.redness == 255 and not self.glow_startframe then
			self.glow_startframe = frame
		end
	end
	--]]
	if loc <= 5 and (loc == 1 or player.pie[loc].damage == 4) and game.phase == "Action" then
		self.redness = math.min(self.redness + SPEED.GEM_PLATFORM_TURN_RED, 255)
		if self.redness == 255 and not self.glow_startframe then
			self.glow_startframe = frame
		end
	end
end

return GemPlatform