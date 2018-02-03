-- server for StrateGem!

require 'socket'
local json = require 'dkjson'
local server = {
	version = "65.0"
}
local id_count = 1
local dudes = {}
local server_socket = socket.bind("*", 49929)
server_socket:settimeout(0)

function server.send(data, conn)
	local blob = json.encode(data) .. "\n" -- we are using *l receive mode
	if conn then
		local success = conn:send(blob)
		if not success then
			print("Oh noes, blob send unsuccessful")
			disconnect(_, conn)
		end
	else
		print("Oh noes, no connection found")
	end
end

local function disconnect(_, conn)
	print("Disconnected", conn)
	if conn then conn:send(json.encode({type = "disconnected"})) end
	if dudes[conn] then dudes[conn] = nil end
	pcall(function() conn:close() end) -- like try/except in python
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
	}
	id_count = id_count + 1
	print("new connection added", new_conn)
end

local function sendDudes(conn)
	local to_send = {type = "current_dudes", all_dudes = getDudes()}
	if dude_id then
		server.send(to_send, dudes[conn])
	else
		for conn, _ in pairs(dudes) do server.send(to_send, conn) end
	end
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
			sendDudes(conn)
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
			sendDudes(conn)
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
	local blob = {}
	if not dudes[conn].waiting then
		print("Client attempted re-connection! lame")
		blob = {type = "rejected", message = "Nope"}
	elseif data.version ~= server.version then
		print("Server/client version mismatch: server " .. server.version .. ", client " .. data.version)
		blob = {type = "rejected", message = "Version", version = server.version}
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
	local opponent_id = dudes[conn].opponent
	for conn, dude in pairs(dudes) do
		if opponent_id == dude.id then return conn end
	end
	print("Opponent not found!")
end

local function receiveGameData(data, conn)
	if dudes[conn] then
		local opponent = getOpponentConn(conn)
		print("Received game data")
		print("Sending to opponent", opponent)
		server.send(data, opponent)
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
		seed = rng_seed,
	}
	local send2 = {
		type = "start",
		side = 2,
		opponent_id = dude1.id,
		p1_details = dude1.queue_details,
		p2_details = dude2.queue_details,
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
	dudes[conn].playing = false
	sendDudes()
end

server.lookup = {
	connect = attemptedConnection,
	disconnect = disconnect,
	delta = receiveGameData,
	state = receiveGameData,
	confirmed_delta = receiveGameData,
	confirmed_state = receiveGameData,
	--ping = receivePing,
	queue = receiveQueue,
	end_match = endMatch,
}

function server:processData(data_str, conn)
	local data = json.decode(data_str)
	if self.lookup[data.type] then 
		self.lookup[data.type](data, conn)
	else
		print("Invalid data type received from client")
		print(data_str)
	end
end

while true do
	local new_conn = server_socket:accept() -- socket:accept() detects a new connection from a client.
	if new_conn then -- write to dudes with minimal connection info.
		new_conn:settimeout(0)
		dudes[new_conn] = {waiting = true, partial_recv = "", name = "Dog"}
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
				server:processData(recv_str, conn)
			elseif partial_data and partial_data ~= "" then -- still a partial packet
				dudes[conn].partial_recv = dudes[conn].partial_recv .. partial_data
				print("received partial data:" .. partial_data .. ".")
			end
		end
	end

	local queuers = getQueuers()
	if #queuers == 2 then startMatch(queuers[1], queuers[2]) end
end

--[[

local function receivePing(_, ip)
	if server.dudes[ip] then server.dudes[ip].connected = true else print("Cr*p") end
end

local function sendPing(dude_ip)
	server:send(json.encode({type = "ping"}), dude_ip)
end

local function checkDisconnected()
-- temporarily set dude connected = false, then send a ping.
-- if they don't ping back by the next check cycle, remove them.
	for id, dude in pairs(server.dudes) do
		if dude.connected then
			dude.connected = false
			sendPing(dude.ip)
		else
			removeDude(id)
			sendDudes()
		end
	end

	if #server.dudes > 0 then print("Currently connected:") end
	for id, dude in pairs(server.dudes) do print(id, dude.ip) end
end


cur_time = os.time()
check_frequency = 5
while true do
	local data_str, ip = server:receive()
	if data_str then
		local data = json.decode(data_str)
		server:processData(data, ip)
	end

	local queuers = getQueuers()
	if #queuers == 2 then startGame(queuers[1], queuers[2]) end

	if os.time() > cur_time + check_frequency then
		cur_time = os.time()
		sendDudes()
		checkDisconnected()
	end
end

--]]