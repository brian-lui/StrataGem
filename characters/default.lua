local image = require 'image'
local tween = require 'tween'

local lamer = {
	full_size_image = love.graphics.newImage('images/characters/heath.png'),
	small_image = love.graphics.newImage('images/characters/heathsmall.png'),
	action_image = love.graphics.newImage('images/characters/heathaction.png'),
	shadow_image = love.graphics.newImage('images/characters/heathshadow.png'),
	super_fuzz_image = love.graphics.newImage('images/ui/superfuzzred.png'),

	character_id = "Lamer",
	meter_gain = {RED = 4, BLUE = 4, GREEN = 4, YELLOW = 4},
	super_images = {
		word = image.UI.super.red_word,
		partial = image.UI.super.red_partial,
		full = image.UI.super.red_full,
		glow = {image.UI.super.red_glow1, image.UI.super.red_glow2, image.UI.super.red_glow3, image.UI.super.red_glow4}
	},

	SUPER_COST = 64,
	RUSH_COST = 32,
	DOUBLE_COST = 16,
	MAX_MP = 64,
	cur_mp = 0,
	old_mp = 0,
	hand_size = 5,
	pieces_fallen = 0,
	--get_piece = false,
	dropped_piece = false,
	super_clicked = false,
	supering = false,
	super_this_turn = false,
	current_rush_cost = 32, -- used for calculations
	current_double_cost = 16, -- used for calculations
	place_type = "normal",
	--piece_fx = false,
}

function lamer:actionPhase(dt)
end

-- returns a list of {frames, func, args to execute}
function lamer:afterGravity()
	return {}
end


function lamer:beforeMatch(gem_table)
end

function lamer:duringMatch(gem_table)
end

function lamer:afterMatch()
end

function lamer:cleanup()
end

function lamer:super()
	if self.cur_mp >= self.SUPER_COST then
		self.super_glow.full.scaling = 0
		self.supering = not self.supering
	end
end

function lamer:pieceDroppedOK(piece, shift)
	local _, place_type = piece:isDropValid(shift)
	if place_type == "normal" then
		return true
	elseif place_type == "rush" then
		return self.cur_mp >= (self.current_rush_cost) and not self.supering
	elseif place_type == "double" then
		return self.cur_mp >= (self.current_double_cost) and not self.supering
	end
end


function lamer:superSlideIn()
	local x_pos = self.ID == "P1" and stage.width * -0.2 or stage.width * 1.2

	local particles = game.particles

	local shadow = particles.superEffects2:new{
		image = self.shadow_image,
		x = x_pos,
		y = stage.height * 0.5,
		update = function(self, dt)
			if self.tweening then
				local complete = self.tweening:update(dt)
				if complete then
					queue.add(25, self.remove, self)
					self.tweening = nil
				end
			end
		end
	}
	local action = particles.superEffects3:new{
		image = self.action_image,
		x = x_pos,
		y = stage.height * 0.5,
		update = function(self, dt)
			if self.tweening then
				local complete = self.tweening:update(dt)
				if complete then
					queue.add(25, self.remove, self)
					self.tweening = nil
				end
			end
		end
	}

	local fuzz1 = particles.superEffects1:new{
		image = self.super_fuzz_image,
		x = stage.width * 0.5,
		y = self.super_fuzz_image:getHeight() * -0.5,
		update = function(self, dt)
			if self.tweening then
				local complete = self.tweening:update(dt)
				if complete then
					queue.add(40, self.remove, self)
					self.tweening = nil
				end
			end
		end
	}

	local fuzz2 = particles.superEffects1:new{
		image = self.super_fuzz_image,
		x = stage.width * 0.5,
		y = self.super_fuzz_image:getHeight() * 0.5 + stage.height,
		update = function(self, dt)
			if self.tweening then
				local complete = self.tweening:update(dt)
				if complete then
					queue.add(40, self.remove, self)
					self.tweening = nil
				end
			end
		end
	}

	fuzz1.tweening = tween.new(0.35, fuzz1, {y = 0}, "outQuart")
	fuzz2.tweening = tween.new(0.35, fuzz2, {y = stage.height}, "outQuart")

	if self.ID == "P1" then
		action.tweening = tween.new(0.5, action, {x = stage.width * 0.475}, "outQuart")
		shadow.tweening = tween.new(0.5, shadow, {x = stage.width * 0.525}, "outQuart")
	else
		action.tweening = tween.new(0.5, action, {x = stage.width * 0.525}, "outQuart")
		shadow.tweening = tween.new(0.5, shadow, {x = stage.width * 0.475}, "outQuart")
		shadow.flip, action.flip = true, true
	end
end

return lamer
