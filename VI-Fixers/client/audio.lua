local FixerCore = _G.FixerCore

local Audio = {
    active = {},
    nextId = 1, 
    masterVolume = 0.8,
    falloffMultiplier = 1.2,
    activeFacialAnimations = {},
}

function Audio:Init()
    RegisterNUICallback('audioEnded', function(data, cb)
        local audioId = data.id
        if Audio.active[audioId] then
            Audio.active[audioId].isPlaying = false
            Audio.active[audioId].currentTime = 0
            if Audio.active[audioId].onEnd then
                Audio.active[audioId].onEnd()
            end
            
            if Audio.active[audioId].autoRemove then
                Audio.active[audioId] = nil
            end
        end
        cb({})
    end)
    
    RegisterNUICallback('audioPosUpdate', function(data, cb)
        local audioId = data.id
        local position = data.position
        
        if Audio.active[audioId] then
            Audio.active[audioId].currentTime = position
        end
        cb({})
    end)
    
    CreateThread(function()
        while true do
            local playerPed = PlayerPedId()
            local playerPos = GetEntityCoords(playerPed)
            local anyActive = false
            local isCloseToSound = false
    
            for id, data in pairs(Audio.active) do
                if data.coords and data.maxDistance and data.isPlaying then
                    anyActive = true
    
                    local distance = FixerCore.Distance:CalculateDistance(playerPos, data.coords)
                    local volume = 0.0
    
                    if distance < data.maxDistance then
                        local factor = 1.0 - (distance / data.maxDistance)
                        factor = factor ^ 3
    
                        volume = math.max(0.0, factor)
                        volume = volume * Audio.falloffMultiplier
                        volume = volume * data.volume
                        volume = volume * Audio.masterVolume
    
                        if distance < (data.maxDistance * 0.3) then
                            isCloseToSound = true
                        end
                    end
    
                    SendNUIMessage({
                        type = 'setVolume',
                        id = id,
                        volume = volume
                    })
                end
            end
    
            if anyActive then
                Wait(isCloseToSound and 50 or 100)
            else
                Wait(1000)
            end
        end
    end)
    
    CreateThread(function()
        while true do
            Wait(10000)
            
            local currentTime = GetGameTimer()
            for id, data in pairs(Audio.active) do
                if data.lastActive and not data.isPlaying then
                    if (currentTime - data.lastActive) > 300000 then
                        Audio:Stop(id)
                        Audio.active[id] = nil
                    end
                end
            end
        end
    end)
    
    return Audio
end

function Audio:PlaySound(fileName, options)
    options = options or {}
    
    local id = Audio.nextId
    Audio.nextId = Audio.nextId + 1
    
    Audio.active[id] = {
        fileName = fileName,
        volume = options.volume or 1.0,
        isPlaying = true,
        currentTime = options.startTime or 0,
        lastActive = GetGameTimer(),
        onEnd = options.onEnd,
        autoRemove = options.autoRemove or true,
        loop = options.loop or false
    }
    
    SendNUIMessage({
        type = 'playAudio',
        id = id,
        file = fileName,
        volume = options.volume or 1.0,
        loop = options.loop or false,
        startTime = options.startTime or 0,
        subtitle = nil,
        enableSubtitles = false
    })
    
    return id
end

function Audio:Play3D(fileName, coords, options)
    options = options or {}
    
    local id = Audio.nextId
    Audio.nextId = Audio.nextId + 1
    
    local initialVolume = options.volume or 1.0
    if coords then
        local playerPed = PlayerPedId()
        local playerPos = GetEntityCoords(playerPed)
        local distance = FixerCore.Distance:CalculateDistance(playerPos, coords)
        
        if distance < (options.maxDistance or 20.0) then
            local factor = 1.0 - (distance / (options.maxDistance or 20.0))
            factor = factor ^ 3
            
            initialVolume = math.max(0.0, factor)
            initialVolume = initialVolume * Audio.falloffMultiplier
            initialVolume = initialVolume * (options.volume or 1.0)
            initialVolume = initialVolume * Audio.masterVolume
        else
            initialVolume = 0.0
        end
    end
    
    Audio.active[id] = {
        fileName = fileName,
        coords = coords,
        volume = options.volume or 1.0,
        maxDistance = options.maxDistance or 20.0,
        autoRemove = options.autoRemove or false,
        loop = options.loop or false,
        isPlaying = true,
        currentTime = options.startTime or 0,
        lastActive = GetGameTimer(),
        onEnd = options.onEnd
    }
    
    local subtitleData = nil
    if options.subtitle then
        subtitleData = {
            text = options.subtitle,
            speaker = options.subtitleSpeaker,
            duration = options.subtitleDuration
        }
    end
    
    SendNUIMessage({
        type = 'playAudio',
        id = id,
        file = fileName,
        volume = initialVolume,        
        loop = options.loop or false,
        startTime = options.startTime or 0,
        subtitle = subtitleData,
        advancedTalk = false,
        is3D = true,
        initialVolume = initialVolume
    })
    
    return id
end

function Audio:PlayOnEntity(fileName, entity, advancedTalk, options)
    options = options or {}
    if not DoesEntityExist(entity) then
        return nil
    end
    
    local id = Audio.nextId
    Audio.nextId = Audio.nextId + 1
    
    local coords = GetEntityCoords(entity)
    
    local initialVolume = options.volume or 1.0
    if coords then
        local playerPed = PlayerPedId()
        local playerPos = GetEntityCoords(playerPed)
        local distance = FixerCore.Distance:CalculateDistance(playerPos, coords)
        
        if distance < (options.maxDistance or 20.0) then
            local factor = 1.0 - (distance / (options.maxDistance or 20.0))
            factor = factor ^ 3
            
            initialVolume = math.max(0.0, factor)
            initialVolume = initialVolume * Audio.falloffMultiplier
            initialVolume = initialVolume * (options.volume or 1.0)
            initialVolume = initialVolume * Audio.masterVolume
        else
            initialVolume = 0.0
        end
    end
    
    if Audio.activeFacialAnimations and Audio.activeFacialAnimations[entity] then
        local oldAudioId = Audio.activeFacialAnimations[entity].audioId
        if oldAudioId then
            Audio:Stop(oldAudioId)
        end
    end
    
    Audio.active[id] = {
        fileName = fileName,
        entity = entity,
        coords = coords,
        volume = options.volume or 1.0,
        maxDistance = options.maxDistance or 20.0,
        autoRemove = options.autoRemove or false,
        loop = options.loop or false,
        isPlaying = true,
        currentTime = options.startTime or 0,
        lastActive = GetGameTimer(),
        onEnd = options.onEnd
    }
    
    local subtitleData = nil
    if options.subtitle then
        subtitleData = {
            text = options.subtitle,
            speaker = options.subtitleSpeaker,
            duration = options.subtitleDuration
        }
    end
    
    SendNUIMessage({
        type = 'playAudio',
        id = id,
        file = fileName,
        volume = initialVolume,        
        loop = options.loop or false,
        startTime = options.startTime or 0,
        subtitle = subtitleData,
        is3D = true,
        initialVolume = initialVolume
    })
    
    if advancedTalk then
        local animDuration = options.subtitleDuration or 5
        Audio:AnimatePedTalking(entity, animDuration, id)
    end
    
    CreateThread(function()
        while Audio.active[id] and DoesEntityExist(entity) do
            Audio.active[id].coords = GetEntityCoords(entity)
            Wait(100)
        end
        
        if Audio.active[id] and not DoesEntityExist(entity) then
            Audio:Stop(id)
            Audio.active[id] = nil
        end
    end)
    
    return id
end

function Audio:Pause(id)
    if Audio.active[id] and Audio.active[id].isPlaying then
        SendNUIMessage({
            type = 'pauseAudio',
            id = id
        })
        Audio.active[id].isPlaying = false
        Audio.active[id].lastActive = GetGameTimer()
        return true
    end
    return false
end

function Audio:Resume(id)
    if Audio.active[id] and not Audio.active[id].isPlaying then
        SendNUIMessage({
            type = 'resumeAudio',
            id = id,
            startTime = Audio.active[id].currentTime
        })
        Audio.active[id].isPlaying = true
        return true
    end
    return false
end

function Audio:Stop(id)
    if Audio.active[id] then
        if Audio.active[id] and Audio.active[id].entity and Audio.activeFacialAnimations then
            local entity = Audio.active[id].entity
            if Audio.activeFacialAnimations[entity] and Audio.activeFacialAnimations[entity].audioId == id then
                Audio.activeFacialAnimations[entity].active = false
            end
        end
        
        SendNUIMessage({
            type = 'stopAudio',
            id = id
        })
        Audio.active[id] = nil
        return true
    end
    return false
end

function Audio:AnimatePedTalking(ped, duration, audioId)
    if not DoesEntityExist(ped) then return end
    
    if not Audio.activeFacialAnimations then
        Audio.activeFacialAnimations = {}
    end
    
    if Audio.activeFacialAnimations[ped] then
        Audio.activeFacialAnimations[ped].active = false
        Wait(50)
    end
    
    local facialDicts = {
        "mp_facial",
        "facials@gen_male@variations@normal",
        "facials@gen_male@variations@angry"
    }
    
    local talkingAnimations = {
        low = {
            {"facials@gen_male@variations@normal", "mood_talking_normal"},
            {"mp_facial", "mic_chatter"}
        },
        medium = {
            {"facials@gen_male@variations@normal", "talk_facial"},
            {"facials@gen_male@variations@normal", "talk_thinking_facial"},
            {"mp_facial", "mic_chatter"}
        },
        high = {
            {"facials@gen_male@variations@angry", "angry_facial"},
            {"facials@gen_male@variations@normal", "mood_stressed_facial"}
        }
    }
    
    for _, dict in ipairs(facialDicts) do
        if not HasAnimDictLoaded(dict) then
            RequestAnimDict(dict)
            local timeout = GetGameTimer() + 1000
            while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
                Wait(10)
            end
        end
    end
    
    local endTime = GetGameTimer() + (duration * 1000)
    
    local threadData = {
        active = true,
        audioId = audioId
    }
    Audio.activeFacialAnimations[ped] = threadData
    
    CreateThread(function()
        local lastAnim = nil
        local thisThreadData = threadData
        
        while GetGameTimer() < endTime and DoesEntityExist(ped) and thisThreadData.active do
            local intensity = "medium"
            if math.random() > 0.7 then
                intensity = "high"
            elseif math.random() < 0.3 then
                intensity = "low"
            end

            local shouldPause = math.random() > 0.75
            
            if shouldPause then
                PlayFacialAnim(ped, "mood_normal_1", "facials@gen_male@variations@normal")
                
                if math.random() > 0.6 then
                    PlayFacialAnim(ped, "eyebrows_up_facial", "facials@gen_male@variations@normal")
                    Wait(math.random(100, 250))
                    PlayFacialAnim(ped, "mood_normal_1", "facials@gen_male@variations@normal")
                end
                
                Wait(math.random(150, 500))
            else
                local animations = talkingAnimations[intensity]
                
                local animIndex
                repeat
                    animIndex = math.random(1, #animations)
                until animations[animIndex] ~= lastAnim or #animations == 1
                
                lastAnim = animations[animIndex]
                
                PlayFacialAnim(ped, lastAnim[2], lastAnim[1])
                
                if math.random() > 0.85 then
                    Wait(math.random(50, 150))
                    PlayFacialAnim(ped, "mood_normal_1", "facials@gen_male@variations@normal")
                else
                    local waitTime = (intensity == "high") and math.random(150, 250) or 
                                     (intensity == "low") and math.random(250, 450) or 
                                     math.random(200, 350)
                    Wait(waitTime)
                end
            end
        end
        
        if DoesEntityExist(ped) and Audio.activeFacialAnimations[ped] == thisThreadData then
            PlayFacialAnim(ped, "mood_normal_1", "facials@gen_male@variations@normal")
            Audio.activeFacialAnimations[ped] = nil
        end
    end)
    
    return threadData
end

FixerCore.Audio = Audio