-- Windower-like lists (L{}) shim for Ashita.

local list_mt = {}
list_mt.__index = list_mt

-- Return number of elements.
function list_mt:length()
    return #self
end

-- Clear all elements.
function list_mt:clear()
    for i = #self, 1, -1 do
        self[i] = nil
    end
end

-- Iterator that yields (key, value) pairs to match Ashita's T{} behavior.
function list_mt:it()
    local i = 0
    return function()
        i = i + 1
        if self[i] ~= nil then
            return i, self[i]
        end
        return nil
    end
end

-- Append value.
function list_mt:append(v)
    table.insert(self, v)
end

local function L(t)
    return setmetatable(t or {}, list_mt)
end

-- Expose globally to mirror Windower behavior.
_G.L = L

return { new = L }
