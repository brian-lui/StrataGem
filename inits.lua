local love = _G.love
local TLfres = require "tlfres"

-- For compatibility; Lua 5.3 moved unpack to table.unpack
_G.table.unpack = _G.table.unpack or _G.unpack

print(love.filesystem.getSaveDirectory())

local CANVAS_WIDTH = 1920
local CANVAS_HEIGHT = 1080
-- all prints go to debug.txt file. achtung!
love.filesystem.remove("debug.txt")
local reallyprint = print
function print(...)
	reallyprint(...)
	local args = {...}
	for i = 1, #args do
		if type(args[i]) == "table" then args[i] = "table"
		elseif args[i] == true then args[i] = "true"
		elseif args[i] == false then args[i] = "false"
		elseif args[i] == nil then args[i] = "nil"
		elseif type(args[i]) == "userdata" then args[i] = "userdata"
		elseif type(args[i]) == "function" then args[i] = "function"
		elseif type(args[i]) == "thread" then args[i] = "thread"
		end
	end
	local write = table.concat(args, ", ")
	love.filesystem.append("debug.txt", write .. "\n")
end

canvas = {
	width = CANVAS_WIDTH,
	height = CANVAS_HEIGHT,
	scale = TLfres.getScale(CANVAS_WIDTH, CANVAS_HEIGHT),
	aspectRatio = CANVAS_WIDTH / CANVAS_HEIGHT,
	tlfres = TLfres,
}

ID = {
	reset = function(self)
		self.gem = 0
		self.piece = 0
		self.particle = 0
		self.background_particle = 0
		self.character_select = 0
	end
}

FONT = {
	REGULAR = love.graphics.newFont('/fonts/anonymous.ttf', 20)
}

ID:reset()
