-- =============================================================================
-- BS19 - Sector Conquest (Developed by Trident40)
-- Native MariaDB / MySQL tables (also auto-created on resource start)
-- Compatible with Arcainex/bs19 + oxmysql
-- =============================================================================

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
