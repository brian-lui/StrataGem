--[[
This module handles the phases for the main gamestate.
There should be a graphical depiction of the loop somewhere, that will be
helpful to read.

Important methods:
setPause, activatePause, setPhase - control flow for when to go to the next
phase
--]]

local love = _G.love
local common = require "class.commons"

--[[
	Bug 13 fix: Netplay timeout configuration
	These values are in frames (60 fps assumed).
	Adjust these based on network conditions:
	- For LANs or fast connections, lower values are fine
	- For high-latency or unreliable connections, increase these values
--]]
local NETPLAY_CONFIG = {
	-- Frames to wait for opponent data before declaring connection lost
	-- 360 frames = 6 seconds at 60 fps
	DELTA_WAIT_FRAMES = 360,
	STATE_WAIT_FRAMES = 360,

	-- Frames between resending unconfirmed data (packet loss recovery)
	-- 60 frames = 1 second at 60 fps
	RESEND_INTERVAL_FRAMES = 60,
}

local Phase = {}

function Phase:init(game)
	self.game = game
	self.INIT_TIME_TO_NEXT = 430 -- frames in each action phase
	self.INIT_TIME_TO_NEXT_REPLAY = 120 -- frames in action phase in replay mode
	self.PLATFORM_SPIN_DELAY = 30 -- frames to animate platforms exploding
	self.GAMEOVER_DELAY = 180 -- how long to stay on gameover screen
	-- Bug 13 fix: Use configuration values for netplay timeouts
	self.NETPLAY_DELTA_WAIT = NETPLAY_CONFIG.DELTA_WAIT_FRAMES
	self.NETPLAY_STATE_WAIT = NETPLAY_CONFIG.STATE_WAIT_FRAMES
	self.NETPLAY_RESEND_INTERVAL = NETPLAY_CONFIG.RESEND_INTERVAL_FRAMES
end

function Phase:reset()
	self.next_phase = nil
	self.frames_until_next_phase = 0
	self.no_rush = {} --whether no_rush is eligible for animation
	for i = 1, self.game.grid.COLUMNS do self.no_rush[i] = true end
	self.last_match_round = {0, 0} -- for p1, p2
	self.garbage_this_round = 0
	self.force_minimum_1_piece = true -- get at least 1 piece per turn
	self.update_gravity_during_pause = false
	self.damage_particle_duration = 0 -- for AfterAllMatches phase
	self.netplay_wait_frames = 0 -- frames spent waiting for opponent data
	self.delta_processed = nil -- reset netplay delta processing flag
	self.state_confirmation_sent = nil -- reset netplay state confirmation flag
	if self.game.type == "Replay" then
		self.INIT_ACTION_TIME = self.INIT_TIME_TO_NEXT_REPLAY
	else
		self.INIT_ACTION_TIME = self.INIT_TIME_TO_NEXT
	end
	self.time_to_next = self.INIT_ACTION_TIME
end

-------------------------------------------------------------------------------
-- helper functions to set duration of the pause until next phase
function Phase:setPause(frames)
	assert(frames >= 0, "Non-positive frames " .. frames .. " provided for phase " .. self.game.current_phase)
	self.frames_until_next_phase = frames
end

-- pause for the amount set in setPause
-- if update_gravity true, also updates the grid gems
function Phase:activatePause(next_phase, update_gravity)
	self.current_phase_for_debug_purposes_only = self.game.current_phase
	self.next_phase = next_phase
	self.update_gravity_during_pause = update_gravity
	self.game.current_phase = "Pause"
end

function Phase:_pause(dt)
	if self.frames_until_next_phase > 0 then
		self.frames_until_next_phase = self.frames_until_next_phase - 1
		if self.update_gravity_during_pause then
			self.game.grid:updateGravity(dt)
		end
	else
		self.game.current_phase = self.next_phase
		self.update_gravity_during_pause = nil
		self.next_phase = nil
	end
end

function Phase:setPhase(next_phase)
	self.game.current_phase = next_phase
	print("New phase: " .. self.game.current_phase)
end

-------------------------------------------------------------------------------

-- Start of match phase. Delay is set within function
function Phase:intro(dt)
	local game = self.game
	local ready_delay = 30
	local delay = 120

	if game.type == "Singleplayer" then	game.ai:clearDeltas() end
	game.debugtextdump:setReplayLocation()
	game.debugtextdump:writeReplayHeader()
	game.particles.words.generateReady(game, ready_delay)
	game.particles.words.generateGo(game, delay)
	game.queue:add(delay, game.sound.newBGM, game.sound, game.p1.sounds.bgm, true)
	game.queue:add(delay, game.sound.newSFX, game.sound, "fountaingo")

	self:setPause(delay)
	self:activatePause("Action")

	love.filesystem.remove("gamelog.txt") -- start a new log

	game.debugtextdump:writeGameInfo()
	game.debugtextdump:writeTitle("Start of log (intro phase)\n")
	game.debugtextdump:writeHandsText()
	game.debugtextdump:writeGridText()
end

-- Active phase. Time here is set in self.time_to_next
function Phase:action(dt)
	local game = self.game
	local ai = game.ai

	for player in game:players() do player:actionPhase(dt) end

	self.time_to_next = self.time_to_next - 1
	if game.type == "Singleplayer" then
		if not ai.finished then ai:evaluateActions(game.them_player) end
	elseif game.type == "Replay" then
		if not ai.finished then ai:evaluateActions() end
	end

	if self.time_to_next <= 0 then
		local drawspace = game.inits.drawspace
		game:mousereleased(game:_getControllerPosition())

		if game.type == "Netplay" then
			self:setPhase("NetplaySendDelta")
		elseif game.type == "Singleplayer" then
			ai:performQueuedAction()
			if game.me_player.is_supering then ai:writePlayerSuper() end
			self:setPhase("Resolve")
		elseif game.type == "Replay" then
			ai:performQueuedAction()
			self:setPhase("Resolve")
		end

		game.particles.wordEffects.clear(game.particles)
		game.particles.upGem.removeAll(game.particles)
		game.particles.placedGem.removeAll(game.particles)
	end
end

-- Netplay only: send delta to opponent. Instant
function Phase:netplaySendDelta(dt)
	local game = self.game
	local client = game.client

	-- NOTE: Don't check pending delta here - it creates a race condition
	-- if delta arrives between this check and the one in netplayWaitForDelta.
	-- Only check in netplayWaitForDelta for consistent handling.

	-- check for super at end of turn
	if game.me_player.is_supering then client:writeDeltaSuper() end

	game.debugtextdump:writeMyDeltaText()

	client:sendDelta()
	self:setPhase("NetplayWaitForDelta")
end

-- Handle connection timeout during netplay
function Phase:handleConnectionTimeout()
	local game = self.game
	local client = game.client

	print("Connection timed out waiting for opponent")

	-- Bug 27 fix: Check client exists before accessing properties
	if not client then
		print("handleConnectionTimeout: client is nil")
		game:switchState("gs_multiplayerselect")
		return
	end

	-- Clear any pending delta/state data to prevent late arrivals from being processed
	-- after we've already transitioned away from the netplay phases
	client.their_delta = nil
	client.their_state = nil

	client:endMatch()
	game:switchState("gs_multiplayerselect")
end

-- Wait for client:receiveDelta here. Once received, push it to game
function Phase:netplayWaitForDelta(dt)
	local game = self.game
	local client = game.client

	-- If opponent left during the match, skip waiting and proceed to resolve
	-- The game will detect the loser naturally
	if client.opponent_left then
		print("Opponent left, skipping delta wait")
		self.netplay_wait_frames = 0
		self.delta_processed = nil
		self:setPhase("Resolve")
		return
	end

	-- Check if there's a pending delta that arrived before we were ready
	client:checkPendingDelta()

	-- Check for timeout
	self.netplay_wait_frames = self.netplay_wait_frames + 1
	if self.netplay_wait_frames >= self.NETPLAY_DELTA_WAIT then
		self:handleConnectionTimeout()
		return
	end

	-- Resend our delta periodically in case it was lost
	if self.netplay_wait_frames > 0 and
	   self.netplay_wait_frames % self.NETPLAY_RESEND_INTERVAL == 0 and
	   not client.delta_confirmed and
	   client.connected then
		print("Resending delta (attempt " .. math.floor(self.netplay_wait_frames / self.NETPLAY_RESEND_INTERVAL) .. ")")
		client:sendDelta()
	end

	-- Process opponent's delta and send confirmation as soon as we receive it
	if client.their_delta and not self.delta_processed then
		game.debugtextdump:writeTheirDeltaText()

		local success = game.ai:evaluateActions(game.them_player)
		if not success then
			print("Failed to process opponent delta, ending match")
			self:handleConnectionTimeout()
			return
		end

		local action_result = game.ai:performQueuedAction()
		if action_result == false then
			print("Failed to execute opponent delta action, ending match")
			self:handleConnectionTimeout()
			return
		end

		game.particles.wordEffects.clear(game.particles)
		game.particles.upGem.removeAll(game.particles)
		game.particles.placedGem.removeAll(game.particles)

		client:sendDeltaConfirmation()

		game.debugtextdump:writePendingGridText()

		self.delta_processed = true
	end

	-- Only advance to Resolve when BOTH conditions are met:
	-- 1. We received and processed their delta (and sent our confirmation)
	-- 2. They confirmed they received our delta
	if client.their_delta and client.delta_confirmed then
		self.netplay_wait_frames = 0 -- reset wait counter
		self.delta_processed = nil -- reset for next turn
		self:setPhase("Resolve")
	end
end

-- Deltas are ready and get played.
-- Delay here is from player.hand:afterActionPhaseUpdate()
function Phase:resolve(dt)
	local game = self.game

	if game.type ~= "Replay" then game.debugtextdump:writeReplayDeltas() end
	game.grid:updateRushPriority()
	game.grid:assignGemOriginators()

	local delay = 0
	for player in game:players() do
		local player_delay = player.hand:afterActionPhaseUpdate()
		delay = math.max(delay, player_delay or 0)
	end
	self:setPause(delay)
	self:activatePause("SuperFreeze")

	game.inputs_frozen = true
end

-- If super(s) was activated, it is played in this phase.
-- Delay is from character's superSlideInAnim(), doubled if both are supering
function Phase:superFreeze(dt)
	local game = self.game
	local p1delay, p2delay = 0, 0
	if game.p1.is_supering then
		game:darkenScreen(1)
		p1delay = game.p1:superSlideInAnim()
	end
	if game.p2.is_supering then
		game:darkenScreen(2)
		p2delay = game.p2:superSlideInAnim(p1delay)
	end
	self:setPause(p1delay + p2delay)
	self:activatePause("BeforeGravity")
end

-- Player actions before this turn's gems fall. Often used for supers
-- Delay is from player:beforeGravity()
function Phase:beforeGravity(dt)
	local game = self.game
	local delay = 0

	for player in game:players() do
		local player_delay = player:beforeGravity()
		delay = math.max(delay, player_delay or 0)
	end
	game.uielements:putPendingAtTop(delay)
	self:setPause(delay)
	self:activatePause("GemTween", true)
end

-- Gems fall from top of screen into intermediate location ABOVE basin.
-- Delay is max(gem:getAnimFrames(), player:beforeTween())
function Phase:applyGemTween(dt)
	local game = self.game
	local grid = game.grid
	local max_delay = 0

	for gem in grid:gems() do
		local gem_delay = gem:getAnimFrames()
		max_delay = math.max(max_delay, gem_delay)
	end

	for player in game:players() do
		local player_delay = player:beforeTween()
		max_delay = math.max(max_delay, player_delay or 0)
	end

	self:setPause(max_delay)
	self:activatePause("DuringGravity", true)
end

-- Gems fall from intermediate location into landing position in basin.
-- Delay is max(grid:dropColumns(), player:duringTween())
function Phase:duringGravity(dt)
	local game = self.game
	local delay = 0

	for player in game:players() do
		local player_delay = player:duringTween()
		delay = math.max(delay, player_delay or 0)
	end

	local gem_tween_duration = self.game.grid:dropColumns()
	local delay = math.max(delay, gem_tween_duration or 0)

	self:setPause(delay)
	self:activatePause("AfterGravity", true)
end

-- Any player effects after gems have landed but before matches.
-- Player effects can optionally redirect to DuringGravity phase.
-- Delay is player:afterGravity()
function Phase:afterGravity(dt)
	local game = self.game
	local grid = game.grid

	game.particles.wordEffects.clear(game.particles)

	grid:updateMatchedGems() -- also sets is_a_horizontal/vertical_match flags

	local delay = 0
	local next_phase = "GetMatchedGems"

	for player in self.game:players() do
		local player_delay, go_to_gravity_phase = player:afterGravity()
		delay = math.max(delay, player_delay or 0)
		if go_to_gravity_phase then next_phase = "DuringGravity" end
	end
	self:setPause(delay)

	for i = 1, grid.COLUMNS do --checks if no_rush should be possible again
		if not self.no_rush[i] then
			if not grid[8][i].gem  then
				self.no_rush[i] = true
			end
		end
	end
	self:activatePause(next_phase)

	game.debugconsole:saveScreencap()
end

--[[ Calculate the gem matches for this round.
If match:
	goes to DestroyMatchedGems.
	delay is player:beforeMatch()
If no match:
	goes to AfterAllMatches.
	Delay is max(self.damage_particle_duration, player:beforeMatch())
	self.damage_particle_duration is set in DestroyMatchedGems phase, and
	represents time until all damage particles have arrived at platforms
--]]
function Phase:getMatchedGems(dt)
	local game = self.game
	local grid = game.grid

	if #grid.matched_gems > 0 then grid:flagMatchedGems() end

	local delay = 0

	if self.garbage_this_round > 0 then
		local diff = game.p1.garbage_rows_created - game.p2.garbage_rows_created
		grid:setGarbageMatchFlags(diff)
		self.garbage_this_round = 0
		game.p1.garbage_rows_created, game.p2.garbage_rows_created = 0, 0
	end

	for player in game:players() do
		local player_delay = player:beforeMatch()
		delay = math.max(delay, player_delay or 0)
	end
	if #grid.matched_gems > 0 then
		self:setPause(delay)
		self:activatePause("DestroyMatchedGems")
	else
		self:setPause(math.max(delay, self.damage_particle_duration))
		self.damage_particle_duration = 0
		self:activatePause("AfterAllMatches")
	end
end

-- Destroy matched gems, and create the gems-being-exploded animation.
-- Only accessed if there was a match this round.
-- Delay is grid:destroyMatchedGems explode_delay
-- Also sets self.damage_particle_duration to time until damage particles land
function Phase:destroyMatchedGems(dt)
	local game = self.game
	local grid = game.grid

	local matched = grid:checkMatchedThisRound()

	if matched[1] then self.last_match_round[1] = game.scoring_combo + 1 end
	if matched[2] then self.last_match_round[2] = game.scoring_combo + 1 end

	local explode_delay, particle_duration = grid:destroyMatchedGems(game.scoring_combo)

	local delay = explode_delay
	for player in game:players() do
		local player_delay = player:duringMatch()
		delay = math.max(delay, player_delay or 0)
	end
	local total_delay = math.max(delay, explode_delay + particle_duration)

	grid:clearMatchedGems()

	self:setPause(delay)
	self:activatePause("AfterMatch")
	self.damage_particle_duration = total_delay
end

-- Player effects after a match. Only accessed if there was a match this round.
-- Delay is player:afterMatch()
function Phase:afterMatch(dt)
	local game = self.game
	local grid = game.grid

	local delay = 0
	for player in game:players() do
		local player_delay = player:afterMatch()
		delay = math.max(delay, player_delay or 0)
	end

	self:setPause(delay)

	game.scoring_combo = game.scoring_combo + 1
	if self.last_match_round[1] < game.scoring_combo then
		grid:removeAllGemOwners(1)
	end
	if self.last_match_round[2] < game.scoring_combo then
		grid:removeAllGemOwners(2)
	end
	grid:updateGrid()
	self:activatePause("DuringGravity")
end

-- Player effects after all matches finished.
-- Always accessed once, can be accessed multiple times if garbage makes match.
-- Player effects can optionally redirect to DuringGravity phase.
-- Delay is player:afterAllMatches() + self.PLATFORM_SPIN_DELAY (if destroyed)
function Phase:afterAllMatches(dt)
	local game = self.game
	local next_phase = "BeforeDestroyingPlatforms"
	local delay = 0

	game.grid:setAllGemOwners(0)

	for player in game:players() do
		local player_delay, go_to_gravity_phase = player:afterAllMatches()
		delay = math.max(delay, player_delay or 0)
		if go_to_gravity_phase then next_phase = "DuringGravity" end
	end

	game.scoring_combo = 0

	self:setPause(delay)
	self:activatePause(next_phase)
end

function Phase:beforeDestroyingPlatforms(dt)
	local game = self.game
	local grid = game.grid
	local delay = 0

	for player in game:players() do
		local player_delay = player:beforeDestroyingPlatforms()
		delay = math.max(delay, player_delay or 0)
	end

	local platforms_get_destroyed = false
	for player in game:players() do
		if not platforms_get_destroyed then
			platforms_get_destroyed = player.hand:damagedPlatformsExist()
		end
	end
	if platforms_get_destroyed then
		delay = delay + self.PLATFORM_SPIN_DELAY
	end

	for i = 1, grid.COLUMNS do --checks if should generate no rush
		if self.no_rush[i] then
			if grid[grid.RUSH_ROW][i].gem then
				game.particles.words.generateNoRush(self.game, i)
				self.no_rush[i] = false
			end
		end
	end

	self:setPause(delay)
	self:activatePause("DestroyDamagedPlatforms")
end

--[[ Destroy fully red playforms.
Delay is:
Max of
	(hand:destroyDamagedPlatforms()	+ consecutive platform destruction delays),
	game.EXPLODING_PLATFORM_FRAMES,
--]]
function Phase:destroyDamagedPlatforms(dt)
	local game = self.game
	local grid = game.grid
	local max_delay = 0
	for player in game:players() do
		local garbage_arrival_frames, platforms_destroyed = player.hand:destroyDamagedPlatforms(self.force_minimum_1_piece)

		-- additional delay waiting for consecutive platform explosions
		local last_platform_time = (platforms_destroyed - 1) * player.hand.CONSECUTIVE_PLATFORM_DESTROY_DELAY
		max_delay = math.max(max_delay, last_platform_time)

		-- additional delay waiting for garbage arrival
		for _, delay in ipairs(garbage_arrival_frames) do
			game.queue:add(delay, grid.addBottomRow, grid, player)
			max_delay = math.max(max_delay, game.EXPLODING_PLATFORM_FRAMES, delay)
			self.garbage_this_round = self.garbage_this_round + 1
		end
	end

	self:setPause(max_delay)
	self:activatePause("GarbageRowCreation")
end

-- Instantly create garbage row(s).
-- Delay is player:whenCreatingGarbageRow()
function Phase:garbageRowCreation(dt)
	local game = self.game
	local grid = game.grid

	game.particles:clearCount()	-- clear here so platforms show correct redness/spin
	grid:updateGravity(dt)

	if game.particles:getNumber("GarbageParticles") == 0 then
		local delay = 0
		for player in self.game:players() do
			local player_delay = player:whenCreatingGarbageRow()
			delay = math.max(delay, player_delay or 0)
		end
		self:setPause(delay)
		self:activatePause("GarbageMoving")
	end
end

-- Move garbage rows up.
-- Delay until grid settled.
-- TODO: change to a fixed frame amount
function Phase:garbageMoving(dt)
	local game = self.game
	local grid = game.grid

	grid:updateGravity(dt)

	if grid:isSettled() and game.particles:getNumber("GarbageParticles") == 0 then
		self:setPhase("GetHandPieces")
	end
end

-- Instantly get new turn pieces, no delay.
function Phase:getHandPieces(dt)
	for player in self.game:players() do
		player.hand:createNewTurnPieces(self.force_minimum_1_piece)
	end
	self.force_minimum_1_piece = false

	self:setPhase("PlatformsMoving")
end

-- Move platforms and pieces up after creating them.
-- If garbage was created this round, go to DuringGravity.
-- Delay is until player.hand:isSettled() then player:beforeCleanup().
-- TODO: change to a fixed frame amount
function Phase:platformsMoving(dt)
	local game = self.game
	local grid = game.grid

	local handsettled = true
	for player in game:players() do
		if not player.hand:isSettled() then handsettled = false end
	end

	grid:updateGravity(dt)

	if handsettled then
		if self.garbage_this_round > 0 then
			self:setPhase("DuringGravity")
		else
			local delay = 0
			local next_phase = "Cleanup"

			for player in game:players() do
				local player_delay, go_to_gravity = player:beforeCleanup()
				delay = math.max(delay, player_delay or 0)
				if go_to_gravity then next_phase = "DuringGravity" end
			end
			self:setPause(delay)
			self:activatePause(next_phase)
		end
	end
end

-- Placeholder phase before cleanup (currently unused but in lookup table)
function Phase:beforeCleanup(dt)
	-- No-op: exists for potential future use
	self:setPhase("Cleanup")
end

-- Game and player cleanup phase.
-- Delay is player:cleanup()
function Phase:cleanup(dt)
	local game = self.game
	local grid = game.grid
	local p1, p2 = game.p1, game.p2

	game.debugconsole:resetScreencapNum()

	for i = 1, grid.COLUMNS do --checks if should generate no rush
		if self.no_rush[i] then
			if grid[grid.RUSH_ROW][i].gem then
				game.particles.words.generateNoRush(self.game, i)
				self.no_rush[i] = false
			end
		end
	end

	grid:updateGrid()
	grid:removeGemOriginators()

	local delay = 0
	for player in self.game:players() do
		local player_delay = player:cleanup()
		delay = math.max(delay, player_delay or 0)
	end
	self:setPause(delay)

	game.ai:newTurn()
	self.garbage_this_round = 0
	self.force_minimum_1_piece = true
	self.last_match_round = {0, 0}
	p1.dropped_piece, p2.dropped_piece = nil, nil
	p1.played_pieces, p2.played_pieces = {}, {}
	game.finished_getting_pieces = false
	grid:setAllGemOwners(0)
	grid:setAllGemReadOnlyFlags(false)

	game.tie_priority = game.rng:random(2)

	for player in game:players() do player.hand:endOfTurnUpdate() end

	if game.type == "Singleplayer" then game.ai:clearDeltas() end

	game.debugtextdump:writeTitle("Logging state at end of turn (cleanup phase)")
	game.debugtextdump:writeMeters()
	game.debugtextdump:writeHandsText()
	game.debugtextdump:writeGridText()
	game.debugtextdump:writeSpecials()

	if grid:getLoser() then
		self:activatePause("GameOver")
	elseif game.type == "Netplay" then
		self:activatePause("NetplaySendState")
	else
		self:activatePause("SingleplayerNewTurn")
	end
end

-- Netplay only phase, sends state to opponent. No delay
function Phase:netplaySendState(dt)
	local game = self.game

	-- Bug 4 fix: Reset wait counter when entering state phase
	-- (it was used during delta phase and would carry over incorrectly)
	self.netplay_wait_frames = 0

	game.client:writeState()
	game.client:sendState()
	self:setPhase("NetplayWaitForState")
end

-- Netplay only phase, wait for opponent state here.
function Phase:netplayWaitForState(dt)
	local game = self.game
	local client = game.client

	-- If opponent left during the match, skip waiting and proceed to new turn
	-- The game will detect the loser naturally
	if client.opponent_left then
		print("Opponent left, skipping state wait")
		self.netplay_wait_frames = 0
		self.state_confirmation_sent = nil
		self:setPhase("NetplayNewTurn")
		return
	end

	-- Check for timeout
	self.netplay_wait_frames = self.netplay_wait_frames + 1
	if self.netplay_wait_frames >= self.NETPLAY_STATE_WAIT then
		self:handleConnectionTimeout()
		return
	end

	-- Resend our state periodically in case it was lost
	if self.netplay_wait_frames > 0 and
	   self.netplay_wait_frames % self.NETPLAY_RESEND_INTERVAL == 0 and
	   not client.state_confirmed and
	   client.connected then
		print("Resending state (attempt " .. math.floor(self.netplay_wait_frames / self.NETPLAY_RESEND_INTERVAL) .. ")")
		client:sendState()
	end

	-- Send confirmation as soon as we receive and validate their state
	if client.their_state and not self.state_confirmation_sent then
		-- Bug 6 fix: Validate our_state exists before comparison
		if not client.our_state then
			print("Error: our_state is nil, cannot compare states")
			self:handleConnectionTimeout()
			return
		end

		if client.our_state ~= client.their_state then
			print("States don't match! Desync detected.")
			print("Upload this file to coder: " .. love.filesystem.getSaveDirectory() .. "/gamelog.txt")
			-- Notify opponent about desync before ending match
			client:sendDesyncNotification()
			self:handleConnectionTimeout()
			return
		end

		client:sendStateConfirmation()
		self.state_confirmation_sent = true
	end

	-- Only advance to next turn when BOTH conditions are met:
	-- 1. We received their state (and sent our confirmation)
	-- 2. They confirmed they received our state
	if client.their_state and client.state_confirmed then
		self.netplay_wait_frames = 0 -- reset wait counter
		self.state_confirmation_sent = nil -- reset for next turn
		self:setPhase("NetplayNewTurn")
	end
end

-- Netplay new turn, runs client:newTurn() in addition to other stuff.
function Phase:netplayNewTurn(dt)
	local game = self.game
	local client = game.client

	-- Bug 2 fix: Check connection before proceeding with new turn
	-- If disconnected, end the match immediately instead of converting to broken singleplayer
	if not client.connected then
		print("Disconnected from server during new turn, ending match")
		client:clear()
		game:switchState("gs_multiplayerselect")
		return
	end

	-- Bug 28 fix: Handle case when newTurn fails due to too many unconfirmed turns
	local success = client:newTurn()
	if not success then
		game:switchState("gs_multiplayerselect")
		return
	end

	game:newTurn()
	self:setPhase("Action")
end

-- Singleplayer new turn, runs game:newTurn().
function Phase:singleplayerNewTurn(dt)
	local game = self.game
	game:newTurn()
	self:setPhase("Action")
end

-- Gameover phase.
-- Currently delay is self.GAMEOVER_DELAY.
function Phase:gameOver(dt)
	local game = self.game
	game.grid:animateGameOver(game.grid:getLoser())
	game.debugtextdump:writeReplayEnd()
	-- Don't send endMatch here - wait until Leave phase so opponent can see game over too
	self:setPause(self.GAMEOVER_DELAY)
	self:activatePause("Leave")
end

function Phase:leave(dt)
	local game = self.game
	if game.type == "Netplay" then
		-- Send endMatch after game over animation has played
		game.client:endMatch()
		game:switchState("gs_multiplayerselect")
	elseif game.type == "Singleplayer" then
		game:switchState("gs_singleplayerselect")
	elseif game.type == "Replay" then
		game:switchState("gs_singleplayerselect")
		-- TODO: Switch to a replay state
	end
end

Phase.lookup = {
	Pause = Phase._pause,
	Intro = Phase.intro,
	Action = Phase.action,
	NetplaySendDelta = Phase.netplaySendDelta,
	NetplayWaitForDelta = Phase.netplayWaitForDelta,
	Resolve = Phase.resolve,
	SuperFreeze = Phase.superFreeze,
	BeforeGravity = Phase.beforeGravity,
	GemTween = Phase.applyGemTween,
	DuringGravity = Phase.duringGravity,
	AfterGravity = Phase.afterGravity,
	GetMatchedGems = Phase.getMatchedGems,
	DestroyMatchedGems = Phase.destroyMatchedGems,
	AfterMatch = Phase.afterMatch,
	AfterAllMatches = Phase.afterAllMatches,
	BeforeDestroyingPlatforms = Phase.beforeDestroyingPlatforms,
	DestroyDamagedPlatforms = Phase.destroyDamagedPlatforms,
	GarbageRowCreation = Phase.garbageRowCreation,
	GarbageMoving = Phase.garbageMoving,
	GetHandPieces = Phase.getHandPieces,
	PlatformsMoving = Phase.platformsMoving,
	BeforeCleanup = Phase.beforeCleanup,
	Cleanup = Phase.cleanup,
	NetplaySendState = Phase.netplaySendState,
	NetplayWaitForState = Phase.netplayWaitForState,
	NetplayNewTurn = Phase.netplayNewTurn,
	SingleplayerNewTurn = Phase.singleplayerNewTurn,
	GameOver = Phase.gameOver,
	Leave = Phase.leave,
}

function Phase:run(...)
	local game = self.game
	if not game.paused then
		local todo = Phase.lookup[game.current_phase]
		assert(todo, "You did a typo for the current phase - " .. game.current_phase)
		for player in game:players() do
			player.hand:update(...)
			player:update(...)
		end
		todo(self, ...)
		game.uielements:update(...)
		game.queue:update()
	end
end

return common.class("Phase", Phase)
