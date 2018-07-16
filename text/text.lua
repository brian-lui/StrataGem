--[[
This file converts the formatted text data into tables.

Return format:
An array of [quote number][line number]{size, text} e.g.
{
	{
		{size = "big", text = "You're fired!"},
		{size = "small", text = "In my younger and more vulnerable days"},
	},
	{
		{size = "medium", text = "Smells like updog in here."},
		{size = "medium", text = "What's updog?"},
		{size = "medium", text = "Not much what's up with you dog?"},
	},
}
--]]

local vs_quotes = {}
local win_quotes = {}

for line in love.filesystem.lines("/text/texts.txt") do
	print(line)
end

return {
	vs_quotes = vs_quotes,
	win_quotes = win_quotes,
}