-- handles the main game phases
local love = _G.love
local common = require "class.commons"
local Phase = {}

function Phase:init(game)
	self.game = game
	self.INIT_TIME_TO_NEXT = 430 -- frames in each action phase
	self.PLATFORM_SPIN_DELAY = 30 -- frames to animate platforms exploding
	self.GAMEOVER_DELAY = 180 -- how long to stay on gameover screen
	self.NETPLAY_DELTA_WAIT = 360 -- how many frames to wait for delta before lost connection
end

function Phase:reset()
	self.next_phase = nil
	self.frames_until_next_phase = 0
	self.time_to_next = self.INIT_TIME_TO_NEXT
	self.no_rush = {} --whether no_rush is eligible for animation
	for i = 1, self.game.grid.COLUMNS do self.no_rush[i] = true end
	self.matched_this_round = {false, false} -- p1 made a match, p2 made a match
	self.garbage_this_round = false
	self.force_minimum_1_piece = true -- get at least 1 piece per turn
	self.should_call_char_ability_this_phase = true
	self.update_gravity_during_pause = false
end

-- helper function to set duration of the pause until next phase
function Phase:setPause(frames)
	assert(frames >= 0, "Non-positive frames " .. frames .. " provided for phase " .. self.game.current_phase)
	self.frames_until_next_phase = frames
end

-- pause for the amount set in setPause
-- if update_gravity true, also updates the grid gems
function Phase:activatePause(next_phase, update_gravity)
	self.next_phase = next_phase
	self.update_gravity_during_pause = update_gravity
	self.game.current_phase = "Pause"
end

function Phase:_pause(dt)
	if self.frames_until_next_phase > 0 then
		self.frames_until_next_phase = self.frames_until_next_phase - 1
		if self.update_gravity_during_pause then self.game.grid:updateGravity(dt) end
	else
		self.game.current_phase = self.next_phase
		self.update_gravity_during_pause = nil
		self.next_phase = nil
	end
end

function Phase:intro(dt)
	local game = self.game
	if game.frame == 30 then
		game.particles.words.generateReady(self.game)
	end
	if game.frame == 120 then
		game.sound:newBGM(game.p1.sounds.bgm, true)
		game.particles.words.generateGo(self.game)
		game.sound:newSFX("fountaingo")
		game.current_phase = "Action"
	end
end

function Phase:action(dt)
	local game = self.game
	local client = game.client
	local ai = game.ai

	for player in game:players() do
		if player.actionPhase then player:actionPhase(dt) end
	end
	self.game.ui:update()

	self.time_to_next = self.time_to_next - 1
	if not ai.finished then ai:evaluateActions(game.them_player) end
	--[[
	if not ai.finished then ai:evaluateActions(game.them_player) end
	This is probably the key part
	Every frame, it checks whether we have received a their_delta. If we have, it performs the delta and
	then sets ai.finished to true.
	So we will get desync bugs for multiple deltas, since deltas are sent immediately.
	Instead, we need to queue this and do it after the confirmdeltas phase.
	--]]
	if self.time_to_next <= 0 and ai.finished then
		love.mousereleased(drawspace.tlfres.getMousePosition(drawspace.width, drawspace.height))
		game.particles.wordEffects.clear(game.particles)
		game.current_phase = "Resolve"

		if game.type == "Netplay" then
			if not client.our_delta[game.turn] then	-- If local player hasn't acted, send empty turn
				client:prepareDelta("blank")
			end
		end
		ai:performQueuedAction()	-- TODO: Expand this to netplay and have the ai read from the net
		game.particles.upGem.removeAll(game.particles)
		game.particles.placedGem.removeAll(game.particles)
	end
end

function Phase:netplaySendDeltas(dt)
	--[[
	Currently, deltas are sent from Client:prepareDelta(). So each time you do a move, it sends.
	Instead, prepareDelta should ONLY prepare the delta. All delta is sent at end of turn in this phase.
	This phase only needs to send the delta, then it can go directly to netplayConfirmDeltas.
	This phase should also handle blank delta. probably use

	if not client.our_delta[game.turn] then	-- If local player hasn't acted, send empty turn
		client:prepareDelta("blank")
	end
	--]]
end
function Phase:netplayConfirmDeltas(dt)
	--[[
	we should confirm that both players received a delta from the other guy.
	stay in this phase for self.NETPLAY_DELTA_WAIT frames until deltas received.
	once it's confirmed that deltas are received, play the deltas from ai_net playPiece.
	then go to resolve phase.

	if self.NETPLAY_DELTA_WAIT frames pass, then go to "lost connection".
	When confirmed deltas, go to game.current_phase = "Resolve".

	Have lots of print statements to see what's going on.


	--]]
end

function Phase:resolve(dt)
	local game = self.game
	if game.me_player.place_type == nil then print("PLACE TYPE BUG") end
	game.grid:updateRushPriority()

	local delay = 0
	for player in game:players() do
		local player_delay = player.hand:afterActionPhaseUpdate()
		delay = math.max(delay, player_delay or 0)
	end
	self:setPause(delay)
	self:activatePause("SuperFreeze")

	game.inputs_frozen = true
end

function Phase:superFreeze(dt)
	local game = self.game
	local p1delay, p2delay = 0, 0
	if game.p1.supering then
		game:darkenScreen(1)
		p1delay = game.p1:superSlideInAnim()
	end
	if game.p2.supering then
		game:darkenScreen(2)
		p2delay = game.p2:superSlideInAnim(p1delay)
	end
	self:setPause(p1delay + p2delay)
	self:activatePause("BeforeGravity")
end

function Phase:beforeGravity(dt)
	local game = self.game
	if game.p1.supering then game.p1:emptyMP() end
	if game.p2.supering then game.p2:emptyMP() end

	local delay = 0
	for player in game:players() do
		local player_delay = player:beforeGravity()
		delay = math.max(delay, player_delay or 0)
	end
	game.ui:putPendingAtTop(delay)
	self:setPause(delay)
	self:activatePause("GemTween", true)
end

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

function Phase:duringGravity(dt)
	local duration = self.game.grid:dropColumns()
	self:setPause(duration or 0)
	self:activatePause("AfterGravity", true)
end

function Phase:afterGravity(dt)
	local game = self.game
	local grid = game.grid
	game.particles.wordEffects.clear(game.particles)

	local delay = 0
	for player in self.game:players() do
		local player_delay = player:afterGravity()
		delay = math.max(delay, player_delay or 0)
	end
	self:setPause(delay)

	for i = 1, grid.COLUMNS do --checks if no_rush should be possible again
		if not self.no_rush[i] then
			if not grid[8][i].gem  then
				self.no_rush[i] = true
			end
		end
	end
	self:activatePause("GetMatchedGems")

	-- screencap
	if game.debug_screencaps then
		game.debug_screencap_number = game.debug_screencap_number or 0
		game.debug_screencap_number = game.debug_screencap_number + 1
		local screenshot = love.graphics.newScreenshot()
		local filename = "turn" .. game.turn .. "cap" .. game.debug_screencap_number .. ".png"
		screenshot:encode("png", filename)
		print("Saved file: " .. filename)
	end
end

function Phase:getMatchedGems(dt)
	local game = self.game
	local grid = game.grid
	local _, matches = grid:getMatchedGems() -- sets is_a_horizontal/vertical_match flags for matches
	if matches > 0 then grid:flagMatchedGems() end

	local delay = 0

	if self.garbage_this_round then
		local diff = game.p1.garbage_rows_created - game.p2.garbage_rows_created
		grid:setGarbageMatchFlags(diff)
		self.garbage_this_round = false
		game.p1.garbage_rows_created, game.p2.garbage_rows_created = 0		
	end

	for player in game:players() do
		local player_delay = player:beforeMatch()
		delay = math.max(delay, player_delay or 0)
	end
	self:setPause(delay)

	if matches > 0 then
		self:activatePause("DestroyMatchedGems")
	else
		self:activatePause("ResolvedMatches")
	end
end

-- destroy matched gems, and create the gems-being-exploded animation
function Phase:destroyMatchedGems(dt)
	local game = self.game
	local grid = game.grid

	self.matched_this_round = grid:checkMatchedThisTurn() -- which players made a match
	grid:destroyMatchedGems(game.scoring_combo)

	if self.should_call_char_ability_this_phase then
		local delay = 0
		for player in game:players() do
			local player_delay = player:duringMatchAnimation()
			delay = math.max(delay, player_delay or 0)
		end
		self:setPause(game.GEM_EXPLODE_FRAMES + game.GEM_FADE_FRAMES + delay)
		self.should_call_char_ability_this_phase = false
	end

	self:activatePause("ResolvingMatches")
	self.should_call_char_ability_this_phase = true
end

function Phase:resolvingMatches(dt)
	local game = self.game
	local grid = game.grid
	local gem_table = grid:getMatchedGems()

	local delay = 0
	for player in game:players() do
		local player_delay = player:afterMatch()
		delay = math.max(delay, player_delay or 0)
	end
	self:setPause(delay)

	game.scoring_combo = game.scoring_combo + 1
	if not self.matched_this_round[1] then grid:removeAllGemOwners(1) end
	if not self.matched_this_round[2] then grid:removeAllGemOwners(2) end
	grid:updateGrid()
	self:activatePause("DuringGravity")
end

function Phase:resolvedMatches(dt)
	local game = self.game
	local grid = game.grid
	if self.should_call_char_ability_this_phase then 
		local delay = 0
		for player in game:players() do
			local player_delay = player:afterAllMatches()
			delay = math.max(delay, player_delay or 0)
		end
		self:setPause(self.PLATFORM_SPIN_DELAY + delay)
		self.should_call_char_ability_this_phase = false
	end
	if game.particles:getCount("onscreen", "Damage", 1) + game.particles:getCount("onscreen", "Damage", 2) == 0 then
	-- all damage particles finished
		for player in game:players() do player.place_type = "none" end
		game.scoring_combo = 0
		game.grid:setAllGemOwners(0)
		for i = 1, grid.COLUMNS do --checks if should generate no rush
			if self.no_rush[i] then
				if grid[grid.RUSH_ROW][i].gem then
					game.particles.words.generateNoRush(self.game, i)
					self.no_rush[i] = false	
				end
			end
		end
		self.should_call_char_ability_this_phase = true
		self:activatePause("DestroyDamagedPlatforms")
	end
end

function Phase:destroyDamagedPlatforms(dt)
	local game = self.game
	local grid = game.grid
	local max_delay = game.EXPLODING_PLATFORM_FRAMES
	for player in game:players() do
		local garbage_arrival_frames = player.hand:destroyDamagedPlatforms(self.force_minimum_1_piece)

		for _, delay in pairs(garbage_arrival_frames) do
			game.queue:add(delay, grid.addBottomRow, grid, player)
			max_delay = math.max(max_delay, delay)
			self.garbage_this_round = true
		end
	end

	self:setPause(max_delay)
	self:activatePause("GarbageRowCreation")
end

function Phase:garbageRowCreation(dt)
	local game = self.game
	local grid = game.grid

	game.particles:clearCount()	-- clear here so the platforms display redness/spin correctly
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

function Phase:garbageMoving(dt)
	local game = self.game
	local grid = game.grid

	grid:updateGravity(dt)

	if grid:isSettled() and game.particles:getNumber("GarbageParticles") == 0 then
		for player in game:players() do
			player.hand:getNewTurnPieces(self.force_minimum_1_piece)
			self.force_minimum_1_piece = false
		end
		game.current_phase = "PlatformsMoving"
	end
end

function Phase:platformsMoving(dt)
	local game = self.game
	local grid = game.grid

	local handsettled = true
	for player in game:players() do
		if not player.hand:isSettled() then handsettled = false end
	end

	grid:updateGravity(dt)

	if handsettled then	
		if self.garbage_this_round then
			game.current_phase = "DuringGravity"
		else
			local delay = 0
			for player in game:players() do
				local player_delay = player:beforeCleanup()
				delay = math.max(delay, player_delay or 0)
			end
			self:setPause(delay)
			self:activatePause("Cleanup")
			self.should_call_char_ability_this_phase = true
		end
	end
end

function Phase:cleanup(dt)
	local game = self.game
	local grid = game.grid
	local p1, p2 = game.p1, game.p2

	for i = 1, grid.COLUMNS do --checks if should generate no rush
		if self.no_rush[i] then
			if grid[grid.RUSH_ROW][i].gem then
				game.particles.words.generateNoRush(self.game, i)
				self.no_rush[i] = false	
			end
		end
	end

	grid:updateGrid()

	local delay = 0
	for player in self.game:players() do
		local player_delay = player:cleanup()
		delay = math.max(delay, player_delay or 0)
	end
	self:setPause(delay)

	game.ai:newTurn()
	self.garbage_this_round = false
	self.force_minimum_1_piece = true
	p1.dropped_piece, p2.dropped_piece = nil, nil
	p1.played_pieces, p2.played_pieces = {}, {}
	game.finished_getting_pieces = false
	grid:setAllGemOwners(0)
	grid:setAllGemReadOnlyFlags(false)

	for player in game:players() do player.hand:endOfTurnUpdate() end

	if grid:getLoser() then
		self:activatePause("GameOver")
	elseif game.type == "Netplay" then
		self:activatePause("Sync")
	else
		self:activatePause("NewTurn")
	end
end

function Phase:newTurn(dt)
	self.game:newTurn()
end

function Phase:sync(dt)
	self.game.client:newTurn()
	self.game:newTurn()
	-- If disconnected by server, change to vs AI
	if not self.game.client.connected then
		self.game.type = "1P"
		print("Disconnected from server :( changing to 1P mode")
	end
end

function Phase:gameOver(dt)
	local game = self.game
	game.grid:animateGameOver(game.grid:getLoser())
	if game.type == "Netplay" then game.client:endMatch() end
	self:setPause(self.GAMEOVER_DELAY)
	self:activatePause("Leave")
end

function Phase:leave(dt)
	local game = self.game
	if game.type == "Netplay" then
		game.statemanager:switch(require "gs_lobby")
	elseif game.type == "1P" then
		game.statemanager:switch(require "gs_charselect")
	end
end

Phase.lookup = {
	Pause = Phase._pause,
	Intro = Phase.intro,
	Action = Phase.action,
	NetplaySendDeltas = Phase.netplaySendDeltas,
	NetplayConfirmDeltas = Phase.netplayConfirmDeltas,
	Resolve = Phase.resolve,
	SuperFreeze = Phase.superFreeze,
	BeforeGravity = Phase.beforeGravity,
	GemTween = Phase.applyGemTween,
	DuringGravity = Phase.duringGravity,
	AfterGravity = Phase.afterGravity,
	GetMatchedGems = Phase.getMatchedGems,
	DestroyMatchedGems = Phase.destroyMatchedGems,
	ResolvingMatches = Phase.resolvingMatches,
	ResolvedMatches = Phase.resolvedMatches,
	PlatformSpinDelay = Phase.platformSpinDelay,
	DestroyDamagedPlatforms = Phase.destroyDamagedPlatforms,
	GarbageRowCreation = Phase.garbageRowCreation,
	GarbageMoving = Phase.garbageMoving,
	PlatformsMoving = Phase.platformsMoving,
	BeforeCleanup = Phase.beforeCleanup,
	Cleanup = Phase.cleanup,
	Sync = Phase.sync,
	NewTurn = Phase.newTurn,
	GameOver = Phase.gameOver,
	Leave = Phase.leave,
}

function Phase:run(...)
	if not self.game.paused then
		local todo = Phase.lookup[self.game.current_phase]
		assert(todo, "You did a typo for the current phase idiot - " .. self.game.current_phase)
		for player in self.game:players() do player.hand:update(...) end
		todo(self, ...)
		self.game.queue:update()
	end
end

return common.class("Phase", Phase)
