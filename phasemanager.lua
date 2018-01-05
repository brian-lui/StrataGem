local love = _G.love

-- handles the main game phases

local common = require "class.commons"

local PhaseManager = {}

function PhaseManager:init(game)
	self.game = game
	self.INIT_TIME_TO_NEXT = 430 -- frames in each action phase
	self.INIT_PLATFORM_SPIN_DELAY_FRAMES = 30 -- frames to animate platforms exploding
	self.INIT_SUPER_PAUSE = 90 -- frames to animate super activation
	self.time_to_next = 430
	self.super_play = nil
	self.super_pause = 0
	self.platform_spin_delay_frames = 30
	self.no_rush = {}
	for i = 1, 8 do --the 8 should be grid.column, but grid isn't initilized yet I don't think
		self.no_rush[i] = true --whether no_rush is eligible for animation
	end
	self.after_match_delay = game.GEM_FADE_FRAMES
	self.matched_this_round = {false, false} -- p1 made a match, p2 made a match
	self.game_is_over = false
	self.INIT_GAMEOVER_PAUSE = 180
	self.gameover_pause = 180
end

function PhaseManager:reset()
	self.time_to_next = self.INIT_TIME_TO_NEXT
	self.super_play = nil
	self.super_pause = 0
	self.platform_spin_delay_frames = self.INIT_PLATFORM_SPIN_DELAY_FRAMES
	self.no_rush = {}
	for i = 1, 8 do
		self.no_rush[i] = true
	end
	self.after_match_delay = self.game.GEM_FADE_FRAMES
	self.matched_this_round = {false, false} -- p1 made a match, p2 made a match
	self.game_is_over = false
	self.gameover_pause = 180
	self.game.grid:clearGameOverAnims()
end

function PhaseManager:intro(dt)
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
		game.sound:newSFX("sfx_fountaingo")
		game.phase = "Action"
	end
end

function PhaseManager:action(dt)
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
		game.phase = "Resolve"

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

function PhaseManager:resolve(dt)
	local game = self.game
	if game.me_player.place_type == nil then print("PLACE TYPE BUG") end
	for player in game:players() do player.hand:afterActionPhaseUpdate() end
	game.grid:updateRushPriority()
	game.frozen = true
	game.phase = "SuperFreeze"
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
function PhaseManager:superFreeze(dt)
	self.super_play = self.super_play or superPlays(self)

	if self.super_pause > 0 then
		self.super_pause = self.super_pause - 1
	elseif self.super_play[1] then
		self.super_play[1]:superSlideIn()
		self.super_pause = self.INIT_SUPER_PAUSE
		table.remove(self.super_play, 1)
	else
		self.super_play = nil
		self.game.phase = "GemTween"
	end
end

function PhaseManager:applyGemTween(dt)
	local game = self.game
	local grid = game.grid
	grid:updateGravity(dt) -- animation
	for player in self.game:players() do player.hand:update(dt) end
	local animation_done = grid:isSettled() --  tween-from-top is done
	if animation_done then
		grid:dropColumns()
		game.phase = "Gravity"
	end
end

function PhaseManager:applyGravity(dt)
	local game = self.game
	local grid = game.grid
	grid:updateGravity(dt) -- animation
	for player in self.game:players() do player.hand:update(dt) end
	if grid:isSettled() then
		game.particles.wordEffects.clear(game.particles)
		for player in game:players() do
			player:afterGravity()
		end
		for i = 1, grid.columns do --checks if no_rush should be possible again
			if not self.no_rush[i] then
				if not grid[8][i].gem  then
					self.no_rush[i] = true
				end
			end
		end
		game.phase = "GetMatchedGems"
	end
end

function PhaseManager:getMatchedGems(dt)
	local _, matches = self.game.grid:getMatchedGems() -- sets horizontal/vertical flags for matches
	if matches > 0 then
		self.game.phase = "FlagGems"
	else
		self.game.phase = "ResolvedMatches"
	end
end

-- flag above gems, destroy matched gems, and generate the exploding gem particles
function PhaseManager:flagGems(dt)
	local grid = self.game.grid
	local gem_table = self.game.grid:getMatchedGems() -- sets h/v flags

	grid:flagMatchedGems() -- state
	for player in self.game:players() do player:beforeMatch(gem_table) end
	self.matched_this_round = grid:checkMatchedThisTurn()
	grid:destroyMatchedGems(self.game.scoring_combo)
	self.game.phase = "MatchAnimations"
end

-- wait for gem explode animation
function PhaseManager:matchAnimations(dt)
	for player in self.game:players() do player.hand:update(dt) end	
	if self.game.particles:getNumber("GemImage") == 0 then
		if self.after_match_delay == 0 then
			self.game.phase = "ResolvingMatches"
			self.after_match_delay = self.game.GEM_FADE_FRAMES
		else
			self.after_match_delay = self.after_match_delay - 1
		end
	end
end

function PhaseManager:resolvingMatches(dt)
	local grid = self.game.grid
	local gem_table = grid:getMatchedGems()

	for player in self.game:players() do player:afterMatch(gem_table) end
	self.game.scoring_combo = self.game.scoring_combo + 1
	if not self.matched_this_round[1] then grid:removeAllGemOwners(1) end
	if not self.matched_this_round[2] then grid:removeAllGemOwners(2) end
	grid:dropColumns()
	grid:updateGrid()
	self.game.phase = "Gravity"
end

function PhaseManager:resolvedMatches(dt)
	local game = self.game
	local grid = game.grid
	if game.particles:getCount("onscreen", "Damage", 1) + game.particles:getCount("onscreen", "Damage", 2) > 0 then
		for player in game:players() do player.hand:update(dt) end
	else	-- all damage particles finished
		for player in game:players() do
			player:afterAllMatches()
			player.hand:update(dt)
			player.place_type = "normal"
		end
		game.scoring_combo = 0
		game.grid:setAllGemOwners(0)
		for i = 1, grid.columns do --checks if should generate no rush
			if self.no_rush[i] then
				if grid[game.RUSH_ROW][i].gem then
					game.particles.words.generateNoRush(self.game, i)
					self.no_rush[i] = false	
				end
			end
		end
		game.phase = "PlatformSpinDelay"
	end
end

function PhaseManager:platformSpinDelay(dt)
	for player in self.game:players() do player.hand:update(dt) end
	if self.platform_spin_delay_frames > 0 then
		for player in self.game:players() do player.hand:update(dt) end
		self.platform_spin_delay_frames = self.platform_spin_delay_frames - 1
	else
		self.platform_spin_delay_frames = self.INIT_PLATFORM_SPIN_DELAY_FRAMES
		self.game.phase = "DestroyPlatforms"
	end
end

function PhaseManager:destroyDamagedPlatforms(dt)
	for player in self.game:players() do player.hand:destroyDamagedPlatforms() end
	self.game.phase = "PlatformsExplodingAndGarbageAppearing"
end

function PhaseManager:platformsExplodingAndGarbageAppearing(dt)
	local game = self.game
	if game.particles:getNumber("ExplodingPlatform") == 0 then
		for player in game:players() do
			player.hand:getNewTurnPieces()
			player.hand:update(dt)
			player:resetMP()
		end
		game.particles:clearCount()	-- clear here so the platforms display redness/spin correctly
		game.phase = "PlatformsMoving"
	end
end

function PhaseManager:platformsMoving(dt)
	local game = self.game
	local grid = game.grid
	local handsettled = true

	for player in game:players() do
		player.hand:update(dt)
		if not player.hand:isSettled() then handsettled = false end
	end

	grid:updateGravity(dt)

	if handsettled then
		for player in game:players() do	-- TODO: check if we can delete this
			player.hand:update(dt)
		end

		if grid:isSettled() then
		-- garbage can possibly push gems up, creating matches.
			local _, matches = grid:getMatchedGems()
			if matches > 0 then
				game.phase = "Gravity"
			else
				for i = 1, grid.columns do --checks if should generate no rush
					if self.no_rush[i] then
						if grid[game.RUSH_ROW][i].gem then
							game.particles.words.generateNoRush(self.game, i)
							self.no_rush[i] = false	
						end
					end
				end
				game.phase = "Cleanup"
			end
		end
	end
end

function PhaseManager:cleanup(dt)
	local game = self.game
	local grid = game.grid
	local p1, p2 = game.p1, game.p2

	grid:updateGrid()
	for player in game:players() do player:cleanup() end
	game.ai:newTurn()
	p1.pieces_fallen, p2.pieces_fallen = 0, 0
	p1.dropped_piece, p2.dropped_piece = false, false
	p1.played_pieces, p2.played_pieces = {}, {}
	game.finished_getting_pieces = false
	grid:setAllGemOwners(0)

	for player in game:players() do player.hand:endOfTurnUpdate() end

	if grid:getLoser() then
		game.phase = "GameOver"
	elseif game.type == "Netplay" then
		game.phase = "Sync"
	else
		game:newTurn()
	end
end

function PhaseManager:sync(dt)
	self.game.client:newTurn()
	self.game:newTurn()
	-- If disconnected by server, change to vs AI
	if not self.game.client.connected then
		self.game.type = "1P"
		print("Disconnected from server :( changing to 1P mode")
		self.game:newTurn()
	end
end

function PhaseManager:gameOver(dt)
	local game = self.game
	if self.game_is_over then
		if self.gameover_pause == 0 then
			self:reset()
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

PhaseManager.lookup = {
	Intro = PhaseManager.intro,
	Action = PhaseManager.action,
	Resolve = PhaseManager.resolve,
	SuperFreeze = PhaseManager.superFreeze,
	GemTween = PhaseManager.applyGemTween,
	Gravity = PhaseManager.applyGravity,
	GetMatchedGems = PhaseManager.getMatchedGems,
	FlagGems = PhaseManager.flagGems,
	MatchAnimations = PhaseManager.matchAnimations,
	ResolvingMatches = PhaseManager.resolvingMatches,
	ResolvedMatches = PhaseManager.resolvedMatches,
	PlatformSpinDelay = PhaseManager.platformSpinDelay,
	DestroyPlatforms = PhaseManager.destroyDamagedPlatforms,
	PlatformsExplodingAndGarbageAppearing = PhaseManager.platformsExplodingAndGarbageAppearing,
	PlatformsMoving = PhaseManager.platformsMoving,
	Cleanup = PhaseManager.cleanup,
	Sync = PhaseManager.sync,
	GameOver = PhaseManager.gameOver
}

function PhaseManager:run(...)
	if not self.game.paused then
		local todo = PhaseManager.lookup[self.game.phase]
		assert(todo, "You did a typo for the current phase idiot - " .. self.game.phase)
		todo(self, ...)
		self.game.queue:update()
	end
end

return common.class("PhaseManager", PhaseManager)
