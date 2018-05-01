local love = _G.love
local socket = require 'socket'
local json = require 'dkjson'
local settings = require 'settings'
local common = require "class.commons"

local Client = {}

-- call this when starting a new match
function Client:clear()
	self.match_start_time = love.timer.getTime()
	self.partial_recv = ""
	--self.our_delta = {}
	self.our_delta = "N_"
	self.their_delta = {}
	self.delta_confirmed = false
	self.our_state = {}
	self.their_state = {}
	self.synced = true
	self.sent_state = true
	self.playing = false
	self.queuing = false
	self.received_state = true
	self.opponent_received_state = true
end

function Client:init(game)
	self.game = game
	self.connected = false
	self.port = 49929
	--client.host = "64.137.189.132" -- sharpo
	self.host = "85.234.133.240" -- thelo
	--client.host = "127.0.0.1" -- local
	self:clear()
	self.client_socket = socket.tcp()
	self.client_socket:settimeout(3)
end

function Client:connect()
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

--[[
our_delta: Current turn's delta. Caleld from ai_net:performDeltas as their_delta.

Actions can be:
	1) Play first piece
	2) Play second piece (doublecast)
	3) Play super + super parameters. Mutually exclusive with 1/2
Encoding:
	0) Default string is "N_", for no action.
	1) Pc1_ID[piece ID]_[piece rotation index]_[first gem column]_
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

-- Write the delta when player plays a piece.
-- Called immediately upon playing a piece, from Piece:dropIntoBasin.
function Client:_writeDeltaPiece(piece, coords)
	local delta = self.our_delta
	local id = piece.ID
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

	local serial = pc .. "_" .. id .. "_" .. rotation .. "_" .. column .. "_"

	if delta == "N_" then
		self.our_delta = serial
	elseif delta:sub(1, 3) == "Pc1" then
		self.our_delta = delta .. serial
	else
		error("Unexpected delta found: ", delta)
	end
end

-- Writes the super when player activates super.
-- Called at end of turn, from Phase:action.
function Client:_writeDeltaSuper()
	local player = self.game.me_player
	assert(player.supering, "Received super instruction, but player not supering")
	assert(self.our_delta == "N_", "Received super instruction, but player has action")
	local serial = player:serializeSuperDeltaParams()

	self.our_delta = "S_" .. serial .. "_"
end

-- Called after turn ends, from Phase:netplaySendDelta.
function Client:_newSendDelta()
	assert(self.connected, "Not connected to opponent")
	assert(type(self.our_delta) == "string", "Tried to send non-string delta")

	self:send{type = "delta", serial = self.our_delta}
end

-- Called when we receive a delta from opponent.
-- Should be activated from Phase:netplayWaitForDelta.
function Client:_newReceiveDelta(recv)
	assert(self.game.current_phase == "NetplayWaitForDelta",
		"Received delta in wrong phase " .. self.game.current_phase .. "!")
	local serial = recv.serial
	print("received serial: " .. serial)

	self.their_delta = serial
	self:send{type = "confirmed_delta", delta = serial} -- send confirmation
end

-- Called when we confirm that they received our delta
-- Should be activated from Phase:netplayWaitForConfirmation.
-- TODO: Better error handling - can request another delta instead of throwing exception
function Client:_newReceiveDeltaConfirmation(recv)
	assert(self.game.current_phase == "NetplayWaitForConfirmation",
		"Received delta in wrong phase " .. self.game.current_phase .. "!")
	assert(self.our_delta == recv.serial, "Received delta confirmation doesn't match!")

	self.delta_confirmed = true
end


--[[
our_state: This is the current turn's state.
----------------------------------------
State information:
	1) P1 burst, P1 super
	2) P2 burst, P2 super
	3) Grid gems
	4) Player 1 pieces
	5) Player 2 pieces
	6) P1 other special info
	7) P2 other special info
	Note: special items must belong to a player, even if they are "neutral".
Encoding:
	1) P1B[burst meter]S[super]_
		e.g. P1B4S35_
	2) P2B[burst meter]S[super]_
		e.g. P2B5S23_
	3) 64 byte string, 8 rows, from top left across to bottom right. [color] or 0_
		e.g. 000000000000000000000000000000000000000000000000RRYBG000RYRBGGYB_
	4) P1H1[color][color][ID]_ .. P1H5_
		e.g. P1H1RY29_P1H2YY30_P1H3_P1H4_P1H5_
	5) P2H1[color][color][ID]_ .. P2H5_
		e.g. P2H1RY31_P2H2YY32_P2H3GG33_P2H4_P2H5_
	6) P1SPEC_[tbc]_
		e.g. SPEC__ to denote location of Heath fires
	7) P2SPEC_[tbc]_
		e.g. SPEC__ to denote column/remaining turns of Walter clouds
Concatenate to get final string


prepareState: Called from two places:
----------------------------------------
	Called at the end of resolution phase.

sendState
---------
	Called right after the prepareState. Sends the [our_state] to opponent.

[Opponent] receiveState
-----------------------
	Receive the state and compare it with prepareState.
	If they are different:
		Throw an exception. This is probably unrecoverable - we should focus on syncing deltas.
--]]



-- On a new turn, clear the flags for having sent and received state information
function Client:newTurn()
	self.sent_state = false
	self.received_state = false
	self.opponent_received_state = false
	self.synced = false
	self.our_delta = "N_"
	print("Starting next turn on frame: " .. self.game.frame, "Time: " .. love.timer.getTime() - self.match_start_time)
	print("Expecting resolution on frame: " .. self.game.frame + self.game.phase.INIT_TIME_TO_NEXT)
end

function Client:endMatch()
	self:send({type = "end_match"})
	self:clear()
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

-- confirm to the other guy that we received his state
local function sendStateConfirmation(self, fail)
	self:send({type = "confirmed_state", turn = self.game.turn, success = not fail})
end


-- the other guy confirmed that he received our state
local function receiveStateConfirmation(self, recv)
	if recv.success then
		--print("Frame: " .. frame, "Time: " .. love.timer.getTime() - client.match_start_time, "Received successful state confirmation")
		self.opponent_received_state = true
	else
		--print("Frame: " .. frame, "Time: " .. love.timer.getTime() - client.match_start_time, "Received failed state confirmation")
		-- HACK: better handling
		self.opponent_received_state = true
	end
end

-- we got a state from them, let's handle it!
local function receiveState(self, recv)
	local fail = false
	print("Frame: " .. self.game.frame, "Time: " .. love.timer.getTime() - self.match_start_time, "Received state")
	if recv.turn ~= self.game.turn then
		print("Received state for wrong turn! Expected: " .. self.game.turn .. ", received: " .. recv.turn)
		fail = true
		-- TODO: better handling
	end
	self.their_state[recv.turn] = recv
	self.received_state = true
	sendStateConfirmation(self, fail)
end

local function startMatch(self, recv)
	assert(recv.side == 1 or recv.side == 2, "oh craps")
	self.match_start_time = love.timer.getTime()

	local p1_details, p2_details = recv.p1_details, recv.p2_details
	local p1_char, p2_char = p1_details.character, p2_details.character
	local p1_background, p2_background = p1_details.background, p2_details.background

	self.queuing = false
	self.playing = true

	self.game:start("Netplay", p1_char, p2_char, p2_background, recv.seed, recv.side)
end

local function connectionAccepted(recv)
	print("User data accepted")
end

local function connectionRejected(self, recv)
	if recv.message == "Version" then
		print("Incorrect version, please update. Server " .. recv.version .. ", client " .. self.game.version)
	elseif recv.message == "Nope" then
		print("You were already connected")
	else
		print("Unknown rejection reason lol")
	end
end

local function receiveDisconnect(self)
	print("Disconnected by server")
	self:disconnect()
end

local function receivePing(self)
	self:send({type = "ping"})
end

local function receiveDudes(self, recv)
	local updateUsers = self.game.statemanager:current().updateUsers
	if updateUsers then
		updateUsers(self.game, recv.all_dudes)
	end
end

local function receiveQueue(self, recv)
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

--[[ Returns a string describing the current gamestate.
First 64 characters are the gems in the basin, going across, from top row to bottom row.
Next 10 characters are the pieces in player 1 hand, from top to bottom.
Next 10 characters are the pieces in player 2 hand, from top to bottom.
Next characters are the modifiers for p1 and p2, like Heath flames or Walter clouds. I didn't think about this part yet.
--]]
function Client:getGamestateString()
	local game = self.game
	local grid = game.grid
	local ret = {}
	local pos = 1
	-- grid
	for row = grid.BASIN_START_ROW, grid.BASIN_END_ROW do
		for col = 1, grid.COLUMNS do
			if grid[row][col].gem then
				ret[pos] = string.sub(grid[row][col].gem.color:lower(), 1, 1)
			else
				ret[pos] = " "
			end
			pos = pos + 1
		end
	end

	-- hands
	for player in game:players() do
		for i = 1, 5 do
			if player.hand[i].piece then
				local gems = player.hand[i].piece.gems
				if gems[1] then
					ret[pos] = string.sub(gems[1].color:lower(), 1, 1)
				else
					ret[pos] = " "
				end
				if gems[2] then
					ret[pos+1] = string.sub(gems[2].color:lower(), 1, 1)
				else
					ret[pos+1] = " "
				end
			else
				ret[pos] = " "
				ret[pos+1] = " "
			end
			pos = pos + 2
		end
	end

	-- specials/passives

	return table.concat(ret)
end

-- called at start of a new turn. packages the state, and sends it with a delay
function Client:sendState(delay)
	local game = self.game
	local state = {
		type = "state",
		turn = game.turn,
		frame = game.frame,
		grid_gems = game.grid:getIDs(),
		p1_hand = game.p1.hand:getPieceIDs(),
		p1_super = game.p1.mp,
		p1_damage = "TODO",
		p2_hand = game.p2.hand:getPieceIDs(),
		p2_super = game.p2.mp,
		p2_damage = "TODO",
		-- place_type
		-- special ability stuff
		-- checksum
	}
	if game.turn > 1 then
		if game.me_player.ID == "P1" then
			state.p1_prev_place_type = self.our_delta[game.turn - 1].place_type
			state.p2_prev_place_type = self.their_delta[game.turn - 1].place_type
		elseif game.me_player.ID == "P2" then
			state.p1_prev_place_type = self.their_delta[game.turn - 1].place_type
			state.p2_prev_place_type = self.our_delta[game.turn - 1].place_type
		end
	end

	print("Frame: " .. game.frame, "Time: " .. love.timer.getTime() - self.match_start_time, "Saving and sending state")
	self.our_state[game.turn] = state
	self.game.queue:add(delay, self.send, self, state)
end

-- if the states don't match, it's a desync. We don't compare the frame when it was sent though.
function Client:compareStates(us, them)
	us = us or self.our_state[self.game.turn]
	them = them or self.their_state[self.game.turn]

	for k, v in pairs(us) do
		if type(v) == "table" then
			--print("Now recursively comparing k, v, us:", k, v, us)
			if type(them[k]) ~= "table" then return false end
			if not self:compareStates(v, them[k]) then return false end
		elseif them[k] ~= v and k ~= "frame" then
			print("OH NO IT DIDN'T MATCH")
			print("them[k]", them[k])
			print("v (us)", v)
			print("k (us)", k)
			return false
		end
	end
	for k, v in pairs(them) do
		if us[k] == nil then
			print("OH NO IT DIDN'T MATCH: key for us not found,", k, v)
		return false end
	end
	return true
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

Client.lookup = {
	connected = connectionAccepted,
	rejected = connectionRejected,
	disconnected = receiveDisconnect,
	start = startMatch,
	delta = receiveDelta,
	confirmed_delta = receiveDeltaConfirmation,
	state = receiveState,
	confirmed_state = receiveStateConfirmation,
	ping = receivePing,
	current_dudes = receiveDudes,
	queue = receiveQueue,
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
