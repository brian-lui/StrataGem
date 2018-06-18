-- Subclass of normal AI that just relays player inputs from over the net.
local common = require "class.commons"

local ai_net = {}
function ai_net:evaluateActions(them_player)
	local game = self.game
	self:queueAction(
		game.deserializeDelta,
		{game, game.client.their_delta, them_player}
	)
end

return common.class("AI_Net", ai_net, require "ai")
