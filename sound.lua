local sound = {
}

sound.gembreak = {}
for i = 1, 5 do
	sound["gembreak"..i] = "sound/gembreak"..i..".ogg"
end

-- helper table and helper function for sound.play
local last_played_frame = {}
setmetatable(last_played_frame, {__index = function() return -1 end})

function sound._playImmediately(s)
	print("playing sound on frame", frame)
	local instance = love.audio.newSource(sound[s])
	love.audio.play(instance)
	last_played_frame[s] = math.max(last_played_frame[s], frame)
	return instance
end

-- play sound, returns the sound object
-- play sounds with a 2 frame delay between identical sounds
function sound:play(s)
	if sound[s] then
		local previous = last_played_frame[s]
		print("frame, prev", frame, previous)
		if frame <= previous then -- queue
			local queue_frame = 2 + previous - frame
			queue.add(queue_frame, sound._playImmediately, s)
			last_played_frame[s] = 2 + previous
		else -- play immediately
			local instance = self._playImmediately(s)
			return instance
		end
	else
		print("invalid sound requested ", s)
	end
end

function sound:reset()
	last_played_frame = {}
end

return sound