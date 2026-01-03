--[[
This module provides the netplay functions, handling connection, disconnection,
finding a match, and sending and receiving deltas and gamestates during a match
--]]

local love = _G.love
local socket = require "socket"
local json = require "/libraries/dkjson"
local common = require "class.commons"

local Client = {}

-- Maximum size for partial packet buffer (64KB)
local MAX_PARTIAL_RECV_SIZE = 65536

function Client:init(game)
	self.game = game
	self.connected = false
	self.port = 49929
	self.host = "165.227.7.122" -- hardlyworkinggames.com
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
		local blob = {
			type = "connect",
			version = self.game.VERSION,
			name = self.game.settings.player.name,
		}
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
			local success, recv = pcall(json.decode, recv_str)
			if success and recv then
				self:processData(recv)
			else
				print("Failed to decode JSON from server: " .. tostring(recv))
				print("Raw data: " .. recv_str:sub(1, 100)) -- log first 100 chars
			end
		elseif partial_data and partial_data ~= "" then -- still incomplete packet.
			-- Check for buffer overflow attack
			if #self.partial_recv + #partial_data > MAX_PARTIAL_RECV_SIZE then
				print("Partial packet buffer overflow, clearing buffer")
				self.partial_recv = ""
			else
				self.partial_recv = self.partial_recv .. partial_data
				print("received partial data:" .. partial_data .. ".")
			end
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
	local background = recv.side == 1 and p1_details.background or p2_details.background

	self.queuing = false
	self.playing = true

	self.game:start{
		gametype = "Netplay",
		char1 = p1_char,
		char2 = p2_char,
		playername1 = recv.p1_name,
		playername2 = recv.p2_name,
		background = background,
		side = recv.side,
		seed = recv.seed,
	}
end

function Client:connectionAccepted(recv)
	print("User data accepted")
end

function Client:connectionRejected(recv)
	if recv.message == "Version" then
		print("Incorrect version, please update.")
		print(" Server " .. recv.version .. ", client " .. self.game.VERSION)
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

function Client:receiveEndMatch(recv)
	print("Match ended by server" .. (recv.reason and (": " .. recv.reason) or ""))
	self:clear()
	if self.game.type == "Netplay" then
		self.game:switchState("gs_multiplayerselect")
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

-- At new turn, clear the flags for having sent and received state information
function Client:newTurn()
	-- Bug 3 fix: Validate both delta and state were confirmed before proceeding
	if not self.delta_confirmed then
		print("Warning: Opponent didn't confirm delta by end of turn")
	end
	if not self.state_confirmed then
		print("Warning: Opponent didn't confirm state by end of turn")
	end

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


-- Called immediately upon playing a piece, from Piece:dropIntoBasin.
function Client:writeDeltaPiece(piece, coords)
	self.our_delta = self.game:serializeDelta(self.our_delta, piece, coords)
end

-- Called at end of turn, from Phase:action.
function Client:writeDeltaSuper()
	self.our_delta = self.game:serializeSuper(self.our_delta)
end

-- Called after turn ends, from Phase:netplaySendDelta.
function Client:sendDelta()
	assert(self.connected, "Not connected to opponent")
	assert(type(self.our_delta) == "string", "Tried to send non-string delta")

	self:send{type = "delta", serial = self.our_delta}
end

-- Valid phases for receiving opponent delta
-- NetplaySendDelta: We just sent ours, opponent may be faster
-- NetplayWaitForDelta: This is the expected phase for receiving delta
local VALID_DELTA_PHASES = {
	NetplaySendDelta = true,
	NetplayWaitForDelta = true,
}

-- Called when we receive a delta from opponent.
-- Should be activated from Phase:netplayWaitForDelta.
function Client:receiveDelta(recv)
	local current_phase = self.game.current_phase

	-- Validate we're in a phase that can accept delta
	if not VALID_DELTA_PHASES[current_phase] then
		print("Warning: Received delta in unexpected phase " .. current_phase .. ", ignoring")
		return
	end

	-- Validate the delta data
	if not recv.serial or type(recv.serial) ~= "string" then
		print("Warning: Received invalid delta data")
		return
	end

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
	-- Bug 2 fix: Validate recv.delta exists before comparison
	if not recv.delta or type(recv.delta) ~= "string" then
		print("Warning: Received invalid delta confirmation data")
		return
	end
	if self.our_delta ~= recv.delta then
		print("Warning: Received delta confirmation doesn't match!")
		print("  our_delta: " .. tostring(self.our_delta))
		print("  recv.delta: " .. tostring(recv.delta))
		return
	end
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
	-- Bug 1 fix: Validate recv.state exists before comparison
	if not recv.state or type(recv.state) ~= "string" then
		print("Warning: Received invalid state confirmation data")
		return
	end
	if self.our_state ~= recv.state then
		print("Warning: Received state confirmation doesn't match!")
		print("  our_state length: " .. (self.our_state and #self.our_state or "nil"))
		print("  recv.state length: " .. #recv.state)
		return
	end
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
	end_match = Client.receiveEndMatch,
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
