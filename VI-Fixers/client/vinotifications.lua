local FixerCore = _G.FixerCore

local VINotifications = {}

function VINotifications:Show(data)
    if not data or not data.title then return end
    local notificationId = data.id or ("notification_" .. GetGameTimer())
    
    SendNUIMessage({
        type = "showVINotification",
        id = notificationId,
        title = data.title,
        status = data.status or "success",
        displayTime = data.displayTime or 5000,
        flashScreen = data.flashScreen,
    })
    
    if data.soundEffect then
        if data.status == "success" then
            FixerCore.Audio:PlaySound("se_success.mp3", {
                volume = 0.8,
                autoRemove = true,
            })
        elseif data.status == "warning" then
            FixerCore.Audio:PlaySound("se_warning.mp3", {
                volume = 0.8,
                autoRemove = true,
            })
        elseif data.status == "danger" then
            FixerCore.Audio:PlaySound("se_danger.mp3", {
                volume = 0.4,
                autoRemove = true,
            })
        end
    end

    return notificationId
end

function VINotifications:Hide()
    SendNUIMessage({
        type = "hideVINotification"
    })
end

FixerCore.VINotifications = VINotifications