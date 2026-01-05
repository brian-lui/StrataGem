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

local CLIENT_PING_INTERVAL = 15 -- seconds between client pings
local CLIENT_PING_TIMEOUT = 45 -- seconds before considering server dead

function Client:init(game)
	self.game = game
	self.connected = false
	self.port = 49929
	self.host = "192.9.188.147" -- hardlyworkinggames.com
end

function Client:connect()
	-- If already connected, don't create a new connection
	if self.connected then
		print("Already connected to server")
		return
	end

	-- Close any existing socket before creating a new one
	if self.client_socket then
		pcall(function() self.client_socket:close() end)
		self.client_socket = nil
	end

	self:clear()
	self.client_socket = socket.tcp()
	self.client_socket:settimeout(3)

	local success, err = self.client_socket:connect(self.host, self.port)
	if success then
		print("Connected to server, sending user data")
		self.connected = true

		-- Check for immediate server rejection before sending
		-- Server may reject due to rate limit/capacity and close immediately
		self.client_socket:settimeout(0.5)
		local recv_str, recv_err = self.client_socket:receive("*l")
		if recv_str then
			-- Server sent something immediately (likely a rejection)
			local decode_success, recv = pcall(json.decode, recv_str)
			if decode_success and recv and recv.type == "rejected" then
				print("Connection rejected by server: " .. tostring(recv.message))
				if recv.message == "ServerFull" then
					print("Server is at capacity, please try again later")
				elseif recv.message == "RateLimit" then
					print("Too many connection attempts, please wait")
				end
				self.connected = false
				self.client_socket:close()
				return
			end
		elseif recv_err == "closed" then
			-- Server closed connection immediately
			print("Server closed connection immediately (may be at capacity or rate limited)")
			self.connected = false
			return
		end
		-- No immediate rejection, proceed with connect

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
		local current_time = socket.gettime()

		if self.last_server_activity and
		   (current_time - self.last_server_activity > CLIENT_PING_TIMEOUT) then
			print("Server connection timed out (no response for " .. CLIENT_PING_TIMEOUT .. "s)")
			self:disconnect()
			return
		end

		if self.last_client_ping and
		   (current_time - self.last_client_ping > CLIENT_PING_INTERVAL) then
			self:send({type = "ping"})
			self.last_client_ping = current_time
		end

		local recv_str, _, partial_data = self.client_socket:receive("*l")
		if recv_str then -- we got a completed packet now
			self.last_server_activity = current_time

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
			self.last_server_activity = current_time

			-- Check for buffer overflow attack
			if #self.partial_recv + #partial_data > MAX_PARTIAL_RECV_SIZE then
				print("Partial packet buffer overflow, disconnecting")
				self:disconnect()
				return
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
		local bytes_sent, err = self.client_socket:send(blob)
		if not bytes_sent then
			print("OH NOES", err)
			self:disconnect()
		elseif bytes_sent ~= #blob then
			print("Partial send: sent " .. bytes_sent .. " of " .. #blob .. " bytes")
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
	if not recv.side or (recv.side ~= 1 and recv.side ~= 2) then
		print("Invalid start packet: missing or invalid side")
		return
	end
	if not recv.p1_details or not recv.p2_details then
		print("Invalid start packet: missing player details")
		return
	end
	if not recv.p1_details.character or not recv.p2_details.character then
		print("Invalid start packet: missing character selection")
		return
	end
	if not recv.seed or type(recv.seed) ~= "number" then
		print("Invalid start packet: missing or invalid seed")
		return
	end

	local p1_details, p2_details = recv.p1_details, recv.p2_details
	local p1_char, p2_char = p1_details.character, p2_details.character
	local background = recv.side == 1 and p1_details.background or p2_details.background

	self.queuing = false
	self.playing = true

	self.game:start{
		gametype = "Netplay",
		char1 = p1_char,
		char2 = p2_char,
		playername1 = recv.p1_name or "Player 1",
		playername2 = recv.p2_name or "Player 2",
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
		print(" Server " .. tostring(recv.version) .. ", client " .. self.game.VERSION)
	elseif recv.message == "MissingVersion" then
		print("Connection rejected: client did not send version info")
		print("This may indicate a bug in the client")
	elseif recv.message == "Nope" then
		print("You were already connected")
	elseif recv.message == "InvalidName" then
		print("Connection rejected: invalid or missing player name")
	elseif recv.message == "ServerFull" then
		print("Connection rejected: server is at capacity, please try again later")
	elseif recv.message == "RateLimit" then
		print("Connection rejected: too many connection attempts, please wait")
	else
		print("Connection rejected: " .. tostring(recv.message))
	end
	-- Server closes connection after rejection, so mark as disconnected
	self.connected = false
	self:clear()
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

	-- If we're still in an active match, mark opponent as left but let the game
	-- finish naturally so we can see the game over animation
	if self.playing then
		print("Opponent left during active match, continuing to game over")
		self.playing = false
		self.opponent_left = true
		-- Don't clear or switch state - let the game detect the loser and show game over
		return
	end

	-- Not in active match, just clean up and return to menu
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
	elseif recv.action == "invalid_details" then
		print("Failed to join queue: invalid queue details")
		if recv.message then
			print("  Reason: " .. recv.message)
		end
	else
		print("Invalid queue response")
	end
end

local UNCONFIRMED_TURN_THRESHOLD = 2

-- call this when initializing client.lua, ending a match, or disconnecting
function Client:clear()
	self.partial_recv = ""
	self.playing = false -- this is overwritten in startMatch
	self.queuing = false
	self.opponent_left = false -- flag set when opponent leaves during active match

	self.our_delta = "N_"
	self.their_delta = nil
	self.pending_their_delta = nil -- delta received before we were ready
	self.delta_confirmed = false
	self.state_confirmed = false
	self.our_state = nil
	self.their_state = nil
	self.synced = true

	self.our_delta_seq = 0      -- sequence number we send
	self.our_state_seq = 0      -- sequence number we send
	self.their_delta_seq = -1   -- last received delta sequence (-1 = none received)
	self.their_state_seq = -1   -- last received state sequence (-1 = none received)

	self.delta_sent = false
	self.state_sent = false

	self.unconfirmed_delta_count = 0
	self.unconfirmed_state_count = 0

	local current_time = socket.gettime()
	self.last_server_activity = current_time
	self.last_client_ping = current_time
end

-- At new turn, clear the flags for having sent and received state information
-- Returns false if too many consecutive unconfirmed turns (caller should handle disconnect)
function Client:newTurn()
	if not self.delta_confirmed then
		self.unconfirmed_delta_count = self.unconfirmed_delta_count + 1
		print("Warning: Opponent didn't confirm delta (" .. self.unconfirmed_delta_count .. " consecutive)")
		if self.unconfirmed_delta_count >= UNCONFIRMED_TURN_THRESHOLD then
			print("Too many unconfirmed deltas, ending match")
			self:sendDesyncNotification()
			self:endMatch()
			return false
		end
	else
		self.unconfirmed_delta_count = 0
	end

	if not self.state_confirmed then
		self.unconfirmed_state_count = self.unconfirmed_state_count + 1
		print("Warning: Opponent didn't confirm state (" .. self.unconfirmed_state_count .. " consecutive)")
		if self.unconfirmed_state_count >= UNCONFIRMED_TURN_THRESHOLD then
			print("Too many unconfirmed states, ending match")
			self:sendDesyncNotification()
			self:endMatch()
			return false
		end
	else
		self.unconfirmed_state_count = 0
	end

	self.our_delta = "N_"
	self.their_delta = nil
	self.pending_their_delta = nil
	self.delta_confirmed = false
	self.state_confirmed = false
	self.our_state = nil
	self.their_state = nil
	self.synced = false

	self.our_delta_seq = self.our_delta_seq + 1
	self.our_state_seq = self.our_state_seq + 1

	self.delta_sent = false
	self.state_sent = false

	return true
end

function Client:endMatch()
	self:send({type = "end_match"})
	self:clear()
end

-- Notify opponent that a desync was detected before ending match
function Client:sendDesyncNotification()
	if self.connected then
		self:send({type = "end_match", reason = "desync"})
	end
end

-- queue up for a match
function Client:queue(action, queue_details)
	self:send{type = "queue", action = action, queue_details = queue_details}
end

local SOCKET_CLOSE_MAX_RETRIES = 3
local SOCKET_CLOSE_RETRY_DELAY = 0.1 -- seconds

-- user-initiated disconnect from server
function Client:disconnect()
	if self.connected then
		-- Try to notify server of disconnect (may fail if connection already broken)
		local success, err = pcall(function()
			self.client_socket:send(json.encode({type = "disconnect"}) .. "\n")
		end)
		if not success then
			print("Failed to send disconnect notification: " .. tostring(err))
		end
		local close_success = false
		for attempt = 1, SOCKET_CLOSE_MAX_RETRIES do
			local ok, close_err = pcall(function() self.client_socket:close() end)
			if ok then
				close_success = true
				break
			else
				print("Socket close failed (attempt " .. attempt .. "/" .. SOCKET_CLOSE_MAX_RETRIES .. "): " .. tostring(close_err))
				if attempt < SOCKET_CLOSE_MAX_RETRIES then
					-- Brief delay before retry
					local socket = require "socket"
					socket.sleep(SOCKET_CLOSE_RETRY_DELAY)
				end
			end
		end
		if not close_success then
			print("Warning: Socket close failed after " .. SOCKET_CLOSE_MAX_RETRIES .. " attempts, may have ghost connection on server")
		end
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

	self.delta_sent = true
	self:send{type = "delta", serial = self.our_delta, seq = self.our_delta_seq}
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

	-- Validate the delta data
	if not recv.serial or type(recv.serial) ~= "string" then
		print("Warning: Received invalid delta data")
		return
	end

	-- Check for duplicate packets using sequence number
	local recv_seq = recv.seq
	if recv_seq ~= nil then
		if type(recv_seq) ~= "number" then
			print("Warning: Received delta with invalid sequence type")
			return
		end
		if recv_seq < self.their_delta_seq then
			-- Truly old packet, ignore completely
			print("Ignoring old delta packet (seq " .. recv_seq .. " < " .. self.their_delta_seq .. ")")
			return
		elseif recv_seq == self.their_delta_seq then
			-- Same sequence as already processed - this is a resend because our confirmation was lost
			-- Re-send the confirmation if we're in a valid phase and have already processed their delta
			if self.their_delta and VALID_DELTA_PHASES[current_phase] then
				print("Re-sending delta confirmation for seq " .. recv_seq .. " (resend detected)")
				self:send{type = "confirmed_delta", delta = recv.serial}
			end
			return
		end
		self.their_delta_seq = recv_seq
	end

	-- If we're in a valid phase, process immediately
	if VALID_DELTA_PHASES[current_phase] then
		print("received serial: " .. recv.serial)
		self.their_delta = recv.serial
	else
		-- Queue it for later - opponent sent their delta before we were ready
		print("Received delta in phase " .. current_phase .. ", queuing for later")
		self.pending_their_delta = recv.serial
	end
end

-- Check if there's a pending delta and process it (called when entering valid phase)
-- Uses local variable to ensure atomic check-and-clear operation
function Client:checkPendingDelta()
	local pending = self.pending_their_delta
	if pending and not self.their_delta then
		-- Clear pending first to prevent double-processing
		self.pending_their_delta = nil
		print("Processing queued delta: " .. pending)
		self.their_delta = pending
		return true
	end
	return false
end

-- Only send the delta confirm during the WaitForDelta phase, to get lockstep
function Client:sendDeltaConfirmation()
	if self.game.current_phase ~= "NetplayWaitForDelta" then
		print("Phase desync detected in sendDeltaConfirmation: " .. self.game.current_phase)
		self:sendDesyncNotification()
		self:endMatch()
		self.game:switchState("gs_multiplayerselect")
		return
	end
	self:send{type = "confirmed_delta", delta = self.their_delta}
end

-- Called when we confirm that they received our delta.
-- Can be activated anytime after sending delta.
-- TODO: Better error handling - can request another delta instead of throwing exception
function Client:receiveDeltaConfirmation(recv)
	if not self.delta_sent then
		print("Warning: Received delta confirmation before sending delta, ignoring")
		return
	end

	-- Validate recv.delta exists before comparison
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

	self.state_sent = true
	self:send{type = "state", serial = self.our_state, seq = self.our_state_seq}
end

-- Called when we receive a state from opponent.
function Client:receiveState(recv)
	-- Validate recv.serial exists before use
	if not recv.serial or type(recv.serial) ~= "string" then
		print("Warning: Received invalid state data")
		return
	end

	-- Check for duplicate packets using sequence number
	local recv_seq = recv.seq
	if recv_seq ~= nil then
		if type(recv_seq) ~= "number" then
			print("Warning: Received state with invalid sequence type")
			return
		end
		if recv_seq < self.their_state_seq then
			-- Truly old packet, ignore completely
			print("Ignoring old state packet (seq " .. recv_seq .. " < " .. self.their_state_seq .. ")")
			return
		elseif recv_seq == self.their_state_seq then
			-- Same sequence as already processed - this is a resend because our confirmation was lost
			-- Re-send the confirmation if we have already processed their state
			if self.their_state then
				print("Re-sending state confirmation for seq " .. recv_seq .. " (resend detected)")
				self:send{type = "confirmed_state", state = recv.serial}
			end
			return
		end
		self.their_state_seq = recv_seq
	end

	print("received serial: " .. recv.serial)
	print("phase in which state was received: " .. self.game.current_phase)
	self.their_state = recv.serial
end

-- TODO: think about when it's allowable to send the confirmation. End of turn?
function Client:sendStateConfirmation()
	if not self.connected then
		print("Warning: Cannot send state confirmation, not connected")
		return
	end
	if self.game.current_phase ~= "NetplayWaitForState" then
		print("Warning: Sending state in wrong phase " .. self.game.current_phase)
		return
	end
	self:send{type = "confirmed_state", state = self.their_state}
end

function Client:receiveStateConfirmation(recv)
	if not self.state_sent then
		print("Warning: Received state confirmation before sending state, ignoring")
		return
	end

	-- Validate recv.state exists before comparison
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
	if not recv or type(recv) ~= "table" then
		print("Warning: Received invalid data (not a table)")
		return
	end
	if not recv.type then
		print("Warning: Received data without type field")
		return
	end
	if self.lookup[recv.type] then
		self.lookup[recv.type](self, recv)
	else
		print("Invalid data type received from server: " .. tostring(recv.type))
	end
end

return common.class("Client", Client)
