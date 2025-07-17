local FixerCore = _G.FixerCore

local VISubtitles = {
    active = {},
    nextId = 1,
}

function VISubtitles:Show(text, speaker, duration)
    local id = self.nextId
    self.nextId = self.nextId + 1
    
    duration = duration or 3000
    
    self.active[id] = {
        text = text,
        speaker = speaker,
        duration = duration,
        startTime = GetGameTimer(),
        endTime = GetGameTimer() + duration
    }
    
    SendNUIMessage({
        type = 'showSubtitle',
        id = id,
        text = text,
        speaker = speaker,
        duration = duration
    })
    
    CreateThread(function()
        Wait(duration)
        VISubtitles:Hide(id)
    end)
    
    return id
end

function VISubtitles:Hide(id)
    if self.active[id] then
        SendNUIMessage({
            type = 'hideSubtitle',
            id = id
        })
        
        self.active[id] = nil
        return true
    end
    return false
end

function VISubtitles:HideAll()
    SendNUIMessage({
        type = 'hideAllSubtitles'
    })
    
    self.active = {}
    return true
end

FixerCore.VISubtitles = VISubtitles