local love = _G.love
--[[
Subclass of normal AI that doesn't do any thinking of its own, just relays
player inputs from over the net.
--]]

local common = require "class.commons"

local ai_net = {
}

-- looks up the piece locally so we don't need to netsend the entire piece info
local function getPieceFromID(ID, player)
	for i = 1, player.hand_size do
		if player.hand[i].piece then
			if player.hand[i].piece.ID == ID then
				return player.hand[i].piece
			end
		end
	end
end

local function split(s)
    local result = {}
    for match in (s.."_"):gmatch("(.-)_") do table.insert(result, match) end
    return result
end

--[[ Delta decoding:
	0) Default string is "N_", for no action.
	1) Pc1_ID[piece ID]_[piece rotation index]_[first gem column]_
		e.g. Pc1_60_3_3_
	2) Same as above, e.g. Pc2_60_2_3_
	3) S_[parameters]_
		e.g. S__, S_58390496405_
	Concatenate to get final string, e.g.:
		Pc1_59_3_2_Pc2_60_1_3_
		Pc1_59_3_2_
		S__
		N_ (no action)
--]]
local function performDeltas(self)
	local player = self.player
	local delta = split(self.game.client.their_delta)

	for i, v in delta do
		if (v == "Pc1") or (v == "Pc2") then
			local id = delta[i+1]
			local piece = getPieceFromID(id, player)
			local rotation = delta[i+2]
			local column = delta[i+3]

			assert(piece, "piece ID not found: " .. piece.piece_ID)
			assert(rotation, "rotation not provided")
			assert(column, "placement column not provided")

			if v == "Pc2" then
				player.place_type = "double"
			else
				for col in self.game.grid:cols(player.player_num) do
					if column == col then
						player.place_type = "normal"
						break
					end
					player.place_type = "rush"
				end
			end

			for _ = 1, rotation do piece:rotate() end

			local coords
			if piece.size == 2 then
				if piece.is_horizontal then
					coords = {column, column + 1}
				else
					coords = {column, column}
				end
			else
				coords = {column}
			end
			piece:dropIntoBasin(coords, true)

		elseif v == "S" then
			player.supering = true
			player.super_params = delta[i+1]
		end
	end
end

-- Easy peasy, no thinking to do here.
function ai_net:evaluateActions()
	if self.game.client.their_delta[self.game.turn] then
		self.finished = true
		self:queueAction(performDeltas, {self})
	end
end

return common.class("AI_Net", ai_net, require "ai")
