-- server for StrataGem!
require "socket"
local json = require "dkjson"

local server = {
	VERSION = "71.0"
}
local id_count = 1
local dudes = {}
local server_socket = socket.bind("*", 49929)
server_socket:settimeout(0)

-- Keepalive settings
local PING_INTERVAL = 30 -- seconds between pings
local PING_TIMEOUT = 60 -- seconds before considering connection dead
local last_ping_time = os.time()

-- Maximum size for partial packet buffer (64KB)
local MAX_PARTIAL_RECV_SIZE = 65536

local function disconnect(_, conn)
	print("Disconnected", conn)
	if conn then conn:send(json.encode({type = "disconnected"})) end
	if dudes[conn] then dudes[conn] = nil end
	pcall(function() conn:close() end) -- like try/except in python
end

function server.send(data, conn)
	local blob = json.encode(data) .. "\n" -- we are using *l receive mode
	if conn then
		local success = conn:send(blob)
		if not success then
			print("Oh noes, blob send unsuccessful")
			disconnect(nil, conn)
		end
	else
		print("Oh noes, no connection found")
	end
end

local function getDudes()
	local all_dudes = {}
	for _, dude in pairs(dudes) do
		all_dudes[#all_dudes+1] = dude
	end
	return all_dudes
end

local function getIdlers()
	local idlers = {}
	for _, dude in pairs(dudes) do
		if not dude.playing then idlers[#idlers+1] = dude end
	end
	return idlers
end

local function getPlayers()
	local players = {}
	for _, dude in pairs(dudes) do
		if dude.playing then players[#players+1] = dude end
	end
	return players
end

local function getQueuers()
	local queuers = {}
	for _, dude in pairs(dudes) do
		if dude.queuing then queuers[#queuers+1] = dude end
	end
	return queuers
end

local function addDude(data, new_conn)
-- adds the client object to connection_to_name table, as a key
	new_conn:settimeout(0) -- never block any receives or sends
	dudes[new_conn] = {
		id = id_count,
		queuing = false,
		queue_details = {},
		playing = false,
		opponent = false,
		connected = true,
		partial_recv = "",
		name = data.name,
		last_activity = os.time(),
	}
	id_count = id_count + 1
	print("new connection added", new_conn)
end

local function sendDudes()
	local to_send = {type = "current_dudes", all_dudes = getDudes()}
	for connection, _ in pairs(dudes) do server.send(to_send, connection) end
end

local function joinQueue(conn, queue_details)
	print("Join queue request from", conn)
	if dudes[conn] then
		if dudes[conn].queuing then
			print("Cannot join queue: Already in queue")
			server.send({type = "queue", action = "already_queued"}, conn)
		else
			dudes[conn].queuing = true
			dudes[conn].queue_details = queue_details
			server.send({type = "queue", action = "queued"}, conn)
			sendDudes()
		end
	else
		print("woah this guy doesn't exist")
	end
end

local function leaveQueue(conn)
	print("Leave queue request from", conn)
	if dudes[conn] then
		if dudes[conn].queuing then
			dudes[conn].queuing = false
			dudes[conn].queue_details = {}
			server.send({type = "queue", action = "left"}, conn)
			sendDudes()
		else
			print("Cannot leave queue: Not in queue")
			server.send({type = "queue", action = "not_queued"}, conn)
		end
	else
		print("woah this guy doesn't exist")
	end
end

local function receiveQueue(data, conn)
	if data.action == "join" then
		joinQueue(conn, data.queue_details)
	elseif data.action == "leave" then
		leaveQueue(conn)
	else
		print("Invalid queue command")
	end
end

local function attemptedConnection(data, conn)
	local blob
	if not dudes[conn].waiting then
		print("Client attempted re-connection! lame")
		blob = {type = "rejected", message = "Nope"}
	elseif not data.version then
		-- Bug 4 fix: Validate version field exists
		print("Client sent connect without version field")
		blob = {type = "rejected", message = "Version", version = server.VERSION}
	elseif data.version ~= server.VERSION then
		print("Server/client version mismatch: server " .. server.VERSION .. ", client " .. tostring(data.version))
		blob = {type = "rejected", message = "Version", version = server.VERSION}
	elseif not data.name or type(data.name) ~= "string" or data.name == "" then
		-- Bug 4 fix: Validate name field exists and is non-empty
		print("Client sent connect without valid name field")
		blob = {type = "rejected", message = "InvalidName"}
	else
		addDude(data, conn)
		blob = {type = "connected", message = "Thanks"}
		print("New connection added from", conn)
		sendDudes()
	end
	server.send(blob, conn)
end

local function getConnFromID(id)
	for conn, dude in pairs(dudes) do
		if id == dude.id then return conn end
	end
	print("error.")
end

local function getOpponentConn(conn)
	if not dudes[conn] then
		print("getOpponentConn: connection not in dudes table")
		return nil
	end
	local opponent_id = dudes[conn].opponent
	if not opponent_id then
		print("getOpponentConn: no opponent_id set")
		return nil
	end
	for connection, dude in pairs(dudes) do
		if opponent_id == dude.id then return connection end
	end
	print("Opponent not found!")
	return nil
end

local function receiveGameData(data, conn)
	if dudes[conn] then
		local opponent = getOpponentConn(conn)
		if opponent then
			print("Received game data")
			print("Sending to opponent", opponent)
			server.send(data, opponent)
		else
			print("Cannot forward game data: opponent not found, ending match")
			endMatch(nil, conn)
		end
	else
		print("Got info from an unconnected dude, this shouldn't happen")
	end
end

local function startMatch(dude1, dude2)
	print(dude1)
	print(dude1.id)
	print(dude2)
	print(dude2.id)
	local rng_seed = os.time()
	local send1 = {
		type = "start",
		side = 1,
		opponent_id = dude2.id,
		p1_details = dude1.queue_details,
		p2_details = dude2.queue_details,
		p1_name = dude1.name,
		p2_name = dude2.name,
		seed = rng_seed,
	}
	local send2 = {
		type = "start",
		side = 2,
		opponent_id = dude1.id,
		p1_details = dude1.queue_details,
		p2_details = dude2.queue_details,
		p1_name = dude1.name,
		p2_name = dude2.name,
		seed = rng_seed,
	}
	local conn1, conn2 = getConnFromID(dude1.id), getConnFromID(dude2.id)
	server.send(send1, conn1)
	server.send(send2, conn2)
	dude1.opponent, dude2.opponent = dude2.id, dude1.id
	dude1.playing, dude2.playing = true, true
	dude1.queuing, dude2.queuing = false, false
	print("Started game with", conn1, conn2)
end

local function endMatch(data, conn)
	if not dudes[conn] then return end

	-- Bug 5 fix: Cache all needed values upfront to avoid TOCTOU issues
	local my_id = dudes[conn].id
	local opponent_id = dudes[conn].opponent

	-- Notify opponent that match has ended
	local opponent_conn = getOpponentConn(conn)
	if opponent_conn and dudes[opponent_conn] then
		server.send({type = "end_match", reason = "opponent_left"}, opponent_conn)
		dudes[opponent_conn].playing = false
		dudes[opponent_conn].opponent = false
	else
		-- Opponent connection not found - clean up any stale references
		-- by scanning for dudes that think they're playing against us
		if opponent_id and my_id then
			for other_conn, dude in pairs(dudes) do
				if dude.opponent == my_id then
					dude.playing = false
					dude.opponent = false
					print("Cleaned up stale opponent reference for dude id " .. dude.id)
				end
			end
		end
	end

	-- Update the player who ended the match (re-check in case of concurrent modification)
	if dudes[conn] then
		dudes[conn].playing = false
		dudes[conn].opponent = false
	end

	sendDudes()
end

local function receivePing(data, conn)
	if dudes[conn] then
		dudes[conn].last_activity = os.time()
	end
end

-- Send ping to all connected clients and check for timeouts
local function checkKeepalive()
	local current_time = os.time()

	-- Only run keepalive check every PING_INTERVAL seconds
	if current_time - last_ping_time < PING_INTERVAL then
		return
	end
	last_ping_time = current_time

	local to_disconnect = {}

	for conn, dude in pairs(dudes) do
		if not dude.waiting then -- only ping fully connected clients
			-- Check for timeout
			if dude.last_activity and (current_time - dude.last_activity > PING_TIMEOUT) then
				print("Client timed out:", conn)
				table.insert(to_disconnect, conn)
			else
				-- Send ping
				server.send({type = "ping"}, conn)
			end
		end
	end

	-- Disconnect timed out clients
	for _, conn in ipairs(to_disconnect) do
		disconnect(nil, conn)
	end
end

server.lookup = {
	connect = attemptedConnection,
	disconnect = disconnect,
	delta = receiveGameData,
	state = receiveGameData,
	confirmed_delta = receiveGameData,
	confirmed_state = receiveGameData,
	ping = receivePing,
	queue = receiveQueue,
	end_match = endMatch,
}

function server:processData(data_str, conn)
	local success, data = pcall(json.decode, data_str)
	if not success or not data then
		print("Failed to decode JSON from client: " .. tostring(data))
		print("Raw data: " .. data_str:sub(1, 100)) -- log first 100 chars
		return
	end

	if not data.type then
		print("Received data without type field")
		return
	end

	if self.lookup[data.type] then
		self.lookup[data.type](data, conn)
	else
		print("Invalid data type received from client: " .. tostring(data.type))
	end
end

while true do
	local new_conn = server_socket:accept() -- socket:accept() detects a new connection from a client.
	if new_conn then -- write to dudes with minimal connection info.
		new_conn:settimeout(0)
		dudes[new_conn] = {waiting = true, partial_recv = "", name = "Dog", last_activity = os.time()}
	end

	local recvt = {server_socket} -- server_socket is the first item in the array, needed to test for new connections
	for conn, name in pairs(dudes) do
		recvt[#recvt+1] = conn -- client objects are the other items in the array
	end

	local ready = socket.select(recvt, nil, 5)
	for _, conn in ipairs(ready) do -- ready returns any object that sent data
		if conn ~= server_socket then -- if it's server_socket, do nothing, it's handled in new_conn above
			local recv_str, err, partial_data = conn:receive("*l")
			if err == "closed" then
				disconnect(_, conn)
			elseif recv_str then -- we got a complete packet now
				recv_str = dudes[conn].partial_recv .. recv_str
				dudes[conn].partial_recv = ""
				-- Update last activity time on any received data
				if dudes[conn] then
					dudes[conn].last_activity = os.time()
				end
				server:processData(recv_str, conn)
			elseif partial_data and partial_data ~= "" then -- still a partial packet
				-- Check for buffer overflow attack
				if #dudes[conn].partial_recv + #partial_data > MAX_PARTIAL_RECV_SIZE then
					print("Partial packet buffer overflow from client, disconnecting")
					disconnect(_, conn)
				else
					dudes[conn].partial_recv = dudes[conn].partial_recv .. partial_data
					print("received partial data:" .. partial_data .. ".")
				end
			end
		end
	end

	-- Check for client keepalive and send pings
	checkKeepalive()

	local queuers = getQueuers()
	if #queuers == 2 then startMatch(queuers[1], queuers[2]) end
end
