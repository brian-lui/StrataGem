-- handles the main game phases

require 'inits'
--local hand = require 'hand'
local ai = require 'ai'
local engine = game.engine
local inputs = require 'inputs'
local stage = game.stage
local particles = game.particles
local anims = require 'anims'
local inspect = require 'inspect'

local phase = {}

function phase.intro(dt)
	for player in game:players() do
		player.hand:update(dt)
	end
	if frame == 30 then
		particles.words:generateReady()
	end
	if frame == 120 then
		particles.words:generateGo()
		game.phase = "Action"
	end
end

function phase.action(dt)
	for player in game:players() do
		player.hand:update(dt)
		if player.actionPhase then
			player:actionPhase(dt)
		end
	end
	anims.update(dt)

	game.time_to_next = game.time_to_next - 1
	if game.type == "1P" then
		if not ai.finished then
			ai.placeholder(game.them_player)
		end
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
	if game.me_player.place_type == nil then
		print("PLACE TYPE BUG")
	end
	for player in game:players() do
		player.hand:afterActionPhaseUpdate()
	end
	anims.putPendingAtTop()
	particles.upGem:removeAll() -- animation
	game.frozen = true
	game.phase = "GemTween"
end

function phase.applyGemTween(dt)
	stage.grid:updateGravity(dt) -- animation
	local animation_done = stage.grid:isSettled() -- function
	if animation_done then
		stage.grid:dropColumns() -- state
		game.phase = "Gravity"
	end
end

function phase.applyGravity(dt)
	stage.grid:updateGravity(dt) -- animation
	local animation_done = stage.grid:isSettled() -- function
	if animation_done then
		for player in game:players() do player:afterGravity() end
		game.phase = "CheckMatches"
	end
end

function phase.getMatchedGems(dt)
	local _, matches = stage.grid:getMatchedGems() -- sets horizontal/vertical flags for matches
	if matches > 0 then
		game.phase = "FlagGems"
	else
		game.phase = "ResolvedMatches"
	end
end

function phase.flagGems(dt)
	local gem_table = stage.grid:getMatchedGems() -- sets h/v flags
	stage.grid:flagMatchedGems() -- state
	for player in game:players() do player:beforeMatch(gem_table) end
	game.phase = "MatchAnimations"
end

local match_anim_phase, match_anim_count = "start", 0
function phase.matchAnimations(dt)
	if match_anim_phase == "start" then
		engine.generateMatchExplodingGems() -- animation
		match_anim_phase, match_anim_count = "explode", 20
	elseif match_anim_phase == "explode" then
		match_anim_count = math.max(match_anim_count - 1, 0)
		if match_anim_count == 0 then
			local matches = stage.grid:getMatchedGems()
			engine.generateMatchParticles() -- animation
			anims.screenshake(#matches) -- animation
			match_anim_phase, match_anim_count = "start", 0
			game.phase = "ResolvingMatches"
		end
	end
end

function phase.resolvingMatches(dt)
	local gem_table = stage.grid:getMatchedGems()
	game.scoring_combo = game.scoring_combo + 1
	for player in game:players() do
		player:duringMatch(gem_table)
	end
	local p1dmg, p2dmg, p1super, p2super = engine.calculateScore(gem_table)
	local p1_matched, p2_matched = engine.checkMatchedThisTurn(gem_table)
	if not p1_matched then
		stage.grid:removeAllGemOwners(p1)
	end
	if not p2_matched then
		stage.grid:removeAllGemOwners(p2)
	end
	p1:addSuper(p1super)
	p2:addSuper(p2super)
	stage.grid:removeMatchedGems()
	p1.hand:addDamage(p2dmg)
	p2.hand:addDamage(p1dmg)
	stage.grid:dropColumnsAnim()
	stage.grid:dropColumns()
	game.phase = "Gravity"
end

function phase.resolvedMatches(dt)
	for player in game:players() do
		player:afterMatch()
		player.hand:update(dt)
		player.place_type = "normal"
	end
	game.scoring_combo = 0
	stage.grid:setAllGemOwners(0)
	game.phase = "GetPiece"
end

function phase.getPiece(dt)
	local handsettled = true
	for player in game:players() do
		player.hand:update(dt)
		if not player.hand:isSettled() then
			handsettled = false
		end
	end

	stage.grid:updateGravity(dt)

	if not game.finished_getting_pieces then
		for player in game:players() do
			player.hand:getNewTurnPieces()
		end
		game.finished_getting_pieces = true
	end

	if handsettled then
		for player in game:players() do player.hand:update(dt) end
		-- ignore garbage pushing gems up, creating matches, for now

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
	for player in game:players() do
		player:cleanup()
	end
	if game.type == "1P" then
		ai.clear()
	end
	p1.pieces_fallen, p2.pieces_fallen = 0, 0
	p1.dropped_piece, p2.dropped_piece = false, false
	p1.played_pieces, p2.played_pieces = {}, {}
	game.finished_getting_pieces = false
	stage.grid:setAllGemOwners(0)

	for player in game:players() do
		player.hand:endOfTurnUpdate()
	end

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
	GemTween = phase.applyGemTween,
	Gravity = phase.applyGravity,
	CheckMatches = phase.getMatchedGems,
	FlagGems = phase.flagGems,
	MatchAnimations = phase.matchAnimations,
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
