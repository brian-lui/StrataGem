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
end

-- helper function to set duration of the pause until next phase
function Phase:setPause(frames)
	self.frames_until_next_phase = frames
end

-- pause for the amount set in setPause
function Phase:activatePause(next_phase)
	self.next_phase = next_phase
	self.game.current_phase = "Pause"
end

function Phase:_pause(dt)
	if self.frames_until_next_phase > 0 then
		self.frames_until_next_phase = self.frames_until_next_phase - 1
	else
		self.game.current_phase = self.next_phase
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
		game.ui:putPendingAtTop(dt) -- ready the gems for falling
		game.particles.upGem.removeAll(game.particles)
		game.particles.placedGem.removeAll(game.particles)
	end
end

function Phase:netplayConfirmDeltas(dt)
	--[[
	we should confirm that both players received a delta from the other guy.
	stay in this phase for self.NETPLAY_DELTA_WAIT frames until deltas received.
	once it's confirmed that deltas are received, play the deltas from ai_net playPiece.
	then go to resolve phase.

	if self.NETPLAY_DELTA_WAIT frames pass, then go to "lost connection".
	--]]
end

function Phase:resolve(dt)
	local game = self.game
	if game.me_player.place_type == nil then print("PLACE TYPE BUG") end

	local delay = 0
	for player in game:players() do
		local player_delay = player.hand:afterActionPhaseUpdate()
		delay = math.max(delay, player_delay or 0)
	end
	self:setPause(delay)
	self:activatePause("SuperFreeze")

	game.grid:updateRushPriority()
	game.inputs_frozen = true
end

function Phase:superFreeze(dt)
	local game = self.game
	local p1delay, p2delay = 0, 0
	if game.p1.supering then
		game.screen_darkened = true
		p1delay = game.p1:superSlideInAnim()
	end
	if game.p2.supering then
		game.screen_darkened = true
		p2delay = game.p2:superSlideInAnim(p1delay)
	end
	self:setPause(p1delay + p2delay)
	self:activatePause("BeforeGravity")
end

function Phase:beforeGravity(dt)
	local game = self.game
	if not game.settings_menu_open then game.screen_darkened = false end
	local delay = 0
	for player in game:players() do
		local player_delay = player:beforeGravity()
		delay = math.max(delay, player_delay or 0)
	end
	self:setPause(delay)
	self:activatePause("GemTween")
end

function Phase:applyGemTween(dt)
	local game = self.game
	local grid = game.grid
	grid:updateGravity(dt) -- animation
	local animation_done = grid:isSettled() --  tween-from-top is done
	if animation_done then
		grid:dropColumns() -- state
		game.current_phase = "Gravity"
	end
end

function Phase:applyGravity(dt)
	local game = self.game
	local grid = game.grid
	grid:updateGravity(dt) -- animation
	if grid:isSettled() then
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
	grid:dropColumns()
	grid:updateGrid()
	self:activatePause("Gravity")
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
		for player in game:players() do player.place_type = "normal" end
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
			player:updateTurnStartMPForDisplay()
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
			game.current_phase = "Gravity"
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
	p1.dropped_piece, p2.dropped_piece = false, false
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
	Resolve = Phase.resolve,
	SuperFreeze = Phase.superFreeze,
	BeforeGravity = Phase.beforeGravity,
	GemTween = Phase.applyGemTween,
	Gravity = Phase.applyGravity,
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
