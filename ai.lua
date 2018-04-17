local love = _G.love
--[[
Each AI is assigned to a player on creation, replacing user input.

The AI follows the following lifecycle, called in Phase and elsewhere.

ai:evaluateActions()	Determines what action to take this turn
ai:queueAction(func, args)	Sets the currently-queued action for the ai
ai:performQueuedAction()	Performs the last action queued (ONCE)
ai:newTurn()	Resets anything that needs to reset between turns.
--]]

local common = require "class.commons"

local ai = {
	finished = nil,
	queuedFunc = nil,
	queuedArgs = nil,
	countdown = 5,	-- frames to wait before calculating move
	-- HACK: Countdown shouldn't need to exist.
}

function ai:init(game, player)
	self.game = game
	self.player = player
end
--[[
-- debug function, prints maximum score and piece drop to achieve it
local function printMaximumScore(maximum_score, possible_moves)
	print("Maximum possible score:", maximum_score)
	if maximum_score ~= 0 then
		for i = 1, #possible_moves do
			print("At orientation " .. possible_moves[i][1] .. ", piece " .. possible_moves[i][2] ..
			", column " .. possible_moves[i][3])
		end
	end
end
--]]


-- return a list of all valid pieces (excluding empty platforms)
local function enumeratePieces(player)
	local has_piece = {}
	for i = 1, player.hand_size do
		if player.hand[i].piece then
			has_piece[#has_piece+1] = i
		end
	end

	local ret = {}
	for i = 1, #has_piece do
		ret[#ret+1] = player.hand[ has_piece[i] ].piece
	end
	return ret
end

-- return a random piece from the list of all valid pieces
local function selectRandomPiece(player)
	local pieces = enumeratePieces(player)
	local ret_idx = math.random(1, #pieces)
	return pieces[ret_idx]
end

-- return a random column from player's valid columns, accounts for horizontal pieces
local function selectRandomColumn(piece, player)
	local start_col = player.start_col
	local end_col = player.end_col
	if piece.is_horizontal then end_col = end_col - 1 end
	return math.random(start_col, end_col)
end

-- takes a column index, and returns table of argument column and the next column
local function getCoords(piece, column)
	local ret = {}
	if piece.is_horizontal then
		for i = 1, #piece.gems do ret[#ret+1] = column + i - 1 end
	else
		for i = 1, #piece.gems do ret[#ret+1] = column end
	end
	return ret
end

-- place piece into actual grid
local function placePiece(self, piece, coords, place_type)
	local player = piece.owner
	place_type = place_type or "normal"
	player.place_type = place_type
	self:queueAction(piece.dropIntoBasin, {piece, coords})
end

local function playSuper(self, super_params)
	super_params = super_params or {}
	self:queueAction(function() self.player.supering = true end, super_params)
end

-- returns a scoring for all possible pieces and their placements
local function generateScoreMatrices(grid, player)
	local piece_list = enumeratePieces(player)

	-- rotate all pieces in hand by 1
	local function rotateAll()
		for i = 1, player.hand_size do
			if player.hand[i].piece then
				player.hand[i].piece:ai_rotate()
			end
		end
	end

	local matrix = {}
	for rotation = 1, 4 do -- a matrix for each orientation
		rotateAll(player)
		matrix[rotation] = {}
		for i = 1, #piece_list do -- i: total number of valid pieces
			local piece = piece_list[i]
			matrix[rotation][i] = {}
			local start_col = player.start_col
			local end_col = player.end_col
			if piece.is_horizontal then end_col = end_col - 1 end
			for col = start_col, end_col do -- j: total valid columns
				matrix[rotation][i][col] = grid:simulateScore(piece, getCoords(piece, col))
			end
		end
	end
	-- return values correspond to the piece rotation index values
	local v1, h1, v2, h2 = matrix[1], matrix[2], matrix[3], matrix[4]
	return {v1, h1, v2, h2}
end

-- this currently always plays the highest possible scoring match, but doesn't discriminate further
function ai:evaluateActions()
	local player = self.player
	if self.countdown == 0 then
		-- play super if available, using params
		if player:canUseSuper() then
			local super_params = nil -- TODO
			playSuper(self, super_params)
		else
			-- Get a set of moves that yield the highest score
			local matrices = generateScoreMatrices(self.game.grid, player)
			local maximum_score = 0
			local possible_moves = {}
			for rot = 1, 4 do
				local h_adj = (rot+1) % 2
				for pc = 1, #matrices[rot] do
					for col = player.start_col, player.end_col - h_adj do
						local score = matrices[rot][pc][col]
						if score > maximum_score then	-- Make a fresh table
							maximum_score = score
							possible_moves = {{rotation = rot, piece_idx = pc, column = col}}
						elseif score == maximum_score then	-- Add to the current table
							possible_moves[#possible_moves+1] = {rotation = rot, piece_idx = pc, column = col}
						end
					end
				end
			end

			if maximum_score > 0 then
				local selected = possible_moves[math.random(#possible_moves)]
				--local selected = possible_moves[1] -- for debug, always select first piece
				local piece = enumeratePieces(player)[selected.piece_idx]
				for _ = 1, selected.rotation do
					piece:rotate()
				end

				placePiece(self, piece, getCoords(piece, selected.column))
			elseif player.cur_burst >= player.RUSH_COST and
			self.game.grid:getFirstEmptyRow(1) >= self.game.grid.RUSH_ROW then
				local piece = selectRandomPiece(player)
				if piece.is_horizontal then	-- Always do vertical rushes.
					piece:rotate()
				end

				placePiece(self, piece, {player.enemy.start_col, player.enemy.start_col}, "rush")
			else
				-- random play
				local piece = selectRandomPiece(player)
				local coords = getCoords(piece, selectRandomColumn(piece, player))

				placePiece(self, piece, coords)
			end
		end
		self.countdown = 5
		self.finished = true
	else
		self.countdown = self.countdown - 1
	end
end

function ai:queueAction(func, args)
	self.queuedFunc, self.queuedArgs = func, args
end

function ai:performQueuedAction()
	if not self.queuedFunc then
		error("ai tried to perform nonexistent queued action")
	end
	self.queuedFunc(table.unpack(self.queuedArgs))
	self.queuedFunc, self.queuedArgs = nil, nil	-- Only run once.
end

-- clears all the ai stuff and get ready for next turn so you don't get some first turn bugs
function ai:newTurn()
	self.finished = false
	self.countdown = 5
end

return common.class("AI", ai)
