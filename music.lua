local love = _G.love

local common = require "class.commons"

local Music = {}

function Music:init(game)
	self.game = game
	self.bgm = {love.audio.newSource("sound/dummy.ogg")}
	
	love.audio.setPosition(0, 1, 0)
end

function Music:setBGM(filename, n)
	local bgm = self.bgm[n or 1]
	if bgm then
		bgm:stop()
	end
	bgm = love.audio.newSource("music/" .. filename, "stream")
	bgm:setVolume(0.0001)
	bgm:setLooping(true)
	bgm:rewind()
	bgm:play()
end

function Music:pauseBGM(n)
	self.bgm[n or 1]:pause()
end

function Music:stopBGM(n)
	self.bgm[n or 1]:stop()
end

function Music:resumeBGM(n)
	self.bgm[n or 1]:resume()
end

function Music:setBGMspeed(speed, n)
	self.bgm[n or 1]:setPitch(speed or 1)
end

function Music:playSFX(filename)
	local sfx = love.audio.newSource("sound/" .. filename)
	sfx:setVolume(0.0001)
	sfx:play()
end

return common.class("Music", Music)
