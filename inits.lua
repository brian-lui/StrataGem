local love = _G.love

-- For compatibility; Lua 5.3 moved unpack to table.unpack
_G.table.unpack = _G.table.unpack or _G.unpack

print(love.filesystem.getSaveDirectory())

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

window = {
	width = 1920,
	height = 1080,
	resize = 2/3,
}

ID = {
	reset = function(self)
		self.gem, self.piece, self.particle, self.background = 0, 0, 0, 0
	end
}

FONT = {
	REGULAR = love.graphics.newFont('/fonts/anonymous.ttf', 20)
}

ID:reset()
