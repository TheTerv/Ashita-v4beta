-- Windower-like tables (T{}) shim for Ashita.

local table_mt = {}
table_mt.__index = table_mt

function table_mt:length()
    return #self
end

function table_mt:clear()
    for k in pairs(self) do
        self[k] = nil
    end
end

function table_mt:it()
    local i = 0
    return function()
        i = i + 1
        if self[i] ~= nil then
            return i, self[i]  -- Return key, value to match Ashita's T{} behavior
        end
        return nil
    end
end

function table_mt:append(v)
    table.insert(self, v)
end

-- Remove element by value (first match).
function table_mt:delete(v)
    for i = 1, #self do
        if self[i] == v then
            table.remove(self, i)
            return
        end
    end
end

-- Sort using Lua's table.sort
function table_mt:sort(cmp)
    table.sort(self, cmp)
end

local function T(t)
    return setmetatable(t or {}, table_mt)
end

-- Shallow merge: copy keys from src into dst and return dst.
function table.update(dst, src)
    for k, v in pairs(src) do
        dst[k] = v
    end
    return dst
end

-- Deep copy (values are copied recursively when tables).
function table.copy(src)
    if type(src) ~= 'table' then
        return src
    end
    local dst = {}
    for k, v in pairs(src) do
        dst[k] = table.copy(v)
    end
    return setmetatable(dst, getmetatable(src))
end

-- Array equality check (length + positional values).
function table.equals(a, b)
    if a == b then return true end
    if type(a) ~= 'table' or type(b) ~= 'table' then return false end
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

-- Only expose globally if Ashita hasn't already defined T (from sugar/table.lua)
-- Ashita's T has more features like containskey that its libs depend on
if _G.T == nil then
    _G.T = T
end

return { new = _G.T or T }
