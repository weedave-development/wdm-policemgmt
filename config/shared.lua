return {
    -- Police departments that can use this management system
    policeDepartments = {
        'police',
        'bcso', 
        'sasp'
    },
    
    -- Minimum rank required to access management panel
    minManagementRank = 0, -- All ranks can access (change to 2 for Sergeant+ only)
    
    -- Minimum rank required to fire officers
    minFireRank = 3, -- Lieutenant and above
    
    -- Minimum rank required to assign callsigns
    minCallsignRank = 1, -- Officer and above
    
    -- Maximum callsign length
    maxCallsignLength = 10,
    
    -- Minimum callsign length
    minCallsignLength = 2,
    
    -- Allowed callsign characters (alphanumeric and dash only)
    callsignPattern = '^[A-Z0-9%-]+$',
    
    -- Database table names
    database = {
        officers = 'police_officers',
        callsigns = 'police_callsigns'
    },
    
    -- NUI settings
    nui = {
        fadeTime = 300, -- milliseconds
        animationDuration = 200 -- milliseconds
    }
}
