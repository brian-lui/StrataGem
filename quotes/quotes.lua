--[[
This file converts the formatted text data into tables.

Permissible font sizes: "big", "medium", "small"
Big takes up 3 rows of space. Medium takes up 2 rows. Small takes up 1 row.
Currently we have enough space to comfortably display 6 rows in vs_quotes

#Hash symbol indicates a comment, will not be parsed
blank lines also will not be parsed
`Backtick indiates a new section
*Asterisk indicates a new sub-section
~Tilde indicates a new quote

Each quote has 3 parts:
	--- indicates new quote
	next line, big/medium/small indicates font size
	next line is the quote itself
	repeat these two

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

local TextReader = {}

TextReader.vs_quotes = {}
TextReader.win_quotes = {}

TextReader.container_lookup = {
	vs_quotes = TextReader.vs_quotes,
	win_quotes = TextReader.win_quotes,
}

TextReader.FILENAME = "/quotes/text.txt"
TextReader.line_count = 0
TextReader.current_character = "dummy"
TextReader.current_field = "size"

function TextReader:setContainer(line)
	local new_container = line:sub(2):lower()
	self.container = self.container_lookup[new_container]
	assert(self.container, "Invalid container provided on line " .. self.line_count)
end

function TextReader:setCharacter(line)
	local new_character = line:sub(2):lower()
	self.container[new_character] = self.container[new_character] or {}
	self.current_character = new_character
end

function TextReader:setNewQuote()
	local char = self.container[self.current_character]
	char[#char + 1] = {}
end

function TextReader:writeCharacterLine(line)
	local char = self.container[self.current_character]
	local quote = char[#char]
	if self.current_field == "size" then
		local s = line:lower()
		assert(s == "big" or s == "medium" or s == "small",
			"Invalid size provided on line " .. self.line_count .. ": " .. s)
		quote[#quote + 1] = {}
		quote[#quote].size = s
		self.current_field = "text"
	elseif self.current_field == "text" then
		quote[#quote].text = line
		self.current_field = "size"
	else
		error("Invalid self.current_field: ", self.current_field)
	end
end

function TextReader:readFile()
	for line in love.filesystem.lines(self.FILENAME) do
		self.line_count = self.line_count + 1
		local first_char = line:sub(1, 1)
		if #line > 0 and first_char ~= "#" then
			if first_char == "`" then
				self:setContainer(line)
			elseif first_char == "*" then
				self:setCharacter(line)
			elseif first_char == "~" then
				self:setNewQuote()
			else
				self:writeCharacterLine(line)
			end
		end
	end
end

function TextReader:verifyTables()
	for char_name, quotes in pairs(self.vs_quotes) do
		assert(#quotes > 0, char_name .. " has no vs_quotes!")
	end

	--[[
	for char_name, quotes in pairs(self.win_quotes) do
		assert(#quotes > 0, char_name .. " has no win_quotes!")
	end
	--]]
end

TextReader:readFile()
TextReader:verifyTables()

return {
	vs_quotes = TextReader.vs_quotes,
	win_quotes = TextReader.win_quotes,
}