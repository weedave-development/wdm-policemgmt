local sharedConfig = require 'config.shared'
local clientConfig = require 'config.client'

local isManagementOpen = false
local currentOfficers = {}
local playerData = {}

-- Initialize
CreateThread(function()
    -- Wait for player to be loaded
    while not exports.qbx_core:GetPlayerData() do
        Wait(100)
    end
    
    playerData = exports.qbx_core:GetPlayerData()
    
    -- Create blips for management locations
    if clientConfig.blips.enabled then
        for _, location in pairs(clientConfig.allowedLocations) do
            local blip = AddBlipForCoord(location.coords.x, location.coords.y, location.coords.z)
            SetBlipSprite(blip, clientConfig.blips.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, clientConfig.blips.scale)
            SetBlipColour(blip, clientConfig.blips.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(clientConfig.blips.name)
            EndTextCommandSetBlipName(blip)
        end
    end
    
    -- Register key mapping
    RegisterKeyMapping('policemgmt', 'Open Police Management', 'keyboard', clientConfig.openKey)
end)

-- Check if player is in allowed location
local function IsInAllowedLocation()
    -- Check if location requirement is disabled
    if not clientConfig.locationRequirement.enabled then
        return true
    end
    
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    for _, location in pairs(clientConfig.allowedLocations) do
        local distance = #(playerCoords - location.coords)
        if distance <= location.radius then
            return true
        end
    end
    
    return false
end

-- Check if player has permission
local function HasPermission()
    if not playerData or not playerData.job then
        return false
    end
    
    local job = playerData.job
    
    -- Check if job is in the police departments list
    local isPoliceDept = false
    for _, dept in pairs(sharedConfig.policeDepartments) do
        if job.name == dept then
            isPoliceDept = true
            break
        end
    end
    
    if not isPoliceDept then
        return false
    end
    
    return job.grade.level >= sharedConfig.minManagementRank
end

-- Open management panel
local function OpenManagementPanel()
    if isManagementOpen then return end
    
    if not HasPermission() then
        lib.notify({
            title = 'Police Management',
            description = 'You do not have permission to access this system.',
            type = 'error'
        })
        return
    end
    
    if not IsInAllowedLocation() then
        lib.notify({
            title = 'Police Management',
            description = clientConfig.locationRequirement.message,
            type = 'error'
        })
        return
    end
    
    isManagementOpen = true
    SetNuiFocus(true, true)
    
    -- Request officer data from server
    TriggerServerEvent('police_management:server:getOfficers')
    
    -- Send NUI data
    SendNUIMessage({
        action = 'openManagement',
        playerData = {
            name = playerData.charinfo.firstname .. ' ' .. playerData.charinfo.lastname,
            job = playerData.job.name,
            grade = playerData.job.grade.level,
            gradeName = playerData.job.grade.name
        },
        config = {
            minFireRank = sharedConfig.minFireRank,
            minCallsignRank = sharedConfig.minCallsignRank,
            maxCallsignLength = sharedConfig.maxCallsignLength,
            minCallsignLength = sharedConfig.minCallsignLength
        }
    })
end

-- Close management panel
local function CloseManagementPanel()
    if not isManagementOpen then return end
    
    isManagementOpen = false
    SetNuiFocus(false, false)
    
    SendNUIMessage({
        action = 'closeManagement'
    })
end

-- Register command
RegisterCommand('policemgmt', function()
    OpenManagementPanel()
end, false)

-- NUI Callbacks
RegisterNUICallback('closeManagement', function(data, cb)
    CloseManagementPanel()
    cb('ok')
end)

RegisterNUICallback('getOfficers', function(data, cb)
    TriggerServerEvent('police_management:server:getOfficers')
    cb('ok')
end)

RegisterNUICallback('updateCallsign', function(data, cb)
    if not data.citizenid or not data.callsign then
        cb({success = false, message = 'Invalid data provided'})
        return
    end
    
    TriggerServerEvent('police_management:server:updateCallsign', data.citizenid, data.callsign)
    cb('ok')
end)

RegisterNUICallback('updateRank', function(data, cb)
    if not data.citizenid or not data.grade then
        cb({success = false, message = 'Invalid data provided'})
        return
    end
    
    TriggerServerEvent('police_management:server:updateRank', data.citizenid, data.grade)
    cb('ok')
end)

RegisterNUICallback('terminateOfficer', function(data, cb)
    if not data.citizenid then
        cb({success = false, message = 'Invalid data provided'})
        return
    end
    
    TriggerServerEvent('police_management:server:terminateOfficer', data.citizenid)
    cb('ok')
end)

RegisterNUICallback('addOfficer', function(data, cb)
    if not data.sourceId or not data.grade then
        cb({success = false, message = 'Invalid data provided'})
        return
    end
    
    TriggerServerEvent('police_management:server:addOfficer', data.sourceId, data.grade, data.callsign or '')
    cb('ok')
end)

RegisterNUICallback('getOfficerDetails', function(data, cb)
    if not data.citizenid then
        cb({success = false, message = 'Invalid data provided'})
        return
    end
    
    TriggerServerEvent('police_management:server:getOfficerDetails', data.citizenid)
    cb('ok')
end)

-- Server events
RegisterNetEvent('police_management:client:receiveOfficers', function(officers)
    currentOfficers = officers
    
    SendNUIMessage({
        action = 'updateOfficers',
        officers = officers
    })
end)

RegisterNetEvent('police_management:client:receiveOfficerDetails', function(officerInfo, callsignHistory)
    SendNUIMessage({
        action = 'updateOfficerDetails',
        officerInfo = officerInfo,
        callsignHistory = callsignHistory
    })
end)

-- Player data updates
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    playerData = exports.qbx_core:GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    playerData = {}
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    if playerData then
        playerData.job = JobInfo
    end
end)

-- ESC key to close
CreateThread(function()
    while true do
        Wait(0)
        if isManagementOpen then
            if IsControlJustPressed(0, 322) then -- ESC key
                CloseManagementPanel()
            end
        else
            Wait(500)
        end
    end
end)
