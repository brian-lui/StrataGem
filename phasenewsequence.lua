-- handles the main game phases

require 'inits'
local hand = require 'hand'
local ai = require 'ai'
local stage = game.stage
local particles = game.particles
local anims = require 'anims'
local inspect = require 'inspect'

-------------------------------------------------------------------------------
------------------ Here are some useful functions for netplay -----------------
-------------------------------------------------------------------------------

-- split out updateGrid from isSettled so it's a pure function

local phase = {}

function instantCalculateGamestate()
	hand.endOfTurnUpdate() -- pure state. sets new player.pieces_to_get, assigns pie damage
	anims.putPendingAtTop() -- pure animations
	stage.grid:dropColumns() -- pure state
	stage.grid:updateGravity(dt) -- pure anims: gem:landedInStagingArea, gem:landedInGrid (also sets self.no_yoshi_particle which is part of animations)
	for player in game:players() do
		local anims = player:afterGravity() -- pure state now :)
		for i = 1, #anims do queue.add(anims[i][1] + thisturnframesintothefuture, anims[i][2], unpack(anims[i], 3)) end -- pure anims
	end
	stage.grid:flagMatchedGems() -- pure state, changes gem flags
	stage.grid:generateMatchExplodingGems() -- pure animations

	for player in game:players() do player:beforeMatch(gem_table) end -- BAD! Need to separate into two functions probably
	local gem_table = stage.grid:getMatchedGems() -- BAD! adds this_gem.vertical/horizontal. Otherwise pure function. Definitely need to separate this out into "addGemHorizontalityAndVerticality"
	game.scoring_combo = game.scoring_combo + 1 -- pure state
	for player in game:players() do player:duringMatch(gem_table) end -- BAD! Need to separate into two functions probably
	local p1dmg, p2dmg, p1super, p2super = stage.grid:calculateScore() -- pure function
	local p1_matched, p2_matched = stage.grid:checkMatchedThisTurn() -- pure function
	if not p1_matched then stage.grid:removeAllGemOwners(p1) end -- pure state, removes ownership flags. prob should run this before p1/p2 specific abilities
	if not p2_matched then stage.grid:removeAllGemOwners(p2) end -- pure state, removes ownership flags. prob should run this before p1/p2 specific abilities
	p1:addSuper(p1super) -- pure state
	p2:addSuper(p2super) -- pure state
	stage.grid:generateMatchParticles() -- pure animations
	stage.grid:removeMatchedGems() -- pure state
	hand.addDamage(p1, p2dmg) -- pure state
	hand.addDamage(p2, p1dmg) -- pure state
	if still matches u can make then go back to updateGravity line otherwise continue -- don't run the player stuff twice though
	for player in game:players() do player:afterMatch() end -- BAD! Need to separate into two functions probably
	game.scoring_combo = 0 -- pure state
	stage.grid:setAllGemOwners(0) -- pure state
	hand.update(dt) -- VERY BAD!
		-- state: destroy garbage if it moved to hand[0].y
		-- anims: player.hand[i].piece:gradualMove, gem platforms gradualmove, player.hand.garbage.move, gemplatform:update
	p1.place_type, p2.place_type = "normal", "normal" -- pure state
	stage.grid:dropColumns()
	stage.grid:updateGravity(dt) -- call this after resolving matches because ???

	if not game.finished_getting_pieces then hand.getNewTurnPieces() end -- fuck
	if hand.isSettled(p1) and hand.isSettled(p2) then -- fuck off we should settle them instantly
		hand.update(dt) -- activates cleanupHand, which may add penalty rows
		instantly settle grid
		local _, matches = stage.grid:getMatchedGems()
		if matches > 0 then
			go back to updateGravity line otherwise continue
		end
	stage.grid:updateGrid() -- fuck off it's this again
	ai.finished = false -- pure state
	p1.pieces_fallen, p2.pieces_fallen = 0, 0 -- pure state
	p1.dropped_piece, p2.dropped_piece = false, false -- pure state
	p1.played_pieces, p2.played_pieces = {}, {} -- pure state
	game.finished_getting_pieces = false -- pure state
	stage.grid:setAllGemOwners(0) -- pure state
	if stage.grid:getLoser() then gameover fuckers -- ok
	game:newTurn() -- pure state

	return gamestate, {all the instructions for the client to play}
end
