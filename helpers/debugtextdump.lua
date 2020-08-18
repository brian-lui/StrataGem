--[[
This module dumps the gamestate turn by turn. Very annoying but whatever
--]]

local common = require "class.commons" -- class support
local love = _G.love
local DebugTextdump = {}

function DebugTextdump:init(game)
	assert(game, "Game object not received!")
	self.game = game
	self.WRITE_FILE = "gamelog.txt"
end

-- write a custom text string
function DebugTextdump:writeTitle(string)
	love.filesystem.append(self.WRITE_FILE, string .. "\n")
end

-- player stuff etc.
function DebugTextdump:writeGameInfo()
	local game = self.game

	local write = "Version: " .. game.VERSION .. "\n"

	write = write .. "ME\n--\n"
	write = write .. "My name: " .. game.me_player.player_name .. "\n"
	write = write .. "My character: " .. game.me_player.character_name .. "\n"
	write = write .. "My player number: " .. game.me_player.player_num .. "\n"
	write = write .. "\nTHEM\n----\n"
	write = write .. "Their name: " .. game.them_player.player_name .. "\n"
	write = write .. "Their character: " .. game.them_player.character_name .. "\n"
	write = write .. "Their player number: " .. game.them_player.player_num .. "\n"

	love.filesystem.append(self.WRITE_FILE, write .. "\n")
end

-- dumps the delta in a human-readable format
function DebugTextdump:writeMyDeltaText()
	local game = self.game
	local player = game.me_player

	local write = "Turn " .. game.turn .. " my action, Player " .. player.player_num .. "\n"

	local delta_string = game.client.our_delta
	local delta = {}
	for s in (delta_string.."_"):gmatch("(.-)_") do table.insert(delta, s) end

	for i, v in ipairs(delta) do
		if v == "Pc1" then
			local pos = tonumber(delta[i+1])
			local rotation = tonumber(delta[i+2])
			local column = tonumber(delta[i+3])

			write = write .. "Played piece in position " .. pos ..
				", rotated " .. rotation .. " times, " ..
				"into column " .. column .. "\n"
		elseif v == "Pc2" then
			local pos = tonumber(delta[i+1])
			local rotation = tonumber(delta[i+2])
			local column = tonumber(delta[i+3])

			write = write .. "Played SECOND piece in position " .. pos ..
				", rotated " .. rotation .. " times, " ..
				"into column " .. column .. "\n"
		elseif v == "S" then
			write = write .. "Activated SUPER\n"
		elseif v == "N_" then
			write = write .. "No action\n"
		end
	end

	love.filesystem.append(self.WRITE_FILE, write .. "\n")
end

-- dumps the delta in a human-readable format
function DebugTextdump:writeTheirDeltaText()
	local game = self.game
	local player = game.them_player

	local write = "Turn " .. game.turn .. " their action, Player " .. player.player_num .. "\n"

	local delta_string = game.client.their_delta
	local delta = {}
	for s in (delta_string.."_"):gmatch("(.-)_") do table.insert(delta, s) end

	for i, v in ipairs(delta) do
		if v == "Pc1" then
			local pos = tonumber(delta[i+1])
			local rotation = tonumber(delta[i+2])
			local column = tonumber(delta[i+3])

			write = write .. "Played piece in position " .. pos ..
				", rotated " .. rotation .. " times, " ..
				"into column " .. column .. "\n"
		elseif v == "Pc2" then
			local pos = tonumber(delta[i+1])
			local rotation = tonumber(delta[i+2])
			local column = tonumber(delta[i+3])

			write = write .. "Played SECOND piece in position " .. pos ..
				", rotated " .. rotation .. " times, " ..
				"into column " .. column .. "\n"
		elseif v == "S" then
			write = write .. "Activated SUPER\n"
		elseif v == "N_" then
			write = write .. "No action\n"
		end
	end

	love.filesystem.append(self.WRITE_FILE, write .. "\n")
end

-- dumps the player hand pieces in a human-readable format
function DebugTextdump:writeHandsText()
	local game = self.game

	local write = "Turn " .. game.turn .. ", hand gems\n"

	local player1, player2
	if game.me_player.player_num == 1 then
		player1, player2 = game.me_player, game.them_player
	else
		player1, player2 = game.them_player, game.me_player
	end

	write = write .. "Player 1:\n"
	for pos = 1, 5 do
		if player1.hand[pos].piece then
			local gem_colors = ""
			for j = 1, #player1.hand[pos].piece.gems do
				gem_colors = gem_colors .. player1.hand[pos].piece.gems[j].color .. " & "
			end
			gem_colors = gem_colors:sub(1, -3)

			write = write .. "Position " .. pos .. ": " .. gem_colors .. "\n"
		else
			write = write .. "Position " .. pos .. ": no piece\n"
		end
	end

	write = write .. "Player 2:\n"
	for pos = 1, 5 do
		if player2.hand[pos].piece then
			local gem_colors = ""
			for j = 1, #player2.hand[pos].piece.gems do
				gem_colors = gem_colors .. player2.hand[pos].piece.gems[j].color .. " & "
			end
			gem_colors = gem_colors:sub(1, -3)

			write = write .. "Position " .. pos .. ": " .. gem_colors .. "\n"
		else
			write = write .. "Position " .. pos .. ": no piece\n"
		end
	end

	love.filesystem.append(self.WRITE_FILE, write .. "\n")
end

-- this might not work with opponent deltas depending on timing
function DebugTextdump:writePendingGridText()
	local game = self.game
	local grid = game.grid

	local write = "Turn " .. game.turn .. ", pending gems\n"

	-- pending gems
	for row = grid.PENDING_START_ROW, grid.PENDING_END_ROW do
		write = write .. " " .. row - grid.BASIN_START_ROW

		for col = 1, grid.COLUMNS do
			if grid[row][col].gem then
				local color_letter = string.sub(grid[row][col].gem.color:upper(), 1, 1)
				write = write .. " " .. color_letter
			else
				write = write .. "  "
			end
		end
		write = write .. "\n"
	end

	write = write .. "    1 2 3 4 5 6 7 8"

	love.filesystem.append(self.WRITE_FILE, write .. "\n\n")
end

-- dumps the grid in a human-readable format
function DebugTextdump:writeGridText()
	local game = self.game
	local grid = game.grid

	local write = "Turn " .. game.turn .. ", basin gems\n"

	-- grid gems
	for row = grid.BASIN_START_ROW, grid.BASIN_END_ROW do
		write = write .. "  " .. row - grid.PENDING_END_ROW

		for col = 1, grid.COLUMNS do
			if grid[row][col].gem then
				local color_letter = string.sub(grid[row][col].gem.color:upper(), 1, 1)
				write = write .. " " .. color_letter
			else
				write = write .. "  "
			end
		end
		write = write .. "\n"
	end

	write = write .. "    1 2 3 4 5 6 7 8"

	love.filesystem.append(self.WRITE_FILE, write .. "\n\n")
end

return common.class("DebugTextdump", DebugTextdump)
