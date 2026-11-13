-- Loot Herald: what each class can (and should) wear and wield.
-- Vanilla-era rules. The game's own "can Need" flag on a roll is still checked
-- separately; these rules add the "should you Need it" layer (for example, a
-- warrior can wear leather but shouldn't take it from the rogue).
local _, ns = ...

ns.ITEM_CLASS_WEAPON = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or 2
ns.ITEM_CLASS_ARMOR = (Enum and Enum.ItemClass and Enum.ItemClass.Armor) or 4

ns.ARMOR_NAMES = { [1] = "Cloth", [2] = "Leather", [3] = "Mail", [4] = "Plate" }

-- Equip locations where the armor type (cloth/leather/mail/plate) matters.
-- Cloaks are "cloth" for everyone, so INVTYPE_CLOAK is deliberately missing.
ns.ARMOR_TYPED_SLOTS = {
    INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true, INVTYPE_ROBE = true,
    INVTYPE_WAIST = true, INVTYPE_LEGS = true, INVTYPE_FEET = true, INVTYPE_WRIST = true,
    INVTYPE_HAND = true,
}

-- { preferred before `at`, preferred from level `at`, at }
ns.ARMOR_PREF = {
    WARRIOR = { 3, 4, 40 }, PALADIN = { 3, 4, 40 },
    HUNTER = { 2, 3, 40 }, SHAMAN = { 2, 3, 40 },
    ROGUE = { 2 }, DRUID = { 2 },
    PRIEST = { 1 }, MAGE = { 1 }, WARLOCK = { 1 },
}

function ns.PreferredArmor(classFile, level)
    local r = ns.ARMOR_PREF[classFile]
    if not r then return nil end
    if r[3] and (level or 0) >= r[3] then return r[2] end
    return r[1]
end

function ns.MaxArmor(classFile, level)
    -- Everyone can wear their preferred type or lower.
    return ns.PreferredArmor(classFile, level)
end

-- Weapon subclass ids (Enum.ItemWeaponSubclass)
local AXE1H, AXE2H, BOW, GUN, MACE1H, MACE2H, POLEARM, SWORD1H, SWORD2H =
      0, 1, 2, 3, 4, 5, 6, 7, 8
local STAFF, FIST, DAGGER, THROWN, CROSSBOW, WAND = 10, 13, 15, 16, 18, 19

local function Set(...)
    local t = {}
    for i = 1, select("#", ...) do t[select(i, ...)] = true end
    return t
end

ns.WEAPON_PROF = {
    WARRIOR = Set(AXE1H, AXE2H, BOW, GUN, MACE1H, MACE2H, POLEARM, SWORD1H, SWORD2H, STAFF, FIST, DAGGER, THROWN, CROSSBOW),
    PALADIN = Set(AXE1H, AXE2H, MACE1H, MACE2H, POLEARM, SWORD1H, SWORD2H),
    HUNTER  = Set(AXE1H, AXE2H, BOW, GUN, POLEARM, SWORD1H, SWORD2H, STAFF, FIST, DAGGER, THROWN, CROSSBOW),
    ROGUE   = Set(BOW, GUN, MACE1H, SWORD1H, FIST, DAGGER, THROWN, CROSSBOW),
    PRIEST  = Set(MACE1H, STAFF, DAGGER, WAND),
    SHAMAN  = Set(AXE1H, AXE2H, MACE1H, MACE2H, STAFF, FIST, DAGGER),
    MAGE    = Set(SWORD1H, STAFF, DAGGER, WAND),
    WARLOCK = Set(SWORD1H, STAFF, DAGGER, WAND),
    DRUID   = Set(MACE1H, MACE2H, STAFF, FIST, DAGGER),
}

ns.WEAPON_NAMES = {
    [AXE1H] = "One-Handed Axes", [AXE2H] = "Two-Handed Axes", [BOW] = "Bows", [GUN] = "Guns",
    [MACE1H] = "One-Handed Maces", [MACE2H] = "Two-Handed Maces", [POLEARM] = "Polearms",
    [SWORD1H] = "One-Handed Swords", [SWORD2H] = "Two-Handed Swords", [STAFF] = "Staves",
    [FIST] = "Fist Weapons", [DAGGER] = "Daggers", [THROWN] = "Thrown", [CROSSBOW] = "Crossbows",
    [WAND] = "Wands",
}

ns.CAN_DUAL_WIELD = { WARRIOR = true, ROGUE = true, HUNTER = true }
ns.CAN_SHIELD = { WARRIOR = true, PALADIN = true, SHAMAN = true }

-- Armor subclass of the relic each class uses: 7 Libram, 8 Idol, 9 Totem.
ns.RELIC_SUBCLASS = { PALADIN = 7, DRUID = 8, SHAMAN = 9 }
