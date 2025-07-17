local FixerCore = _G.FixerCore

local Distance = {
    activeAreas = {}
}

function Distance:TrackArea(name, coords, radius, autoStop, onEnter, onExit)
    local inside = false
    self.activeAreas[name] = true

    CreateThread(function()
        while self.activeAreas[name] do
            local sleep = 2000
            local dist = Distance:CalculateDistance(GetEntityCoords(PlayerPedId()), coords)

            if dist < radius then
                if not inside then
                    inside = true
                    if onEnter then onEnter() end
                    if autoStop then
                        Distance:StopTracking(name)
                        break
                    end
                end
                sleep = 500
            elseif dist < radius * 2 then
                sleep = 1000
                if inside then
                    inside = false
                    if onExit then onExit() end
                end
            else
                sleep = 2000
                if inside then
                    inside = false
                    if onExit then onExit() end
                end
            end

            Wait(sleep)
        end
    end)
end

function Distance:StopTracking(name)
    self.activeAreas[name] = nil
end

function Distance:CalculateDistance(coords1, coords2)
    return #(vector2(coords1.x, coords1.y) - vector2(coords2.x, coords2.y))
end

FixerCore.Distance = Distance