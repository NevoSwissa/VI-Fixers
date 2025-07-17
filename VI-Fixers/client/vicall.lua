local FixerCore = _G.FixerCore

local VICall = {
    active = false,
    currentCallId = nil,
    awaitingResponse = false,
    responseTimeout = nil,
    callSoundEffectId = nil,
}

function VICall:StartCall(fileName, callerName, options)
    if VICall.active then
        VICall:EndCall()
    end
    
    callSoundEffectId = nil
    options = options or {}
    callerName = callerName or "UNKNOWN CALLER"
    local timeoutMs = options.timeout or 5000
    
    VICall.active = true
    VICall.awaitingResponse = true
    
    SendNUIMessage({
        type = 'vicall-show-incoming',
        caller = callerName,
        timeout = math.floor(timeoutMs / 1000)
    })

    if options.useSoundEffect then
        callSoundEffectId = FixerCore.Audio:PlaySound("se_call.mp3", {
            volume = 0.1,
            autoRemove = true,
        })
    end
    
    VICall:StartResponseLoop()

    VICall.pendingCallData = {
        fileName = fileName,
        callerName = callerName,
        options = options or {},
    }

    VICall.responseTimeout = Citizen.SetTimeout(timeoutMs, function()
        if VICall.awaitingResponse then
            VICall:HandleCallResponse(false)
        end
    end)
    
    return true
end

function VICall:StartCall3D(fileName, coords, callerName, options)
    if VICall.active then
        VICall:EndCall()
    end
    
    callSoundEffectId = nil
    options = options or {}
    callerName = callerName or "UNKNOWN CALLER"
    local timeoutMs = options.timeout or 5000
    
    VICall.active = true
    VICall.awaitingResponse = true
    
    SendNUIMessage({
        type = 'vicall-show-incoming',
        caller = callerName,
        coords = coords,
        options = options,
        timeout = math.floor(timeoutMs / 1000)
    })
    
    if options.useSoundEffect then
        callSoundEffectId = FixerCore.Audio:PlaySound("se_call.mp3", {
            volume = 0.1,
            autoRemove = true,
        })
    end

    VICall:StartResponseLoop()

    VICall.pendingCallData = {
        fileName = fileName,
        callerName = callerName,
        options = options or {},
        coords = coords
    }

    VICall.responseTimeout = Citizen.SetTimeout(timeoutMs, function()
        if VICall.awaitingResponse then
            VICall:HandleCallResponse(false)
        end
    end)
    
    return true
end

function VICall:StartResponseLoop()
    Citizen.CreateThread(function()
        while VICall.awaitingResponse do
            Citizen.Wait(0)
            
            if IsControlJustPressed(0, 38) then
                VICall:HandleCallResponse(true)
                break
            end
            
            if IsControlJustPressed(0, 73) then
                VICall:HandleCallResponse(false)
                break
            end
        end
    end)
end

function VICall:HandleCallResponse(accepted)
    if not VICall.awaitingResponse then return end
    
    FixerCore.Audio:Stop(callSoundEffectId)
    VICall.awaitingResponse = false
    
    if VICall.responseTimeout then
        Citizen.ClearTimeout(VICall.responseTimeout)
        VICall.responseTimeout = nil
    end
    
    if accepted then
        VICall:AcceptCall()
    else
        VICall:DeclineCall()
    end
end

function VICall:AcceptCall()
    local callData = VICall.pendingCallData
    if not callData then return end
    
    local audioId
    if callData.coords then
        audioId = FixerCore.Audio:Play3D(callData.fileName, callData.coords, {
            volume = callData.options.volume or 1.0,
            maxDistance = callData.options.maxDistance or 20.0,
            loop = callData.options.loop or false,
            onEnd = function()
                VICall:OnAudioEnd()
            end,
            autoRemove = true
        })
    else
        audioId = FixerCore.Audio:PlaySound(callData.fileName, {
            volume = callData.options.volume or 1.0,
            loop = callData.options.loop or false,
            onEnd = function()
                VICall:OnAudioEnd()
            end,
            autoRemove = true
        })
    end
    
    VICall.currentCallId = audioId
    
    SendNUIMessage({
        type = 'vicall-show',
        caller = callData.callerName,
        fileName = callData.fileName
    })
    
    VICall.pendingCallData = nil
end

function VICall:DeclineCall()
    local callData = VICall.pendingCallData
    
    VICall.active = false
    
    SendNUIMessage({
        type = 'vicall-hide'
    })

    if callData and callData.options and callData.options.declineMessage then
        Wait(1300)
        FixerCore.VILink:ShowLinkMessage({
            sender = callData.options.declineMessage.sender,
            subject = callData.options.declineMessage.subject,
            message = callData.options.declineMessage.message,
            flashScreen = callData.options.declineMessage.flashScreen,
            displayTime = callData.options.declineMessage.displayTime or 8000,
        })
    end

    VICall.pendingCallData = nil
end

function VICall:EndCall()
    if not VICall.active then return end
    
    VICall.awaitingResponse = false
    if VICall.responseTimeout then
        Citizen.ClearTimeout(VICall.responseTimeout)
        VICall.responseTimeout = nil
    end
    
    if VICall.currentCallId then
        FixerCore.Audio:Stop(VICall.currentCallId)
        VICall.currentCallId = nil
    end
    
    VICall.active = false
    VICall.pendingCallData = nil
    
    SendNUIMessage({
        type = 'vicall-hide'
    })
end

function VICall:OnAudioEnd()
    if not VICall.active then return end
    
    VICall.currentCallId = nil
    
    SendNUIMessage({
        type = 'vicall-audio-ended'
    })
    
    Citizen.SetTimeout(2000, function()
        if VICall.active then
            VICall.active = false
            SendNUIMessage({
                type = 'vicall-hide'
            })
        end
    end)
end

FixerCore.VICall = VICall