-- Windower-like string helper shim for Ashita.

local string_ext = {}

-- Return length of a string (0 when nil).
function string.length(s)
    if not s then return 0 end
    return #s
end

-- Returns true if string starts with prefix.
function string.startswith(s, prefix)
    if not s or not prefix then return false end
    return s:sub(1, #prefix) == prefix
end

-- Returns true if string ends with suffix.
function string.endswith(s, suffix)
    if not s or not suffix then return false end
    return suffix == '' or s:sub(-#suffix) == suffix
end

-- Slice using 1-based inclusive indices (matches Windower's slice).
function string.slice(s, i, j)
    if not s then return s end
    return s:sub(i or 1, j)
end

-- Split string by a separator, returns an array table.
function string.split(s, sep)
    sep = sep or '%s'
    local t = {}
    if not s or s == '' then return t end
    for part in s:gmatch('([^' .. sep .. ']+)') do
        table.insert(t, part)
    end
    return t
end

-- Uppercase first character.
function string.ucfirst(s)
    if not s or s == '' then return s end
    return s:sub(1, 1):upper() .. s:sub(2)
end

return string_ext
