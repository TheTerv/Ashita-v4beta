--[[
    Windower 'config' library compatibility shim for Ashita v4

    This is a temporary, simplified shim.
    It does not actually load or parse XML files.
    Instead, it simply returns the provided 'defaults' table.
    This allows the addon to load and use default settings.
]]--

local config = {};

-- shallow/deep copy helper
local function deep_copy(src)
    if type(src) ~= 'table' then
        return src;
    end
    local dst = {};
    for k, v in pairs(src) do
        dst[k] = deep_copy(v);
    end
    return dst;
end

-- A mock 'load' function that just returns the defaults.
-- Supports both Windower signatures:
--   config.load(defaults_table)
--   config.load(path_string, defaults_table)
function config.load(path, defaults)
    -- Allow single-arg form where the defaults table is passed as the first parameter.
    if type(path) == 'table' and defaults == nil then
        defaults = path;
    end

    local loaded = {};
    if defaults then
        loaded = deep_copy(defaults);
    end

    -- No-op save to satisfy callers.
    function loaded:save() end
    return loaded;
end

return config;
