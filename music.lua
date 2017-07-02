local music = {}

local bgm = {}
bgm[1] = love.audio.newSource("sounds/dummy.ogg")

function music.setBGM(filename, n)
	n = n or 1
	if bgm[n] then bgm[n]:stop() end
	bgm[n] = love.audio.newSource("music/" .. filename, "stream")
	bgm[n]:setVolume(0.0001)
	bgm[n]:setLooping(true)
	bgm[n]:rewind()
	bgm[n]:play()
end

function music.pauseBGM(n)
	n = n or 1
	bgm[n]:pause()
end

function music.stopBGM(n)
	n = n or 1
	bgm[n]:stop()
end

function music.resumeBGM(n)
	n = n or 1
	bgm[n]:resume()
end

function music.setBGMspeed(speed, n)
	n = n or 1
	speed = speed or 1
	bgm[n]:setPitch(speed)
end

function music.playSFX(filename)
	local sfx = love.audio.newSource("sounds/" .. filename)
	sfx:setVolume(0.0001)
	sfx:play()
end

return music