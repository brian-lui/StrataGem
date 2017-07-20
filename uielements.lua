-- graphics for UI elements such as the timer bar.

local image = require 'image'
local pic = require 'pic'
local stage = game.stage

-- Red X shown on gems in invalid placement spots
local redX = pic:new{x = 0, y = 0, image = image.UI.redX}

-- Base tub image
local tub_img = pic:new{x = stage.x_mid, y = stage.height * 0.95 - 189, image = image.UI.tub}

-- Timer text displayed when time is running out
local timertext = {
	scaling = function(t) return math.max(1 / (t * 2 + 0.4), 1) end,
	transparency = function(t) return math.min(255 * 2.5 * t, 255) end,
	x = stage.x_mid,
	y = stage.height * 0.33,
}

function timertext:draw()
	local time_remaining = (game.time_to_next * time.step)

	if time_remaining <= 3 and time_remaining > 0 then
		local time_int = math.ceil(time_remaining)
		local todraw = image.UI.timer[time_int]
		local w, h = todraw:getWidth(), todraw:getHeight()
		local t = time_int - time_remaining
		local scale = self.scaling(t)

		love.graphics.push("all")
			love.graphics.setColor(255, 255, 255, self.transparency(t))
			love.graphics.draw(todraw, self.x, self.y, 0, scale, scale, w/2, h/2)
		love.graphics.pop()
	end
end

-- Base timer bar image
local timerbase = pic:new{x = stage.x_mid, y = stage.height * 0.5 - 80, image = image.UI.timer_bar}

-- Timer class but I'm not using classes yolo
-- It pulls from timertext and timerbase
local Timer = pic:new{x = stage.x_mid, y = stage.height * 0.5 - 80, image = image.UI.timer_bar_full}
Timer.FADE_SPEED = 15
Timer.transparency = 255

function Timer:update()
	-- set percentage of timer to show
	local percent = (game.time_to_next / game.INIT_TIME_TO_NEXT)
	local bar_width = percent * self.width
	self.draw_offset = (1 - percent) * 0.5 * self.width
	self.quad = love.graphics.newQuad(0, 0, bar_width, self.height, self.width, self.height)

	-- fade in/out
	if percent == 0 then
		self.transparency = math.max(self.transparency - self.FADE_SPEED, 0)
	else
		self.transparency = math.min(self.transparency + self.FADE_SPEED, 255)
	end
	timerbase.transparency = self.transparency
end

function Timer:draw()
	timerbase:draw()
	pic.draw(self, nil, self.draw_offset + self.x) -- centered timer bar
	timertext:draw()
end

local UI = {
	timer = Timer,
	redX = redX,
	tub_img = tub_img,
}

return UI
