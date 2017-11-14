local love = _G.love
local common = require "class.commons"

local soundfiles = {
	bgm_menu = {filename = "music/menu.ogg", loop_from = 34.758, loop_to = 1.655},
	bgm_heath = {filename = "music/heath.ogg", loop_from = 79.666, loop_to = 3.666},
	bgm_buzz = {filename = "music/buzz.ogg", loop_from = 70.235, loop_to = 1.058},
	bgm_gail = {filename = "music/gail.ogg", loop_from = 61.714, loop_to = 6.857},
	bgm_hailey = {filename = "music/hailey.ogg", loop_from = 72.000, loop_to = 2.666},
	bgm_holly = {filename = "music/holly.ogg", loop_from = 82.000, loop_to = 2.000},
	bgm_ivy = {filename = "music/ivy.ogg", loop_from = 65.142, loop_to = 3.428},
}

local sfx_files = {"button", "buttonback", "buttonsuper", "buttonbacksuper",
	"buttoncharacter", "gembreak1", "gembreak2", "gembreak3", "gembreak4",
	"gembreak5", "gemrotate", "gemdrop", "rush", "doublecast", "fountaingo",
	"fountainrush", "fountaindoublecast", "superactivate", "starbreak",
	"trashrow", "countdown3", "countdown2", "countdown1"}
for _, v in pairs(sfx_files) do
	soundfiles["sfx_" .. v] = {filename = "sound/" .. v .. ".ogg"}
end

-------------------------------------------------------------------------------
local SoundObject = {}
function SoundObject:init(manager, params)
	manager.active_sounds[params.sound_name][params.start_frame] = self
	self.manager = manager

	-- defaults
	self.volume = 1
	self.fade_in = false
	self.fade_out = false

	for k, v in pairs(params) do self[k] = v end -- optional arguments

	self.source:play()
end

function SoundObject:remove()
	self.manager.active_sounds[self.sound_name][self.start_frame] = nil
end

-- no_repeats is an optional trigger. If true, then it won't replay it 2 frames later,
-- instead it will just not create any sound effect
function SoundObject.generate(game, sound_name, is_bgm, no_repeats)
	local s = soundfiles[sound_name]
	if s then
		local start_frame = game.frame
		local previous_play = game.sound.last_played_frame[sound_name]
		if start_frame <= (previous_play + 1) then -- delay by 2 frames
			if no_repeats then return end
			start_frame = previous_play + 2
		end
		local params = {
			source = love.audio.newSource(s.filename),
			sound_name = sound_name,
			start_frame = start_frame,
			is_bgm = is_bgm,
			looping = is_bgm,
			loop_from = s.loop_from or -1,
			loop_to = s.loop_to or -1,
		}

		local object = common.instance(SoundObject, game.sound, params)
		game.sound.last_played_frame[sound_name] = start_frame
		return object
	else
		print("invalid sound requested ", sound_name)
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
function SoundObject:setLooping(is_looping, loop_from, loop_to)
	self.loop_from = loop_from or self.loop_from
	self.loop_to = loop_to or self.loop_to
	self.looping = is_looping
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
	for _, sound_name in pairs(self.active_sounds) do
		for start_frame, instance in pairs(sound_name) do
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

function Sound:newBGM(sound_name, is_looping)
	self.current_bgm = self.object.generate(self.game, sound_name, true)
	if is_looping then self.current_bgm:setLooping(true) end
	self.current_bgm:setVolume(0.4) -- placeholder
	return self.current_bgm
end

function Sound:stopBGM()
	if self.current_bgm then
		self.current_bgm:stop()
		self.current_bgm = nil
	end
end

function Sound:pauseBGM()
	self.current_bgm:pause()
end

function Sound:getCurrentBGM()
	if self.current_bgm then return self.current_bgm.sound_name end
end

function Sound:newSFX(sound_name, no_repeats)
	return self.object.generate(self.game, sound_name, false, no_repeats)
end

function Sound:reset()
	if self.active_sounds then
		for _, sound_name in pairs(self.active_sounds) do
			for _, instance in pairs(sound_name) do
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
