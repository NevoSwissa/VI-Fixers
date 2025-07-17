local FixerCore = _G.FixerCore

local VFX = {}

VFX.Presets = {
    MessageReceived = function()
        VFX:Play("CamPushInNeutral", 500, false, 400)
    end,
    
    ObjectiveComplete = function()
        VFX:Play("FocusIn", 800, false, 600)
    end,
    
    InteractionStart = function()
        VFX:Play("CamPushInFranklin", 600, false, 500)
    end
}

function VFX:CleanupEntityEffects(sequenceState)
    if sequenceState.activePtfx and DoesParticleFxLoopedExist(sequenceState.activePtfx) then
        StopParticleFxLooped(sequenceState.activePtfx, 0)
        RemoveParticleFx(sequenceState.activePtfx, true)
        sequenceState.activePtfx = nil
    end
    
    if sequenceState.additionalPtfx then
        for _, ptfx in ipairs(sequenceState.additionalPtfx) do
            if DoesParticleFxLoopedExist(ptfx) then
                StopParticleFxLooped(ptfx, 0)
                RemoveParticleFx(ptfx, true)
            end
        end
        sequenceState.additionalPtfx = {}
    end
    
    return true
end

function VFX:HandleVFXApplication(sequenceState, vfxData, entityHandle, isProp, delay)
    if not vfxData or not sequenceState or not DoesEntityExist(entityHandle) then
        return nil
    end

    delay = delay or 0

    local function applyVFX()
        if not sequenceState.isPlaying or not DoesEntityExist(entityHandle) then return end

        local ptfx = isProp
            and VFX:ApplyVFXToProp(
                entityHandle,
                vfxData.dict,
                vfxData.name,
                vfxData.offset,
                vfxData.rotation,
                vfxData.scale
            )
            or VFX:ApplyVFXToPed(
                entityHandle,
                vfxData.dict,
                vfxData.name,
                vfxData.bone,
                vfxData.offset,
                vfxData.rotation,
                vfxData.scale
            )

        if ptfx then
            if vfxData.isMainEffect then
                sequenceState.activePtfx = ptfx
                sequenceState.vfxAttachedToProp = isProp
            else
                table.insert(sequenceState.additionalPtfx, ptfx)
            end
        end
    end

    if delay > 0 then
        CreateThread(function()
            Wait(delay)
            applyVFX()
        end)
    else
        applyVFX()
    end
end

function VFX:ApplyVFXToProp(propHandle, dict, name, offset, rotation, scale)
    if not DoesEntityExist(propHandle) then return end
    
    if not HasNamedPtfxAssetLoaded(dict) then
        RequestNamedPtfxAsset(dict)
        local timeout = GetGameTimer() + 2000
        while not HasNamedPtfxAssetLoaded(dict) and GetGameTimer() < timeout do
            Wait(50)
        end
    end
    
    UseParticleFxAssetNextCall(dict)
    
    local ptfx = StartParticleFxLoopedOnEntity(
        name,
        propHandle,
        offset.x or 0.0,
        offset.y or 0.0,
        offset.z or 0.0,
        rotation.x or 0.0,
        rotation.y or 0.0,
        rotation.z or 0.0,
        scale or 1.0,
        false, false, false
    )
    
    return ptfx
end

function VFX:ApplyVFXToPed(pedHandle, dict, name, boneIndex, offset, rotation, scale)
    if not DoesEntityExist(pedHandle) then return end
    
    if not HasNamedPtfxAssetLoaded(dict) then
        RequestNamedPtfxAsset(dict)
        local timeout = GetGameTimer() + 2000
        while not HasNamedPtfxAssetLoaded(dict) and GetGameTimer() < timeout do
            Wait(50)
        end
    end
    
    UseParticleFxAssetNextCall(dict)
    
    local boneIndex = boneIndex or GetPedBoneIndex(pedHandle, 31086)
    
    local ptfx = StartParticleFxLoopedOnEntityBone(
        name,
        pedHandle,
        offset.x or 0.0,
        offset.y or 0.0,
        offset.z or 0.0,
        rotation.x or 0.0,
        rotation.y or 0.0,
        rotation.z or 0.0,
        boneIndex,
        scale or 1.0,
        false, false, false
    )
    
    return ptfx
end

function VFX:Play(effectName, holdTime, looped, fadeOutDelay)
    if not effectName or type(effectName) ~= "string" then return end

    holdTime = holdTime or 1000
    looped = looped or false
    fadeOutDelay = fadeOutDelay or 500

    AnimpostfxPlay(effectName, 0, looped)

    CreateThread(function()
        Wait(holdTime + fadeOutDelay)
        AnimpostfxStop(effectName)
    end)
end

FixerCore.VFX = VFX