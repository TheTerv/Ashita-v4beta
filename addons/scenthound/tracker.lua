local active = T{};
local lastSend = 0;

local degreeMap = {
    { Degrees=-168.75, Direction="S" },
    { Degrees=-146.25, Direction="SSW" },
    { Degrees=-123.75, Direction="SW" },
    { Degrees=-101.25, Direction="WSW" },
    { Degrees=-78.75, Direction="W" },
    { Degrees=-56.25, Direction="WNW" },
    { Degrees=-33.75, Direction="NW" },
    { Degrees=-11.25, Direction="NNW" },
    { Degrees=11.25, Direction="N" },
    { Degrees=33.75, Direction="NNE" },
    { Degrees=56.25, Direction="NE" },
    { Degrees=78.75, Direction="ENE" },
    { Degrees=101.25, Direction="E" },
    { Degrees=123.75, Direction="ESE" },
    { Degrees=146.25, Direction="SE" },
    { Degrees=168.75, Direction="SSE" },
};

local function GetDirection(position)
    local myEntity = GetPlayerEntity();
    if position == nil or myEntity == nil then
        return ', but position could not be detected';
    end

    local myPosition = {
        X = myEntity.Movement.LocalPosition.X,
        Y = myEntity.Movement.LocalPosition.Y,
        Z = myEntity.Movement.LocalPosition.Z,
    }
    
    local xDiff = myPosition.X - position.X;
    local yDiff = myPosition.Y - position.Y;
    local distance = math.sqrt((xDiff * xDiff) + (yDiff * yDiff));
    local direction = 'S';
    
    local rads = math.atan2(position.X - myPosition.X, position.Y - myPosition.Y);
    local degrees = (rads * (180 / math.pi));
    for _,entry in ipairs(degreeMap) do
        if entry.Degrees > degrees then
            direction = entry.Direction;
            break;
        end
    end

    return string.format(' %0.1f yalms %s', distance, direction);
end


local tracker = {};

function tracker:HandleEntityUpdate(e)
    local id = struct.unpack('L', e.data, 0x04 + 1);
    local entry = gZoneList[id];
    if entry and gSettings.Monitored[id] then
        local mask = struct.unpack('B', e.data, 0x0A+1);
        --If flags sent and hidden, mark inactive..
        if (bit.band(mask, 0x07) ~= 0) then
            local flags1 = struct.unpack('L', e.data, 0x20+1);
            if bit.band(flags1, 0x02) == 2 then
                active[id] = nil;
                return;
            end
        else
            --Not dealing with these packets..
            if bit.band(mask, 0x20) == 0x20 then
                active[id] = nil;
            end
            return;
        end

        --If hp sent and zero, mark inactive..
        if (bit.band(mask, 0x04) == 0x04) then
            local hp = struct.unpack('B', e.data, 0x1E+1);
            if (hp == 0) then
                active[id] = nil;
                return;
            end
        elseif AshitaCore:GetMemoryManager():GetEntity():GetHPPercent(bit.band(id, 0xFFF)) == 0 then
            active[id] = nil;
            return;
        end
        
        --If already active, no need to alert again.
        if active[id] then
            return;
        end

        --Get position..
        local index = struct.unpack('H', e.data, 0x08 + 1);
        local position;
        if bit.band(mask, 0x01) == 0x01 then
            position = {
                X = struct.unpack('f', e.data, 0x0C+1),
                Y = struct.unpack('f', e.data, 0x14+1),
                Z = struct.unpack('f', e.data, 0x10+1)
            };
        else
            local enemyEntity = GetEntity(index);
            if enemyEntity then
                position = {
                    X = enemyEntity.Movement.LocalPosition.X,
                    Y = enemyEntity.Movement.LocalPosition.Y,
                    Z = enemyEntity.Movement.LocalPosition.Z,
                };
            else
                position = gWidescanCache[index];
            end
        end

        if entry.Alarm then
            local path = string.format('%s/assets/%s', addon.path, gSettings.Sound);
            ashita.misc.play_sound(path);
        end

        if entry.Widescan then
            local cmd = string.format('/watchdog track %u', bit.band(id, 0x7FF));
            AshitaCore:GetChatManager():QueueCommand(-1, cmd);
        end

        print(chat.header('ScentHound') .. chat.message(string.format('%s popped%s.', entry:ToString(), GetDirection(position))));
        active[id] = true;
    end
end

function tracker:HandleZone()
    active = T{};
end

ashita.events.register('packet_out', 'scenthound_handleoutgoingpacket', function (e)
    if e.id == 0x15 and gSettings.AllowPacketSearch and os.clock() > (lastSend + gSettings.PacketSearchDelay) then
        local sortable = T{};
        for entry,lastSearch in pairs(gPacketList) do
            sortable:append({ Entry=entry, LastSearch=lastSearch });
        end
        table.sort(sortable, function(a,b) return a.LastSearch < b.LastSearch end);
        if sortable[1] then
            local packet = struct.pack('LL', 0, bit.band(sortable[1].Entry.Id, 0x7FF));
            AshitaCore:GetPacketManager():AddOutgoingPacket(0x16, packet:totable());
            print(chat.header('ScentHound') .. chat.message(string.format('Sent update request packet for %s.', sortable[1].Entry:ToString())));
            gPacketList[sortable[1].Entry] = os.clock();
            lastSend = os.clock();
        end
    end
end);

return tracker;