local love = _G.love

local common = "class.commons"

local Sound = {
}

function Sound:init(game)
	self.game = game
	Sound.gembreak = {}
	for i = 1, 5 do
		Sound["gembreak"..i] = "sound/gembreak"..i..".ogg"
	end
	self.last_played_frame = setmetatable({}, {__index = function() return -1 end})
end

function Sound:_playImmediately(s)
	print("playing sound on frame", self.game.frame)
	local instance = love.audio.newSource(self[s])
	love.audio.play(instance)
	self.last_played_frame[s] = math.max(self.last_played_frame[s], self.game.frame)
	return instance
end

-- play sound, returns the sound object
-- play sounds with a 2 frame delay between identical sounds
function Sound:play(s)
	if self[s] then
		local frame = self.game.frame
		local previous = self.last_played_frame[s]
		print("frame, prev", frame, previous)
		if frame <= previous then -- queue
			self.game.queue:add(2 + previous - frame, self._playImmediately, self, s)
			self.last_played_frame[s] = 2 + previous
		else -- play immediately
			local instance = self:_playImmediately(s)
			return instance
		end
	else
		print("invalid sound requested ", s)
	end
end

function Sound:reset()
	self.last_played_frame = setmetatable({}, {__index = function() return -1 end})
end

return common.class("Sound", Sound)
