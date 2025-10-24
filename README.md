# qbx_police_management

A comprehensive police management system for QBOX framework that allows police department leaders to manage officers, assign or edit callsigns, and fire officers directly from an in-game panel, all synchronized live with the database.

## Features

🔹 **Clean and Responsive NUI Panel** - Modern interface with fade animations and popup editing
🔹 **Real-time Updates** - All connected officers receive live updates
🔹 **Secure Permission Logic** - Only higher ranks can manage callsigns and officers
🔹 **Full Database Integration** - Auto job removal when officers are fired
🔹 **Multi-Department Support** - Works with LSPD, BCSO, and SASP
🔹 **Callsign Management** - Assign, update, and track officer callsigns
🔹 **Rank Management** - Promote and demote officers with proper permissions
🔹 **Officer Termination** - Remove officers from the force with database cleanup

## Dependencies

- [qbx_core](https://github.com/Qbox-project/qbx_core)
- [ox_lib](https://github.com/communityox/ox_lib)
- [oxmysql](https://github.com/CommunityOx/oxmysql)

## Installation

1. Place the `qbx_police_management` folder in your `resources` directory
2. Add `ensure qbx_police_management` to your `server.cfg`
3. Restart your server

## Configuration

### Shared Config (`config/shared.lua`)

```lua
-- Police departments that can use this management system
policeDepartments = {
    'police',
    'bcso', 
    'sasp'
},

-- Minimum rank required to access management panel
minManagementRank = 2, -- Sergeant and above

-- Minimum rank required to fire officers
minFireRank = 3, -- Lieutenant and above

-- Minimum rank required to assign callsigns
minCallsignRank = 1, -- Officer and above
```

### Client Config (`config/client.lua`)

```lua
-- Key to open police management panel
openKey = 'F6',

-- Command to open police management panel
openCommand = 'policemgmt',

-- Locations where the management panel can be opened
allowedLocations = {
    {
        name = 'Mission Row PD',
        coords = vector3(441.7, -982.3, 30.7),
        radius = 10.0
    }
}
```

## Usage

### Opening the Management Panel

- **Key**: Press `F6` (configurable)
- **Command**: `/policemgmt`
- **Location**: Must be at a configured police station

### Managing Officers

1. **View Officers**: See all department officers with their status, rank, and callsign
2. **Add Officers**: Hire new officers with specific ranks and callsigns
3. **Update Callsigns**: Change officer callsigns with validation
4. **Promote/Demote**: Change officer ranks with permission checks
5. **Terminate Officers**: Remove officers from the force with database cleanup

### Permission System

- **Sergeant+ (Rank 2+)**: Can access management panel and assign callsigns
- **Lieutenant+ (Rank 3+)**: Can fire officers and manage ranks
- **Chief (Rank 4)**: Full access to all management features

## Database Schema

The system automatically creates the following tables:

### `police_officers`
- `id` - Primary key
- `citizenid` - Player's citizen ID
- `job` - Police department (police, bcso, sasp)
- `grade` - Officer rank level
- `callsign` - Officer callsign
- `status` - active/suspended/terminated
- `hired_by` - Who hired the officer
- `hired_date` - When they were hired
- `last_updated` - Last modification timestamp

### `police_callsigns`
- `id` - Primary key
- `callsign` - The callsign text
- `job` - Department
- `citizenid` - Officer's citizen ID
- `assigned_date` - When assigned
- `assigned_by` - Who assigned it

## Commands

- `/policemgmt` - Open police management panel
- `/syncpolice` - Admin command to sync all police officers (admin only)

## Events

### Server Events
- `police_management:server:getOfficers` - Get department officers
- `police_management:server:updateCallsign` - Update officer callsign
- `police_management:server:updateRank` - Update officer rank
- `police_management:server:terminateOfficer` - Terminate officer
- `police_management:server:addOfficer` - Add new officer

### Client Events
- `police_management:client:receiveOfficers` - Receive officer list
- `police_management:client:receiveOfficerDetails` - Receive officer details

## Exports

### Server Exports
```lua
-- Get all officers for a department
exports['qbx_police_management']:GetDepartmentOfficers(job)

-- Get officer information
exports['qbx_police_management']:GetOfficerInfo(citizenid, job)

-- Check if callsign is available
exports['qbx_police_management']:IsCallsignAvailable(callsign, job, excludeCitizenid)

-- Update officer callsign
exports['qbx_police_management']:UpdateOfficerCallsign(citizenid, job, newCallsign, updatedBy)

-- Update officer grade
exports['qbx_police_management']:UpdateOfficerGrade(citizenid, job, newGrade, updatedBy)

-- Terminate officer
exports['qbx_police_management']:TerminateOfficer(citizenid, job, terminatedBy)

-- Add officer
exports['qbx_police_management']:AddOfficer(citizenid, job, grade, callsign, hiredBy)
```

### Client Exports
```lua
-- Check if management panel is open
exports['qbx_police_management']:IsManagementOpen()

-- Open management panel
exports['qbx_police_management']:OpenManagement()

-- Close management panel
exports['qbx_police_management']:CloseManagement()
```

## Localization

The system supports multiple languages through the `locales/` directory:
- `en.json` - English
- `es.json` - Spanish

## Security Features

- **Permission-based Access**: Only authorized ranks can perform actions
- **Location Restrictions**: Management panel only works at police stations
- **Callsign Validation**: Prevents duplicate callsigns and enforces format rules
- **Rank Hierarchy**: Prevents promoting officers above your own rank
- **Database Integrity**: Automatic cleanup when officers are terminated

## Troubleshooting

### Common Issues

1. **Panel won't open**: Check if you're at an allowed location and have proper rank
2. **Callsign not updating**: Ensure callsign format is correct and not already in use
3. **Permission denied**: Verify your rank meets the minimum requirements
4. **Database errors**: Check MySQL connection and table creation

### Debug Commands

- `/syncpolice` - Force sync all police officers (admin only)
- Check server console for database initialization messages

## Support

For support and updates, visit the [QBOX Discord](https://discord.gg/qbox) or create an issue on the GitHub repository.

## License

This resource is part of the QBOX framework and follows the same licensing terms.
