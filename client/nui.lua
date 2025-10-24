-- NUI specific client code
local nuiOpen = false

-- NUI state management
local function SetNUIState(state)
    nuiOpen = state
    SetNuiFocus(state, state)
end

-- Export functions for other resources
exports('IsManagementOpen', function()
    return nuiOpen
end)

exports('OpenManagement', function()
    if nuiOpen then return end
    
    SetNUIState(true)
    SendNUIMessage({
        action = 'openManagement'
    })
end)

exports('CloseManagement', function()
    if not nuiOpen then return end
    
    SetNUIState(false)
    SendNUIMessage({
        action = 'closeManagement'
    })
end)
