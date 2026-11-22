-- =============================================================================
-- BS19 - Sector Conquest (Developed by Trident40)
-- Client Map Territory Blips, 3D Capture Ring & Live Capture Progress HUD
-- =============================================================================

local SectorSnapshot = {}
local RadiusBlips = {}
local CenterBlips = {}

local function clearBlips()
    for _, blip in pairs(RadiusBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    for _, blip in pairs(CenterBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    RadiusBlips = {}
    CenterBlips = {}
end

local function refreshTerritoryBlips()
    clearBlips()

    for _, cfg in ipairs(ConquestConfig.Sectors) do
        local st = SectorSnapshot[cfg.id] or {}
        local color = ConquestConfig.BlipColors.Neutral
        local suffix = 'Unclaimed'

        if st.status == 'CONTESTED' then
            color = ConquestConfig.BlipColors.Contested
            suffix = ('CONTESTED (%s)'):format(st.attackerLabel or 'Raid')
        elseif st.ownerFactionId then
            if (st.shieldMinutes or 0) > 0 then
                color = ConquestConfig.BlipColors.Shielded
                suffix = ('%s [Shield %dm]'):format(st.ownerLabel or st.ownerFactionId, st.shieldMinutes)
            else
                color = ConquestConfig.BlipColors.Owned
                suffix = st.ownerLabel or st.ownerFactionId
            end
        end

        local areaBlip = AddBlipForRadius(cfg.coords.x, cfg.coords.y, cfg.coords.z, cfg.radius)
        SetBlipColour(areaBlip, color)
        SetBlipAlpha(areaBlip, st.status == 'CONTESTED' and 140 or 90)
        if st.status == 'CONTESTED' then
            SetBlipFlashes(areaBlip, true)
        end
        RadiusBlips[cfg.id] = areaBlip

        local pinBlip = AddBlipForCoord(cfg.coords.x, cfg.coords.y, cfg.coords.z)
        SetBlipSprite(pinBlip, 310) -- Strategic Territory Flag
        SetBlipDisplay(pinBlip, 4)
        SetBlipScale(pinBlip, 0.85)
        SetBlipColour(pinBlip, color)
        SetBlipAsShortRange(pinBlip, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(('Sector: %s — %s'):format(cfg.label, suffix))
        EndTextCommandSetBlipName(pinBlip)
        CenterBlips[cfg.id] = pinBlip
    end
end

RegisterNetEvent('bs19_conquest:syncState', function(snapshot)
    SectorSnapshot = snapshot or {}
    refreshTerritoryBlips()
end)

AddEventHandler('onClientResourceStart', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    TriggerServerEvent('bs19_conquest:requestSync')
end)

AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    clearBlips()
end)

local function drawHudText(x, y, text, scale, r, g, b)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, 255)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

-- Main proximity loop: renders 3D capture circle & on-screen tactical progress bar
CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for _, cfg in ipairs(ConquestConfig.Sectors) do
            local dist = #(coords - cfg.coords)
            if dist < (cfg.radius + 40.0) then
                sleep = 0
                local st = SectorSnapshot[cfg.id] or {}
                local r, g, b = 217, 119, 6
                if st.status == 'CONTESTED' then
                    r, g, b = 220, 38, 38
                elseif (st.shieldMinutes or 0) > 0 then
                    r, g, b = 22, 163, 74
                end

                DrawMarker(
                    1,
                    cfg.coords.x, cfg.coords.y, cfg.coords.z - 1.0,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    cfg.radius * 2.0, cfg.radius * 2.0, 1.8,
                    r, g, b, 65,
                    false, false, 2, false, nil, nil, false
                )

                if dist <= cfg.radius then
                    -- Top-center compact tactical sector banner
                    DrawRect(0.5, 0.075, 0.28, 0.068, 12, 14, 17, 210)
                    drawHudText(0.5, 0.046, ('SECTOR: %s'):format(cfg.label:upper()), 0.42, 245, 246, 248)

                    if st.status == 'CONTESTED' then
                        local pct = tonumber(st.captureProgress) or 0
                        local barWidth = 0.24 * (pct / 100.0)
                        DrawRect(0.5, 0.088, 0.24, 0.012, 35, 41, 50, 230)
                        DrawRect(0.5 - (0.24 - barWidth) / 2.0, 0.088, barWidth, 0.012, 220, 38, 38, 255)
                        local stateMsg = st.contested
                            and ('CONTESTED — DEFENDERS IN ZONE (%d%%)'):format(pct)
                            or ('CAPTURING (%s): %d%%'):format(st.attackerLabel or 'Faction', pct)
                        drawHudText(0.5, 0.095, stateMsg, 0.32, 252, 165, 165)
                    elseif (st.shieldMinutes or 0) > 0 then
                        drawHudText(
                            0.5, 0.078,
                            ('OWNER: %s  |  SHIELDED: %dm  |  %s'):format(st.ownerLabel or 'Unknown', st.shieldMinutes, cfg.perkLabel),
                            0.32, 134, 239, 172
                        )
                    else
                        drawHudText(
                            0.5, 0.078,
                            ('OWNER: %s  |  [E] CONTEST SECTOR  |  %s'):format(st.ownerLabel or 'Unclaimed', cfg.perkLabel),
                            0.32, 253, 224, 71
                        )
                        if IsControlJustReleased(0, ConquestConfig.CaptureKey) then
                            TriggerServerEvent('bs19_conquest:startCapture', cfg.id)
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- Client chat command to inspect live sectors & perks anytime
RegisterCommand('sectors', function()
    TriggerEvent('chat:addMessage', {
        color = { 217, 119, 6 },
        args = { 'BS19 - Sector Conquest', 'Live Strategic Territory Control:' }
    })
    for _, cfg in ipairs(ConquestConfig.Sectors) do
        local st = SectorSnapshot[cfg.id] or {}
        local owner = st.ownerLabel or 'Unclaimed'
        local status = st.status == 'CONTESTED' and 'CONTESTED' or ((st.shieldMinutes or 0) > 0 and ('Shield ' .. st.shieldMinutes .. 'm') or 'Open')
        TriggerEvent('chat:addMessage', {
            color = { 229, 231, 235 },
            args = { cfg.label, ('Owner: %s (%s) | %s | $%d/hr'):format(owner, status, cfg.perkLabel, cfg.hourlyPayout) }
        })
    end
end, false)
