-- You can make some patterns to test bugs
local NOP = function() end
local common = require "class.commons"
local image = require 'image'
local Gem = require 'gem'
local Piece = require 'piece'

local colorAliases = {
	r = "red",
	red = "red",
	b = "blue",
	blue = "blue",
	g = "green",
	green = "green",
	y = "yellow",
	yellow = "yellow"
}

-------------------------------------------------------------------------------
------------------------------ TEST GEM PATTERNS ------------------------------
-------------------------------------------------------------------------------

-- rows is from 8 at the top to 1 at the bottom
local function n(self, row, column, color, owner)
	owner = owner or 0
	color = colorAliases[color:lower()] or "red"
	if type(row) ~= "number" or type(column) ~= "number" then
		print("row or column not a number!")
		return
	end
	if row % 1 ~= 0 or column % 1 ~= 0 then
		print("row or column not an integer!")
		return
	end
	if row < 1 or row > 8 then
		print("row out of bounds! 1 = bottom, 8 = top")
		return
	end
	if column < 1 or column > 8 then
		print("column out of bounds!")
		return
	end

	row = row + 12
	local x, y = self.grid.x[column], self.grid.y[row]
	self.grid[row][column].gem = common.instance(Gem, self, x, y, color)
	if owner > 0 then
		self.grid[row][column].gem:addOwner(owner)
	end
end

local function nrow(game, row, colors)
	if type(colors) ~= "string" or #colors ~= 8 then
		love.errhand("nrow() received invalid string: \"" .. tostring(colors) .. "\"")
	end
	for i = 1, 8 do
		local c = colors:sub(i, i)
		if c ~= " " then
			n(game, row, i, c)
		end
	end
end

---------------------------------- PATTERNS -----------------------------------

-- test Walter passive
local function testWalterPassive(game)
	nrow(game, 3, " GYR    ")
	nrow(game, 4, " GYR    ")
	nrow(game, 5, "YRGB    ")
	nrow(game, 6, "YRGB    ")
	nrow(game, 7, "RGBY    ")
	nrow(game, 8, "RGBY    ")
end

-- test garbage matches
local function garbageMatch(game)
	nrow(game, 7, " YRRBBY ")
	nrow(game, 8, " GBBRRG ")
end

-- test big combos
local function multiCombo(game)
	nrow(game, 4, "     R G")
	nrow(game, 5, "    RBBR")
	nrow(game, 6, "  GRBYYR")
	nrow(game, 7, " RRGBGGY")
	nrow(game, 8, " YYRGBBR")
end

-- test match end/basin overflow
local function overflow(game)
	nrow(game, 1, "B       ")
	nrow(game, 2, "B       ")
	nrow(game, 3, "RG      ")
	nrow(game, 4, "YY      ")
	nrow(game, 5, "RRG     ")
	nrow(game, 6, "BGB     ")
	nrow(game, 7, "BRR     ")
	nrow(game, 8, "RGGY    ")
end

local function p2VerticalMatch(game)
	nrow(game, 8, "    BRBB")
	for i = 1, 5 do
		if game.p2.hand[i].piece then
			for _, gem in pairs(game.p2.hand[i].piece.gems) do
				gem:setColor("red")
			end
		end
	end
end

local function flagPropogateProblem(game)
	nrow(game, 6, "     R  ")
	nrow(game, 7, "    BRGR")
	nrow(game, 8, "    GGRY")
end

-------------------------------------------------------------------------------
------------------------------ TEST OTHER THINGS ------------------------------
-------------------------------------------------------------------------------

local function allRedGems(game)
	local hands = {game.p1.hand, game.p2.hand}
	for _, hand in pairs(hands) do
		for i = 1, 5 do
			if hand[i].piece then
				for _, gem in pairs(hand[i].piece.gems) do
					gem:setColor("red")
				end
			end
		end
	end
end

local function shuffleHands(game)
	local hands = {game.p1.hand, game.p2.hand}
	for _, hand in pairs(hands) do
		for i = 1, 5 do
			hand[i].piece = common.instance(Piece, game, {
				location = hand[i],
				hand_idx = i,
				owner = hand.owner,
				owner_num = hand.owner.player_num,
				x = hand[i].x,
				y = hand[i].y,
			})
		end
	end
end

local function resetGame(game)
	game:start("1P", "walter", "heath", "checkmate", nil, 1)
end

local function displayNoRush(game)
	local column = 6
	game.particles.words.generateNoRush(game, column)
end

local function tweenPlacedGemDown(game)
	local placedgems = game.particles.allParticles.PlacedGem
	for _, v in pairs(placedgems) do
		v:tweenDown()
	end
end

local function tweenPlacedGemUp(game)
	local placedgems = game.particles.allParticles.PlacedGem
	for _, v in pairs(placedgems) do
		v:tweenUp()
	end
end

local function addBottomRowP1(game)
	game.grid:addBottomRow(p1)
	for g in grid:gems() do g.x, g.y = g.target_x, g.target_y end
end

local function addBottomRowP2(game)
	game.grid:addBottomRow(p2)
	for g in grid:gems() do g.x, g.y = g.target_x, g.target_y end
end

local function printSaveDirectory(game)
	print(love.filesystem.getSaveDirectory())
end

local function skipToTurnEnd(game)
	game.phase.time_to_next = 1
end

local function addDamageP1(game)
	game.p1:addDamage(1)
end

local function addDamageP2(game)
	game.p2:addDamage(1)
end

local function addSuperAndBurst(game)
	for player in game:players() do
		player.cur_burst = math.min(player.cur_burst + 1, player.MAX_BURST)
		player:addSuper(10000)
		player:resetMP()
	end
end

local function showAnimationCanvas(game)
	game.canvas[6]:renderTo(function() love.graphics.clear() end)
end

local function showDebugInfo(game)
	game.debug_drawGemOwners = not game.debug_drawGemOwners
	game.debug_drawParticleDestinations = not game.debug_drawParticleDestinations
	game.debug_drawGamestate = not game.debug_drawGamestate
	game.debug_drawDamage = not game.debug_drawDamage
	game.debug_drawGrid = not game.debug_drawGrid	
	if game.debug_overlay then
		game.debug_overlay = nil
	else
		game.debug_overlay = function() return game.current_phase end
	end
end

local function toggleSlowdown(game)
	if game.timeStep == 1/60 then
		game.timeStep = 1/5
	elseif game.timeStep == 1/5 then
		game.timeStep = 2
	else
		game.timeStep = 1/60
	end
end

local function testGemImage(game)
	local stage = game.stage
	game.grid:animateGameOver(2)	
end

local function makeAGarbage(game)
	game.grid:addBottomRow(game.p2)
	game.grid:updateGrid()
	for i = 1, 60 do
		game.queue:add(i, game.grid.updateGravity, game.grid, 1/60)
	end
end

local player_toggle
local function maxDamage(game)
	if player_toggle ~= game.p1 then
		game.p2:addDamage(20)
		player_toggle = game.p1
	else
		game.p1:addDamage(20)
		player_toggle = game.p2
	end
end

local function healingParticleGenerate(game)
	game.particles.healing.generate{
		game = game,
		x = 1000,
		y = 400,
		owner = game.p1,
		delay = 15,
	}
end

local function healingCloudGenerate(game)
	game.p1:_makeCloud(3, 1)
end
local function healingTwinkleGenerate(game)
	game.particles.healing.generateTwinkle(game, game.p1.hand[2].platform)
end

local function glowDestroyTest(game)
	local grid = game.grid
	grid:updateGrid()
	grid:destroyGem{
		gem = grid[20][1].gem,
		glow_delay = 120,
	}
end

local super_toggle_state = 0
local function superToggle(game)
	for player in game:players() do
		player:addSuper(10000)
		player:resetMP()
	end

	if super_toggle_state == 0 then
		game.p1.supering = true
		game.p2.supering = false
		super_toggle_state = 1
	elseif super_toggle_state == 1 then
		game.p1.supering = false
		game.p2.supering = true
		super_toggle_state = 2
	elseif super_toggle_state == 2 then
		game.p1.supering = true
		game.p2.supering = true
		super_toggle_state = 3
	elseif super_toggle_state == 3 then
		game.p1.supering = false
		game.p2.supering = false
		super_toggle_state = 0
	end
end

local function heathFireFadeTest(game)
	game.p2.particle_fx.smallFire.generateSmallFireFadeTest(game, game.p2, 8)
end

local function gailPetalTest(game)
	game.p1.particle_fx.testPetal.generate(game, game.p1)
end

local function toggleScreencaps(game)
	if game.debug_screencaps then
		print("Screencaps off")
		game.debug_screencaps = false
	else
		print("Screencaps saving to " .. love.filesystem.getSaveDirectory())
		game.debug_screencaps = true
	end
end
local Unittests = {
	q = garbageMatch,
	w = multiCombo,
	e = overflow,
	r = p2VerticalMatch,
	t = allRedGems,
	y = shuffleHands,
	u = resetGame,
	i = displayNoRush,
	o = tweenPlacedGemDown,
	p = tweenPlacedGemUp,
	a = gailPetalTest, -- gail petal
	s = addBottomRowP2,
	d = toggleScreencaps,
	f = skipToTurnEnd,
	g = addDamageP1,
	h = addDamageP2,
	j = addSuperAndBurst,
	k = superToggle,
	l = showDebugInfo,
	z = heathFireFadeTest, -- heath fire
	x = toggleSlowdown,
	c = testGemImage,
	v = flagPropogateProblem,
	b = makeAGarbage,
	n = testWalterPassive,
	m = glowDestroyTest,
}

return common.class("Unittests", Unittests)
