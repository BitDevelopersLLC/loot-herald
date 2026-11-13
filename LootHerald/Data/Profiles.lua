-- Loot Herald: class / spec / role profiles and their stat weights.
--
-- HOW TO READ THESE NUMBERS
--   A weight is "how much one point of this stat is worth" for that role.
--   The main stat of each role is about 1.0; everything else is relative to it.
--   An item's score is simply  sum(stat value x weight).
--
--   HIT, CRIT, DODGE, PARRY and BLOCK are weighted per 1% (Vanilla-style items
--   say "Improves your chance to hit by 1%"). WoW Forever merges spell/melee/
--   ranged hit into one Hit stat and the crit stats into one Crit stat, so each
--   profile has a single HIT and a single CRIT weight.
--
--   DPS  = weapon damage per second of a melee weapon.
--   RDPS = damage per second of a ranged weapon / wand / thrown.
--
-- These are community-style starting points, NOT simulation results. They are
-- deliberately simple and easy to audit. If you think a number is wrong, open an
-- issue or pull request, or override it in game:  /lh weight CRIT 10
--
-- Stat keys (see ns.STAT_LABELS below):
--   STR AGI STA INT SPI ARMOR AP RAP SP HEAL SPDMG SPFIRE SPFROST SPSHADOW
--   SPARCANE SPNATURE SPHOLY MP5 HP5 HIT CRIT DEF DODGE PARRY BLOCK BLOCKVALUE
--   DPS RDPS
local _, ns = ...

-- The game version these weights and rules were last reviewed against.
-- Update this whenever you finish the patch-day checklist (docs/MAINTENANCE.md).
-- /lh selftest warns when the game is newer than this.
ns.DATA_REVIEWED_FOR = "1.60.1"

ns.STAT_LABELS = {
    STR = "Strength", AGI = "Agility", STA = "Stamina", INT = "Intellect", SPI = "Spirit",
    ARMOR = "Armor", AP = "Attack Power", RAP = "Ranged Attack Power",
    SP = "Spell Damage & Healing", HEAL = "Healing", SPDMG = "Spell Damage",
    SPFIRE = "Fire Spell Damage", SPFROST = "Frost Spell Damage", SPSHADOW = "Shadow Spell Damage",
    SPARCANE = "Arcane Spell Damage", SPNATURE = "Nature Spell Damage", SPHOLY = "Holy Spell Damage",
    MP5 = "Mana per 5 sec", HP5 = "Health per 5 sec",
    HIT = "Hit %", CRIT = "Crit %", DEF = "Defense", DODGE = "Dodge %", PARRY = "Parry %",
    BLOCK = "Block %", BLOCKVALUE = "Block Value",
    DPS = "Weapon DPS", RDPS = "Ranged Weapon DPS",
}

ns.ROLE_LABELS = { TANK = "Tank", HEALER = "Healer", DPS = "Damage" }

-- key     unique id, saved per character
-- name    shown to the player
-- tree    talent tree index (1-3) this profile belongs to, used for auto-detect
-- role    TANK / HEALER / DPS
-- aliases other spec names the game client might report for this profile
-- default preferred profile when a talent tree has more than one (Feral)
ns.Profiles = {
    WARRIOR = {
        { key = "WARRIOR_ARMS", name = "Arms", tree = 1, role = "DPS",
          weights = { STR = 1.0, AGI = 0.7, AP = 0.5, CRIT = 14, HIT = 16, STA = 0.15, ARMOR = 0.005, DPS = 7.0, RDPS = 0.5 } },
        { key = "WARRIOR_FURY", name = "Fury", tree = 2, role = "DPS",
          weights = { STR = 1.0, AGI = 0.7, AP = 0.5, CRIT = 14, HIT = 17, STA = 0.15, ARMOR = 0.005, DPS = 6.5, RDPS = 0.5 } },
        { key = "WARRIOR_PROT", name = "Protection", tree = 3, role = "TANK",
          weights = { STA = 1.0, DEF = 1.3, ARMOR = 0.06, AGI = 0.6, DODGE = 13, PARRY = 12, BLOCK = 7, BLOCKVALUE = 0.35,
                      STR = 0.5, AP = 0.2, HIT = 8, CRIT = 3, DPS = 2.0, HP5 = 1.5, RDPS = 0.3 } },
    },
    PALADIN = {
        { key = "PALADIN_HOLY", name = "Holy", tree = 1, role = "HEALER",
          weights = { HEAL = 1.0, SP = 1.0, INT = 0.9, MP5 = 2.2, CRIT = 11, SPI = 0.15, STA = 0.15, ARMOR = 0.002 } },
        { key = "PALADIN_PROT", name = "Protection", tree = 2, role = "TANK",
          weights = { STA = 1.0, DEF = 1.1, ARMOR = 0.05, BLOCKVALUE = 0.45, BLOCK = 9, DODGE = 11, PARRY = 11,
                      SP = 0.6, SPHOLY = 0.6, INT = 0.3, AGI = 0.4, STR = 0.3, HIT = 6, MP5 = 0.8, DPS = 1.0 } },
        { key = "PALADIN_RET", name = "Retribution", tree = 3, role = "DPS",
          weights = { STR = 1.0, AGI = 0.6, AP = 0.5, CRIT = 13, HIT = 14, INT = 0.2, SP = 0.25, SPHOLY = 0.25,
                      STA = 0.15, MP5 = 0.4, DPS = 8.0, ARMOR = 0.005 } },
    },
    HUNTER = {
        { key = "HUNTER_BM", name = "Beast Mastery", tree = 1, role = "DPS",
          weights = { AGI = 1.0, RAP = 0.45, AP = 0.4, CRIT = 12, HIT = 15, INT = 0.3, STA = 0.15, MP5 = 0.6, RDPS = 7.5, DPS = 0.4, ARMOR = 0.005 } },
        { key = "HUNTER_MM", name = "Marksmanship", tree = 2, role = "DPS", aliases = { "Marksman" },
          weights = { AGI = 1.0, RAP = 0.45, AP = 0.4, CRIT = 13, HIT = 15, INT = 0.3, STA = 0.15, MP5 = 0.6, RDPS = 8.0, DPS = 0.4, ARMOR = 0.005 } },
        { key = "HUNTER_SV", name = "Survival", tree = 3, role = "DPS",
          weights = { AGI = 1.1, RAP = 0.45, AP = 0.4, CRIT = 13, HIT = 15, INT = 0.3, STA = 0.2, MP5 = 0.6, RDPS = 7.5, DPS = 0.5, ARMOR = 0.005 } },
    },
    ROGUE = {
        { key = "ROGUE_ASSA", name = "Assassination", tree = 1, role = "DPS",
          weights = { AGI = 1.0, STR = 0.5, AP = 0.5, CRIT = 13, HIT = 16, STA = 0.15, DPS = 6.0, RDPS = 0.3, ARMOR = 0.005 } },
        { key = "ROGUE_COMBAT", name = "Combat", tree = 2, role = "DPS", aliases = { "Outlaw" },
          weights = { AGI = 1.0, STR = 0.5, AP = 0.5, CRIT = 12, HIT = 17, STA = 0.15, DPS = 7.0, RDPS = 0.3, ARMOR = 0.005 } },
        { key = "ROGUE_SUB", name = "Subtlety", tree = 3, role = "DPS",
          weights = { AGI = 1.0, STR = 0.5, AP = 0.5, CRIT = 12, HIT = 15, STA = 0.15, DPS = 6.0, RDPS = 0.3, ARMOR = 0.005 } },
    },
    PRIEST = {
        { key = "PRIEST_DISC", name = "Discipline", tree = 1, role = "HEALER",
          weights = { HEAL = 1.0, SP = 1.0, INT = 0.7, SPI = 0.45, MP5 = 2.3, CRIT = 6, STA = 0.15, RDPS = 0.2 } },
        { key = "PRIEST_HOLY", name = "Holy", tree = 2, role = "HEALER",
          weights = { HEAL = 1.0, SP = 1.0, INT = 0.6, SPI = 0.7, MP5 = 2.2, CRIT = 7, STA = 0.15, RDPS = 0.2 } },
        { key = "PRIEST_SHADOW", name = "Shadow", tree = 3, role = "DPS",
          weights = { SP = 1.0, SPSHADOW = 1.0, HIT = 13, CRIT = 4, INT = 0.3, SPI = 0.3, MP5 = 1.0, STA = 0.25, RDPS = 0.3 } },
    },
    SHAMAN = {
        { key = "SHAMAN_ELE", name = "Elemental", tree = 1, role = "DPS",
          weights = { SP = 1.0, SPNATURE = 0.9, SPFIRE = 0.35, SPFROST = 0.1, CRIT = 12, HIT = 12, INT = 0.4, MP5 = 1.2,
                      SPI = 0.1, STA = 0.15, DPS = 0.1 } },
        { key = "SHAMAN_ENH", name = "Enhancement", tree = 2, role = "DPS",
          weights = { STR = 1.0, AGI = 0.65, AP = 0.5, CRIT = 13, HIT = 14, INT = 0.2, SP = 0.15, SPNATURE = 0.1,
                      STA = 0.15, MP5 = 0.3, DPS = 8.0, ARMOR = 0.005 } },
        { key = "SHAMAN_RESTO", name = "Restoration", tree = 3, role = "HEALER",
          weights = { HEAL = 1.0, SP = 1.0, MP5 = 2.5, INT = 0.65, CRIT = 6, SPI = 0.15, STA = 0.15, ARMOR = 0.002 } },
    },
    MAGE = {
        { key = "MAGE_ARCANE", name = "Arcane", tree = 1, role = "DPS",
          weights = { SP = 1.0, SPARCANE = 0.9, SPFROST = 0.5, SPFIRE = 0.5, HIT = 13, CRIT = 9, INT = 0.45, SPI = 0.2,
                      MP5 = 0.8, STA = 0.15, RDPS = 0.3 } },
        { key = "MAGE_FIRE", name = "Fire", tree = 2, role = "DPS",
          weights = { SP = 1.0, SPFIRE = 1.0, CRIT = 12, HIT = 13, INT = 0.35, SPI = 0.1, MP5 = 0.6, STA = 0.15, RDPS = 0.3 } },
        { key = "MAGE_FROST", name = "Frost", tree = 3, role = "DPS",
          weights = { SP = 1.0, SPFROST = 1.0, HIT = 13, CRIT = 8, INT = 0.35, SPI = 0.1, MP5 = 0.6, STA = 0.2, RDPS = 0.3 } },
    },
    WARLOCK = {
        { key = "WARLOCK_AFF", name = "Affliction", tree = 1, role = "DPS",
          weights = { SP = 1.0, SPSHADOW = 1.0, SPFIRE = 0.1, HIT = 14, CRIT = 5, INT = 0.3, SPI = 0.15, STA = 0.35, RDPS = 0.3 } },
        { key = "WARLOCK_DEMO", name = "Demonology", tree = 2, role = "DPS",
          weights = { SP = 1.0, SPSHADOW = 0.95, SPFIRE = 0.2, HIT = 13, CRIT = 7, INT = 0.3, SPI = 0.1, STA = 0.45, RDPS = 0.3 } },
        { key = "WARLOCK_DESTRO", name = "Destruction", tree = 3, role = "DPS",
          weights = { SP = 1.0, SPSHADOW = 0.85, SPFIRE = 0.5, HIT = 14, CRIT = 9, INT = 0.3, SPI = 0.1, STA = 0.3, RDPS = 0.3 } },
    },
    DRUID = {
        { key = "DRUID_BALANCE", name = "Balance", tree = 1, role = "DPS",
          weights = { SP = 1.0, SPARCANE = 0.6, SPNATURE = 0.6, CRIT = 10, HIT = 12, INT = 0.4, SPI = 0.25, MP5 = 0.9, STA = 0.15 } },
        -- Feral forms ignore weapon DPS in Vanilla, so DPS weight is 0 for both feral profiles.
        { key = "DRUID_FERAL_CAT", name = "Feral (Cat)", tree = 2, role = "DPS", default = true,
          weights = { STR = 1.0, AGI = 1.05, AP = 0.5, CRIT = 13, HIT = 14, STA = 0.1, INT = 0.05, ARMOR = 0.005, DPS = 0 } },
        { key = "DRUID_FERAL_BEAR", name = "Feral (Bear)", tree = 2, role = "TANK", aliases = { "Guardian" },
          weights = { STA = 1.0, ARMOR = 0.09, AGI = 0.75, DEF = 1.0, DODGE = 12, STR = 0.5, AP = 0.2, HIT = 6, CRIT = 4, DPS = 0 } },
        { key = "DRUID_RESTO", name = "Restoration", tree = 3, role = "HEALER",
          weights = { HEAL = 1.0, SP = 1.0, MP5 = 2.3, SPI = 0.55, INT = 0.6, CRIT = 5, STA = 0.15 } },
    },
}

-- Fallback for any class this file doesn't know yet (a future Forever class).
ns.GenericProfiles = {
    { key = "GENERIC_TANK", name = "Tank", role = "TANK",
      weights = { STA = 1.0, ARMOR = 0.05, DEF = 1.1, DODGE = 12, PARRY = 11, BLOCK = 7, BLOCKVALUE = 0.35, AGI = 0.6, STR = 0.5, HIT = 6 } },
    { key = "GENERIC_HEALER", name = "Healer", role = "HEALER",
      weights = { HEAL = 1.0, SP = 1.0, INT = 0.7, SPI = 0.4, MP5 = 2.2, CRIT = 6, STA = 0.15 } },
    { key = "GENERIC_MELEE", name = "Melee Damage", role = "DPS",
      weights = { STR = 1.0, AGI = 0.8, AP = 0.5, CRIT = 13, HIT = 15, STA = 0.15, DPS = 7.0 } },
    { key = "GENERIC_RANGED", name = "Ranged Damage", role = "DPS",
      weights = { AGI = 1.0, RAP = 0.45, AP = 0.4, CRIT = 13, HIT = 15, INT = 0.3, STA = 0.15, RDPS = 7.5 } },
    { key = "GENERIC_CASTER", name = "Caster Damage", role = "DPS",
      weights = { SP = 1.0, HIT = 13, CRIT = 9, INT = 0.4, SPI = 0.15, MP5 = 0.8, STA = 0.15, RDPS = 0.3 } },
}

-- Fill in derived weights so every profile is complete:
--   HEAL  ("healing only" gear) is worth SP to healers, nothing to everyone else.
--   SPDMG ("damage only" spell gear) is worth SP to non-healers, nothing to healers.
--   hitCapType: casters use the spell hit cap, everyone else the melee/ranged cap.
local function Finalize(profile)
    local w = profile.weights
    if w.HEAL == nil then w.HEAL = (profile.role == "HEALER") and (w.SP or 0) or 0 end
    if w.SPDMG == nil then w.SPDMG = (profile.role == "HEALER") and 0 or (w.SP or 0) end
    if profile.hitCapType == nil then
        profile.hitCapType = ((w.SP or 0) >= 1 and profile.role ~= "HEALER") and "spell" or "melee"
    end
end

for _, list in pairs(ns.Profiles) do
    for _, p in ipairs(list) do Finalize(p) end
end
for _, p in ipairs(ns.GenericProfiles) do Finalize(p) end

-- The highest weight any class profile gives each stat. Used by the group
-- check: "how much does this role care about this item, compared with the
-- role that cares the most?"
ns.MAX_WEIGHTS = {}
for _, list in pairs(ns.Profiles) do
    for _, p in ipairs(list) do
        for stat, w in pairs(p.weights) do
            if w > (ns.MAX_WEIGHTS[stat] or 0) then ns.MAX_WEIGHTS[stat] = w end
        end
    end
end

-- Short names for the "why" line: "+22 Healing, +8 Int, -5 Spirit".
ns.STAT_SHORT = {
    STR = "Str", AGI = "Agi", STA = "Stam", INT = "Int", SPI = "Spirit", ARMOR = "Armor",
    AP = "AP", RAP = "Ranged AP", SP = "Spell Power", HEAL = "Healing", SPDMG = "Spell Dmg",
    SPFIRE = "Fire Dmg", SPFROST = "Frost Dmg", SPSHADOW = "Shadow Dmg", SPARCANE = "Arcane Dmg",
    SPNATURE = "Nature Dmg", SPHOLY = "Holy Dmg", MP5 = "Mp5", HP5 = "Hp5",
    HIT = "Hit", CRIT = "Crit", DEF = "Defense", DODGE = "Dodge", PARRY = "Parry", BLOCK = "Block",
    BLOCKVALUE = "Block Value", DPS = "DPS", RDPS = "Ranged DPS",
}
ns.PERCENT_STAT = { HIT = true, CRIT = true, DODGE = true, PARRY = true, BLOCK = true }
