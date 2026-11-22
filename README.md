# BS19 - Sector Conquest

> **Standalone Risk-Style Faction Territory Control, Strategic Perks & Passive Treasury Tax for BeyondSurvival (BS19)**
> **Developed by Trident40**

![FiveM](https://img.shields.io/badge/FiveM-Cerulean%20%7C%20Lua%205.4-f59e0b?style=for-the-badge)
![BS19](https://img.shields.io/badge/BeyondSurvival-Arcainex%2Fbs19-dc2626?style=for-the-badge)
![Database](https://img.shields.io/badge/Database-oxmysql%20%7C%20MariaDB-0d9488?style=for-the-badge)
![Standalone](https://img.shields.io/badge/Mode-Zero--Edit%20Standalone-16a34a?style=for-the-badge)

---

## Overview

**BS19 - Sector Conquest** is a standalone, zero-edit FiveM expansion built natively for **BeyondSurvival (`Arcainex/bs19`)**. It transforms San Andreas into a Risk-style strategic war map where factions battle over **6 high-value control sectors** to unlock stacked gameplay perks and collect automated hourly taxes straight into `bs_faction_banks`.

### Key Highlights
- **Zero Edits to Core BS19 Files** — Resolves active characters and factions directly through `exports.bs_core:GetPlayer(src)` (with automatic `bs_users` + `bs_characters` fallback) and native `bs_faction_members` / `bs_faction_registry` / `bs_faction_banks` tables.
- **Auto-Bootstrapping SQL** — Automatically creates `bs_conquest_sectors` and `bs_conquest_history` on resource start via `oxmysql` (manual SQL file also included in `sql/sector_conquest.sql`).
- **Server-Authoritative Capture Loop** — 1-second authoritative zone tick checks living attackers vs. defenders inside the sector radius:
  - Attackers uncontested: capture progresses toward 100% (`180s` default).
  - Defenders enter the circle: progress **freezes** and HUD switches to **CONTESTED**.
  - Attackers retreat or die: capture progress decays (`-2s/sec`) until the assault fails.
- **Post-Capture Immunity Shield** — Newly captured sectors automatically receive a configurable protection shield (`120 min` default) to prevent instant offline ninja-caps, plus optional `MinOnlineDefenders` enforcement.
- **Hourly Faction Treasury Tax** — Automatically deposits passive territory revenue into `bs_faction_banks` every hour for every sector a faction holds.
- **Dynamic GTA V Map Blips & Tactical HUD** — Color-coded territory radius circles (Grey = Neutral, Amber = Owned, Green = Shielded, Flashing Red = Contested), 3D ground perimeter markers, `[E]` contest prompt, and compact top-center progress HUD.
- **Developer-Friendly Server Exports** — Drop 1-line calls into any BS19 script (crafting, salvage, XP, vending, airdrops) to apply real territory perk multipliers.

https://prnt.sc/UUBOAwrGYuk2
https://prnt.sc/3Wd3syQPbu8b
https://prnt.sc/Jf624cGuPwyr
https://prnt.sc/MDni4GOVAxDU


---

## Strategic San Andreas Control Sectors

| Sector ID | Location | Region | Coordinates | Radius | Hourly Tax | Strategic Perk | Perk Key |
| :--- | :--- | :--- | :--- | :---: | :---: | :--- | :--- |
| `paleto_sawmill` | **Paleto Bay Sawmill** | Blaine County North | `-558.4, 5348.2, 70.2` | `45m` | `$2,500/hr` | **+25%** Building & Salvage Yield | `build_yield` (`1.25x`) |
| `sandy_airfield` | **Sandy Shores Airfield** | Grand Senora Desert | `1734.5, 3294.8, 41.2` | `55m` | `$3,500/hr` | **+15%** Airdrop & Crate Loot Speed | `loot_speed` (`1.15x`) |
| `bolingbroke_prison` | **Bolingbroke Penitentiary** | Senora Freeway | `1690.2, 2591.4, 45.6` | `55m` | `$4,500/hr` | **+20%** Armory Craft & Munitions Yield | `ammo_supply` (`1.20x`) |
| `thomson_scrapyard` | **Thomson Scrapyard** | East Senora | `2352.1, 3133.6, 48.2` | `45m` | `$3,000/hr` | **+25%** Scrap & Vehicle Repair Efficiency | `scrap_efficiency` (`1.25x`) |
| `palmer_taylor_grid` | **Palmer-Taylor Power Relay** | East Coast Industrial | `2742.0, 1518.4, 24.5` | `50m` | `$5,000/hr` | **+20%** Wasteland Pass & Survival XP | `xp_boost` (`1.20x`) |
| `port_of_ls` | **Port of Los Santos** | South Docks | `842.6, -2986.4, 5.9` | `60m` | `$4,000/hr` | **-50%** Vending Tax & Trade Rebate | `vending_rebate` (`1.50x`) |

> All sectors, coordinates, radii, payouts, and perk multipliers can be customized or expanded in `config.lua`.

---

## Resource Structure

```text
bs19-sector-conquest/
├── fxmanifest.lua             # Cerulean Lua 5.4 FiveM manifest
├── config.lua                 # Timers, blip colors, defender rules & 6 sector definitions
├── sql/
│   └── sector_conquest.sql    # Optional manual SQL import (auto-created on first boot)
├── server/
│   └── main.lua               # Authoritative capture loop, DB persistence, payouts & exports
├── client/
│   └── main.lua               # GTA V radius/flag blips, 3D markers, tactical HUD & /sectors
└── README.md                  # Documentation & install guide
```

---

## Prerequisites

- **FiveM Server** (Cerulean artifact, Lua 5.4 enabled)
- **BeyondSurvival (`Arcainex/bs19`)** running with `bs_core` and faction tables (`bs_faction_members`, `bs_faction_registry`, `bs_faction_banks`)
- **`oxmysql`** started before `bs19-sector-conquest`

---

## Step-by-Step Installation

### Step 1 — Copy the Resource
Place the `bs19-sector-conquest/` folder inside your FiveM server's `resources/[local]/` directory (or any custom resource folder you use).

### Step 2 — Configure `config.lua` (Optional)
Open `bs19-sector-conquest/config.lua` and adjust gameplay timers to match your server's pacing:

```lua
ConquestConfig.Debug = false                  -- Console logs for capture ticks & payouts
ConquestConfig.CaptureDurationSeconds = 180   -- Hold time uncontested (3 minutes)
ConquestConfig.ShieldDurationMinutes = 120    -- Post-capture immunity shield (2 hours)
ConquestConfig.MinOnlineDefenders = 0         -- Require X defending faction members online (0 = off)
ConquestConfig.PayoutIntervalMinutes = 60     -- Hourly bs_faction_banks tax interval
ConquestConfig.CaptureKey = 38                -- Control ID 38 = [E]
```

### Step 3 — Database Tables (Automatic)
You do **not** need to import SQL manually — on first startup, `server/main.lua` automatically executes `CREATE TABLE IF NOT EXISTS` for:
- `bs_conquest_sectors` — Stores live ownership, status, capture timestamp, shield expiry, and capture count.
- `bs_conquest_history` — Permanent audit log of every territory flip and who captured it.

*(If you prefer manual migrations, import `sql/sector_conquest.sql` using HeidiSQL or phpMyAdmin.)*

### Step 4 — Add to `server.cfg`
Add `ensure bs19-sector-conquest` **after** `oxmysql` and `[beyond]`:

```cfg
ensure oxmysql
ensure [beyond]
ensure bs19-sector-conquest
```

*(Optional)* Grant staff ACE permission to reset sectors in-game:

```cfg
add_ace group.admin command.conquestreset allow
```

### Step 5 — Start & Verify
Restart your server or run `refresh` followed by `ensure bs19-sector-conquest` in the FiveM console. Look for:

```text
[bs19-sector-conquest] BS19 - Sector Conquest (Developed by Trident40) loaded 6 strategic sectors.
```

Join in-game, open your pause map to verify all 6 strategic sector blips appear, and type `/sectors` in chat!

---

## In-Game & Admin Commands

| Command | Access | Description |
| :--- | :--- | :--- |
| `[E]` (inside sector ring) | Any Faction Member | Initiates a takeover of an unshielded neutral or rival sector. |
| `/sectors` | Everyone (Client) | Prints all 6 sectors in chat with current owner, shield timer, perk, and hourly tax. |
| `conquestreset all` | Console / ACE Admin | Resets all 6 sectors back to `NEUTRAL` and clears active shields. |
| `conquestreset <sector_id>` | Console / ACE Admin | Resets a single sector (e.g. `conquestreset paleto_sawmill`) back to `NEUTRAL`. |

---

## Server Exports (Hook Perks Into Any BS19 Script)

Use these server-side exports inside any BS19 resource to reward controlling factions automatically:

| Export | Parameters | Returns | Description |
| :--- | :--- | :--- | :--- |
| `GetSectorOwner` | `sectorId` (string) | `string \| nil` | Returns the controlling `faction_id` (or `nil` if neutral). |
| `GetFactionSectors` | `factionId` (string) | `table` | Returns an array of `sector_id` strings owned by that faction. |
| `HasFactionPerk` | `factionId, perkKey` | `boolean` | Returns `true` if the faction currently holds that perk key. |
| `GetPerkMultiplier` | `src, perkKey` | `number` | Resolves player `src`'s faction and returns the multiplier (e.g. `1.25`), or `1.0` if unowned. |

### Example Lua Integration Snippets

```lua
-- Example 1: Apply +25% salvage/building yield from Paleto Bay Sawmill
local mult = exports['bs19-sector-conquest']:GetPerkMultiplier(src, 'build_yield')
local finalAmount = math.floor(baseYield * mult)

-- Example 2: Apply +20% Wasteland Pass / Survival XP from Palmer-Taylor Power Relay
local xpMult = exports['bs19-sector-conquest']:GetPerkMultiplier(src, 'xp_boost')
local awardedXp = math.floor(baseXp * xpMult)

-- Example 3: Cut offline vending fee in half if faction holds Port of Los Santos
if exports['bs19-sector-conquest']:HasFactionPerk(factionId, 'vending_rebate') then
    vendingTax = math.floor(vendingTax * 0.5)
end
```

---

## Troubleshooting

- **`oxmysql is not started; running in memory-only mode.`**
  - Make sure `ensure oxmysql` is listed **above** `ensure bs19-sector-conquest` in `server.cfg`.
- **"You must belong to a BS19 faction to capture strategic sectors."**
  - Solo players without a `bs_faction_members` record cannot claim territories. Join or create a BS19 faction first.
- **No blips appear when joining:**
  - Verify `client/main.lua` loaded cleanly in F8 console, or run `ensure bs19-sector-conquest` while in-game to trigger `bs19_conquest:requestSync`.
- **Want to prevent offline raiding?**
  - Set `ConquestConfig.MinOnlineDefenders = 2` (or higher) in `config.lua` so rivals cannot start a takeover unless defending members are online.

---

## Credits

- **BS19 - Sector Conquest** — **Developed by Trident40**
- Built natively for **BeyondSurvival (`Arcainex/bs19`)**
