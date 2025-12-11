--[[
    Copyright (c) 2024, Tylas
    All rights reserved.

    XivParty - Ashita v4 Port
    Original: https://github.com/Tylas11/XivParty

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

        * Redistributions of source code must retain the above copyright
          notice, this list of conditions and the following disclaimer.
        * Redistributions in binary form must reproduce the above copyright
          notice, this list of conditions and the following disclaimer in the
          documentation and/or other materials provided with the distribution.
        * Neither the name of XivParty nor the
          names of its contributors may be used to endorse or promote products
          derived from this software without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
    ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
    WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY
    DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
    (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
    ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
    (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
    SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]--

-- Addon metadata (required by Ashita v4)
addon.name      = 'xivparty';
addon.author    = 'TheTerv (Windower port - credit to Tylas)';
addon.version   = '0.1.0';
addon.desc      = 'Displays party member HP/MP/TP bars, job icons, and buff icons.';
addon.link      = 'https://github.com/TheTerv/XivParty';

-- Add parent folder to package path to allow requiring main modules
package.path = package.path .. ';../?.lua;';

-- Required Ashita modules
local chat = require('chat');

-- Load the Windower compatibility adapter (creates global 'windower' table)
require('adapter');

-- Load Windower compatibility shims for tables/lists (defines global T{} and L{})
-- These MUST be loaded before any module that uses them
require('tables');
require('lists');

-- Pre-load the config shim so it's available for other modules
package.loaded['config'] = require('config');

-- Load Windower compatibility shims for UI
local images = require('images');
local texts = require('texts');

-- Main addon modules
local const = require('const');
local utils = require('utils');
local uiView = require('uiView');
local model = require('model').new();
local settings = require('settings');

----------------------------------------------------------------------------------------------------
-- Variables
----------------------------------------------------------------------------------------------------

local isInitialized = false;
local isZoning = false;
local lastFrameTimeMsec = 0;

local view = nil;
Settings = nil; -- Global for now to match original structure

local setupModel = nil;
local isSetupEnabled = false;
local testImage = nil;
local isUiHidden = false;

local debugLastStats = { hp = nil, mp = nil, tp = nil };

math.randomseed(os.time());

-- Debugging ref counts from original code
RefCountImage = 0;
RefCountText = 0;

----------------------------------------------------------------------------------------------------
-- Core Functions
----------------------------------------------------------------------------------------------------

-- Initializes the addon's main components
local function init()
    if not isInitialized then
        -- The original code makes a global Settings object. We will replicate that for compatibility.
        Settings = settings.new(model);
        Settings:load();
        view = uiView.new(model); -- Depends on settings, always create view after loading settings
        isInitialized = true;
        print(chat.header(addon.name):append(chat.success('XivParty initialized!')));
    end
end

-- Disposes of the addon's components
local function dispose()
    if isInitialized then
        if view then
            view:dispose();
        end
        view = nil;
        Settings = nil;
        isInitialized = false;
        print(chat.header(addon.name):append(chat.message('XivParty disposed.')));
    end
end

----------------------------------------------------------------------------------------------------
-- Event Handlers (Ported from original)
----------------------------------------------------------------------------------------------------

ashita.events.register('load', 'xivparty_load', function()
    -- settings must only be loaded when logged in, as they are separate for every character
    if windower.ffxi.get_info().logged_in then
        init()
    end
end);

ashita.events.register('unload', 'xivparty_unload', function()
    dispose();
end);

ashita.events.register('login', 'xivparty_login', function()
    init();
end);

ashita.events.register('logout', 'xivparty_logout', function()
    dispose();
end);

ashita.events.register('status change', 'xivparty_status_change', function(status)
    if isInitialized then
        view:visible(not Settings.hideCutscene or status ~= 4, const.visCutscene) -- hide UI during cutscenes
    end
end);

ashita.events.register('prerender', 'xivparty_prerender', function()
    if isZoning or not isInitialized then return end

    local timeMsec = AshitaCore:GetMilliTimestamp();
    if timeMsec - lastFrameTimeMsec < Settings.updateIntervalMsec then return end
    lastFrameTimeMsec = timeMsec

    Settings:update()
    model:updatePlayers()

    -- Debug: log main player HP/MP/TP changes when utils.level <= 1
    if utils.level <= 1 then
        local main = windower.ffxi.get_player();
        if main then
            if main.hp ~= debugLastStats.hp or main.mp ~= debugLastStats.mp or main.tp ~= debugLastStats.tp then
                utils:log(string.format('Main stats HP:%s MP:%s TP:%s', tostring(main.hp), tostring(main.mp), tostring(main.tp)), 1);
                debugLastStats.hp = main.hp;
                debugLastStats.mp = main.mp;
                debugLastStats.tp = main.tp;
            end
        end
    end

    local partyInfo = windower.ffxi.get_party();
    local isSolo = true;
    if partyInfo and partyInfo.p1 and partyInfo.p1.name and partyInfo.p1.name ~= '' then
        isSolo = false;
    end

    view:visible(isSetupEnabled or not Settings.hideSolo or not isSolo, const.visSolo)
    view:update()
end);

----------------------------------------------------------------------------------------------------
-- Event: Packet In
-- Handles incoming packet data to update the model.
----------------------------------------------------------------------------------------------------
ashita.events.register('packet_in', 'xivparty_packet_in', function(e)
    -- The 'e.data' field contains the raw packet string, similar to Windower's 'original'
    local original = e.data;
    local pktlen = #original;

    -- Safe unpack helper to avoid bounds errors.
    local function safeUnpack(fmt, pos)
        if not pos or pos < 1 or pos > pktlen then return nil end
        local ok, v = pcall(function() return original:unpack(fmt, pos) end)
        if ok then return v end
        return nil
    end

    if e.id == 0xC8 then -- alliance update
        -- This packet structure is complex and may need a proper definition.
        -- For now, we assume direct parsing might work if structure is simple.
        -- NOTE: Ashita's packet objects are tables, but without a definition, we get raw data.
        -- The original used packets.parse, which we don't have. Let's try manual unpacking.
        -- This part is highly likely to fail without proper struct definitions.
        -- For now, we will skip it until we can verify the structure.

    elseif e.id == 0xDD then -- party member update (HP/MP/TP/Jobs)
        if pktlen < 40 then return end
        local playerId = safeUnpack('I', 5)
        if playerId and playerId > 0 then
            local name = utils:trim(safeUnpack('s', 37)) -- name at offset 37 (32 bytes)
            local hp = safeUnpack('I', 9) or 0
            local mp = safeUnpack('I', 13) or 0
            local tp = safeUnpack('I', 17) or 0
            local mJob = original:byte(21) or 0
            local mJobLvl = original:byte(22) or 0
            local sJob = original:byte(23) or 0
            local sJobLvl = original:byte(24) or 0

            local foundPlayer = model:getPlayer(name, playerId, 'packet_dd')
            if foundPlayer then
                foundPlayer.hp = hp
                foundPlayer.mp = mp
                foundPlayer.tp = tp
                foundPlayer.hpp = hp -- percentage unknown, will be normalized by UI bars if needed
                foundPlayer.mpp = mp -- percentage unknown
                foundPlayer.tpp = math.min(tp / 10, 100)

                if mJob > 0 and mJobLvl > 0 then
                    foundPlayer.job = (res.jobs[mJob] and res.jobs[mJob].ens) or foundPlayer.job
                    foundPlayer.jobLvl = mJobLvl
                end
                if sJob > 0 and sJobLvl > 0 then
                    foundPlayer.subJob = (res.jobs[sJob] and res.jobs[sJob].ens) or foundPlayer.subJob
                    foundPlayer.subJobLvl = sJobLvl
                end
                utils:log(string.format('Packet 0xDD update: %s HP:%d MP:%d TP:%d', name or 'nil', hp, mp, tp), 1)
            end
        end

    elseif e.id == 0xDF then -- char update (single actor job/state)
        if pktlen < 32 then return end
        local playerId = safeUnpack('I', 5)
        if playerId and playerId > 0 then
            local hp = safeUnpack('I', 9) or 0
            local mp = safeUnpack('I', 13) or 0
            local tp = safeUnpack('I', 17) or 0
            local mJob = original:byte(21) or 0
            local mJobLvl = original:byte(22) or 0
            local sJob = original:byte(23) or 0
            local sJobLvl = original:byte(24) or 0

            local foundPlayer = model:getPlayer(nil, playerId, 'packet_df')
            if foundPlayer then
                foundPlayer.hp = hp
                foundPlayer.mp = mp
                foundPlayer.tp = tp
                foundPlayer.hpp = hp
                foundPlayer.mpp = mp
                foundPlayer.tpp = math.min(tp / 10, 100)

                if mJob > 0 and mJobLvl > 0 then
                    foundPlayer.job = (res.jobs[mJob] and res.jobs[mJob].ens) or foundPlayer.job
                    foundPlayer.jobLvl = mJobLvl
                end
                if sJob > 0 and sJobLvl > 0 then
                    foundPlayer.subJob = (res.jobs[sJob] and res.jobs[sJob].ens) or foundPlayer.subJob
                    foundPlayer.subJobLvl = sJobLvl
                end
                utils:log(string.format('Packet 0xDF update: id:%d HP:%d MP:%d TP:%d', playerId, hp, mp, tp), 1)
            end
        end

    elseif e.id == 0x076 then -- party buffs (Credit: Kenshi, PartyBuffs)
        for k = 0, 4 do
            local playerId = original:unpack('I', k*48+5)

            if playerId ~= 0 then -- NOTE: main player buffs are not available here
                local buffsList = {}

                for i = 1, const.maxBuffs do
                    local buff = original:byte(k*48+5+16+i-1) + 256*( math.floor( original:byte(k*48+5+8+ math.floor((i-1)/4)) / 4^((i-1)%4) )%4) -- Credit: Byrth, GearSwap

                    if buff == 255 then -- empty buff
                        buff = nil
                    end
                    buffsList[i] = buff
                end

                local foundPlayer = model:getPlayer(nil, playerId, 'buffs')
                foundPlayer:updateBuffs(buffsList)
                utils:log('Updated buffs for player with ID ' .. tostring(playerId), 1)
            end
        end

    elseif e.id == 0xB then -- zoning, also happens on log out
        utils:log('Zoning...')
        isZoning = true
        model:clear() -- clear model only when zoning
        if isInitialized then
            view:hide(const.visZoning)
        end
    elseif e.id == 0xA and isZoning then -- also happens on login
        utils:log('Zoning done.')
        isZoning = false
        ashita.timer.once(3000, function() -- 3 sec delay to hide pre-zoning party lists
            if isInitialized then
                view:show(const.visZoning)
            end
        end)
    end
end);

-- NOTE: Packet event handling will be part of Milestone 4
-- For now, the UI will load but not update based on packets.

----------------------------------------------------------------------------------------------------
-- Event: d3d_present
-- Ashita primitives auto-render, but hook present to keep debug elements alive.
----------------------------------------------------------------------------------------------------
ashita.events.register('d3d_present', 'xivparty_present', function()
    if testImage then
        testImage:visible(not isUiHidden);
    end
end);

----------------------------------------------------------------------------------------------------
-- Command Handling (Ported from original)
----------------------------------------------------------------------------------------------------

-- Local log function for compatibility with original code
local function log(text, level)
    utils:log(text, level);
end
local function logChat(text)
    print(chat.header(addon.name):append(chat.message(text)));
end

----------------------------------------------------------------------------------------------------
-- Debug helpers (Milestone 3 validation)
----------------------------------------------------------------------------------------------------
local function destroyTestImage()
    if testImage then
        images.destroy(testImage);
        testImage = nil;
    end
end

local function createTestImage()
    destroyTestImage();
    local img = images.new();
    img:draggable(false);
    img:size(256, 32);
    img:pos(100, 100);
    local rel = 'assets/ffxi/BarFG.png'; -- colored texture so we see it
    img:path(rel);
    -- Debug: verify path resolved
    local candidate = string.format('%s%s', windower.addon_path, rel);
    local f = io.open(candidate, 'r');
    if f then
        f:close();
        print(chat.header(addon.name):append(chat.success('testui: loaded ' .. candidate)));
    else
        print(chat.header(addon.name):append(chat.error('testui: texture not found ' .. candidate)));
    end
    img:color(255, 255, 255);
    img:alpha(255);
    img:visible(not isUiHidden);
    testImage = img;
end

local function runTestShim()
    local info = windower.ffxi.get_info() or {};
    local player = windower.ffxi.get_player() or {};
    local party = windower.ffxi.get_party() or {};

    print(chat.header(addon.name):append(chat.message(string.format('Shim OK - zone:%s logged:%s', tostring(info.zone), tostring(info.logged_in)))));
    print(chat.header(addon.name):append(chat.message(string.format('Shim OK - player:%s id:%s job:%s/%s', tostring(player.name), tostring(player.id), tostring(player.main_job), tostring(player.sub_job)))));
    local partyLeader = party.party1_leader or 'nil';
    print(chat.header(addon.name):append(chat.message(string.format('Shim OK - party leader:%s', tostring(partyLeader)))));
end

local function toggleHideUi()
    isUiHidden = not isUiHidden;
    if view then
        view:visible(not isUiHidden, const.visFeature);
    end
    if testImage then
        testImage:visible(not isUiHidden);
    end
    if isUiHidden then
        log('UI hidden (debug toggle).');
    else
        log('UI shown (debug toggle).');
    end
end

-- Helper functions for command handling (ported from original)
local function showHelp()
    log('Commands: //xivparty or //xp')
    log('filter - hides specified buffs in party list. Use command \"buffs\" to find out IDs.')
    log('   add <ID> - adds filter for a buff (e.g. //xp filter add 123)')
    log('   remove <ID> - removes filter for a buff')
    log('   clear - removes all filters')
    log('   list - shows list of currently set filters')
    log('   mode - switches between blacklist and whitelist mode (both use same filter list)')
    log('buffs <name> - shows list of currently active buffs and their IDs for a party member')
    log('range - display party member distances as icons or numeric values')
    log('   <near> <far> - shows a marker for each party member closer than the set distances (off or 0 to disable)')
    log('   num - numeric display mode, disables near/far markers.')
    log('customOrder - toggles custom buff order (customize in bufforder.lua)')
    log('hideSolo - hides the UI while solo')
    log('hideAlliance - hides alliance party lists')
    log('hideCutscene - hides the UI during cutscenes')
    log('mouseTargeting - toggles targeting party members using the mouse')
    log('swapSingleAlliance - shows single alliance in the 2nd alliance list')
    log('alignBottom - expands the party list from bottom to top')
    log('showEmptyRows - show empty rows in partially filled parties')
    log('job - toggles job specific settings for current job')
    log('setup - move the UI using drag and drop, hold CTRL for grid snap, mouse wheel to scale the UI')
    log('testshim - runs adapter sanity checks')
    log('testui - toggles a debug image at (100,100)')
    log('hideui - toggles debug UI visibility')
    log('layout <file> - loads a UI layout file')
end

local function handleCommand(currentValue, argsString, text, option1String, option1Value, option2String, option2Value, isNowText)
    local setValue
    if not isNowText then
        isNowText = 'is now'
    end

    if argsString and string.lower(argsString) == option1String then
        setValue = option1Value
    elseif argsString and string.lower(argsString) == option2String then
        setValue = option2Value
    elseif not argsString or argsString == '' then
        if currentValue == option1Value then
            setValue = option2Value
        else
            setValue = option1Value
        end
    else
        error('Unknown parameter \'' .. argsString .. '\'.')
        return currentValue
    end

    local setString = option1String
    if setValue == option2Value then
        setString = option2String
    end
    log(text .. ' ' .. isNowText .. ' ' .. setString .. '.')

    return setValue
end

local function handleCommandOnOff(currentValue, argsString, text, plural)
    local isNowText = nil
    if plural then
        isNowText = 'are now'
    end
    return handleCommand(currentValue, argsString, text, 'on', true, 'off', false, isNowText)
end

local function handlePartySettingsOnOff(settingsName, argsString1, argsString2, text)
    local partyIndex = tonumber(argsString1)
    if partyIndex ~= nil then
        if partyIndex < 0 or partyIndex > 2 then
            error('Invalid party index \'' .. argsString1 .. '\'. Valid values are 0 (main party), 1 (alliance 1), 2 (alliance 2).')
        else
            local partySettings = Settings:getPartySettings(partyIndex)
            local ret = handleCommandOnOff(partySettings[settingsName], argsString2, text .. ' (' .. Settings:partyIndexToName(partyIndex) .. ')')
            partySettings[settingsName] = ret
            Settings:save()
        end
    else
        local ret = handleCommandOnOff(Settings.party[settingsName], argsString1, text)
        for i = 0, 2 do
            Settings:getPartySettings(i)[settingsName] = ret
        end
        Settings:save()
    end
end

local function checkBuff(buffId)
    -- The original used res.buffs, which is a Windower resource.
    -- Ashita's resources are structured differently. For now, we will just check for ID.
    -- This needs to be replaced with Ashita's resource manager access.
    if buffId and buffId > 0 then
        return true
    elseif not buffId then
        error('Invalid buff ID.')
    else
        error('Buff with ID ' .. buffId .. ' not found.')
    end

    return false
end

local function getBuffText(buffId)
    -- Similar to checkBuff, this needs to be adapted for Ashita resources.
    return 'BuffID:' .. tostring(buffId)
end

local function getRange(arg)
    if not arg then return nil end

    local range = string.lower(arg)
    if range == 'off' then
        range = 0
    else
        range = tonumber(range)
    end

    if not range then
        error('Invalid range \'' .. arg .. '\'.')
    end

    return range
end

local function setSetupEnabled(enabled)
    isSetupEnabled = enabled

    if not setupModel then
        setupModel = model.new()
        setupModel:createSetupData()
    end

    view:setModel(isSetupEnabled and setupModel or model) -- lua style ternary operator
    view:setUiLocked(not isSetupEnabled)
end

ashita.events.register('command', 'xivparty_command', function(e)
    local args = e.command:args();
    if (args[1] ~= '/xivparty' and args[1] ~= '/xp') then
        return;
    end
    e.blocked = true;

    local command
    if args[2] then
        command = string.lower(args[2])
    end

    if not command or command == 'help' then
        showHelp()
        return
    end
    
    local arg2 = args[3]
    local arg3 = args[4]
    local arg4 = args[5]

    if command == 'status' then
        -- Debug status command - bypasses log level filter
        print(chat.header(addon.name):append(chat.message('--- XivParty Status ---')));
        print(chat.header(addon.name):append(chat.message('  isInitialized: ' .. tostring(isInitialized))));
        print(chat.header(addon.name):append(chat.message('  Settings: ' .. tostring(Settings ~= nil))));
        print(chat.header(addon.name):append(chat.message('  view: ' .. tostring(view ~= nil))));
        print(chat.header(addon.name):append(chat.message('  isZoning: ' .. tostring(isZoning))));
        print(chat.header(addon.name):append(chat.message('  isUiHidden: ' .. tostring(isUiHidden))));
        if Settings then
            print(chat.header(addon.name):append(chat.message('  Settings.hideSolo: ' .. tostring(Settings.hideSolo))));
        end
        -- Model debug
        if model then
            local p0 = model.parties[0][0];
            print(chat.header(addon.name):append(chat.message('  model.parties[0][0]: ' .. (p0 and p0.name or 'nil'))));
            local count = 0;
            for i = 0, 5 do if model.parties[0][i] then count = count + 1 end end
            print(chat.header(addon.name):append(chat.message('  Party0 count: ' .. count)));
        end
        -- View debug
        if view then
            print(chat.header(addon.name):append(chat.message('  view.isEnabled: ' .. tostring(view.isEnabled))));
            print(chat.header(addon.name):append(chat.message('  view.isCreated: ' .. tostring(view.isCreated))));
            if view.partyLists and view.partyLists[0] then
                local pl = view.partyLists[0];
                print(chat.header(addon.name):append(chat.message('  partyList[0].isEnabled: ' .. tostring(pl.isEnabled))));
                print(chat.header(addon.name):append(chat.message('  partyList[0].isCreated: ' .. tostring(pl.isCreated))));
                local itemCount = 0;
                if pl.listItems then
                    for i = 0, 5 do if pl.listItems[i] then itemCount = itemCount + 1 end end
                end
                print(chat.header(addon.name):append(chat.message('  partyList[0].listItems count: ' .. itemCount)));
            end
        end
        return;
    elseif command == 'trace' then
        -- Detailed trace of model update
        print(chat.header(addon.name):append(chat.message('--- Trace model:updatePlayers ---')));
        local party = windower.ffxi.get_party();
        print(chat.header(addon.name):append(chat.message('1. get_party returned: ' .. type(party))));
        if party then
            print(chat.header(addon.name):append(chat.message('2. party.p0: ' .. type(party.p0) .. ' = ' .. (party.p0 and party.p0.name or 'nil'))));
        end
        local ok, err = pcall(function()
            model:updatePlayers();
        end);
        if ok then
            print(chat.header(addon.name):append(chat.message('3. updatePlayers() succeeded')));
        else
            print(chat.header(addon.name):append(chat.error('3. updatePlayers() FAILED: ' .. tostring(err))));
        end
        local p0 = model.parties[0][0];
        print(chat.header(addon.name):append(chat.message('4. model.parties[0][0]: ' .. (p0 and p0.name or 'nil'))));
        -- Now test view update
        local ok2, err2 = pcall(function()
            view:update();
        end);
        if ok2 then
            print(chat.header(addon.name):append(chat.message('5. view:update() succeeded')));
        else
            print(chat.header(addon.name):append(chat.error('5. view:update() FAILED: ' .. tostring(err2))));
        end
        local itemCount = 0;
        if view.partyLists and view.partyLists[0] and view.partyLists[0].listItems then
            for i = 0, 5 do if view.partyLists[0].listItems[i] then itemCount = itemCount + 1 end end
        end
        print(chat.header(addon.name):append(chat.message('6. listItems count after update: ' .. itemCount)));
        return;
    elseif command == 'testshim' then
        runTestShim()
    elseif command == 'testui' then
        if testImage then
            destroyTestImage()
            log('Test UI image destroyed.')
        else
            createTestImage()
            log('Test UI image created at (100,100).')
        end
    elseif command == 'hideui' then
        toggleHideUi()
    elseif command == 'setup' then
        local ret = handleCommandOnOff(isSetupEnabled, arg2, 'Setup mode')
        setSetupEnabled(ret)
    elseif command == 'hidesolo' then
        local ret = handleCommandOnOff(Settings.hideSolo, arg2, 'Party list hiding while solo')
        Settings.hideSolo = ret
        Settings:save()
    elseif command == 'hidealliance' then
        local ret = handleCommandOnOff(Settings.hideAlliance, arg2, 'Alliance list hiding')
        Settings.hideAlliance = ret
        Settings:save()
        view:reload()
    elseif command == 'hidecutscene' then
        local ret = handleCommandOnOff(Settings.hideCutscene, arg2, 'Party list hiding during cutscenes')
        Settings.hideCutscene = ret
        Settings:save()
    elseif command == 'mousetargeting' then
        local ret = handleCommandOnOff(Settings.mouseTargeting, arg2, 'Targeting party members using the mouse')
        Settings.mouseTargeting = ret
        Settings:save()
    elseif command == 'swapsinglealliance' then
        local ret = handleCommandOnOff(Settings.swapSingleAlliance, arg2, 'Swapping UI for single alliance')
        Settings.swapSingleAlliance = ret
        Settings:save()
    elseif command == 'alignbottom' then
        handlePartySettingsOnOff("alignBottom", arg2, arg3, 'Bottom alignment')
    elseif command == 'showemptyrows' then
        handlePartySettingsOnOff("showEmptyRows", arg2, arg3, 'Display of empty rows')
    elseif command == 'customorder' then
        local ret = handleCommandOnOff(Settings.buffs.customOrder, arg2, 'Custom buff order')
        Settings.buffs.customOrder = ret
        Settings:save()
        if setupModel then setupModel:refreshFilteredBuffs() end
        model:refreshFilteredBuffs()
    elseif command == 'range' then
        if arg2 then
            if arg2 == 'num' or arg2 == 'numeric' then
                Settings.rangeNumeric = true
                Settings.rangeIndicator = 0
                Settings.rangeIndicatorFar = 0
                Settings:save()
                log('Range numeric display mode enabled.')
            else
                local range1 = getRange(arg2)
                local range2 = getRange(arg3)
                if range1 then
                    Settings.rangeNumeric = false
                    Settings.rangeIndicator = range1
                    if range2 then
                        Settings.rangeIndicatorFar = range2
                        if Settings.rangeIndicator > Settings.rangeIndicatorFar then -- fix when swapped
                            Settings.rangeIndicator = range2
                            Settings.rangeIndicatorFar = range1
                        end
                        log('Range indicators set to near ' .. tostring(Settings.rangeIndicator) .. ', far ' .. tostring(Settings.rangeIndicatorFar) .. '.')
                    else
                        Settings.rangeIndicatorFar = 0
                        if range1 > 0 then
                            log('Range indicator set to ' .. tostring(Settings.rangeIndicator) .. '.')
                        else
                            log('Range indicator disabled.')
                        end
                    end
                    Settings:save()
                end
            end
        else
            showHelp()
        end
    elseif command == 'filter' or command == 'filters' then
        local subCommand = string.lower(arg2)
        if subCommand == 'add' then
            local buffId = tonumber(arg3)
            if checkBuff(buffId) then
                Settings.buffFilters[buffId] = true
                Settings:save()
                if setupModel then setupModel:refreshFilteredBuffs() end
                model:refreshFilteredBuffs()
                log('Added buff filter for ' .. getBuffText(buffId))
            end
        elseif subCommand == 'remove' then
            local buffId = tonumber(arg3)
            if checkBuff(buffId) then
                Settings.buffFilters[buffId] = nil
                Settings:save()
                if setupModel then setupModel:refreshFilteredBuffs() end
                model:refreshFilteredBuffs()
                log('Removed buff filter for ' .. getBuffText(buffId))
            end
        elseif subCommand == 'clear' then
            Settings.buffFilters = T{}
            Settings:save()
            if setupModel then setupModel:refreshFilteredBuffs() end
            model:refreshFilteredBuffs()
            log('All buff filters cleared.')
        elseif subCommand == 'list' then
            log('Currently active buff filters (' .. Settings.buffs.filterMode .. '):')
            for buffId, doFilter in pairs(Settings.buffFilters) do
                if doFilter then
                    log(getBuffText(buffId))
                end
            end
        elseif subCommand == 'mode' then
            local ret = handleCommand(Settings.buffs.filterMode, arg3, 'Filter mode', 'blacklist', 'blacklist', 'whitelist', 'whitelist')
            Settings.buffs.filterMode = ret
            Settings:save()
            if setupModel then setupModel:refreshFilteredBuffs() end
            model:refreshFilteredBuffs()
        else
            showHelp()
        end
    elseif command == 'buffs' then
        local playerName = arg2
        local buffs
        if playerName then
            playerName = playerName:ucfirst()
            local foundPlayer = model:findPlayer(playerName)
            if foundPlayer then
                buffs = foundPlayer.buffs
                logChat(playerName .. '\'s active buffs:')
            else
                error('Player ' .. playerName .. ' not found.')
                return
            end
        else
            buffs = windower.ffxi.get_player().buffs
            logChat('Your active buffs:')
        end

        local any = false
        for i = 1, const.maxBuffs do
            if buffs[i] then
                logChat(getBuffText(buffs[i]))
                any = true
            end
        end
        if not any then
            logChat('No buffs found (player buff source may not be available).')
        end
    elseif command == 'layout' then
        if arg2 then
            if arg2:endswith(const.xmlExtension) then
                arg2 = arg2:slice(1, #arg2 - #const.xmlExtension) -- trim the file extension
            end

            local filename = const.layoutDir .. arg2 .. const.xmlExtension

            if windower.file_exists(windower.addon_path .. filename) then
                log('Loading layout \'' .. arg2 .. '\'.')

                Settings.layout = arg2
                Settings:save()

                view:reload()
            else
                error('The layout file \'' .. filename .. '\' does not exist!')
            end
        else
            showHelp()
        end
    elseif command == 'job' then
        local job = windower.ffxi.get_player().main_job
        local ret = handleCommandOnOff(Settings.jobEnabled, arg2, 'Job specific settings for ' .. job, true)

        if ret then
            if not Settings.jobEnabled then
                Settings:load(true, true)
                log('Settings changes to range and buffs will now only affect this job.')
            end
        elseif Settings.jobEnabled then
            Settings.jobEnabled = false
            Settings:save()
            Settings:load()
            log('Global settings applied. The job specific settings for ' .. job .. ' will remain saved for later use.')
        end
    elseif command == 'debug' then
        local subCommand = arg2 and string.lower(arg2) or ''
        if subCommand == 'savelayout' then
            view:debugSaveLayout()
        elseif subCommand == 'refcount' then
            print(chat.header(addon.name):append(chat.message('Images: ' .. RefCountImage .. ', Texts: ' .. RefCountText)))
        elseif subCommand == 'setbar' and arg3 ~= nil and setupModel then -- example: //xp debug setbar hpp 50 0 2
            setupModel:debugSetBarValue(arg3, tonumber(arg4), tonumber(args[6]), tonumber(args[7]))
        elseif subCommand == 'addplayer' and setupModel then
            setupModel:debugAddSetupPlayer(tonumber(arg3))
        elseif subCommand == 'testbuffs' then
            setupModel:debugTestBuffs()
            setupModel:refreshFilteredBuffs()
        elseif subCommand == 'stats' then
            local p = windower.ffxi.get_player()
            local party = windower.ffxi.get_party()
            local slot0 = party and party.p0 or {}
            -- Pull some direct values via Ashita managers for debugging
            local pm = AshitaCore:GetMemoryManager():GetPlayer()
            local function pmCall(m)
                local ok, val = pcall(function() return pm[m](pm) end)
                return ok and val or nil
            end
            local pmHP = pmCall('GetHP')
            local pmMP = pmCall('GetMP')
            local pmTP = pmCall('GetTP')
            local pmHPMax = pmCall('GetMaxHP') or pmCall('GetHPMax')
            local pmMPMax = pmCall('GetMaxMP') or pmCall('GetMPMax')
            local pmHPP = (pmHP and pmHPMax and pmHPMax > 0) and math.floor((pmHP / pmHPMax) * 100) or 'n/a'
            local pmMPP = (pmMP and pmMPMax and pmMPMax > 0) and math.floor((pmMP / pmMPMax) * 100) or 'n/a'
            print(chat.header(addon.name):append(chat.message(string.format(
                'Main stats HP:%s MP:%s TP:%s HPP:%s MPP:%s (slot0 HP:%s MP:%s TP:%s HPP:%s MPP:%s) [PM HP:%s/%s (%s%%) MP:%s/%s (%s%%) TP:%s]',
                tostring(p and p.hp), tostring(p and p.mp), tostring(p and p.tp), tostring(p and p.hpp), tostring(p and p.mpp),
                tostring(slot0.hp), tostring(slot0.mp), tostring(slot0.tp), tostring(slot0.hpp), tostring(slot0.mpp),
                tostring(pmHP), tostring(pmHPMax), tostring(pmHPP), tostring(pmMP), tostring(pmMPMax), tostring(pmMPP), tostring(pmTP)
            ))))
            if p and p.buffs then
                local buffList = {}
                for i = 1, const.maxBuffs do
                    if p.buffs[i] then
                        table.insert(buffList, p.buffs[i])
                    end
                end
                print(chat.header(addon.name):append(chat.message('Main buffs: ' .. tostring(#buffList) .. ' -> ' .. table.concat(buffList, ','))))
            end
        elseif subCommand == 'party' then
            local party = windower.ffxi.get_party()
            for i = 0, 17 do
                local key = i < 6 and ('p' .. i) or (i < 12 and ('a1' .. (i - 6)) or ('a2' .. (i - 12)))
                local m = party[key]
                if m and m.name then
                    print(chat.header(addon.name):append(chat.message(string.format('%s HP:%s MP:%s TP:%s Zone:%s', m.name, tostring(m.hp), tostring(m.mp), tostring(m.tp), tostring(m.zone)))))
                end
            end
        elseif subCommand == 'testprim' then
            -- Direct test of Ashita primitives library (bypassing XivParty shims)
            local primitives = require('primitives');
            local testPrim = primitives.new({
                visible = true,
                locked = true,
                position_x = 100,
                position_y = 100,
                width = 200,
                height = 50,
                color = 0xFFFF0000,  -- Red
            });
            print(chat.header(addon.name):append(chat.message('Created test primitive at 100,100 size 200x50 (red rectangle)')));
            print(chat.header(addon.name):append(chat.message('Run "/xp debug testprim" again to create another, or reload addon to clear')));
        elseif subCommand == 'testshim' then
            -- Test using our images.lua shim
            local testimages = require('images');
            local testImg = testimages.new();
            testImg:pos(150, 150);
            testImg:size(100, 100);
            testImg:color(0, 255, 0);  -- Green
            testImg:alpha(255);
            testImg:visible(true);
            print(chat.header(addon.name):append(chat.message('Created test image via shim at 150,150 size 100x100 (green rectangle)')));
        elseif subCommand == 'testfull' then
            -- Test with texture like XivParty uses
            local testimages = require('images');
            local testImg = testimages.new();
            testImg:pos(200, 200);
            testImg:size(377, 21);
            testImg:path('assets/xiv/BgTop.png');
            testImg:visible(true);
            print(chat.header(addon.name):append(chat.message('Created test image with texture at 200,200')));
            print(chat.header(addon.name):append(chat.message('Texture: ' .. windower.addon_path .. 'assets\\xiv\\BgTop.png')));
        elseif subCommand == 'uistate' then
            -- Detailed UI state trace
            print(chat.header(addon.name):append(chat.message('--- UI State Debug ---')));
            if not view then
                print(chat.header(addon.name):append(chat.error('view is nil!')));
                return;
            end
            print(chat.header(addon.name):append(chat.message('view.isEnabled=' .. tostring(view.isEnabled) .. ' isCreated=' .. tostring(view.isCreated))));
            print(chat.header(addon.name):append(chat.message('view.absoluteVisibility=' .. tostring(view.absoluteVisibility))));
            print(chat.header(addon.name):append(chat.message('view.children count=' .. tostring(#view.children))));

            for pi = 0, 2 do
                local pl = view.partyLists[pi];
                if pl then
                    print(chat.header(addon.name):append(chat.message('--- PartyList[' .. pi .. '] ---')));
                    print(chat.header(addon.name):append(chat.message('  isEnabled=' .. tostring(pl.isEnabled) .. ' isCreated=' .. tostring(pl.isCreated))));
                    print(chat.header(addon.name):append(chat.message('  absoluteVisibility=' .. tostring(pl.absoluteVisibility))));
                    print(chat.header(addon.name):append(chat.message('  pos=' .. tostring(pl.posX) .. ',' .. tostring(pl.posY))));
                    print(chat.header(addon.name):append(chat.message('  absolutePos=' .. tostring(pl.absolutePos.x) .. ',' .. tostring(pl.absolutePos.y))));
                    print(chat.header(addon.name):append(chat.message('  scale=' .. tostring(pl.scaleX) .. ',' .. tostring(pl.scaleY))));
                    print(chat.header(addon.name):append(chat.message('  children count=' .. tostring(#pl.children))));

                    -- Check background
                    if pl.background then
                        local bg = pl.background;
                        print(chat.header(addon.name):append(chat.message('  background.isEnabled=' .. tostring(bg.isEnabled) .. ' isCreated=' .. tostring(bg.isCreated))));
                        print(chat.header(addon.name):append(chat.message('  background.absoluteVisibility=' .. tostring(bg.absoluteVisibility))));
                        if bg.imgTop then
                            print(chat.header(addon.name):append(chat.message('    imgTop: isCreated=' .. tostring(bg.imgTop.isCreated) .. ' absVis=' .. tostring(bg.imgTop.absoluteVisibility))));
                            print(chat.header(addon.name):append(chat.message('      calculated pos=' .. tostring(bg.imgTop.absolutePos.x) .. ',' .. tostring(bg.imgTop.absolutePos.y) .. ' size=' .. tostring(bg.imgTop.absoluteWidth) .. ',' .. tostring(bg.imgTop.absoluteHeight))));
                            if bg.imgTop.wrappedImage and bg.imgTop.wrappedImage.prim then
                                local prim = bg.imgTop.wrappedImage.prim;
                                print(chat.header(addon.name):append(chat.message('      actual prim pos=' .. tostring(prim.position_x) .. ',' .. tostring(prim.position_y) .. ' size=' .. tostring(prim.width) .. 'x' .. tostring(prim.height))));
                            end
                        end
                    end

                    -- Check listItems
                    local itemCount = 0;
                    for i = 0, 5 do
                        local item = pl.listItems[i];
                        if item then
                            itemCount = itemCount + 1;
                            print(chat.header(addon.name):append(chat.message('  listItem[' .. i .. '].isEnabled=' .. tostring(item.isEnabled) .. ' isCreated=' .. tostring(item.isCreated))));
                            print(chat.header(addon.name):append(chat.message('    absoluteVisibility=' .. tostring(item.absoluteVisibility))));
                            print(chat.header(addon.name):append(chat.message('    children count=' .. tostring(#item.children))));
                            -- Check first text element
                            if item.txtName then
                                print(chat.header(addon.name):append(chat.message('    txtName.isEnabled=' .. tostring(item.txtName.isEnabled) .. ' isCreated=' .. tostring(item.txtName.isCreated))));
                                print(chat.header(addon.name):append(chat.message('    txtName.absoluteVisibility=' .. tostring(item.txtName.absoluteVisibility))));
                                print(chat.header(addon.name):append(chat.message('    txtName.calculated pos=' .. tostring(item.txtName.absolutePos.x) .. ',' .. tostring(item.txtName.absolutePos.y))));
                                if item.txtName.wrappedText and item.txtName.wrappedText.prim then
                                    local prim = item.txtName.wrappedText.prim;
                                    print(chat.header(addon.name):append(chat.message('    txtName.actual prim pos=' .. tostring(prim.position_x) .. ',' .. tostring(prim.position_y) .. ' visible=' .. tostring(prim.visible))));
                                    print(chat.header(addon.name):append(chat.message('    txtName.text="' .. tostring(prim.text) .. '" color=' .. string.format('0x%08X', prim.color or 0) .. ' font_height=' .. tostring(prim.font_height))));
                                end
                            else
                                print(chat.header(addon.name):append(chat.message('    txtName is nil!')));
                            end
                            -- Check hover image
                            if item.hover then
                                print(chat.header(addon.name):append(chat.message('    hover.isEnabled=' .. tostring(item.hover.isEnabled) .. ' isCreated=' .. tostring(item.hover.isCreated))));
                            end
                        end
                    end
                    print(chat.header(addon.name):append(chat.message('  listItems total=' .. itemCount)));
                end
            end
        end
    else
        showHelp()
    end
end);

ashita.events.register('keyboard', 'xivparty_keyboard', function(key, down)
    if Settings and Settings.hideKeyCode > 0 and key == Settings.hideKeyCode then
        view:visible(not down, const.visKeyboard)
    end
end);
