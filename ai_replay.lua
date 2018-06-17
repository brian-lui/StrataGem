-- Subclass of normal AI that just relays player inputs from a file.
local common = require "class.commons"
local ai_replay = {}

-- stores as a table of deltas[turn][player_num]
function ai_replay:storeDeltas(deltas)
	self.deltas = deltas
end

function ai_replay:evaluateActions()
	local game = self.game
	local p1, p2 = game.me_player, game.them_player
	local p1_delta = self.deltas[game.turn][1]
	local p2_delta = self.deltas[game.turn][2]

	-- TODO: better handling of END
	if p1_delta ~= "END" and p2_delta ~= "END" then
		self:queueAction(game.deserializeDelta, {game, p1_delta, p1})
		self:queueSecondAction(game.deserializeDelta, {game, p2_delta, p2})
	end
end

return common.class("AI_Net", ai_replay, require "ai")
