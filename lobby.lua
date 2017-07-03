local image = require 'image'
local stage = game.stage
local character = require 'character'
local class = require 'middleclass'
local socket = require 'socket'
local Background = require 'background'
local client = require 'client'
local pic = require 'pic'
require 'utilities'

lobby = {}
lobby.connected = false
local clicked = false

lobby.current_users = {}


function lobby.updateUsers(all_dudes)
	lobby.current_users = all_dudes
end

function lobby.createCustomGame()
end

function lobby.joinCustomGame()
end

function lobby.spectateGame()
end

function lobby.joinRankedQueue()
	client.queue("join")
	print("Joining queue...")
end

function lobby.cancelRankedQueue()
	client.queue("leave")
	print("Leaving queue...")
end

function lobby.goBack()
	if client.queuing then
		client.queue("leave")

		local queue_time = os.time()
		while client.queuing do
			client.update()
			love.timer.sleep(0.1)
			if os.time() - queue_time > 3 then
				print("server problem!")
				client.queuing = false
			end
		end
	end
	
	client.disconnect()
	local disc_time = os.time()
	while client.connected do
		client.update()
		love.timer.sleep(0.1)
		if os.time() - disc_time > 3 then
			print("server problem!")
			client.is_connected = false
		end
	end

	game.current_screen = "title"
end

local locations = {
	ranked_match = {x = stage.width * 0.25, y = stage.height * 0.3},
	create = {x = stage.width * 0.75, y = stage.height * 0.3},
	game_background = {x = stage.x_mid, y = stage.height * 0.7},
	search_ranked = {x = stage.x_mid, y = stage.height * 0.1},
	search_none = {x = stage.x_mid, y = stage.height * 0.1},
	cancel_search = {x = stage.width * 0.75, y = stage.height * 0.1},
	back = {x = stage.width * 0.1, y = stage.height * 0.9},
}

local screen_elements = {
	create = pic:new{x = locations.create.x,
		y = locations.create.y, image = image.lobby.create},
	ranked_match = pic:new{x = locations.ranked_match.x,
		y = locations.ranked_match.y, image = image.lobby.ranked_match},
	game_background = pic:new{x = locations.game_background.x,
		y = locations.game_background.y, image = image.lobby.game_background},
	search_ranked = pic:new{x = locations.search_ranked.x,
		y = locations.search_ranked.y, image = image.lobby.search_ranked},
	search_none = pic:new{x = locations.search_none.x,
		y = locations.search_none.y, image = image.lobby.search_none},
	cancel_search = pic:new{x = locations.cancel_search.x,
		y = locations.cancel_search.y, image = image.lobby.cancel_search},
	back = pic:new{x = locations.back.x,
		y = locations.back.y, image = image.lobby.back},
}
local screen_buttons = {
	{item = screen_elements.create, action = lobby.createCustomGame},
	{item = screen_elements.ranked_match, action = lobby.joinRankedQueue},
	{item = screen_elements.cancel_search, action = lobby.cancelRankedQueue},
	{item = screen_elements.back, action = lobby.goBack},
}


function lobby.handleClick(x, y)
	for i = 1, #screen_buttons do
		if pointIsInRect(x, y, screen_buttons[i].item:getRect()) then
			clicked = screen_buttons[i]
			return
		end
	end
	clicked = false
end

function lobby.handleRelease(x, y)
	for i = 1, #screen_buttons do
		if pointIsInRect(x, y, screen_buttons[i].item:getRect()) and 
		screen_buttons[i] == clicked then
			screen_buttons[i].action()
			break
		end
	end
	clicked = false
end

function lobby.handleMove(x, y)
end

function lobby.getClickedButton(x, y)
	for i = 1, #screen_buttons do
		if pointIsInRect(x, y, screen_buttons[i].item:getRect()) then
			return screen_buttons[i]
		end
	end
	return false
end

function lobby.drawBackground()
	love.graphics.clear()
	Background.Colors.drawImages()
end

function lobby.drawCurrentUsers()
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

function lobby.drawScreenElements()
	love.graphics.clear()
	screen_elements.game_background:draw()
	screen_elements.create:draw()
	screen_elements.ranked_match:draw()
	--screen_elements.search_ranked:draw()
	screen_elements.search_none:draw()
	screen_elements.cancel_search:draw()
	screen_elements.back:draw()
	lobby.drawCurrentUsers()
end

function lobby.update()
	Background.Colors.update()
end

return lobby