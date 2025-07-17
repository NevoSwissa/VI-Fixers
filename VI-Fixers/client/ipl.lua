local FixerCore = _G.FixerCore
local IPLSystem = {}
local IPLPoints = {}
local PlayerInIPL = false
local CurrentIPLId = nil
local Config = {
    fadeTime = 1000,
    interactionDistance = 1.2,
    blipSprite = 40,
    blipColor = 2,
    marker = {
        type = 23,
        size = {x = 1.5, y = 1.5, z = 0.8},
        maxVisibleDistance = 20.0,
        groundOffset = 0.98,
        faceCamera = false,
        rotate = false,
        rotationSpeed = 1.0
    }
}

local activeMarkers = {}

local function SetupInteractions(id, pointData)
    FixerCore.VIInteract:Remove("ipl_entry_" .. id)
    FixerCore.VIInteract:Remove("ipl_exit_" .. id)
    
    local entryInteractions = {}
    table.insert(entryInteractions, {
        key = "E",
        label = "Enter",
        description = "Enter the building",
        action = function()
            IPLSystem:EnterIPL(id)
        end
    })
    
    FixerCore.VIInteract:Add("ipl_entry_" .. id, {
        coords = pointData.entryCoords,
        distance = pointData.interactionDistance,
        interactions = entryInteractions,
        condition = function()
            return not PlayerInIPL and not pointData.locked
        end
    })
    
    FixerCore.VIInteract:Add("ipl_exit_" .. id, {
        coords = pointData.exitCoords,
        distance = pointData.interactionDistance,
        interactions = {
            {
                key = "E",
                label = "Exit",
                description = "Leave the building",
                action = function()
                    IPLSystem:ExitIPL(id)
                end
            }
        },
        condition = function()
            local p = IPLPoints[id]
            return PlayerInIPL and CurrentIPLId == id and p and not p.locked
        end
    })
end

local function CreateMarker(coords, color, id, isExit)
    local markerId = (isExit and "exit_" or "entry_") .. id
    activeMarkers[markerId] = {
        coords = coords,
        color = color,
        id = markerId,
        isExit = isExit,
        startTime = GetGameTimer()
    }
end

local function RemoveMarker(id, isExit)
    local markerId = (isExit and "exit_" or "entry_") .. id
    activeMarkers[markerId] = nil
end

local function DrawMarkers()
    local currentTime = GetGameTimer()
    local playerCoords = GetEntityCoords(PlayerPedId(), false)
    
    for markerId, marker in pairs(activeMarkers) do
        local distance = FixerCore.Distance:CalculateDistance(playerCoords, marker.coords)

        if distance <= Config.marker.maxVisibleDistance then
            local markerCoords = vector3(
                marker.coords.x, 
                marker.coords.y, 
                marker.coords.z - Config.marker.groundOffset
            )
            
            local rotation = 0.0
            if Config.marker.rotate then
                rotation = (currentTime - marker.startTime) * Config.marker.rotationSpeed * 0.1
            end
            
            DrawMarker(
                Config.marker.type,
                markerCoords.x, markerCoords.y, markerCoords.z,
                0.0, 0.0, 0.0,
                0.0, 0.0, rotation,
                Config.marker.size.x, Config.marker.size.y, Config.marker.size.z,
                marker.color.r, marker.color.g, marker.color.b, marker.color.a,
                false,
                false,
                2,
                Config.marker.rotate,
                nil, nil,
                false
            )
        end
    end
end

local function DoFadeTransition(callback)
    DoScreenFadeOut(Config.fadeTime)
    Citizen.CreateThread(function()
        while not IsScreenFadedOut() do
            Citizen.Wait(10)
        end
        if callback then
            callback()
        end
        Citizen.Wait(100)
        DoScreenFadeIn(Config.fadeTime)
    end)
end

function IPLSystem:CreatePoint(id, data)
    if IPLPoints[id] then
        IPLSystem:RemovePoint(id)
    end
    
    if not data.entryCoords or not data.exitCoords then
        print("^1[IPL System] Error: Entry and exit coordinates are required^7")
        return false
    end
    
    local pointData = {
        id = id,
        entryCoords = vector4(data.entryCoords.x, data.entryCoords.y, data.entryCoords.z, data.entryCoords.w),
        exitCoords = vector4(data.exitCoords.x, data.exitCoords.y, data.exitCoords.z, data.exitCoords.w),
        name = data.name or "IPL Point",
        blipEntry = data.blipEntry ~= false,
        blipExit = data.blipExit ~= false,
        markerEntry = data.markerEntry ~= false,
        markerExit = data.markerExit ~= false,
        onEntry = data.onEntry,
        onExit = data.onExit,
        interactionDistance = data.interactionDistance or Config.interactionDistance,
        locked = false,
    }

    IPLPoints[id] = pointData
    
    if pointData.blipEntry then
        FixerCore.Blips:Add("ipl_entry_" .. id, {
            coords = pointData.entryCoords,
            sprite = Config.blipSprite,
            color = Config.blipColor,
            scale = 0.8,
            name = pointData.name .. " (Entry)",
            shortRange = true
        })
    end
    
    if pointData.markerEntry then
        CreateMarker(pointData.entryCoords, {r = 255, g = 45, b = 85, a = 100}, id, false)
    end
    
    local entryInteractions = {}
    table.insert(entryInteractions, {
        key = "E",
        label = "Enter",
        description = "Enter the building",
        action = function()
            IPLSystem:EnterIPL(id)
        end
    })
    
    FixerCore.VIInteract:Add("ipl_entry_" .. id, {
        coords = pointData.entryCoords,
        distance = pointData.interactionDistance,
        interactions = entryInteractions,
        condition = function()
            return not PlayerInIPL and not pointData.locked
        end
    })

    FixerCore.VIInteract:Add("ipl_exit_" .. id, {
        coords = pointData.exitCoords,
        distance = pointData.interactionDistance,
        interactions = {
            {
                key = "E",
                label = "Exit",
                description = "Leave the building",
                action = function()
                    IPLSystem:ExitIPL(id)
                end
            }
        },
        condition = function()
            local p = IPLPoints[id]
            return PlayerInIPL and CurrentIPLId == id and p and not p.locked
        end
    })
    
    return true
end

function IPLSystem:RemovePoint(id)
    if not IPLPoints[id] then
        return false
    end
    
    FixerCore.Blips:Remove("ipl_entry_" .. id)
    FixerCore.Blips:Remove("ipl_exit_" .. id)
    
    RemoveMarker(id, false)
    RemoveMarker(id, true)
    
    FixerCore.VIInteract:Remove("ipl_entry_" .. id)
    FixerCore.VIInteract:Remove("ipl_exit_" .. id)
    
    IPLPoints[id] = nil
    return true
end

function IPLSystem:EnterIPL(id)
    local pointData = IPLPoints[id]
    if not pointData or pointData.locked then
        return false
    end

    DoFadeTransition(function()
        if pointData.onEntry then
            pointData.onEntry()
        end

        local playerPed = PlayerPedId()
        
        SetEntityCoords(playerPed, pointData.exitCoords.x, pointData.exitCoords.y, pointData.exitCoords.z, false, false, false, true)
        SetEntityHeading(playerPed, pointData.exitCoords.w)

        PlayerInIPL = true
        CurrentIPLId = id
        
        if pointData.blipExit then
            FixerCore.Blips:Add("ipl_exit_" .. id, {
                coords = pointData.exitCoords,
                sprite = Config.blipSprite,
                color = 1,
                scale = 0.8,
                name = pointData.name .. " (Exit)",
                shortRange = true
            })
        end
        
        if pointData.markerExit then
            CreateMarker(pointData.exitCoords, {r = 255, g = 45, b = 85, a = 100}, id, true)
        end
    end)
    
    return true
end

function IPLSystem:ExitIPL(id, delete)
    local pointData = IPLPoints[id]
    if not pointData or pointData.locked then
        return false
    end
    
    if pointData.onExit then
        pointData.onExit()
    end
    
    DoFadeTransition(function()
        local playerPed = PlayerPedId()
        
        SetEntityCoords(playerPed, pointData.entryCoords.x, pointData.entryCoords.y, pointData.entryCoords.z, false, false, false, true)
        SetEntityHeading(playerPed, pointData.entryCoords.w)

        PlayerInIPL = false
        CurrentIPLId = nil
        
        FixerCore.Blips:Remove("ipl_exit_" .. id)
        RemoveMarker(id, true)
        
        if id and delete then
            IPLSystem:RemovePoint(id)
        end
    end)
    
    return true
end

function IPLSystem:Cleanup()
    for id, _ in pairs(IPLPoints) do
        IPLSystem:RemovePoint(id)
    end
    
    PlayerInIPL = false
    CurrentIPLId = nil
    activeMarkers = {}
end

function IPLSystem:LockPoint(id)
    local pointData = IPLPoints[id]
    if pointData then
        pointData.locked = true
        SetupInteractions(id, pointData)
        return true
    end
    return false
end

function IPLSystem:UnlockPoint(id)
    local pointData = IPLPoints[id]
    if pointData then
        pointData.locked = false
        SetupInteractions(id, pointData)
        return true
    end
    return false
end

function IPLSystem:IsPointLocked(id)
    local pointData = IPLPoints[id]
    return pointData and pointData.locked or false
end

Citizen.CreateThread(function()
    while true do
        local sleep = 800
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed, false)
        local shouldDraw = false
        
        for id, pointData in pairs(IPLPoints) do
            local entryDistance = FixerCore.Distance:CalculateDistance(playerCoords, pointData.entryCoords)
            local exitDistance = FixerCore.Distance:CalculateDistance(playerCoords, pointData.exitCoords)

            if entryDistance <= Config.marker.maxVisibleDistance and not PlayerInIPL and pointData.markerEntry then
                if not activeMarkers["entry_" .. id] then
                    CreateMarker(pointData.entryCoords, {r = 255, g = 45, b = 85, a = 100}, id, false)
                end
                shouldDraw = true
            else
                if activeMarkers["entry_" .. id] then
                    RemoveMarker(id, false)
                end
            end
            
            if exitDistance <= Config.marker.maxVisibleDistance and PlayerInIPL and CurrentIPLId == id and pointData.markerExit then
                if not activeMarkers["exit_" .. id] then
                    CreateMarker(pointData.exitCoords, {r = 255, g = 45, b = 85, a = 100}, id, true)
                end
                shouldDraw = true
            else
                if activeMarkers["exit_" .. id] then
                    RemoveMarker(id, true)
                end
            end
        end
        
        if shouldDraw then
            sleep = 0
            DrawMarkers()
        end
        
        Citizen.Wait(sleep)
    end
end)

FixerCore.IPLSystem = IPLSystem