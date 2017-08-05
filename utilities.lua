local utilities = {}

function utilities.spairs(tab, ...)
	local keys,vals,idx = {},{},0
	for k in pairs(tab) do
		keys[#keys+1] = k
	end
	table.sort(keys, ...)
	for i=1,#keys do
		vals[i]=tab[keys[i]]
	end
	return function()
		idx = idx + 1
		return keys[idx], vals[idx]
	end
end

function utilities.reverseTable(table)
	local reversedTable = {}
	local itemCount = #table
	for k, v in ipairs(table) do
		reversedTable[itemCount + 1 - k] = v
	end
	return reversedTable
end

function utilities.pointIsInRect(x, y, rx, ry, rw, rh)
	return x >= rx and y >= ry and x < rx + rw and y < ry + rh
end

local deepcpy_mapping = {}
local function real_deepcpy(tab)
  if deepcpy_mapping[tab] ~= nil then
    return deepcpy_mapping[tab]
  end
  local ret = {}
  deepcpy_mapping[tab] = ret
  deepcpy_mapping[ret] = ret
  for k,v in pairs(tab) do
    if type(k) == "table" then
      k=real_deepcpy(k)
    end
    if type(v) == "table" then
      v=real_deepcpy(v)
    end
    ret[k]=v
  end
  return setmetatable(ret, getmetatable(tab))
end

function utilities.deepcpy(tab)
  if type(tab) ~= "table" then
		return tab
	end
  local ret = real_deepcpy(tab)
  deepcpy_mapping = {}
  return ret
end

return utilities
