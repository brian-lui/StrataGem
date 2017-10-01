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

local function playPiece(self, recv_piece)
	local player = self.player
	local piece = getPieceFromID(recv_piece.piece_ID, player)
	for _ = 1, recv_piece.rotation do
		piece:rotate()
	end
	player.place_type = recv_piece.place_type or error("place_type is nil")

	print("current place type for playing their piece:", player.place_type)
	piece:dropIntoBasin(recv_piece.coords, true)
end

local function playSuper(self, params)
	self.player.supering = true
	self.player.super_params = params
end

local function performDeltas(self)
	local play = self.game.client.their_delta[self.game.turn]
	if play.super then
		playSuper(self, play.super_params)
	end
	if next(play.piece1) then
		playPiece(self, play.piece1)
	end
	if next(play.piece2) then
		playPiece(self, play.piece2)
	end
	-- NOTE: player.place_type will be set to double if piece2 exists, since it
	-- takes the last place_type.
end

-- Easy peasy, no thinking to do here.
function ai_net:evaluateActions()
	if self.game.client.their_delta[self.game.turn] then
		self.finished = true
		self:queueAction(performDeltas, {self})
	end
end

return common.class("AI_Net", ai_net, require "ai")
