local FixerCore = _G.FixerCore

local VIObjectives = {
    currentObjectives = {}
}

function VIObjectives:Show(data)
    if not data or not data.title or not data.text then return end
    local objectiveId = data.id or ("objective_" .. GetGameTimer())
    
    VIObjectives.currentObjectives[objectiveId] = {
        id = objectiveId,
        title = data.title,
        text = data.text,
        displayTime = data.displayTime or 0,
        showProgress = data.showProgress or false,
        progress = data.progress or 0,
        optionalText = data.optionalText,
    }
    
    SendNUIMessage({
        type = "showVIObjective",
        id = objectiveId,
        title = data.title,
        text = data.text,
        displayTime = data.displayTime or 0,
        showProgress = data.showProgress or false,
        progress = data.progress or 0,
        optionalText = data.optionalText,
    })
    
    return objectiveId
end

function VIObjectives:Update(data)
    if not data or not data.id then return end

    local obj = VIObjectives.currentObjectives[data.id]
    if not obj then
        return VIObjectives:Show(data)
    end

    if data.title ~= nil then obj.title = data.title end
    if data.text ~= nil then obj.text = data.text end
    if data.showProgress ~= nil then obj.showProgress = data.showProgress end
    if data.progress ~= nil then obj.progress = data.progress end
    if data.optionalText ~= nil then obj.optionalText = data.optionalText end

    SendNUIMessage({
        type = "updateVIObjective",
        id = obj.id,
        title = obj.title,
        text = obj.text,
        showProgress = obj.showProgress,
        progress = obj.progress,
        optionalText = obj.optionalText,
    })
end

function VIObjectives:Hide(id)
    SendNUIMessage({
        type = "hideVIObjective",
        id = id
    })
end

FixerCore.VIObjectives = VIObjectives