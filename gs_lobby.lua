local love = _G.love

local common = require "class.commons"
local image = require "image"
local Pic = require "pic"

local pointIsInRect = require "utilities".pointIsInRect

local lobby = {}

function lobby:enter()
	if self.sound:getCurrentBGM() ~= "bgm_menu" then
		self.sound:stopBGM()
		self.sound:newBGM("bgm_menu", true)
	end
	self.current_background = common.instance(self.background.RabbitInASnowstorm, self)

	local stage = self.stage
	self.clicked = false
	self.current_users = {}

	local locations = {
		ranked_match = {x = stage.width * 0.25, y = stage.height * 0.3},
		create = {x = stage.width * 0.75, y = stage.height * 0.3},
		game_background = {x = stage.x_mid, y = stage.height * 0.7},
		search_ranked = {x = stage.x_mid, y = stage.height * 0.1},
		search_none = {x = stage.x_mid, y = stage.height * 0.1},
		cancel_search = {x = stage.width * 0.75, y = stage.height * 0.1},
		back = {x = stage.width * 0.1, y = stage.height * 0.9},
	}

	self.screen_elements = {
		create = common.instance(Pic, self, {x = locations.create.x,
			y = locations.create.y, image = image.lobby.create}),
		ranked_match = common.instance(Pic, self, {x = locations.ranked_match.x,
			y = locations.ranked_match.y, image = image.lobby.ranked_match}),
		game_background = common.instance(Pic, self, {x = locations.game_background.x,
			y = locations.game_background.y, image = image.lobby.game_background}),
		search_ranked = common.instance(Pic, self, {x = locations.search_ranked.x,
			y = locations.search_ranked.y, image = image.lobby.search_ranked}),
		search_none = common.instance(Pic, self, {x = locations.search_none.x,
			y = locations.search_none.y, image = image.lobby.search_none}),
		cancel_search = common.instance(Pic, self, {x = locations.cancel_search.x,
			y = locations.cancel_search.y, image = image.lobby.cancel_search}),
		back = common.instance(Pic, self, {x = locations.back.x,
			y = locations.back.y, image = image.lobby.back}),
	}
	self.screen_buttons = {
		{item = self.screen_elements.create, action = lobby.createCustomGame},
		{item = self.screen_elements.ranked_match, action = lobby.joinRankedQueue},
		{item = self.screen_elements.cancel_search, action = lobby.cancelRankedQueue},
		{item = self.screen_elements.back, action = lobby.goBack},
	}
end

function lobby:updateUsers(all_dudes)
	self.current_users = all_dudes
end

function lobby:createCustomGame()
end

function lobby:joinCustomGame()
end

function lobby:spectateGame()
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

function lobby:mousepressed(x, y)
	for i = 1, #self.screen_buttons do
		if pointIsInRect(x, y, self.screen_buttons[i].item:getRect()) then
			self.clicked = self.screen_buttons[i]
			return
		end
	end
	self.clicked = false
end

function lobby:mousereleased(x, y)
	for _, v in pairs(self.screen_buttons) do
		if pointIsInRect(x, y, v.item:getRect()) and v == self.clicked then
			v.action(self)
			break
		end
	end
	self.clicked = false
end

function lobby:mousemoved(x, y)
	if self.clicked then
		if not pointIsInRect(x, y, self.clicked.item:getRect()) then
			self.clicked.released()
			self.clicked = false
		end
	end		
end

function lobby:getClickedButton(x, y)
	for _, v in pairs(self.screen_buttons) do
		if pointIsInRect(x, y, v.item:getRect()) then
			return v
		end
	end
	return false
end

function lobby:drawCurrentUsers()
	local dude = self.current_users

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

function lobby:draw()
	local screen_elements = self.screen_elements

	self.current_background:draw()
	screen_elements.game_background:draw()
	screen_elements.create:draw()
	screen_elements.ranked_match:draw()
	--screen_elements.search_ranked:draw()
	screen_elements.search_none:draw()
	screen_elements.cancel_search:draw()
	screen_elements.back:draw()
	lobby.drawCurrentUsers(self)
end

function lobby:update(dt)
	self.current_background:update(dt)
end

return lobby
