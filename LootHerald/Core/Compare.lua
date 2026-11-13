-- Loot Herald: compare a dropped item with what the player has equipped.
local _, ns = ...

local Compare = {}
ns.Compare = Compare

-- Inventory slot ids
local HEAD, NECK, SHOULDER, CHEST, WAIST, LEGS, FEET, WRIST, HANDS = 1, 2, 3, 5, 6, 7, 8, 9, 10
local FINGER1, FINGER2, TRINKET1, TRINKET2, BACK, MAINHAND, OFFHAND, RANGED = 11, 12, 13, 14, 15, 16, 17, 18

Compare.SLOT_NAMES = {
    [HEAD] = "Head", [NECK] = "Neck", [SHOULDER] = "Shoulder", [CHEST] = "Chest", [WAIST] = "Waist",
    [LEGS] = "Legs", [FEET] = "Feet", [WRIST] = "Wrist", [HANDS] = "Hands",
    [FINGER1] = "Ring", [FINGER2] = "Ring", [TRINKET1] = "Trinket", [TRINKET2] = "Trinket",
    [BACK] = "Back", [MAINHAND] = "Main Hand", [OFFHAND] = "Off Hand", [RANGED] = "Ranged / Relic",
}

-- equipLoc -> list of slot sets to compare against. The best result wins
-- (so a ring is compared with your weaker ring).
local SIMPLE = {
    INVTYPE_HEAD = { { HEAD } }, INVTYPE_NECK = { { NECK } }, INVTYPE_SHOULDER = { { SHOULDER } },
    INVTYPE_CHEST = { { CHEST } }, INVTYPE_ROBE = { { CHEST } }, INVTYPE_WAIST = { { WAIST } },
    INVTYPE_LEGS = { { LEGS } }, INVTYPE_FEET = { { FEET } }, INVTYPE_WRIST = { { WRIST } },
    INVTYPE_HAND = { { HANDS } }, INVTYPE_FINGER = { { FINGER1 }, { FINGER2 } },
    INVTYPE_TRINKET = { { TRINKET1 }, { TRINKET2 } }, INVTYPE_CLOAK = { { BACK } },
    INVTYPE_RANGED = { { RANGED } }, INVTYPE_RANGEDRIGHT = { { RANGED } },
    INVTYPE_THROWN = { { RANGED } }, INVTYPE_RELIC = { { RANGED } },
}

local OFFHAND_LOCS = { INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true }
local ONEHAND_WEAPON_LOCS = { INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true }

function Compare.ItemInstant(link)
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not fn or not link then return nil end
    local itemID, _, _, equipLoc, icon, classID, subclassID = fn(link)
    return itemID, equipLoc, icon, classID, subclassID
end

local function EquippedLink(slot)
    return GetInventoryItemLink("player", slot)
end

local function EquippedLoc(slot)
    local link = EquippedLink(slot)
    if not link then return nil end
    local _, loc = Compare.ItemInstant(link)
    return loc, link
end

-- Can (and should) this class use the item? Returns ok, reason.
function Compare.CheckUsable(classFile, level, equipLoc, classID, subclassID, respectArmorType)
    if classID == ns.ITEM_CLASS_ARMOR then
        if subclassID == 6 then
            if ns.ARMOR_PREF[classFile] and not ns.CAN_SHIELD[classFile] then
                return false, "Your class can't use shields"
            end
        elseif subclassID and subclassID >= 7 and subclassID <= 11 then
            local relic = ns.RELIC_SUBCLASS[classFile]
            if ns.ARMOR_PREF[classFile] and relic ~= subclassID then
                return false, "That relic is for another class"
            end
        elseif ns.ARMOR_TYPED_SLOTS[equipLoc] and subclassID and subclassID >= 1 and subclassID <= 4 then
            local pref = ns.PreferredArmor(classFile, level)
            if pref then
                if subclassID > pref then
                    return false, string.format("You can't wear %s yet", ns.ARMOR_NAMES[subclassID])
                end
                if respectArmorType and subclassID < pref then
                    return false, string.format("%s isn't your armor type (%s)",
                        ns.ARMOR_NAMES[subclassID], ns.ARMOR_NAMES[pref])
                end
            end
        end
    elseif classID == ns.ITEM_CLASS_WEAPON then
        local prof = ns.WEAPON_PROF[classFile]
        if prof and subclassID and not prof[subclassID] then
            return false, string.format("Your class can't use %s", ns.WEAPON_NAMES[subclassID] or "this weapon")
        end
    end
    return true
end

-- Which equipped slots should a new item be compared with?
-- Returns sets (or nil) and an optional note.
function Compare.CandidateSets(equipLoc, classFile)
    local mhLoc = EquippedLoc(MAINHAND)
    local mhIs2H = (mhLoc == "INVTYPE_2HWEAPON")

    if equipLoc == "INVTYPE_2HWEAPON" then
        return { { MAINHAND, OFFHAND } }
    end
    if OFFHAND_LOCS[equipLoc] then
        if mhIs2H then return nil, "You're using a two-handed weapon" end
        return { { OFFHAND } }
    end
    if equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONMAINHAND" then
        if mhIs2H then
            return { { MAINHAND } }, "Compared with your two-handed weapon"
        end
        local sets = { { MAINHAND } }
        if equipLoc == "INVTYPE_WEAPON" and ns.CAN_DUAL_WIELD[classFile] then
            local ohLoc = EquippedLoc(OFFHAND)
            if ohLoc == nil or ONEHAND_WEAPON_LOCS[ohLoc] then
                sets[#sets + 1] = { OFFHAND }
            end
        end
        return sets
    end
    return SIMPLE[equipLoc]
end

-- Hit cap (%) for a profile, or false when the hit cap option is off.
function Compare.HitCapFor(profile)
    local db = ns.db
    if not db or not db.hitCap or not profile then return false end
    if profile.hitCapType == "spell" then return db.hitCapSpell or 16 end
    return db.hitCapMelee or 9
end

-- Total Hit % from everything equipped, plus the player's manual bonus.
function Compare.EquippedHit()
    local total = (ns.db and ns.db.hitBonus) or 0
    for slot = HEAD, RANGED do
        if slot ~= 4 then -- shirt
            local link = EquippedLink(slot)
            if link then
                local _, loc = Compare.ItemInstant(link)
                total = total + (ns.ItemReader.GetStats(link, loc).stats.HIT or 0)
            end
        end
    end
    return total
end

-- Main entry point.
-- result.verdict: UPGRADE / EQUAL / DOWNGRADE / NONE / REVIEW / NOT_USABLE / NOT_GEAR
function Compare.Evaluate(link, profile, weights, opts)
    opts = opts or {}
    local res = { link = link, profile = profile, specials = {}, replaced = {} }
    local _, equipLoc, icon, classID, subclassID = Compare.ItemInstant(link)
    res.icon, res.equipLoc = icon, equipLoc

    if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP_IGNORE" or equipLoc == "INVTYPE_NON_EQUIP"
        or equipLoc == "INVTYPE_BAG" or equipLoc == "INVTYPE_BODY" or equipLoc == "INVTYPE_TABARD"
        or equipLoc == "INVTYPE_AMMO" or equipLoc == "INVTYPE_QUIVER" then
        res.verdict = "NOT_GEAR"
        return res
    end

    local classFile = opts.classFile or select(2, UnitClass("player"))
    local level = opts.level or UnitLevel("player")
    local respect = opts.respectArmorType
    if respect == nil then respect = not ns.db or ns.db.respectArmorType ~= false end

    local ok, why = Compare.CheckUsable(classFile, level, equipLoc, classID, subclassID, respect)
    if not ok then
        res.verdict, res.reason = "NOT_USABLE", why
        return res
    end

    local sets, note = Compare.CandidateSets(equipLoc, classFile)
    res.note = note
    if not sets then
        res.verdict, res.reason = "NONE", note
        return res
    end

    local info = ns.ItemReader.GetStats(link, equipLoc)
    res.stats, res.specials = info.stats, info.specials

    local cap = opts.hitCap
    if cap == nil then cap = Compare.HitCapFor(profile) end
    local gearHit = cap and (opts.gearHit or Compare.EquippedHit()) or 0

    local S = ns.Scoring
    local best
    for _, set in ipairs(sets) do
        local oldStats, links, empty, special = {}, {}, true, false
        for _, slot in ipairs(set) do
            local eq = EquippedLink(slot)
            if eq then
                empty = false
                links[#links + 1] = eq
                if eq == link then res.isEquipped = true end
                local _, eqLoc = Compare.ItemInstant(eq)
                local eqInfo = ns.ItemReader.GetStats(eq, eqLoc)
                S.AddStats(oldStats, eqInfo.stats)
                if #eqInfo.specials > 0 then special = true end
            end
        end
        local newEff, oldEff, capped = info.stats, oldStats, false
        if cap then
            local baseHit = gearHit - (oldStats.HIT or 0)
            newEff, capped = S.ApplyHitCap(info.stats, baseHit, cap)
            oldEff = S.ApplyHitCap(oldStats, baseHit, cap)
        end
        local newScore, old = S.Score(newEff, weights), S.Score(oldEff, weights)
        local pct, noBase = S.PercentChange(newScore, old)
        if not best or pct > best.pct then
            best = { pct = pct, old = old, new = newScore, links = links, empty = empty, noBase = noBase,
                     slot = set[1], special = special, newEff = newEff, oldEff = oldEff, capped = capped }
        end
    end

    local newScore = best.new
    res.newScore, res.pct, res.oldScore, res.replaced = newScore, best.pct, best.old, best.links
    res.emptySlot, res.slotName, res.replacedHasSpecial = best.empty, Compare.SLOT_NAMES[best.slot], best.special
    res.diff = S.StatDiff(best.newEff, best.oldEff, weights)
    res.hitCapped = best.capped

    local threshold = opts.threshold or (ns.db and ns.db.threshold) or 3
    res.verdict = ns.Scoring.Classify(best.pct, threshold, best.noBase, newScore)

    -- Effects we can't put a number on (Use:, Chance on hit:, unusual Equip:).
    if #res.specials > 0 and (res.verdict == "NONE" or (res.verdict == "DOWNGRADE" and best.pct > -25)) then
        res.verdict = "REVIEW"
        res.reason = "Has an effect Loot Herald can't score - read the tooltip"
    end
    return res
end
