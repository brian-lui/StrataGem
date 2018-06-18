-- LOVE Async Loading Library (Thread Part)
-- Copyright (c) 2039 Dark Energy Processor
--
-- This software is provided 'as-is', without any express or implied
-- warranty. In no event will the authors be held liable for any damages
-- arising from the use of this software.
--
-- Permission is granted to anyone to use this software for any purpose,
-- including commercial applications, and to alter it and redistribute it
-- freely, subject to the following restrictions:
--
-- 1. The origin of this software must not be misrepresented; you must not
--    claim that you wrote the original software. If you use this software
--    in a product, an acknowledgment in the product documentation would be
--    appreciated but is not required.
-- 2. Altered source versions must be plainly marked as such, and must not be
--    misrepresented as being the original software.
-- 3. This notice may not be removed or altered from any source distribution.

local love = require("love")
local modules, seed, channel, channel_info, errorindicator = ...
local nts_modules = {"graphics", "window"}
local has_graphics = false
local is_love_11 = love._version >= "11.0"

-- We need love.event, always.
require("love.event")
math.randomseed((math.random() + seed) * 1073741823.5)

-- Load modules
for _, v in pairs(modules) do
	local f = false
	if v == "graphics" then has_graphics = true end

	for i = 1, #nts_modules do
		if nts_modules[i] == v then
			f = true
			break
		end
	end

	if not(f) then
		require("love."..v)
	end
end

local thread_lily_id
do
	-- Generate our lily thread id
	-- Lily thread id consist of 64 printable ASCII char
	local t = {}
	for _ = 1, 64 do
		t[#t + 1] = string.char(math.floor(math.random() * 94 + 32))
	end

	-- Supply the thread id
	-- Supply means push + wait until received.
	thread_lily_id = table.concat(t)
	channel_info:supply(thread_lily_id)
	-- Push current lily thread task count
	channel_info:push(0)
end

-- Function handlers
local reg = debug.getregistry()
local lily_processor = {}
local function push_data(req_id, ...)
	return love.event.push("lily_resp", req_id, select(1, ...))
end

-- Macto function to create table handler
local function lily_handler_func(reqtype, minarg, handler)
	lily_processor[reqtype] = {minarg = minarg, handler = handler}
end

if love.audio then
	-- LOVE 11.0 requires 2 arguments to love.audio.newSource
	-- but LOVE 0.10.0 only requires 1
	local argc = is_love_11 and 2 or 1
	lily_handler_func("newSource", argc, function(t)
		return love.audio.newSource(t[1], t[2])
	end)
end

-- Always exist
if love.filesystem then
	lily_handler_func("append", 2, function(t)
		return assert(love.filesystem.append(t[1], t[2], t[3]))
	end)
	lily_handler_func("newFileData", 1, function(t)
		return assert(love.filesystem.newFileData(t[1], t[2], t[3]))
	end)
	lily_handler_func("read", 1, function(t)
		return assert(love.filesystem.read(t[1], t[2]))
	end)
	lily_handler_func("readFile", 1, function(t)
		return reg.File.read(t[1], t[2])
	end)
	lily_handler_func("write", 2, function(t)
		return assert(love.filesystem.write(t[1], t[2], t[3]))
	end)
	lily_handler_func("writeFile", 2, function(t)
		return reg.File.write(t[1], t[2], t[3])
	end)
end

if has_graphics then
	lily_handler_func("newFont", 1, function(t)
		return love.font.newRasterizer(t[1]), t[2]
	end)
	lily_handler_func("newImage", 1, function(t)
		local s, x = pcall(love.image.newCompressedData, t[1])
		return (s and x or love.image.newImageData(t[1])), select(2, unpack(t))
	end)
	lily_handler_func("newVideo", 1, function(t)
		return love.video.newVideoStream(t[1]), t[2]
	end)
	lily_handler_func("newCubeImage", 1, function(t)
		-- If it's not table, then it should be processed with
		-- love.image.newCubeFaces (undocumented function)
		if type(t[1]) ~= "table" then
			local id = t[1]
			if type(id) ~= "userdata" or id:type() ~= "ImageData" then
				id = love.image.newImageData(id)
			end
			t[1] = {love.image.newCubeFaces(id)}
		end
		for i = 1, 6 do
			local v = t[1][i]
			local t = v:type()
			if type(v) ~= "userdata" or (t ~= "ImageData" and t ~= "CompressedImageData") then
				t[1][i] = love.image.newImageData(v)
			end
		end
		return t[1], t[2]
	end)
end

if love.image then
	lily_handler_func("encodeImageData", 1, function(t)
		return reg.ImageData.encode(t[1], t[2])
	end)
	lily_handler_func("newImageData", 1, function(t)
		return love.image.newImageData(t[1])
	end)
	lily_handler_func("newCompressedData", function(t)
		return love.image.newCompressedData(t[1])
	end)
	lily_handler_func("pasteImageData", 7, function(t)
		return reg.ImageData.paste(t[1], t[2], t[3], t[4], t[5], t[6], t[7])
	end)
end

if love.math and not(is_love_11) then
	lily_handler_func("compress", 2, function(t)
		-- lily.compress expects LOVE 11.0 order. That's it, format first then data then level
		return love.math.compress(t[2], t[1], t[3])
	end)
	lily_handler_func("decompress", 1, function(t)
		-- lily.decompress expects LOVE 11.0 order too.
		if type(t[1]) == "string" then
			-- string supplied as first argument (format)
			return love.math.decompress(t[2], t[1])
		else
			-- CompressedData supplied as first argument
			return love.math.decompress(t[1])
		end
	end)
elseif love.data then
	lily_handler_func("compress", 2, function(t)
		return love.data.compress("data", t[1], t[2], t[3])
	end)
	lily_handler_func("decompress", 1, function(t)
		return love.data.decompress("data", t[1], t[2])
	end)
end

if love.sound then
	lily_handler_func("newSoundData", 1, function(t)
		return love.sound.newSoundData(t[1], t[2], t[3], t[4])
	end)
end

if love.video then
	lily_handler_func("newVideoStream", 1, function(t)
		return love.video.newVideoStream(t[1])
	end)
end

-- Function to update the current task count
-- Meant to be passed to Channel:performAtomic
local function decrease_task_count()
	local task_count = channel_info:pop()

	if not(task_count) then return end
	channel_info:push(task_count - 1)
end

local function not_quit()
	return channel_info:getCount() == 1
end

-- If main thread puses anything to channel_info, or pop the count, that means we should exit
while channel_info:performAtomic(not_quit) do
	-- Structure
	-- 1. thread_id
	-- 2. task type
	-- 3. request ID
	-- 4. argument count
	-- n arguments.
	local tid = channel:demand()
	if not(not_quit()) then return end -- These 3 checks must be on each demand!
	local tasktype = channel:demand()
	if not(not_quit()) then return end -- so even on incomplete, we cna quit
	local req_id = channel:demand()
	if not(not_quit()) then return end -- faster and more earlier.
	

	if not(lily_processor[tasktype]) then
		-- We don't know such event.
		local argcount = channel:demand()
		for i = 1, argcount do
			channel:pop()
		end
	else
		-- We know such event.
		local task = lily_processor[tasktype]
		local inputs = {}

		-- Get all arguments first, so the channel is clean.
		local argcount = channel:demand()
		for i = 1, argcount do
			inputs[i] = channel:demand()
		end
		
		if argcount < task.minarg then
			-- Error: too few arguments
			push_data(req_id, errorindicator, string.format("'%s': too few arguments (at least %d is required)", tasktype, task.minarg))
		else
			local result = {pcall(task.handler, inputs)}

			if result[1] == false then
				-- Error
				push_data(req_id, errorindicator, string.format("'%s': %s", tasktype, result[2]))
			else
				-- Remove first element
				for i = 2, #result do
					result[i - 1] = result[i]
				end
				result[#result] = nil

				-- Unfortunately, due to default love.run way to handle events
				-- we can't pass more than 6 arguments to event.
				-- We must pass "req_id", which means we only able to return 5 values.
				if #result == 0 then
					push_data(req_id)
				elseif #result == 1 then
					push_data(req_id, result[1])
				elseif #result == 2 then
					push_data(req_id, result[1], result[2])
				elseif #result == 3 then
					push_data(req_id, result[1], result[2], result[3])
				elseif #result == 4 then
					push_data(req_id, result[1], result[2], result[3], result[4])
				elseif #result >= 5 then
					push_data(req_id, result[1], result[2], result[3], result[4], result[5])
				end
			end
		end
	end

	channel_info:performAtomic(decrease_task_count)
end
