local ESX = exports['es_extended']:getSharedObject()

local activeRentals = {}
local plateOwners = {}

local function trim(value)
    return (tostring(value or ''):gsub('^%s*(.-)%s*$', '%1'))
end

local function fail(message)
    return { ok = false, message = message }
end

local function notify(src, message)
    if GetPlayerName(src) then
        TriggerClientEvent('len_vehiclerental:notify', src, message)
    end
end

local function findInsurance(key)
    for _, insurance in ipairs(Config.Insurances) do
        if insurance.key == key then
            return insurance
        end
    end
    return nil
end

local function findVehicle(station, categoryIndex, vehicleIndex)
    local category = station.categories[categoryIndex]
    if not category then
        return nil, nil
    end
    return category, category.vehicles[vehicleIndex]
end

local function getRentalEntity(rental)
    if not rental or not rental.netId then
        return nil
    end
    local entity = NetworkGetEntityFromNetworkId(rental.netId)
    if entity == 0 or not DoesEntityExist(entity) then
        return nil
    end
    return entity
end

local function hasLicense(identifier, licenseType)
    if not Config.RequireLicenseCheck or not licenseType then
        return true
    end
    local row = MySQL.scalar.await('SELECT type FROM ' .. Config.LicenseTable .. ' WHERE owner = ? AND type = ?', { identifier, licenseType })
    return row ~= nil
end

local function getDebtTotal(identifier)
    local total = MySQL.scalar.await('SELECT COALESCE(SUM(amount), 0) FROM len_rental_debts WHERE identifier = ?', { identifier })
    return tonumber(total) or 0
end

local function getDebts(identifier)
    local rows = MySQL.query.await('SELECT id, amount, reason FROM len_rental_debts WHERE identifier = ? ORDER BY id DESC LIMIT 25', { identifier }) or {}
    for _, row in ipairs(rows) do
        row.amount = tonumber(row.amount) or 0
    end
    return rows
end

local function addDebt(identifier, amount, reason)
    MySQL.insert.await('INSERT INTO len_rental_debts (identifier, amount, reason, created_at) VALUES (?, ?, ?, NOW())', { identifier, amount, reason })
end

local function payOrDebt(src, identifier, amount, reason)
    if amount <= 0 then
        return true
    end
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer and xPlayer.getAccount(Config.Account).money >= amount then
        xPlayer.removeAccountMoney(Config.Account, amount)
        return true
    end
    addDebt(identifier, amount, reason)
    notify(src, L('debt_added', FormatMoney(amount)))
    return false
end

local function generatePlate()
    local chars = 'ABCDEFGHJKLMNPRSTUVWXYZ0123456789'
    for _ = 1, 100 do
        local parts = {}
        for i = 1, 5 do
            local index = math.random(1, #chars)
            parts[i] = chars:sub(index, index)
        end
        local plate = 'RNT' .. table.concat(parts)
        if not plateOwners[plate] then
            return plate
        end
    end
    return nil
end

local function buildRentalState(src)
    local rental = activeRentals[src]
    if not rental then
        return nil
    end
    return {
        plate = rental.plate,
        model = rental.model,
        status = rental.status,
        expiresIn = rental.expiresAt - os.time(),
        insurance = rental.insuranceKey,
        deposit = rental.deposit,
        basePrice = rental.basePrice,
        tempPrice = rental.tempPrice,
        damage = rental.damageTotal,
        lateFees = rental.lateFees,
        km = rental.kmTotal,
        stationIndex = rental.stationIndex
    }
end

local function endRental(src, status, notifyClient)
    local rental = activeRentals[src]
    if not rental then
        return
    end
    MySQL.update.await('UPDATE len_rentals SET status = ?, ended_at = NOW(), damage_total = ?, km_total = ?, late_fees = ? WHERE id = ?', {
        status, rental.damageTotal, rental.kmTotal, rental.lateFees, rental.id
    })
    local entity = getRentalEntity(rental)
    if entity then
        DeleteEntity(entity)
    end
    plateOwners[rental.plate] = nil
    activeRentals[src] = nil
    if notifyClient ~= false and GetPlayerName(src) then
        TriggerClientEvent('len_vehiclerental:clear', src, rental.plate)
    end
end

local function alertPolice(rental)
    local entity = getRentalEntity(rental)
    if not entity then
        return
    end
    local coords = GetEntityCoords(entity)
    for _, job in ipairs(Config.Penalties.stolenJobs) do
        for _, xPlayer in ipairs(ESX.GetExtendedPlayers('job', job)) do
            TriggerClientEvent('len_vehiclerental:stolenAlert', xPlayer.source, rental.plate, coords)
        end
    end
end

ESX.RegisterServerCallback('len_vehiclerental:getState', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return cb(nil)
    end
    local identifier = xPlayer.identifier
    local licenses = {}
    for _, station in ipairs(Config.Stations) do
        for _, category in ipairs(station.categories) do
            if category.license and licenses[category.license] == nil then
                licenses[category.license] = hasLicense(identifier, category.license)
            end
        end
    end
    cb({
        licenses = licenses,
        rental = buildRentalState(source),
        debts = getDebts(identifier),
        debtTotal = getDebtTotal(identifier)
    })
end)

ESX.RegisterServerCallback('len_vehiclerental:rent', function(source, cb, data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then
        return cb(fail(L('rent_error')))
    end
    if activeRentals[src] then
        return cb(fail(L('rent_already')))
    end

    local stationIndex = tonumber(data.stationIndex)
    local station = Config.Stations[stationIndex]
    if not station then
        return cb(fail(L('rent_invalid')))
    end
    if #(GetEntityCoords(GetPlayerPed(src)) - station.coords) > Config.MaxRentDistance then
        return cb(fail(L('rent_too_far')))
    end

    local category, vehicle = findVehicle(station, tonumber(data.categoryIndex), tonumber(data.vehicleIndex))
    local duration = Config.Durations[tonumber(data.durationIndex)]
    local insurance = findInsurance(data.insuranceKey)
    if not category or not vehicle or not duration or not insurance then
        return cb(fail(L('rent_invalid')))
    end

    local identifier = xPlayer.identifier
    local debt = getDebtTotal(identifier)
    if debt > 0 then
        return cb(fail(L('rent_debts', FormatMoney(debt))))
    end
    if not hasLicense(identifier, category.license) then
        return cb(fail(L('rent_license')))
    end

    local rent = math.floor(vehicle.basePrice * duration.multiplier)
    local insuranceCost = math.floor(vehicle.basePrice * insurance.percent)
    local deposit = math.floor(vehicle.basePrice * Config.Deposit)
    local total = rent + insuranceCost + deposit
    if xPlayer.getAccount(Config.Account).money < total then
        return cb(fail(L('rent_no_money', FormatMoney(total))))
    end

    local plate = generatePlate()
    if not plate then
        return cb(fail(L('rent_error')))
    end

    xPlayer.removeAccountMoney(Config.Account, total)
    local id = MySQL.insert.await([[
        INSERT INTO len_rentals (identifier, plate, model, station, status, base_price, deposit, insurance, paid, started_at, expires_at)
        VALUES (?, ?, ?, ?, 'active', ?, ?, ?, ?, NOW(), DATE_ADD(NOW(), INTERVAL ? MINUTE))
    ]], { identifier, plate, vehicle.model, stationIndex, vehicle.basePrice, deposit, insurance.key, total, duration.minutes })
    if not id then
        xPlayer.addAccountMoney(Config.Account, total)
        return cb(fail(L('rent_error')))
    end

    activeRentals[src] = {
        id = id,
        identifier = identifier,
        plate = plate,
        model = vehicle.model,
        stationIndex = stationIndex,
        basePrice = vehicle.basePrice,
        tempPrice = vehicle.tempPrice,
        deposit = deposit,
        insuranceKey = insurance.key,
        coverage = insurance.coverage,
        expiresAt = os.time() + duration.minutes * 60,
        status = 'active',
        overdueSince = nil,
        lastFeeAt = nil,
        stolenReported = false,
        lateFees = 0,
        damageTotal = 0,
        kmTotal = 0,
        lastKmAt = nil,
        netId = nil
    }
    plateOwners[plate] = src

    cb({
        ok = true,
        message = L('rent_success', plate),
        plate = plate,
        model = vehicle.model,
        expiresIn = duration.minutes * 60,
        insurance = insurance.key,
        deposit = deposit,
        basePrice = vehicle.basePrice,
        tempPrice = vehicle.tempPrice
    })
end)

ESX.RegisterServerCallback('len_vehiclerental:bind', function(source, cb, plate, netId)
    local rental = activeRentals[source]
    if not rental or rental.plate ~= plate or type(netId) ~= 'number' then
        return cb(false)
    end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 or not DoesEntityExist(entity) then
        return cb(false)
    end
    if trim(GetVehicleNumberPlateText(entity)) ~= plate then
        return cb(false)
    end
    rental.netId = netId
    cb(true)
end)

ESX.RegisterServerCallback('len_vehiclerental:returnVehicle', function(source, cb, plate)
    local src = source
    local rental = activeRentals[src]
    if not rental or rental.plate ~= plate then
        return cb(fail(L('not_rental_vehicle')))
    end
    local entity = getRentalEntity(rental)
    if not entity then
        return cb(fail(L('return_no_vehicle')))
    end
    local station = Config.Stations[rental.stationIndex]
    if #(GetEntityCoords(entity) - station.returnPoint) > Config.ReturnRadius + 2.0 then
        return cb(fail(L('return_not_near')))
    end

    local overdue = rental.status == 'overdue'
    local refund = rental.deposit
    if overdue then
        refund = math.floor(refund * Config.OverdueDepositRefund)
    end
    local xPlayer = ESX.GetPlayerFromId(src)
    if refund > 0 and xPlayer then
        xPlayer.addAccountMoney(Config.Account, refund)
    end

    endRental(src, overdue and 'returned_late' or 'returned')
    cb({
        ok = true,
        message = L(overdue and 'return_success_overdue' or 'return_success', FormatMoney(refund))
    })
end)

ESX.RegisterServerCallback('len_vehiclerental:extend', function(source, cb, durationIndex)
    local rental = activeRentals[source]
    if not rental then
        return cb(fail(L('no_rental')))
    end
    if rental.status == 'overdue' then
        return cb(fail(L('extend_overdue')))
    end
    local duration = Config.Durations[tonumber(durationIndex)]
    local xPlayer = ESX.GetPlayerFromId(source)
    if not duration or not xPlayer then
        return cb(fail(L('rent_invalid')))
    end
    local cost = math.floor(rental.basePrice * duration.multiplier)
    if xPlayer.getAccount(Config.Account).money < cost then
        return cb(fail(L('rent_no_money', FormatMoney(cost))))
    end
    xPlayer.removeAccountMoney(Config.Account, cost)
    rental.expiresAt = rental.expiresAt + duration.minutes * 60
    MySQL.update.await('UPDATE len_rentals SET expires_at = DATE_ADD(expires_at, INTERVAL ? MINUTE), paid = paid + ? WHERE id = ?', { duration.minutes, cost, rental.id })
    cb({
        ok = true,
        message = L('extend_success', duration.minutes),
        expiresIn = rental.expiresAt - os.time()
    })
end)

ESX.RegisterServerCallback('len_vehiclerental:payDebts', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return cb(fail(L('rent_error')))
    end
    local identifier = xPlayer.identifier
    local total = getDebtTotal(identifier)
    if total <= 0 then
        return cb(fail(L('debts_none')))
    end
    local pay = math.min(total, xPlayer.getAccount(Config.Account).money)
    if pay <= 0 then
        return cb(fail(L('debts_insufficient')))
    end

    local rows = MySQL.query.await('SELECT id, amount FROM len_rental_debts WHERE identifier = ? ORDER BY id ASC', { identifier }) or {}
    local remaining = pay
    for _, row in ipairs(rows) do
        local amount = tonumber(row.amount) or 0
        if remaining <= 0 then
            break
        end
        if amount <= remaining then
            MySQL.update.await('DELETE FROM len_rental_debts WHERE id = ?', { row.id })
            remaining = remaining - amount
        else
            MySQL.update.await('UPDATE len_rental_debts SET amount = amount - ? WHERE id = ?', { remaining, row.id })
            remaining = 0
        end
    end

    xPlayer.removeAccountMoney(Config.Account, pay)
    cb({
        ok = true,
        message = L('debts_paid', FormatMoney(pay)),
        remaining = total - pay
    })
end)

RegisterNetEvent('len_vehiclerental:km', function(plate)
    local src = source
    local rental = activeRentals[src]
    if not rental or rental.plate ~= plate then
        return
    end
    local now = GetGameTimer()
    if rental.lastKmAt and now - rental.lastKmAt < 8000 then
        return
    end
    rental.lastKmAt = now
    rental.kmTotal = rental.kmTotal + 1
    payOrDebt(src, rental.identifier, rental.tempPrice, 'km')
end)

RegisterNetEvent('len_vehiclerental:damage', function(plate, points)
    local src = source
    local rental = activeRentals[src]
    points = tonumber(points)
    if not rental or rental.plate ~= plate or not points or points <= 0 then
        return
    end
    points = math.min(points, Config.Damage.maxPointsPerEvent)
    local cost = math.floor(points * rental.basePrice * Config.Damage.costFactor)
    local insurance = findInsurance(rental.insuranceKey)
    local owed = cost - math.floor(cost * insurance.coverage)
    if owed <= 0 then
        return
    end
    rental.damageTotal = rental.damageTotal + owed
    if payOrDebt(src, rental.identifier, owed, 'damage') then
        notify(src, L('damage_charged', FormatMoney(owed)))
    end
end)

RegisterNetEvent('len_vehiclerental:totalLoss', function(plate)
    local src = source
    local rental = activeRentals[src]
    if not rental or rental.plate ~= plate then
        return
    end
    local insurance = findInsurance(rental.insuranceKey)
    if insurance.totalLoss then
        notify(src, L('totalloss_insured'))
    else
        local fee = math.floor(rental.basePrice * Config.Damage.totalLossFactor)
        rental.damageTotal = rental.damageTotal + fee
        payOrDebt(src, rental.identifier, fee, 'wreck')
        notify(src, L('totalloss', FormatMoney(fee)))
    end
    endRental(src, 'wrecked')
end)

RegisterNetEvent('len_vehiclerental:vehicleLost', function(plate)
    local src = source
    local rental = activeRentals[src]
    if not rental or rental.plate ~= plate or not rental.netId then
        return
    end
    if getRentalEntity(rental) then
        return
    end
    local fee = math.floor(rental.basePrice * Config.Penalties.lostFactor)
    payOrDebt(src, rental.identifier, fee, 'lost')
    notify(src, L('vehicle_lost', FormatMoney(fee)))
    endRental(src, 'lost')
end)

AddEventHandler('playerDropped', function()
    local src = source
    local rental = activeRentals[src]
    if not rental then
        return
    end
    local fee = math.floor(rental.basePrice * Config.Penalties.abandonFactor)
    payOrDebt(src, rental.identifier, fee, 'abandon')
    endRental(src, 'abandoned', false)
end)

CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for src, rental in pairs(activeRentals) do
            if now >= rental.expiresAt then
                if rental.status ~= 'overdue' then
                    rental.status = 'overdue'
                    rental.overdueSince = now
                    rental.lastFeeAt = now
                    MySQL.update.await("UPDATE len_rentals SET status = 'overdue' WHERE id = ?", { rental.id })
                    notify(src, L('overdue_started'))
                elseif now - rental.lastFeeAt >= Config.Penalties.lateFeeInterval * 60 then
                    rental.lastFeeAt = now
                    local fee = math.floor(rental.basePrice * Config.Penalties.lateFeeFactor)
                    rental.lateFees = rental.lateFees + fee
                    if payOrDebt(src, rental.identifier, fee, 'late') then
                        notify(src, L('overdue_fee', FormatMoney(fee)))
                    end
                end
                if not rental.stolenReported and now - rental.overdueSince >= Config.Penalties.stolenAfter * 60 then
                    rental.stolenReported = true
                    alertPolice(rental)
                end
            end
        end
    end
end)

MySQL.ready(function()
    MySQL.update.await("UPDATE len_rentals SET status = 'expired', ended_at = NOW() WHERE status IN ('active', 'overdue')")
end)
