local FixerCore = _G.FixerCore

local Sequences = {
    ActiveSequences = {}, 
    ActiveDialogueChoices = {}, 
}

function Sequences:PlaySequenceWith3DAudio(ped, sequence, subtitleSettings, resumeData)
    if not DoesEntityExist(ped) or not sequence then return end
    
    local pedHandle = NetworkGetNetworkIdFromEntity(ped)
    local sequenceState = {
        ped = ped,
        sequence = sequence,
        subtitleSettings = subtitleSettings,
        currentStep = resumeData and resumeData.currentStep or 1,
        currentAudio = resumeData and resumeData.currentAudio or 1,
        isPlaying = true,
        attachedProps = resumeData and resumeData.attachedProps or {},
        lastProp = resumeData and resumeData.lastProp or nil,
        interactionRadius = resumeData and resumeData.interactionRadius or 5.0,
        timeoutDuration = resumeData and resumeData.timeoutDuration or 30000,
        lastActiveTime = GetGameTimer(),
        playerInRange = true,
        trackingAreaName = "seq_tracking_" .. pedHandle,
        activeAudioId = nil,
        activeSubtitleId = nil,
        pauseStartTime = nil,
        stepStartTime = GetGameTimer(),
        pauseTime = nil,
        onInteractionExit = resumeData and resumeData.onInteractionExit or nil,
        branches = resumeData and resumeData.branches or nil,
        waitingForChoice = false,
        activeChoiceId = nil,
        onDialogueChoice = resumeData and resumeData.onDialogueChoice or nil,
        loopAnimActive = false
    }
    
    Sequences.ActiveSequences[pedHandle] = sequenceState
    
    local pedCoords = GetEntityCoords(ped)
    FixerCore.Distance:TrackArea(
        sequenceState.trackingAreaName,
        pedCoords,
        sequenceState.interactionRadius,
        false,
        function()
            sequenceState.playerInRange = true
            sequenceState.lastActiveTime = GetGameTimer()
            if not sequenceState.isPlaying then
                Sequences:ResumeSequence(pedHandle)
            end
        end,
        function()
            sequenceState.playerInRange = false
            
            if sequenceState.isPlaying then
                Sequences:PauseSequence(pedHandle)
                Sequences:StartSequenceMonitor(pedHandle)
            end
        end
    )
    
    if IsPedUsingAnyScenario(ped) or IsPedActiveInScenario(ped) then
        local timeout = GetGameTimer() + 2000
        ClearPedTasks(ped)
        SetPedShouldPlayNormalScenarioExit(ped, true)
        
        while IsPedUsingAnyScenario(ped) and GetGameTimer() < timeout do
            Wait(50)
        end
    end

    if IsEntityPositionFrozen(ped) then
        FreezeEntityPosition(ped, false)
    end

    CreateThread(function()
        local i = sequenceState.currentStep
        while i <= #sequence do
            sequenceState.currentStep = i
            sequenceState.stepStartTime = GetGameTimer()
            
            local step = sequence[i]
            local hasDialogueChoices = step.DialogueChoices ~= nil
            
            if step.Anim then
                FixerCore.Animations:PlaySequenceAnimation(sequenceState, i)
            end

            if step.Condition then
                local conditionMet = false
                if type(step.Condition) == "function" or type(step.Condition) == "table" then
                    conditionMet = step.Condition(sequenceState, step, i)
                elseif type(step.Condition) == "boolean" then
                    conditionMet = step.Condition
                end
                
                if not conditionMet then
                    i = i + 1
                    goto continue_sequence
                end
            end
            
            if step.AudioSubtitles and step.AudioSubtitles.AudiosToPlay then
                local totalAudioDuration = 0
                
                local startAudio = i == sequenceState.currentStep and sequenceState.currentAudio or 1
                
                for audioIndex = startAudio, #step.AudioSubtitles.AudiosToPlay do
                    sequenceState.currentAudio = audioIndex
                    local audioInfo = step.AudioSubtitles.AudiosToPlay[audioIndex]
                    if sequenceState.activeSubtitleId then
                        FixerCore.VISubtitles:Hide(sequenceState.activeSubtitleId)
                        sequenceState.activeSubtitleId = nil
                    end
                    local startTime = 0
                    if resumeData and resumeData.audioProgress and i == resumeData.currentStep and audioIndex == resumeData.currentAudio then
                        startTime = resumeData.audioProgress
                    end
                    
                    sequenceState.activeAudioId = FixerCore.Audio:PlayOnEntity(
                        audioInfo.File,
                        ped,
                        true,
                        {
                            volume = audioInfo.Volume or 0.7,
                            maxDistance = sequenceState.interactionRadius,
                            startTime = startTime,
                            autoRemove = false,
                            subtitle = audioInfo.Subtitle or "No subtitles were found.",
                            subtitleSpeaker = subtitleSettings.Speaker,
                            subtitleDuration = audioInfo.Duration * 1000 or 4000
                        }
                    )
                    
                    local duration = audioInfo.Duration or 4
                    local audioEndTime = GetGameTimer() + (duration * 1000)
                    
                    while GetGameTimer() < audioEndTime and sequenceState.isPlaying do
                        Wait(100)
                    end
                    
                    if not sequenceState.isPlaying then
                        return
                    end
                    
                    if sequenceState.activeAudioId then
                        FixerCore.Audio:Stop(sequenceState.activeAudioId)
                        sequenceState.activeAudioId = nil
                    end
                    
                    totalAudioDuration = totalAudioDuration + duration
                end
                
                sequenceState.currentAudio = 1
                
                if step.Anim and step.Anim.Time and step.Anim.Time > 0 and (step.Anim.Time > totalAudioDuration * 1000) then
                    local remainingTime = step.Anim.Time - (totalAudioDuration * 1000)
                    if remainingTime > 0 then
                        local startTime = GetGameTimer()
                        local endTime = startTime + remainingTime
                        
                        while GetGameTimer() < endTime and sequenceState.isPlaying do
                            Wait(100)
                        end
                        
                        if not sequenceState.isPlaying then return end
                    end
                end
            elseif step.Anim and step.Anim.Time and step.Anim.Time > 0 then
                local startTime = GetGameTimer()
                local endTime = startTime + step.Anim.Time
                
                while GetGameTimer() < endTime and sequenceState.isPlaying do
                    Wait(100)
                end
                
                if not sequenceState.isPlaying then return end
            end
            
            if hasDialogueChoices then
                local idleAnim = nil
                
                if step.Anim then
                    if step.Anim.Flag == -1 or not step.Anim.Time then
                        idleAnim = {
                            Dict = step.Anim.Dict,
                            Anim = step.Anim.Anim,
                            Flag = 49,
                            BlendIn = step.Anim.BlendIn or 3.0,
                            BlendOut = step.Anim.BlendOut or 3.0,
                            Prop = step.Anim.Prop,
                            VFX = step.Anim.VFX
                        }
                    end
                end
                
                if not idleAnim then
                    for j = i, 1, -1 do
                        local prevStep = sequence[j]
                        if prevStep.Anim then
                            local animFlag = prevStep.Anim.Flag or 0
                            if (animFlag & 1) == 1 or
                               (animFlag & 16) == 16 or
                               (animFlag & 32) == 32 or
                               (animFlag & 49) == 49 then
                                idleAnim = {
                                    Dict = prevStep.Anim.Dict,
                                    Anim = prevStep.Anim.Anim,
                                    Flag = 49,
                                    BlendIn = prevStep.Anim.BlendIn or 3.0,
                                    BlendOut = prevStep.Anim.BlendOut or 3.0,
                                    Prop = prevStep.Anim.Prop,
                                    VFX = prevStep.Anim.VFX
                                }
                                break
                            end
                        end
                    end
                    
                    if not idleAnim then
                        idleAnim = {
                            Dict = "amb@world_human_hang_out_street@male_a@idle_a",
                            Anim = "idle_a",
                            Flag = 49,
                            BlendIn = 3.0,
                            BlendOut = 3.0
                        }
                    end
                end
                
                if idleAnim then
                    sequenceState.loopAnimActive = true
                    FixerCore.Animations:PlayLoopAnimation(sequenceState, idleAnim)
                end
                
                local choiceResult = FixerCore.VIDialogue:ShowDialogueChoices(pedHandle, step.DialogueChoices)
                
                sequenceState.waitingForChoice = true
                local chosenBranch = Citizen.Await(choiceResult)
                sequenceState.waitingForChoice = false
                sequenceState.loopAnimActive = false
                
                if not Sequences.ActiveSequences[pedHandle] then
                    return
                end
                
                if chosenBranch and sequenceState.branches and sequenceState.branches[chosenBranch] then
                    sequence = sequenceState.branches[chosenBranch]
                    sequenceState.sequence = sequence
                    i = 1
                    goto continue_sequence
                end
            end
            
            i = i + 1
            
            ::continue_sequence::
        end
        Sequences:CleanupSequence(pedHandle)
    end)
    
    return true
end

function Sequences:StartSequenceMonitor(pedHandle)
    local sequenceState = Sequences.ActiveSequences[pedHandle]
    if not sequenceState then return false end

    sequenceState.pauseStartTime = GetGameTimer()

    CreateThread(function()
        while true do
            Wait(500)

            if sequenceState.isPlaying then return end

            local currentTime = GetGameTimer()
            local timeSincePaused = currentTime - (sequenceState.pauseStartTime or currentTime)

            if timeSincePaused >= sequenceState.timeoutDuration then
                Sequences:CleanupSequence(pedHandle, true)
                return
            end

            if sequenceState.playerInRange then
                Sequences:ResumeSequence(pedHandle)
                return
            end
        end
    end)

    return true
end

function Sequences:ContinueSequenceFromCurrentPoint(pedHandle, elapsedTime)
    local sequenceState = Sequences.ActiveSequences[pedHandle]
    if not sequenceState then return false end
    
    local sequence = sequenceState.sequence
    local currentStep = sequenceState.currentStep
    local currentAudio = sequenceState.currentAudio
    
    if sequenceState.waitingForChoice then
        return
    end
    
    for i = currentStep, #sequence do
        sequenceState.currentStep = i
        sequenceState.stepStartTime = GetGameTimer()
        local step = sequence[i]

        if step.Condition then
            local conditionMet = false
            if type(step.Condition) == "function" or type(step.Condition) == "table" then
                conditionMet = step.Condition(sequenceState, step, i)
            elseif type(step.Condition) == "boolean" then
                conditionMet = step.Condition
            end
            
            if not conditionMet then
                i = i + 1
                goto continue_sequence
            end
        end
        
        if step.Anim and (i > currentStep or elapsedTime < (step.Anim.Time or 0)) then
            local vfxNeedsReapplication = false
            local vfxElapsedTime = elapsedTime
            
            if step.Anim.VFX and step.Anim.VFX.delay and i == currentStep then
                if elapsedTime >= step.Anim.VFX.delay and elapsedTime < step.Anim.Time then
                    vfxNeedsReapplication = true
                    vfxElapsedTime = elapsedTime - step.Anim.VFX.delay
                end
            end
            
            FixerCore.Animations:PlaySequenceAnimation(sequenceState, i)
            
            if vfxNeedsReapplication and step.Anim.VFX then
                Wait(100)
                
                if sequenceState.lastProp and step.Anim.VFX.attachToProp then
                    FixerCore.VFX:ApplyVFXToProp(
                        sequenceState.lastProp,
                        step.Anim.VFX.dict,
                        step.Anim.VFX.name,
                        step.Anim.VFX.offset,
                        step.Anim.VFX.rotation,
                        step.Anim.VFX.scale
                    )
                else
                    FixerCore.VFX:ApplyVFXToPed(
                        sequenceState.ped,
                        step.Anim.VFX.dict,
                        step.Anim.VFX.name,
                        step.Anim.VFX.bone,
                        step.Anim.VFX.offset,
                        step.Anim.VFX.rotation,
                        step.Anim.VFX.scale
                    )
                end
            end
        end
        
        if step.AudioSubtitles and step.AudioSubtitles.AudiosToPlay then
            local audioStartIndex = 1
            local audioProgressTime = 0
            
            if i == currentStep then
                audioStartIndex = currentAudio
                
                if sequenceState.activeAudioId and FixerCore.Audio.active[sequenceState.activeAudioId] then
                    if FixerCore.Audio.active[sequenceState.activeAudioId].currentTime >= 
                       (step.AudioSubtitles.AudiosToPlay[audioStartIndex].Duration or 4) - 0.1 then
                        audioStartIndex = audioStartIndex + 1
                        audioProgressTime = 0
                    else
                        audioProgressTime = FixerCore.Audio.active[sequenceState.activeAudioId].currentTime
                        
                        if not FixerCore.Audio.active[sequenceState.activeAudioId].isPlaying then
                            FixerCore.Audio:Resume(sequenceState.activeAudioId)
                        end
                    end
                end
            end
            
            local totalAudioDuration = 0
            
            for audioIndex = audioStartIndex, #step.AudioSubtitles.AudiosToPlay do
                sequenceState.currentAudio = audioIndex
                local audioInfo = step.AudioSubtitles.AudiosToPlay[audioIndex]
                
                if sequenceState.activeSubtitleId then
                    FixerCore.VISubtitles:Hide(sequenceState.activeSubtitleId)
                    sequenceState.activeSubtitleId = nil
                end
                
                local startTime = 0
                if audioIndex == audioStartIndex and i == currentStep and audioProgressTime > 0 then
                    startTime = audioProgressTime
                    
                    if sequenceState.activeAudioId and FixerCore.Audio.active[sequenceState.activeAudioId] then
                        local remainingDuration = (audioInfo.Duration or 4) - (startTime or 0)
                        if remainingDuration > 0 then
                            local audioEndTime = GetGameTimer() + (remainingDuration * 1000)
                            
                            while GetGameTimer() < audioEndTime and sequenceState.isPlaying do
                                Wait(100)
                            end
                            
                            if not sequenceState.isPlaying then
                                return
                            end
                        end
                        
                        totalAudioDuration = totalAudioDuration + remainingDuration
                        
                        if sequenceState.activeAudioId then
                            FixerCore.Audio:Stop(sequenceState.activeAudioId)
                            sequenceState.activeAudioId = nil
                        end
                        
                        goto continueAudioQueue
                    end
                end
                
                sequenceState.activeAudioId = FixerCore.Audio:PlayOnEntity(
                    audioInfo.File,
                    sequenceState.ped,
                    true,
                    {
                        volume = audioInfo.Volume or 0.7,
                        maxDistance = sequenceState.interactionRadius,
                        startTime = startTime,
                        autoRemove = false,
                        subtitle = audioInfo.Subtitle or "No subtitles were found.",
                        subtitleSpeaker = sequenceState.subtitleSettings.Speaker,
                        subtitleDuration = audioInfo.Duration * 1000 or 4000
                    }
                )
                
                local duration = audioInfo.Duration or 4
                if startTime > 0 then
                    duration = duration - startTime
                end
                
                local audioEndTime = GetGameTimer() + (duration * 1000)
                
                while GetGameTimer() < audioEndTime and sequenceState.isPlaying do
                    Wait(100)
                end
                
                if not sequenceState.isPlaying then
                    return
                end
                
                if sequenceState.activeAudioId then
                    FixerCore.Audio:Stop(sequenceState.activeAudioId)
                    sequenceState.activeAudioId = nil
                end
                
                totalAudioDuration = totalAudioDuration + duration
                
                ::continueAudioQueue::
            end
            
            sequenceState.currentAudio = 1
            
            if step.Anim and step.Anim.Time and (step.Anim.Time > totalAudioDuration * 1000) then
                local remainingTime = step.Anim.Time - (totalAudioDuration * 1000)
                
                if i == currentStep and elapsedTime > 0 then
                    remainingTime = remainingTime - elapsedTime
                end
                
                if remainingTime > 0 then
                    local endTime = GetGameTimer() + remainingTime
                    
                    while GetGameTimer() < endTime and sequenceState.isPlaying do
                        Wait(100)
                    end
                    
                    if not sequenceState.isPlaying then return end
                end
            end
        elseif step.Anim and step.Anim.Time and step.Anim.Time > 0 then
            local animDuration = step.Anim.Time
            
            if i == currentStep and elapsedTime > 0 then
                animDuration = animDuration - elapsedTime
            end
            
            if animDuration > 0 then
                local endTime = GetGameTimer() + animDuration
                
                while GetGameTimer() < endTime and sequenceState.isPlaying do
                    Wait(100)
                end
                
                if not sequenceState.isPlaying then return end
            end
        end
        
        if step.DialogueChoices then
            local idleAnim = nil
            
            if step.LoopAnim then
                idleAnim = step.LoopAnim
            elseif sequenceState.activeLoopAnim then
                idleAnim = sequenceState.activeLoopAnim
            else
                for j = i, 1, -1 do
                    local prevStep = sequence[j]
                    if prevStep.Anim then
                        local animFlag = prevStep.Anim.Flag or 0
                        if (animFlag & 1) == 1 or
                           (animFlag & 16) == 16 or
                           (animFlag & 32) == 32 or
                           (animFlag & 49) == 49 then
                            idleAnim = {
                                Dict = prevStep.Anim.Dict,
                                Anim = prevStep.Anim.Anim,
                                Flag = 49,
                                BlendIn = prevStep.Anim.BlendIn or 3.0,
                                BlendOut = prevStep.Anim.BlendOut or 3.0,
                                Prop = prevStep.Anim.Prop,
                                VFX = prevStep.Anim.VFX
                            }
                            break
                        end
                    end
                end
                
                if not idleAnim then
                    idleAnim = {
                        Dict = "amb@world_human_hang_out_street@male_a@idle_a",
                        Anim = "idle_a",
                        Flag = 49,
                        BlendIn = 3.0,
                        BlendOut = 3.0
                    }
                end
            end
            
            if idleAnim then
                sequenceState.activeLoopAnim = idleAnim
                sequenceState.loopAnimActive = true
                FixerCore.Animations:PlayLoopAnimation(sequenceState, idleAnim)
            end
            
            local choiceResult = FixerCore.VIDialogue:ShowDialogueChoices(pedHandle, step.DialogueChoices)
            
            sequenceState.waitingForChoice = true
            local chosenBranch = Citizen.Await(choiceResult)
            sequenceState.waitingForChoice = false
            sequenceState.loopAnimActive = false
            
            if not Sequences.ActiveSequences[pedHandle] then
                return
            end
            
            if chosenBranch and sequenceState.branches and sequenceState.branches[chosenBranch] then
                sequenceState.sequence = sequenceState.branches[chosenBranch]
                sequenceState.currentStep = 1
                sequenceState.currentAudio = 1
                sequenceState.stepStartTime = GetGameTimer()
                
                return Sequences:ContinueSequenceFromCurrentPoint(pedHandle, 0)
            else
                i = i + 1
            end
        else
            i = i + 1
        end
        
        ::continue_sequence::
    end
    
    Sequences:CleanupSequence(pedHandle)
end

function Sequences:PauseSequence(pedHandle)
    local sequenceState = Sequences.ActiveSequences[pedHandle]
    if not sequenceState then return false end
    
    if sequenceState.isPlaying then
        sequenceState.isPlaying = false
        sequenceState.pauseTime = GetGameTimer()
        sequenceState.pauseStartTime = GetGameTimer()
        
        if sequenceState.activeAudioId then
            if FixerCore.Audio.active[sequenceState.activeAudioId] and 
               FixerCore.Audio.active[sequenceState.activeAudioId].isPlaying then
                FixerCore.Audio:Pause(sequenceState.activeAudioId)
            else
                if FixerCore.Audio.active[sequenceState.activeAudioId] then
                    FixerCore.Audio.active[sequenceState.activeAudioId].isPlaying = false
                end
            end
        end
        
        if sequenceState.waitingForChoice and sequenceState.activeChoiceId then
            local choiceData = Sequences.ActiveDialogueChoices[sequenceState.activeChoiceId]
            if choiceData then
                sequenceState.savedDialogueChoice = {
                    choiceData = table.clone(choiceData),
                    id = sequenceState.activeChoiceId
                }
                
                FixerCore.VIDialogue:HideDialogueChoices(sequenceState.activeChoiceId)
                Sequences.ActiveDialogueChoices[sequenceState.activeChoiceId] = nil
                sequenceState.activeChoiceId = nil
            end
        end
        
        sequenceState.vfxStateBeforePause = {
            activePtfx = sequenceState.activePtfx,
            vfxAttachedToProp = sequenceState.vfxAttachedToProp,
            loopAnimActive = sequenceState.loopAnimActive
        }
    end
    
    return true
end

function Sequences:ResumeSequence(pedHandle)
    local sequenceState = Sequences.ActiveSequences[pedHandle]
    if not sequenceState then return false end
    
    if not sequenceState.isPlaying then
        sequenceState.isPlaying = true
        sequenceState.pauseStartTime = nil
        
        local elapsedTime = 0
        if sequenceState.stepStartTime then
            elapsedTime = (sequenceState.pauseTime or GetGameTimer()) - sequenceState.stepStartTime
        end
        
        local currentStep = sequenceState.currentStep
        local currentAudio = sequenceState.currentAudio
        local step = sequenceState.sequence[currentStep]
        
        if step and step.AudioSubtitles and step.AudioSubtitles.AudiosToPlay then
            local audioInfo = step.AudioSubtitles.AudiosToPlay[currentAudio]
            
            if sequenceState.activeAudioId then
                if FixerCore.Audio.active[sequenceState.activeAudioId] then
                    local audioDuration = audioInfo.Duration or 4
                    if FixerCore.Audio.active[sequenceState.activeAudioId].currentTime >= audioDuration - 0.1 then
                        FixerCore.Audio:Stop(sequenceState.activeAudioId)
                        sequenceState.activeAudioId = nil
                        
                        if currentAudio < #step.AudioSubtitles.AudiosToPlay then
                            sequenceState.currentAudio = currentAudio + 1
                            local nextAudioInfo = step.AudioSubtitles.AudiosToPlay[sequenceState.currentAudio]
                            sequenceState.activeAudioId = FixerCore.Audio:PlayOnEntity(
                                nextAudioInfo.File,
                                sequenceState.ped,
                                true,
                                {
                                    volume = nextAudioInfo.Volume or 0.7,
                                    maxDistance = sequenceState.interactionRadius,
                                    startTime = 0,
                                    autoRemove = false,
                                    subtitle = nextAudioInfo.Subtitle or "No subtitles were found.",
                                    subtitleSpeaker = sequenceState.subtitleSettings.Speaker,
                                    subtitleDuration = nextAudioInfo.Duration * 1000 or 4000
                                }
                            )
                        end
                    else
                        FixerCore.Audio:Resume(sequenceState.activeAudioId)
                    end
                else
                    sequenceState.activeAudioId = FixerCore.Audio:PlayOnEntity(
                        audioInfo.File,
                        sequenceState.ped,
                        true,
                        {
                            volume = audioInfo.Volume or 0.7,
                            maxDistance = sequenceState.interactionRadius,
                            startTime = 0,
                            autoRemove = false,
                            subtitle = audioInfo.Subtitle or "No subtitles were found.",
                            subtitleSpeaker = sequenceState.subtitleSettings.Speaker,
                            subtitleDuration = audioInfo.Duration * 1000 or 4000
                        }
                    )
                end
            else
                sequenceState.activeAudioId = FixerCore.Audio:PlayOnEntity(
                    audioInfo.File,
                    sequenceState.ped,
                    true,
                    {
                        volume = audioInfo.Volume or 0.7,
                        maxDistance = sequenceState.interactionRadius,
                        startTime = 0,
                        autoRemove = false,
                        subtitle = audioInfo.Subtitle or "No subtitles were found.",
                        subtitleSpeaker = sequenceState.subtitleSettings.Speaker,
                        subtitleDuration = audioInfo.Duration * 1000 or 4000
                    }
                )
            end
        end
        
        if sequenceState.vfxStateBeforePause then
            if sequenceState.vfxStateBeforePause.loopAnimActive and sequenceState.activeLoopAnim then
                FixerCore.Animations:PlayLoopAnimation(sequenceState, sequenceState.activeLoopAnim)
            end
            
            if sequenceState.vfxStateBeforePause.activePtfx and sequenceState.ptfxDict and sequenceState.ptfxName then
                if sequenceState.vfxStateBeforePause.vfxAttachedToProp and sequenceState.lastProp then
                    FixerCore.VFX:ApplyVFXToProp(
                        sequenceState.lastProp,
                        sequenceState.ptfxDict,
                        sequenceState.ptfxName,
                        sequenceState.ptfxOffset,
                        sequenceState.ptfxRotation,
                        sequenceState.ptfxScale
                    )
                else
                    FixerCore.VFX:ApplyVFXToPed(
                        sequenceState.ped,
                        sequenceState.ptfxDict,
                        sequenceState.ptfxName,
                        sequenceState.ptfxBone,
                        sequenceState.ptfxOffset,
                        sequenceState.ptfxRotation,
                        sequenceState.ptfxScale
                    )
                end
            end
        end
        
        if sequenceState.waitingForChoice and sequenceState.savedDialogueChoice then
            local savedChoice = sequenceState.savedDialogueChoice
    
            local promise = promise.new()
            local choiceId = "choices_" .. pedHandle .. "_" .. GetGameTimer()
            
            Sequences.ActiveDialogueChoices[choiceId] = {
                promise = promise,
                timeout = savedChoice.choiceData.timeout,
                defaultChoice = savedChoice.choiceData.defaultChoice,
                startTime = GetGameTimer(),
                onDialogueChoice = savedChoice.choiceData.onDialogueChoice,
                choices = savedChoice.choiceData.choices
            }
            
            sequenceState.activeChoiceId = choiceId
            
            if sequenceState.activeLoopAnim then
                sequenceState.loopAnimActive = true
                FixerCore.Animations:PlayLoopAnimation(sequenceState, sequenceState.activeLoopAnim)
            end
            
            SetNuiFocus(true, false)
            SendNUIMessage({
                type = 'showDialogueChoices',
                id = choiceId,
                promptText = savedChoice.choiceData.promptText or "Choose an option",
                choices = savedChoice.choiceData.choices,
                timeout = savedChoice.choiceData.timeout
            })
            
            if savedChoice.choiceData.timeout and savedChoice.choiceData.timeout > 0 then
                CreateThread(function()
                    local endTime = GetGameTimer() + savedChoice.choiceData.timeout
                    
                    while GetGameTimer() < endTime do
                        Wait(100)
                        
                        if not Sequences.ActiveDialogueChoices[choiceId] then
                            return
                        end
                    end
                    
                    local choiceData = Sequences.ActiveDialogueChoices[choiceId]
                    if choiceData then
                        local defaultIdx = choiceData.defaultChoice or 1
                        if choiceData.choices[defaultIdx] and not choiceData.choices[defaultIdx].disabled then
                            FixerCore.VIDialogue:HandleDialogueChoice(choiceId, defaultIdx)
                        else
                            for idx, choice in ipairs(choiceData.choices) do
                                if not choice.disabled then
                                    FixerCore.VIDialogue:HandleDialogueChoice(choiceId, idx)
                                    return
                                end
                            end
                            
                            if FixerCore.Sequences.ActiveDialogueChoices[choiceId] then
                                FixerCore.VIDialogue:HideDialogueChoices(choiceId)
                                promise:resolve(nil)
                                Sequences.ActiveDialogueChoices[choiceId] = nil
                            end
                        end
                    end
                end)
            end
            
            CreateThread(function()
                sequenceState.waitingForChoice = true
                local chosenBranch = Citizen.Await(promise)
                sequenceState.waitingForChoice = false
                sequenceState.loopAnimActive = false
                sequenceState.savedDialogueChoice = nil
                
                if not Sequences.ActiveSequences[pedHandle] then
                    return
                end
                
                if chosenBranch and sequenceState.branches and sequenceState.branches[chosenBranch] then
                    sequenceState.sequence = sequenceState.branches[chosenBranch]
                    sequenceState.currentStep = 1
                    sequenceState.currentAudio = 1
                    sequenceState.stepStartTime = GetGameTimer()
                    
                    Sequences:ContinueSequenceFromCurrentPoint(pedHandle, 0)
                else
                    sequenceState.currentStep = sequenceState.currentStep + 1
                    sequenceState.currentAudio = 1
                    sequenceState.stepStartTime = GetGameTimer()
                    Sequences:ContinueSequenceFromCurrentPoint(pedHandle, 0)
                end
            end)
        else
            CreateThread(function()
                Sequences:ContinueSequenceFromCurrentPoint(pedHandle, elapsedTime)
            end)
        end
        
        return true
    end
    
    return true
end

function Sequences:CleanupSequence(pedHandle, timeoutExpired)
    local sequenceState = Sequences.ActiveSequences[pedHandle]
    if not sequenceState then return end
    
    if sequenceState.trackingAreaName then
        FixerCore.Distance:StopTracking(sequenceState.trackingAreaName)
    end
    
    if sequenceState.activeAudioId then
        FixerCore.Audio:Stop(sequenceState.activeAudioId)
    end
    
    if sequenceState.activeSubtitleId then
        FixerCore.VISubtitles:Hide(sequenceState.activeSubtitleId)
    end
    
    if sequenceState.activeChoiceId then
        FixerCore.VIDialogue:HideDialogueChoices(sequenceState.activeChoiceId)
        sequenceState.activeChoiceId = nil
    end
    
    for _, prop in ipairs(sequenceState.attachedProps) do
        if DoesEntityExist(prop) then
            local propModel = GetEntityModel(prop)
            DeleteEntity(prop)
            
            if propModel ~= 0 then
                SetModelAsNoLongerNeeded(propModel)
            end
        end
    end
    
    if sequenceState.activePtfx then
        StopParticleFxLooped(sequenceState.activePtfx, 0)
        sequenceState.activePtfx = nil
        
        if sequenceState.ptfxAssetName then
            RemoveNamedPtfxAsset(sequenceState.ptfxAssetName)
        end
    end

    if sequenceState.onInteractionExit then
        sequenceState.onInteractionExit(timeoutExpired)
    end
    
    if sequenceState.loadedAnimDicts then
        for dict, _ in pairs(sequenceState.loadedAnimDicts) do
            RemoveAnimDict(dict)
        end
    end
    
    Sequences.ActiveSequences[pedHandle] = nil
end

function Sequences:TriggerSequence(sequence, ped, sequenceData, options)
    options = options or {}
    local pedHandle = NetworkGetNetworkIdFromEntity(ped)
    local interactionRadius = options.radius or 5.0
    local trackingId = "dialoguetrigger"..sequence.."_"..pedHandle
    local playerPed = PlayerPedId()
    
    if IsEntityDead(playerPed) or IsEntityInWater(playerPed) or IsEntityInAir(playerPed) or IsPedInParachuteFreeFall(playerPed) or IsPedBeingStunned(playerPed) or IsPedRagdoll(playerPed) or IsPedFalling(playerPed) or IsPedJumpingOutOfVehicle(playerPed) or IsPedInAnyVehicle(playerPed, false) then
        return
    end
    
    FixerCore.Distance:TrackArea(
        trackingId, 
        options.coords or GetEntityCoords(ped), 
        interactionRadius, 
        true,
        function()
            TaskTurnPedToFaceEntity(ped, PlayerPedId(), -1)
            TaskLookAtEntity(ped, PlayerPedId(), -1)
            Sequences:PlaySequenceWith3DAudio(
                ped, 
                sequenceData.Sequence, 
                sequenceData.SubtitleSettings,
                {
                    interactionRadius = interactionRadius,
                    timeoutDuration = options.interactionTimeout or 30000,
                    enableSubtitles = options.enableSubtitles,
                    onInteractionExit = options.onInteractionExit,
                    branches = sequenceData.Branches,
                    onDialogueChoice = options.onDialogueChoice
                }
            )
            if options.onStart then
                options.onStart()
            end
        end,
        options.onInteractionExit
    )
    return true
end

function table.clone(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else
        copy = orig
    end
    return copy
end

FixerCore.Sequences = Sequences