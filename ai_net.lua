local love = _G.love
local common = require "class.commons"

--[[
Subclass of normal AI that doesn't do any thinking of its own, just relays
player inputs from over the net.
--]]

local ai_net = {}
--[[
local function split(s)
    local result = {}
    for match in (s.."_"):gmatch("(.-)_") do table.insert(result, match) end
    return result
end
--]]
--[[ Delta decoding:
	0) Default string is "N_", for no action.
	1) Pc1_ID[piece hand position]_[piece rotation index]_[first gem column]_
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
--[[
local function performDeltas(self, player)
	print("performing delta " .. self.game.client.their_delta)
	local delta = split(self.game.client.their_delta)
	for i, v in ipairs(delta) do
		if (v == "Pc1") or (v == "Pc2") then
			local pos = tonumber(delta[i+1])
			local piece = player.hand[pos].piece
			local rotation = tonumber(delta[i+2])
			local column = tonumber(delta[i+3])

			assert(piece, "piece in position " .. pos .. " not found")
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
--]]
-- Easy peasy, no thinking to do here.
function ai_net:evaluateActions(them_player)
	--self:queueAction(performDeltas, {self, them_player})
	---[[
	self:queueAction(self.game.deserializeDelta, {self.game, self.game.client.their_delta, them_player})
	--]]
end

return common.class("AI_Net", ai_net, require "ai")
