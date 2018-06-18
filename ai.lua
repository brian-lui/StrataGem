--[[
Each AI is assigned to a player on creation, replacing user input.

The AI follows the following lifecycle, called in Phase and elsewhere.

ai:evaluateActions()	Determines what action to take this turn
ai:queueAction(func, args)	Sets the currently-queued action for the ai
ai:performQueuedAction()	Performs the last action queued (ONCE)
ai:newTurn()	Resets anything that needs to reset between turns.
--]]

local common = require "class.commons"

local ai = {
	finished = false,
	queuedFunc = nil,
	queued_args = nil,
}

function ai:init(game, player)
	self.game = game
	self.player = player
end

function ai:queueAction(func, args)
	self.queuedFunc, self.queued_args = func, args
end

-- for replays only. This is hacky lol
function ai:queueSecondAction(func, args)
	self.queuedSecondFunc, self.queued_second_args = func, args
end

function ai:performQueuedAction()
	if not self.queuedFunc then
		error("ai tried to perform nonexistent queued action")
	end
	self.queuedFunc(table.unpack(self.queued_args))
	self.queuedFunc, self.queued_args = nil, nil	-- Only run once.

	if self.queuedSecondFunc then
		self.queuedSecondFunc(table.unpack(self.queued_second_args))
		self.queuedSecondFunc, self.queued_second_args = nil, nil
	end
end

function ai:newTurn()
	self.finished = false
end

function ai:evaluateActions()
	-- put in the ai behavior here
end
return common.class("AI", ai)
