require 'socket'
local json = require 'dkjson'
local inspect = require 'inspect'
local character = require 'character' -- temp
local settings = require 'settings'
local hand = require 'hand'

client = {}
local client_socket = socket.tcp()
client_socket:settimeout(3)

-- call this when starting a new match
function client.clear()
	client.match_start_time = love.timer.getTime()
	client.partial_recv = ""
	client.our_delta = {}
	client.their_delta = {}
	client.our_state = {}
	client.their_state = {}
	client.synced = true
	client.received_delta = {} -- we received delta from opponent
	client.opponent_received_delta = {} -- they received our delta
	client.sent_state = true
	client.playing = false
	client.queuing = false
	client.received_state = true
	client.opponent_received_state = true
	client.giving_frameback = 0
end

local function initializeClient()
	client.connected = false
	client.port = 49929
	--client.host = "64.137.189.132" -- sharpo
	client.host = "85.234.133.240" -- thelo
	--client.host = "127.0.0.1" -- local
	client.clear()
	client_socket = socket.tcp()
	client_socket:settimeout(3)
end
initializeClient()

function client.connect()
	local success, err = client_socket:connect(client.host, client.port)
	if success then
		print("Connected to server, sending user data")
		client.connected = true
		client_socket:settimeout(0)
		local blob = {type = "connect", version = game.VERSION, name = settings.player.name}
		client.send(blob)
	else
		print("Server not found lol. Error code:")
		print(err)
	end
end

function client.update()
	if client.connected then
        local recv_str, _, partial_data = client_socket:receive("*l")
        if recv_str then -- we got a completed packet now
            recv_str = client.partial_recv .. recv_str
            client.partial_recv = ""
            local recv = json.decode(recv_str)
            client:processData(recv)
        elseif partial_data and partial_data ~= "" then -- still incomplete packet. how come we have to test for null string
            client.partial_recv = client.partial_recv .. partial_data
            print("received partial data:" .. partial_data .. ".")
        end

        -- lag adjustment during game
        if client.giving_frameback > 0 then
        	time.bucket = time.bucket + (0.5 * time.step)
        	client.giving_frameback = math.max(client.giving_frameback - 0.5, 0)
        end
    end
end

-- On a new turn, clear the flags for having sent and received state information
function client:newTurn()
	self.sent_state = false
	self.received_state = false
	self.opponent_received_state = false
	self.synced = false
	print("Starting next turn on frame: " .. frame, "Time: " .. love.timer.getTime() - client.match_start_time)
	print("Expecting resolution on frame: " .. frame + game.INIT_TIME_TO_NEXT)
end

function client:endMatch()
	client.send({type = "end_match"})
	client.clear()
end

-- general send function
function client.send(data)
	if client.connected then
		local blob = json.encode(data) .. "\n" -- we are using *l receive mode
		local success, err = client_socket:send(blob)
		if not success then
			print("OH NOES", err)
			client.disconnect()
		end
	else
		print("ur not connected")
	end
end

-- confirm to the other guy that we received his delta
local function sendDeltaConfirmation(fail)
	if not fail then
		client.send({type = "confirmed_delta", turn = game.turn, success = true})
		--print("Frame: " .. frame, "Time: " .. love.timer.getTime() - client.match_start_time, "sent successful Delta Confirmation")
	else
		client.send({type = "confirmed_delta", turn = game.turn, success = false})
		--print("Frame: " .. frame, "Time: " .. love.timer.getTime() - client.match_start_time, "sent failed Delta Confirmation")
	end
end

-- confirm to the other guy that we received his state
local function sendStateConfirmation(fail)
	if not fail then
		client.send({type = "confirmed_state", turn = game.turn, success = true})
		--print("Frame: " .. frame, "Time: " .. love.timer.getTime() - client.match_start_time, "sent successful State Confirmation")
	else
		client.send({type = "confirmed_state", turn = game.turn, success = false})
		--print("Frame: " .. frame, "Time: " .. love.timer.getTime() - client.match_start_time, "sent failed State Confirmation")
	end
end

-- the other guy confirmed that he received our delta
local function receiveDeltaConfirmation(recv)
	if recv.success then
		--print("Frame: " .. frame, "Time: " .. love.timer.getTime() - client.match_start_time, "Received successful delta confirmation")
		client.opponent_received_delta[recv.turn] = true
	else
		--print("Frame: " .. frame, "Time: " .. love.timer.getTime() - client.match_start_time, "Received failed delta confirmation")
		-- TODO: better handling
	end
end

-- the other guy confirmed that he received our state
local function receiveStateConfirmation(recv)
	if recv.success then
		--print("Frame: " .. frame, "Time: " .. love.timer.getTime() - client.match_start_time, "Received successful state confirmation")
		client.opponent_received_state = true
	else
		--print("Frame: " .. frame, "Time: " .. love.timer.getTime() - client.match_start_time, "Received failed state confirmation")
		-- TODO: better handling
		client.opponent_received_state = true
	end
end

-- looks up the piece locally so we don't need to netsend the entire piece info
local function getPieceFromID(ID, player)
	for i = 1, player.hand_size do
		if player.hand[i].piece then
			if player.hand[i].piece.ID == ID then
				return player.hand[i].piece
			end
		end
	end
end

-- play the delta-piece when it's time
local function playPiece(recv_piece)
	local opp_piece = getPieceFromID(recv_piece.piece_ID, game.them_player)
	for i = 1, recv_piece.rotation do opp_piece:rotate() end
	game.them_player.place_type = recv_piece.place_type
	if game.them_player.place_type == nil then
		print("place_type is nil, exiting")
		game.phase = "GameOver"
	end
	print("current place type for playing their piece:", game.them_player.place_type)
	opp_piece:dropIntoBasin(recv_piece.coords, true)
end

-- called at end of turn, plays all deltas received from opponent
function client.playTurn(delta, turn_to_play)
	local play = delta[turn_to_play]
	if next(play.super) then
		-- blah blah
	end
	if next(play.piece1) then playPiece(play.piece1) end
	if next(play.piece2) then playPiece(play.piece2) end
	-- place_type will be set to double if piece2 exists, since it takes the last place_type
end

-- we got a delta from them, let's handle it!
local function receiveDelta(recv)
	local fail = false
	print("Frame: " .. frame, "Time: " .. love.timer.getTime() - client.match_start_time, "Receiving delta")
	client.their_delta[recv.turn] = recv
	client.received_delta[recv.turn] = true
	sendDeltaConfirmation(fail)

	if recv.blank then -- received their blank delta
		print("Opponent sent blank delta")
	elseif recv.turn ~= game.turn then
		print("Opponent sent delta from another turn, woah!") -- TODO: still save it?
		print("Expected turn: " .. game.turn .. ", received turn: " .. recv.turn)
		local fail = true
	else -- received their delta sending
		print("Frame: " .. frame, "Time: " .. love.timer.getTime() - client.match_start_time, "Correct delta received:")
		for k, v in pairs(recv) do
			if type(v) == "table" then
				for key, val in pairs(v) do print(key, val) end
			else
				print(k, v)
			end
		end
	end
end

-- we got a state from them, let's handle it!
local function receiveState(recv)
	local fail = false
	print("Frame: " .. frame, "Time: " .. love.timer.getTime() - client.match_start_time, "Received state")
	if recv.turn ~= game.turn then
		print("Received state for wrong turn! Expected: " .. game.turn .. ", received: " .. recv.turn)
		fail = true
		-- TODO: better handling
	end
	client.their_state[recv.turn] = recv
	client.received_state = true
	sendStateConfirmation(fail)
end

local function startMatch(recv)
	assert(recv.side == 1 or recv.side == 2, "oh craps")
	client.match_start_time = love.timer.getTime()
	local char1 = "heath" -- need to lookup the character name
	local char2 = "walter" -- need to lookup the character name
	local bkground = Background.Seasons
	client.queuing = false
	client.playing = true
	startGame("Netplay", char1, char2, bkground, recv.seed, recv.side)
end

local function connectionAccepted(recv)
	print("User data accepted")
end

local function connectionRejected(recv)
	if recv.message == "Version" then
		print("Incorrect version, please update. Server " .. recv.version .. ", client " .. game.version)
	elseif recv.message == "Nope" then
		print("You were already connected")
	else
		print("Unknown rejection reason lol")
	end
end

local function receiveDisconnect()
	print("Disconnected by server")
	client.disconnect()
end

local function receivePing()
	client.send({type = "ping"})
end

local function receiveDudes(recv)
	lobby.updateUsers(recv.all_dudes)
end

local function receiveQueue(recv)
	if recv.action == "already_queued" then
		print("Already queued, didn't join again")
	elseif recv.action == "not_queued" then
		print("Not queued, didn't leave")
	elseif recv.action == "queued" then
		print("Joined queue")
		client.queuing = true
	elseif recv.action == "left" then
		print("Left queue")
		client.queuing = false
	else
		print("Invalid queue response")
	end
end

-- called from mainengine.lua, packages our delta so we don't have to send so much stuff
function client.prepareDelta(...)
	local args = {...}
	if client.our_delta[game.turn] == nil then
		client.our_delta[game.turn] = {
			type = "delta",
			turn = game.turn,
			piece1 = {},
			piece2 = {},
			super = {}
		}
	end

	if args[1] == "blank" then
		client.our_delta[game.turn].blank = true
		client.our_delta[game.turn].send_frame = frame
	elseif args[3] == "normal" or args[3] == "rush" then
		client.our_delta[game.turn].send_frame = frame
		client.our_delta[game.turn].place_type = args[3]
		client.our_delta[game.turn].piece1 = {
			piece_ID = args[1].ID,
			rotation = args[1].rotation_index,
			coords = args[2],
			place_type = args[3]
		}
	elseif args[3] == "double" then
		client.our_delta[game.turn].send_frame = frame
		client.our_delta[game.turn].place_type = args[3]
		client.our_delta[game.turn].piece2 = {
			piece_ID = args[1].ID,
			rotation = args[1].rotation_index,
			coords = args[2],
			place_type = args[3]
		}
	elseif args[3] == "super" then
		client.our_delta[game.turn].send_frame = frame
		client.our_delta[game.turn].super = {
			-- tbc
		}
	else
		print("Error: invalid delta received from player")
	end
	--print("Frame: " .. frame, "Time: " .. love.timer.getTime() - client.match_start_time, "Prepared delta")
	client.sendDelta()
end

function client.sendDelta()
	if client.our_delta[game.turn] then
		print("Frame: " .. frame, "Time: " .. love.timer.getTime() - client.match_start_time, "Sent delta")
		client.send(client.our_delta[game.turn])
	else
		print("Delta already sent, or not available")
	end
end

-- called at start of a new turn. packages the state, and sends it with a delay
function client.sendState(delay)
	state = {
		type = "state",
		turn = game.turn,
		frame = frame,
		grid_gems = stage.grid:getIDs(),
		p1_hand = p1.hand:getPieceIDs(),
		p1_super = p1.cur_mp,
		p1_damage = "TODO",
		p2_hand = p2.hand:getPieceIDs(),
		p2_super = p2.cur_mp,
		p2_damage = "TODO",
		-- place_type
		-- special ability stuff
		-- checksum
	}
	if game.turn > 1 then
		if game.me_player.ID == "P1" then
			state.p1_prev_place_type = client.our_delta[game.turn - 1].place_type
			state.p2_prev_place_type = client.their_delta[game.turn - 1].place_type
		elseif game.me_player.ID == "P2" then
			state.p1_prev_place_type = client.their_delta[game.turn - 1].place_type
			state.p2_prev_place_type = client.our_delta[game.turn - 1].place_type
		end
	end

	print("Frame: " .. frame, "Time: " .. love.timer.getTime() - client.match_start_time, "Saving and sending state")
	client.our_state[game.turn] = state
	queue.add(delay, client.send, state)
end

-- if the states don't match, it's a desync. We don't compare the frame when it was sent though.
function client.compareStates(us, them)
	us = us or client.our_state[game.turn]
	them = them or client.their_state[game.turn]

	for k, v in pairs(us) do
		if type(v) == "table" then
			--print("Now recursively comparing k, v, us:", k, v, us)
			if type(them[k]) ~= "table" then return false end
			if not client.compareStates(v, them[k]) then return false end
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
function client.queue(action)
	local blob = {type = "queue", action = action}
	client.send(blob)
end

-- user-initiated disconnect from server
function client.disconnect()
	if client.connected then
		client_socket:send(json.encode({type = "disconnect"}))
		pcall(function() client_socket:close() end)
	else
		print("Cannot disconnect, you weren't connected")
	end
	initializeClient()
end

client.lookup = {
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
function client.processData(self, recv)
	if self.lookup[recv.type] then
		self.lookup[recv.type](recv)
	else
		print("Invalid data type received from server")
	end
end

return client
