--[[
	This module provides the animations for the characters in the top corners
	of the game field.
--]]

local image = require 'image'
local class = require 'middleclass'
local stage = require 'stage'
local pic = require 'pic'
local tween = require 'tween'
local pairs = pairs

-----------------------------------HELPERS-------------------------------------
-- cartesian to polar
local function polar(x, y)
	return (x^2 + y^2)^0.5, math.atan2(y, x)
end

-- polar to cartesian
local function xy(dist, angle, x, y)
	x, y = x or 0, y or 0
	return dist * math.cos(angle) + x, dist * math.sin(angle) + y
end

-----------------------------------UPDATES-------------------------------------
local locations = { -- put into stage.lua later
	[p1] = {x = 150, y = 150},
	[p2] = {x = 876, y = 150},
}

local AllAnimations = {}
local draw_array = {} -- sorted AllAnimations
local priority = 0 -- draw order. higher numbers are shown on top

local function updatePriority() -- update the draw_array. Only called when needed
	local draws, n = {}, 0
	for _, v in pairs(AllAnimations) do
		n = n + 1
		draws[n] = v
	end
	table.sort(draws, function(a, b) return a.priority<b.priority end)
	priority = draws[n].priority + 1
	draw_array = draws
end

------------------------------PRIVATE FUNCTIONS--------------------------------
-- Sets a tween. Duration in seconds, property is the variable to change,
-- target is the ending number for the property, easing is the easing function.
local function newTween(self, duration, property, target, easing, name, tween_target)
	self.tweens[name] = tween.new(duration, tween_target or self, {[property] = target}, easing)
end

-- Reset the rotation information once the rotation is finished
local function rotateFinished(self)
    -- store the finished rotation values
    self.final.angle = self.final.angle + self.rotation.angle

    -- reset the rotation state variables
    self.rotation.angle = 0
    self.tweens.Rotate = nil
end

local function spinFinished(self)
	self.final.angle = self.final.angle + self.spin_angle
	self.spin_angle = 0
	self.tweens.Spin = nil
end

local function updateThis(self, dt)
  -- tween the stuff
  for k, v in pairs(self.tweens) do
      local complete = v:update(dt)
      if complete then
          if k == "Rotate" then rotateFinished(self) end
          self.tweens[k] = nil
      end
  end

  -- get position as rotated around pivot point
  local pivot_dist, pivot_angle = polar(-self.rotation.pivot_x, -self.rotation.pivot_y)
  local pivot_x, pivot_y = xy(pivot_dist, pivot_angle + self.rotation.angle + self.final.angle)

  -- reset origin so it's relative to the image center
  local rotated_local_x = pivot_x + self.rotation.pivot_x
  local rotated_local_y = pivot_y + self.rotation.pivot_y

  -- rotate with the parent
  local absolute_offset_dist, absolute_offset_angle = polar(rotated_local_x + self.x_from_parent, rotated_local_y + self.y_from_parent)
  local absolute_offset_x, absolute_offset_y = xy(absolute_offset_dist, absolute_offset_angle + self.parent.angle)

  -- store final values
  self.x = self.parent.x + absolute_offset_x
  self.y = self.parent.y + absolute_offset_y
  self.angle = self.parent.angle + self.final.angle + self.rotation.angle
	
	-- remove function
	self:remove_func()
end

local function drawThis(self)
	local h_flip = self.owner == p2
	pic.draw(self, h_flip, self.x, self.y, self.angle)
end

---------------------------------PUBLIC CLASS----------------------------------
local Animations = class('Animations', pic)
function Animations:initialize(tbl, player)
	local object = { -- default parameters
		particle_type = "Animations",
		spin_angle = 0, -- this's spin amount. this gets tweened
		x_from_parent = 0, -- gets tweened
		y_from_parent = 0, -- gets tweened
		x = 0, -- recalculated every frame, leave this alone
		y = 0, -- recalculated every frame, leave this alone
		angle = 0, -- recalculated every frame, leave this alone
		scaling = 1,
		transparency = 255,
		priority = priority,
		owner = player,
		is_child = false,
		children = {},
		parent = {x = locations[player].x, y = locations[player].y, angle = 0, rotation = {angle = 0}}, -- put x y spin here lol
		rotation = {pivot_x = 0, pivot_y = 0, angle = 0},
		final = {x = 0, y = 0, angle = 0},
		remove_func = function(self) end,
		tweens = {},
	}
	-- apply user parameters
	for k, v in pairs(tbl) do object[k] = v end
	pic.initialize(self, object)
	AllAnimations[ID.particle] = self
	updatePriority()
end

function Animations:remove()
	AllAnimations[ID.particle] = nil
	updatePriority()
end

-- replace current image with a new one
function Animations:swapImage(img)
	self.image = img
	self.width = self.image:getWidth()
	self.height = self.image:getHeight()
	self.quad = love.graphics.newQuad(0, 0, self.width, self.height, self.width, self.height)	
end

-- push this image to the bottom of the display stack
function Animations:pushToBottom()
	local min = draw_array[1].priority
	self.priority = min - 1
	updatePriority()
end

-- push this image to the top of the display stack
function Animations:pushToTop()
	local max = draw_array[#draw_array].priority
	self.priority = max + 1
	updatePriority()
end

function Animations:spin(angle, duration, easing)
	assert(type(angle) == "number", "Duration is not a number")
	assert(type(duration) == "number", "Tween destination is not a number")
	if self.tweens.Spin then spinFinished(self) end
	newTween(self, duration, "spin_angle", self.spin_angle + angle, easing, "Spin")
end

-- Attaches this to a parent animation. x, y are relative to an unrotated parent.
function Animations:attach(parent, x, y)
	assert(parent ~= nil, "Parent does not exist")
	assert(parent.particle_type == "Animations", "Not an Animations class")
	assert(type(x) == "number" and type(y) == "number", "Distance/angle is NaN")
	self.is_child = true
	self.parent = parent
	parent.children[self] = true
	self.x_from_parent, self.y_from_parent = x, y
	self.spin_angle = parent.angle
end

-- detach this animation from a parent
function Animations:detach()
	self.is_child = false
	self.parent.children[self] = nil
	self.parent = {x = self.x, y = self.y, angle = self.angle}
end

-- set the pivot point for rotation, given as absolute values.
function Animations:setPivot(pivot_x, pivot_y)
	assert(type(pivot_x) == "number", "pivot_x is not a number")
	assert(type(pivot_y) == "number", "pivot_y is not a number")
	self.rotation.pivot_x = pivot_x or 0
	self.rotation.pivot_y = pivot_y or 0
end

--[[ rotate an image for (angle) radians around a point with (pivot_x) and (pivot_y)
	offset from the image center for (duration) seconds, using (easing) tweening function.
--]]
function Animations:rotate(angle, duration, easing)
	assert(type(angle) == "number", "Angle is not a number")
	assert(type(duration) == "number", "Duration is not a number")	
	--[[
	This is to explain to myself what I am doing here for when I forget later.
	1. Translate the pivot point to become the origin
	2. Find the radius and angle from the pivot point
	3. Find the destination angle: the pivot angle plus the angle change supplied by user
	4. Use the destination angle to find the destination x and y offsets from the pivot
	5. Reverse the translation to send origin back to the pivot point
	--]]
	if self.tweens.Rotate then rotateFinished(self) end -- clear previous rotate
	newTween(self, duration, "angle", angle, easing, "Rotate", self.rotation)
end

-- Move an image by x, y, relative to its angle.
function Animations:move(x, y, duration, easing)
	assert(type(x) == "number", "x is not a number")	
	assert(type(y) == "number", "y is not a number")
	assert(type(duration) == "number", "Duration is not a number")	
	local dist, angle = polar(x, y)
	local abs_x, abs_y = xy(dist, angle - self.parent.angle)
	newTween(self, duration, "x_from_parent", self.x_from_parent + abs_x, easing, "MoveX")
	newTween(self, duration, "y_from_parent", self.y_from_parent + abs_y, easing, "MoveY")
end

function Animations:resize(scaling, duration, easing)
	assert(type(scaling) == "number", "scaling is not a number")
	assert(type(duration) == "number", "duration is not a number")
	newTween(self, duration, "scaling", self.scaling * scaling, easing, "Resize")
end

function Animations:fadeOut(duration, easing)
	assert(type(duration) == "number", "duration is not a number")
	newTween(self, duration, "transparency", 0, easing, "FadeOut")
end

function Animations:fadeIn(duration, easing)
	assert(type(duration) == "number", "duration is not a number")
	newTween(self, duration, "transparency", 255, easing, "FadeIn")
end

function Animations:updateAll(dt)
	local function onwards(v)
		updateThis(v, dt)
		for k, v in pairs(v.children) do onwards(k) end
	end
	for _, v in pairs(AllAnimations) do
		if not v.is_child then onwards(v) end
	end
end

function Animations:drawAll()
	for i = 1, #draw_array do drawThis(draw_array[i]) end
end

function Animations:drawTracers()
	local colors = {{255, 0, 0}, {0, 255, 0}, {0, 0, 255}, {255, 255, 0}, {255, 0, 255}, {0, 255, 255}}
	local count = 1
	love.graphics.push("all")
		love.graphics.setPointSize(3)
		for _, v in spairs(AllAnimations) do
			love.graphics.setColor(colors[count])
			count = (count % #colors) + 1
			love.graphics.points(v.x, v.y)
		end
	love.graphics.pop()
end

return Animations
