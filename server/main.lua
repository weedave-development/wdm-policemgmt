local sharedConfig = require 'config.shared'

-- Permission checking functions
local function HasManagementPermission(player)
    local job = player.PlayerData.job
    if not job then
        return false
    end
    
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

local function HasFirePermission(player)
    local job = player.PlayerData.job
    if not job then
        return false
    end
    
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
    
    return job.grade.level >= sharedConfig.minFireRank
end

local function HasCallsignPermission(player)
    local job = player.PlayerData.job
    if not job then
        return false
    end
    
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
    
    return job.grade.level >= sharedConfig.minCallsignRank
end

-- Get department officers
RegisterNetEvent('police_management:server:getOfficers', function()
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    
    -- Always print debug info for troubleshooting
    local job = player.PlayerData.job
    local debugInfo = string.format(
        "[Police Management Debug] Player: %s, Job: %s, Grade: %s, Required: %s, Departments: %s",
        player.PlayerData.charinfo.firstname .. " " .. player.PlayerData.charinfo.lastname,
        job and job.name or "nil",
        job and job.grade.level or "nil", 
        sharedConfig.minManagementRank,
        table.concat(sharedConfig.policeDepartments, ",")
    )
    print(debugInfo)
    
    if not HasManagementPermission(player) then
        lib.notify(src, {
            title = 'Police Management',
            description = 'You do not have permission to access this system.',
            type = 'error'
        })
        return
    end
    
    local job = player.PlayerData.job.name
    local officers = GetDepartmentOfficers(job)
    
    print(string.format('[Police Management] Sending %d officers to client %s for job %s', #officers, src, job))
    
    -- Enrich officer data with online status and player names
    local enrichedOfficers = {}
    for _, officer in pairs(officers) do
        local onlinePlayer = exports.qbx_core:GetPlayerByCitizenId(officer.citizenid)
        local isOnline = onlinePlayer ~= nil
        
        enrichedOfficers[#enrichedOfficers + 1] = {
            citizenid = officer.citizenid,
            job = officer.job,
            grade = officer.grade,
            callsign = officer.callsign,
            status = officer.status,
            hiredDate = officer.hired_date,
            isOnline = isOnline,
            playerName = isOnline and onlinePlayer.PlayerData.charinfo.firstname .. ' ' .. onlinePlayer.PlayerData.charinfo.lastname or 'Offline'
        }
    end
    
    print(string.format('[Police Management] Enriched %d officers for client', #enrichedOfficers))
    TriggerClientEvent('police_management:client:receiveOfficers', src, enrichedOfficers)
end)

-- Update officer callsign
RegisterNetEvent('police_management:server:updateCallsign', function(targetCitizenid, newCallsign)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    
    if not HasCallsignPermission(player) then
        lib.notify(src, {
            title = 'Police Management',
            description = 'You do not have permission to assign callsigns.',
            type = 'error'
        })
        return
    end
    
    -- Validate callsign format
    if not newCallsign or #newCallsign < sharedConfig.minCallsignLength or #newCallsign > sharedConfig.maxCallsignLength then
        lib.notify(src, {
            title = 'Police Management',
            description = 'Invalid callsign format. Must be 2-10 characters.',
            type = 'error'
        })
        return
    end
    
    if not string.match(newCallsign, sharedConfig.callsignPattern) then
        lib.notify(src, {
            title = 'Police Management',
            description = 'Callsign can only contain letters, numbers, and dashes.',
            type = 'error'
        })
        return
    end
    
    local job = player.PlayerData.job.name
    
    -- Check if callsign is available
    if not IsCallsignAvailable(newCallsign, job, targetCitizenid) then
        lib.notify(src, {
            title = 'Police Management',
            description = 'Callsign "' .. newCallsign .. '" is already in use.',
            type = 'error'
        })
        return
    end
    
    -- Update callsign in database
    local success = UpdateOfficerCallsign(targetCitizenid, job, newCallsign, player.PlayerData.citizenid)
    
    if success then
        -- Update player's metadata if online
        local targetPlayer = exports.qbx_core:GetPlayerByCitizenId(targetCitizenid)
        if targetPlayer then
            targetPlayer.Functions.SetMetaData('callsign', newCallsign)
        end
        
        -- Notify all department members
        local departmentPlayers = exports.qbx_core:GetQBPlayers()
        for _, deptPlayer in pairs(departmentPlayers) do
            if deptPlayer.PlayerData.job.name == job and deptPlayer.PlayerData.job.onduty then
                lib.notify(deptPlayer.PlayerData.source, {
                    title = 'Police Management',
                    description = 'Officer callsign updated: ' .. newCallsign,
                    type = 'success'
                })
            end
        end
        
        lib.notify(src, {
            title = 'Police Management',
            description = 'Callsign updated successfully.',
            type = 'success'
        })
    else
        lib.notify(src, {
            title = 'Police Management',
            description = 'Failed to update callsign.',
            type = 'error'
        })
    end
end)

-- Update officer rank
RegisterNetEvent('police_management:server:updateRank', function(targetCitizenid, newGrade)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    
    if not HasManagementPermission(player) then
        lib.notify(src, {
            title = 'Police Management',
            description = 'You do not have permission to change ranks.',
            type = 'error'
        })
        return
    end
    
    -- Validate grade
    local job = player.PlayerData.job.name
    local jobData = exports.qbx_core:GetJob(job)
    if not jobData or not jobData.grades[newGrade] then
        lib.notify(src, {
            title = 'Police Management',
            description = 'Invalid rank specified.',
            type = 'error'
        })
        return
    end
    
    -- Check if trying to promote to higher rank than self
    if newGrade > player.PlayerData.job.grade.level then
        lib.notify(src, {
            title = 'Police Management',
            description = 'You cannot promote someone to a higher rank than yourself.',
            type = 'error'
        })
        return
    end
    
    local success = UpdateOfficerGrade(targetCitizenid, job, newGrade, player.PlayerData.citizenid)
    
    if success then
        -- Update player's job grade if online
        local targetPlayer = exports.qbx_core:GetPlayerByCitizenId(targetCitizenid)
        if targetPlayer then
            targetPlayer.Functions.SetJob(job, newGrade)
        end
        
        lib.notify(src, {
            title = 'Police Management',
            description = 'Officer rank updated successfully.',
            type = 'success'
        })
    else
        lib.notify(src, {
            title = 'Police Management',
            description = 'Failed to update officer rank.',
            type = 'error'
        })
    end
end)

-- Terminate officer
RegisterNetEvent('police_management:server:terminateOfficer', function(targetCitizenid)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    
    if not HasFirePermission(player) then
        lib.notify(src, {
            title = 'Police Management',
            description = 'You do not have permission to terminate officers.',
            type = 'error'
        })
        return
    end
    
    local job = player.PlayerData.job.name
    local success = TerminateOfficer(targetCitizenid, job, player.PlayerData.citizenid)
    
    if success then
        -- Remove job from player if online
        local targetPlayer = exports.qbx_core:GetPlayerByCitizenId(targetCitizenid)
        if targetPlayer then
            targetPlayer.Functions.SetJob('unemployed', 0)
            lib.notify(targetPlayer.PlayerData.source, {
                title = 'Police Management',
                description = 'You have been terminated from the police force.',
                type = 'error'
            })
        end
        
        -- Notify all department members
        local departmentPlayers = exports.qbx_core:GetQBPlayers()
        for _, deptPlayer in pairs(departmentPlayers) do
            if deptPlayer.PlayerData.job.name == job and deptPlayer.PlayerData.job.onduty then
                lib.notify(deptPlayer.PlayerData.source, {
                    title = 'Police Management',
                    description = 'An officer has been terminated from the force.',
                    type = 'inform'
                })
            end
        end
        
        lib.notify(src, {
            title = 'Police Management',
            description = 'Officer terminated successfully.',
            type = 'success'
        })
    else
        lib.notify(src, {
            title = 'Police Management',
            description = 'Failed to terminate officer.',
            type = 'error'
        })
    end
end)

-- Add new officer
RegisterNetEvent('police_management:server:addOfficer', function(targetSourceId, grade, callsign)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    
    if not HasManagementPermission(player) then
        lib.notify(src, {
            title = 'Police Management',
            description = 'You do not have permission to hire officers.',
            type = 'error'
        })
        return
    end
    
    local job = player.PlayerData.job.name
    
    -- Validate callsign if provided
    if callsign and callsign ~= '' then
        if not string.match(callsign, sharedConfig.callsignPattern) then
            lib.notify(src, {
                title = 'Police Management',
                description = 'Callsign can only contain letters, numbers, and dashes.',
                type = 'error'
            })
            return
        end
        
        if not IsCallsignAvailable(callsign, job) then
            lib.notify(src, {
                title = 'Police Management',
                description = 'Callsign "' .. callsign .. '" is already in use.',
                type = 'error'
            })
            return
        end
    end
    
    local success, message = AddOfficer(targetSourceId, job, grade, callsign, player.PlayerData.citizenid)
    
    if success then
        -- Set player's job if online
        local targetPlayer = exports.qbx_core:GetPlayer(targetSourceId)
        if targetPlayer then
            targetPlayer.Functions.SetJob(job, grade)
            if callsign then
                targetPlayer.Functions.SetMetaData('callsign', callsign)
            end
        end
        
        lib.notify(src, {
            title = 'Police Management',
            description = message,
            type = 'success'
        })
    else
        lib.notify(src, {
            title = 'Police Management',
            description = message or 'Failed to add officer.',
            type = 'error'
        })
    end
end)

-- Get officer details
RegisterNetEvent('police_management:server:getOfficerDetails', function(targetCitizenid)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    
    if not HasManagementPermission(player) then
        return
    end
    
    local job = player.PlayerData.job.name
    local officerInfo = GetOfficerInfo(targetCitizenid, job)
    
    if officerInfo then
        local callsignHistory = GetOfficerCallsignHistory(targetCitizenid, job)
        TriggerClientEvent('police_management:client:receiveOfficerDetails', src, officerInfo, callsignHistory)
    end
end)
