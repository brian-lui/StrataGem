local love = _G.love
local common = require "class.commons"
local image = require "image"
local Pic = require "pic"
local pointIsInRect = require "utilities".pointIsInRect

local lobby = {name = "lobby"}

function lobby:init()
	lobby.selectable_chars = {"heath", "walter", "gail", "holly",
		"wolfgang", "hailey", "diggory", "buzz", "ivy", "joy"}
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

-- creates the clickable buttons for selecting characters
function lobby:_createCharacterButtons()
	local stage = self.stage
	lobby.clicked = nil
	local end_x, end_y
	for i = 1, #lobby.selectable_chars do
		local char = lobby.selectable_chars[i]
		if i >= 1 and i < 4 then
			end_x = stage.width * (0.125 * i + 0.5)
			end_y = stage.height * 0.2
		elseif i >= 4 and i < 8 then
			end_x = stage.width * (0.125 * i + 0.0625)
			end_y = stage.height * 0.4
		elseif i >= 8 and i < 11 then
			end_x = stage.width * (0.125 * i - 0.375)
			end_y = stage.height * 0.6
		end
		lobby._createButton(self, {
			name = char,
			image = image.charselect[char.."ring"],
			image_pushed = image.charselect[char.."ring"], -- need new pics!
			duration = 30,
			start_x = -0.05 * i,
			end_x = end_x,
			start_y = 0.1 * i,
			end_y = end_y,
			start_transparency = 195,
			easing = "inOutSine",
			pushed_sfx = "buttoncharacter",
			action = function() 
				if lobby.my_character ~= char and not self.client.queuing then
					lobby.my_character = char
					lobby.displayed_character:newImage(image.charselect[char.."char"])
					lobby.displayed_character_text:newImage(image.charselect[char.."name"])
					lobby.displayed_character:reset()
					lobby.displayed_character_text:reset()
				end
			end,
		})
	end
end

-- creates the clickable UI objects
function lobby:_createUIButtons()
	local stage = self.stage

	-- start button
	lobby._createButton(self, {
		name = "start",
		image = image.button.start,
		image_pushed = image.button.startpush,
		duration = 15,
		end_x = stage.width * 0.25,
		start_y = stage.height + image.button.start:getHeight(),
		end_y = stage.height * 0.8,
		easing = "outQuad",
		action = function() 
			if lobby.my_character and not self.client.queuing then
				lobby.joinRankedQueue(self, "The Queue Details Thanks.") 
				--[[
				local gametype = lobby.gametype
				local char1 = lobby.my_character
				local char2 = lobby.opponent_character
				local bkground = self.background:idx_to_str(lobby.game_background)
				lobby.my_character = nil
				self:start(gametype, char1, char2, bkground, nil, 1)
				--]]
			end
		end,
	})

	-- left arrow for background select
	lobby._createButton(self, {
		name = "leftarrow",
		image = image.button.leftarrow,
		image_pushed = image.button.leftarrow,
		duration = 60,
		end_x = stage.width * 0.6,
		end_y = stage.height * 0.8,
		transparency = 127,
		easing = "linear",
		action = function()
			lobby.game_background = (lobby.game_background - 2) % self.background.total + 1
			local selected_background = self.background:idx_to_str(lobby.game_background)
			local new_image = image.background[selected_background].thumbnail
			lobby.game_background_image:newImage(new_image)
		end,
	})

	-- right arrow for background select
	lobby._createButton(self, {
		name = "rightarrow",
		image = image.button.rightarrow,
		image_pushed = image.button.rightarrow,
		duration = 60,
		end_x = stage.width * 0.9,
		end_y = stage.height * 0.8,
		transparency = 127,
		easing = "linear",
		action = function()
			lobby.game_background = lobby.game_background % self.background.total + 1
			local selected_background = self.background:idx_to_str(lobby.game_background)
			local new_image = image.background[selected_background].thumbnail
			lobby.game_background_image:newImage(new_image)
		end,
	})
end

-- creates the unclickable UI display images
function lobby:_createUIImages()
	local stage = self.stage

	-- large portrait with dummy pic
	lobby.displayed_character = lobby._createImage(self, {
		name = "maincharacter",
		image = image.dummy,
		duration = 6,
		start_x = stage.width * 0.20,
		end_x = stage.width * 0.25,
		end_y = stage.height * 0.5,
		transparency = 60,
		easing = "outQuart",
	})
	lobby.displayed_character.reset = function(c)
		c.x = stage.width * 0.20
		c.transparency = 60
		c:change{duration = 6, x = stage.width * 0.25, transparency = 255, easing = "outQuart"}
	end

	-- large portrait text with dummy pic
	lobby.displayed_character_text = lobby._createImage(self, {
		name = "maincharactertext",
		image = image.dummy,
		duration = 6,
		end_x = stage.width * 0.25,
		start_y = stage.height * 0.7,
		end_y = stage.height * 0.65,
		transparency = 60,
		easing = "outQuart",
	})
	lobby.displayed_character_text.reset = function(c)
		c.y = stage.height * 0.7
		c.transparency = 60
		c:change{duration = 6, y = stage.height * 0.65, transparency = 255, easing = "outQuart"}
	end

	-- background_image_frame
	lobby._createImage(self, {
		name = "backgroundframe",
		image = image.unclickable.select_stageborder,
		duration = 60,
		end_x = stage.width * 0.75,
		end_y = stage.height * 0.8,
		transparency = 127,
		easing = "linear",
	})

	local selected_background = self.background:idx_to_str(lobby.game_background)
	-- background_image
	lobby.game_background_image = lobby._createImage(self, {
		name = "backgroundimage",
		image = image.background[selected_background].thumbnail,
		duration = 60,
		end_x = stage.width * 0.75,
		end_y = stage.height * 0.8,
		transparency = 127,
		easing = "linear",
	})
end

function lobby:enter()
	local stage = self.stage
	lobby.clicked = nil
	if self.sound:getCurrentBGM() ~= "bgm_menu" then
		self.sound:stopBGM()
		self.sound:newBGM("bgm_menu", true)
	end

	lobby.current_background = common.instance(self.background.checkmate, self)
	lobby.current_users = {}

	lobby.game_background = 1 -- what's chosen for the maingame background

	lobby._createCharacterButtons(self)
	lobby._createUIButtons(self)
	lobby._createUIImages(self)

	lobby.my_character = nil -- selected character for gamestart
	lobby.gametype = "1P" -- can change this later to re-use for netplay
	lobby.opponent_character = "walter" -- ditto

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

function lobby:joinRankedQueue(queue_details)
	self.client:queue("join", queue_details)
	print("Joining queue with queue details:")
	print(queue_details)
end

function lobby:cancelRankedQueue()
	self.client:queue("leave")
	print("Leaving queue...")
end

function lobby:goBack()
	print("hello!")
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
