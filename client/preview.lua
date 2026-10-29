Preview = {}

local entity = nil
local camera = nil
local token = 0

function Preview.clear()
    token = token + 1
    if camera then
        RenderScriptCams(false, true, 400, true, false)
        DestroyCam(camera, false)
        camera = nil
    end
    if entity and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
    entity = nil
end

function Preview.show(model, station)
    Preview.clear()
    if not Config.Preview.enable then
        return
    end

    local current = token
    local hash = GetHashKey(model)
    RequestModel(hash)
    local attempts = 0
    while not HasModelLoaded(hash) and attempts < 200 do
        Wait(10)
        attempts = attempts + 1
    end
    if current ~= token or not HasModelLoaded(hash) then
        SetModelAsNoLongerNeeded(hash)
        return
    end

    local spawn = station.spawnPoint
    entity = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityInvincible(entity, true)
    FreezeEntityPosition(entity, true)
    SetVehicleDoorsLocked(entity, 2)
    SetVehicleDirtLevel(entity, 0.0)

    local center = vector3(spawn.x, spawn.y, spawn.z + 0.8)
    camera = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', center.x + Config.Preview.distance, center.y, center.z + Config.Preview.height, 0.0, 0.0, 0.0, 50.0, false, 0)
    PointCamAtCoord(camera, center.x, center.y, center.z)
    SetCamActive(camera, true)
    RenderScriptCams(true, true, 500, true, false)

    local angle = 0.0
    CreateThread(function()
        while camera and current == token do
            angle = angle + Config.Preview.speed
            local rad = math.rad(angle)
            SetCamCoord(camera, center.x + math.cos(rad) * Config.Preview.distance, center.y + math.sin(rad) * Config.Preview.distance, center.z + Config.Preview.height)
            PointCamAtCoord(camera, center.x, center.y, center.z)
            Wait(0)
        end
    end)
end
