--[[
    Windower to Ashita v4 Adapter

    This module provides a compatibility layer that maps Windower API calls
    to their Ashita v4 equivalents, allowing the original XivParty code to
    work with minimal modifications.
]]--

local adapter = {};
local const = require('const');

----------------------------------------------------------------------------------------------------
-- Helper: Get Memory Manager interfaces
----------------------------------------------------------------------------------------------------

local function getPartyManager()
    return AshitaCore:GetMemoryManager():GetParty();
end

local function getPlayerManager()
    return AshitaCore:GetMemoryManager():GetPlayer();
end

local function getTargetManager()
    return AshitaCore:GetMemoryManager():GetTarget();
end

-- Internal handler registries for Windower-style event shims
local keyboardHandlers = {};
local mouseHandlers = {};
local nextHandlerId = 1;
local isShimEventsRegistered = false;

----------------------------------------------------------------------------------------------------
-- windower.ffxi.get_info()
-- Returns game state information (zone, logged_in status, etc.)
----------------------------------------------------------------------------------------------------
function adapter.get_info()
    local info = {};

    local party = getPartyManager();
    local playerEntity = GetPlayerEntity();

    -- Zone ID (player is always index 0 in party)
    info.zone = party:GetMemberZone(0);

    -- Check if logged in by verifying player entity exists and has a name
    info.logged_in = (playerEntity ~= nil and playerEntity.Name ~= nil and playerEntity.Name ~= '');

    return info;
end

----------------------------------------------------------------------------------------------------
-- windower.ffxi.get_player()
-- Returns current player data (name, jobs, buffs, etc.)
--
-- SDK Reference (Ashita.h):
--   IPlayer: GetHPMax(), GetMPMax(), GetMainJob(), GetSubJob(), etc. (NO GetHP/GetMP/GetTP!)
--   IParty:  GetMemberHP(0), GetMemberMP(0), GetMemberTP(0), GetMemberHPPercent(0), GetMemberMPPercent(0)
--   Entity:  HPPercent only (NO HP, MP, TP, MPPercent fields)
----------------------------------------------------------------------------------------------------
function adapter.get_player()
    local playerData = {};
    local player = getPlayerManager();
    local playerEntity = GetPlayerEntity();
    local party = getPartyManager();

    -- Name and ID from entity
    if playerEntity then
        playerData.name = playerEntity.Name;
        playerData.id = playerEntity.ServerId;
    end

    -- Job information (IPlayer has these)
    playerData.main_job = player:GetMainJob();
    playerData.main_job_id = player:GetMainJob();
    playerData.main_job_level = player:GetMainJobLevel();
    playerData.sub_job = player:GetSubJob();
    playerData.sub_job_id = player:GetSubJob();
    playerData.sub_job_level = player:GetSubJobLevel();

    -- HP/MP/TP values from IParty (self is index 0) - THIS IS THE CORRECT SOURCE
    playerData.hp = party:GetMemberHP(0) or 0;
    playerData.mp = party:GetMemberMP(0) or 0;
    playerData.tp = party:GetMemberTP(0) or 0;
    playerData.hpp = party:GetMemberHPPercent(0) or 0;
    playerData.mpp = party:GetMemberMPPercent(0) or 0;

    -- Max values from IPlayer (for reference, not currently used by XivParty)
    playerData.hp_max = player:GetHPMax() or 0;
    playerData.mp_max = player:GetMPMax() or 0;

    -- Buffs array (1-32, matching Windower's 1-based indexing)
    playerData.buffs = {};
    local buffs = nil;
    local okGet, res = pcall(function()
        if player.GetBuffs ~= nil then
            return player:GetBuffs();
        end
        return nil;
    end)
    if okGet then buffs = res end
    local function assignBuff(idx, v)
        if v and type(v) == 'number' and v > 0 and v ~= 255 then
            playerData.buffs[idx] = v
        else
            playerData.buffs[idx] = nil
        end
    end

    if type(buffs) == 'table' then
        for i = 1, const.maxBuffs do
            assignBuff(i, buffs[i])
        end
    elseif type(buffs) == 'userdata' then
        -- Some Ashita APIs return a userdata array; try to index it.
        for i = 1, const.maxBuffs do
            local ok, v = pcall(function() return buffs[i] end)
            if ok then
                assignBuff(i, v)
            end
        end
    end

    return playerData;
end

----------------------------------------------------------------------------------------------------
-- windower.ffxi.get_party()
-- Returns party and alliance member data
-- Windower format: { p0={}, p1={}, ..., p5={}, a10={}, a11={}, ..., a25={}, party1_leader=name }
--
-- SDK Reference (Ashita.h):
--   IParty: GetMemberHP(i), GetMemberMP(i), GetMemberTP(i), GetMemberHPPercent(i), GetMemberMPPercent(i)
--   Entity: Only HPPercent available (NO HP, MP, TP, MPPercent fields!)
----------------------------------------------------------------------------------------------------
function adapter.get_party()
    local partyData = {};
    local party = getPartyManager();
    local playerZone = party:GetMemberZone(0);

    -- Party key format: p0-p5 (main party), a10-a15 (alliance 1), a20-a25 (alliance 2)
    local keyFormats = { 'p%d', 'a1%d', 'a2%d' };

    for i = 0, 17 do
        local partyIndex = math.floor(i / 6);  -- 0, 1, or 2
        local memberIndex = i % 6;              -- 0-5 within party
        local key = string.format(keyFormats[partyIndex + 1], memberIndex);

        local memberName = party:GetMemberName(i);

        -- Check if member actually exists (name is not nil/empty)
        if memberName and memberName ~= '' then
            local member = {};

            member.name = memberName;
            member.zone = party:GetMemberZone(i);

            -- HP/MP/TP from IParty - THIS IS THE CORRECT AND ONLY RELIABLE SOURCE
            member.hp = party:GetMemberHP(i) or 0;
            member.mp = party:GetMemberMP(i) or 0;
            member.tp = party:GetMemberTP(i) or 0;
            member.hpp = party:GetMemberHPPercent(i) or 0;
            member.mpp = party:GetMemberMPPercent(i) or 0;

            -- Get entity for mob sub-table (distance, is_npc, etc.)
            local targetIndex = party:GetMemberTargetIndex(i);
            local entity = nil;
            if targetIndex > 0 then
                entity = GetEntity(targetIndex);
            end

            if entity then
                -- Mob sub-table (matches Windower structure)
                member.mob = {
                    id = entity.ServerId or party:GetMemberServerId(i),
                    name = entity.Name,
                    index = targetIndex,
                    is_npc = (entity.SpawnFlags == 16),  -- Trusts have SpawnFlags 16
                    distance = entity.Distance,
                    models = { entity.ModelHair or 0 }  -- Model info for trust detection
                };
            else
                member.mob = nil;
            end

            partyData[key] = member;

            -- Track party leader (first member of main party, index 0)
            if i == 0 then
                partyData.party1_leader = member.name;
            end
        else
            partyData[key] = nil;
        end
    end

    -- Alliance party counts
    partyData.party1_count = party:GetAlliancePartyMemberCount1();

    return partyData;
end

----------------------------------------------------------------------------------------------------
-- windower.ffxi.get_mob_by_target(target_type)
-- Returns mob data for a target type: 't' (target), 'st' (subtarget), etc.
----------------------------------------------------------------------------------------------------
function adapter.get_mob_by_target(targetType)
    local target = getTargetManager();
    local targetIndex = 0;

    if targetType == 't' then
        targetIndex = target:GetTargetIndex(0);  -- Main target
    elseif targetType == 'st' or targetType == 'stpt' or targetType == 'stal' then
        targetIndex = target:GetTargetIndex(1);  -- Sub-target
    end

    if targetIndex == 0 then
        return nil;
    end

    local entity = GetEntity(targetIndex);
    if not entity then
        return nil;
    end

    return {
        id = entity.ServerId,
        name = entity.Name,
        index = targetIndex,
        hpp = entity.HPPercent,
        distance = entity.Distance,
        is_npc = (entity.SpawnFlags == 16)
    };
end

----------------------------------------------------------------------------------------------------
-- windower.send_command(command)
-- Executes a game command
----------------------------------------------------------------------------------------------------
function adapter.send_command(command)
    AshitaCore:GetChatManager():QueueCommand(-1, command);
end

----------------------------------------------------------------------------------------------------
-- windower.add_to_chat(mode, message)
-- Adds a message to the chat log
----------------------------------------------------------------------------------------------------
function adapter.add_to_chat(mode, message)
    -- Use print for now - Ashita's chat module handles formatting
    local chat = require('chat');
    print(chat.header('XivParty'):append(chat.message(tostring(message))));
end

----------------------------------------------------------------------------------------------------
-- windower.addon_path
-- Returns the addon's directory path
----------------------------------------------------------------------------------------------------
function adapter.get_addon_path()
    -- Use backslashes consistently for Windows paths
    local installPath = AshitaCore:GetInstallPath():gsub('/', '\\');
    return string.format('%saddons\\xivparty\\', installPath);
end

----------------------------------------------------------------------------------------------------
-- windower.file_exists(path)
-- Checks if a file exists
----------------------------------------------------------------------------------------------------
function adapter.file_exists(path)
    local f = io.open(path, 'r');
    if f then
        f:close();
        return true;
    end
    return false;
end

----------------------------------------------------------------------------------------------------
-- windower.register_event / unregister_event
-- Minimal support for 'keyboard' and 'mouse' events used by UI classes.
----------------------------------------------------------------------------------------------------
local function ensure_shim_events_registered()
    if isShimEventsRegistered then return end
    isShimEventsRegistered = true

    ashita.events.register('keyboard', 'windower_keyboard_shim', function(e)
        for _, cb in pairs(keyboardHandlers) do
            local handled = cb(e.dik, e.down)
            if handled then
                e.blocked = true
            end
        end
    end)

    ashita.events.register('mouse', 'windower_mouse_shim', function(e)
        for _, cb in pairs(mouseHandlers) do
            local handled = cb(e.message, e.x, e.y, e.delta, e.blocked)
            if handled then
                e.blocked = true
            end
        end
    end)
end

local function register_event(name, cb)
    if type(cb) ~= 'function' then
        return nil
    end
    ensure_shim_events_registered()
    local id = nextHandlerId
    nextHandlerId = nextHandlerId + 1

    if name == 'keyboard' then
        keyboardHandlers[id] = cb
    elseif name == 'mouse' then
        mouseHandlers[id] = cb
    else
        -- unsupported event name; store anyway but won't be invoked
        keyboardHandlers[id] = cb
    end
    return id
end

local function unregister_event(id)
    keyboardHandlers[id] = nil
    mouseHandlers[id] = nil
end

----------------------------------------------------------------------------------------------------
-- windower.get_windower_settings()
-- Provides UI resolution values used by layout code.
-- Falls back to 1920x1080 if configuration keys are missing.
----------------------------------------------------------------------------------------------------
local function get_windower_settings()
    local cfg = AshitaCore:GetConfigurationManager();
    -- Windower exposes ui_x_res/ui_y_res; Ashita stores resolution in registry keys 0001 / 0002.
    local x = cfg:GetUInt32('boot', 'ffxi.registry', '0001', 1920);
    local y = cfg:GetUInt32('boot', 'ffxi.registry', '0002', 1080);
    return {
        ui_x_res = x,
        ui_y_res = y,
    };
end

----------------------------------------------------------------------------------------------------
-- Create global 'windower' compatibility table
----------------------------------------------------------------------------------------------------
windower = windower or {};
windower.ffxi = windower.ffxi or {};

windower.ffxi.get_info = adapter.get_info;
windower.ffxi.get_player = adapter.get_player;
windower.ffxi.get_party = adapter.get_party;
windower.ffxi.get_mob_by_target = adapter.get_mob_by_target;
windower.send_command = adapter.send_command;
windower.add_to_chat = adapter.add_to_chat;
windower.addon_path = adapter.get_addon_path();
windower.file_exists = adapter.file_exists;
windower.get_windower_settings = get_windower_settings;
windower.register_event = register_event;
windower.unregister_event = unregister_event;

----------------------------------------------------------------------------------------------------
-- Export
----------------------------------------------------------------------------------------------------
return adapter;
