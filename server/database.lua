local sharedConfig = require 'config.shared'

-- Create database tables if they don't exist
CreateThread(function()
    -- Police officers table
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `police_officers` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `citizenid` varchar(50) NOT NULL,
            `job` varchar(50) NOT NULL,
            `grade` int(11) NOT NULL DEFAULT 0,
            `callsign` varchar(20) DEFAULT NULL,
            `status` enum('active','suspended','terminated') DEFAULT 'active',
            `hired_by` varchar(50) DEFAULT NULL,
            `hired_date` timestamp DEFAULT CURRENT_TIMESTAMP,
            `last_updated` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `citizenid_job` (`citizenid`, `job`),
            KEY `status` (`status`),
            KEY `job` (`job`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    
    -- Police callsigns table for tracking callsign usage
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `police_callsigns` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `callsign` varchar(20) NOT NULL,
            `job` varchar(50) NOT NULL,
            `citizenid` varchar(50) NOT NULL,
            `assigned_date` timestamp DEFAULT CURRENT_TIMESTAMP,
            `assigned_by` varchar(50) DEFAULT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `callsign_job` (`callsign`, `job`),
            KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    
    print('^2[Police Management]^7 Database tables initialized successfully')
end)

-- Get all officers for a specific department
function GetDepartmentOfficers(job)
    local result = MySQL.query.await('SELECT * FROM police_officers WHERE job = ? AND status = "active" ORDER BY grade DESC, hired_date ASC', {job})
    print(string.format('[Police Management] Found %d officers for job: %s', #(result or {}), job))
    return result or {}
end

-- Get officer information by citizenid
function GetOfficerInfo(citizenid, job)
    local result = MySQL.query.await('SELECT * FROM police_officers WHERE citizenid = ? AND job = ?', {citizenid, job})
    return result[1]
end

-- Add officer to database
function AddOfficer(sourceId, job, grade, callsign, hiredBy)
    local player = exports.qbx_core:GetPlayer(sourceId)
    if not player then
        return false, "Player not found"
    end
    
    local citizenid = player.PlayerData.citizenid
    local query = [[
        INSERT INTO police_officers (citizenid, job, grade, callsign, hired_by) 
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE 
        grade = VALUES(grade), 
        callsign = VALUES(callsign), 
        status = 'active',
        hired_by = VALUES(hired_by),
        last_updated = CURRENT_TIMESTAMP
    ]]
    
    local result = MySQL.insert.await(query, {citizenid, job, grade, callsign, hiredBy})
    
    if callsign then
        -- Update callsign tracking
        MySQL.query.await([[
            INSERT INTO police_callsigns (callsign, job, citizenid, assigned_by) 
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE 
            citizenid = VALUES(citizenid),
            assigned_by = VALUES(assigned_by),
            assigned_date = CURRENT_TIMESTAMP
        ]], {callsign, job, citizenid, hiredBy})
    end
    
    return result, "Officer added successfully"
end

-- Update officer grade
function UpdateOfficerGrade(citizenid, job, newGrade, updatedBy)
    local query = 'UPDATE police_officers SET grade = ?, last_updated = CURRENT_TIMESTAMP WHERE citizenid = ? AND job = ?'
    return MySQL.update.await(query, {newGrade, citizenid, job})
end

-- Update officer callsign
function UpdateOfficerCallsign(citizenid, job, newCallsign, updatedBy)
    -- First, remove old callsign
    MySQL.query.await('DELETE FROM police_callsigns WHERE citizenid = ? AND job = ?', {citizenid, job})
    
    -- Update officer record
    local result = MySQL.update.await('UPDATE police_officers SET callsign = ?, last_updated = CURRENT_TIMESTAMP WHERE citizenid = ? AND job = ?', {newCallsign, citizenid, job})
    
    -- Add new callsign tracking
    if newCallsign then
        MySQL.query.await([[
            INSERT INTO police_callsigns (callsign, job, citizenid, assigned_by) 
            VALUES (?, ?, ?, ?)
        ]], {newCallsign, job, citizenid, updatedBy})
    end
    
    return result
end

-- Terminate officer
function TerminateOfficer(citizenid, job, terminatedBy)
    -- Update officer status
    local result = MySQL.update.await('UPDATE police_officers SET status = "terminated", last_updated = CURRENT_TIMESTAMP WHERE citizenid = ? AND job = ?', {citizenid, job})
    
    -- Remove callsign tracking
    MySQL.query.await('DELETE FROM police_callsigns WHERE citizenid = ? AND job = ?', {citizenid, job})
    
    return result
end

-- Check if callsign is available
function IsCallsignAvailable(callsign, job, excludeCitizenid)
    local query = 'SELECT COUNT(*) as count FROM police_callsigns WHERE callsign = ? AND job = ?'
    local params = {callsign, job}
    
    if excludeCitizenid then
        query = query .. ' AND citizenid != ?'
        table.insert(params, excludeCitizenid)
    end
    
    local result = MySQL.query.await(query, params)
    return result[1].count == 0
end

-- Get callsign history for an officer
function GetOfficerCallsignHistory(citizenid, job)
    local result = MySQL.query.await('SELECT * FROM police_callsigns WHERE citizenid = ? AND job = ? ORDER BY assigned_date DESC', {citizenid, job})
    return result or {}
end

-- Sync existing police officers to database
function SyncExistingOfficers()
    local sharedConfig = require 'config.shared'
    local syncedCount = 0
    
    for _, dept in pairs(sharedConfig.policeDepartments) do
        local players = exports.qbx_core:GetQBPlayers()
        
        for _, player in pairs(players) do
            if player.PlayerData.job.name == dept then
                local citizenid = player.PlayerData.citizenid
                local job = player.PlayerData.job.name
                local grade = player.PlayerData.job.grade.level
                local callsign = player.PlayerData.metadata.callsign or ''
                
                -- Check if officer already exists in database
                local existingOfficer = GetOfficerInfo(citizenid, job)
                
                if not existingOfficer then
                    -- Add officer to database
                    local success = MySQL.insert.await([[
                        INSERT INTO police_officers (citizenid, job, grade, callsign, hired_by, status) 
                        VALUES (?, ?, ?, ?, 'system', 'active')
                    ]], {citizenid, job, grade, callsign})
                    
                    if success then
                        syncedCount = syncedCount + 1
                        print(string.format('[Police Management] Synced officer: %s (%s) - %s', 
                            player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
                            citizenid, job))
                    end
                else
                    -- Update existing officer if needed
                    if existingOfficer.grade ~= grade or existingOfficer.callsign ~= callsign then
                        MySQL.update.await([[
                            UPDATE police_officers 
                            SET grade = ?, callsign = ?, last_updated = CURRENT_TIMESTAMP 
                            WHERE citizenid = ? AND job = ?
                        ]], {grade, callsign, citizenid, job})
                        
                        print(string.format('[Police Management] Updated officer: %s (%s)', 
                            player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname, citizenid))
                    end
                end
            end
        end
    end
    
    print(string.format('[Police Management] Synced %d existing officers to database', syncedCount))
    return syncedCount
end
