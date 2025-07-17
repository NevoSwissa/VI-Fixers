local FixerCore = _G.FixerCore

local VIDialogue = {}

function VIDialogue:ShowDialogueChoices(pedHandle, choicesData)
    local promise = promise.new()
    local sequenceState = FixerCore.Sequences.ActiveSequences[pedHandle]
    choicesData.Timeout = choicesData.Timeout * 1000
    if not sequenceState then
        promise:resolve(nil)
        return promise
    end
    
    local choiceId = "choices_" .. pedHandle .. "_" .. GetGameTimer()
    SetNuiFocus(true, false)
    FixerCore.Sequences.ActiveDialogueChoices[choiceId] = {
        promise = promise,
        timeout = choicesData.Timeout,
        defaultChoice = choicesData.DefaultChoice,
        startTime = GetGameTimer(),
        onDialogueChoice = sequenceState.onDialogueChoice
    }
    sequenceState.activeChoiceId = choiceId
    
    local filteredChoices = {}
    for _, choice in ipairs(choicesData.Choices) do        
        table.insert(filteredChoices, {
            text = choice.Text,
            icon = choice.Icon,
            branchName = choice.SequenceBranch,
        })
    end
    
    FixerCore.Sequences.ActiveDialogueChoices[choiceId].choices = filteredChoices
    SendNUIMessage({
        type = 'showDialogueChoices',
        id = choiceId,
        promptText = choicesData.PromptText,
        choices = filteredChoices,
        timeout = choicesData.Timeout
    })
    
    if choicesData.Timeout and choicesData.Timeout > 0 then
        CreateThread(function()
            local endTime = GetGameTimer() + choicesData.Timeout
            
            while GetGameTimer() < endTime do
                Wait(100)
                
                if not FixerCore.Sequences.ActiveDialogueChoices[choiceId] then
                    return
                end
            end
            
            local choiceData = FixerCore.Sequences.ActiveDialogueChoices[choiceId]
            if choiceData then
                local defaultIdx = choiceData.defaultChoice or 1
                if defaultIdx > 0 and defaultIdx <= #filteredChoices then
                    VIDialogue:HandleDialogueChoice(choiceId, defaultIdx)
                else
                    for idx, choice in ipairs(filteredChoices) do
                        if not choice.disabled then
                            VIDialogue:HandleDialogueChoice(choiceId, idx)
                            return
                        end
                    end
                    
                    if FixerCore.Sequences.ActiveDialogueChoices[choiceId] then
                        VIDialogue:HideDialogueChoices(choiceId)
                        promise:resolve(nil)
                        FixerCore.Sequences.ActiveDialogueChoices[choiceId] = nil
                    end
                end
            end
        end)
    end
    
    return promise
end

function VIDialogue:HideDialogueChoices(choiceId)
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = 'hideDialogueChoices',
        id = choiceId
    })
end

function VIDialogue:HandleDialogueChoice(choiceId, choiceIndex)
    local choiceData = FixerCore.Sequences.ActiveDialogueChoices[choiceId]
    if not choiceData then return end

    local promise = choiceData.promise
    local branchName = nil
    local choice = choiceData.choices and choiceData.choices[choiceIndex]

    if choice then
        branchName = choice.branchName
    end

    if choiceData.onDialogueChoice and branchName then
        choiceData.onDialogueChoice(branchName)
    end

    VIDialogue:HideDialogueChoices(choiceId)

    if promise then
        promise:resolve(branchName)
    end

    FixerCore.Sequences.ActiveDialogueChoices[choiceId] = nil
end

RegisterNUICallback('dialogueChoiceSelected', function(data, cb)
    local choiceId = data.id
    local choiceIndex = data.index
    local branchName = data.branchName
    local choiceData = FixerCore.Sequences.ActiveDialogueChoices[choiceId]
    
    if choiceData then
        if choiceData.onDialogueChoice and branchName then
            local choice = choiceData.choices and choiceData.choices[choiceIndex]
            local choiceAction = choice and choice.action
            choiceData.onDialogueChoice(branchName, choiceAction, choiceIndex)
        end
        
        SetNuiFocus(false, false)
        choiceData.promise:resolve(branchName)
        FixerCore.Sequences.ActiveDialogueChoices[choiceId] = nil
    end
    
    cb({success = true})
end)

FixerCore.VIDialogue = VIDialogue