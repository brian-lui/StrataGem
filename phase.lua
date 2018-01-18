-- handles the main game phases
local love = _G.love
local common = require "class.commons"
local Phase = {}

function Phase:init(game)
	self.game = game
	self.INIT_TIME_TO_NEXT = 430 -- frames in each action phase
	self.INIT_PLATFORM_SPIN_DELAY_FRAMES = 30 -- frames to animate platforms exploding
	self.INIT_SUPER_PAUSE = 90 -- frames to animate super activation
	self.INIT_GAMEOVER_PAUSE = 180 -- how long to stay on gameover screen
end

function Phase:reset()
	self.time_to_next = self.INIT_TIME_TO_NEXT
	self.super_play = nil
	self.super_pause = 0
	self.platform_spin_delay_frames = self.INIT_PLATFORM_SPIN_DELAY_FRAMES
	self.no_rush = {} --whether no_rush is eligible for animation
	for i = 1, self.game.grid.columns do self.no_rush[i] = true end
	self.after_match_delay = self.game.GEM_FADE_FRAMES
	self.matched_this_round = {false, false} -- p1 made a match, p2 made a match
	self.game_is_over = false
	self.gameover_pause = self.INIT_GAMEOVER_PAUSE
	self.garbage_this_round = false
	self.should_call_char_ability_this_phase = true
end

function Phase:intro(dt)
	local game = self.game
	for player in game:players() do
		player.hand:update(dt)
	end
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
		player.hand:update(dt)
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

function Phase:resolve(dt)
	local game = self.game
	if game.me_player.place_type == nil then print("PLACE TYPE BUG") end
	for player in game:players() do player.hand:afterActionPhaseUpdate() end
	game.grid:updateRushPriority()
	game.frozen = true
	game.current_phase = "SuperFreeze"
end

local function superPlays(self)
	local ret = {}
	for player in self.game:players() do
		if player.supering then
			ret[#ret + 1] = player
		end
	end
	return ret
end

-- TODO: refactor this lame stuff
function Phase:superFreeze(dt)
	self.super_play = self.super_play or superPlays(self)

	if self.super_pause > 0 then
		self.super_pause = self.super_pause - 1
	elseif self.super_play[1] then
		self.super_play[1]:superSlideIn()
		self.super_pause = self.INIT_SUPER_PAUSE
		table.remove(self.super_play, 1)
	else
		self.super_play = nil
		self.game.current_phase = "BeforeGravity"
	end
end

function Phase:beforeGravity(dt)
	for player in self.game:players() do player:beforeGravity() end
	self.game.current_phase = "GemTween"
end

function Phase:applyGemTween(dt)
	local game = self.game
	local grid = game.grid
	grid:updateGravity(dt) -- animation
	for player in self.game:players() do player.hand:update(dt) end
	local animation_done = grid:isSettled() --  tween-from-top is done
	if animation_done then
		grid:dropColumns()
		game.current_phase = "Gravity"
	end
end

function Phase:applyGravity(dt)
	local game = self.game
	local grid = game.grid
	grid:updateGravity(dt) -- animation
	for player in self.game:players() do player.hand:update(dt) end
	if grid:isSettled() then
		game.particles.wordEffects.clear(game.particles)
		for player in game:players() do player:afterGravity() end
		for i = 1, grid.columns do --checks if no_rush should be possible again
			if not self.no_rush[i] then
				if not grid[8][i].gem  then
					self.no_rush[i] = true
				end
			end
		end
		game.current_phase = "GetMatchedGems"
	end
end

function Phase:getMatchedGems(dt)
	local _, matches = self.game.grid:getMatchedGems() -- sets is_horizontal/is_vertical flags for matches
	if matches > 0 then
		self.game.current_phase = "FlagGems"
	else
		self.game.current_phase = "ResolvedMatches"
	end
end

-- flag above gems, destroy matched gems, and generate the exploding gem particles
function Phase:flagGems(dt)
	local game = self.game
	local grid = game.grid

	if self.garbage_this_round then
		local diff = game.p1.garbage_rows_created - game.p2.garbage_rows_created
		grid:setGarbageMatchFlags(diff)
		self.garbage_this_round = false
		game.p1.garbage_rows_created, game.p2.garbage_rows_created = 0		
	end

	local gem_table = grid:getMatchedGems() -- sets h/v flags
	grid:flagMatchedGems() -- sets flags
	for player in game:players() do player:beforeMatch(gem_table) end
	self.matched_this_round = grid:checkMatchedThisTurn()
	grid:destroyMatchedGems(game.scoring_combo)
	game.current_phase = "MatchAnimations"
end

-- wait for gem explode animation
function Phase:matchAnimations(dt)
	for player in self.game:players() do player.hand:update(dt) end	
	
	if self.should_call_char_ability_this_phase then
		for player in self.game:players() do
			player:duringMatchAnimation()
		end	
		self.should_call_char_ability_this_phase = false
	end

	if self.game.particles:getNumber("GemImage") == 0 then
		if self.after_match_delay == 0 then
			self.game.current_phase = "ResolvingMatches"
			self.after_match_delay = self.game.GEM_FADE_FRAMES
			self.should_call_char_ability_this_phase = true
		else
			self.after_match_delay = self.after_match_delay - 1
		end
	end
end

function Phase:resolvingMatches(dt)
	local grid = self.game.grid
	local gem_table = grid:getMatchedGems()

	for player in self.game:players() do player:afterMatch(gem_table) end
	self.game.scoring_combo = self.game.scoring_combo + 1
	if not self.matched_this_round[1] then grid:removeAllGemOwners(1) end
	if not self.matched_this_round[2] then grid:removeAllGemOwners(2) end
	grid:dropColumns()
	grid:updateGrid()
	self.game.current_phase = "Gravity"
end

function Phase:resolvedMatches(dt)
	local game = self.game
	local grid = game.grid
	if self.should_call_char_ability_this_phase then 
		for player in game:players() do
			player:afterAllMatches()
		end
		self.should_call_char_ability_this_phase = false
	end
	if game.particles:getCount("onscreen", "Damage", 1) + game.particles:getCount("onscreen", "Damage", 2) > 0 then
		for player in game:players() do player.hand:update(dt) end
	else	-- all damage particles finished
		for player in game:players() do
			player.hand:update(dt)
			player.place_type = "normal"
		end
		game.scoring_combo = 0
		game.grid:setAllGemOwners(0)
		for i = 1, grid.columns do --checks if should generate no rush
			if self.no_rush[i] then
				if grid[grid.RUSH_ROW][i].gem then
					game.particles.words.generateNoRush(self.game, i)
					self.no_rush[i] = false	
				end
			end
		end
		game.current_phase = "PlatformSpinDelay"
		self.should_call_char_ability_this_phase = true
	end
end

function Phase:platformSpinDelay(dt)
	for player in self.game:players() do player.hand:update(dt) end
	if self.platform_spin_delay_frames > 0 then
		for player in self.game:players() do player.hand:update(dt) end
		self.platform_spin_delay_frames = self.platform_spin_delay_frames - 1
	else
		self.platform_spin_delay_frames = self.INIT_PLATFORM_SPIN_DELAY_FRAMES
		self.game.current_phase = "DestroyDamagedPlatforms"
	end
end

function Phase:destroyDamagedPlatforms(dt)
	local game = self.game
	local grid = game.grid
	local max_delay = 0
	for player in game:players() do
		local arrival_frames = player.hand:destroyDamagedPlatforms()
		for _, delay in pairs(arrival_frames) do
			game.queue:add(delay, grid.addBottomRow, grid, player)
			max_delay = math.max(max_delay, delay)
			self.garbage_this_round = true
		end
	end

	game.current_phase = "PlatformsExploding"
end

function Phase:platformsExploding(dt)
	local game = self.game
	for player in game:players() do player.hand:update(dt) end
	if game.particles:getNumber("ExplodingPlatform") == 0 then
		game.particles:clearCount()	-- clear here so the platforms display redness/spin correctly
		game.current_phase = "GarbageRowCreation"
	end
end

function Phase:garbageRowCreation(dt)
	local game = self.game
	local grid = game.grid

	for player in game:players() do player.hand:update(dt) end
	grid:updateGravity(dt)

	if game.particles:getNumber("GarbageParticles") == 0 and self.should_call_char_ability_this_phase then
		for player in game:players() do
			player:whenCreatingGarbageRow()
		end
		self.should_call_char_ability_this_phase = false
	end

	if grid:isSettled() and game.particles:getNumber("GarbageParticles") == 0 then
		for player in game:players() do
			player.hand:getNewTurnPieces()
			player.hand:clearDamage()
			player:resetMP()
		end
		game.current_phase = "PlatformsMoving"
		self.should_call_char_ability_this_phase = true
	end
end

function Phase:platformsMoving(dt)
	local game = self.game
	local grid = game.grid

	local handsettled = true
	for player in game:players() do
		player.hand:update(dt)
		if not player.hand:isSettled() then handsettled = false end
	end

	grid:updateGravity(dt)

	if handsettled then	
		if self.garbage_this_round then
			game.current_phase = "Gravity"
		else
			game.current_phase = "Cleanup"
		end
	end
end

function Phase:cleanup(dt)
	local game = self.game
	local grid = game.grid
	local p1, p2 = game.p1, game.p2

	for i = 1, grid.columns do --checks if should generate no rush
		if self.no_rush[i] then
			if grid[grid.RUSH_ROW][i].gem then
				game.particles.words.generateNoRush(self.game, i)
				self.no_rush[i] = false	
			end
		end
	end

	grid:updateGrid()
	for player in game:players() do player:cleanup() end
	game.ai:newTurn()
	self.garbage_this_round = false
	p1.dropped_piece, p2.dropped_piece = false, false
	p1.played_pieces, p2.played_pieces = {}, {}
	game.finished_getting_pieces = false
	grid:setAllGemOwners(0)
	grid:setAllGemReadOnlyFlags(false)

	for player in game:players() do player.hand:endOfTurnUpdate() end

	if grid:getLoser() then
		game.current_phase = "GameOver"
	elseif game.type == "Netplay" then
		game.current_phase = "Sync"
	else
		game:newTurn()
	end
end

function Phase:sync(dt)
	self.game.client:newTurn()
	self.game:newTurn()
	-- If disconnected by server, change to vs AI
	if not self.game.client.connected then
		self.game.type = "1P"
		print("Disconnected from server :( changing to 1P mode")
		self.game:newTurn()
	end
end

function Phase:gameOver(dt)
	local game = self.game
	if self.game_is_over then
		if self.gameover_pause == 0 then
			if game.type == "Netplay" then
				game.statemanager:switch(require "gs_lobby")
			elseif game.type == "1P" then
				game.statemanager:switch(require "gs_charselect")
			end
		else
			self.gameover_pause = self.gameover_pause - 1
		end
	else
		game.grid:animateGameOver(game.grid:getLoser())
		self.game_is_over = true
		if game.type == "Netplay" then game.client:endMatch() end
	end
end

Phase.lookup = {
	Intro = Phase.intro,
	Action = Phase.action,
	Resolve = Phase.resolve,
	SuperFreeze = Phase.superFreeze,
	BeforeGravity = Phase.beforeGravity,
	GemTween = Phase.applyGemTween,
	Gravity = Phase.applyGravity,
	GetMatchedGems = Phase.getMatchedGems,
	FlagGems = Phase.flagGems,
	MatchAnimations = Phase.matchAnimations,
	ResolvingMatches = Phase.resolvingMatches,
	ResolvedMatches = Phase.resolvedMatches,
	PlatformSpinDelay = Phase.platformSpinDelay,
	DestroyDamagedPlatforms = Phase.destroyDamagedPlatforms,
	PlatformsExploding = Phase.platformsExploding,
	GarbageRowCreation = Phase.garbageRowCreation,
	PlatformsMoving = Phase.platformsMoving,
	Cleanup = Phase.cleanup,
	Sync = Phase.sync,
	GameOver = Phase.gameOver
}

function Phase:run(...)
	if not self.game.paused then
		local todo = Phase.lookup[self.game.current_phase]
		assert(todo, "You did a typo for the current phase idiot - " .. self.game.current_phase)
		todo(self, ...)
		self.game.queue:update()
	end
end

return common.class("Phase", Phase)
