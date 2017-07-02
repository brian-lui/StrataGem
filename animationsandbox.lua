--[[
	HEY DUDES READ THIS
	put images into the img table then call img.name

	functions u can use:
	dog:new(tbl, owner) -- just stick with the defaults here for now thanks
	dog:remove() -- delete dog
	dog:swapImage(image) -- image should be in the form img.dog
	dog:pushToBottom() -- show on bottom
	dog:pushToTop() -- show on top
	dog:spin(angle, duration, easing) -- rotate by angle in-place around origin.
	dog:attach(parent, x, y) -- attach to parent, offset by x and y
	dog:detach() -- detach from parent (haven't tried this yet, please see if it works)
	dog:setPivot(x, y) -- set pivot for rotation at x, y (absolute) relative to image origin.
	dog:rotate(angle, duration, easing) -- rotate by angle around pivot_x, y.
	dog:move(x, y, duration, easing) -- move by x, y relative to parent. sorry
	dog:resize(scaling, duration, easing) -- not implemented yet lol!
	dog:fadeOut(fade_speed, duration, easing) -- not implemented yet lol!
	dog:fadeIn(fade_speed, duration, easing) -- not implemented yet lol!
--]]

local animations = require 'animations'
local pi = math.pi

local img = {
	heathbody = love.graphics.newImage('images/heathpuppet/heathbody.png'),
	heathhead = love.graphics.newImage('images/heathpuppet/heathhead.png'),
	frontarm = love.graphics.newImage('images/heathpuppet/frontarmready.png'),
	backarm = love.graphics.newImage('images/heathpuppet/backarmready.png'),
	wand = love.graphics.newImage('images/heathpuppet/wand.png'),
	heathblink = love.graphics.newImage('images/heathpuppet/heathblink.png')
}
local function press_g()
	local heathBody = {
		image = img.heathbody,
	}
	local HeathHead = {
		image = img.heathhead,
	}
	local Frontarm = {
		image = img.frontarm,
	}
	local backarm = {
		image = img.backarm,
	}
	local wand = {
		image = img.wand,
	}
	
	TestAnimation = animations:new(heathBody, p1)
	TestAnimation2 = animations:new(HeathHead, p1)
	TestAnimation3 = animations:new(Frontarm, p1)
	TestAnimation4 = animations:new(backarm, p1)
	TestAnimation5 = animations:new(wand, p1)
	TestAnimation2:attach(TestAnimation, -6, -89)
	TestAnimation3:attach(TestAnimation, 30, -21)	
	TestAnimation4:attach(TestAnimation, -43, -13)
	TestAnimation5:attach(TestAnimation3, 32, -34)
	TestAnimation:setPivot(0, 50)
	TestAnimation2:setPivot(0, 60)
	TestAnimation3:setPivot(-20, -3)

end

local function press_b()
	TestAnimation:rotate(-math.pi/2, 2, "inQuart")
	TestAnimation:move(80, 0, 2, "inQuart")
	for i = 10, 120, 20 do
		queue.add(i, TestAnimation3.rotate, TestAnimation3, -math.pi/2, 0.15, "linear")
	end
	for i = 0, 110, 20 do
		queue.add(i, TestAnimation3.rotate, TestAnimation3, math.pi/2, 0.15, "linear")
	end

	queue.add(125, TestAnimation5.move, TestAnimation5, 50, 500, 1, "outCubic")
	--[[
	for i = 30, 360, 30 do	
		-- queue.add(frames, func, self, args)
		queue.add(i, TestAnimation2.swapImage, TestAnimation2, img.heathblink)
		queue.add(i + 10, TestAnimation2.swapImage, TestAnimation2, img.heathhead)
	end
	--]]
end

local function press_h()
	TestAnimation2:move(30, 10, 0.5, "linear")
	TestAnimation:spin(math.pi/3, 0.2, "linear")
	--TestAnimation:resize(2, 1, "linear")
end

local function press_j()
	TestAnimation2:rotate(math.pi/3, 1, "inQuart")
	--TestAnimation:resize(0.5, 1, "outCubic")
end

local function press_n()
	TestAnimation2:rotate(math.pi*2, 1, "linear") 
	TestAnimation:fadeOut(1, "outQuart")
end

local function press_m()
	TestAnimation:pushToTop()
	TestAnimation:fadeIn(0.5, "inQuart")
	TestAnimation:resize(0.5, 2, "inQuart")
end


local sandbox = {
	g = press_g,
	b = press_b,
	h = press_h,
	n = press_n,
	j = press_j,
	m = press_m,
}

return sandbox