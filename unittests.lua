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

	row = row + 6
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

-- patterns here

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

-- other test things here
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
				x = hand[i].x,
				y = hand[i].y,
			})
		end
	end
end

local function resetWithSeed(game, rng_seed)
	game:start("1P", "heath", "walter", "Clouds", rng_seed, 1)
end

local function displayNoRush(game)
	local column = 6
	game.particles.words.generateNoRush(game, column)
end

local Unittests = {
	garbageMatch = garbageMatch,
	multiCombo = multiCombo,
	overflow = overflow,
	allRedGems = allRedGems,
	shuffleHands = shuffleHands,
	displayNoRush = displayNoRush,
	resetWithSeed = resetWithSeed,
	p2VerticalMatch = p2VerticalMatch,
}

return common.class("Unittests", Unittests)
