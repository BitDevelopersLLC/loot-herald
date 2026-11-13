-- Loot Herald: shared namespace, defaults and small helpers.
-- Every file in this addon receives (addonName, ns) from the game client.
local ADDON_NAME, ns = ...

ns.ADDON_NAME = ADDON_NAME
ns.TITLE = "Loot Herald"
ns.SHORT = "Loot Herald"
ns.GOLD = "d4af37"
ns.PREFIX = "|cffd4af37[Loot Herald]|r "

local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.VERSION = (GetMeta and GetMeta(ADDON_NAME, "Version")) or "dev"

-- Account-wide settings (SavedVariables: LootHeraldDB)
ns.defaults = {
    enabled = true,
    onlyInInstances = true,   -- only judge rolls inside dungeons (and raids, see below)
    includeRaids = true,
    threshold = 3,            -- percent: >= +threshold is an upgrade, within +/-threshold is "about equal"
    alertOnEqual = true,      -- "better or equal" -> equal items alert too
    alertOffSpec = true,      -- tell me when it's an upgrade for another spec/role of my class
    alertOnUnscored = true,   -- items with Use:/proc effects we can't score
    respectArmorType = true,  -- a warrior shouldn't Need leather, etc.
    playSound = true,
    raidWarning = true,       -- big centre-screen text for upgrades
    chatSummary = true,       -- one chat line per drop judged
    tooltipLine = true,       -- add a verdict line to item tooltips everywhere
    announceNeed = false,     -- opt-in: post "Need on [item]: +14% upgrade ... (why)" to group chat
    askRoleOnEnter = true,    -- role picker when entering a dungeon
    alertScale = 1.0,
    customWeights = {},       -- [profileKey][STAT] = number (user overrides)
    showWhy = true,           -- "+22 Healing, +8 Int, -5 Spirit" on alerts and tooltips
    groupCheck = true,        -- "also good for: <party member>"
    bindWarning = true,       -- Bind on Equip reminder
    hitCap = true,            -- hit past the cap is worth nothing
    -- Hit caps in %. UNVERIFIED for WoW Forever's merged Hit stat: these are the
    -- Vanilla raid-boss values. Change with /lh hitcap <melee> <spell> [bonus].
    hitCapMelee = 9,
    hitCapSpell = 16,
    hitBonus = 0,             -- hit from talents/racials that gear doesn't show
    welcomed = false,
}

-- Per-character settings (SavedVariablesPerCharacter: LootHeraldCharDB)
ns.charDefaults = {
    profileKey = nil,     -- chosen class/spec/role profile
    dontAsk = false,      -- skip the picker unless talents or group role change
    lastTree = nil,       -- talent signals when the profile was picked
    lastSpecName = nil,
    lastAssigned = nil,
    history = {},
}

function ns.ApplyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            if type(v) == "table" then
                target[k] = ns.ApplyDefaults({}, v)
            else
                target[k] = v
            end
        end
    end
    return target
end

function ns.Print(fmt, ...)
    local msg = (select("#", ...) > 0) and string.format(fmt, ...) or tostring(fmt)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(ns.PREFIX .. msg)
    else
        print(ns.PREFIX .. msg)
    end
end

ns.debugMode = false
function ns.Debug(fmt, ...)
    if ns.debugMode then ns.Print("|cff888888debug:|r " .. tostring(fmt), ...) end
end

function ns.Color(hex, text)
    return "|cff" .. hex .. tostring(text) .. "|r"
end

-- Verdict colours (hex) used by chat, tooltip and alert text.
ns.VERDICT_COLORS = {
    UPGRADE   = "1eff00",
    EQUAL     = "ffd100",
    OFFSPEC   = "66b3ff",
    REVIEW    = "ff9933",
    DOWNGRADE = "9d9d9d",
    NONE      = "9d9d9d",
    NOT_USABLE = "9d9d9d",
}

function ns.FormatPct(pct)
    if not pct then return "" end
    local sign = pct >= 0 and "+" or ""
    return string.format("%s%.0f%%", sign, pct)
end
