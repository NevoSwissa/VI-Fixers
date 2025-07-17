local FixerCore = _G.FixerCore

local VILink = {}

function VILink:ShowLinkMessage(data)
    SendNUIMessage({
        type = "showVILink",
        id = data.id or ("msg_" .. GetGameTimer()),
        sender = data.sender,
        subject = data.subject,
        message = data.message,
        displayTime = data.displayTime or 8000,
    })

    if data.flashScreen ~= false then
        FixerCore.VFX.Presets.MessageReceived()
    end
end

function VILink:HideLinkMessage()
    SendNUIMessage({
        type = "hideVILink"
    })
end

FixerCore.VILink = VILink