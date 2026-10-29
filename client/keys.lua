Keys = {}

local detected = nil

local function resourceRunning(name)
    return GetResourceState(name) == 'started'
end

function Keys.system()
    if detected then
        return detected
    end
    if Config.Keys.system ~= 'auto' then
        detected = Config.Keys.system
        return detected
    end
    local candidates = { 'Renewed-Vehiclekeys', 'qs-vehiclekeys', 'wasabi_carlock', 'qb-vehiclekeys', 'esx_vehiclelock' }
    for _, name in ipairs(candidates) do
        if resourceRunning(name) then
            detected = name
            return detected
        end
    end
    detected = 'none'
    return detected
end

function Keys.give(plate, model)
    local system = Keys.system()
    if system == 'Renewed-Vehiclekeys' then
        pcall(function() exports['Renewed-Vehiclekeys']:addKey(plate) end)
    elseif system == 'qs-vehiclekeys' then
        pcall(function() exports['qs-vehiclekeys']:GiveKeys(plate, model) end)
    elseif system == 'wasabi_carlock' then
        pcall(function() exports.wasabi_carlock:GiveKey(plate) end)
    elseif system == 'qb-vehiclekeys' then
        TriggerEvent('vehiclekeys:client:SetOwner', plate)
    elseif system == 'esx_vehiclelock' then
        TriggerServerEvent('esx_vehiclelock:stealKey', plate)
    end
end

function Keys.remove(plate)
    local system = Keys.system()
    if system == 'Renewed-Vehiclekeys' then
        pcall(function() exports['Renewed-Vehiclekeys']:removeKey(plate) end)
    elseif system == 'qs-vehiclekeys' then
        pcall(function() exports['qs-vehiclekeys']:RemoveKeys(plate) end)
    elseif system == 'wasabi_carlock' then
        pcall(function() exports.wasabi_carlock:RemoveKey(plate) end)
    elseif system == 'esx_vehiclelock' then
        TriggerServerEvent('esx_vehiclelock:deleteKey', plate)
    end
end
