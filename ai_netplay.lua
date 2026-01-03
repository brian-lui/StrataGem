--[[
Subclass of normal AI that just relays player inputs from over the net.
--]]

local common = require "class.commons"

local ai_net = {}

-- Evaluates and queues opponent actions from network delta
-- Returns true on success, false if delta validation fails
function ai_net:evaluateActions(them_player)
	local game = self.game
	local delta = game.client.their_delta

	-- Validate delta exists
	if not delta then
		print("No delta received from opponent")
		return false
	end

	-- Validate delta before queuing
	-- We do a pre-validation check here to catch errors early
	if type(delta) ~= "string" or delta == "" then
		print("Invalid delta format received from opponent")
		return false
	end

	self:queueAction(
		game.deserializeDelta,
		{game, delta, them_player}
	)

	return true
end

return common.class("AI_Net", ai_net, require "ai")
