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

function engine.initialize(game)
	particles = game.particles
	stage = game.stage
	grid = stage.grid
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
	gem_table = gem_table or stage.grid:getMatchedGems()

	for _, gem in pairs(gem_table) do
		particles.explodingGem:generate(gem)
	end
end

function engine.generateMatchParticles(gem_table)
	local own_tbl = {p1, p2, false}
	gem_table = gem_table or stage.grid:getMatchedGems()
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

function engine.setGarbageMatchFlags()
	local garbage_diff = p1.pieces_fallen - p2.pieces_fallen

	if garbage_diff == 0 then
		stage.grid:setAllGemOwners(0)
	elseif garbage_diff < 0 then
		stage.grid:setAllGemOwners(1)
	elseif garbage_diff > 0 then
		stage.grid:setAllGemOwners(2)
	end
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

local function getFirstEmptyRow(column)
--[[ This function slightly differs from getFirstEmptyRow in stage.grid. This
	is because we need to check the top two rows, too, to see if any overflowed.
	TODO: can refactor the functions together
--]]
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
			if i <= 4 then
				p1loss = true
			else
				p2loss = true
			end
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
