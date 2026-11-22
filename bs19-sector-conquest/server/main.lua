-- =============================================================================
-- BS19 - Sector Conquest (Developed by Trident40)
-- Server-Authoritative Risk-Style Territory Control, Perks & Treasury Payouts
-- =============================================================================

local RESOURCE_NAME = GetCurrentResourceName()
local SectorsState = {}   -- [sectorId] = runtime + DB state
local ActiveCaptures = {} -- [sectorId] = { attackerId, attackerLabel, attackerShort, progress, contested, startedBy, startedByName }

local function dbg(fmt, ...)
    if not ConquestConfig.Debug then return end
    print(('^3[%s] ' .. fmt .. '^7'):format(RESOURCE_NAME, ...))
end

local function hasOxMysql()
    return GetResourceState('oxmysql') == 'started' and exports.oxmysql ~= nil
end

local function dbQuery(sql, params)
    if not hasOxMysql() then return {} end
    local ok, res = pcall(function()
        return exports.oxmysql:query_async(sql, params or {})
    end)
    if ok and type(res) == 'table' then return res end
    return {}
end

local function dbExecute(sql, params)
    if not hasOxMysql() then return end
    pcall(function()
        exports.oxmysql:execute_async(sql, params or {})
    end)
end

local function getSectorConfig(sectorId)
    for _, s in ipairs(ConquestConfig.Sectors) do
        if s.id == sectorId then return s end
    end
    return nil
end

local function formatCoords(vec)
    return ('X: %.1f, Y: %.1f'):format(vec.x, vec.y)
end

-- Resolve a FiveM player's active BS19 character & faction (zero-edit Arcainex/bs19)
local function getPlayerFactionInfo(src)
    local charId = nil
    local charName = GetPlayerName(src) or ('Survivor #' .. tostring(src))

    if GetResourceState('bs_core') == 'started' then
        local ok, p = pcall(function() return exports.bs_core:GetPlayer(src) end)
        if ok and type(p) == 'table' then
            charId = tonumber(p.charId or p.char_id or p.id or (p.char and p.char.id))
            if p.first_name and p.last_name then
                charName = p.first_name .. ' ' .. p.last_name
            elseif p.char and p.char.first_name then
                charName = p.char.first_name .. ' ' .. (p.char.last_name or '')
            end
        end
    end

    if not charId then
        local license = GetPlayerIdentifierByType(src, 'license')
        if license then
            local rows = dbQuery([[
                SELECT c.id, CONCAT(c.first_name, ' ', c.last_name) AS full_name
                FROM bs_users u
                JOIN bs_characters c ON c.user_id = u.id AND c.deleted_at IS NULL
                WHERE u.identifier = ?
                ORDER BY c.last_played DESC
                LIMIT 1
            ]], { license })
            if rows[1] then
                charId = tonumber(rows[1].id)
                if rows[1].full_name and rows[1].full_name ~= ' ' then
                    charName = rows[1].full_name
                end
            end
        end
    end

    if not charId then return nil end

    local fRows = dbQuery([[
        SELECT m.faction_id, m.rank, r.label AS faction_label, r.short AS faction_short
        FROM bs_faction_members m
        LEFT JOIN bs_faction_registry r ON r.faction_id = m.faction_id
        WHERE m.character_id = ?
        LIMIT 1
    ]], { charId })

    local f = fRows[1]
    if not f or not f.faction_id then
        return { charId = charId, charName = charName, factionId = nil }
    end

    return {
        charId = charId,
        charName = charName,
        factionId = f.faction_id,
        factionLabel = f.faction_label or f.faction_id,
        factionShort = f.faction_short or f.faction_id:sub(1, 4):upper(),
        rank = f.rank or 'member'
    }
end

local function countOnlineFactionMembers(factionId)
    if not factionId then return 0 end
    local count = 0
    for _, pid in ipairs(GetPlayers()) do
        local info = getPlayerFactionInfo(tonumber(pid))
        if info and info.factionId == factionId then
            count = count + 1
        end
    end
    return count
end

local function buildClientSyncPayload()
    local now = os.time()
    local out = {}
    for _, cfg in ipairs(ConquestConfig.Sectors) do
        local st = SectorsState[cfg.id] or {}
        local cap = ActiveCaptures[cfg.id]
        local shieldLeft = 0
        if st.shieldUntil and st.shieldUntil > now then
            shieldLeft = math.ceil((st.shieldUntil - now) / 60)
        end

        out[cfg.id] = {
            id = cfg.id,
            label = cfg.label,
            region = cfg.region,
            ownerFactionId = st.ownerFactionId,
            ownerLabel = st.ownerLabel or 'Unclaimed',
            ownerShort = st.ownerShort or 'NEU',
            status = cap and 'CONTESTED' or (st.ownerFactionId and 'CAPTURED' or 'NEUTRAL'),
            shieldMinutes = shieldLeft,
            perkLabel = cfg.perkLabel,
            hourlyPayout = cfg.hourlyPayout,
            captureProgress = cap and math.floor((cap.progress / ConquestConfig.CaptureDurationSeconds) * 100) or 0,
            attackerLabel = cap and cap.attackerLabel or nil,
            contested = cap and cap.contested or false,
        }
    end
    return out
end

local function broadcastState(targetSrc)
    local snapshot = buildClientSyncPayload()
    TriggerClientEvent('bs19_conquest:syncState', targetSrc or -1, snapshot)
end

local function chatNotify(src, msg, rgb)
    TriggerClientEvent('chat:addMessage', src, {
        color = rgb or { 217, 119, 6 },
        args = { 'BS19 - Sector Conquest', msg }
    })
end

-- =============================================================================
-- 1. BOOTSTRAP DATABASE TABLES & LOAD SAVED SECTOR OWNERSHIP
-- =============================================================================
local function bootstrapDatabase()
    if not hasOxMysql() then
        print(('^1[%s] oxmysql is not started; running in memory-only mode.^7'):format(RESOURCE_NAME))
    else
        dbExecute([[
            CREATE TABLE IF NOT EXISTS bs_conquest_sectors (
                sector_id VARCHAR(48) NOT NULL PRIMARY KEY,
                label VARCHAR(80) NOT NULL,
                owner_faction_id VARCHAR(64) DEFAULT NULL,
                owner_label VARCHAR(80) DEFAULT NULL,
                owner_short VARCHAR(16) DEFAULT NULL,
                status VARCHAR(24) NOT NULL DEFAULT 'NEUTRAL',
                captured_at BIGINT DEFAULT NULL,
                shield_until BIGINT DEFAULT NULL,
                captures_count INT NOT NULL DEFAULT 0,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]])

        dbExecute([[
            CREATE TABLE IF NOT EXISTS bs_conquest_history (
                id INT AUTO_INCREMENT PRIMARY KEY,
                sector_id VARCHAR(48) NOT NULL,
                sector_label VARCHAR(80) NOT NULL,
                previous_faction_id VARCHAR(64) DEFAULT NULL,
                new_faction_id VARCHAR(64) DEFAULT NULL,
                new_faction_label VARCHAR(80) DEFAULT NULL,
                captured_by_char INT DEFAULT NULL,
                captured_by_name VARCHAR(80) DEFAULT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]])
    end

    local savedRows = dbQuery('SELECT * FROM bs_conquest_sectors')
    local savedById = {}
    for _, row in ipairs(savedRows) do
        savedById[row.sector_id] = row
    end

    for _, cfg in ipairs(ConquestConfig.Sectors) do
        local row = savedById[cfg.id]
        if row then
            SectorsState[cfg.id] = {
                ownerFactionId = row.owner_faction_id,
                ownerLabel = row.owner_label,
                ownerShort = row.owner_short,
                capturedAt = tonumber(row.captured_at),
                shieldUntil = tonumber(row.shield_until),
                capturesCount = tonumber(row.captures_count) or 0,
            }
        else
            SectorsState[cfg.id] = {
                ownerFactionId = nil,
                ownerLabel = nil,
                ownerShort = nil,
                capturedAt = nil,
                shieldUntil = nil,
                capturesCount = 0,
            }
            dbExecute(
                'INSERT IGNORE INTO bs_conquest_sectors (sector_id, label, status) VALUES (?, ?, ?)',
                { cfg.id, cfg.label, 'NEUTRAL' }
            )
        end
    end

    print(('^2[%s] BS19 - Sector Conquest (Developed by Trident40) loaded %d strategic sectors.^7'):format(
        RESOURCE_NAME, #ConquestConfig.Sectors
    ))
    broadcastState(-1)
end

-- =============================================================================
-- 2. CAPTURE INITIATION & 1-SECOND AUTHORITATIVE CAPTURE LOOP
-- =============================================================================
RegisterNetEvent('bs19_conquest:requestSync', function()
    broadcastState(source)
end)

RegisterNetEvent('bs19_conquest:startCapture', function(sectorId)
    local src = source
    local cfg = getSectorConfig(sectorId)
    if not cfg then return end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local dist = #(GetEntityCoords(ped) - cfg.coords)
    if dist > (cfg.radius + 5.0) then
        chatNotify(src, 'Move inside the capture perimeter to contest this sector.', { 220, 38, 38 })
        return
    end

    local info = getPlayerFactionInfo(src)
    if not info or not info.factionId then
        chatNotify(src, 'You must belong to a BS19 faction to capture strategic sectors.', { 220, 38, 38 })
        return
    end

    local st = SectorsState[sectorId]
    if st.ownerFactionId == info.factionId then
        chatNotify(src, ('Your faction already controls %s (%s).'):format(cfg.label, cfg.perkLabel), { 22, 163, 74 })
        return
    end

    local now = os.time()
    if st.shieldUntil and st.shieldUntil > now then
        local mins = math.ceil((st.shieldUntil - now) / 60)
        chatNotify(src, ('%s is shielded for %d more minute(s).'):format(cfg.label, mins), { 217, 119, 6 })
        return
    end

    if ActiveCaptures[sectorId] then
        chatNotify(src, ('%s is already being contested by %s!'):format(cfg.label, ActiveCaptures[sectorId].attackerLabel), { 217, 119, 6 })
        return
    end

    if ConquestConfig.MinOnlineDefenders > 0 and st.ownerFactionId then
        local onlineDef = countOnlineFactionMembers(st.ownerFactionId)
        if onlineDef < ConquestConfig.MinOnlineDefenders then
            chatNotify(src, ('At least %d defending faction member(s) must be online to contest this sector.'):format(
                ConquestConfig.MinOnlineDefenders
            ), { 220, 38, 38 })
            return
        end
    end

    ActiveCaptures[sectorId] = {
        attackerId = info.factionId,
        attackerLabel = info.factionLabel,
        attackerShort = info.factionShort,
        progress = 0,
        contested = false,
        startedByChar = info.charId,
        startedByName = info.charName,
    }

    dbExecute('UPDATE bs_conquest_sectors SET status = ? WHERE sector_id = ?', { 'CONTESTED', sectorId })

    chatNotify(-1, ('[ALERT] %s is contesting %s! Defend or intercept at %s.'):format(
        info.factionLabel, cfg.label, formatCoords(cfg.coords)
    ), { 220, 38, 38 })

    broadcastState(-1)
    dbg('Capture started at %s by %s (%s)', cfg.id, info.factionLabel, info.charName)
end)

CreateThread(function()
    Wait(2500)
    bootstrapDatabase()

    while true do
        Wait(1000)

        local changed = false
        for sectorId, cap in pairs(ActiveCaptures) do
            local cfg = getSectorConfig(sectorId)
            local st = SectorsState[sectorId]
            local attackersInZone = 0
            local defendersInZone = 0

            for _, pidStr in ipairs(GetPlayers()) do
                local pid = tonumber(pidStr)
                local ped = GetPlayerPed(pid)
                if ped and ped ~= 0 and GetEntityHealth(ped) > 0 then
                    if #(GetEntityCoords(ped) - cfg.coords) <= cfg.radius then
                        local pInfo = getPlayerFactionInfo(pid)
                        if pInfo and pInfo.factionId == cap.attackerId then
                            attackersInZone = attackersInZone + 1
                        elseif pInfo and pInfo.factionId and pInfo.factionId ~= cap.attackerId then
                            defendersInZone = defendersInZone + 1
                        end
                    end
                end
            end

            if attackersInZone > 0 and defendersInZone == 0 then
                cap.contested = false
                cap.progress = cap.progress + 1
                changed = true
            elseif attackersInZone > 0 and defendersInZone > 0 then
                if not cap.contested then changed = true end
                cap.contested = true
            else
                -- Attackers left or were eliminated -> decay capture progress
                cap.contested = false
                cap.progress = math.max(0, cap.progress - 2)
                changed = true
                if cap.progress <= 0 then
                    ActiveCaptures[sectorId] = nil
                    local revertStatus = st.ownerFactionId and 'CAPTURED' or 'NEUTRAL'
                    dbExecute('UPDATE bs_conquest_sectors SET status = ? WHERE sector_id = ?', { revertStatus, sectorId })
                    chatNotify(-1, ('Capture attempt on %s by %s failed!'):format(cfg.label, cap.attackerLabel), { 100, 116, 139 })
                    changed = true
                end
            end

            -- Capture Completed!
            if ActiveCaptures[sectorId] and cap.progress >= ConquestConfig.CaptureDurationSeconds then
                local prevOwnerId = st.ownerFactionId
                local prevOwnerLabel = st.ownerLabel or 'Unclaimed'
                local now = os.time()
                local shieldUntil = now + (ConquestConfig.ShieldDurationMinutes * 60)

                st.ownerFactionId = cap.attackerId
                st.ownerLabel = cap.attackerLabel
                st.ownerShort = cap.attackerShort
                st.capturedAt = now
                st.shieldUntil = shieldUntil
                st.capturesCount = (st.capturesCount or 0) + 1
                ActiveCaptures[sectorId] = nil

                dbExecute([[
                    UPDATE bs_conquest_sectors
                    SET owner_faction_id = ?, owner_label = ?, owner_short = ?,
                        status = 'CAPTURED', captured_at = ?, shield_until = ?, captures_count = ?
                    WHERE sector_id = ?
                ]], {
                    st.ownerFactionId, st.ownerLabel, st.ownerShort,
                    now, shieldUntil, st.capturesCount, sectorId
                })

                dbExecute([[
                    INSERT INTO bs_conquest_history
                        (sector_id, sector_label, previous_faction_id, new_faction_id, new_faction_label, captured_by_char, captured_by_name)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ]], {
                    sectorId, cfg.label, prevOwnerId, st.ownerFactionId,
                    st.ownerLabel, cap.startedByChar, cap.startedByName
                })

                chatNotify(-1, ('%s captured %s! Perk unlocked: %s ($%d/hr tax).'):format(
                    st.ownerLabel, cfg.label, cfg.perkLabel, cfg.hourlyPayout
                ), { 22, 163, 74 })

                changed = true
            end
        end

        if changed then
            broadcastState(-1)
        end
    end
end)

-- =============================================================================
-- 3. HOURLY FACTION TREASURY PAYOUT LOOP (bs_faction_banks)
-- =============================================================================
CreateThread(function()
    local intervalMs = math.max(5, tonumber(ConquestConfig.PayoutIntervalMinutes) or 60) * 60 * 1000
    while true do
        Wait(intervalMs)
        local totalsByFaction = {}

        for _, cfg in ipairs(ConquestConfig.Sectors) do
            local st = SectorsState[cfg.id]
            if st and st.ownerFactionId and cfg.hourlyPayout > 0 then
                totalsByFaction[st.ownerFactionId] = (totalsByFaction[st.ownerFactionId] or 0) + cfg.hourlyPayout
            end
        end

        for factionId, payout in pairs(totalsByFaction) do
            dbExecute([[
                INSERT INTO bs_faction_banks (faction_id, balance)
                VALUES (?, ?)
                ON DUPLICATE KEY UPDATE balance = balance + VALUES(balance)
            ]], { factionId, payout })
            dbg('Deposited $%d conquest tax into bs_faction_banks for faction "%s"', payout, factionId)
        end
    end
end)

-- =============================================================================
-- 4. PUBLIC SERVER EXPORTS (Use from any BS19 script for Risk-style perks!)
-- =============================================================================
exports('GetSectorOwner', function(sectorId)
    local st = SectorsState[sectorId]
    return st and st.ownerFactionId or nil
end)

exports('GetFactionSectors', function(factionId)
    local owned = {}
    for _, cfg in ipairs(ConquestConfig.Sectors) do
        local st = SectorsState[cfg.id]
        if st and st.ownerFactionId == factionId then
            owned[#owned + 1] = cfg.id
        end
    end
    return owned
end)

exports('HasFactionPerk', function(factionId, perkKey)
    if not factionId or not perkKey then return false end
    for _, cfg in ipairs(ConquestConfig.Sectors) do
        local st = SectorsState[cfg.id]
        if cfg.perkKey == perkKey and st and st.ownerFactionId == factionId then
            return true
        end
    end
    return false
end)

exports('GetPerkMultiplier', function(src, perkKey)
    local info = getPlayerFactionInfo(src)
    if not info or not info.factionId then return 1.0 end
    for _, cfg in ipairs(ConquestConfig.Sectors) do
        local st = SectorsState[cfg.id]
        if cfg.perkKey == perkKey and st and st.ownerFactionId == info.factionId then
            return cfg.perkMultiplier or 1.0
        end
    end
    return 1.0
end)

-- =============================================================================
-- 5. ADMIN CONSOLE COMMANDS (conquestreset / conquestset)
-- =============================================================================
RegisterCommand('conquestreset', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'command.conquestreset') then return end
    local target = args[1] or 'all'
    for _, cfg in ipairs(ConquestConfig.Sectors) do
        if target == 'all' or target == cfg.id then
            ActiveCaptures[cfg.id] = nil
            SectorsState[cfg.id] = { ownerFactionId = nil, ownerLabel = nil, ownerShort = nil, shieldUntil = nil, capturesCount = 0 }
            dbExecute(
                'UPDATE bs_conquest_sectors SET owner_faction_id = NULL, owner_label = NULL, owner_short = NULL, status = ?, shield_until = NULL WHERE sector_id = ?',
                { 'NEUTRAL', cfg.id }
            )
        end
    end
    broadcastState(-1)
    print(('^2[%s] Reset Sector Conquest state (%s).^7'):format(RESOURCE_NAME, target))
end, false)
