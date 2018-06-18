local getmetatable, setmetatable, pairs = getmetatable, setmetatable, pairs

local metamethods = {	-- Everything but index and newindex
	"__add", "__band", "__bor", "__bxor", "__bnot", "__call", "__concat", "__div",
	"__eq", "__gc", "__ipairs", "__idiv", "__le", "__len", "__lt", "__metatable",
	"__mod", "__mode", "__mul", "__pairs", "__pow", "__shl", "__shr", "__sub",
	"__tostring",	"__unm"
}

local function writeError()
	error("tried writing to class (read-only)", 2)
end

local common = {
	class = function (name, class, superclass)
		if type(class) ~= "table" then
			error("bad argument #2 to 'common.class' (table expected)", 2)
		end

		local mt = getmetatable(class) or {}
		setmetatable(class, mt)

		mt.__class = type(name) == "string" and name or true
		if superclass then
			local _mt = getmetatable(superclass) or {}
			if not _mt.__class then
				error("tried to subclass non-class", 2)
			else
				-- Inherit metamethods (except index and newindex)
				for _, m in pairs(metamethods) do
					mt[m] = mt[m] or _mt[m]
				end

				mt.__index = superclass
			end
		end

		-- Make class readonly by storing members elsewhere and mediating reads/writes
		local backend = setmetatable({}, mt.__index and {__index = mt.__index})
		for k, v in pairs(class) do
			backend[k] = v
			class[k] = nil
		end
		mt.__index = backend
		mt.__newindex = writeError

		-- Make class metamethods readonly (doesn't throw error though)
		local mt_copy = {}
		for _, m in pairs(metamethods) do
			mt_copy[m] = mt[m]
		end
		mt_copy.__class = mt.__class
		mt.__metatable = mt_copy

		return class
	end,

	instance = function (class, ...)
		local _mt = getmetatable(class)
		if not _mt or not _mt.__class then
			error("tried to instantiate non-class", 2)
		end

		local mt = {__index = class}
		local i = setmetatable({}, mt)


		for _, m in pairs(metamethods) do	-- Copy metamethods (except index, newindex, class, and name)
			mt[m] = _mt[m]
		end

		if i.init then -- Initialize
			i:init(...)
		end
		return i
	end
}

package.loaded["class.commons"] = package.loaded["class.commons"] or common

return common
