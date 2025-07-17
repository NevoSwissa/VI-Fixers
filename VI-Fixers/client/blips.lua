local FixerCore = _G.FixerCore

local Blips = {}
local GlobalBlips = {}

function Blips:Add(id, data)
    if GlobalBlips[id] then
        RemoveBlip(GlobalBlips[id])
        GlobalBlips[id] = nil
    end

    local blip
    if data.entity then
        blip = AddBlipForEntity(data.entity)
    else
        blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
    end

    SetBlipSprite(blip, data.sprite or 1)
    SetBlipDisplay(blip, data.display or 4)
    SetBlipScale(blip, data.scale or 0.8)
    SetBlipColour(blip, data.color or 1)
    SetBlipAsShortRange(blip, (data.dials and data.dials.isShortRange) or false)

    if data.name then
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(data.name)
        EndTextCommandSetBlipName(blip)
    end

    if data.dials then
        if data.dials.isRoute then
            SetBlipRoute(blip, true)
            SetBlipRouteColour(blip, data.dials.routeColor or data.color or 1)
        end

        if data.dials.isWaypoint and data.coords then
            local blipsRef = self
            FixerCore.Distance:TrackArea("blip_wp_"..id, data.coords, data.dials.radius or 20.0, true, function()
                if data.dials.removeOnArrival then
                    blipsRef:Remove(id)
                end
                
                if data.onArrival then
                    data.onArrival()
                end
            end)
        end
    end

    GlobalBlips[id] = blip

    return blip
end

function Blips:Exists(id)
    return GlobalBlips[id] ~= nil and DoesBlipExist(GlobalBlips[id])
end

function Blips:Remove(id)
    if GlobalBlips[id] then
        if DoesBlipExist(GlobalBlips[id]) then
            RemoveBlip(GlobalBlips[id])
        end
        GlobalBlips[id] = nil
    end
end

FixerCore.Blips = Blips