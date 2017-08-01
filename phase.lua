-- handles the main game phases
require 'inits'
local ai = require 'ai'
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
				print("Player 1 meter: " .. p1.mp, "Player 2 meter: " .. p2.mp)
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
	for player in game:players() do player.hand:afterActionPhaseUpdate() end
	particles.upGem:removeAll() -- animation
	game.frozen = true
	game.phase = "SuperFreeze"
end

local function superPlays()
	local ret = {}
	for player in game:players() do
		if player.supering then ret[#ret+1] = player end
	end
	return ret
end
local super_play, super_pause = nil, 0

-- TODO: refactor this lame stuff
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
		anims.putPendingAtTop()
		game.phase = "GemTween"
	end
end

function phase.applyGemTween(dt)
	stage.grid:updateGravity(dt) -- animation
	for player in game:players() do	player.hand:update(dt) end	
	local animation_done = stage.grid:isSettled() -- tween-from-top is done
	if animation_done then
		stage.grid:dropColumns() -- state
		game.phase = "Gravity"
	end
end

function phase.applyGravity(dt)
	stage.grid:updateGravity(dt) -- animation
	for player in game:players() do	player.hand:update(dt) end
	local animation_done = stage.grid:isSettled() -- function
	if animation_done then
		particles.wordEffects:clear()
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
	for player in game:players() do	player.hand:update(dt) end
	if match_anim_phase == "start" then
		stage.grid:generateMatchExplodingGems() -- animation
		match_anim_phase, match_anim_count = "explode", 20
	elseif match_anim_phase == "explode" then
		match_anim_count = math.max(match_anim_count - 1, 0)
		if match_anim_count == 0 then
			local matches = stage.grid:getMatchedGems()
			stage.grid:generateMatchParticles() -- animation
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
	local p1dmg, p2dmg, p1super, p2super = stage.grid:calculateScore()
	local p1_matched, p2_matched = stage.grid:checkMatchedThisTurn()
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
	stage.grid:updateGrid()
	game.phase = "Gravity"
end

function phase.resolvedMatches(dt)
	-- wait for damage particles to arrive first
	if particles:getCount("onscreen", "Damage", 1) + particles:getCount("onscreen", "Damage", 2) > 0 then
		for player in game:players() do
			player.hand:update(dt)
		end
	else -- all damage particles finished
		for player in game:players() do
			player:afterMatch()
			player.hand:update(dt)
			player.place_type = "normal"
		end
		game.scoring_combo = 0
		stage.grid:setAllGemOwners(0)
		game.phase = "PlatformSpinDelay"
	end
end

local platform_spin_delay_counter = 15
-- wait a few frames for excitement, before exploding the platforms and getting new pieces
function phase.platformSpinDelay(dt)
	if platform_spin_delay_counter > 0 then
		for player in game:players() do
			player.hand:update(dt)
		end
		platform_spin_delay_counter = platform_spin_delay_counter - 1
	else
		platform_spin_delay_counter = 30
		game.phase = "GetPiece"
	end
end

function phase.getPiece(dt)
	for player in game:players() do 
		player.hand:destroyPlatformsAnim()
		player.hand:getNewTurnPieces()
	end
	game.phase = "PlatformsExploding"
end

function phase.platformsExploding(dt)
	if particles:getNumber("ExplodingPlatform") == 0 then
		particles:clearCount() -- clear here so the platforms display redness/spin correctly
		for player in game:players() do player:resetMP() end
		game.phase = "PlatformsMoving"
	end
end

function phase.platformsMoving(dt)
	local handsettled = true
	for player in game:players() do
		player.hand:update(dt)
		if not player.hand:isSettled() then
			handsettled = false
		end
	end

	stage.grid:updateGravity(dt)
	
	if handsettled then
		for player in game:players() do player.hand:update(dt) end -- TODO: check if we can delete this

		if stage.grid:isSettled() then
		-- garbage can possibly push gems up, creating matches.
			local _, matches = stage.grid:getMatchedGems()
			if matches > 0 then
				stage.grid:setGarbageMatchFlags()
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
	stage.grid:setAllGemOwners(0)

	for player in game:players() do
		player.hand:endOfTurnUpdate()
	end

	if stage.grid:getLoser() then
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
	local loser = stage.grid:getLoser()
	if loser == "P1" then
		print("P2 wins gg")
	elseif loser == "P2" then
		print("P1 wins gg")
	elseif loser == "Draw" then
		print("Draw gg")
	else
		print("Match ended unexpectedly, whopps!")
	end
	local damage_particles = particles:getCount("onscreen", "Damage", 1) + particles:getCount("onscreen", "Damage", 2)
	local super_particles = particles:getCount("onscreen", "MP", 1) + particles:getCount("onscreen", "MP", 2)
	local anims_done = damage_particles + super_particles == 0
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
	PlatformSpinDelay = phase.platformSpinDelay,
	GetPiece = phase.getPiece,
	PlatformsExploding = phase.platformsExploding,
	PlatformsMoving = phase.platformsMoving,
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
