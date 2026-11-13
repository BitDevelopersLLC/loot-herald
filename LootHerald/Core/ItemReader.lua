-- Loot Herald: turn an item link into a table of stats.
--
-- Two sources, in this order:
--   1. The game API (C_Item.GetItemStats) for plain stats.
--   2. English tooltip text for "Equip:" bonuses the API may not report.
-- A stat family the API already reported is never read again from the tooltip,
-- so nothing is counted twice.
local _, ns = ...

local IR = {}
ns.ItemReader = IR

-- Game API stat keys -> our stat keys.
IR.API_STAT_MAP = {
    ITEM_MOD_STRENGTH_SHORT = "STR",
    ITEM_MOD_AGILITY_SHORT = "AGI",
    ITEM_MOD_STAMINA_SHORT = "STA",
    ITEM_MOD_INTELLECT_SHORT = "INT",
    ITEM_MOD_SPIRIT_SHORT = "SPI",
    RESISTANCE0_NAME = "ARMOR",
    ITEM_MOD_ATTACK_POWER_SHORT = "AP",
    ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RAP",
    ITEM_MOD_SPELL_POWER_SHORT = "SP",
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "SPDMG",
    ITEM_MOD_SPELL_HEALING_DONE_SHORT = "HEAL",
    ITEM_MOD_MANA_REGENERATION_SHORT = "MP5",
    ITEM_MOD_POWER_REGEN0_SHORT = "MP5",
    ITEM_MOD_HEALTH_REGEN_SHORT = "HP5",
    ITEM_MOD_HEALTH_REGENERATION_SHORT = "HP5",
    ITEM_MOD_HIT_RATING_SHORT = "HIT",
    ITEM_MOD_HIT_SPELL_RATING_SHORT = "HIT",
    ITEM_MOD_HIT_MELEE_RATING_SHORT = "HIT",
    ITEM_MOD_HIT_RANGED_RATING_SHORT = "HIT",
    ITEM_MOD_CRIT_RATING_SHORT = "CRIT",
    ITEM_MOD_CRIT_SPELL_RATING_SHORT = "CRIT",
    ITEM_MOD_CRIT_MELEE_RATING_SHORT = "CRIT",
    ITEM_MOD_CRIT_RANGED_RATING_SHORT = "CRIT",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEF",
    ITEM_MOD_DODGE_RATING_SHORT = "DODGE",
    ITEM_MOD_PARRY_RATING_SHORT = "PARRY",
    ITEM_MOD_BLOCK_RATING_SHORT = "BLOCK",
    ITEM_MOD_BLOCK_VALUE_SHORT = "BLOCKVALUE",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS",
}

-- Stats we weight per 1%. If the API ever reports them as ratings (values far
-- above what a Vanilla item gives), they are converted with RATING_PER_PERCENT.
-- UNVERIFIED for WoW Forever: check with /lh debug and adjust if needed.
IR.PERCENT_STATS = { HIT = true, CRIT = true, DODGE = true, PARRY = true, BLOCK = true }
IR.RATING_PER_PERCENT = 14
IR.MAX_PLAUSIBLE_PERCENT = 5

-- A family is skipped in the tooltip pass if the API reported any member of it.
IR.FAMILY = {
    SP = "spell", HEAL = "spell", SPDMG = "spell",
    SPFIRE = "spell", SPFROST = "spell", SPSHADOW = "spell",
    SPARCANE = "spell", SPNATURE = "spell", SPHOLY = "spell",
    AP = "ap", RAP = "rap",
}

local RANGED_LOCS = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }
IR.RANGED_LOCS = RANGED_LOCS

local function StripCodes(s)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
    s = s:gsub("|cn[^:]*:", "")
    s = s:gsub("|r", "")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s
end
IR.StripCodes = StripCodes

local function IsSpecial(line)
    for _, prefix in ipairs(ns.SPECIAL_PREFIXES) do
        if line:find(prefix) then return true end
    end
    return false
end

-- PURE: read stats from a list of tooltip line strings.
-- Returns stats table, list of unscored special-effect lines, and a per-line log.
function IR.ParseTooltipLines(lines)
    local stats, specials, log = {}, {}, {}
    for _, raw in ipairs(lines or {}) do
        if type(raw) == "string" and raw ~= "" then
            local line = StripCodes(raw)
            local isSet = line:find("^%(%d+%) Set:") or line:find("^Set:")
            if not isSet then
                local isEquip = line:find("^Equip: ") ~= nil
                local body = isEquip and (line:gsub("^Equip: ", "")) or line
                local matched
                for _, p in ipairs(ns.TooltipPatterns) do
                    if isEquip or not p.equip then
                        local a, b = body:match(p.pattern)
                        if a then
                            local stat, value = p.stat, tonumber(a)
                            if p.school then
                                local school, num = a, b
                                if p.swap then school, num = b, a end
                                stat = ns.SCHOOL_STATS[(school or ""):lower()]
                                value = tonumber(num)
                            end
                            if stat and value then
                                stats[stat] = (stats[stat] or 0) + value
                                matched = stat
                                break
                            end
                        end
                    end
                end
                if matched then
                    log[#log + 1] = { line = line, stat = matched }
                elseif IsSpecial(line) then
                    specials[#specials + 1] = line
                    log[#log + 1] = { line = line, special = true }
                end
            end
        end
    end
    return stats, specials, log
end

-- PURE: does an unscored "Equip:" line look like a stat we failed to read
-- (new wording after a patch) rather than a normal special effect?
function IR.LooksLikeMissedStat(line)
    if type(line) ~= "string" or not line:find("^Equip: ") then return false end
    return line:find("by up to %d") ~= nil
        or line:find("by %d+%%?%.?$") ~= nil
        or line:find("^Equip: %+%d") ~= nil
        or line:find("rating by %d") ~= nil
end

-- PURE: combine API stats and tooltip stats without double counting.
-- Third return: API stat keys we don't recognise (a patch may add new ones).
function IR.Merge(apiStats, tipStats, equipLoc)
    local stats, sources, families, unknown = {}, {}, {}, {}
    for key, value in pairs(apiStats or {}) do
        local stat = IR.API_STAT_MAP[key]
        if not stat and type(value) == "number" and value ~= 0 then unknown[#unknown + 1] = key end
        if stat and type(value) == "number" and value ~= 0 then
            local src = "api"
            if IR.PERCENT_STATS[stat] and value > IR.MAX_PLAUSIBLE_PERCENT then
                value = value / IR.RATING_PER_PERCENT
                src = "api (rating converted)"
            end
            stats[stat] = (stats[stat] or 0) + value
            sources[stat] = src
            if IR.FAMILY[stat] then families[IR.FAMILY[stat]] = true end
        end
    end
    for stat, value in pairs(tipStats or {}) do
        local fam = IR.FAMILY[stat]
        if stats[stat] == nil and not (fam and families[fam]) then
            stats[stat] = value
            sources[stat] = "tooltip"
        end
    end
    -- A ranged weapon's DPS is ranged DPS.
    if stats.DPS and equipLoc and RANGED_LOCS[equipLoc] then
        stats.RDPS = (stats.RDPS or 0) + stats.DPS
        sources.RDPS = sources.DPS
        stats.DPS, sources.DPS = nil, nil
    end
    table.sort(unknown)
    return stats, sources, unknown
end

-- ---------------------------------------------------------------------------
-- Game-client functions below
-- ---------------------------------------------------------------------------

function IR.CanParseTooltips()
    local loc = GetLocale and GetLocale()
    return loc == "enUS" or loc == "enGB"
end

local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

function IR.GetTooltipLines(link)
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
        if ok and type(data) == "table" and type(data.lines) == "table" then
            local out = {}
            for _, line in ipairs(data.lines) do
                local t = line.leftText
                if t == nil and type(line.args) == "table" then
                    for _, arg in ipairs(line.args) do
                        if arg.field == "leftText" then t = arg.stringVal end
                    end
                end
                if type(t) == "string" and not IsSecret(t) then out[#out + 1] = t end
            end
            return out
        end
    end
    -- Fallback: a hidden tooltip we read line by line.
    if not IR.scanner then
        IR.scanner = CreateFrame("GameTooltip", "LootHeraldScanTooltip", nil, "GameTooltipTemplate")
    end
    local tt = IR.scanner
    tt:SetOwner(WorldFrame, "ANCHOR_NONE")
    tt:ClearLines()
    tt:SetHyperlink(link)
    local out = {}
    for i = 1, tt:NumLines() do
        local fs = _G["LootHeraldScanTooltipTextLeft" .. i]
        local t = fs and fs:GetText()
        if type(t) == "string" and not IsSecret(t) then out[#out + 1] = t end
    end
    tt:Hide()
    return out
end

local function GetApiStats(link)
    if C_Item and C_Item.GetItemStats then
        local ok, t = pcall(C_Item.GetItemStats, link)
        if ok and type(t) == "table" then return t end
    end
    if GetItemStats then
        local ok, t = pcall(GetItemStats, link)
        if ok and type(t) == "table" then return t end
    end
    return {}
end

local cache = {}

-- Returns { stats, sources, specials, log }. Cached per link.
function IR.GetStats(link, equipLoc)
    if not link then return { stats = {}, sources = {}, specials = {}, log = {} } end
    local key = link .. "|" .. tostring(equipLoc)
    if cache[key] then return cache[key] end

    local api = GetApiStats(link)
    local tipStats, specials, log = {}, {}, {}
    if IR.CanParseTooltips() then
        local lines = IR.GetTooltipLines(link)
        tipStats, specials, log = IR.ParseTooltipLines(lines)
    end
    local stats, sources, unknown = IR.Merge(api, tipStats, equipLoc)
    local result = { stats = stats, sources = sources, specials = specials, log = log, api = api, unknown = unknown }
    -- Don't cache an empty read: the item data may simply not be loaded yet.
    if next(stats) or #specials > 0 then cache[key] = result end
    return result
end

function IR.ClearCache()
    cache = {}
end

-- Run `callback` once the client has the item's data (name, stats, tooltip).
function IR.WhenLoaded(link, callback)
    if Item and Item.CreateFromItemLink then
        local item = Item:CreateFromItemLink(link)
        if item and not item:IsItemEmpty() then
            item:ContinueOnItemLoad(callback)
            return
        end
    end
    callback()
end
