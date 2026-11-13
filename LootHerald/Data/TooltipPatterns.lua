-- Loot Herald: English tooltip patterns.
--
-- The game API (C_Item.GetItemStats) reports the plain stats (+Stamina, Armor,
-- ...), but Vanilla-style "Equip:" bonuses such as spell damage, hit and crit
-- may only appear in the tooltip text. These patterns read them. A stat the API
-- already reported is never counted twice (see ItemReader.lua).
--
-- Each entry: pattern (Lua pattern, first capture = number), stat, and
--   equip = true   only match lines that start with "Equip:"
--   school = true  first capture is a school name, second is the number
--
-- If WoW Forever words a bonus differently, fix it here. `/lh debug <item>`
-- prints every tooltip line and what was read from it.
local _, ns = ...

ns.SCHOOL_STATS = {
    fire = "SPFIRE", frost = "SPFROST", shadow = "SPSHADOW",
    arcane = "SPARCANE", nature = "SPNATURE", holy = "SPHOLY",
}

ns.TooltipPatterns = {
    -- Spell power family
    { pattern = "Increases damage and healing done by magical spells and effects by up to (%d+)", stat = "SP", equip = true },
    { pattern = "Increases healing done by spells and effects by up to (%d+)", stat = "HEAL", equip = true },
    { pattern = "Increases healing done by up to (%d+)", stat = "HEAL", equip = true },
    { pattern = "Increases damage done by magical spells and effects by up to (%d+)", stat = "SPDMG", equip = true },
    { pattern = "Increases damage done by (%a+) spells and effects by up to (%d+)", school = true, equip = true },
    { pattern = "Increases spell power by (%d+)", stat = "SP", equip = true },
    { pattern = "^%+(%d+) Spell Power", stat = "SP" },
    { pattern = "^%+(%d+) Healing Spells", stat = "HEAL" },
    { pattern = "^%+(%d+) (%a+) Spell Damage", school = true, swap = true },

    -- Hit / crit (merged in WoW Forever: one Hit stat, one Crit stat)
    { pattern = "Improves your chance to hit with spells by (%d+)%%", stat = "HIT", equip = true },
    { pattern = "Improves your chance to hit by (%d+)%%", stat = "HIT", equip = true },
    { pattern = "Improves your chance to get a critical strike with spells by (%d+)%%", stat = "CRIT", equip = true },
    { pattern = "Improves your chance to get a critical strike by (%d+)%%", stat = "CRIT", equip = true },
    { pattern = "^%+(%d+)%% Hit", stat = "HIT" },
    { pattern = "^%+(%d+)%% Critical Strike", stat = "CRIT" },

    -- Regeneration
    { pattern = "Restores (%d+) mana per 5 sec", stat = "MP5", equip = true },
    { pattern = "Restores (%d+) health per 5 sec", stat = "HP5", equip = true },
    { pattern = "^%+(%d+) [Mm]ana every 5 [Ss]ec", stat = "MP5" },

    -- Attack power
    { pattern = "%+(%d+) ranged Attack Power", stat = "RAP", equip = true },
    { pattern = "Increases ranged attack power by (%d+)", stat = "RAP", equip = true },
    { pattern = "%+(%d+) Attack Power", stat = "AP", equip = true },
    { pattern = "Increases attack power by (%d+)", stat = "AP", equip = true },
    { pattern = "^%+(%d+) Attack Power", stat = "AP" },

    -- Tanking
    { pattern = "Increased Defense %+(%d+)", stat = "DEF", equip = true },
    { pattern = "Increases defense rating by (%d+)", stat = "DEF", equip = true },
    { pattern = "^%+(%d+) Defense", stat = "DEF" },
    { pattern = "Increases your chance to dodge an attack by (%d+)%%", stat = "DODGE", equip = true },
    { pattern = "Increases your chance to parry an attack by (%d+)%%", stat = "PARRY", equip = true },
    { pattern = "Increases your chance to block attacks with a shield by (%d+)%%", stat = "BLOCK", equip = true },
    { pattern = "Increases the block value of your shield by (%d+)", stat = "BLOCKVALUE", equip = true },

    -- Base lines on the item itself (not "Equip:")
    { pattern = "^(%d+) Armor$", stat = "ARMOR" },
    { pattern = "^(%d+) Block$", stat = "BLOCKVALUE" },
    { pattern = "%(([%d%.]+) damage per second%)", stat = "DPS" },
    { pattern = "^%+(%d+) Strength$", stat = "STR" },
    { pattern = "^%+(%d+) Agility$", stat = "AGI" },
    { pattern = "^%+(%d+) Stamina$", stat = "STA" },
    { pattern = "^%+(%d+) Intellect$", stat = "INT" },
    { pattern = "^%+(%d+) Spirit$", stat = "SPI" },
}

-- Lines that describe an effect we can't turn into a number.
ns.SPECIAL_PREFIXES = { "^Equip: ", "^Use: ", "^Chance on hit: " }
