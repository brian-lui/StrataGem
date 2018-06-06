local love = _G.love
local socket = require 'socket'
local json = require 'dkjson'
local settings = require 'settings'
local common = require "class.commons"

local Client = {}

function Client:init(game)
	self.game = game
	self.connected = false
	self.port = 49929
	--client.host = "64.137.189.132" -- sharpo
	self.host = "85.234.133.240" -- thelo
	--client.host = "127.0.0.1" -- local
end

function Client:connect()
	self:clear()
	self.client_socket = socket.tcp()
	self.client_socket:settimeout(3)

	local success, err = self.client_socket:connect(self.host, self.port)
	if success then
		print("Connected to server, sending user data")
		self.connected = true
		self.client_socket:settimeout(0)
		local blob = {type = "connect", version = self.game.VERSION, name = settings.player.name}
		self:send(blob)
	else
		print("Server not found lol. Error code:")
		print(err)
	end
end

function Client:update()
	if self.connected then
		local recv_str, _, partial_data = self.client_socket:receive("*l")
		if recv_str then -- we got a completed packet now
			recv_str = self.partial_recv .. recv_str
			self.partial_recv = ""
			local recv = json.decode(recv_str)
			self:processData(recv)
		elseif partial_data and partial_data ~= "" then -- still incomplete packet.
			self.partial_recv = self.partial_recv .. partial_data
			print("received partial data:" .. partial_data .. ".")
		end
	end
end

-- general send function
function Client:send(data)
	if self.connected then
		local blob = json.encode(data) .. "\n" -- we are using *l receive mode
		local success, err = self.client_socket:send(blob)
		if not success then
			print("OH NOES", err)
			self:disconnect()
		end
	else
		print("ur not connected")
	end
end

-------------------------------------------------------------------------------
-----------------------------------HELPERS-------------------------------------
-------------------------------------------------------------------------------

function Client:startMatch(recv)
	assert(recv.side == 1 or recv.side == 2, "oh craps")
	self.match_start_time = love.timer.getTime()

	local p1_details, p2_details = recv.p1_details, recv.p2_details
	local p1_char, p2_char = p1_details.character, p2_details.character
	local p1_background, p2_background = p1_details.background, p2_details.background

	self.queuing = false
	self.playing = true

	self.game:start("Netplay", p1_char, p2_char, p2_background, recv.seed, recv.side)
end

function Client:connectionAccepted(recv)
	print("User data accepted")
end

function Client:connectionRejected(recv)
	if recv.message == "Version" then
		print("Incorrect version, please update. Server " .. recv.version .. ", client " .. self.game.version)
	elseif recv.message == "Nope" then
		print("You were already connected")
	else
		print("Unknown rejection reason lol")
	end
end

function Client:receiveDisconnect()
	print("Disconnected by server")
	self:disconnect()
end

function Client:receivePing()
	self:send({type = "ping"})
end

function Client:receiveDudes(recv)
	local updateUsers = self.game.statemanager:current().updateUsers
	if updateUsers then
		updateUsers(self.game, recv.all_dudes)
	end
end

function Client:receiveQueue(recv)
	if recv.action == "already_queued" then
		print("Already queued, didn't join again")
	elseif recv.action == "not_queued" then
		print("Not queued, didn't leave")
	elseif recv.action == "queued" then
		print("Joined queue")
		self.queuing = true
	elseif recv.action == "left" then
		print("Left queue")
		self.queuing = false
	else
		print("Invalid queue response")
	end
end

-- call this when initializing client.lua, ending a match, or disconnecting
function Client:clear()
	self.match_start_time = love.timer.getTime()
	self.partial_recv = ""
	self.playing = false -- this is overwritten in startMatch
	self.queuing = false

	self.our_delta = "N_"
	self.their_delta = nil
	self.delta_confirmed = false
	self.state_confirmed = false
	self.our_state = nil
	self.their_state = nil
	self.synced = true
end

-- On a new turn, clear the flags for having sent and received state information
function Client:newTurn()
	assert(self.delta_confirmed, "Opponent didn't confirm delta by end of turn!")

	self.our_delta = "N_"
	self.their_delta = nil
	self.delta_confirmed = false
	self.state_confirmed = false
	self.our_state = nil
	self.their_state = nil
	self.synced = false
end

function Client:endMatch()
	self:send({type = "end_match"})
	self:clear()
end

-- queue up for a match
-- TODO: This needs to ask the matchmaker and not the peer.
function Client:queue(action, queue_details)
	self:send{type = "queue", action = action, queue_details = queue_details}
end

-- user-initiated disconnect from server
function Client:disconnect()
	if self.connected then
		self.client_socket:send(json.encode({type = "disconnect"}))
		pcall(function() self.client_socket:close() end)
	else
		print("Cannot disconnect, you weren't connected")
	end
	self.connected = false
	self:clear()
end

-------------------------------------------------------------------------------
------------------------------------DELTA--------------------------------------
-------------------------------------------------------------------------------

--[[
our_delta: Current turn's delta. Caleld from ai_net:performDeltas as their_delta.

Actions can be:
	1) Play first piece
	2) Play second piece (doublecast)
	3) Play super + super parameters. Mutually exclusive with 1/2
Encoding:
	0) Default string is "N_", for no action.
	1) Pc1_ID[piece hand position]_[piece rotation index]_[first gem column]_
		e.g. Pc1_60_3_3_
	2) Same as above, e.g. Pc2_60_2_3_
	3) S_[parameters]_
		e.g. S__, S_58390496405_
	Concatenate to get final string, e.g.:
		Pc1_59_3_2_Pc2_60_1_3_
		Pc1_59_3_2_
		S__
		N_ (no action)
--]]

-- Write the delta when player plays a piece, by modifying self.our_delta.
-- Called immediately upon playing a piece, from Piece:dropIntoBasin.
function Client:writeDeltaPiece(piece, coords)
	local delta = self.our_delta
	assert(delta:sub(1, 2) ~= "S_", "Received delta, but player is supering")
	local pos = piece.hand_idx
	local rotation = piece.rotation_index
	local column = coords[1]
	local pc
	if delta == "N_" then -- no piece played yet
		pc = "Pc1"
	elseif delta:sub(1, 3) == "Pc1" then
		pc = "Pc2"
	else
		error("Unexpected delta found: ", delta)
	end

	local serial = pc .. "_" .. pos .. "_" .. rotation .. "_" .. column .. "_"

	if delta == "N_" then
		self.our_delta = serial
	elseif delta:sub(1, 3) == "Pc1" then
		self.our_delta = delta .. serial
	else
		error("Unexpected delta found: ", delta)
	end
	print("delta serial is now " .. self.our_delta)
end

-- Writes the super when player activates super, by modifying self.our_delta.
-- Called at end of turn, from Phase:action.
function Client:writeDeltaSuper()
	local player = self.game.me_player
	assert(player.supering, "Received super instruction, but player not supering")
	assert(self.our_delta == "N_", "Received super instruction, but player has action")
	local serial = player:serializeSuperDeltaParams()

	self.our_delta = "S_" .. serial .. "_"
end

-- Called after turn ends, from Phase:netplaySendDelta.
function Client:sendDelta()
	assert(self.connected, "Not connected to opponent")
	assert(type(self.our_delta) == "string", "Tried to send non-string delta")

	self:send{type = "delta", serial = self.our_delta}
end

-- Called when we receive a delta from opponent.
-- Should be activated from Phase:netplayWaitForDelta.
function Client:receiveDelta(recv)
	local current_phase = self.game.current_phase
	assert(current_phase == "NetplayWaitForDelta" or current_phase == "Action" or
		current_phase == "NetplaySendDelta",
		"Received delta in wrong phase " .. current_phase .. "!")
	print("received serial: " .. recv.serial)
	self.their_delta = recv.serial
end

-- Only send the delta confirm during the WaitForDelta phase, to get lockstep
function Client:sendDeltaConfirmation()
	assert(self.game.current_phase == "NetplayWaitForDelta",
		"Sending delta in wrong phase " .. self.game.current_phase .. "!")
	self:send{type = "confirmed_delta", delta = self.their_delta}
end

-- Called when we confirm that they received our delta.
-- Can be activated anytime after sending delta.
-- TODO: Better error handling - can request another delta instead of throwing exception
function Client:receiveDeltaConfirmation(recv)
	--[[
	assert(self.game.current_phase == "NetplayWaitForConfirmation",
		"Received delta confirmation in wrong phase " .. self.game.current_phase .. "!")
	--]]
	assert(self.our_delta == recv.delta, "Received delta confirmation doesn't match!")
	self.delta_confirmed = true
end

-- Called at the sync phase, after cleanup.
function Client:writeState()
	self.our_state = self.game:serializeState()
end

-- Called right before waiting for sync phase.
function Client:sendState()
	assert(self.connected, "Not connected to opponent")
	assert(type(self.our_state) == "string", "Tried to send non-string state")

	self:send{type = "state", serial = self.our_state}
end

-- Called when we receive a state from opponent.
function Client:receiveState(recv)
	print("received serial: " .. recv.serial)
	print("phase in which state was received: " .. self.game.current_phase)
	self.their_state = recv.serial
end

-- TODO: think about when it's allowable to send the confirmation. End of turn?
function Client:sendStateConfirmation()
	assert(self.game.current_phase == "NetplayWaitForState",
		"Sending state in wrong phase " .. self.game.current_phase .. "!")
	self:send{type = "confirmed_state", state = self.their_state}
end

function Client:receiveStateConfirmation(recv)
	--[[
	assert(self.game.current_phase == "NetplayWaitForConfirmation",
		"Received state confirmation in wrong phase " .. self.game.current_phase .. "!")
	--]]
	assert(self.our_state == recv.state, "Received state confirmation doesn't match!")
	self.state_confirmed = true
end

-------------------------------------------------------------------------------
Client.lookup = {
	connected = Client.connectionAccepted,
	rejected = Client.connectionRejected,
	disconnected = Client.receiveDisconnect,
	start = Client.startMatch,
	delta = Client.receiveDelta,
	confirmed_delta = Client.receiveDeltaConfirmation,
	state = Client.receiveState,
	confirmed_state = Client.receiveStateConfirmation,
	ping = Client.receivePing,
	current_dudes = Client.receiveDudes,
	queue = Client.receiveQueue,
}

-- select/case function
function Client:processData(recv)
	if self.lookup[recv.type] then
		self.lookup[recv.type](self, recv)
	else
		print("Invalid data type received from server")
	end
end

return common.class("Client", Client)
