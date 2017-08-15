local love = _G.love
local common = require "class.commons"

local soundfiles = {
	sfx_gembreak1 = "sound/gembreak1.ogg",
	sfx_gembreak2 = "sound/gembreak2.ogg",
	sfx_gembreak3 = "sound/gembreak3.ogg",
	sfx_gembreak4 = "sound/gembreak4.ogg",
	sfx_gembreak5 = "sound/gembreak5.ogg",
	bgm_menu = "music/menu.ogg",
	bgm_heath = "music/heath.ogg",
	bgm_buzz = "music/buzz.ogg",
}

-- sound object class
local SoundObject = {}
function SoundObject:init(manager, params)
	for k, v in pairs(params) do self[k] = v end
	manager[params.soundfile_name][params.start_frame] = self
	self.manager = manager
end

function SoundObject:remove()
	self.manager[params.soundfile_name][params.start_frame] = nil
end

function SoundObject.generate(game, soundfile_name)
	local s = soundfiles[soundfile_name]
	if s then
		local start_frame = game.frame
		local previous_play = game.sound.last_played_frame[soundfile_name]
		if start_frame <= (previous_play - 1) then -- delay by 2 frames
			start_frame = previous_play + 2
		end

		local params = {
			source = love.audio.newSource(s),
			soundfile_name = soundfile_name,
			start_frame = start_frame,
			volume = 1,
			looping = false, -- only for custom loop settings, not for setLooping/isLooping
			loop_to = -1,
			loop_from = -1,
			fade_in = false,
			fade_out = false,
		}

		local object = common.instance(SoundObject, game.sound.active_sounds, params)
		game.sound.last_played_frame[soundfile_name] = start_frame
		return object
	else
		print("invalid sound requested ", soundfile_name)
	end
end

function SoundObject:play()
	self.source:play()
end

function SoundObject:isStopped()
	return self.source:isStopped()
end

function SoundObject:setVolume(vol)
	self.source:setVolume(vol)
end

function SoundObject:getTime()
	return self.source:tell()
end

function SoundObject:setTime(time)
	self.source:seek(time)
end

-- sets volume to fade in from 0 to default volume
-- frames is optional
function SoundObject:fadeIn(frames)
end

-- sets volume to fade out from current volume to 0
-- frames is optional
function SoundObject:fadeOut(frames)
end

-- will loop if set to true. optional for time to loop from, and time to loop to
function SoundObject:setLooping(bool, loop_from, loop_to)
end

function SoundObject:isPlaying()
	return self.source:isPlaying()
end
SoundObject = common.class("SoundObject", SoundObject)


local Sound = {}
function Sound:init(game)
	self.game = game
	self:reset()
end


function Sound:update()
	local frame = self.game.frame
	for _, soundfile_name in pairs(self.active_sounds) do
		for start_frame, instance in pairs(soundfile_name) do
			if start_frame <= frame and not instance:isPlaying() then
				instance:play()
			elseif instance:isStopped() then
				instance:remove()
			end

			if instance.fade_in then
				--fade in
				--if finished fadein then instance.fade_in = false end
			elseif instance.fade_out then
				--fade out
				--if finished fadeout then instance.fade_out = false end
			end

			if instance.looping then
				if instance:getTime() >= instance.loop_from then
					instance:setTime(instance.loop_to)
				end
			end
		end
	end
end

function Sound:reset()
	self.last_played_frame = {}
	self.active_sounds = {}
	for name, _ in pairs(soundfiles) do
		self.active_sounds[name] = {}
		self.last_played_frame[name] = -1
	end
end

Sound.object = SoundObject
return common.class("Sound", Sound)
