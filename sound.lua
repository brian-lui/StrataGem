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

-------------------------------------------------------------------------------
local SoundObject = {}
function SoundObject:init(manager, params)
	manager.active_sounds[params.soundfile_name][params.start_frame] = self
	self.manager = manager

	-- defaults
	self.volume = 1
	self.looping = false -- only for custom loop settings, not for setLooping/isLooping
	self.loop_to = -1
	self.loop_from = -1
	self.fade_in = false
	self.fade_out = false

	for k, v in pairs(params) do self[k] = v end -- optional arguments

	self.source:play()
end

function SoundObject:remove()
	self.manager.active_sounds[self.soundfile_name][self.start_frame] = nil
end

function SoundObject.generate(game, soundfile_name, is_bgm)
	local s = soundfiles[soundfile_name]
	if s then
		local start_frame = game.frame
		local previous_play = game.sound.last_played_frame[soundfile_name]
		if start_frame <= (previous_play + 1) then -- delay by 2 frames
			start_frame = previous_play + 2
		end
		local params = {
			source = love.audio.newSource(s),
			soundfile_name = soundfile_name,
			start_frame = start_frame,
			is_bgm = is_bgm,
		}

		local object = common.instance(SoundObject, game.sound, params)
		game.sound.last_played_frame[soundfile_name] = start_frame
		return object
	else
		print("invalid sound requested ", soundfile_name)
	end
end

function SoundObject:play()
	self.source:play()
end

function SoundObject:pause()
	self.source:pause()
end

function SoundObject:stop()
	self.source:stop()
end

function SoundObject:isStopped()
	return self.source:isStopped()
end

function SoundObject:getVolume()
	return self.source:getVolume()
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

function SoundObject:setPosition(x, y, z)
	self.source:setPosition(x, y, z)
end

-- sets volume to fade in from 0
-- frames is optional. volume_mult is optional, stated as a multiple of the default volume
function SoundObject:fadeIn(frames_taken, volume_mult)
	print("fading in")
	frames_taken = frames_taken or 30
	volume_mult = volume_mult or 1
	local target_volume = self.is_bgm and self.manager.bgm_volume or self.manager.sfx_volume
	self.volume = target_volume * volume_mult

	local volume_per_frame = target_volume / frames_taken
	self:setVolume(0)
	self.fade_in = true
	self.fade_in_speed = volume_per_frame
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

-------------------------------------------------------------------------------
local Sound = {}
function Sound:init(game)
	self.game = game
	self.current_bgm = nil
	self:reset()
end

function Sound:update()
	local frame = self.game.frame
	for _, soundfile_name in pairs(self.active_sounds) do
		for start_frame, instance in pairs(soundfile_name) do
			if instance:isStopped() and frame > start_frame then instance:remove() end

			if instance.fade_in then
				local cur_volume = instance:getVolume()
				if instance.volume > cur_volume then
					instance:setVolume(math.min(cur_volume + instance.fade_in_speed, instance.volume))
				else
					instance.fade_in = false
					instance.fade_in_speed = 0
				end
			elseif instance.fade_out then
				local cur_volume = instance:getVolume()
				if cur_volume > 0 then
					instance:setVolume(math.max(cur_volume + instance.fade_out_speed, 0))
				else
					instance.fade_out = false
					instance.fade_out_speed = 0
				end
			end

			if instance.looping then
				if instance:getTime() >= instance.loop_from then
					instance:setTime(instance.loop_to)
				end
			end
		end
	end
end

function Sound:newBGM(soundfile_name)
	self.current_bgm = self.object.generate(self.game, soundfile_name, true)
	return self.current_bgm
end

function Sound:stopBGM()
	self.current_bgm:stop()
	self.current_bgm = nil
end

function Sound:pauseBGM()
	self.current_bgm:pause()
end

function Sound:newSFX(soundfile_name)
	return self.object.generate(self.game, soundfile_name, false)
end

function Sound:reset()
	if self.active_sounds then
		for _, soundfile_name in pairs(self.active_sounds) do
			for _, instance in pairs(soundfile_name) do
				instance:stop()
			end
		end
	end
	self.last_played_frame = {}
	self.active_sounds = {}
	for name, _ in pairs(soundfiles) do
		self.active_sounds[name] = {}
		self.last_played_frame[name] = -1
	end
	self.sfx_volume = 1 -- later we can point to user settings for these
	self.bgm_volume = 1 -- later we can point to user settings for these
end

Sound.object = SoundObject
return common.class("Sound", Sound)
