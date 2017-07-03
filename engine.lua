require 'utilities' -- helper functions
--local class = require "middleclass"
local pairs = pairs
local stage	-- Set in initializer
local particles	-- Set in initializer
local grid	-- Set in initializer

-------------------------------------------------------------------------------
--------------------------------- MATCH ENGINE --------------------------------
-------------------------------------------------------------------------------
local engine = {}

function engine.initialize()
	particles = game.particles
	stage = game.stage
	grid = stage.grid
	if not particles.super_ then
		love.errhand("No particles.super_")
	end
	if not stage then
		love.errhand("No stage")
	end
	if not grid then
		love.errhand("No grid")
	end
end

local function getColor(row, column, use_grid)
	use_grid = use_grid or grid
	if use_grid[row][column].gem then return use_grid[row][column].gem.color end
end

local function getAboveGems(column, start_row)
	start_row = start_row or 1
	local above = {}
	for i = start_row, 1, -1 do
		if grid[i][column].gem then above[#above+1] = grid[i][column].gem end
	end
	return above
end

function engine.getMatches(use_grid, matching_number)
	use_grid = use_grid or grid

	matching_number = matching_number or 3
	local match_colors = {"RED", "BLUE", "GREEN", "YELLOW"}
	local ret = {}
	for i = 1, #match_colors do
		local c = match_colors[i]
		for _, row, column in use_grid:gems() do
			local h_match, v_match = 1, 1
			local current_color = getColor(row, column, use_grid)
			if current_color == c then
				-- HORIZONTAL MATCHES
				local left_color = getColor(row, column-1, use_grid)
				local still_matching_h = current_color ~= left_color -- start check
				local cur_column = column
				while still_matching_h do
					local right_color = getColor(row, cur_column+1, use_grid)
					still_matching_h = current_color == right_color
					if still_matching_h then
						h_match = h_match + 1
						cur_column = cur_column + 1
					end
				end
				if h_match >= matching_number then
					ret[#ret+1] = {match = h_match, row = row, column = column, horizontal = true}
				end

				-- VERTICAL MATCHES
				local up_color = getColor(row-1, column, use_grid)
				local still_matching_v = current_color ~= up_color -- start check
				local cur_row = row
				while still_matching_v do
					local down_color = getColor(cur_row+1, column, use_grid)
					still_matching_v = current_color == down_color
					if still_matching_v then
						v_match = v_match + 1
						cur_row = cur_row + 1
					end
				end

				if v_match >= matching_number then
					ret[#ret+1] = {match = v_match, row = row, column = column, horizontal = false}
				end
			end
		end
	end
	return ret
end

-- returns a list of gem matches, and the total number of matches
function engine.checkMatches(matching_number, use_grid)
	use_grid = use_grid or grid
	local matches = engine.getMatches(use_grid, matching_number)
	local gem_set, gem_table = {}, {}

	for _, tbl in pairs(matches) do
		if tbl.horizontal then
			for i = 1, tbl.match do
				local r = tbl.row
				local c = tbl.column + i - 1
				local this_gem = grid[r][c].gem
				if this_gem then
					if gem_set[this_gem] then -- both horizontal and vertical
						this_gem.horizontal, this_gem.vertical = true, true
					else
						gem_set[this_gem] = true
						this_gem.horizontal = true
					end
				end
			end
		else
			for i = 1, tbl.match do
				local r = tbl.row + i - 1
				local c = tbl.column
				local this_gem = grid[r][c].gem
				if this_gem then
					if gem_set[this_gem] then -- both horizontal and vertical
						this_gem.horizontal, this_gem.vertical = true, true
					else
						gem_set[this_gem] = true
						this_gem.vertical = true
					end
				end
			end
		end
	end

	for gem, _ in pairs(gem_set) do	gem_table[#gem_table+1] = gem end

	return gem_table, #matches
end

function engine.checkMatchedThisTurn(gem_table)
	local p1_matched, p2_matched = false, false
	for i = 1, #gem_table do
		local owner = gem_table[i].owner
		if owner == 1 or owner == 3 then p1_matched = true end
		if owner == 2 or owner == 3 then p2_matched = true end
	end
	return p1_matched, p2_matched
end

function engine.generateMatchExplodingGems(gem_table)
	gem_table = gem_table or engine.checkMatches()

	for _, gem in pairs(gem_table) do
		particles.explodingGem:generate(gem)
	end
end

function engine.generateMatchParticles(gem_table)
	local own_tbl = {p1, p2, false}
	local gem_table = gem_table or engine.checkMatches(matching_number, stage.grid)
	for _, gem in pairs(gem_table) do
		local player = own_tbl[gem.owner]
		if player then
			local num_super_particles = player.meter_gain[gem.color]
			if player.supering then
				num_super_particles = 0
			elseif player.place_type == "rush" or player.place_type == "double" then
				num_super_particles = num_super_particles * 0.25
			end
			particles.super_:generate(gem, num_super_particles)
			particles.damage:generate(gem)
			particles.pop:generate(gem)
			particles.dust:generateBigFountain(gem, 24, player)
		end
	end
end

-- remove all gem flags claimed by a specific player
function engine.removeAllGemOwners(player, use_grid)
	use_grid = use_grid or grid
	for gem in use_grid:gems() do
		gem:removeOwner(player)
	end
end

function engine.setAllGemFlags(flag_num, use_grid)
	use_grid = use_grid or grid
	for gem in use_grid:gems() do
		gem.owner = flag_num
	end
end

function engine.setGarbageMatchFlags(use_grid)
	use_grid = use_grid or grid
	local garbage_diff = p1.pieces_fallen - p2.pieces_fallen

	if garbage_diff == 0 then
		engine.setAllGemFlags(0)
	elseif garbage_diff < 0 then
		engine.setAllGemFlags(1)
	elseif garbage_diff > 0 then
		engine.setAllGemFlags(2)
	end
end

-- propogate flags to each match
-- uses the owner of the original match gem to propogate to all gems in the matched part
function engine.flagMatchedGems(use_grid)
	use_grid = use_grid or grid
	local matches = engine.getMatches()

	for i = 1, #matches do
		local p1flag, p2flag = false, false
		if matches[i].horizontal then
			-- for the current set of matches, whether to set flags for player(s)
			for j = 1, matches[i].match do
				local row = matches[i].row
				local column = matches[i].column + (j-1)
				if grid[row][column].gem.owner == 1 then p1flag = true end
				if grid[row][column].gem.owner == 2 then p2flag = true end
				if grid[row][column].gem.owner == 3 then p1flag = true p2flag = true end
			end
			-- propogate flags to all gems in the current set of matches
			for j = 1, matches[i].match do
				local row = matches[i].row
				local column = matches[i].column + (j-1)
				if p1flag then grid[row][column].gem:addOwner(p1) end
				if p2flag then grid[row][column].gem:addOwner(p2) end
			end
		else
			for j = 1, matches[i].match do
				local row = matches[i].row + (j-1)
				local column = matches[i].column
				if grid[row][column].gem.owner == 1 then p1flag = true end
				if grid[row][column].gem.owner == 2 then p2flag = true end
				if grid[row][column].gem.owner == 3 then p1flag = true p2flag = true end
			end
			for j = 1, matches[i].match do
				local row = matches[i].row + (j-1)
				local column = matches[i].column
				if p1flag then grid[row][column].gem:addOwner(p1) end
				if p2flag then grid[row][column].gem:addOwner(p2) end
			end
		end
	end
end

local function propogateFlagsUp(gem_table)
	for _, gem in pairs(gem_table) do
		local ownership = gem.owner
		local above_gems = getAboveGems(gem.column, gem.row)
		for i = 1, #above_gems do
			above_gems[i]:setOwner(ownership)
		end
	end
end

function engine.removeMatchedGems(matching_number, use_grid)
	use_grid = use_grid or grid
	local gem_table = engine.checkMatches(matching_number, use_grid)
	propogateFlagsUp(gem_table)
	for _, gem in pairs(gem_table) do grid:removeGem(gem) end
end

function engine.calculateScore(gem_table)
	local own_tbl = {p1, p2}
	local dmg, super = {0, 0}, {0, 0}
	for i = 1, #gem_table do
		if gem_table[i].owner ~= 3 then
			local gem, own_idx = gem_table[i], gem_table[i].owner
			local owner = own_tbl[own_idx]
			dmg[own_idx] = dmg[own_idx] + 1
			super[own_idx] = super[own_idx] + owner.meter_gain[gem.color]
		end
	end

	for i = 1, 2 do
		local player = own_tbl[i]
		dmg[i] = dmg[i] + game.scoring_combo - 1
		if player.supering then
			super[i] = 0
		elseif player.place_type == "rush" or player.place_type == "double" then
			super[i] = super[i] * 0.25
		end
	end

	return dmg[1], dmg[2], super[1], super[2]
end

function engine.addSuper(p1super, p2super)
	p1.old_mp = p1.cur_mp
	p1.cur_mp = math.min(p1.cur_mp + p1super, p1.MAX_MP)
	p2.old_mp = p2.cur_mp
	p2.cur_mp = math.min(p2.cur_mp + p2super, p2.MAX_MP)
end

local function getFirstEmptyRow(column)
--[[ This function slightly differs from getFirstEmptyRow in stage.grid. This
	is because we need to check the top two rows, too, to see if any overflowed.
	TODO: can refactor the functions together
--]]
	start_row = start_row or 1
	if column then
		local empty_spaces = 0
		for i = 1, grid.rows do
			if not grid[i][column].gem then empty_spaces = empty_spaces + 1 end
		end
		return empty_spaces
	end
end

function engine.checkLoser()
	local p1loss, p2loss = false, false
	for i = 1, grid.columns do
		local empty_row = getFirstEmptyRow(i)
		if empty_row < game.LOSE_ROW then
			if i <= 4 then p1loss = true else p2loss = true end
		end
	end

	if p1loss and p2loss then
		return "Draw"
	elseif p1loss then
		return "P1"
	elseif p2loss then
		return "P2"
	end
		return false
	end

return engine
