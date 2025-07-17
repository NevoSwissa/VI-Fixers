local FixerCore = _G.FixerCore

local Vehicles = {}

function Vehicles:FindClosestRoad(coords)
    local outPosition = vector3(0, 0, 0)
    local outHeading = 0
    local success, roadPosition, heading = GetClosestVehicleNodeWithHeading(
        coords.x, coords.y, coords.z, 
        outPosition, outHeading, 
        1, 3.0, 0
    )
    
    if not success then
        roadPosition = coords
        heading = 0
    end
    
    return success, roadPosition, heading
end

function Vehicles:SpawnVehicle(model, position, heading)
    RequestModel(model)
    local timeout = GetGameTimer() + 10000 
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(100)
    end
    
    if not HasModelLoaded(model) then
        return nil
    end
    
    local vehicle = CreateVehicle(model, position.x, position.y, position.z, heading, true, false)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleEngineOn(vehicle, true, true, false)
    
    SetModelAsNoLongerNeeded(model)
    
    return vehicle
end

function Vehicles:PedEnterAndDriveOff(ped, vehicle, options)
    options = options or {}
    local drivingStyle = options.drivingStyle or "normal"
    local withDriver = options.withDriver or false
    local onEnterVehicle = options.onEnterVehicle
    
    local DRIVING_STYLES = {
        fast = { speed = 35.0, driveMode = 1074528293 },
        normal = { speed = 20.0, driveMode = 786603 },
        relaxed = { speed = 12.0, driveMode = 2883621 }
    }
    local driveStyle = DRIVING_STYLES[drivingStyle] or DRIVING_STYLES.normal
    SetEntityAsMissionEntity(ped, true, true)
    SetPedMovementClipset(ped, "move_m@casual@d", 1.0)
    SetVehicleDoorsLockedForPlayer(vehicle, PlayerId(), true)
    SetEntityNoCollisionEntity(PlayerPedId(), vehicle, false)
    local state = {
        pedEntered = false,
        areaTracked = false,
        driver = nil,
        trackingId = "vehicle_entry_" .. tostring(ped)
    }
    local function handleDriveOff()
        if onEnterVehicle then onEnterVehicle() end
        
        local drivingPed = withDriver and state.driver or ped
        TaskVehicleDriveWander(drivingPed, vehicle, driveStyle.speed, driveStyle.driveMode)
        
        Wait(withDriver and 10000 or 20000)
        
        if DoesEntityExist(vehicle) then
            SetEntityAsNoLongerNeeded(vehicle)
            SetEntityAsNoLongerNeeded(ped)
            DeleteEntity(ped)
            if withDriver and DoesEntityExist(state.driver) then
                SetEntityAsNoLongerNeeded(state.driver)
                DeleteEntity(state.driver)
            end
        end
    end
    
    local function monitorPedEntry()
        local timeout = GetGameTimer() + 30000
        while GetGameTimer() < timeout and not state.pedEntered do
            Wait(100)
            if IsPedInVehicle(ped, vehicle, false) then
                state.pedEntered = true
                if state.areaTracked then
                    FixerCore.Distance:StopTracking(state.trackingId)
                    state.areaTracked = false
                end
                handleDriveOff()
                return
            end
        end
        
        if not state.pedEntered and DoesEntityExist(vehicle) then 
            DeleteEntity(vehicle) 
            if withDriver and DoesEntityExist(state.driver) then
                DeleteEntity(state.driver)
            end
        end
    end
    
    local function setupWarpIfNeeded()
        if state.areaTracked then return end
        state.areaTracked = true
        
        FixerCore.Distance:TrackArea(
            state.trackingId,
            GetEntityCoords(vehicle),
            1.5,
            true,
            function()
                if state.pedEntered then
                    FixerCore.Distance:StopTracking(state.trackingId)
                    state.areaTracked = false
                    return
                end
                
                local deadline = GetGameTimer() + 3000
                CreateThread(function()
                    while GetGameTimer() < deadline and not state.pedEntered do
                        if IsPedInVehicle(ped, vehicle, false) then
                            state.pedEntered = true
                            return
                        end
                        Wait(250)
                    end
                    
                    if not state.pedEntered then
                        local seatIndex = withDriver and 0 or -1
                        TaskWarpPedIntoVehicle(ped, vehicle, seatIndex)
                        state.pedEntered = true
                        FixerCore.Distance:StopTracking(state.trackingId)
                        state.areaTracked = false
                    end
                end)
            end
        )
    end
    if withDriver then
        local driverModel = `a_m_m_prolhost_01`
        RequestModel(driverModel)
        while not HasModelLoaded(driverModel) do Wait(10) end
        state.driver = CreatePed(4, driverModel, 0.0, 0.0, 0.0, 0.0, true, false)
        SetEntityAsMissionEntity(state.driver, true, true)
        SetPedIntoVehicle(state.driver, vehicle, -1)
        
        TaskEnterVehicle(ped, vehicle, 20000, 0, 1.3, 1, 0)
    else
        TaskEnterVehicle(ped, vehicle, 20000, -1, 1.3, 1, 0)
    end
    setupWarpIfNeeded()
    CreateThread(monitorPedEntry)
end

function Vehicles:ExitWithVehicle(ped, vehicleModel, options)
    options = options or {}
    local withDriver = options.withDriver or false
    local drivingStyle = options.drivingStyle or "normal"
    local onEnterVehicle = options.onEnterVehicle
    local customSpawnCoords = options.spawnCoords
    local customHeading = options.heading
    
    local pedCoords = GetEntityCoords(ped)
    local spawnPosition, heading
    
    if customSpawnCoords then
        spawnPosition = customSpawnCoords
        heading = customHeading or GetEntityHeading(ped)
    else
        local success, roadPosition, roadHeading = Vehicles:FindClosestRoad(pedCoords)
        if not success then
            spawnPosition = pedCoords
            heading = GetEntityHeading(ped)
        else
            spawnPosition = roadPosition
            heading = roadHeading
        end
    end
    
    ClearPedTasks(ped)
    
    local vehicle = Vehicles:SpawnVehicle(vehicleModel, spawnPosition, heading)
    
    if not vehicle then
        if onEnterVehicle then
            onEnterVehicle()
        end
        return
    end
    
    Vehicles:PedEnterAndDriveOff(ped, vehicle, {
        withDriver = withDriver,
        drivingStyle = drivingStyle,
        onEnterVehicle = onEnterVehicle
    })
    
    return vehicle
end

FixerCore.Vehicles = Vehicles