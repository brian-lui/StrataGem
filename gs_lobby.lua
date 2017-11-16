local love = _G.love
local common = require "class.commons"
local image = require "image"
local Pic = require "pic"
local pointIsInRect = require "utilities".pointIsInRect

local lobby = {name = "lobby"}

function lobby:init()
	lobby.ui = {clickable = {}, static = {}, popup_clickable = {}, popup_static = {}}
	self:_createSettingsMenu(lobby, {
		exitstate = "gs_title",
		settings_icon = image.button.back,
		settings_iconpush = image.button.backpush,
	})
end
-- refer to game.lua for instructions for _createButton and _createImage
function lobby:_createButton(params)
	return self:_createButton(lobby, params)
end

function lobby:_createImage(params)
	return self:_createImage(lobby, params)
end

function lobby:enter()
	local stage = self.stage
	lobby.clicked = nil
	if self.sound:getCurrentBGM() ~= "bgm_menu" then
		self.sound:stopBGM()
		self.sound:newBGM("bgm_menu", true)
	end

	lobby.current_background = common.instance(self.background.rabbitsnowstorm, self)
	lobby.current_users = {}
	lobby.status_image = nil

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

function lobby:openSettingsMenu()
	self:_openSettingsMenu(lobby)
end

function lobby:closeSettingsMenu()
	self:_closeSettingsMenu(lobby)
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
	for _, tbl in pairs(lobby.ui) do
		for _, v in pairs(tbl) do v:update(dt) end
	end

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
	local darkened = self.settings_menu_open
	lobby.current_background:draw{darkened = darkened}
	for _, v in pairs(lobby.ui.static) do v:draw{darkened = darkened} end
	for _, v in pairs(lobby.ui.clickable) do v:draw{darkened = darkened} end
	lobby._drawCurrentUsers(self)
	self:_drawSettingsMenu(lobby)
end

function lobby:mousepressed(x, y)
	self:_mousepressed(x, y, lobby)
end

function lobby:mousereleased(x, y)
	self:_mousereleased(x, y, lobby)
end

function lobby:mousemoved(x, y)
	self:_mousemoved(x, y, lobby)
end

return lobby
