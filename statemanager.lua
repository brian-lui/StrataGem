--[[
Copyright (c) 2010-2013 Matthias Richter

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

Except as contained in this notice, the name(s) of the above copyright holders
shall not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]--

--[[
HOW TO USE

  local object = {x = 1}
	function object:update()
		print(self.x)
	end

	local someState = {}
	function someState:update()
		self.x = self.x + 1
		print(self.x)
	end

	object.stateManager = common.instance(require "statemanager", object)
	object.stateManager:switch(someState)
	-- Some time later, when object:update() is called, someState.update(object)
	-- is called afterward, resulting in the output:
	-- 1
	-- 2

	In addition to standard Love2D callbacks, the state manager calls state:init()
	the first time `state` is switched to or pushed, state:enter() every time
	`state` is switched to or pushed, and state:leave() every time `state` is
	switched from or popped.
--]]

local common
do
	local success
	success, common = pcall(require, "class.commons")
	if not success then
		common = require "classcommons"
	end
end

local function __NULL__() end

local SM = {}

-- fetch event callbacks from love.handlers
local all_callbacks = { 'draw', 'errhand', 'update' }
for k in pairs(_G.love.handlers) do
	all_callbacks[#all_callbacks+1] = k
end

local function registerEvents(self, callbacks)
	local registry = {}
	callbacks = callbacks or all_callbacks
	for _, f in ipairs(callbacks) do
		registry[f] = self.parentObject[f] or __NULL__
		self.parentObject[f] = function(...)
			registry[f](...)
			return self:pass(f)(...)
		end
	end
end

function SM:init(parentObject)
	assert(type(parentObject) == "table", "No parentObject given to StateManager constructor")
	self.parentObject = parentObject
	registerEvents(self)
	self.state_init = setmetatable({leave = __NULL__},	-- default gamestate produces error on every callback
			{__index = function() error("StateManager not initialized. Use StateManager:switch()") end})
	self.stack = {self.state_init}
	self.initialized_states = setmetatable({}, {__mode = "k"})
	self.state_is_dirty = true
end

local function change_state(self, stack_offset, to, ...)
	local pre = self.stack[#self.stack]

	-- initialize only on first call
	;(self.initialized_states[to] or to.init or __NULL__)(self.parentObject)
	self.initialized_states[to] = __NULL__

	self.stack[#self.stack+stack_offset] = to
	self.state_is_dirty = true
	return (to.enter or __NULL__)(self.parentObject, pre, ...)
end

function SM:switch(to, ...)
	assert(to, "Missing argument: Gamestate to switch to")
	assert(to ~= SM, "Can't call switch with colon operator")
	;(self.stack[#self.stack].leave or __NULL__)(self.parentObject)
	return change_state(self, 0, to, ...)
end

function SM:push(to, ...)
	assert(to, "Missing argument: Gamestate to switch to")
	assert(to ~= SM, "Can't call push with colon operator")
	return change_state(self, 1, to, ...)
end

function SM:pop(...)
	assert(#self.stack > 1, "No more states to pop!")
	local pre, to = self.stack[#self.stack], self.stack[#self.stack-1]
	self.stack[#self.stack] = nil
	;(pre.leave or __NULL__)(self.parentObject)
	self.state_is_dirty = true
	return (to.resume or __NULL__)(to, pre, ...)
end

function SM:current()
	return self.stack[#self.stack]
end

function SM:pass(callback)
	if not self.state_is_dirty or callback == 'update' then
		self.state_is_dirty = false
		return function(...)
			return (self.stack[#self.stack][callback] or __NULL__)(...)
		end
	end
	return __NULL__
end

return common.class("StateManager", SM)
