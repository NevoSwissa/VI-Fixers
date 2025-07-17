local FixerCore = {}

FixerCore.Distance = {}
FixerCore.Blips = {}
FixerCore.Props = {}
FixerCore.Peds = {}
FixerCore.VFX = {}
FixerCore.Audio = {}
FixerCore.StealthTakedown = {}
FixerCore.EnemyAI = {}
FixerCore.Vehicles = {}
FixerCore.Animations = {}
FixerCore.Sequences = {}
FixerCore.IPLSystem = {}

-- UI modules
FixerCore.VISubtitles = {}
FixerCore.VINotifications = {}
FixerCore.VIObjectives = {}
FixerCore.VILink = {}
FixerCore.VIInteract = {}
FixerCore.VIDialogue = {}

exports('GetFixerCore', function() return FixerCore end)

_G.FixerCore = FixerCore

Citizen.CreateThread(function()
    Citizen.Wait(500)
    
    FixerCore.Audio:Init() 
    FixerCore.VIInteract:Init()
end)

return FixerCore