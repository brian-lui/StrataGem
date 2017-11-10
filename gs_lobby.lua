local love = _G.love
local common = require "class.commons"
local image = require "image"
local Pic = require "pic"
local pointIsInRect = require "utilities".pointIsInRect

local lobby = {}

--[[ create a clickable object
	mandatory parameters: name, image, image_pushed, end_x, end_y, action
	optional parameters: duration, transparency, start_x, start_y, easing,
		exit, pushed, pushed_sfx, released, released_sfx
--]]
function lobby:_createButton(params)
	if params.name == nil then print("No object name received!") end
	if params.image_pushed == nil then print("No push image received for " .. params.name .. "!") end
	local stage = self.stage
	local button = common.instance(Pic, self, {
		name = params.name,
		x = params.start_x or params.end_x,
		y = params.start_y or params.end_y,
		transparency = params.start_transparency or 255,
		image = params.image,
		container = lobby.ui_clickable,
	})
	button:moveTo{duration = params.duration, x = params.end_x, y = params.end_y,
		transparency = params.end_transparency or 255,
		easing = params.easing or "linear", exit = params.exit}
	button.pushed = params.pushed or function()
		self.sound:newSFX(pushed_sfx or "button")
		button:newImage(params.image_pushed)
	end
	button.released = params.released or function()
		if released_sfx then self.sound:newSFX(released_sfx) end
		button:newImage(params.image)
	end
	button.action = params.action
	return button
end

--[[ creates an object that can be tweened but not clicked
	mandatory parameters: name, image, end_x, end_y
	optional parameters: duration, transparency, start_x, start_y, easing, exit
--]]
function lobby:_createImage(params)
	if params.name == nil then print("No object name received!") end
	local stage = self.stage
	local button = common.instance(Pic, self, {
		name = params.name,
		x = params.start_x or params.end_x,
		y = params.start_y or params.end_y,
		transparency = params.transparency or 255,
		image = params.image,
		container = lobby.ui_static,
	})
	button:moveTo{duration = params.duration, x = params.end_x, y = params.end_y,
		transparency = params.transparency, easing = params.easing, exit = params.exit}
	return button
end

function lobby:enter()
	lobby.clicked = nil
	if self.sound:getCurrentBGM() ~= "bgm_menu" then
		self.sound:stopBGM()
		self.sound:newBGM("bgm_menu", true)
	end
	lobby.ui_clickable = {}
	lobby.ui_static = {}
	lobby.current_background = common.instance(self.background.rabbitsnowstorm, self)
	lobby.current_users = {}
	lobby.status_image = nil

	local stage = self.stage
	--create custom game
	lobby._createButton(self, {
		name = "creategame",
		image = image.button.lobbycreatenew,
		image_pushed = image.button.lobbycreatenew,
		duration = 30,
		start_x = 0,
		end_x = stage.width * 0.75,
		start_y = stage.height * 0.9,
		end_y = stage.height * 0.3,
		easing = "inOutBounce",
		action = function() lobby.createCustomGame(self) end,
	})

	-- queue in ranked match
	lobby._createButton(self, {
		name = "rankedmatch",
		image = image.button.lobbyqueueranked,
		image_pushed = image.button.lobbyqueueranked,
		duration = 45,
		start_x = stage.width,
		end_x = stage.width * 0.25,
		start_y = stage.height * 0.7,
		end_y = stage.height * 0.3,
		easing = "outElastic",
		action = function() lobby.joinRankedQueue(self) end,
	})

	-- cancel ranked match search
	lobby._createButton(self, {
		name = "cancelsearch",
		image = image.button.lobbycancelsearch,
		image_pushed = image.button.lobbycancelsearch,
		duration = 60,
		start_x = stage.width * 0.2,
		end_x = stage.width * 0.75,
		start_y = stage.height * 0.2,
		end_y = stage.height * 0.1,
		easing = "inElastic",
		action = function() lobby.cancelRankedQueue(self) end,
	})

	-- back button
	lobby._createButton(self, {
		name = "back",
		image = image.button.back,
		image_pushed = image.button.backpush,
		duration = 15,
		start_x = -image.button.back:getWidth(),
		end_x = image.button.back:getWidth() * 0.6,
		end_y = image.button.back:getHeight() * 0.6,
		easing = "outQuad",
		pushed_sfx = "button_back",
		action = function() lobby.goBack(self) end,
	})

	-- status indicator image
	lobby.status_image = lobby._createImage(self, {
		name = "status",
		image = image.unclickable.lobby_searchingnone,
		duration = 20,
		start_x = stage.width * 0.9,
		end_x = stage.x_mid,
		start_y = stage.height * 0.4,
		end_y = stage.height * 0.1,
		easing = "inOutBounce",
	})
	lobby.status_image.status = "idle"
end

function lobby:updateUsers(all_dudes)
	lobby.current_users = all_dudes
end

function lobby:createCustomGame()
	print("TBD - Create custom game")
end

function lobby:joinCustomGame()
	print("TBD - Join custom game")
end

function lobby:spectateGame()
	print("TBD - Spectate game")
end

function lobby:joinRankedQueue()
	self.client:queue("join")
	print("Joining queue...")
end

function lobby:cancelRankedQueue()
	self.client:queue("leave")
	print("Leaving queue...")
end

function lobby:goBack()
	local client = self.client

	if client.queuing then
		client:queue("leave")

		local queue_time = os.time()
		while client.queuing do
			client:update()
			love.timer.sleep(0.1)
			if os.time() - queue_time > 3 then
				print("server problem!")
				client.queuing = false
			end
		end
	end

	client:disconnect()
	local disc_time = os.time()
	while client.connected do
		client:update()
		love.timer.sleep(0.1)
		if os.time() - disc_time > 3 then
			print("server problem!")
			client.connected = false
		end
	end
	self.sound:newSFX("button_back")
	self.statemanager:switch(require "gs_title")
end

function lobby:_drawCurrentUsers()
	local dude = lobby.current_users

	love.graphics.push("all")
		local x = 150
		local y = 400
		local y_step = 50
		love.graphics.print("Users", x, y-50)
		love.graphics.print("Playing", x+150, y-50)

		for i = 1, #dude do
			if dude[i].queuing then
				love.graphics.setColor(0, 255, 0)
			elseif dude[i].playing then
				love.graphics.setColor(0, 0, 255)
			else
				love.graphics.setColor(0, 0, 0)
			end

			love.graphics.print(dude[i].name, x, y)
			y = y + y_step
		end
	love.graphics.pop()
end

function lobby:update(dt)
	lobby.current_background:update(dt)
	for _, v in pairs(lobby.ui_clickable) do v:update(dt) end
	for _, v in pairs(lobby.ui_static) do v:update(dt) end

	local client = self.client
	if client.queuing then
		if lobby.status_image.status == "idle" then
			lobby.status_image:newImage(image.unclickable.lobby_searchingranked)
			lobby.status_image.status = "queuing"
		end
	else
		if lobby.status_image.status == "queuing" then
			lobby.status_image:newImage(image.unclickable.lobby_searchingnone)
			lobby.status_image.status = "idle"
		end
	end

end

function lobby:draw()
	lobby.current_background:draw()
	for _, v in pairs(lobby.ui_static) do v:draw() end
	for _, v in pairs(lobby.ui_clickable) do v:draw() end
	lobby._drawCurrentUsers(self)
end

function lobby:mousepressed(x, y)
	for _, button in pairs(lobby.ui_clickable) do
		if pointIsInRect(x, y, button:getRect()) then
			lobby.clicked = button
			button.pushed()
			return
		end
	end
	lobby.clicked = false
end

function lobby:mousereleased(x, y)
	for _, button in pairs(lobby.ui_clickable) do
		button.released()
		if pointIsInRect(x, y, button:getRect()) and lobby.clicked == button then
			button.action()
			break
		end
	end
	lobby.clicked = false
end

function lobby:mousemoved(x, y)
	if lobby.clicked then
		if not pointIsInRect(x, y, lobby.clicked:getRect()) then
			lobby.clicked.released()
			lobby.clicked = false
		end
	end
end

return lobby
