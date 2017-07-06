local love = _G.love
local json = require 'dkjson'
local settings = {}
settings.player = {name = "Card Gamer"}

-- Check for player file and put it into settings.player.
-- If file doesn't exist, write settings.player to disk
if love.filesystem.exists("player.txt") then
	local player_str = love.filesystem.read("player.txt")
	settings.player = json.decode(player_str)
else
	love.filesystem.write("player.txt", json.encode(settings.player))
end

return settings
