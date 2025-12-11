
local drawing = require('drawing');

local function GetBone(actorPointer, bone)
    local x = ashita.memory.read_float(actorPointer + 0x678);
    local y = ashita.memory.read_float(actorPointer + 0x680);
    local z = ashita.memory.read_float(actorPointer + 0x67C);

    local skeletonBaseAddress = ashita.memory.read_uint32(actorPointer + 0x6B8);

    local skeletonOffsetAddress = ashita.memory.read_uint32(skeletonBaseAddress + 0x0C);

    local skeletonAddress = ashita.memory.read_uint32(skeletonOffsetAddress);

    local boneCount = ashita.memory.read_uint16(skeletonAddress + 0x32);

    local bufferPointer = skeletonAddress + 0x30;
    local skeletonSize = 0x04;
    local boneSize = 0x1E;

    local generatorsAddress = bufferPointer + skeletonSize + boneSize * boneCount + 4;

    return x + ashita.memory.read_float(generatorsAddress + (bone * 0x1A) + 0x0E + 0x0),
        y + ashita.memory.read_float(generatorsAddress + (bone * 0x1A) + 0x0E + 0x8),
        z + ashita.memory.read_float(generatorsAddress + (bone * 0x1A) + 0x0E + 0x4)
end

local function Tick()
    local myEntity = GetPlayerEntity();
    if myEntity == nil then
        return;
    end
    local myPosition = {
        X = myEntity.Movement.LocalPosition.X,
        Y = myEntity.Movement.LocalPosition.Y,
        Z = myEntity.Movement.LocalPosition.Z,
    }

    local entMgr = AshitaCore:GetMemoryManager():GetEntity();
    local drawList = T{};
    for index=1,0x400 do
        local id = entMgr:GetServerId(index);
        if id > 0 then
            local settings = gSettings.Monitored[id];
            if settings and settings.Draw then
                local entity = GetEntity(index);
                if entity then                
                    local targetPosition = {
                        X = entity.Movement.LocalPosition.X,
                        Y = entity.Movement.LocalPosition.Y,
                        Z = entity.Movement.LocalPosition.Z,
                    }
                    local xDiff = targetPosition.X - myPosition.X;
                    local yDiff = targetPosition.Y - myPosition.Y;
                    local distance = math.sqrt((xDiff * xDiff) + (yDiff * yDiff));

                    local draw = false;
                    local isRendered = (bit.band(entity.Render.Flags0, 0x200) == 0x200) and (bit.band(entity.Render.Flags0, 0x4000) == 0);
                    if (isRendered) then
                        local srcPointer = entity.ActorPointer;
                        local xOffset,yOffset,zOffset = GetBone(srcPointer, 2);
                        targetPosition.Z = (ashita.memory.read_float(srcPointer + 0x67C) + zOffset) / 2;
                        draw = distance > 5;
                    elseif (bit.band(entity.Render.Flags0, 0x00040000) == 0) then
                        draw = true;
                    end

                    if draw then
                        drawList:append({Position=targetPosition, Color=settings.Color or gSettings.DefaultColor });
                    end
                else
                    local ws = gWidescanCache[index];
                    if ws then
                        drawList:append({Position=ws, Color=settings.Color or gSettings.DefaultColor });
                    end
                end
            end
        end
    end
    
    if #drawList == 0 then
        return;
    end

    do
        local srcPointer = myEntity.ActorPointer;
        local xOffset,yOffset,zOffset = GetBone(srcPointer, 2);
        myPosition.Z = (ashita.memory.read_float(srcPointer + 0x67C) + zOffset) / 2;
    end

    for _,entry in ipairs(drawList) do
        drawing:DrawLine(myPosition, entry.Position, entry.Color);
    end
end

local exports = T{
    Tick = Tick,
};
return exports;