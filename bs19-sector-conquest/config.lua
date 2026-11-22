ConquestConfig = {}

-- Enable verbose FiveM console logs for capture state changes & payouts
ConquestConfig.Debug = true

-- Seconds an attacking faction must hold the capture circle uncontested
ConquestConfig.CaptureDurationSeconds = 180

-- Minutes of post-capture immunity shield before a sector can be contested again
ConquestConfig.ShieldDurationMinutes = 120

-- Minimum online members of the defending faction required to start a takeover (0 = always allowed)
ConquestConfig.MinOnlineDefenders = 0

-- Interval (minutes) for depositing passive sector tax into bs_faction_banks
ConquestConfig.PayoutIntervalMinutes = 60

-- Control key used to start capturing when standing inside a sector ring (38 = E)
ConquestConfig.CaptureKey = 38

-- Blip color IDs per state (GTA V HUD blip colors)
ConquestConfig.BlipColors = {
    Neutral   = 40, -- Slate Grey
    Owned     = 47, -- Tactical Amber
    Contested = 1,  -- Flashing Crimson
    Shielded  = 2,  -- Secured Green
}

-- =============================================================================
-- STRATEGIC SAN ANDREAS CONTROL SECTORS (Risk-Style Territory Perks)
-- Each sector provides both an hourly bs_faction_banks tax payout AND a real
-- perk queryable by any BS19 resource via exports['bs19-sector-conquest'].
-- =============================================================================
ConquestConfig.Sectors = {
    {
        id = 'paleto_sawmill',
        label = 'Paleto Bay Sawmill',
        region = 'Blaine County North',
        coords = vector3(-558.4, 5348.2, 70.2),
        radius = 45.0,
        hourlyPayout = 2500,
        perkKey = 'build_yield',
        perkMultiplier = 1.25,
        perkLabel = '+25% Building & Salvage Yield',
        perkSummary = 'Controlling faction receives +25% timber & salvage yield and $2,500/hr treasury tax.'
    },
    {
        id = 'sandy_airfield',
        label = 'Sandy Shores Airfield',
        region = 'Grand Senora Desert',
        coords = vector3(1734.5, 3294.8, 41.2),
        radius = 55.0,
        hourlyPayout = 3500,
        perkKey = 'loot_speed',
        perkMultiplier = 1.15,
        perkLabel = '+15% Airdrop & Crate Loot Speed',
        perkSummary = 'Controlling faction unlocks supply drops and crates 15% faster plus $3,500/hr treasury tax.'
    },
    {
        id = 'bolingbroke_prison',
        label = 'Bolingbroke Penitentiary',
        region = 'Senora Freeway',
        coords = vector3(1690.2, 2591.4, 45.6),
        radius = 55.0,
        hourlyPayout = 4500,
        perkKey = 'ammo_supply',
        perkMultiplier = 1.20,
        perkLabel = '+20% Armory Craft & Munitions Yield',
        perkSummary = 'Controlling faction gains +20% munitions craft efficiency and $4,500/hr treasury tax.'
    },
    {
        id = 'thomson_scrapyard',
        label = 'Thomson Scrapyard',
        region = 'East Senora',
        coords = vector3(2352.1, 3133.6, 48.2),
        radius = 45.0,
        hourlyPayout = 3000,
        perkKey = 'scrap_efficiency',
        perkMultiplier = 1.25,
        perkLabel = '+25% Scrap & Vehicle Repair Efficiency',
        perkSummary = 'Controlling faction earns +25% scrap dismantling & repair speed plus $3,000/hr treasury tax.'
    },
    {
        id = 'palmer_taylor_grid',
        label = 'Palmer-Taylor Power Relay',
        region = 'East Coast Industrial',
        coords = vector3(2742.0, 1518.4, 24.5),
        radius = 50.0,
        hourlyPayout = 5000,
        perkKey = 'xp_boost',
        perkMultiplier = 1.20,
        perkLabel = '+20% Wasteland Pass & Survival XP',
        perkSummary = 'Controlling faction receives +20% Wasteland Pass & survival XP plus $5,000/hr treasury tax.'
    },
    {
        id = 'port_of_ls',
        label = 'Port of Los Santos',
        region = 'South Docks',
        coords = vector3(842.6, -2986.4, 5.9),
        radius = 60.0,
        hourlyPayout = 4000,
        perkKey = 'vending_rebate',
        perkMultiplier = 1.50,
        perkLabel = '-50% Vending Tax & Trade Rebate',
        perkSummary = 'Controlling faction cuts offline vending fees in half and collects $4,000/hr port tax.'
    }
}
