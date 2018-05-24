local love = _G.love

local common = require "class.commons"
local tween = require 'tween'

local Pic = {}

-- required: x, y, image
-- container/counter to specify different container and ID counter
-- doesn't assign the created instance to any container by default
-- TODO: If needed, initialize self.RGB and make it changeable with the change() method
function Pic:init(game, tbl)
	self.game = game
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
	if tbl.container then
		if not tbl.name and not tbl.counter then
			print ("Container specified without either name or counter!")
		end
		if not tbl.counter then
			self.ID = tbl.name
			self.container[tbl.name] = self
		else
			ID[tbl.counter] = ID[tbl.counter] + 1
			self.ID = ID[tbl.counter]
			self.container[self.ID] = self
		end
	else
		ID.particle = ID.particle + 1
		self.ID = ID.particle
	end

	self.width = self.image:getWidth()
	self.height = self.image:getHeight()
	self.quad = love.graphics.newQuad(0, 0, self.width, self.height, self.width, self.height)
	self.quad_data = {}
end

function Pic:create(params)
	assert(params.game, "Game object not received!")
	assert(params.x, "x-value not received!")
	assert(params.y, "y-value not received!")
	assert(params.image, "Image not received!")
	if params.container then
		assert(params.name or params.counter, "Container specified without name or counter!")
	end
	
	return common.instance(self, params.game, params)
end

--[[ Takes the following optional table arguments:
		h_flip: whether to draw the image flipped around the horizontal axis
		x, y: x or y position to draw the image at
		rotation: rotation number to draw
		scale: scaling to draw
		RGBTable: colors to draw, given as {red, green, blue, alpha}
		image: image to draw
		darkened: draw darker (when a pop-up menu is onscreen). Overridden by force_max_alpha boolean
--]]
function Pic:draw(params)
	if self.transparency == 0 then return end

	params = params or {}
	love.graphics.push("all")
		local x_scale = params.scale or self.x_scaling or self.scaling
		local y_scale = params.scale or self.y_scaling or self.scaling
		local rgbt = self.RGB or {255, 255, 255}
		rgbt[4] = self.transparency or 255

		if params.darkened and not self.force_max_alpha then
			love.graphics.setColor(params.darkened * 255, params.darkened * 255, params.darkened * 255)
		elseif params.RGBTable then
			love.graphics.setColor(params.RGBTable)
		elseif self.transparency then
			love.graphics.setColor(rgbt)
		end
		if (self.h_flip or params.h_flip) then x_scale = x_scale * -1 end

		love.graphics.draw(
			params.image or self.image,
			self.quad,
			(params.x or self.x) + (self.quad_data.x_offset or 0),
			(params.y or self.y) + (self.quad_data.y_offset or 0),
			params.rotation or self.rotation,
			x_scale or 1,
			y_scale or 1,
			self.width / 2, -- origin x
			self.height / 2 -- origin y
		)

		if self.new_image then
			local r, g, b
			if params.RGBTable then
				r, g, b = params.RGBTable[1], params.RGBTable[2], params.RGBTable[3]
			else
				r, g, b = rgbt[1], rgbt[2], rgbt[3]
			end
			love.graphics.setColor(r, g, b, self.new_image.transparency)
			love.graphics.draw(
			self.new_image.image,
			self.quad,
			(params.x or self.x) + (self.quad_data.x_offset or 0),
			(params.y or self.y) + (self.quad_data.y_offset or 0),
			params.rotation or self.rotation,
			x_scale or 1,
			y_scale or 1,
			self.width / 2, -- origin x
			self.height / 2 -- origin y
		)
		end
	love.graphics.pop()
end

function Pic:isStationary()
	return self.move_func == nil
end

function Pic:remove()
	if self.container then
		self.container[self.ID] = nil
	else
		self.game.particles.allParticles[self.ID] = nil
	end
end

function Pic:getRect()
	return self.x - (self.width / 2), self.y - (self.height / 2), self.width, self.height
end

-- Set queue to true to put into queue, otherwise instantly swaps
-- Queue actually doesn't work yet though lmao
function Pic:newImage(img, queue)
	if queue then
		local new_width, new_height = img:getWidth(), img:getHeight()
		self.queued_moves[#self.queued_moves+1] = {
			image_swap = true,
			image = img,
			width = new_width,
			height = new_height,
			quad = love.graphics.newQuad(0, 0, new_width, new_height, new_width, new_height)
		}
	else
		self.image = img
		self.width = img:getWidth()
		self.height = img:getHeight()
		self.quad = love.graphics.newQuad(0, 0, self.width, self.height, self.width, self.height)
	end
end

-- fades in a new image over the previous one.
function Pic:newImageFadeIn(img, frames)
	self.new_image = {
		image = img,
		transparency = 0,
		opaque_speed = 255 / frames,
	}
end

-- clear the junk from all the tweens and stuff. runs exit function too.
local function clearMove(self)
	if self.exit_func then
		if type(self.exit_func) == "function" then -- single func, no args
			self.exit_func()
		elseif type(self.exit_func) == "table" then
			if type(self.exit_func[1]) == "function" then -- single func, args
				self.exit_func[1](unpack(self.exit_func, 2))
			elseif type(self.exit_func[1]) == "table" then -- multiple funcs
				for i = 1, #self.exit_func do
					self.exit_func[i][1](unpack(self.exit_func[i], 2))
				end
			else -- wot
				print("passed in something wrong for exit_func table")
			end
		else -- wot
			print("maybe passed in something wrong for the exit_func property")
		end
	end
	if self.remove_on_exit then self:remove() end
	self.t, self.tweening, self.curve, self.move_func = nil, nil, nil, nil
	self.during, self.during_frame = nil, nil
	self.exit, self.exit_func = nil, nil
end

-- this is called from createMoveFunc and from some UI functions
function Pic:setQuad(x, y, w, h)
	self.quad = love.graphics.newQuad(x, y, w, h, self.width, self.height)
	self.quad_data = {
		x_offset = x or 0,
		y_offset = y or 0,
		x = self.x + (x or 0),
		y = self.y + (y or 0),
		x_pct = w / self.width,
		y_pct = h / self.height,
	}
end

-- create the move_func that's updated each pic:update()
local function createMoveFunc(self, target)
	-- convert numbers into function equivalents
	local functionize = {"x", "y", "rotation", "transparency", "scaling", "x_scaling", "y_scaling"}
	for i = 1, #functionize do
		local item = functionize[i]
		if target[item] then
			if type(target[item]) == "number" then
				local original = self[item] or 1
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
	self.remove_on_exit = target.remove
	self.exit_func = target.exit_func
	self.t = 0
	self.tweening = tween.new(target.duration, self, target.tween_target, target.easing)
	if target.debug then print("duration:", target.duration) end

	-- set the x/y function depending on if it's a bezier or not
	local xy_func = function() return target.x(), target.y() end
	if target.curve then
		if target.debug then print("creating bezier curve move func") end
		xy_func = function(_self) return _self.curve:evaluate(_self.t) end
		self.curve = target.curve
	end

	-- set the quad change function if provided
	local quad_func = nil
	if target.quad then
		local start_x_pct = self.quad_data.x_pct or (target.quad.x and 0 or 1)
		local end_x_pct = target.quad.x_percentage or 1
		local start_y_pct = self.quad_data.y_pct or (target.quad.y and 0 or 1)
		local end_y_pct = target.quad.y_percentage or 1

		quad_func = function(_self, dt)
			local cur_x_pct = (end_x_pct - start_x_pct) * _self.t + start_x_pct
			local cur_width = cur_x_pct * _self.width
			local cur_x = target.quad.x and target.quad.x_anchor * (1-_self.t) * _self.width * end_x_pct or 0
			local cur_y_pct = (end_y_pct - start_y_pct) * _self.t + start_y_pct
			local cur_height = cur_y_pct * _self.height
			local cur_y = target.quad.y and target.quad.y_anchor * (1-_self.t) * _self.height * end_y_pct or 0
			_self:setQuad(cur_x, cur_y, cur_width, cur_height)
		end
	end

	-- create the move_func
	local move_func = function(_self, dt)
		_self.t = _self.t + dt / target.duration
		local complete = _self.tweening:update(dt)
		_self.x, _self.y = xy_func(_self)
		_self.rotation, _self.transparency = target.rotation(), target.transparency()
		_self.scaling = target.scaling()
		_self.x_scaling = target.x_scaling()
		_self.y_scaling = target.y_scaling()
		if quad_func then quad_func(_self, dt) end
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
		scaling: target scaling, or function
		x_scaling, y_scaling: target scaling in one axis, takes precedence over scaling
		transparency: target transparency, or function
		easing: easing, default is "linear"
		tween_target: variables to tween, default is {t = 1}
		curve: bezier curve, provided as a love.math.newBezierCurve() object
		queue: if true, will queue this move after the previous one is finished. default is true
		here: if true, will instantly move from current position; false to move from end of previous position. only if queue is false
		during: {frame_step, frame_start, func, args}, if any, to execute every dt_step while tweening.
		remove: execute when the move finishes. Can be: 1) "true" to delete, 2) func, 3) {func, args},  4) {{f1, a1}, {f2, a2}, ...}
		exit_func: execute when the move finishes. Can be 1) func, 2) {func, args}, 3) {{f1, a1}, {f2, a2}, ...}
		quad: {x = bool, y = bool, x_percentage = 0-1, y_percentage = 0-1, x_anchor = 0-1, y_anchor = 0-1} to tween a quad
		debug: print some unhelpful debug info
	Junk created: self.t, move_func, tweening, curve, exit, during. during_frame
	Cleans up after itself when movement or tweening finished during Pic:update()
--]]
function Pic:change(target)
	target.easing = target.easing or "linear"
	target.tween_target = target.tween_target or {t = 1}
	if target.queue ~= false then target.queue = true end
	if target.debug then print("New move instruction received")	end
	if target.duration == 0 then target.duration = 0.0078125 end -- let me know if this hack causes problems

	if not target.duration then -- apply instantly, interrupting all moves
		clearMove(self)
		self.queued_moves = {}
		self.x = target.x or self.x
		self.y = target.y or self.y
		self.rotation = target.rotation or self.rotation
		self.scaling = target.scaling or self.scaling
		self.x_scaling = target.x_scaling or self.x_scaling
		self.y_scaling = target.y_scaling or self.y_scaling
		self.transparency = target.transparency or self.transparency
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

-- queues a wait during the move animation, in frames. 0 duration is ok I guess
function Pic:wait(frames)
	self:change{duration = frames}
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
	self.exit_func = nil
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
						self.during[i][3](table.unpack(self.during[i], 4))
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
				if new_target.image_swap then
					self.image = new_target.image
					self.width = new_target.width
					self.height = new_target.height
					self.quad = new_target.quad
					self.move_func = function() return true end
				else
					self.move_func = createMoveFunc(self, new_target)
				end
			end
		end
	end
	if self.new_image then
		self.new_image.transparency = self.new_image.transparency + self.new_image.opaque_speed
		if self.new_image.transparency >= 255 then
			self.image = self.new_image.image
			self.new_image = nil
		end
	end
end

return common.class("Pic", Pic)
