--[[
	The multiplayer lobby class. Currently a bit bare
--]]

local common = require "class.commons"

local Lobby = {}

function Lobby:init(game, charselect)
	self.game = game
	self.client = game.client
	self.charselect = charselect
end

function Lobby:connect()
	self.client:connect()
end

function Lobby:createCustomGame()
	print("TBD - Create custom game")
end

function Lobby:joinCustomGame()
	print("TBD - Join custom game")
end

function Lobby:spectateGame()
	print("TBD - Spectate game")
end

function Lobby:joinRankedQueue(queue_details)
	self.client:queue("join", queue_details)
	print("Joining queue")
end

function Lobby:cancelRankedQueue()
	self.client:queue("leave")
	print("Leaving queue...")
end

function Lobby:goBack()
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
	self.game:switchState("gs_title")
end

function Lobby:draw()
end

return common.class("Lobby", Lobby)

