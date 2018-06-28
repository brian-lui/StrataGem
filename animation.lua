local love = _G.love

--[[
	This module provides the animations for the characters in the top corners
	of the game field.
--]]

local common = require "class.commons"
local Pic = require "pic"
local tween = require "/libraries/tween"

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

local function updatePriority(self) -- update the draw_array. Only called when needed
	local draws, n = {}, 0
	for _, v in pairs(self.allAnimations) do
		n = n + 1
		draws[n] = v
	end
	table.sort(draws, function(a, b) return a.priority < b.priority end)
	self.priority = draws[n].priority + 1
	self.draw_array = draws
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

---------------------------------PUBLIC CLASS----------------------------------
local Animation = {}
function Animation:init(object, manager)
	Pic.init(self, manager.game, object)
	self.manager = manager
end

-- replace current image with a new one
function Animation:swapImage(image)
	self.image = image
	self.width = self.image:getWidth()
	self.height = self.image:getHeight()
	self.quad = love.graphics.newQuad(0, 0, self.width, self.height, self.width, self.height)
end

-- push this image to the bottom of the display stack
function Animation:pushToBottom()
	local min = self.manager.draw_array[1].priority
	self.priority = min - 1
	updatePriority()
end

-- push this image to the top of the display stack
function Animation:pushToTop()
	local max = self.manager.draw_array[#self.draw_array].priority
	self.priority = max + 1
	updatePriority()
end

function Animation:spin(angle, duration, easing)
	assert(type(angle) == "number", "Duration is not a number")
	assert(type(duration) == "number", "Tween destination is not a number")
	if self.tweens.Spin then
		spinFinished(self)
	end
	newTween(self, duration, "spin_angle", self.spin_angle + angle, easing, "Spin")
end

-- Attaches this to a parent Animations. x, y are relative to an unrotated parent.
function Animation:attach(parent, x, y)
	assert(parent ~= nil, "Parent does not exist")
	assert(parent.particle_type == "Animations", "Not an Animations class")
	assert(type(x) == "number" and type(y) == "number", "Distance/angle is NaN")
	self.is_child = true
	self.parent = parent
	parent.children[self] = true
	self.x_from_parent, self.y_from_parent = x, y
	self.spin_angle = parent.angle
end

-- detach this Animations from a parent
function Animation:detach()
	self.is_child = false
	self.parent.children[self] = nil
	self.parent = {x = self.x, y = self.y, angle = self.angle}
end

-- set the pivot point for rotation, given as absolute values.
function Animation:setPivot(pivot_x, pivot_y)
	assert(type(pivot_x) == "number", "pivot_x is not a number")
	assert(type(pivot_y) == "number", "pivot_y is not a number")
	self.rotation.pivot_x = pivot_x or 0
	self.rotation.pivot_y = pivot_y or 0
end

--[[ rotate an image for (angle) radians around a point with (pivot_x) and (pivot_y)
	offset from the image center for (duration) seconds, using (easing) tweening function.
--]]
function Animation:rotate(angle, duration, easing)
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
	if self.tweens.Rotate then
		rotateFinished(self)
	end -- clear previous rotate
	newTween(self, duration, "angle", angle, easing, "Rotate", self.rotation)
end

-- Move an image by x, y, relative to its angle.
function Animation:move(x, y, duration, easing)
	assert(type(x) == "number", "x is not a number")
	assert(type(y) == "number", "y is not a number")
	assert(type(duration) == "number", "Duration is not a number")
	local dist, angle = polar(x, y)
	local abs_x, abs_y = xy(dist, angle - self.parent.angle)
	newTween(self, duration, "x_from_parent", self.x_from_parent + abs_x, easing, "MoveX")
	newTween(self, duration, "y_from_parent", self.y_from_parent + abs_y, easing, "MoveY")
end

function Animation:resize(scaling, duration, easing)
	assert(type(scaling) == "number", "scaling is not a number")
	assert(type(duration) == "number", "duration is not a number")
	newTween(self, duration, "scaling", self.scaling * scaling, easing, "Resize")
end

function Animation:fadeOut(duration, easing)
	assert(type(duration) == "number", "duration is not a number")
	newTween(self, duration, "transparency", 0, easing, "FadeOut")
end

function Animation:fadeIn(duration, easing)
	assert(type(duration) == "number", "duration is not a number")
	newTween(self, duration, "transparency", 1, easing, "FadeIn")
end

return common.class("Animation", Animation, Pic)
