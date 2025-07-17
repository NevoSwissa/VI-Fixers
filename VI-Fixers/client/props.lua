local FixerCore = _G.FixerCore

local Props = { 
    active = {}, 
    activeProps = {} 
}

function Props:SpawnProp(id, model, coords, heading, opts)
    if self.active[id] then
        DeleteEntity(self.active[id])
        self.active[id] = nil
    end
    
    local modelHash = type(model) == 'string' and joaat(model) or model
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do Wait(50) end
    
    local propCoords = coords
    if opts and opts.offset then
        propCoords = vec3(
            coords.x + (opts.offset.x or 0.0),
            coords.y + (opts.offset.y or 0.0),
            coords.z + (opts.offset.z or 0.0)
        )
    end

    local propEntity = CreateObject(modelHash, propCoords.x, propCoords.y, propCoords.z, false, false, false)
    
    if opts then
        if opts.flipHeading then
            SetEntityHeading(propEntity, heading - 180)
        else
            SetEntityHeading(propEntity, heading)
        end
        
        if opts.freeze ~= false then
            FreezeEntityPosition(propEntity, true)
        end
        
        if opts.attachTo then
            local attachEntity = opts.attachTo.entity
            local boneIndex = opts.attachTo.bone and GetPedBoneIndex(attachEntity, opts.attachTo.bone) or -1
            AttachEntityToEntity(
                propEntity, attachEntity, boneIndex,
                opts.attachTo.offset.x or 0.0, opts.attachTo.offset.y or 0.0, opts.attachTo.offset.z or 0.0,
                opts.attachTo.rotation.x or 0.0, opts.attachTo.rotation.y or 0.0, opts.attachTo.rotation.z or 0.0,
                true, true, false, true, 1, true
            )
        end
    end
    
    self.active[id] = propEntity
    return propEntity
end

function Props:GetProp(id)
    return self.active[id]
end

function Props:DeleteProp(id)
    if self.active[id] then
        DeleteEntity(self.active[id])
        SetModelAsNoLongerNeeded(self.active[id])
        self.active[id] = nil
        return true
    end
    return false
end

function Props:AttachPropToEntity(sequenceState, propData)
    if not propData or not sequenceState or not DoesEntityExist(sequenceState.ped) then
        return nil
    end
    
    local ped = sequenceState.ped
    local propModel = propData.model
    
    if type(propModel) == "string" then
        propModel = GetHashKey(propModel)
    end
    
    if not HasModelLoaded(propModel) then
        RequestModel(propModel)
        local timeout = GetGameTimer() + 2000
        while not HasModelLoaded(propModel) and GetGameTimer() < timeout do
            Wait(50)
        end
    end
    
    local prop = CreateObject(propModel, 0.0, 0.0, 0.0, true, true, false)
    local bone = GetPedBoneIndex(ped, propData.bone)
    
    AttachEntityToEntity(
        prop, 
        ped, 
        bone, 
        propData.offset.x, 
        propData.offset.y, 
        propData.offset.z, 
        propData.rotation.x, 
        propData.rotation.y, 
        propData.rotation.z, 
        true, true, false, true, 0, true
    )
    
    sequenceState.lastProp = prop
    table.insert(sequenceState.attachedProps, prop)
    
    SetModelAsNoLongerNeeded(propModel)
    
    return prop
end

function Props:CleanupEntityProps(sequenceState)
    if sequenceState.attachedProps then
        for _, prop in ipairs(sequenceState.attachedProps) do
            if DoesEntityExist(prop) then
                DetachEntity(prop, true, true)
                SetEntityAsNoLongerNeeded(prop)
                DeleteObject(prop)
            end
        end
        sequenceState.attachedProps = {}
        sequenceState.lastProp = nil
    end
    
    return true
end

FixerCore.Props = Props