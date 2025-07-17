local FixerCore = _G.FixerCore

local StealthTakedown = {
    isPerformingTakedown = false,
    targetPed = nil,
    takedownRange = 3.5,
    takedownDuration = 4500,
}

function StealthTakedown:ExecuteTakedown(targetPed, targetId)
    if StealthTakedown.isPerformingTakedown then return end
    StealthTakedown.isPerformingTakedown = true
    StealthTakedown.targetPed = targetPed
    local playerPed = PlayerPedId()
    
    DoScreenFadeOut(200)
    RequestAnimDict("anim@scripted@bty2@ig2_beat_target@male@")
    
    local startTime = GetGameTimer()
    while not HasAnimDictLoaded("anim@scripted@bty2@ig2_beat_target@male@") and GetGameTimer() < startTime + 1000 do
        Wait(10)
    end
    
    while not IsScreenFadedOut() do
        Wait(10)
    end
    
    if not HasAnimDictLoaded("anim@scripted@bty2@ig2_beat_target@male@") then
        DoScreenFadeIn(200)
        StealthTakedown.isPerformingTakedown = false
        return
    end
    
    local enemyPos = GetEntityCoords(targetPed)
    local enemyHeading = GetEntityHeading(targetPed)
    
    local behind_distance = 0.75
    local behind_x = enemyPos.x - behind_distance * math.sin(math.rad(enemyHeading))
    local behind_y = enemyPos.y - behind_distance * math.cos(math.rad(enemyHeading))
    local groundZ = enemyPos.z
    
    local found, properZ = GetGroundZFor_3dCoord(behind_x, behind_y, enemyPos.z + 2.0, 0)
    if found then
        groundZ = properZ
    end
    
    SetEntityCoordsNoOffset(playerPed, behind_x, behind_y, groundZ, true, true, true)
    SetEntityHeading(playerPed, enemyHeading)
    
    Wait(100)
    
    SetEntityInvincible(targetPed, true)
    SetBlockingOfNonTemporaryEvents(targetPed, true)
    ClearPedTasksImmediately(targetPed)
    SetEntityHeading(targetPed, enemyHeading)
    
    if not IsEntityInAir(targetPed) then
        PlaceObjectOnGroundProperly(targetPed)
    end
    
    if not IsEntityInAir(playerPed) then
        PlaceObjectOnGroundProperly(playerPed)
    end
    
    local playerPos = GetEntityCoords(playerPed)
    local targetPos = GetEntityCoords(targetPed)
    
    SetEntityCoordsNoOffset(playerPed, playerPos.x, playerPos.y, targetPos.z, true, true, true)
    
    local offsetX = 0.75 * math.sin(math.rad(enemyHeading))
    local offsetY = 0.75 * math.cos(math.rad(enemyHeading))
    SetEntityCoordsNoOffset(playerPed, 
        targetPos.x - offsetX, 
        targetPos.y - offsetY, 
        targetPos.z, 
        true, true, true)
    SetEntityHeading(playerPed, enemyHeading)
    
    TaskPlayAnim(playerPed, "anim@scripted@bty2@ig2_beat_target@male@", "leaning_choke_golfer", 8.0, -8.0, StealthTakedown.takedownDuration, 0, 0, false, false, false)
    TaskPlayAnim(targetPed, "anim@scripted@bty2@ig2_beat_target@male@", "leaning_choke_bounty", 8.0, -8.0, StealthTakedown.takedownDuration, 0, 0, false, false, false)
    
    AttachEntityToEntity(targetPed, playerPed, GetPedBoneIndex(playerPed, 0), -0.15, 0.3, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    DoScreenFadeIn(200)
    
    Citizen.CreateThread(function()
        local startTime = GetGameTimer()
        
        while GetGameTimer() < startTime + StealthTakedown.takedownDuration - 500 do
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 157, true)
            DisableControlAction(0, 158, true)
            DisableControlAction(0, 160, true)
            DisableControlAction(0, 164, true)
            
            if not DoesEntityExist(targetPed) or IsEntityDead(targetPed) then
                break
            end
            
            Wait(0)
        end
        
        local playerPos = GetEntityCoords(playerPed)
        local playerHeading = GetEntityHeading(playerPed)
        local offsetX = 1.0 * math.sin(math.rad(playerHeading))
        local offsetY = 1.0 * math.cos(math.rad(playerHeading))
        
        DetachEntity(targetPed, false, false)
        SetEntityInvincible(targetPed, false)
        SetPedToRagdoll(targetPed, 1000, 4000, 0, false, false, false)
        Wait(1600)
        SetEntityHealth(targetPed, 0)
        
        StealthTakedown.isPerformingTakedown = false
        StealthTakedown.targetPed = nil
        
        ClearPedTasksImmediately(playerPed)
    end)
end

function StealthTakedown:CheckStealthTakedownOpportunity(enemyId)
    local enemyData = FixerCore.EnemyAI.active[enemyId]
    if not enemyData or not enemyData.canUseStealth or not DoesEntityExist(enemyData.ped) or IsEntityDead(enemyData.ped) or enemyData.isAlerted then
        return false
    end
    
    local playerPed = PlayerPedId()
    local playerPos = GetEntityCoords(playerPed)
    local enemyPos = GetEntityCoords(enemyData.ped)
    local distance = FixerCore.Distance:CalculateDistance(playerPos, enemyPos)
    
    local zDifference = math.abs(playerPos.z - enemyPos.z)
    local maxZDifference = 0.5
    
    if zDifference > maxZDifference then
        return false
    end
    
    if IsEntityInAir(playerPed) or IsEntityInAir(enemyData.ped) then
        return false
    end
    
    if distance <= 3.0 then
        local angleToPlayer = FixerCore.EnemyAI:GetAngleBetweenEntities(enemyData.ped, playerPed)
        
        local absAngle = math.abs(angleToPlayer)
        local isBehindEnemy = absAngle > 120 and absAngle < 240
        
        local enemyHeading = GetEntityHeading(enemyData.ped)
        local playerHeading = GetEntityHeading(playerPed)
        
        local headingDiff = math.abs((enemyHeading - playerHeading + 180) % 360 - 180)
        local isAlignedHeading = headingDiff < 50
        
        return isBehindEnemy and isAlignedHeading
    end
    
    return false
end

function StealthTakedown:ArePedsOnSameLevel(ped1, ped2, tolerance)
    tolerance = tolerance or 1.0
    
    if not DoesEntityExist(ped1) or not DoesEntityExist(ped2) then
        return false
    end
    
    local pos1 = GetEntityCoords(ped1)
    local pos2 = GetEntityCoords(ped2)
    
    local zDiff = math.abs(pos1.z - pos2.z)
    
    return zDiff <= tolerance
end

function StealthTakedown:GetPedHeightDifference(ped1, ped2)
    if not DoesEntityExist(ped1) or not DoesEntityExist(ped2) then
        return 0.0
    end
    
    local pos1 = GetEntityCoords(ped1)
    local pos2 = GetEntityCoords(ped2)
    
    return pos1.z - pos2.z
end

function StealthTakedown:AlignPedsForTakedown(playerPed, targetPed)
    if not DoesEntityExist(playerPed) or not DoesEntityExist(targetPed) then
        return false
    end
    
    local targetPos = GetEntityCoords(targetPed)
    local targetHeading = GetEntityHeading(targetPed)
    
    local behind_distance = 0.75
    local offsetX = behind_distance * math.sin(math.rad(targetHeading))
    local offsetY = behind_distance * math.cos(math.rad(targetHeading))
    
    local _, groundZ = GetGroundZFor_3dCoord(targetPos.x - offsetX, targetPos.y - offsetY, targetPos.z, false)
    
    SetEntityCoordsNoOffset(playerPed, 
        targetPos.x - offsetX, 
        targetPos.y - offsetY, 
        targetPos.z,
        true, true, true)
    
    SetEntityHeading(playerPed, targetHeading)
    
    if not IsEntityInAir(targetPed) then
        PlaceObjectOnGroundProperly(targetPed)
    end
    
    if not IsEntityInAir(playerPed) then
        PlaceObjectOnGroundProperly(playerPed)
    end
    
    local playerPos = GetEntityCoords(playerPed)
    targetPos = GetEntityCoords(targetPed)
    
    if math.abs(playerPos.z - targetPos.z) > 0.1 then
        SetEntityCoordsNoOffset(playerPed, playerPos.x, playerPos.y, targetPos.z, true, true, true)
    end
    
    return true
end

FixerCore.StealthTakedown = StealthTakedown