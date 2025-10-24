return {
    -- Key to open police management panel
    openKey = 'F6',
    
    -- Command to open police management panel
    openCommand = 'policemgmt',
    
    -- Location requirement settings
    locationRequirement = {
        enabled = true, -- Set to false to disable location requirement
        message = 'You must be at a police station to access the management system.'
    },
    
    -- Locations where the management panel can be opened
    allowedLocations = {
        {
            name = 'Mission Row PD',
            coords = vector3(441.7, -982.3, 30.7),
            radius = 10.0
        },
        {
            name = 'Sandy Shores Sheriff',
            coords = vector3(1853.2, 3689.5, 34.3),
            radius = 10.0
        },
        {
            name = 'Paleto Bay Sheriff',
            coords = vector3(-448.1, 6014.3, 31.7),
            radius = 10.0
        }
    },
    
    -- Blip settings for management locations
    blips = {
        enabled = true,
        sprite = 60,
        color = 3,
        scale = 0.8,
        name = 'Police Management'
    }
}
