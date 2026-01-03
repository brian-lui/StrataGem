--[[
	The multiplayer lobby class. Currently a bit bare
--]]

local love = _G.love
local common = require "class.commons"

local Lobby = {}

-- Disconnect states
local DISCONNECT_NONE = 0
local DISCONNECT_LEAVING_QUEUE = 1
local DISCONNECT_DISCONNECTING = 2

function Lobby:init(game, charselect)
	self.game = game
	self.client = game.client
	self.charselect = charselect
	self.disconnect_state = DISCONNECT_NONE
	self.disconnect_start_time = 0
	self.DISCONNECT_TIMEOUT = 10 -- Bug 11 fix: increased from 3 to 10 seconds for slow/unreliable networks
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

-- Start the non-blocking disconnect process
function Lobby:goBack()
	local client = self.client

	if client.queuing then
		-- Need to leave queue first
		client:queue("leave")
		self.disconnect_state = DISCONNECT_LEAVING_QUEUE
		self.disconnect_start_time = love.timer.getTime()
		print("Leaving queue before disconnect...")
	elseif client.connected then
		-- Go straight to disconnecting
		client:disconnect()
		self.disconnect_state = DISCONNECT_DISCONNECTING
		self.disconnect_start_time = love.timer.getTime()
		print("Disconnecting...")
	else
		-- Already disconnected, just switch state
		self:_finishDisconnect()
	end
end

-- Called each frame to update disconnect progress
function Lobby:updateDisconnect()
	if self.disconnect_state == DISCONNECT_NONE then
		return false -- not disconnecting
	end

	local client = self.client
	local elapsed = love.timer.getTime() - self.disconnect_start_time

	if self.disconnect_state == DISCONNECT_LEAVING_QUEUE then
		if not client.queuing then
			-- Successfully left queue, now disconnect
			client:disconnect()
			self.disconnect_state = DISCONNECT_DISCONNECTING
			self.disconnect_start_time = love.timer.getTime()
			print("Left queue, now disconnecting...")
		elseif elapsed > self.DISCONNECT_TIMEOUT then
			-- Timeout waiting for queue leave
			print("Timeout leaving queue, forcing disconnect")
			client.queuing = false
			client:disconnect()
			self.disconnect_state = DISCONNECT_DISCONNECTING
			self.disconnect_start_time = love.timer.getTime()
		end
	elseif self.disconnect_state == DISCONNECT_DISCONNECTING then
		if not client.connected then
			-- Successfully disconnected
			self:_finishDisconnect()
		elseif elapsed > self.DISCONNECT_TIMEOUT then
			-- Timeout waiting for disconnect
			print("Timeout disconnecting, forcing state change")
			client.connected = false
			self:_finishDisconnect()
		end
	end

	return true -- still disconnecting
end

-- Internal function to complete the disconnect process
function Lobby:_finishDisconnect()
	self.disconnect_state = DISCONNECT_NONE
	self.game:switchState("gs_title")
end

-- Returns true if currently in the process of disconnecting
function Lobby:isDisconnecting()
	return self.disconnect_state ~= DISCONNECT_NONE
end

function Lobby:draw()
end

return common.class("Lobby", Lobby)

