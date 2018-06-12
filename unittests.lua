-- You can make some patterns to test bugs
local common = require "class.commons"
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
	self.grid[row][column].gem = Gem:create{
		game = self,
		x = x,
		y = y,
		color = color,
	}

	if owner > 0 then self.grid[row][column].gem:addOwner(owner) end
end

local function ndel(game, row, column)
	game.grid[row + 12][column].gem = false
end

local function nrow(game, row, colors)
	if type(colors) ~= "string" or #colors ~= 8 then
		love.errhand("nrow() received invalid string: \"" .. tostring(colors) .. "\"")
	end
	for i = 1, 8 do
		local c = colors:sub(i, i)
		if c == " " then
			ndel(game, row, i)
		else
			n(game, row, i, c)
		end
	end
end

---------------------------------- PATTERNS -----------------------------------

local function testGreyCombo(game)
	nrow(game, 1, "        ")
	nrow(game, 2, "        ")
	nrow(game, 3, "        ")
	nrow(game, 4, "        ")
	nrow(game, 5, "    R   ")
	nrow(game, 6, "    R   ")
	nrow(game, 7, "   BB   ")
	nrow(game, 8, "   YR   ")
	game.grid:updateGrid()
end

local function testWalterPassive(game)
	nrow(game, 1, "        ")
	nrow(game, 2, "        ")
	nrow(game, 3, "    R   ")
	nrow(game, 4, "    B   ")
	nrow(game, 5, "    R   ")
	nrow(game, 6, "    BGYY")
	nrow(game, 7, "RG YYBGR")
	nrow(game, 8, "RG YYBGR")
	game.grid:updateGrid()
end

local function testComboPropagate(game)
	nrow(game, 1, "        ")
	nrow(game, 2, "        ")
	nrow(game, 3, "        ")
	nrow(game, 4, "        ")
	nrow(game, 5, "  G    R")
	nrow(game, 6, "Y Y   BB")
	nrow(game, 7, "RRG  YGR")
	nrow(game, 8, "RRG  GYR")
	game.grid:updateGrid()
end

local function testHeathFireMovement(game)
	nrow(game, 1, "        ")
	nrow(game, 2, "        ")
	nrow(game, 3, "GG      ")
	nrow(game, 4, "YY      ")
	nrow(game, 5, "RR      ")
	nrow(game, 6, "BB      ")
	nrow(game, 7, "RR      ")
	nrow(game, 8, "GG      ")
	game.grid:updateGrid()
end

-- test vertical chain combo
local function testVerticalCombo(game)
	nrow(game, 1, "        ")
	nrow(game, 2, "        ")
	nrow(game, 3, "   R    ")
	nrow(game, 4, "   R    ")
	nrow(game, 5, "   G    ")
	nrow(game, 6, "   GB   ")
	nrow(game, 7, "   RR   ")
	nrow(game, 8, "   YY   ")
	game.grid:updateGrid()
end

-- test garbage matches
local function garbageMatch(game)
	nrow(game, 1, "        ")
	nrow(game, 2, "        ")
	nrow(game, 3, "        ")
	nrow(game, 4, "        ")
	nrow(game, 5, "        ")
	nrow(game, 6, "        ")
	nrow(game, 7, " YRRBBY ")
	nrow(game, 8, " GBBRRG ")
	game.grid:updateGrid()
end

-- test big combos
local function multiCombo(game)
	nrow(game, 1, "        ")
	nrow(game, 2, "        ")
	nrow(game, 3, "        ")
	nrow(game, 4, "     R G")
	nrow(game, 5, "    RBBR")
	nrow(game, 6, "  GRBYYR")
	nrow(game, 7, " RRGBGGY")
	nrow(game, 8, " YYRGBBR")
	game.grid:updateGrid()
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
	game.grid:updateGrid()
end

local function p2VerticalMatch(game)
	nrow(game, 1, "        ")
	nrow(game, 2, "        ")
	nrow(game, 3, "        ")
	nrow(game, 4, "        ")
	nrow(game, 5, "        ")
	nrow(game, 6, "        ")
	nrow(game, 7, "        ")
	nrow(game, 8, "    BRBB")
	for i = 1, 5 do
		if game.p2.hand[i].piece then
			for _, gem in pairs(game.p2.hand[i].piece.gems) do
				gem:setColor("red")
			end
		end
	end
end

local function flagPropagateProblem(game)
	nrow(game, 1, "        ")
	nrow(game, 2, "        ")
	nrow(game, 3, "        ")
	nrow(game, 4, "        ")
	nrow(game, 5, "        ")
	nrow(game, 6, "     R  ")
	nrow(game, 7, "    BRGR")
	nrow(game, 8, "    GGRY")
	game.grid:updateGrid()
end

local function flagVerticalHorizontal(game)
	nrow(game, 1, "        ")
	nrow(game, 2, "        ")
	nrow(game, 3, "        ")
	nrow(game, 4, "        ")
	nrow(game, 5, "        ")
	nrow(game, 6, "        ")
	nrow(game, 7, "  Y RY  ")
	nrow(game, 8, "  R RRG ")
	game.grid:updateGrid()
end

local layouts_to_test = {
	testWalterPassive,
	testHeathFireMovement,
	testVerticalCombo,
	garbageMatch,
	multiCombo,
	overflow,
	p2VerticalMatch,
	flagPropagateProblem,
	flagVerticalHorizontal,
}
local current_layout = 1
local TOTAL_LAYOUTS = #layouts_to_test

local function changeLayout(game)
	layouts_to_test[current_layout](game)
	current_layout = current_layout % TOTAL_LAYOUTS + 1
	print("next layout", current_layout)
end
-------------------------------------------------------------------------------
------------------------------ TEST OTHER THINGS ------------------------------
-------------------------------------------------------------------------------
local function charselectScreenCPUCharToggle(game)
	if game.opponent_character == "walter" then
		game.opponent_character = "heath"
	elseif game.opponent_character == "heath" then
		game.opponent_character = "walter"
	end
end

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
			hand[i].piece = Piece:create{
				game = game,
				hand_idx = i,
				owner = hand.owner,
				player_num = hand.owner.player_num,
				x = hand[i].x,
				y = hand[i].y,
			}
		end
	end
end

local function resetGame(game)
	game:start("Singleplayer", "wolfgang", "walter", "checkmate", nil, 1)
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
		game.timeStep = 1/6
		game.debugconsole.is_pause_mode_on = true
	elseif game.timeStep == 1/6 then
		game.timeStep = 2
		game.debugconsole.is_pause_mode_on = true
	else
		game.timeStep = 1/60
		game.debugconsole.is_pause_mode_on = false
	end
end

local function testGemImage(game)
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
	end

	if super_toggle_state == 0 then
		game.p1.is_supering = true
		game.p2.is_supering = false
		super_toggle_state = 1
	elseif super_toggle_state == 1 then
		game.p1.is_supering = false
		game.p2.is_supering = true
		super_toggle_state = 2
	elseif super_toggle_state == 2 then
		game.p1.is_supering = true
		game.p2.is_supering = true
		super_toggle_state = 3
	elseif super_toggle_state == 3 then
		game.p1.is_supering = false
		game.p2.is_supering = false
		super_toggle_state = 0
	end
end

local function gailPetalTest(game)
	game.p1.fx.testPetal.generate(game, game.p1)
end

local function wolfgangLightUp(game)
	local wolf = game.p1.letters
	if not wolf.red.lighted then
		wolf.red:lightUp()
	elseif not wolf.blue.lighted then
		wolf.blue:lightUp()
	elseif not wolf.green.lighted then
		wolf.green:lightUp()
	elseif not wolf.yellow.lighted then
		wolf.yellow:lightUp()
	end
end

local function wolfgangCreate3Dog(game)
	game.p1:_turnPieceToDog(3, false)
end

local function wolfgangCreate4Dog(game)
	game.p1:_turnPieceToDog(4, true)
end
local function toggleScreencaps(game)
	if game.debugconsole.save_screencaps then
		print("Screencaps off")
		game.debugconsole.save_screencaps = false
	else
		print("Screencaps saving to " .. love.filesystem.getSaveDirectory())
		game.debugconsole.save_screencaps = true
	end
end

local function toggleDebugDisplay(game)
	game.debugconsole.display_all = not game.debugconsole.display_all
end

local function saveGamestate(game)
	local filename = "gamestate.txt"
	local gamestate = game:serializeState()
	love.filesystem.write(filename, gamestate)
	print("saved gamestate in " .. love.filesystem.getSaveDirectory() .. "/" .. filename)
end

local function loadGamestate(game)
	local filename = "gamestate.txt"
	local gamestate = love.filesystem.read(filename)
	game:deserializeState(gamestate)
	print("loaded gamestate")
end

local function p1Serialize(game)
	print(game.p1:serializeSpecials())
end

local function isGamestateSame(game)
	local current_gamestate = game:serializeState()
	game:deserializeState(current_gamestate)
	local new_gamestate = game:serializeState()
	if current_gamestate == new_gamestate then
		print("Gamestates are the same. Good job coder!")
	else
		print("Gamestates are different. Before:")
		print(current_gamestate)
		print("After:")
		print(new_gamestate)
	end
end

local Unittests = {
	f1 = saveGamestate,
	f2 = loadGamestate,
	f3 = isGamestateSame,
	q = p1Serialize,
	w = wolfgangLightUp,
	e = charselectScreenCPUCharToggle,
	r = testComboPropagate,
	t = testGreyCombo,
	y = shuffleHands,
	u = resetGame,
	i = displayNoRush,
	o = tweenPlacedGemDown,
	p = tweenPlacedGemUp,
	a = wolfgangCreate3Dog,
	s = wolfgangCreate4Dog,
	d = toggleScreencaps,
	f = skipToTurnEnd,
	g = addDamageP1,
	h = addDamageP2,
	j = addSuperAndBurst,
	k = superToggle,
	l = showDebugInfo,
	z = toggleDebugDisplay,
	x = toggleSlowdown,
	c = testGemImage,
	--v = ,
	b = makeAGarbage,
	n = changeLayout,
	m = glowDestroyTest,
}

return common.class("Unittests", Unittests)
