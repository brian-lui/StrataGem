-- Subclass of normal AI that just relays player inputs from a file.
local common = require "class.commons"
local ai_replay = {}

-- stores as a table of deltas[turn][player_num]
function ai_replay:storeDeltas(deltas)
	self.deltas = deltas
end

function ai_replay:evaluateActions()
	local game = self.game
	self:queueAction(game.deserializeDelta, {game, game.client.their_delta, them_player})
end

return common.class("AI_Net", ai_replay, require "ai")
