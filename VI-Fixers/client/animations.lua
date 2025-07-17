local FixerCore = _G.FixerCore

local Animations = {}

function Animations:PrepareAnimation(sequenceState, animData)
    if not sequenceState or not DoesEntityExist(sequenceState.ped) or not animData then
        return false
    end
    
    local ped = sequenceState.ped
    
    sequenceState.loadedAnimDicts = sequenceState.loadedAnimDicts or {}
    sequenceState.attachedProps = sequenceState.attachedProps or {}
    sequenceState.additionalPtfx = sequenceState.additionalPtfx or {}
    
    FixerCore.VFX:CleanupEntityEffects(sequenceState)
    FixerCore.Props:CleanupEntityProps(sequenceState)
    
    if animData.Dict then
        if not HasAnimDictLoaded(animData.Dict) then
            RequestAnimDict(animData.Dict)
            local timeout = GetGameTimer() + 5000
            while not HasAnimDictLoaded(animData.Dict) and GetGameTimer() < timeout do
                Wait(50)
            end
        end
        
        sequenceState.loadedAnimDicts[animData.Dict] = true
    end
    
    return true
end

function Animations:PlaySequenceAnimation(sequenceState, stepIndex)
    local ped = sequenceState.ped
    local step = sequenceState.sequence[stepIndex]
    
    if not step or not step.Anim then return end
    
    if not Animations:PrepareAnimation(sequenceState, step.Anim) then
        return
    end
    
    local propEntity = nil
    if step.Anim.Prop then
        propEntity = FixerCore.Props:AttachPropToEntity(sequenceState, step.Anim.Prop)
    end
    
    TaskPlayAnim(
        ped,
        step.Anim.Dict,
        step.Anim.Anim,
        step.Anim.BlendIn or 2.0,
        step.Anim.BlendOut or 2.0,
        step.Anim.Time or -1,
        step.Anim.Flag or 1,
        0.0,
        false, false, false
    )
    
    if step.Anim.VFX then
        step.Anim.VFX.isMainEffect = true
        
        if step.Anim.VFX.attachToProp and propEntity then
            FixerCore.VFX:HandleVFXApplication(
                sequenceState,
                step.Anim.VFX,
                propEntity,
                true,
                step.Anim.VFX.delay
            )
        else
            FixerCore.VFX:HandleVFXApplication(
                sequenceState,
                step.Anim.VFX,
                ped,
                false,
                step.Anim.VFX.delay
            )
        end
    end
    
    if step.Anim.VFX and step.Anim.VFX.secondaryVFX then
        step.Anim.VFX.secondaryVFX.isMainEffect = false
        
        local targetEntity = step.Anim.VFX.secondaryVFX.attachToProp and propEntity or ped
        local isProp = step.Anim.VFX.secondaryVFX.attachToProp and true or false
        local delay = step.Anim.VFX.secondaryVFX.triggerAt or 0
        
        FixerCore.VFX:HandleVFXApplication(
            sequenceState,
            step.Anim.VFX.secondaryVFX,
            targetEntity,
            isProp,
            delay
        )
    end
end

function Animations:PlayLoopAnimation(sequenceState, animData)
    if not sequenceState or not DoesEntityExist(sequenceState.ped) then return end
    
    local ped = sequenceState.ped
    
    if not Animations:PrepareAnimation(sequenceState, animData) then
        return
    end
    
    local propEntity = nil
    if animData.Prop then
        propEntity = FixerCore.Props:AttachPropToEntity(sequenceState, animData.Prop)
    end
    
    local flag = 49
    TaskPlayAnim(
        ped, 
        animData.Dict, 
        animData.Anim, 
        animData.BlendIn or 3.0, 
        animData.BlendOut or 3.0, 
        -1,
        flag,
        0,
        false, false, false
    )
    
    if animData.VFX then
        animData.VFX.isMainEffect = true
        
        if animData.VFX.attachToProp and propEntity then
            FixerCore.VFX:HandleVFXApplication(
                sequenceState,
                animData.VFX,
                propEntity,
                true,
                animData.VFX.delay or 0
            )
        else
            FixerCore.VFX:HandleVFXApplication(
                sequenceState,
                animData.VFX,
                ped,
                false,
                animData.VFX.delay or 0
            )
        end
    end
    
    if animData.VFX and animData.VFX.secondaryVFX then
        animData.VFX.secondaryVFX.isMainEffect = false
        
        local targetEntity = animData.VFX.secondaryVFX.attachToProp and propEntity or ped
        local isProp = animData.VFX.secondaryVFX.attachToProp and true or false
        local delay = animData.VFX.secondaryVFX.triggerAt or 0
        
        FixerCore.VFX:HandleVFXApplication(
            sequenceState,
            animData.VFX.secondaryVFX,
            targetEntity,
            isProp,
            delay
        )
    end
end

FixerCore.Animations = Animations