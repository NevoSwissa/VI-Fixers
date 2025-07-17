local FixerCore = _G.FixerCore

local EnemyAI = {
    active = {},
    groups = {},
    nextId = 1,
    defaultAccuracy = 50,
    defaultDetectionRange = 15.0,
    defaultFieldOfView = 110.0,
    guardScenarios = {
        "WORLD_HUMAN_GUARD_STAND",
        "WORLD_HUMAN_GUARD_STAND_ARMY",
        "WORLD_HUMAN_SMOKING",
        "WORLD_HUMAN_CLIPBOARD",
        "WORLD_HUMAN_STAND_MOBILE",
        "WORLD_HUMAN_SECURITY_SHINE_TORCH",
        "WORLD_HUMAN_COP_IDLES",
        "WORLD_HUMAN_STAND_IMPATIENT"
    },
    patrolTypes = {
        NONE = 0,
        STATIONARY = 1,
        ROAMING = 2
    },
}

AddEventHandler('gameEventTriggered', function(event, args)
    if event ~= 'CEventNetworkEntityDamage' then return end

    local victimEntity = args[1]
    local attackerEntity = args[2]

    local playerPed = PlayerPedId()
    if attackerEntity ~= playerPed then return end

    local weapon = GetSelectedPedWeapon(playerPed)

    if not IsPedCurrentWeaponSilenced(weapon) then
        for enemyId, enemyData in pairs(EnemyAI.active) do
            if enemyData.ped == victimEntity then
                EnemyAI:HandlePlayerDetection(enemyId, playerPed)
                break
            end
        end
    end
end)

function EnemyAI:ProcessEnemyBehavior(enemyId)
    local enemyData = EnemyAI.active[enemyId]
    if not enemyData then return end

    local isSpottingPlayer = false
    local hasActiveInteraction = false
    local detectionScore = 0.0
    local spottingWait = 500
    
    SetBlockingOfNonTemporaryEvents(enemyData.ped, true)
    SetPedCombatAttributes(enemyData.ped, 46, false)
    SetPedCombatAttributes(enemyData.ped, 5, true)

    local takedownInteractionId = "takedown_" .. enemyId
    if not enemyData.detectionBlip then
        enemyData.detectionBlip = FixerCore.Blips:Add("enemy_vision_cone_" .. enemyId, {
            entity = enemyData.ped,
            sprite = 6,
            color = 3,
            scale = 0.9,
            alpha = 100,
            name = "Detection Range",
            dials = {
                isShortRange = true,
            },
        })
        SetBlipRotation(enemyData.detectionBlip, math.floor(GetEntityHeading(enemyData.ped)))
        SetBlipAsShortRange(enemyData.detectionBlip, true)
    end

    while DoesEntityExist(enemyData.ped) do
        local playerPed = PlayerPedId()
        local enemyPos = GetEntityCoords(enemyData.ped)
        local playerPos = GetEntityCoords(playerPed)
        local distance = FixerCore.Distance:CalculateDistance(playerPos, enemyPos)
        local isPlayerInStealth = GetPedStealthMovement(playerPed)
        local hasClearLOS = HasEntityClearLosToEntity(enemyData.ped, playerPed, 17)
        local angleToPlayer = EnemyAI:GetAngleBetweenEntities(enemyData.ped, playerPed)
        local playerSpeed = GetEntitySpeed(playerPed)
        
        if IsEntityDead(enemyData.ped) then
            FixerCore.Blips:Remove("enemy_vision_cone_" .. enemyId)
            FixerCore.Blips:Remove("enemy_" .. enemyId)

            if not enemyData.deadTimer then
                enemyData.isDead = true
                if enemyData.onDeath then
                    local allEnemiesDead = EnemyAI:AreAllEnemiesDead(enemyId)
                    enemyData.onDeath(enemyData.ped, allEnemiesDead)
                end

                if hasActiveInteraction then
                    FixerCore.VIInteract:Remove(takedownInteractionId)
                    hasActiveInteraction = false
                end

                enemyData.isAlerted = false
                enemyData.deadTimer = GetGameTimer() + 60000
            else
                if distance > 100.0 or GetGameTimer() > enemyData.deadTimer then
                    EnemyAI:CleanupEnemy(enemyId)
                    break
                end
            end
            Citizen.Wait(1000)
            goto continue
        end
        
        if enemyData.isAlerted then
            detectionScore = 0.0
            if enemyData.patrol then
                enemyData.patrol.isMoving = false
                enemyData.patrol.currentScenario = nil
            end
        end
        
        if not enemyData.isAlerted and enemyData.patrol then
            if enemyData.patrol.type == EnemyAI.patrolTypes.STATIONARY then
                EnemyAI:ProcessStationaryPatrol(enemyData)
            elseif enemyData.patrol.type == EnemyAI.patrolTypes.ROAMING then
                EnemyAI:ProcessRoamingPatrol(enemyData)
            end
        end
        
        if not enemyData.isAlerted then
            local canTakedown = FixerCore.StealthTakedown:CheckStealthTakedownOpportunity(enemyId)
            if canTakedown and not hasActiveInteraction and isPlayerInStealth == 1 and not isSpottingPlayer then
                FixerCore.VIInteract:Add(takedownInteractionId, {
                    entity = enemyData.ped,
                    distance = 2.0,
                    interactions = {
                        {
                            key = "F",
                            label = "Stealth Takedown",
                            action = function()
                                FixerCore.StealthTakedown:ExecuteTakedown(enemyData.ped, enemyId)
                            end,
                        }
                    },
                    onExit = function()
                        FixerCore.VIInteract:Remove(takedownInteractionId)
                        hasActiveInteraction = false
                    end
                })
                hasActiveInteraction = true
            elseif (not canTakedown or isPlayerInStealth ~= 1 or isSpottingPlayer) and hasActiveInteraction then
                FixerCore.VIInteract:Remove(takedownInteractionId)
                hasActiveInteraction = false
            end
        elseif hasActiveInteraction then
            FixerCore.VIInteract:Remove(takedownInteractionId)
            hasActiveInteraction = false
            goto continue
        end
        
        if not enemyData.isAlerted and IsPedInCombat(enemyData.ped, playerPed) then
            SetBlockingOfNonTemporaryEvents(enemyData.ped, true)
            SetPedCombatAttributes(enemyData.ped, 46, false)
            if distance <= enemyData.detectionRange then
                EnemyAI:HandlePlayerDetection(enemyId, playerPed)
            end
        end
        
        if enemyData.detectionBlip and DoesBlipExist(enemyData.detectionBlip) then
            SetBlipCoords(enemyData.detectionBlip, enemyPos.x, enemyPos.y, enemyPos.z)
            SetBlipRotation(enemyData.detectionBlip, math.floor(GetEntityHeading(enemyData.ped)))
        end
        
        if not enemyData.isAlerted and distance <= enemyData.detectionRange then
            local canSeePlayer = false
            local fieldOfView = math.min(enemyData.fieldOfView or 90.0, 120.0)
            local peripheralFOV = 160.0
            
            if math.abs(angleToPlayer) > (fieldOfView / 2) then
                local behindDetectionRange = 4.0
                local crouchDetectionRange = 1.0
                
                if isPlayerInStealth == 1 then
                    if playerSpeed > 2.0 and distance < crouchDetectionRange then
                        canSeePlayer = true
                    elseif playerSpeed > 1.5 and distance < (crouchDetectionRange * 0.7) then
                        canSeePlayer = true
                    end
                else
                    if playerSpeed > 2.5 and distance < behindDetectionRange then
                        canSeePlayer = true
                    elseif playerSpeed > 1.0 and distance < (behindDetectionRange * 0.6) then
                        canSeePlayer = true
                    elseif playerSpeed > 0.1 and distance < 1.5 then
                        canSeePlayer = true
                    end
                end
            end
            
            if not canSeePlayer and hasClearLOS then
                local isInMainFOV = math.abs(angleToPlayer) <= (fieldOfView / 2)
                local isInPeripheralFOV = math.abs(angleToPlayer) <= (peripheralFOV / 2)
                local timeMultiplier = spottingWait / 1000.0

                if isInMainFOV or isInPeripheralFOV then
                    local maxDist = enemyData.detectionRange
                    local usedFOV = isInMainFOV and fieldOfView or peripheralFOV
                    
                    local distanceFactor = math.max(0.0, 1.0 - math.pow(distance / maxDist, 1.5))
                    
                    local angleFactor = math.max(0.0, 1.0 - math.pow(math.abs(angleToPlayer) / (usedFOV / 2), 2.0))
                    
                    if not isInMainFOV then
                        angleFactor = angleFactor * 0.3 
                    end
                    
                    local detectionProbability = distanceFactor * angleFactor
                    
                    if playerSpeed > 4.0 then
                        detectionProbability = detectionProbability * 2.5
                    elseif playerSpeed > 2.0 then
                        detectionProbability = detectionProbability * 1.8
                    elseif playerSpeed > 1.0 then
                        detectionProbability = detectionProbability * 1.3
                    elseif playerSpeed > 0.5 then
                        detectionProbability = detectionProbability * 1.0
                    else
                        detectionProbability = detectionProbability * 0.7
                    end
                    
                    if isPlayerInStealth == 1 then
                        detectionProbability = detectionProbability * 0.25
                    end
                    
                    if distance > (maxDist * 0.7) then
                        detectionProbability = detectionProbability * 0.6
                    end
                    
                    detectionScore = detectionScore + (detectionProbability * timeMultiplier)
                    
                    if not isInMainFOV or distance > (maxDist * 0.8) then
                        detectionScore = math.max(detectionScore - (1.0 * timeMultiplier), 0.0)
                    end
                    
                    if detectionScore >= 0.8 then
                        isSpottingPlayer = true
                        if not IsEntityDead(enemyData.ped) then
                            canSeePlayer = true
                        end
                    end
                else
                    detectionScore = math.max(detectionScore - (1.5 * (spottingWait / 1000.0)), 0.0)
                end
            else
                detectionScore = math.max(detectionScore - (1.0 * (spottingWait / 1000.0)), 0.0)
            end
            
            if canSeePlayer then
                EnemyAI:HandlePlayerDetection(enemyId, playerPed)
            else
                isSpottingPlayer = false
            end
        else
            detectionScore = 0.0
            isSpottingPlayer = false
        end
        
        ::continue::
        spottingWait = isSpottingPlayer and 100 or 500
        Citizen.Wait(spottingWait)
    end
    
    FixerCore.Blips:Remove("enemy_vision_cone_" .. enemyId)
    FixerCore.Blips:Remove("enemy_" .. enemyId)

    if hasActiveInteraction then
        FixerCore.VIInteract:Remove(takedownInteractionId)
    end

    EnemyAI:CleanupEnemy(enemyId)
end

function EnemyAI:SpawnEnemy(pedModel, position, heading, options)
    options = options or {}
    local pedHash = type(pedModel) == "string" and GetHashKey(pedModel) or pedModel
    
    if not HasModelLoaded(pedHash) then
        RequestModel(pedHash)
        local timeout = GetGameTimer() + 5000
        while not HasModelLoaded(pedHash) and GetGameTimer() < timeout do
            Wait(50)
        end
        if not HasModelLoaded(pedHash) then
            return nil
        end
    end
    
    local ped = CreatePed(4, pedHash, position.x, position.y, position.z, heading, true, false)
    if not DoesEntityExist(ped) then
        return nil
    end
    
    local groupName = options.group or "ENEMY_AI_GROUP"
    
    if not options.sharedRelationshipGroup then
        AddRelationshipGroup(groupName)
    end
    
    local relGroupHash = GetHashKey(groupName)
    SetPedRelationshipGroupHash(ped, relGroupHash)
    
    if not options.sharedRelationshipGroup then
        SetRelationshipBetweenGroups(5, relGroupHash, GetHashKey("PLAYER"))
        SetRelationshipBetweenGroups(5, GetHashKey("PLAYER"), relGroupHash)
        SetRelationshipBetweenGroups(1, relGroupHash, relGroupHash)
    end
    
    SetPedFleeAttributes(ped, 0, false)
    
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCombatAttributes(ped, 46, false)
    SetPedCombatAttributes(ped, 5, true)
    
    SetEntityAsMissionEntity(ped, true, true)
    
    local weapon = options.weapon or "WEAPON_PISTOL"
    local accuracy = options.accuracy or EnemyAI.defaultAccuracy
    
    GiveWeaponToPed(ped, GetHashKey(weapon), 999999, false, true)
    SetPedAccuracy(ped, accuracy)
    SetPedCombatAbility(ped, options.combatAbility or 2)
    SetPedAmmo(ped, GetHashKey(weapon), 999999)

    local enemyId = EnemyAI.nextId
    EnemyAI.nextId = EnemyAI.nextId + 1
    
    local enemyData = {
        id = enemyId,
        ped = ped,
        group = options.group,
        sharedRelationshipGroup = options.sharedRelationshipGroup,
        spawnPosition = vector3(position.x, position.y, position.z),
        detectionRange = options.detectionRange or EnemyAI.defaultDetectionRange,
        fieldOfView = options.fieldOfView or EnemyAI.defaultFieldOfView,
        alertOthers = (options.alertOthers ~= false),
        isAlerted = false,
        canUseStealth = options.canUseStealth or false,
        onSpotted = options.onSpotted,
        onDeath = options.onDeath,
        useSoundEffect = options.useSoundEffect or false,
        detectionBlip = nil,
        patrol = nil
    }
    
    if options.patrol then
        local patrol = {
            type = options.patrol.type or EnemyAI.patrolTypes.NONE,
            usedScenarios = {},
            minWaitTime = options.patrol.minWaitTime or 5000,
            maxWaitTime = options.patrol.maxWaitTime or 15000,
        }
        
        if patrol.type == EnemyAI.patrolTypes.STATIONARY then
            patrol.nextScenarioTime = GetGameTimer() + 1000
            patrol.currentScenario = nil
        elseif patrol.type == EnemyAI.patrolTypes.ROAMING then
            local patrolRadius = options.patrol.radius or 20.0
            local numPoints = options.patrol.numPoints or 4
            local avoidPositions = options.patrol.avoidPositions or {}
            
            patrol.points = EnemyAI:GeneratePatrolPoints(vector3(position.x, position.y, position.z), patrolRadius, numPoints, avoidPositions)
            patrol.currentPointIndex = 0
            patrol.isMoving = false
            patrol.nextMoveTime = GetGameTimer() + 1000
            patrol.useScenarios = options.patrol.useScenarios ~= false
            
            if patrol.useScenarios and options.patrol.startWithScenario ~= false then
                local selectedScenario = EnemyAI.guardScenarios[math.random(1, #EnemyAI.guardScenarios)]
                patrol.usedScenarios[selectedScenario] = true
                TaskStartScenarioAtPosition(ped, selectedScenario, position.x, position.y, position.z, heading, 0, true, false)
            end
        end
        
        enemyData.patrol = patrol
    end
    
    if options.group then
        if not EnemyAI.groups[options.group] then
            EnemyAI.groups[options.group] = {}
        end
        table.insert(EnemyAI.groups[options.group], enemyId)
    end
    
    EnemyAI.active[enemyId] = enemyData

    Citizen.CreateThread(function()
        Wait(100)
        EnemyAI:ProcessEnemyBehavior(enemyId)
    end)
    
    return ped, enemyId
end

function EnemyAI:SpawnEnemyGroup(config)
    if not config or not config.positions or #config.positions == 0 then
        return nil
    end
    
    local groupName = config.groupName or "group_" .. tostring(math.random(1000, 9999))
    local spawnedEnemies = {}
    local allSpawnPositions = {}
    
    for _, posData in ipairs(config.positions) do
        table.insert(allSpawnPositions, posData.pos)
    end
    
    for i, posData in ipairs(config.positions) do
        local pedModel = config.pedModels and config.pedModels[math.random(1, #config.pedModels)] or "s_m_y_blackops_01"
        local weapon = config.weapons and config.weapons[math.random(1, #config.weapons)] or "WEAPON_PISTOL"
        
        local enemyOptions = {
            group = groupName,
            weapon = weapon,
            accuracy = config.accuracy,
            alertOthers = config.alertOthers ~= false,
            detectionRange = config.detectionRange,
            fieldOfView = config.fieldOfView,
            onSpotted = config.onSpotted,
            onDeath = config.onDeath,
            useSoundEffect = config.useSoundEffect,
            canUseStealth = config.canUseStealth or false,
        }
        
        if config.patrol then
            enemyOptions.patrol = {
                type = config.patrol.type or EnemyAI.patrolTypes.NONE,
                minWaitTime = config.patrol.minWaitTime or 5000,
                maxWaitTime = config.patrol.maxWaitTime or 15000,
                radius = config.patrol.radius or 20.0,
                numPoints = config.patrol.numPoints or 4,
                useScenarios = config.patrol.useScenarios ~= false,
                avoidPositions = allSpawnPositions
            }
        end
        
        local ped, enemyId = EnemyAI:SpawnEnemy(pedModel, posData.pos, posData.pos.w or 0.0, enemyOptions)
        
        if ped and enemyId then
            table.insert(spawnedEnemies, enemyId)
        end
    end
    
    return groupName, spawnedEnemies
end

function EnemyAI:SpawnMultipleGroups(configs)
    if not configs or #configs == 0 then
        return nil
    end
    
    local sharedGroupName = configs.sharedGroupName or "shared_group_" .. tostring(math.random(1000, 9999))
    local allSpawnedEnemies = {}
    local groupResults = {}
    local allSpawnPositions = {}
    
    for _, config in ipairs(configs) do
        if config.positions then
            for _, posData in ipairs(config.positions) do
                table.insert(allSpawnPositions, posData.pos)
            end
        end
    end
    
    AddRelationshipGroup(sharedGroupName)
    local sharedRelGroupHash = GetHashKey(sharedGroupName)
    SetRelationshipBetweenGroups(5, sharedRelGroupHash, GetHashKey("PLAYER"))
    SetRelationshipBetweenGroups(5, GetHashKey("PLAYER"), sharedRelGroupHash)
    SetRelationshipBetweenGroups(1, sharedRelGroupHash, sharedRelGroupHash)
    
    for _, config in ipairs(configs) do
        if config.positions and #config.positions > 0 then
            local groupName = config.groupName or "group_" .. tostring(math.random(1000, 9999))
            local spawnedEnemies = {}
            
            for i, posData in ipairs(config.positions) do
                local pedModel = config.pedModels and config.pedModels[math.random(1, #config.pedModels)] or "s_m_y_blackops_01"
                local weapon = config.weapons and config.weapons[math.random(1, #config.weapons)] or "WEAPON_PISTOL"
                
                local enemyOptions = {
                    group = sharedGroupName,
                    weapon = weapon,
                    accuracy = config.accuracy,
                    alertOthers = config.alertOthers ~= false,
                    detectionRange = config.detectionRange,
                    fieldOfView = config.fieldOfView,
                    onSpotted = config.onSpotted,
                    onDeath = config.onDeath,
                    useSoundEffect = config.useSoundEffect,
                    canUseStealth = config.canUseStealth or false,
                    sharedRelationshipGroup = sharedGroupName,
                }
                
                if config.patrol then
                    enemyOptions.patrol = {
                        type = config.patrol.type or EnemyAI.patrolTypes.NONE,
                        minWaitTime = config.patrol.minWaitTime or 5000,
                        maxWaitTime = config.patrol.maxWaitTime or 15000,
                        radius = config.patrol.radius or 20.0,
                        numPoints = config.patrol.numPoints or 4,
                        useScenarios = config.patrol.useScenarios ~= false,
                        avoidPositions = allSpawnPositions
                    }
                end
                
                local ped, enemyId = EnemyAI:SpawnEnemy(pedModel, posData.pos, posData.pos.w or 0.0, enemyOptions)
                
                if ped and enemyId then
                    table.insert(spawnedEnemies, enemyId)
                    table.insert(allSpawnedEnemies, enemyId)
                end
            end
            
            groupResults[groupName] = spawnedEnemies
        end
    end
    
    return sharedGroupName, allSpawnedEnemies, groupResults
end

--RESET & CLEAN
function EnemyAI:CleanupAll()
    local enemyIds = {}
    for id, _ in pairs(EnemyAI.active) do
        table.insert(enemyIds, id)
    end
    
    for _, id in ipairs(enemyIds) do
        EnemyAI:RemoveEnemy(id)
    end
    
    EnemyAI.groups = {}
end

function EnemyAI:CleanupEnemy(enemyId)
    local enemyData = EnemyAI.active[enemyId]
    if not enemyData then return end
    
    FixerCore.Blips:Remove("enemy_vision_cone_" .. enemyId)
    FixerCore.Blips:Remove("enemy_" .. enemyId)
    
    if DoesEntityExist(enemyData.ped) then
        DeleteEntity(enemyData.ped)
    end
    
    if enemyData.group and EnemyAI.groups[enemyData.group] then
        for i, id in ipairs(EnemyAI.groups[enemyData.group]) do
            if id == enemyId then
                table.remove(EnemyAI.groups[enemyData.group], i)
                break
            end
        end
    end
    
    EnemyAI.active[enemyId] = nil
end

function EnemyAI:RemoveEnemy(enemyId)
    local enemyData = EnemyAI.active[enemyId]
    if not enemyData then return false end
    
    if DoesEntityExist(enemyData.ped) then
        SetEntityAsNoLongerNeeded(enemyData.ped)
        if IsPedInAnyVehicle(enemyData.ped, false) then
            local vehicle = GetVehiclePedIsIn(enemyData.ped, false)
            SetEntityAsNoLongerNeeded(vehicle)
        end
        DeletePed(enemyData.ped)
    end
    
    EnemyAI:CleanupEnemy(enemyId)
    return true
end

--UTILS
function EnemyAI:AreAllEnemiesDead(currentEnemyId)
    if not EnemyAI.active or next(EnemyAI.active) == nil then
        return true
    end
    
    for enemyId, enemyData in pairs(EnemyAI.active) do
        if enemyId ~= currentEnemyId then
            if not IsEntityDead(enemyData.ped) and not enemyData.isDead then
                return false
            end
        end
    end
    
    return true
end

function EnemyAI:HandlePlayerDetection(enemyId, targetPed)
    local enemyData = EnemyAI.active[enemyId]
    if not enemyData or enemyData.isAlerted then return end
    
    ClearPedTasksImmediately(enemyData.ped)
    enemyData.isAlerted = true
    
    if enemyData.onSpotted then
        enemyData.onSpotted()
    end

    if enemyData.useSoundEffect then
        FixerCore.Audio:PlaySound("se_player_spotted.mp3", {
            volume = 0.3,
            autoRemove = true,
        })
    end

    if FixerCore.Blips:Exists("enemy_vision_cone_" .. enemyId) then
        FixerCore.Blips:Remove("enemy_vision_cone_" .. enemyId)
    end
    
    if enemyData.alertOthers then
        local groupToAlert = enemyData.sharedRelationshipGroup or enemyData.group
        if groupToAlert then
            for otherId, otherData in pairs(EnemyAI.active) do
                if otherId ~= enemyId and 
                   (otherData.group == groupToAlert or otherData.sharedRelationshipGroup == groupToAlert) and
                   not otherData.isAlerted and not IsEntityDead(otherData.ped) then
                    
                    otherData.isAlerted = true
                    SetBlockingOfNonTemporaryEvents(otherData.ped, false)
                    SetPedCombatAttributes(otherData.ped, 46, true)
                    TaskCombatPed(otherData.ped, targetPed, 0, 16)
                    
                    if not FixerCore.Blips:Exists("enemy_" .. otherId) then
                        FixerCore.Blips:Add("enemy_" .. otherId, {
                            entity = otherData.ped,
                            sprite = 1,
                            color = 1,
                            scale = 0.8,
                            name = "Alerted Enemy"
                        })
                    end

                    if FixerCore.Blips:Exists("enemy_vision_cone_" .. otherId) then
                        FixerCore.Blips:Remove("enemy_vision_cone_" .. otherId)
                    end
                    
                    if otherData.onSpotted then
                        otherData.onSpotted()
                    end
                end
            end
        end
    end
    
    SetBlockingOfNonTemporaryEvents(enemyData.ped, false)
    SetPedCombatAttributes(enemyData.ped, 46, true)
    TaskCombatPed(enemyData.ped, targetPed, 0, 16)
    
    if not FixerCore.Blips:Exists("enemy_" .. enemyId) then
        FixerCore.Blips:Add("enemy_" .. enemyId, {
            entity = enemyData.ped,
            sprite = 1,
            color = 1,
            scale = 0.8,
            name = "Alerted Enemy"
        })
    end
end

function EnemyAI:GetAngleBetweenEntities(entity1, entity2)
    local pos1 = GetEntityCoords(entity1)
    local pos2 = GetEntityCoords(entity2)
    
    local heading = GetEntityHeading(entity1)
    local headingRad = math.rad(heading)
    
    local forwardX = math.sin(-headingRad)
    local forwardY = math.cos(-headingRad)
    local forward = vector3(forwardX, forwardY, 0.0)
    
    local direction = vector3(pos2.x - pos1.x, pos2.y - pos1.y, 0.0)
    local length = math.sqrt(direction.x^2 + direction.y^2)
    
    if length <= 0.001 then
        return 0.0
    end
    
    direction = vector3(direction.x / length, direction.y / length, 0.0)
    
    local dot = forward.x * direction.x + forward.y * direction.y
    local angle = math.deg(math.acos(math.min(math.max(dot, -1.0), 1.0)))
    
    local cross = forward.x * direction.y - forward.y * direction.x
    if cross < 0 then
        angle = -angle
    end
    
    return angle
end

--PATROL
function EnemyAI:GeneratePatrolPoints(centerPos, radius, numPoints, avoidPositions)
    local points = {}
    avoidPositions = avoidPositions or {}
    local minDistance = math.max(3.0, radius * 0.3)
    
    for i = 1, numPoints do
        local attempts = 0
        local validPoint = false
        
        while not validPoint and attempts < 50 do
            local angle = (2 * math.pi * i / numPoints) + math.random(-30, 30) * (math.pi / 180)
            local distance = radius * 0.5 + math.random() * (radius * 0.5)
            
            local x = centerPos.x + math.cos(angle) * distance
            local y = centerPos.y + math.sin(angle) * distance
            local z = centerPos.z
            
            local groundFound, groundZ = GetGroundZFor_3dCoord(x, y, z + 10.0, false)
            if groundFound then
                z = groundZ
            end
            
            local newPoint = vector3(x, y, z)
            
            validPoint = true
            
            for _, existingPoint in ipairs(points) do
                if #(newPoint - existingPoint) < minDistance then
                    validPoint = false
                    break
                end
            end
            
            if validPoint then
                for _, avoidPos in ipairs(avoidPositions) do
                    local dist = #(vector3(newPoint.x, newPoint.y, newPoint.z) - vector3(avoidPos.x, avoidPos.y, avoidPos.z))
                    if dist < minDistance then
                        validPoint = false
                        break
                    end
                end
            end
            
            if validPoint then
                table.insert(points, newPoint)
            end
            
            attempts = attempts + 1
        end
        
        if #points < i then
            local angle = 2 * math.pi * i / numPoints
            local x = centerPos.x + math.cos(angle) * radius * 0.8
            local y = centerPos.y + math.sin(angle) * radius * 0.8
            local groundFound, groundZ = GetGroundZFor_3dCoord(x, y, centerPos.z + 10.0, false)
            local z = groundFound and groundZ or centerPos.z
            table.insert(points, vector3(x, y, z))
        end
    end
    
    return points
end

function EnemyAI:ProcessStationaryPatrol(enemyData)
    local patrol = enemyData.patrol
    
    if GetGameTimer() >= patrol.nextScenarioTime then
        if patrol.currentScenario then
            ClearPedTasks(enemyData.ped)
            patrol.currentScenario = nil
        end
        
        local availableScenarios = {}
        for i, scenario in ipairs(EnemyAI.guardScenarios) do
            if not patrol.usedScenarios[scenario] then
                table.insert(availableScenarios, scenario)
            end
        end
        
        if #availableScenarios == 0 then
            patrol.usedScenarios = {}
            availableScenarios = EnemyAI.guardScenarios
        end
        
        local selectedScenario = availableScenarios[math.random(1, #availableScenarios)]
        patrol.usedScenarios[selectedScenario] = true
        patrol.currentScenario = selectedScenario
        
        local pos = GetEntityCoords(enemyData.ped)
        local heading = GetEntityHeading(enemyData.ped)
        TaskStartScenarioAtPosition(enemyData.ped, selectedScenario, pos.x, pos.y, pos.z, heading, 0, true, false)
        
        patrol.nextScenarioTime = GetGameTimer() + math.random(patrol.minWaitTime, patrol.maxWaitTime)
    end
end

function EnemyAI:ProcessRoamingPatrol(enemyData)
    local patrol = enemyData.patrol
    local currentTime = GetGameTimer()
    
    if not patrol.isMoving and currentTime >= patrol.nextMoveTime then
        patrol.currentPointIndex = patrol.currentPointIndex % #patrol.points + 1
        local targetPoint = patrol.points[patrol.currentPointIndex]
        
        ClearPedTasks(enemyData.ped)

        TaskGoToCoordAnyMeans(enemyData.ped, targetPoint.x, targetPoint.y, targetPoint.z, 1.0, 0, false, 786603, 0)
        patrol.isMoving = true
        patrol.moveStartTime = currentTime
    elseif patrol.isMoving then
        local targetPoint = patrol.points[patrol.currentPointIndex]
        local currentPos = GetEntityCoords(enemyData.ped)
        local distance = #(currentPos - targetPoint)
        
        if distance < 2.0 or (currentTime - patrol.moveStartTime) > 30000 then
            patrol.isMoving = false
            
            if patrol.useScenarios then
                local availableScenarios = {}
                for i, scenario in ipairs(EnemyAI.guardScenarios) do
                    if not patrol.usedScenarios[scenario] then
                        table.insert(availableScenarios, scenario)
                    end
                end
                
                if #availableScenarios == 0 then
                    patrol.usedScenarios = {}
                    availableScenarios = EnemyAI.guardScenarios
                end
                
                local selectedScenario = availableScenarios[math.random(1, #availableScenarios)]
                patrol.usedScenarios[selectedScenario] = true
                
                local pos = GetEntityCoords(enemyData.ped)
                local heading = GetEntityHeading(enemyData.ped)
                TaskStartScenarioAtPosition(enemyData.ped, selectedScenario, pos.x, pos.y, pos.z, heading, 0, true, false)
            end
            
            patrol.nextMoveTime = currentTime + math.random(patrol.minWaitTime, patrol.maxWaitTime)
        end
    end
end

FixerCore.EnemyAI = EnemyAI