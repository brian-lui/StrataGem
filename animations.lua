local love = _G.love

--[[
	This module provides the animations for the characters in the top corners
	of the game field.
--]]

local common = require 'classcommons'
local pairs = pairs
local Animation = require "animation"

local spairs = require "utilities".spairs

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
local locations = { -- TODO: put into stage.lua later?
	P1 = {x = 150, y = 150},
	P2 = {x = 876, y = 150},
}

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
-- Reset the rotation information once the rotation is finished
local function rotateFinished(self)
    -- store the finished rotation values
    self.final.angle = self.final.angle + self.rotation.angle

    -- reset the rotation state variables
    self.rotation.angle = 0
    self.tweens.Rotate = nil
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

---------------------------------PUBLIC CLASS----------------------------------
local Animations = {}
function Animations:init(game)
	self.game = game
	self.allAnimations = {}

	self.draw_array = {} -- sorted allAnimations
	self.priority = 0 -- draw order. higher numbers are shown on top
end

function Animations:create(tbl, player)
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
		priority = self.priority,
		owner = player,
		is_child = false,
		children = {},
		parent = { -- put x y spin here lol
			x = locations[player.ID].x,
			y = locations[player.ID].y,
			angle = 0,
			rotation = {angle = 0},
		},
		rotation = {pivot_x = 0, pivot_y = 0, angle = 0},
		final = {x = 0, y = 0, angle = 0},
		remove_func = function() end,
		tweens = {},
	}
	-- apply user parameters
	for k, v in pairs(tbl) do object[k] = v end

	local container = self.game.inits.ID.particle
	self.allAnimations[container] = common.instance(Animation, object, self)
	updatePriority()
end

function Animations:remove()
	local container = self.game.inits.ID.particle
	self.allAnimations[container] = nil
	updatePriority()
end

function Animations:updateAll(dt)
	local function onwards(v)
		updateThis(v, dt)
		for k, _ in pairs(v.children) do onwards(k) end
	end
	for _, v in pairs(self.allAnimations) do
		if not v.is_child then onwards(v) end
	end
end

function Animations:drawAll()
end

function Animations:drawTracers()
	local colors = {{255, 0, 0}, {0, 255, 0}, {0, 0, 255}, {255, 255, 0}, {255, 0, 255}, {0, 255, 255}}
	local count = 1
	love.graphics.push("all")
		love.graphics.setPointSize(3 * window.scale)
		for _, v in spairs(self.allAnimations) do
			love.graphics.setColor(colors[count])
			count = (count % #colors) + 1
			love.graphics.points(v.x, v.y)
		end
	love.graphics.pop()
end

return common.class("Animations", Animations)
