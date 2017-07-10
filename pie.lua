local image = require 'image'
local class = require 'middleclass' -- class support
local pic = require 'pic'
local particles

local Segment = class('Segment', pic)
function Segment:initialize(pie, segment_number)
	local todraw = image.lookup.pie(pie.owner, 1)
	local h_adjust = todraw:getWidth() * 0.5
	local v_adjust = todraw:getHeight() * 0.5
	if segment_number == 1 or segment_number == 4 then v_adjust = -v_adjust end

	if pie.owner.ID == "P1" and (segment_number == 3 or segment_number == 4) then
		h_adjust = -h_adjust
	elseif pie.owner.ID == "P2" and (segment_number == 1 or segment_number == 2) then
		h_adjust = -h_adjust
	end

	self.x = pie.x + h_adjust
	self.y = pie.y + v_adjust
	self.transparency = 255
	self.should_draw = true
	self.pie = pie
	self.owner = pie.owner
	self.segment_number = segment_number
	self.rotation = math.pi * segment_number * 0.5
	if pie.owner.ID == "P2" then	self.rotation = math.pi * (5 - segment_number) * 0.5 end
	self.t = 0
	pic.initialize(self, {x = self.x, y = self.y, rotation = self.rotation, image = todraw})
end

function Segment:update(dt, need_new_image)
	if need_new_image then
		self.image = image.lookup.pie(self.pie.owner, self.pie.damage)
	end
	-- don't show image if it is damaged
	self.should_draw = self.pie.damage < self.segment_number
end

function Segment:draw(h_flip, x, y, rotation, scale, RGBTable, img, quad)
	pic.draw(self, h_flip, x, y, rotation, scale, RGBTable, img, quad)
end

local Pie = class('Pie', pic)
function Pie:initialize(player, loc)
	particles = game.particles

	local todraw = player.ID == "P1" and image.pie.p1 or image.pie.p2
	local x_shift = player.ID == "P1" and -image.UI.platform_gold:getWidth() * 0.5 or image.UI.platform_gold:getWidth() * 0.5
	local y_shift = image.UI.platform_gold:getHeight() * 0.15

	self.x = player.hand[loc].x + x_shift
	self.y = player.hand[loc].y + y_shift
	self.damage = 0
	self.damage_changed = false -- whether to update images
	self.loc = loc
	self.owner = player
	self.transparency = 255
	self.should_draw = false
	self.t = 0
	pic.initialize(self, {x = self.x, y = self.y, image = todraw})
	self.segment = {}
	for i = 1, 4 do
		self.segment[i] = Segment:new(self, i)
	end
end

function Pie:update(dt)
	self.should_draw = self.damage > 0 and (self.loc >= 2 and self.loc <= 5)

	-- update pie segments
	if self.damage_changed then
		for i = 1, 4 do	self.segment[i]:update(dt, true) end
		self.damage_changed = false
	else
		for i = 1, 4 do	self.segment[i]:update(dt) end
	end

end

function Pie:addDamage(add_dmg)
	for i = self.damage + 1, (self.damage + add_dmg) do
		queue.add(5*i, particles.pieEffects.generateSegment, particles.pieEffects,
			self.segment[i], self.segment[i].image)
	end
	self.damage = self.damage + add_dmg
end

function Pie:reset()
	self.damage = 0
	self.should_draw = false
	self.t = 0
end

function Pie:draw(h_flip, x, y, rotation, scale, RGBTable, img, quad)
	if self.should_draw then
		-- draw pie
		pic.draw(self, h_flip, x, y, rotation, scale, RGBTable, img, quad)

		-- draw segments
		for i = 1, 4 do
			if self.segment[i].should_draw then
				pic.draw(self.segment[i], h_flip, x, y, rotation, scale, RGBTable, img, quad)
			end
		end
	end
end

return Pie
