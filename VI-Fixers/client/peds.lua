local FixerCore = _G.FixerCore

local Peds = { 
    active = {}, 
    activeProps = {},
    activeFollowTask = nil,
    activeGuideTask = nil,
}

function Peds:SpawnPed(id, model, coords, heading, opts)
    if Peds.active[id] then
        DeleteEntity(Peds.active[id])
        Peds.active[id] = nil
    end
    
    local propEntity = nil
    if opts and opts.prop then
        local propId = id .. "_prop"
        propEntity = FixerCore.Props:SpawnProp(propId, opts.prop.model, coords, heading, {
            offset = opts.prop.offset,
            flipHeading = opts.prop.flipPropHeading,
            freeze = opts.prop.freezeProp
        })

        Peds.activeProps[id] = propId
    end
    
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(50) end
    
    local zOffset = (opts and opts.minusValue) and -opts.minusValue or 0.0
    local spawnCoords = vec3(coords.x, coords.y, coords.z + zOffset)
    
    local ped = CreatePed(4, model, spawnCoords.x, spawnCoords.y, spawnCoords.z, heading or 0.0, true, true)
    
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, true)
    SetPedCombatAttributes(ped, 46, true)
    SetPedCombatAttributes(ped, 17, true)
    SetPedCombatAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 1, false)
    SetPedCombatAttributes(ped, 2, false)
    SetPedCombatAttributes(ped, 4, false)
    SetPedCanBeTargetted(ped, false)
    SetPedCanBeTargettedByPlayer(ped, false)
    SetEntityInvincible(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedDiesWhenInjured(ped, false)
    SetPedAsEnemy(ped, false)
    SetEntityProofs(ped, true, true, true, true, true, true, true, true)
    DisablePedPainAudio(ped, true)

    SetPedConfigFlag(ped, 104, true)
    SetPedConfigFlag(ped, 208, true)
    SetPedConfigFlag(ped, 410, true)
    SetPedConfigFlag(ped, 281, true)
    SetPedConfigFlag(ped, 33, true)

    if opts then
        if opts.freeze then FreezeEntityPosition(ped, true) end
        if opts.invincible then SetEntityInvincible(ped, true) end
        if opts.scenario then TaskStartScenarioInPlace(ped, opts.scenario, 0, true) end
        if opts.anim then
            RequestAnimDict(opts.anim.Dict)
            while not HasAnimDictLoaded(opts.anim.Dict) do Wait(50) end
            TaskPlayAnim(ped, opts.anim.Dict, opts.anim.Name, 8.0, -8.0, -1, opts.anim.Flag or 1, 0, false, false, false)
        end
    end

    Peds.active[id] = ped
    return ped, propEntity
end

function Peds:GetPed(id)
    return Peds.active[id]
end

function Peds:DeletePed(id, alsoDeleteProp)
    if Peds.active[id] then
        DeleteEntity(Peds.active[id])
        Peds.active[id] = nil
    end

    if alsoDeleteProp and Peds.activeProps[id] then
        FixerCore.Props:DeleteProp(Peds.activeProps[id])
        Peds.activeProps[id] = nil
    end
end

function Peds:SetFollowBehavior(guider, follower, opts)
    if not opts then return end

    Peds:ClearFollowBehavior()
    
    local taskData = {
        guider = guider,
        follower = follower,
        destination = opts.destination,
        isPlayerGuider = opts.isPlayerGuider,
        isActive = true,
        destinationReached = opts.onDestinationReached
    }
    
    if isPlayerGuider then
        Peds.activeFollowTask = taskData
    else
        Peds.activeGuideTask = taskData
    end
    
    Peds:StartTaskLoop(taskData)
end

function Peds:ClearFollowBehavior()
    if Peds.activeGuideTask then
        Peds.activeGuideTask.isActive = false
        if DoesEntityExist(Peds.activeGuideTask.guider) then
            ClearPedTasks(Peds.activeGuideTask.guider)
        end

        Peds.activeGuideTask = nil
    end
    
    if Peds.activeFollowTask then
        Peds.activeFollowTask.isActive = false
        if DoesEntityExist(Peds.activeFollowTask.follower) then
            ClearPedTasks(Peds.activeFollowTask.follower)
        end

        Peds.activeFollowTask = nil
    end
end

function Peds:StartTaskLoop(taskData)
    Citizen.CreateThread(function()
        while taskData.isActive do
            Citizen.Wait(500)
            
            if not taskData.isActive then break end
            local guiderCoords, followerCoords
            
            if taskData.isPlayerGuider then
                guiderCoords = GetEntityCoords(GetPlayerPed(taskData.guider))
                followerCoords = GetEntityCoords(taskData.follower)
                
                local distToDestination = FixerCore.Distance:CalculateDistance(guiderCoords, taskData.destination)
                if distToDestination <= 2.0 then
                    Peds:ClearFollowBehavior()
                    if taskData.destinationReached then taskData.destinationReached() end
                    break
                end
                
                Peds:HandlePedFollowing(taskData.follower, guiderCoords, followerCoords)
            else
                guiderCoords = GetEntityCoords(taskData.guider)
                followerCoords = GetEntityCoords(GetPlayerPed(taskData.follower))
                
                local distToDestination = FixerCore.Distance:CalculateDistance(guiderCoords, taskData.destination)
                if distToDestination <= 2.0 then
                    Peds:ClearFollowBehavior()
                    if taskData.destinationReached then taskData.destinationReached() end
                    break
                end
                
                Peds:HandlePedGuiding(taskData.guider, taskData.destination, guiderCoords, followerCoords)
            end
        end
    end)
end

function Peds:HandlePedFollowing(pedHandle, targetCoords, pedCoords)
    if not DoesEntityExist(pedHandle) then return end
    
    local distance = FixerCore.Distance:CalculateDistance(pedCoords, targetCoords)
    
    if distance > 3.0 then
        if not IsPedInAnyVehicle(pedHandle, false) then
            ClearPedTasks(pedHandle)

            if distance > 8.0 then
                TaskGoToCoordAnyMeans(pedHandle, targetCoords.x, targetCoords.y, targetCoords.z, 2.0, 0, 0, 786603, 0xbf800000)
            else
                TaskGoToCoordAnyMeans(pedHandle, targetCoords.x, targetCoords.y, targetCoords.z, 1.0, 0, 0, 786603, 0xbf800000)
            end
        end
    else
        if GetEntitySpeed(pedHandle) > 0.1 then
            ClearPedTasks(pedHandle)
        end
    end
end

function Peds:HandlePedGuiding(pedHandle, destination, pedCoords, playerCoords)
    if not DoesEntityExist(pedHandle) then return end
    
    local distToDestination = FixerCore.Distance:CalculateDistance(pedCoords, destination)
    local distToPlayer = FixerCore.Distance:CalculateDistance(pedCoords, playerCoords)
    
    if distToPlayer > 8.0 then
        ClearPedTasks(pedHandle)
        TaskTurnPedToFaceEntity(pedHandle, GetPlayerPed(PlayerId()), 3000)
        return
    end
    
    if distToDestination <= 2.0 then
        ClearPedTasks(pedHandle)
        return
    end
    
    if distToPlayer < 3.0 then
        if not IsPedInAnyVehicle(pedHandle, false) then
            ClearPedTasks(pedHandle)
            TaskGoToCoordAnyMeans(pedHandle, destination.x, destination.y, destination.z, 1.0, 0, 0, 786603, 0xbf800000)
        end
    end
end

FixerCore.Peds = Peds