-- Subclass of normal AI that just relays player inputs from a file.
local common = require "class.commons"
local ai_replay = {}

function ai_replay:loadReplay(replay_string)
end

function ai_replay:evaluateActions()
	local game = self.game
	self:queueAction(game.deserializeDelta, {game, game.client.their_delta, them_player})
end

return common.class("AI_Net", ai_replay, require "ai")
