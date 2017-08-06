local love = _G.love

--[[
	HEY DUDES READ THIS
	put images into the img table then call img.name

	functions u can use:
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

local img = {
	heathbody = love.graphics.newImage('images/heathpuppet/heathbody.png'),
	heathhead = love.graphics.newImage('images/heathpuppet/heathhead.png'),
	frontarm = love.graphics.newImage('images/heathpuppet/frontarmready.png'),
	backarm = love.graphics.newImage('images/heathpuppet/backarmready.png'),
	wand = love.graphics.newImage('images/heathpuppet/wand.png'),
	heathblink = love.graphics.newImage('images/heathpuppet/heathblink.png')
}
local function press_g(self)
	self.TestAnimation = self.animations:create({image = img.heathbody}, self.p1)
	self.TestAnimation2 = self.animations:create({image = img.heathhead}, self.p1)
	self.TestAnimation3 = self.animations:create({image = img.frontarm}, self.p1)
	self.TestAnimation4 = self.animations:create({image = img.backarm}, self.p1)
	self.TestAnimation5 = self.animations:create({image = img.wand}, self.p1)
	self.TestAnimation2:attach(self.self.TestAnimation, -6, -89)
	self.TestAnimation3:attach(self.TestAnimation, 30, -21)
	self.TestAnimation4:attach(self.TestAnimation, -43, -13)
	self.TestAnimation5:attach(self.TestAnimation3, 32, -34)
	self.TestAnimation:setPivot(0, 50)
	self.TestAnimation2:setPivot(0, 60)
	self.TestAnimation3:setPivot(-20, -3)
end

local function press_b(self)
	self.TestAnimation:rotate(-math.pi/2, 2, "inQuart")
	self.TestAnimation:move(80, 0, 2, "inQuart")
	for i = 10, 120, 20 do
		self.queue:add(i, self.TestAnimation3.rotate, self.TestAnimation3, -math.pi * 0.5, 0.15, "linear")
	end
	for i = 0, 110, 20 do
		self.queue:add(i, self.TestAnimation3.rotate, self.TestAnimation3, math.pi * 0.5, 0.15, "linear")
	end

	self.queue:add(125, self.TestAnimation5.move, self.TestAnimation5, 50, 500, 1, "outCubic")
	--[[
	for i = 30, 360, 30 do
		-- self.queue:add(frames, func, self, args)
		self.queue:add(i, TestAnimation2.swapImage, TestAnimation2, img.heathblink)
		self.queue:add(i + 10, TestAnimation2.swapImage, TestAnimation2, img.heathhead)
	end
	--]]
end

local function press_h(self)
	self.TestAnimation2:move(30, 10, 0.5, "linear")
	self.TestAnimation:spin(math.pi/3, 0.2, "linear")
	--TestAnimation:resize(2, 1, "linear")
end

local function press_j(self)
	self.TestAnimation2:rotate(math.pi/3, 1, "inQuart")
	--TestAnimation:resize(0.5, 1, "outCubic")
end

local function press_n(self)
	self.TestAnimation2:rotate(math.pi*2, 1, "linear")
	self.TestAnimation:fadeOut(1, "outQuart")
end

local function press_m(self)
	self.TestAnimation:pushToTop()
	self.TestAnimation:fadeIn(0.5, "inQuart")
	self.TestAnimation:resize(0.5, 2, "inQuart")
end

local sandbox = {
	g = press_g,
	b = press_b,
	h = press_h,
	n = press_n,
	j = press_j,
	m = press_m,
}

function sandbox:keypressed(key)
	if type(self[key]) == "function" then
		self[key](self)
	end
end

function sandbox:update(dt)
	self.animations:updateAll(dt)
	self.queue.update()
	self.timeBucket = self.timeBucket + dt
end

return sandbox
