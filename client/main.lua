local ESX = exports['es_extended']:getSharedObject()

local rental = nil
local menuOpen = false

local function notify(message)
    ESX.ShowNotification(message)
end

local function vehicleLabel(model)
    local name = GetDisplayNameFromVehicleModel(GetHashKey(model))
    local label = GetLabelText(name)
    if label == nil or label == '' or label == 'NULL' then
        return name
    end
    return label
end

local function formatRental(data)
    if not data then
        return nil
    end
    data.label = vehicleLabel(data.model)
    return data
end

local function updateHud()
    if not rental then
        SendNUIMessage({ action = 'hud', active = false })
        return
    end
    local remaining = rental.endAt - GetGameTimer()
    local status = 'active'
    if remaining <= 0 then
        status = 'overdue'
        remaining = 0
    end
    local seconds = math.floor(remaining / 1000)
    SendNUIMessage({
        action = 'hud',
        active = true,
        vehicle = rental.label,
        time = string.format('%02d:%02d', seconds // 60, seconds % 60),
        status = status,
        insurance = L('insurance_' .. rental.insurance)
    })
end

local function closeMenu()
    if not menuOpen then
        return
    end
    menuOpen = false
    SetNuiFocus(false, false)
    Preview.clear()
    SendNUIMessage({ action = 'close' })
end

local function refreshMenuState()
    ESX.TriggerServerCallback('len_vehiclerental:getState', function(state)
        if not state then
            return
        end
        SendNUIMessage({
            action = 'refresh',
            rental = formatRental(state.rental),
            debts = state.debts,
            debtTotal = state.debtTotal
        })
    end)
end

local function bindVehicle(plate, netId, attempt)
    ESX.TriggerServerCallback('len_vehiclerental:bind', function(ok)
        if not ok and attempt < 10 then
            SetTimeout(500, function()
                bindVehicle(plate, netId, attempt + 1)
            end)
        end
    end, plate, netId)
end

local function spawnRental(result, stationIndex)
    local station = Config.Stations[stationIndex]
    if not station then
        return
    end
    local spawn = station.spawnPoint
    ESX.Game.SpawnVehicle(result.model, vector3(spawn.x, spawn.y, spawn.z), spawn.w, function(vehicle)
        SetVehicleNumberPlateText(vehicle, result.plate)
        TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
        Keys.give(result.plate, result.model)
        rental = {
            plate = result.plate,
            model = result.model,
            label = vehicleLabel(result.model),
            vehicle = vehicle,
            endAt = GetGameTimer() + result.expiresIn * 1000,
            insurance = result.insurance,
            stationIndex = stationIndex,
            lastEngine = GetVehicleEngineHealth(vehicle),
            lastBody = GetVehicleBodyHealth(vehicle),
            pendingDamage = 0,
            kmAcc = 0.0,
            lastPos = nil
        }
        bindVehicle(result.plate, NetworkGetNetworkIdFromEntity(vehicle), 1)
        updateHud()
    end)
end

local function monitorRental()
    local vehicle = rental.vehicle

    if not DoesEntityExist(vehicle) then
        TriggerServerEvent('len_vehiclerental:vehicleLost', rental.plate)
        Keys.remove(rental.plate)
        rental = nil
        updateHud()
        return
    end

    if not IsVehicleDriveable(vehicle, false) then
        TriggerServerEvent('len_vehiclerental:totalLoss', rental.plate)
        Keys.remove(rental.plate)
        rental = nil
        updateHud()
        return
    end

    local engine = GetVehicleEngineHealth(vehicle)
    local body = GetVehicleBodyHealth(vehicle)
    local loss = math.max(0, rental.lastEngine - engine) + math.max(0, rental.lastBody - body)
    rental.lastEngine = engine
    rental.lastBody = body
    rental.pendingDamage = rental.pendingDamage + loss
    if rental.pendingDamage >= Config.Damage.threshold then
        TriggerServerEvent('len_vehiclerental:damage', rental.plate, math.floor(rental.pendingDamage))
        rental.pendingDamage = 0
    end

    local position = GetEntityCoords(vehicle)
    if rental.lastPos then
        local distance = #(position - rental.lastPos)
        if distance < 150.0 then
            rental.kmAcc = rental.kmAcc + distance
        end
    end
    rental.lastPos = position
    if rental.kmAcc >= 1000.0 then
        rental.kmAcc = rental.kmAcc - 1000.0
        TriggerServerEvent('len_vehiclerental:km', rental.plate)
    end

    updateHud()
end

local function returnRental()
    if menuOpen then
        return
    end
    if not rental then
        notify(L('no_rental'))
        return
    end
    local station = Config.Stations[rental.stationIndex]
    local vehicle = rental.vehicle
    if not DoesEntityExist(vehicle) then
        notify(L('return_no_vehicle'))
        return
    end
    local vehicleCoords = GetEntityCoords(vehicle)
    local playerCoords = GetEntityCoords(PlayerPedId())
    if #(vehicleCoords - station.returnPoint) > Config.ReturnRadius or #(playerCoords - vehicleCoords) > 10.0 then
        notify(L('return_not_near'))
        return
    end
    ESX.TriggerServerCallback('len_vehiclerental:returnVehicle', function(result)
        notify(result.message)
    end, rental.plate)
end

local function openRentalMenu(stationIndex)
    if menuOpen then
        return
    end
    menuOpen = true
    ESX.TriggerServerCallback('len_vehiclerental:getState', function(state)
        if not state then
            menuOpen = false
            return
        end
        local station = Config.Stations[stationIndex]
        local categories = {}
        for _, category in ipairs(station.categories) do
            local vehicles = {}
            for _, vehicle in ipairs(category.vehicles) do
                vehicles[#vehicles + 1] = {
                    model = vehicle.model,
                    label = vehicleLabel(vehicle.model),
                    basePrice = vehicle.basePrice,
                    tempPrice = vehicle.tempPrice
                }
            end
            categories[#categories + 1] = {
                name = LT(category.name),
                locked = category.license ~= nil and state.licenses[category.license] ~= true,
                vehicles = vehicles
            }
        end
        local insurances = {}
        for _, insurance in ipairs(Config.Insurances) do
            insurances[#insurances + 1] = {
                key = insurance.key,
                label = L('insurance_' .. insurance.key),
                desc = L('insurance_desc_' .. insurance.key),
                percent = insurance.percent,
                coverage = insurance.coverage,
                totalLoss = insurance.totalLoss
            }
        end
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'open',
            locale = GetLocaleTable(),
            currency = Config.Currency,
            station = { id = stationIndex, name = LT(station.name) },
            categories = categories,
            durations = Config.Durations,
            insurances = insurances,
            deposit = Config.Deposit,
            defaultDuration = Config.DefaultDuration,
            previewEnabled = Config.Preview.enable,
            rental = formatRental(state.rental),
            debts = state.debts,
            debtTotal = state.debtTotal
        })
    end)
end

RegisterNUICallback('close', function(_, cb)
    cb({})
    closeMenu()
end)

RegisterNUICallback('preview', function(data, cb)
    cb({})
    local station = Config.Stations[tonumber(data.stationIndex)]
    if station and menuOpen and Config.Preview.enable then
        CreateThread(function()
            Preview.show(data.model, station)
        end)
    end
end)

RegisterNUICallback('rent', function(data, cb)
    ESX.TriggerServerCallback('len_vehiclerental:rent', function(result)
        if result.ok then
            closeMenu()
            spawnRental(result, tonumber(data.stationIndex))
        end
        notify(result.message)
        cb(result)
    end, data)
end)

RegisterNUICallback('extend', function(data, cb)
    ESX.TriggerServerCallback('len_vehiclerental:extend', function(result)
        if result.ok and rental then
            rental.endAt = GetGameTimer() + result.expiresIn * 1000
            updateHud()
        end
        notify(result.message)
        refreshMenuState()
        cb(result)
    end, tonumber(data.durationIndex))
end)

RegisterNUICallback('payDebts', function(_, cb)
    ESX.TriggerServerCallback('len_vehiclerental:payDebts', function(result)
        notify(result.message)
        refreshMenuState()
        cb(result)
    end)
end)

RegisterNUICallback('returnVehicle', function(_, cb)
    cb({})
    closeMenu()
    returnRental()
end)

RegisterNetEvent('len_vehiclerental:notify', function(message)
    notify(message)
end)

RegisterNetEvent('len_vehiclerental:clear', function(plate)
    if rental and rental.plate == plate then
        rental = nil
    end
    Keys.remove(plate)
    updateHud()
end)

RegisterNetEvent('len_vehiclerental:stolenAlert', function(plate, coords)
    notify(L('stolen_alert', plate))
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 161)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.0)
    SetBlipRoute(blip, true)
    SetTimeout(120000, function()
        RemoveBlip(blip)
    end)
end)

CreateThread(function()
    Wait(1000)
    SendNUIMessage({ action = 'hud', active = false })
    SendNUIMessage({ action = 'locale', locale = GetLocaleTable() })
    if not Config.Blip.enable then
        return
    end
    for _, station in ipairs(Config.Stations) do
        local blip = AddBlipForCoord(station.coords.x, station.coords.y, station.coords.z)
        SetBlipSprite(blip, Config.Blip.sprite)
        SetBlipColour(blip, Config.Blip.color)
        SetBlipScale(blip, Config.Blip.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(L('blip') .. ' - ' .. LT(station.name))
        EndTextCommandSetBlipName(blip)
    end
end)

CreateThread(function()
    while true do
        if rental then
            monitorRental()
        end
        Wait(rental and 500 or 1000)
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000
        local coords = GetEntityCoords(PlayerPedId())
        for index, station in ipairs(Config.Stations) do
            local distRent = #(coords - station.coords)
            if distRent < 25.0 then
                sleep = 0
                DrawMarker(2, station.coords.x, station.coords.y, station.coords.z + 0.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 240, 147, 43, 150, true, true, 2, nil, nil, false)
                if distRent < 1.5 and not menuOpen then
                    ESX.ShowHelpNotification(L('rent_help'))
                    if IsControlJustReleased(0, 38) then
                        openRentalMenu(index)
                    end
                end
            end

            if rental and rental.stationIndex == index and DoesEntityExist(rental.vehicle) then
                local vehicleCoords = GetEntityCoords(rental.vehicle)
                local distReturn = #(vehicleCoords - station.returnPoint)
                if distReturn < 40.0 then
                    sleep = 0
                    DrawMarker(1, station.returnPoint.x, station.returnPoint.y, station.returnPoint.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 6.0, 6.0, 1.5, 255, 50, 50, 150, false, true, 2, nil, nil, false)
                    if distReturn < Config.ReturnRadius and #(coords - vehicleCoords) < 10.0 and not menuOpen then
                        ESX.ShowHelpNotification(L('return_help'))
                        if IsControlJustReleased(0, 38) then
                            returnRental()
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)
