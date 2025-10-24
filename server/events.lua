-- Player loaded event - sync officer data
RegisterNetEvent('QBCore:Server:PlayerLoaded', function()
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    
    if not player then return end
    
    local job = player.PlayerData.job
    if not job or not job.name then return end
    
    -- Check if player is in a police department
    local sharedConfig = require 'config.shared'
    local isPoliceDept = false
    for _, dept in pairs(sharedConfig.policeDepartments) do
        if job.name == dept then
            isPoliceDept = true
            break
        end
    end
    
    if not isPoliceDept then return end
    
    -- Auto-sync this officer to database
    local citizenid = player.PlayerData.citizenid
    local jobName = job.name
    local grade = job.grade.level
    local callsign = player.PlayerData.metadata.callsign or ''
    
    -- Check if officer exists in database
    local existingOfficer = GetOfficerInfo(citizenid, jobName)
    
    if not existingOfficer then
        -- Add officer to database
        MySQL.insert.await([[
            INSERT INTO police_officers (citizenid, job, grade, callsign, hired_by, status) 
            VALUES (?, ?, ?, ?, 'auto_sync', 'active')
        ]], {citizenid, jobName, grade, callsign})
        
        print(string.format('[Police Management] Auto-synced new officer: %s (%s) - %s', 
            player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
            citizenid, jobName))
    else
        -- Update existing officer if needed
        if existingOfficer.grade ~= grade or existingOfficer.callsign ~= callsign then
            MySQL.update.await([[
                UPDATE police_officers 
                SET grade = ?, callsign = ?, last_updated = CURRENT_TIMESTAMP 
                WHERE citizenid = ? AND job = ?
            ]], {grade, callsign, citizenid, jobName})
            
            print(string.format('[Police Management] Auto-updated officer: %s (%s)', 
                player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname, citizenid))
        end
        
        -- Sync callsign if exists
        if existingOfficer.callsign then
            player.Functions.SetMetaData('callsign', existingOfficer.callsign)
        end
        
        -- Ensure job grade matches database
        if existingOfficer.grade ~= job.grade.level then
            player.Functions.SetJob(job.name, existingOfficer.grade)
        end
    end
end)

-- Job change event - handle police department changes
RegisterNetEvent('QBCore:Server:OnJobUpdate', function(src, newJob, oldJob)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    
    local sharedConfig = require 'config.shared'
    
    -- Check if joining a police department
    local isPoliceDept = false
    for _, dept in pairs(sharedConfig.policeDepartments) do
        if newJob.name == dept then
            isPoliceDept = true
            break
        end
    end
    
    if isPoliceDept then
        -- Auto-sync officer when joining police department
        local citizenid = player.PlayerData.citizenid
        local jobName = newJob.name
        local grade = newJob.grade.level
        local callsign = player.PlayerData.metadata.callsign or ''
        
        -- Check if officer exists in database
        local existingOfficer = GetOfficerInfo(citizenid, jobName)
        
        if not existingOfficer then
            -- Add officer to database
            MySQL.insert.await([[
                INSERT INTO police_officers (citizenid, job, grade, callsign, hired_by, status) 
                VALUES (?, ?, ?, ?, 'auto_sync', 'active')
            ]], {citizenid, jobName, grade, callsign})
            
            print(string.format('[Police Management] Auto-synced officer joining department: %s (%s) - %s', 
                player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
                citizenid, jobName))
        else
            -- Update existing officer
            MySQL.update.await([[
                UPDATE police_officers 
                SET grade = ?, callsign = ?, status = 'active', last_updated = CURRENT_TIMESTAMP 
                WHERE citizenid = ? AND job = ?
            ]], {grade, callsign, citizenid, jobName})
            
            -- Sync callsign if exists
            if existingOfficer.callsign then
                player.Functions.SetMetaData('callsign', existingOfficer.callsign)
            end
        end
    else
        -- Check if leaving a police department
        local wasPoliceDept = false
        for _, dept in pairs(sharedConfig.policeDepartments) do
            if oldJob.name == dept then
                wasPoliceDept = true
                break
            end
        end
        
        if wasPoliceDept then
            -- Mark officer as inactive when leaving police department
            local citizenid = player.PlayerData.citizenid
            MySQL.update.await([[
                UPDATE police_officers 
                SET status = 'inactive', last_updated = CURRENT_TIMESTAMP 
                WHERE citizenid = ? AND job = ?
            ]], {citizenid, oldJob.name})
            
            print(string.format('[Police Management] Marked officer as inactive: %s (%s) - %s', 
                player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
                citizenid, oldJob.name))
        end
    end
end)

-- Player disconnect - cleanup if needed
RegisterNetEvent('QBCore:Server:OnPlayerUnload', function(src)
    -- Any cleanup logic can go here if needed
end)

-- Auto-sync all existing police officers when resource starts
CreateThread(function()
    Wait(5000) -- Wait 5 seconds for server to fully load
    
    print('[Police Management] Starting automatic officer sync...')
    local syncedCount = SyncExistingOfficers()
    print(string.format('[Police Management] Auto-sync completed: %d officers synced', syncedCount))
end)

-- Periodic sync every 5 minutes to keep database updated
CreateThread(function()
    while true do
        Wait(300000) -- 5 minutes
        print('[Police Management] Running periodic database sync...')
        local syncedCount = SyncExistingOfficers()
        if syncedCount > 0 then
            print(string.format('[Police Management] Periodic sync: %d officers updated', syncedCount))
        end
    end
end)

-- Command to get nearby players for hiring
RegisterCommand('nearbyplayers', function(source, args)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    
    if not player then return end
    
    local players = exports.qbx_core:GetQBPlayers()
    local nearbyPlayers = {}
    
    for _, targetPlayer in pairs(players) do
        if targetPlayer.PlayerData.source ~= src then
            nearbyPlayers[#nearbyPlayers + 1] = {
                source = targetPlayer.PlayerData.source,
                name = targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname,
                job = targetPlayer.PlayerData.job.name,
                grade = targetPlayer.PlayerData.job.grade.name
            }
        end
    end
    
    if #nearbyPlayers == 0 then
        lib.notify(src, {
            title = 'Nearby Players',
            description = 'No other players found online.',
            type = 'info'
        })
        return
    end
    
    local message = 'Nearby Players:\n'
    for _, p in pairs(nearbyPlayers) do
        message = message .. string.format('ID: %s | %s | %s (%s)\n', p.source, p.name, p.job, p.grade)
    end
    
    lib.notify(src, {
        title = 'Nearby Players',
        description = message,
        type = 'info',
        duration = 10000
    })
    
    -- Also print to console for easy copying
    print('=== Nearby Players ===')
    for _, p in pairs(nearbyPlayers) do
        print(string.format('ID: %s | %s | %s (%s)', p.source, p.name, p.job, p.grade))
    end
end, false)

-- Test command to bypass all permission checks
RegisterCommand('testpolicemgmt', function(source, args)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    
    if not player then
        lib.notify(src, {
            title = 'Police Management',
            description = 'Player data not found.',
            type = 'error'
        })
        return
    end
    
    -- Force open the management panel
    TriggerClientEvent('police_management:client:receiveOfficers', src, {})
    
    lib.notify(src, {
        title = 'Police Management',
        description = 'Test mode: Management panel opened (bypassing permissions)',
        type = 'success'
    })
end, false)

-- Debug command to check player permissions
RegisterCommand('checkpoliceperms', function(source, args)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    
    if not player then
        lib.notify(src, {
            title = 'Police Management',
            description = 'Player data not found.',
            type = 'error'
        })
        return
    end
    
    local job = player.PlayerData.job
    local sharedConfig = require 'config.shared'
    
    local debugInfo = {
        "=== Police Management Debug ===",
        "Player: " .. (player.PlayerData.charinfo.firstname or "Unknown") .. " " .. (player.PlayerData.charinfo.lastname or "Unknown"),
        "Job: " .. (job and job.name or "nil"),
        "Grade Level: " .. (job and job.grade.level or "nil"),
        "Grade Name: " .. (job and job.grade.name or "nil"),
        "Required Management Rank: " .. sharedConfig.minManagementRank,
        "Required Fire Rank: " .. sharedConfig.minFireRank,
        "Required Callsign Rank: " .. sharedConfig.minCallsignRank,
        "Police Departments: " .. table.concat(sharedConfig.policeDepartments, ", "),
        "Is Police Department: " .. tostring(job and job.name and table.concat(sharedConfig.policeDepartments, ","):find(job.name) and true or false),
        "Has Management Permission: " .. tostring(HasManagementPermission(player)),
        "Has Fire Permission: " .. tostring(HasFirePermission(player)),
        "Has Callsign Permission: " .. tostring(HasCallsignPermission(player))
    }
    
    for _, line in ipairs(debugInfo) do
        print(line)
        lib.notify(src, {
            title = 'Debug Info',
            description = line,
            type = 'info',
            duration = 5000
        })
    end
end, false)

-- Command for police officers to sync their department
RegisterCommand('syncmydepartment', function(source, args)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    
    if not player then return end
    
    local job = player.PlayerData.job
    local sharedConfig = require 'config.shared'
    
    -- Check if player is in a police department
    local isPoliceDept = false
    for _, dept in pairs(sharedConfig.policeDepartments) do
        if job.name == dept then
            isPoliceDept = true
            break
        end
    end
    
    if not isPoliceDept then
        lib.notify(src, {
            title = 'Police Management',
            description = 'You must be in a police department to use this command.',
            type = 'error'
        })
        return
    end
    
    local syncedCount = SyncExistingOfficers()
    
    lib.notify(src, {
        title = 'Police Management',
        description = 'Synced ' .. syncedCount .. ' officers from your department.',
        type = 'success'
    })
end, false)

-- Admin command to sync all police officers
RegisterCommand('syncpolice', function(source, args)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    
    if not player then return end
    
    -- Check if player is admin (you can modify this check as needed)
    if not exports.qbx_core:HasPermission(src, 'admin') then
        lib.notify(src, {
            title = 'Police Management',
            description = 'You do not have permission to use this command.',
            type = 'error'
        })
        return
    end
    
    local syncedCount = SyncExistingOfficers()
    
    lib.notify(src, {
        title = 'Police Management',
        description = 'Synced ' .. syncedCount .. ' police officers to database.',
        type = 'success'
    })
end, false)

-- Export functions for other resources
exports('GetDepartmentOfficers', GetDepartmentOfficers)
exports('GetOfficerInfo', GetOfficerInfo)
exports('IsCallsignAvailable', IsCallsignAvailable)
exports('UpdateOfficerCallsign', UpdateOfficerCallsign)
exports('UpdateOfficerGrade', UpdateOfficerGrade)
exports('TerminateOfficer', TerminateOfficer)
exports('AddOfficer', AddOfficer)
