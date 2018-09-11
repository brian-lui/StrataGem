--[[
Subclass of normal AI that provides computer actions in a local
singleplayer game.
--]]

local common = require "class.commons"
local deepcpy = require "/helpers/utilities".deepcpy
local ai_singleplayer = {}

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

-- return a random column from player's valid columns
-- accounts for horizontal pieces
local function selectRandomColumn(piece, player)
	local start_col = player.start_col
	local end_col = player.end_col
	if piece.is_horizontal then end_col = end_col - 1 end
	return math.random(start_col, end_col)
end

-- takes a column index, and returns table of given column and the next column
local function getCoords(piece, column)
	local ret = {}
	if piece.is_horizontal then
		for i = 1, #piece.gems do ret[#ret+1] = column + i - 1 end
	else
		for _ = 1, #piece.gems do ret[#ret+1] = column end
	end
	return ret
end

-- place piece into actual grid
local function placePiece(self, piece, coords)
	self:queueAction(piece.dropIntoBasin, {piece, coords, true})
	self.ai_delta = self.game:serializeDelta(self.ai_delta, piece, coords)
end

local function playSuper(self, super_params)
	super_params = super_params or {}
	self:queueAction(
		function() self.player.is_supering = true end,
		super_params
	)
	self.ai_delta = self.game:serializeSuper(self.ai_delta)
end

-- returns a scoring for all possible pieces and their placements
function ai_singleplayer:_generateScoreMatrices(grid, player)
	-- only calculate if there's enough time left
	local MAX_TIME = self.game.time_step * 0.25
	local time_used = 0
	local piece_list = enumeratePieces(player)
	local finished_loading = true

	-- initialize the matrix if it doesn't exist
	if not self.matrices then
		self.matrices = {}
		for rotation = 1, 4 do
			self.matrices[rotation] = {}
			for i = 1, # piece_list do self.matrices[rotation][i] = {} end
		end
	end

	-- function to rotate all pieces in hand by 1
	local function rotateAll()
		for i = 1, player.hand_size do
			if player.hand[i].piece then player.hand[i].piece:ai_rotate() end
		end
	end

	for rotation = 1, 4 do -- a matrix for each orientation
		rotateAll(player)
		for i = 1, #piece_list do -- i: total number of valid pieces
			local piece = piece_list[i]
			local start_col = player.start_col
			local end_col = player.end_col
			if piece.is_horizontal then end_col = end_col - 1 end

			for col = start_col, end_col do
				if not self.matrices[rotation][i][col] and time_used < MAX_TIME then
					local start_time = love.timer.getTime()
					self.matrices[rotation][i][col] = grid:simulateScore(piece, getCoords(piece, col))
					local end_time = love.timer.getTime()

					time_used = time_used + (end_time - start_time)
					if time_used >= MAX_TIME then finished_loading = false end
				end
			end
		end
	end

	return finished_loading
end

-- this currently always plays the highest possible scoring match
-- doesn't discriminate further
function ai_singleplayer:evaluateActions()
	local game = self.game
	local player = self.player

	if not self.grid_snapshot then self.grid_snapshot = deepcpy(game.grid) end
	local grid = self.grid_snapshot

	-- play super if available, using params
	if player:canUseSuper() then
		local super_params = nil -- TODO
		playSuper(self, super_params)
		self.grid_snapshot = nil
		self.finished = true
	else
		-- Get a set of moves that yield the highest score
		local finished_loading = self:_generateScoreMatrices(grid, player)

		if finished_loading then
			local maximum_score = 0
			local possible_moves = {}
			for rot = 1, 4 do
				local h_adj = (rot+1) % 2
				for pc = 1, #self.matrices[rot] do
					for col = player.start_col, player.end_col - h_adj do
						local score = self.matrices[rot][pc][col]
						if score > maximum_score then -- Make a fresh table
							maximum_score = score
							possible_moves = {{
								rotation = rot,
								piece_idx = pc,
								column = col,
							}}
						elseif score == maximum_score then	-- Add to current table
							possible_moves[#possible_moves+1] = {
								rotation = rot,
								piece_idx = pc,
								column = col,
							}
						end
					end
				end
			end

			if maximum_score > 0 then
				local selected = possible_moves[math.random(#possible_moves)]
				local piece = enumeratePieces(player)[selected.piece_idx]
				for _ = 1, selected.rotation do piece:rotate() end

				placePiece(
					self,
					piece,
					getCoords(piece, selected.column)
				)
			elseif player.cur_burst >= player.RUSH_COST and
			grid:getFirstEmptyRow(1) >= grid.RUSH_ROW then
				local piece = selectRandomPiece(player)
				if piece.is_horizontal then piece:rotate() end -- Vertical rush

				placePiece(
					self,
					piece,
					{player.enemy.start_col, player.enemy.start_col},
					"rush"
				)
			else
				-- random play
				local piece = selectRandomPiece(player)
				local coords = getCoords(piece, selectRandomColumn(piece, player))

				placePiece(
					self,
					piece,
					coords
				)
			end

			self.matrices = nil
			self.grid_snapshot = nil
			self.finished = true
		end
	end
end

-- for replays
function ai_singleplayer:clearDeltas()
	self.ai_delta, self.player_delta = "N_", "N_"
end

function ai_singleplayer:writePlayerDelta(piece, coords)
	self.player_delta = self.game:serializeDelta(self.player_delta, piece, coords)
end

function ai_singleplayer:writePlayerSuper()
	self.player_delta = self.game:serializeSuper(self.player_delta)
end

return common.class("AI_Singleplayer", ai_singleplayer, require "ai")
