local dats = require('ffxi.dats');

local lib = {};

local identifierLookup = T{
    ['Index (Decimal)'] = function(self)
        return string.format('%u', bit.band(self.Id, 0x7FF));
    end,
    ['Index (Hex)'] = function(self)
        return string.format('0x%03X', bit.band(self.Id, 0x7FF));
    end,
    ['Id (Decimal)'] = function(self)
        return string.format('%u', self.Id);
    end,
    ['Id (Hex)'] = function(self)
        return string.format('0x%X', self.Id);
    end,
};
local MobEntry = T{};
function MobEntry:New(id, name)
    local mobEntry = {
        Id = id,
        Name = name,
        Alias = name,
        Alarm = false,
        Color = gSettings.DefaultColor,
        Draw = true,
        Widescan = false,
    };
    setmetatable(mobEntry, self);
    self.__index = self;
    return mobEntry;
end
function MobEntry:ToString()
    return string.format('[%s]%s%s', identifierLookup[gSettings.IdentifierType](self), self.Name, self.Alias == self.Name and '' or ('('..self.Alias..')'));
end

--[[
    Credit to atom0s for the bulk of this function, taken from watchdog.
]]--
function lib:Load(zid, sid)
    local output = T{};

    local file = dats.get_zone_npclist(zid, sid);
    if (file == nil or file:len() == 0) then
        print(chat.header(addon.name):append(chat.error('Failed to determine zone entity DAT file for current zone. [zid: %d, sid: %d]'):fmt(zid, sid)));
        return output;
    end

    local f = io.open(file, 'rb');
    if (f == nil) then
        print(chat.header(addon.name):append(chat.error('Failed to access zone entity DAT file for current zone. [zid: %d, sid: %d]'):fmt(zid, sid)));
        return output;
    end

    local size = f:seek('end');
    f:seek('set', 0);

    if (size == 0 or ((size - math.floor(size / 0x20) * 0x20) ~= 0)) then
        f:close();
        print(chat.header(addon.name):append(chat.error('Failed to validate zone entity DAT file for current zone. [zid: %d, sid: %d]'):fmt(zid, sid)));
        return output;
    end

    for _ = 0, ((size / 0x20) - 0x01) do
        local data = f:read(0x20);
        local name, id = struct.unpack('c28L', data);
        name = name:trim('\0');

        if id > 0 and string.len(name) > 0 then
            local entry = MobEntry:New(id, name);
            local settingData = gSettings.Monitored[id];
            if settingData then
                if settingData.Name == entry.Name then
                    for k,v in pairs(settingData) do
                        entry[k] = v;
                    end
                    gSettings.Monitored[id] = entry;
                else
                    gSettings.Monitored[id] = nil;
                    gUpdate = true;
                    gUpdateTimer = os.clock() + 5;
                end
            end
            output[id] = entry;
        end
    end

    f:close();
    return output;
end

return lib;
