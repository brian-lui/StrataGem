--[[
	This powerful module provides the CPU moves in the single player game.
--]]
require 'utilities'
local stage = require 'stage'
local engine = require 'engine'

local ai = {
	finished = false,
	queued_action = false,
}

local countdown = 5 -- frames to wait before calculating move

-- debug function, prints maximum score and piece drop to achieve it
local function printMaximumScore(maximum_score, possible_pieces)
	print("Maximum possible score:", maximum_score)

	if maximum_score ~= 0 then
		for i = 1, #possible_pieces do
			print("At orientation " .. possible_pieces[i][1] .. ", piece " .. possible_pieces[i][2] ..
			", column " .. possible_pieces[i][3])
		end
	end
end

-- sends all gems to the bottom immediately
local function simulateGravity(use_grid)
	use_grid = use_grid or stage.grid
	for j = 1, use_grid.columns do
		local sorted_column = columnSort(j, use_grid)
		for i = 1, use_grid.rows do
			use_grid[i][j].gem = sorted_column[i]
		end
	end
end

-- get score of simulated piece placements
local function getScore(use_grid, matching_number)
	use_grid = use_grid or stage.grid
	matching_number = matching_number or 3
	local gems_removed = engine.checkMatches(matching_number, use_grid)
	return #gems_removed
end

-- randomly rotate all pieces in hand by 1
local function rotateRandom(player)
	for i = 1, player.hand_size do
		local rotate = math.random() < 0.5
		if rotate and player.hand[i].piece then
			player.hand[i].piece:rotate()
		end
	end
end

-- rotate all pieces in hand by 1
local function rotateAll(player)
	for i = 1, player.hand_size do
		if player.hand[i].piece then
			player.hand[i].piece:rotate()
		end
	end
end

-- rotate all pieces until they are horizontal
local function rotateToHorizontal(player)
	for i = 1, player.hand_size do
		if player.hand[i].piece and not player.hand[i].piece.horizontal then
			player.hand[i].piece:rotate()
		end
	end
end

-- rotate all pieces until they are vertical
local function rotateToVertical(player)
	for i = 1, player.hand_size do
		if player.hand[i].piece and player.hand[i].piece.horizontal then
			player.hand[i].piece:rotate()
		end
	end
end

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
	if piece.horizontal then end_col = end_col - 1 end
	return math.random(start_col, end_col)
end

-- takes a column index, and returns table of argument column and the next column
local function getCoords(column)
	return {column, column + 1}
end

-- place piece into actual grid
local function placePiece(piece, coords, place_type)
	local player = piece.owner
	place_type = place_type or "normal"
	player.place_type = place_type
	ai.queued_action = {func = piece.dropIntoBasin, args = {piece, coords}}
end

-- place piece into simulated grid
local function simulatePlacePiece(use_grid, piece, coords) -- only works with 2-gem piece
	if piece.horizontal then
		for i = 1, #piece.gems do
			local column = coords[i]
			use_grid[1][column].gem = piece.gems[i]
		end

	elseif not piece.horizontal then
		for i = 1, #piece.gems do
			local column = coords[1]
			use_grid[i][column].gem = piece.gems[i]
		end
	end
end

-- return score for simulated grid + piece placement
local function simulateScore(player, piece, coords)
	local orig_grid = deepcpy(stage.grid)
	simulatePlacePiece(orig_grid, piece, coords)
	simulateGravity(orig_grid)

	if not getScore(orig_grid) then print ("nil score") end
	return getScore(orig_grid)
end

-- returns a scoring for all possible pieces and their placements
local function generateScoreMatrix(player)
	local piece_list = enumeratePieces(player)

	rotateToHorizontal(player) -- settle down the pieces

	local matrix = {}
	for rotation = 1, 4 do -- a matrix for each orientation
		rotateAll(player)
		matrix[rotation] = {}
		for piece = 1, #piece_list do -- i: total number of valid pieces
			matrix[rotation][piece] = {}
			local start_col = player.start_col
			local end_col = player.end_col
			if piece_list[piece].horizontal then end_col = end_col - 1 end
			for col = start_col, end_col do -- j: total valid columns
				matrix[rotation][piece][col] = simulateScore(player, piece_list[piece], getCoords(col))
			end
		end
	end
	-- return values correspond to the piece rotation index values
	local v1, h1, v2, h2 = matrix[1], matrix[2], matrix[3], matrix[4]
	return v1, h1, v2, h2
end

-- this currently always plays the highest possible scoring match, but doesn't discriminate further
function ai.placeholder(player)
	if countdown == 0 then
		-- random play
		local play_piece = selectRandomPiece(player)
		local play_column = selectRandomColumn(play_piece, player)
		local play_coords = getCoords(play_column)

		local piece_list = enumeratePieces(player)

		local v1, h1, v2, h2 = generateScoreMatrix(player)
		local matrices = {v1, h1, v2, h2}
		local maximum_score = 0

		for rot = 1, 4 do
			local h_adj = (rot+1) % 2 -- 1 if horizontal at 2 and 4
			for pc = 1, #matrices[rot] do -- total number of valid pieces
				for col = player.start_col, player.end_col - h_adj do -- total valid columns
					if matrices[rot][pc][col] > maximum_score then maximum_score = matrices[rot][pc][col] end
				end
			end
		end

		local possible_pieces = {}
		for rot = 1, 4 do
			local h_adj = (rot+1) % 2
			for pc = 1, #matrices[rot] do
				for col = player.start_col, player.end_col - h_adj do
					if matrices[rot][pc][col] == maximum_score then
						possible_pieces[#possible_pieces+1] = {rotation = rot, piece_idx = pc, column = col}
					end
				end
			end
		end

		--printMaximumScore(maximum_score, possible_pieces)
		if maximum_score > 0 then
			local random = math.random(#possible_pieces)
			local selected = possible_pieces[random]
			--local selected = possible_pieces[1] -- for debug, always select first piece
			local piece_number = selected.piece_idx
			local piece = piece_list[piece_number]
			for i = 1, selected.rotation do
				piece:rotate()
			end
			placePiece(piece, getCoords(selected.column))

		elseif player.cur_mp >= player.RUSH_COST then
			local piece = play_piece
			if piece.horizontal then piece:rotate() end
			placePiece(piece, {player.enemy.start_col, player.enemy.start_col}, "rush")
		else
			placePiece(play_piece, play_coords)
			--placePiece(piece_list[1], getCoords(1))
		end

		countdown = 5
		ai.finished = true
	else
		countdown = countdown - 1
	end
end

-- clears all the ai stuff and get ready for next turn so you don't get some first turn bugs
function ai.clear()
	ai.finished = false
	ai.queued_action = false
	countdown = 5
end

return ai
