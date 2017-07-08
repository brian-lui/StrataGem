-- handles the main game phases

require 'inits'
local hand = require 'hand'
local ai = require 'ai'
local engine = game.engine
local inputs = require 'inputs'
local stage = game.stage
local particles = game.particles
local anims = require 'anims'
local inspect = require 'inspect'

local phase = {}

function phase.intro(dt)
	if frame == 15 then particles.words:generate("Ready") end
	hand.update(dt)
	if hand.isSettled(p1) and hand.isSettled(p2) then
		particles.words:generate("Go")
		game.phase = "Action"
	end
end

function phase.action(dt)
	hand.update(dt)
	anims.update(dt)
	for player in game:players() do
		if player.actionPhase then player:actionPhase(dt) end
	end

	game.time_to_next = game.time_to_next - 1
	if game.type == "1P" then
		if not ai.finished then ai.placeholder(game.them_player) end
	end
	if game.time_to_next == 0 then
		inputs.maingameRelease(mouse.x, mouse.y)
		particles.wordEffects:clear()
		game.phase = "Resolve"
		if game.type == "Netplay" then
			if not client.our_delta[game.turn] then
				client.prepareDelta("blank")
			end
		elseif game.type == "1P" then
			if ai.queued_action then
				ai.queued_action.func(unpack(ai.queued_action.args))
				ai.queued_action = false
			end
		end
	end

	-- This part checks that the state is the same
	-- We do it in this phase so that players don't need to wait
	-- Send it 50 frames after turn start, hope this removes the state bug?!
	if not client.synced and game.type == "Netplay" then
		if not client.sent_state then
			print("Queueing state-send")
			client.sendState(game.STATE_SEND_WAIT)
			client.sent_state = true
		end

		if client.received_state and client.opponent_received_state then
			-- all state sending is done, now compare them and raise an error if different
			print("Frame: " .. frame, "Time: " .. love.timer.getTime() - client.match_start_time,"States successfully exchanged")

			-- time adjustment for lag
			local our_frames_behind = client.their_state[game.turn].frame - client.our_state[game.turn].frame
			print("Frame: " .. frame, "Time: " .. love.timer.getTime() - client.match_start_time,"Our frames behind:", our_frames_behind)
			-- If we are behind in frames, it means we processed state more slowly
			-- We need to catch up (our_frames_behind) frames.
			-- Therefore, we add to time bucket (our_frames_behind * timestep).
			if our_frames_behind > 0 then
				print("Need to speed up by " .. our_frames_behind .. " frames")
				client.giving_frameback = our_frames_behind
			end

			if client.compareStates() then
				print("Frame: " .. frame, "Time: " .. love.timer.getTime() - client.match_start_time, "States match!")
				print("Player 1 meter: " .. p1.cur_mp, "Player 2 meter: " .. p2.cur_mp)
				client.synced = true
			else
				print("Frame: " .. frame, "Time: " .. love.timer.getTime() - client.match_start_time, "Desync.")
				print("Game turn: " .. game.turn)
				print("Our state:")
				for k, v in spairs(client.our_state[game.turn]) do print(k, v) end
				print("Their state:")
				for k, v in spairs(client.their_state[game.turn]) do print(k, v) end
				print("Desynced due to states not matching!")

				print("hey send garcia1000 ourstate.txt and theirstate.txt please")
				print("File path is:")
				print( love.filesystem.getSaveDirectory() )
				local write1 = inspect(client.our_state[game.turn])
				local write2 = inspect(client.their_state[game.turn])
				love.filesystem.write("ourstate.txt", write1)
				love.filesystem.write("theirstate.txt", write2)

				game.phase = "GameOver"
				--[[
				Need to do more stuff here
				--]]
			end
		end
	end
end

function phase.resolve(dt)
	local function resolveThings()
		if game.me_player.place_type == nil then print("PLACE TYPE BUG") end
		hand.endOfTurnUpdate()
		game.frozen = true
		anims.putPendingAtTop()
		particles.gems:removeAll()
		game.phase = "SuperFreeze"
	end

	if game.type == "Netplay" then
		if client.received_delta[game.turn] and client.opponent_received_delta[game.turn] then
			print("Frame: " .. frame, "Time: " .. love.timer.getTime() - client.match_start_time, "Resolving turn")
			client.playTurn(client.their_delta, game.turn)
			game.netplay_wait = 0
			resolveThings()
		elseif game.netplay_wait <= game.NETPLAY_MAX_WAIT then
			game.netplay_wait = game.netplay_wait + 1
		else -- assume opponent connection problem
			print("Connection problem! Please help")
			game.netplay_wait = 0
			resolveThings()
		end
	else
		resolveThings()
	end
end

local function superPlays()
	local ret = {}
	for player in game:players() do
		if player.supering then ret[#ret+1] = player end
	end
	return ret
end
local super_play, super_pause = nil, 0

function phase.superFreeze(dt)
	if not super_play then super_play = superPlays() end

	if super_pause > 0 then
		super_pause = super_pause - 1
	elseif super_play[1] then
		super_play[1]:superSlideIn()
		super_pause = 90
		table.remove(super_play, 1)
	else
		super_play = nil
		--stage.grid:dropColumns()
		game.phase = "Gravity"
	end
end

function phase.applyGravity(dt)
	stage.grid:dropColumns()
	stage.grid:updateGravity(dt)
	if stage.grid:isSettled() then
		for player in game:players() do
			local anims = player:afterGravity()
			for i = 1, #anims do
				queue.add(anims[i][1], anims[i][2], unpack(anims[i], 3))
			end
		end
		game.phase = "CheckMatches"
	end
end

function phase.getMatchedGems(dt)
	local _, matches = stage.grid:getMatchedGems()
	if matches > 0 then
		game.phase = "DrawEffects"
	else
		game.phase = "ResolvedMatches"
	end
end

function phase.drawEffects(dt)
	local gem_table = stage.grid:getMatchedGems()
	-- draw exploding gems, keep everything else the same
	stage.grid:flagMatchedGems()
	engine.generateMatchExplodingGems()
	for player in game:players() do player:beforeMatch(gem_table) end
	game.grid_wait = SPEED.GEM_EXPLODE_FRAMES -- wait same time as fadeout animation
	game.phase = "WaitForDrawEffects"
end

function phase.waitForDrawEffects(dt)
	game.grid_wait = math.max(0, game.grid_wait - 1)
	if game.grid_wait == 0 then
		game.phase = "ResolvingMatches"
	end
end

function phase.resolvingMatches(dt)
	local gem_table = stage.grid:getMatchedGems()
	game.scoring_combo = game.scoring_combo + 1

	for player in game:players() do player:duringMatch(gem_table) end

	local p1dmg, p2dmg, p1super, p2super = engine.calculateScore(gem_table)
	if game.type == "Netplay" then
		print("Frame: " .. frame, "Time: " .. love.timer.getTime() - client.match_start_time)
	end
	print("P1 place type:", p1.place_type, "P2 place type:", p2.place_type)
	print("P1 super gain:", p1super, "P2 super gain:", p2super)

	local p1_matched, p2_matched = engine.checkMatchedThisTurn(gem_table)

	if not p1_matched then stage.grid:removeAllGemOwners(p1) end
	if not p2_matched then stage.grid:removeAllGemOwners(p2) end
	print("Now adding super gain for p1:", p1super, "p2:", p2super)
	game.character.addSuper(p1super, p2super)

	engine.generateMatchParticles()
	stage.grid:removeMatchedGems()
	hand.addDamage(p1, p2dmg)
	hand.addDamage(p2, p1dmg)
	anims.screenshake(math.max(p1dmg, p2dmg))

	game.phase = "Gravity"
end

function phase.resolvedMatches(dt)
	for player in game:players() do player:afterMatch() end
	game.scoring_combo = 0
	stage.grid:setAllGemOwners(0)
	hand.update(dt)
	if hand.isSettled(p1) and hand.isSettled(p2) then
		-- pause for a bit for match explosions before we advance the hands
		game.piece_waiting_time = game.piece_waiting_time - 1
	end
	if game.piece_waiting_time <= 0 then
		game.piece_waiting_time = game.INIT_PIECE_WAITING_TIME
		p1.place_type, p2.place_type = "normal", "normal"
		game.phase = "GetPiece"
	end
end

function phase.getPiece(dt)
	hand.update(dt)
	stage.grid:dropColumns()
	stage.grid:updateGravity(dt)

	if not game.finished_getting_pieces then hand.getNewTurnPieces() end

	if hand.isSettled(p1) and hand.isSettled(p2) then
		hand.update(dt) -- activates cleanupHand, which may add penalty rows

		if stage.grid:isSettled() then
		-- garbage can possibly push gems up, creating matches.
			local _, matches = stage.grid:getMatchedGems()
			if matches > 0 then
				engine.setGarbageMatchFlags()
				game.phase = "Gravity"
			else
				game.phase = "Cleanup"
			end
		end
	end
end

function phase.cleanup(dt)
	stage.grid:updateGrid()
	for player in game:players() do player:cleanup()	end
	if game.type == "1P" then	ai.clear() end
	p1.pieces_fallen, p2.pieces_fallen = 0, 0
	p1.dropped_piece, p2.dropped_piece = false, false
	p1.played_pieces, p2.played_pieces = {}, {}
	game.finished_getting_pieces = false
	stage.grid:setAllGemOwners(0)

	if engine.checkLoser() then
		game.phase = "GameOver"
	elseif game.type == "Netplay" then
		game.phase = "Sync"
	else
		game:newTurn()
	end
end

function phase.sync(dt)
	client:newTurn()
	game:newTurn()
	-- If disconnected by server, change to vs AI
	if not client.connected then
		game.type = "1P"
		print("Disconnected from server :( changing to 1P mode")
		game:newTurn()
	end
end

function phase.gameOver(dt)
	local loser = engine.checkLoser()
	if loser == "P1" then
		print("P2 wins gg")
	elseif loser == "P2" then
		print("P1 wins gg")
	elseif loser == "Draw" then
		print("Draw gg")
	else
		print("Match ended unexpectedly, whopps!")
	end
	local damage_particles = particles.getNumber("Damage", p1) + particles.getNumber("Damage", p2)
	local super_particles = particles.getNumber("Super", p1) + particles.getNumber("Super", p2)
	local anims_done = (damage_particles == 0) and (super_particles == 0)
	if anims_done and game.type == "Netplay" then
		client:endMatch()
		game.current_screen = "lobby"
	elseif anims_done and game.type == "1P" then
		game.current_screen = "charselect"
	end
end

phase.lookup = {
	Intro = phase.intro,
	Action = phase.action,
	Resolve = phase.resolve,
	SuperFreeze = phase.superFreeze,
	Gravity = phase.applyGravity,
	CheckMatches = phase.getMatchedGems,
	DrawEffects = phase.drawEffects,
	WaitForDrawEffects = phase.waitForDrawEffects,
	ResolvingMatches = phase.resolvingMatches,
	ResolvedMatches = phase.resolvedMatches,
	GetPiece = phase.getPiece,
	Cleanup = phase.cleanup,
	Sync = phase.sync,
	GameOver = phase.gameOver
}

function phase.run(self, ...)
	local todo = phase.lookup[game.phase]
	assert (todo, "You did a typo for the current phase idiot - " .. game.phase)
	todo(...)
	queue.update()
end

return phase
