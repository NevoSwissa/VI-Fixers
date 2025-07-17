local FixerCore = _G.FixerCore

local VIInteract = {
    active = {},
    activeEntity = nil,
    activeCoords = nil,
    isVisible = false,
    currentOptions = {},
    keysPressed = {},
    displayDistance = 5.0,
}

local GlobalActive = {}
local nearbyInteractions = {}

function VIInteract:Init()
    RegisterNUICallback('interactionVisibilityChanged', function(data, cb)
        self.isVisible = data.visible
        cb({})
    end)

    RegisterNUICallback('interactionOptionSelected', function(data, cb)
        self.currentSelectedIndex = data.index
        cb({})
    end)

    Citizen.CreateThread(function()
        while true do
            if #GlobalActive > 0 then
                local playerPed = PlayerPedId()
                local playerPos = GetEntityCoords(playerPed)
                
                nearbyInteractions = {}
                
                self:UpdateNearbyInteractions(playerPos)
                self:UpdateActiveInteraction()
                
                Citizen.Wait(500)
            else
                Citizen.Wait(1000)
            end
        end
    end)
    
    Citizen.CreateThread(function()
        while true do
            if self.isVisible then
                self:ProcessKeyPresses()
                Citizen.Wait(0)
            else
                Citizen.Wait(250)
            end
        end
    end)
end

function VIInteract:UpdateNearbyInteractions(playerPos)
    for _, interaction in ipairs(GlobalActive) do
        local targetPos
        if interaction.config.entity then
            if DoesEntityExist(interaction.config.entity) then
                targetPos = GetEntityCoords(interaction.config.entity)
            else
                targetPos = vector3(0, 0, 0)
            end
        else
            targetPos = interaction.config.coords
        end
        
        local dx, dy, dz = playerPos.x - targetPos.x, playerPos.y - targetPos.y, playerPos.z - targetPos.z
        local squaredDistance = dx*dx + dy*dy + dz*dz
        local roughCheckDistance = interaction.config.distance * 1.5
        
        if squaredDistance <= (roughCheckDistance * roughCheckDistance) then
            local distance = Vdist(playerPos.x, playerPos.y, playerPos.z, targetPos.x, targetPos.y, targetPos.z)
            local inRange = distance <= interaction.config.distance
            
            local conditionMet = true
            if interaction.config.condition then
                conditionMet = interaction.config.condition()
            end
            
            if inRange and conditionMet then
                if not interaction.isInRange then
                    interaction.isInRange = true
                    if interaction.config.onEnter then
                        interaction.config.onEnter()
                    end
                end
                
                table.insert(nearbyInteractions, {
                    interaction = interaction,
                    distance = distance
                })
            elseif interaction.isInRange then
                interaction.isInRange = false
                if interaction.config.onExit then
                    interaction.config.onExit()
                end
            end
        elseif interaction.isInRange then
            interaction.isInRange = false
            if interaction.config.onExit then
                interaction.config.onExit()
            end
        end
    end
    
    table.sort(nearbyInteractions, function(a, b)
        return a.distance < b.distance
    end)
end

function VIInteract:UpdateActiveInteraction()
    if #nearbyInteractions > 0 then
        local closest = nearbyInteractions[1].interaction
        
        if self.activeEntity == closest.config.entity and self.activeCoords == closest.config.coords then
            return
        end
        
        if closest.config.entity then
            self.activeEntity = closest.config.entity
            self.activeCoords = nil
        else
            self.activeEntity = nil
            self.activeCoords = closest.config.coords
        end
        
        self:Show(closest.id, closest.config.interactions, closest.config.autoRemove)
    elseif self.isVisible then
        self:Hide()
    end
end

function VIInteract:ProcessKeyPresses()
    if #self.currentOptions == 0 then
        return
    end

    for index, option in ipairs(self.currentOptions) do
        local keyCode = GetKeyFromLabel(option.key)
        if not keyCode then goto continue end

        local isKeyDown = IsControlPressed(0, keyCode)

        if isKeyDown and not self.keysPressed[keyCode] then
            self.keysPressed[keyCode] = true
            self.currentSelectedIndex = index

            SendNUIMessage({
                action = "interactionOptionSelected",
                index = index,
                key = option.key
            })

            SendNUIMessage({
                action = "triggerKeyAnimation",
                key = option.key
            })

            if option.action then
                option.action()
            end
            
            if self.currentAutoRemove then
                self:Remove(self.currentInteractionId)
            end
        elseif not isKeyDown and self.keysPressed[keyCode] then
            self.keysPressed[keyCode] = false
        end

        ::continue::
    end
end

function VIInteract:Add(id, options)
    local config = {
        coords = nil,
        entity = nil,
        distance = self.displayDistance,
        interactions = {},
        onEnter = nil,
        onExit = nil,
        condition = nil,
        autoRemove = false,
    }

    for k, v in pairs(options) do
        config[k] = v
    end

    if not config.coords and not config.entity then
        print("^1Error: Interaction requires either coords or entity^7")
        return false
    end

    if #config.interactions == 0 then
        print("^1Error: No interactions provided for " .. id .. "^7")
        return false
    end

    table.insert(GlobalActive, {
        id = id,
        config = config,
        isInRange = false
    })

    return true
end

function VIInteract:Remove(id)
    local removed = false
    
    for i = #GlobalActive, 1, -1 do
        if GlobalActive[i].id == id then
            table.remove(GlobalActive, i)
            removed = true
        end
    end
    
    self.keysPressed = {}
    self:Hide()
    
    return removed
end

function VIInteract:Show(id, interactions, autoRemove)
    local interactionData = {}
    for i, interaction in ipairs(interactions) do
        table.insert(interactionData, {
            id = id .. "" .. i,
            key = interaction.key,
            label = interaction.label,
            description = interaction.description or "",
        })
    end

    self.currentOptions = interactions
    self.currentAutoRemove = autoRemove or false
    self.currentInteractionId = id

    SendNUIMessage({
        action = "showInteraction",
        interactions = interactionData
    })

    self.keysPressed = {}
    self.currentSelectedIndex = 1
end

function VIInteract:Hide()
    SendNUIMessage({
        action = "hideInteraction"
    })

    self.activeEntity = nil
    self.activeCoords = nil
    self.currentOptions = {}
    self.keysPressed = {}
    self.currentAutoRemove = false
    self.currentInteractionId = nil
end

function GetKeyFromLabel(keyLabel)
    local keyMap = {
        ["E"] = 38,
        ["F"] = 23,
        ["H"] = 74,
        ["SPACE"] = 22,
        ["ENTER"] = 18,
    }

    return keyMap[keyLabel]
end

FixerCore.VIInteract = VIInteract