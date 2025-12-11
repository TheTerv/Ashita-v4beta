-- Minimal Windower-like resources shim for Ashita tests.

local resources = {}

-- Basic job list (indices 1..22), field 'ens' as in Windower.
resources.jobs = {
    [1]  = { ens = 'WAR' },
    [2]  = { ens = 'MNK' },
    [3]  = { ens = 'WHM' },
    [4]  = { ens = 'BLM' },
    [5]  = { ens = 'RDM' },
    [6]  = { ens = 'THF' },
    [7]  = { ens = 'PLD' },
    [8]  = { ens = 'DRK' },
    [9]  = { ens = 'BST' },
    [10] = { ens = 'BRD' },
    [11] = { ens = 'RNG' },
    [12] = { ens = 'SAM' },
    [13] = { ens = 'NIN' },
    [14] = { ens = 'DRG' },
    [15] = { ens = 'SMN' },
    [16] = { ens = 'BLU' },
    [17] = { ens = 'COR' },
    [18] = { ens = 'PUP' },
    [19] = { ens = 'DNC' },
    [20] = { ens = 'SCH' },
    [21] = { ens = 'GEO' },
    [22] = { ens = 'RUN' },
}

-- Zones table; returns a default stub when missing.
resources.zones = setmetatable({}, {
    __index = function(_, k)
        local name = 'Zone' .. tostring(k or '')
        return { name = name, search = name }
    end
})

return resources
