local love = _G.love

local common = require "class.commons"
local tween = require 'tween'

local Pic = {}

-- required: x, y, image
function Pic:init(game, tbl)
	self.game = game
	ID.particle = ID.particle + 1
	self.queued_moves = {}
	self.speed_x = 0
	self.speed_y = 0
	self.rotation = 0
	self.speed_rotation = 0
	self.scaling = 1
	self.transparency = 255

	for k, v in pairs(tbl) do
		self[k] = v
	end
	if tbl.x == nil then print("No x-value received!") end
	if tbl.y == nil then print("No y-value received!") end
	if tbl.image == nil then print("No image received!") end
	self.width = self.image:getWidth()
	self.height = self.image:getHeight()
	self.quad = love.graphics.newQuad(0, 0, self.width, self.height, self.width, self.height)
	self.ID = ID.particle
end

function Pic:draw(h_flip, x, y, rotation, scale, RGBTable, img, quad)
	love.graphics.push("all")
		local x_scale = scale or self.scaling
		local y_scale = scale or self.scaling

		local rgbt = {255, 255, 255}
		if self.RGB then
			rgbt = self.RGB
		end
		rgbt[4] = self.transparency or 255

		if RGBTable then
			love.graphics.setColor(RGBTable)
		elseif self.transparency then
			love.graphics.setColor(rgbt)
		end
		if h_flip or self.flip then x_scale = x_scale * -1 end

		love.graphics.draw(
			img or self.image,
			quad or self.quad,
			(x or self.x) + (self.quad_x_offset or 0),
			(y or self.y) + (self.quad_y_offset or 0),
			rotation or self.rotation,
			x_scale or 1,
			y_scale or 1,
			self.width / 2, -- origin x
			self.height / 2, -- origin y
			0,
			0
		)
	love.graphics.pop()
end

function Pic:changeQuad(x, y, w, h)
	--self.new_quad = love.graphics.newQuad(x, y, w, h, self.width, self.height)
	self.quad = love.graphics.newQuad(x, y, w, h, self.width, self.height)
	self.quad_y = self.y + y
	self.quad_x = self.x + x
end

function Pic:isStationary()
	return self.move_func == nil
end

function Pic:remove()
	self.game.particles.allParticles[self.ID] = nil
end

function Pic:getRect()
	return self.x - (self.width / 2), self.y - (self.height / 2), self.width, self.height
end

function Pic:newImage(img)
	self.image = img
	self.width = img:getWidth()
	self.height = img:getHeight()
	self.quad = love.graphics.newQuad(0, 0, self.width, self.height, self.width, self.height)
end

-- clear the junk from all the tweens and stuff
-- runs exit function too. Takes either {func, args} or {{func, args}, {...}}
local function clearMove(self)
	if self.exit then
		if self.exit == true then -- delete
			self:remove()
		elseif type(self.exit[1]) == "table" then -- multiple funcs
			for i = 1, #self.exit do
				self.exit[i][1](table.unpack(self.exit[i], 2))
			end
		else -- single func
			self.exit[1](table.unpack(self.exit, 2))
		end
	end
	self.t, self.tweening, self.curve, self.move_func = nil, nil, nil, nil
	self.during, self.during_frame = nil, nil
	self.exit = nil
end

-- create the move_func that's updated each pic:update()
local function createMoveFunc(self, target)
	-- convert numbers into function equivalents
	local functionize = {"x", "y", "rotation", "transparency", "scaling"}
	for i = 1, #functionize do
		local item = functionize[i]
		if target[item] then
			if type(target[item]) == "number" then
				local original = self[item]
				local diff = target[item] - original
				target[item] = function() return original + diff * self.t end
				if target.debug then print("converting number into function for " .. item) end
			else
				if target.debug then print("using provided function for " .. item) end
			end
		else
			target[item] = function() return self[item] end
		end
	end

	-- create some yummy state
	self.during, self.during_frame = target.during, 0
	self.exit = target.exit
	self.t = 0
	self.tweening = tween.new(target.duration, self, target.tween_target, target.easing)
	if target.debug then
		print("duration:", target.duration)
	end

	-- create the move_func
	local xy_func
	if target.curve then
		if target.debug then print("creating bezier curve") end
		xy_func = function(_self) return _self.curve:evaluate(_self.t) end
		self.curve = target.curve
	else
		if target.debug then print("creating non-bezier move_func") end
		xy_func = function() return target.x(), target.y() end
	end
	
	local move_func = function(_self, dt)
		_self.t = _self.t + dt / target.duration
		local complete = _self.tweening:update(dt)
		_self.x, _self.y = xy_func(_self)
		_self.rotation, _self.transparency = target.rotation(), target.transparency()
		_self.scaling = target.scaling()
		if target.debug then
			target.debugCounter = ((target.debugCounter or 0) + 1) % 10
			if target.debugCounter == 0 then
				print("current x, current y:", _self.x, _self.y)
			end
		end
		if complete then
			if target.debug then print("Tween ended") end
			return true
		end
	end

	return move_func
end

--[[ Tell the pic how to move.
	Takes the following table arguments:
		duration: amount of time for movement, in frames. If not provided, instantly moves there
		x: target x location, or function, e.g. x = function() return self.y^2 end
		y: target y location, or function
		rotation: target rotation, or function
		transparency: target transparency, or function
		easing: easing, default is "linear"
		tween_target: variables to tween, default is {t = 1}
		curve: bezier curve, provided as a love.math.newBezierCurve() object
		queue: if true, will queue this move after the previous one is finished. default is true
		here: if true, will instantly move from current position; false to move from end of previous position. only if queue is false
		during: {frame_step, frame_start, func, args}, if any, to execute every dt_step while tweening.
		exit: {func, args}, if any, to execute when the move finishes. Optional "true" to delete
		quad: {percentage, x (bool), y(bool), x_anchor(0-1), y_anchor(0-1)} to tween a quad
		debug: print some unhelpful debug info
	Junk created: self.t, move_func, tweening, curve, exit, during. during_frame
	Cleans up after itself when movement or tweening finished during Pic:update()
--]]
function Pic:moveTo(target)
	target.easing = target.easing or "linear"
	target.tween_target = target.tween_target or {t = 1}
	if target.queue ~= false then
		target.queue = true
	end
	if target.debug then
		print("New move instruction received")
	end

	if not target.duration then -- apply instantly, interrupting all moves
		clearMove(self)
		self.queued_moves = {}
		self.x = target.x or self.x
		self.y = target.y or self.y
		self.rotation = target.rotation or self.rotation
		if target.debug then print("Instantly moving image") end
	elseif not self.move_func then -- no active tween, apply this immediately
		self.move_func = createMoveFunc(self, target)
		if target.debug then
			print("No active tween, applying immediately")
			print("self.move_func is now ", self.move_func)
		end
	elseif target.queue then -- append to end of self.queued_moves
		self.queued_moves[#self.queued_moves+1] = target
		if target.debug then
			print("Queueing this tween")
		end
	elseif target.here then -- clear queue, tween from current position
		clearMove(self)
		self.queued_moves = {}
		self.move_func = createMoveFunc(self, target)
		if target.debug then
			print("Tweening from current position")
			print("self.move_func is now ", self.move_func)
		end
	else -- clear queue, tween from end position
		self:move_func(math.huge)
		clearMove(self)
		self.queued_moves = {}
		self.move_func = createMoveFunc(self, target)
		if target.debug then
			print("Queueing from end position")
			print("self.move_func is now ", self.move_func)
		end
	end
end

-- queues a wait during the move animation, in frames.
function Pic:wait(frames)
	self:moveTo{duration = frames}
end

function Pic:resolve()
	while self.move_func do
		self:move_func(math.huge)
		clearMove(self)
		if #self.queued_moves > 0 then
			local new_target = table.remove(self.queued_moves, 1)
			self.move_func = createMoveFunc(self, new_target)
		end
	end
end
-- clears all moves
function Pic:clear()
	self.t, self.tweening, self.curve, self.move_func = nil, nil, nil, nil
	self.during, self.during_frame = nil, nil
	self.exit = nil
	self.queued_moves = {}
end

function Pic:update(dt)
	dt = dt / self.game.timeStep  -- convert dt to frames
	if self.move_func then
		if self.during then -- takes {frame_step, frame_start, func, args}
			self.during_frame = self.during_frame + 1
			if type(self.during[1]) == "table" then -- multiple funcs
				for i = 1, #self.during do
					local step, start = self.during[i][1], self.during[i][2]
					if (self.during_frame + start) % step == 0 then
						self.during[i][3](table.unpack(self.during, 4))
					end
				end
			else -- single func
				local step, start = self.during[1], self.during[2]
				if (self.during_frame + start) % step == 0 then
					self.during[3](table.unpack(self.during, 4))
				end
			end
		end

		local finished = self:move_func(dt)
		if finished then
			clearMove(self)
			if #self.queued_moves > 0 then
				local new_target = table.remove(self.queued_moves, 1)
				self.move_func = createMoveFunc(self, new_target)
			end
		end
	end
end

return common.class("Pic", Pic)
