--[[
This is all the text, currently has vs_quotes and win_quotes.
We put it in a separate file for convenience and possible ease of translation.

Permissible font sizes: "big", "medium", "small"
Big takes up 3 rows of space. Medium takes up 2 rows. Small takes up 1 row.
Currently we have enough space to comfortably display 6 rows in vs_quotes
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

vs_quotes.default = {
	{
		{
			size = "big",
			text = "Smells like updog in here.",
		},
		{
			size = "small",
			text = "Not much what's up with you dog?",
		},
	},
	{
		{
			size = "small",
			text = "It was the best of times, it was the worst of times.",
		},
		{
			size = "big",
			text = "In bed",
		},
	},
}

--vs_quotes.heath
--vs_quotes.walter
--vs_quotes.gail
--vs_quotes.holly
--vs_quotes.wolfgang
--vs_quotes.hailey
--vs_quotes.diggory
--vs_quotes.buzz
--vs_quotes.ivy
--vs_quotes.joy
--vs_quotes.mort
--vs_quotes.damon


win_quotes.default = {
	{
		{size = "big", text = "I win."},
		{size = "small", text = "Thanks."},
	},
	{
		{size = "medium", text = "You lose."},
		{size = "medium", text = "Sorry."},
		{size = "small", text = "In bed"},
	},
}

--win_quotes.heath
--win_quotes.walter
--win_quotes.gail
--win_quotes.holly
--win_quotes.wolfgang
--win_quotes.hailey
--win_quotes.diggory
--win_quotes.buzz
--win_quotes.ivy
--win_quotes.joy
--win_quotes.mort
--win_quotes.damon

return {
	vs_quotes = vs_quotes,
	win_quotes = win_quotes,
}