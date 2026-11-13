-- Offline tests for Loot Herald's logic (no game client needed).
-- Run from the repository root with Lua 5.1+:   lua tests/run_tests.lua
-- The game API is replaced with small stubs below.

ROOT = ROOT or "."
local ADDON = ROOT .. "/LootHerald/"

-- ---------------------------------------------------------------------------
-- Tiny test framework
-- ---------------------------------------------------------------------------
local passed, failed = 0, 0
local function check(cond, name, detail)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL: " .. name .. (detail and ("  (" .. tostring(detail) .. ")") or ""))
    end
end
local function eq(a, b, name) check(a == b, name, "got " .. tostring(a) .. ", want " .. tostring(b)) end
local function near(a, b, name) check(type(a) == "number" and math.abs(a - b) < 0.01, name, "got " .. tostring(a) .. ", want " .. tostring(b)) end

-- ---------------------------------------------------------------------------
-- Game API stubs
-- ---------------------------------------------------------------------------
local ITEMS = {}      -- link -> { loc, class, sub, api = {}, tip = {} }
local EQUIPPED = {}   -- slot -> link
local PLAYER = { class = "DRUID", localized = "Druid", level = 60 }

function GetLocale() return "enUS" end
function UnitClass() return PLAYER.localized, PLAYER.class end
function UnitLevel() return PLAYER.level end
function GetInventoryItemLink(_, slot) return EQUIPPED[slot] end
C_Item = {
    GetItemInfoInstant = function(link)
        local it = ITEMS[link]
        if not it then return nil end
        return 1, "Armor", "Misc", it.loc, 134400, it.class, it.sub
    end,
    GetItemStats = function(link) return (ITEMS[link] or {}).api end,
}
C_TooltipInfo = {
    GetHyperlink = function(link)
        local lines = {}
        for _, t in ipairs((ITEMS[link] or {}).tip or {}) do lines[#lines + 1] = { leftText = t } end
        return { lines = lines }
    end,
}

local function item(link, loc, class, sub, api, tip)
    ITEMS[link] = { loc = loc, class = class, sub = sub, api = api or {}, tip = tip or {} }
    return link
end
local ARMOR, WEAPON = 4, 2

-- ---------------------------------------------------------------------------
-- Load the addon's logic files with a shared namespace
-- ---------------------------------------------------------------------------
local ns = {}
local LOGIC = {
    "Core/Init.lua", "Data/Profiles.lua", "Data/ClassRules.lua", "Data/TooltipPatterns.lua",
    "Core/Scoring.lua", "Core/ItemReader.lua", "Core/Compare.lua", "Core/Role.lua", "Core/Judge.lua", "Core/Announce.lua", "Core/SelfTest.lua",
}
for _, f in ipairs(LOGIC) do
    local chunk, err = loadfile(ADDON .. f)
    assert(chunk, err)
    chunk("LootHerald", ns)
end

-- Every other file must at least compile.
local ALL = {
    "UI/Theme.lua", "UI/AlertFrame.lua", "UI/RolePicker.lua", "UI/Options.lua", "UI/Tooltip.lua",
    "Core/Events.lua", "Core/Slash.lua",
}
for _, f in ipairs(ALL) do
    local chunk, err = loadfile(ADDON .. f)
    check(chunk ~= nil, "compiles: " .. f, err)
end

ns.db = ns.ApplyDefaults({}, ns.defaults)
ns.char = ns.ApplyDefaults({}, ns.charDefaults)

-- ---------------------------------------------------------------------------
-- Profiles
-- ---------------------------------------------------------------------------
do
    local classes = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
    local keys = {}
    for _, c in ipairs(classes) do
        local list = ns.Profiles[c]
        check(list and #list >= 3, "profiles exist for " .. c)
        local trees = {}
        for _, p in ipairs(list or {}) do
            check(not keys[p.key], "unique key " .. p.key)
            keys[p.key] = true
            check(ns.ROLE_LABELS[p.role] ~= nil, "valid role " .. p.key)
            trees[p.tree] = true
            for stat, w in pairs(p.weights) do
                check(ns.STAT_LABELS[stat] ~= nil, "known stat " .. p.key .. "." .. stat)
                check(type(w) == "number", "numeric weight " .. p.key .. "." .. stat)
            end
            check(p.weights.HEAL ~= nil and p.weights.SPDMG ~= nil, "derived weights filled " .. p.key)
        end
        check(trees[1] and trees[2] and trees[3], "all three talent trees covered for " .. c)
    end
    local resto = ns.Role.FindProfile("DRUID", "DRUID_RESTO")
    eq(resto.weights.HEAL, 1.0, "resto HEAL weight")
    eq(ns.Role.FindProfile("MAGE", "MAGE_FIRE").weights.HEAL, 0, "mage gets nothing from healing-only gear")
    eq(ns.Role.FindProfile("MAGE", "MAGE_FIRE").weights.SPDMG, 1.0, "mage SPDMG = SP")
    eq(resto.weights.SPDMG, 0, "healer gets nothing from damage-only gear")
end

-- ---------------------------------------------------------------------------
-- Tooltip parsing
-- ---------------------------------------------------------------------------
do
    local stats, specials = ns.ItemReader.ParseTooltipLines({
        "Robe of Testing",
        "Binds when picked up",
        "Chest", "Cloth",
        "64 Armor",
        "+12 Intellect",
        "|cff00ff00Equip: Increases healing done by spells and effects by up to 33.|r",
        "Equip: Improves your chance to get a critical strike with spells by 1%.",
        "Equip: Restores 4 mana per 5 sec.",
        "Equip: Increases damage done by Fire spells and effects by up to 20.",
        "Equip: Improves your chance to hit by 2%.",
        "(2) Set: +10 Stamina",
        "Use: Restores 375 to 625 mana.",
        "Chance on hit: Blasts the target for 50 Fire damage.",
        "\"Smells faintly of sulfur.\"",
    })
    eq(stats.HEAL, 33, "parse healing")
    eq(stats.CRIT, 1, "parse spell crit as merged crit")
    eq(stats.MP5, 4, "parse mp5")
    eq(stats.SPFIRE, 20, "parse school damage")
    eq(stats.HIT, 2, "parse hit")
    eq(stats.ARMOR, 64, "parse armor line")
    eq(stats.INT, 12, "parse base intellect")
    eq(stats.STA, nil, "set bonus ignored")
    eq(#specials, 2, "two special effect lines")

    local w = ns.ItemReader.ParseTooltipLines({ "Speed 2.60", "45 - 85 Damage", "(25.0 damage per second)",
        "Equip: +24 Attack Power.", "Equip: +12 ranged Attack Power.", "Equip: Increased Defense +7.",
        "Equip: Increases damage and healing done by magical spells and effects by up to 18." })
    near(w.DPS, 25.0, "parse weapon dps")
    eq(w.AP, 24, "parse attack power")
    eq(w.RAP, 12, "parse ranged attack power (not counted as AP)")
    eq(w.DEF, 7, "parse defense")
    eq(w.SP, 18, "parse damage+healing")
end

-- ---------------------------------------------------------------------------
-- Merging API + tooltip
-- ---------------------------------------------------------------------------
do
    local s = ns.ItemReader.Merge({ ITEM_MOD_SPELL_POWER_SHORT = 20, ITEM_MOD_STAMINA_SHORT = 5 }, { HEAL = 20, STA = 5, MP5 = 3 })
    eq(s.SP, 20, "API spell power kept")
    eq(s.HEAL, nil, "tooltip healing skipped when API reported spell family")
    eq(s.STA, 5, "stamina not doubled")
    eq(s.MP5, 3, "tooltip mp5 added")
    local r = ns.ItemReader.Merge({ ITEM_MOD_HIT_RATING_SHORT = 28 }, {})
    near(r.HIT, 2, "hit rating converted to percent")
    local p = ns.ItemReader.Merge({ ITEM_MOD_HIT_RATING_SHORT = 1 }, {})
    eq(p.HIT, 1, "small hit value treated as percent")
    local g = ns.ItemReader.Merge({ ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 30 }, {}, "INVTYPE_RANGED")
    eq(g.RDPS, 30, "ranged weapon dps becomes RDPS")
    eq(g.DPS, nil, "no melee DPS for a bow")
end

-- ---------------------------------------------------------------------------
-- Scoring
-- ---------------------------------------------------------------------------
do
    local S = ns.Scoring
    eq(S.Score({ STR = 10, STA = 10 }, { STR = 1, STA = 0.5 }), 15, "score sum")
    local pct, noBase = S.PercentChange(110, 100)
    near(pct, 10, "percent change")
    eq(noBase, false, "has baseline")
    local _, nb = S.PercentChange(5, 0)
    eq(nb, true, "empty baseline")
    eq(S.Classify(5, 3, false, 10), "UPGRADE", "classify upgrade")
    eq(S.Classify(1, 3, false, 10), "EQUAL", "classify equal")
    eq(S.Classify(-2.9, 3, false, 10), "EQUAL", "classify slight loss as equal")
    eq(S.Classify(-10, 3, false, 10), "DOWNGRADE", "classify downgrade")
    eq(S.Classify(0, 3, true, 0), "NONE", "worthless item")
    eq(S.Classify(100, 3, true, 4), "UPGRADE", "anything useful in empty slot")
    local m = S.MergeWeights({ A = 1, B = 2 }, { B = 5 })
    eq(m.B, 5, "override weight")
    eq(m.A, 1, "keep base weight")
end

-- ---------------------------------------------------------------------------
-- Role detection
-- ---------------------------------------------------------------------------
do
    local R = ns.Role
    local druid = ns.Profiles.DRUID
    eq(R.ChooseProfile(druid, 2, nil, "TANK").key, "DRUID_FERAL_BEAR", "feral + tank role -> bear")
    eq(R.ChooseProfile(druid, 2, nil, nil).key, "DRUID_FERAL_CAT", "feral, no role -> cat (default)")
    eq(R.ChooseProfile(druid, 3, nil, nil).key, "DRUID_RESTO", "tree 3 -> resto")
    eq(R.ChooseProfile(druid, nil, "Guardian", nil).key, "DRUID_FERAL_BEAR", "retail spec name alias")
    eq(R.ChooseProfile(druid, nil, nil, "HEALER").key, "DRUID_RESTO", "healer role only")
    eq(R.ChooseProfile(ns.Profiles.WARRIOR, nil, nil, nil).key, "WARRIOR_ARMS", "no signals -> first profile")
    eq(R.PointsFromTabInfo("Balance", "icon", 31, "file"), 31, "vanilla GetTalentTabInfo shape")
    eq(R.PointsFromTabInfo(283, "Balance", "desc", 136096, 31), 31, "newer GetTalentTabInfo shape")
end

-- ---------------------------------------------------------------------------
-- Compare.Evaluate with fake gear
-- ---------------------------------------------------------------------------
local function reset(class, localized, level)
    for k in pairs(EQUIPPED) do EQUIPPED[k] = nil end
    PLAYER.class, PLAYER.localized, PLAYER.level = class, localized, level or 60
    ns.ItemReader.ClearCache()
end

local function evaluate(link, key, opts)
    local p = ns.Role.FindProfile(PLAYER.class, key)
    return ns.Compare.Evaluate(link, p, ns.Role.GetWeights(p), opts)
end

do -- Resto druid head upgrade
    reset("DRUID", "Druid")
    EQUIPPED[1] = item("oldHead", "INVTYPE_HEAD", ARMOR, 2, { ITEM_MOD_INTELLECT_SHORT = 10, ITEM_MOD_SPIRIT_SHORT = 5 })
    local new = item("newHead", "INVTYPE_HEAD", ARMOR, 2, { ITEM_MOD_INTELLECT_SHORT = 8 },
        { "Equip: Increases healing done by spells and effects by up to 22." })
    local r = evaluate(new, "DRUID_RESTO")
    eq(r.verdict, "UPGRADE", "resto: healing helm is an upgrade")
    eq(r.replaced[1], "oldHead", "resto: replaces old helm")
    local cat = evaluate(new, "DRUID_FERAL_CAT")
    eq(cat.verdict, "DOWNGRADE", "cat: healing helm is not an upgrade")

    local mail = item("mailHead", "INVTYPE_HEAD", ARMOR, 3, { ITEM_MOD_INTELLECT_SHORT = 30 })
    eq(evaluate(mail, "DRUID_RESTO").verdict, "NOT_USABLE", "druid can't wear mail")

    local wand = item("wand", "INVTYPE_RANGEDRIGHT", WEAPON, 19, { ITEM_MOD_INTELLECT_SHORT = 5 })
    eq(evaluate(wand, "DRUID_RESTO").verdict, "NOT_USABLE", "druid can't use wands")
end

do -- Off-spec detection through Judge.Item
    reset("DRUID", "Druid")
    ns.char.profileKey = "DRUID_RESTO"
    EQUIPPED[3] = item("oldShoulder", "INVTYPE_SHOULDER", ARMOR, 2, { ITEM_MOD_INTELLECT_SHORT = 12 })
    local agi = item("agiShoulder", "INVTYPE_SHOULDER", ARMOR, 2, { ITEM_MOD_AGILITY_SHORT = 15, ITEM_MOD_STAMINA_SHORT = 10 })
    local res = ns.Judge.Item(agi)
    eq(res.display, "OFFSPEC", "agility shoulders: off-spec for a resto druid")
    check(res.offspec and #res.offspec >= 1, "off-spec list filled")
    check(ns.Judge.ShortText(res) ~= nil, "short text for off-spec")
    ns.char.profileKey = nil
end

do -- Warrior armor type
    reset("WARRIOR", "Warrior", 60)
    EQUIPPED[5] = item("plateChest", "INVTYPE_CHEST", ARMOR, 4, { ITEM_MOD_STRENGTH_SHORT = 10 })
    local mailChest = item("mailChest", "INVTYPE_CHEST", ARMOR, 3, { ITEM_MOD_STRENGTH_SHORT = 20 })
    eq(evaluate(mailChest, "WARRIOR_ARMS").verdict, "NOT_USABLE", "lvl 60 warrior: mail isn't your type")
    eq(evaluate(mailChest, "WARRIOR_ARMS", { respectArmorType = false }).verdict, "UPGRADE", "armor type rule can be off")
    PLAYER.level = 30
    eq(evaluate(mailChest, "WARRIOR_ARMS").verdict, "UPGRADE", "lvl 30 warrior: mail is fine")
    local plate = item("plateLegs", "INVTYPE_LEGS", ARMOR, 4, { ITEM_MOD_STRENGTH_SHORT = 5 })
    eq(evaluate(plate, "WARRIOR_ARMS").verdict, "NOT_USABLE", "lvl 30 warrior: can't wear plate yet")
end

do -- Rings compare against the weaker ring; empty slots; equal items
    reset("ROGUE", "Rogue")
    EQUIPPED[11] = item("strongRing", "INVTYPE_FINGER", ARMOR, 0, { ITEM_MOD_AGILITY_SHORT = 20 })
    EQUIPPED[12] = item("weakRing", "INVTYPE_FINGER", ARMOR, 0, { ITEM_MOD_AGILITY_SHORT = 5 })
    local mid = item("midRing", "INVTYPE_FINGER", ARMOR, 0, { ITEM_MOD_AGILITY_SHORT = 10 })
    local r = evaluate(mid, "ROGUE_COMBAT")
    eq(r.verdict, "UPGRADE", "ring beats the weaker ring")
    eq(r.replaced[1], "weakRing", "ring replaces the weaker ring")

    local same = item("sameRing", "INVTYPE_FINGER", ARMOR, 0, { ITEM_MOD_AGILITY_SHORT = 20 })
    EQUIPPED[12] = item("strongRing2", "INVTYPE_FINGER", ARMOR, 0, { ITEM_MOD_AGILITY_SHORT = 20 })
    eq(evaluate(same, "ROGUE_COMBAT").verdict, "EQUAL", "identical ring is about equal")

    local cloak = item("cloak", "INVTYPE_CLOAK", ARMOR, 1, { ITEM_MOD_AGILITY_SHORT = 3 })
    local c = evaluate(cloak, "ROGUE_COMBAT")
    eq(c.verdict, "UPGRADE", "anything useful fills an empty slot")
    eq(c.emptySlot, true, "empty slot flagged")

    local leatherCloth = item("clothGloves", "INVTYPE_HAND", ARMOR, 1, { ITEM_MOD_AGILITY_SHORT = 30 })
    eq(evaluate(leatherCloth, "ROGUE_COMBAT").verdict, "NOT_USABLE", "rogue skips cloth gloves")
end

do -- Weapons
    reset("WARRIOR", "Warrior", 60)
    EQUIPPED[16] = item("sword", "INVTYPE_WEAPON", WEAPON, 7, { ITEM_MOD_STRENGTH_SHORT = 5, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 30 })
    EQUIPPED[17] = item("shield", "INVTYPE_SHIELD", ARMOR, 6, { RESISTANCE0_NAME = 1500, ITEM_MOD_STAMINA_SHORT = 10 })
    local twoH = item("greatsword", "INVTYPE_2HWEAPON", WEAPON, 8, { ITEM_MOD_STRENGTH_SHORT = 25, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 48 })
    local arms = evaluate(twoH, "WARRIOR_ARMS")
    eq(arms.verdict, "UPGRADE", "arms: big two-hander beats sword + shield")
    eq(#arms.replaced, 2, "two-hander replaces both hands")
    local prot = evaluate(twoH, "WARRIOR_PROT")
    check(prot.verdict ~= "UPGRADE", "prot: two-hander doesn't beat the shield", prot.verdict)

    EQUIPPED[16], EQUIPPED[17] = twoH, nil
    local shield2 = item("shield2", "INVTYPE_SHIELD", ARMOR, 6, { RESISTANCE0_NAME = 1700 })
    eq(evaluate(shield2, "WARRIOR_PROT").verdict, "NONE", "off-hand while holding a two-hander")

    local wand = item("wand2", "INVTYPE_RANGEDRIGHT", WEAPON, 19, {})
    eq(evaluate(wand, "WARRIOR_ARMS").verdict, "NOT_USABLE", "warrior can't use wands")
end

do -- Special effects
    reset("MAGE", "Mage")
    EQUIPPED[13] = item("trinketA", "INVTYPE_TRINKET", ARMOR, 0, { ITEM_MOD_INTELLECT_SHORT = 10 })
    EQUIPPED[14] = item("trinketB", "INVTYPE_TRINKET", ARMOR, 0, { ITEM_MOD_INTELLECT_SHORT = 10 })
    local useOnly = item("useTrinket", "INVTYPE_TRINKET", ARMOR, 0, {}, { "Use: Increases spell damage by up to 175 for 20 sec." })
    local r = evaluate(useOnly, "MAGE_FIRE")
    eq(r.verdict, "REVIEW", "use-only trinket asks for a manual look")
    check(ns.Judge.ShortText(r) ~= nil, "review short text")

    local notGear = item("potion", "", 0, 0, {})
    eq(evaluate(notGear, "MAGE_FIRE").verdict, "NOT_GEAR", "non-equippable ignored")
end

do -- Alert decision
    local db = ns.ApplyDefaults({}, ns.defaults)
    check(ns.Judge.ShouldAlert({ display = "UPGRADE" }, db), "alert on upgrade")
    check(ns.Judge.ShouldAlert({ display = "EQUAL" }, db), "alert on equal by default")
    db.alertOnEqual = false
    check(not ns.Judge.ShouldAlert({ display = "EQUAL" }, db), "equal alerts can be turned off")
    check(not ns.Judge.ShouldAlert({ display = "DOWNGRADE" }, db), "no alert on downgrade")
end

-- ---------------------------------------------------------------------------
-- v0.1 release features: why / hit cap / group check / bind warning
-- ---------------------------------------------------------------------------
do -- Pure helpers
    local S = ns.Scoring
    local rows = S.StatDiff({ HEAL = 22, INT = 8 }, { INT = 10, SPI = 5 }, { HEAL = 1, INT = 0.6, SPI = 0.15, STR = 1 })
    eq(rows[1].stat, "HEAL", "diff: biggest effect first")
    eq(#rows, 3, "diff: only changed stats that matter")
    local capped, was = S.ApplyHitCap({ HIT = 3, AGI = 5 }, 8, 9)
    eq(capped.HIT, 1, "hit cap: only 1% of room left")
    eq(was, true, "hit cap: flagged")
    local same = S.ApplyHitCap({ HIT = 1 }, 2, 9)
    eq(same.HIT, 1, "hit cap: under cap untouched")
    eq(S.ApplyHitCap({ HIT = 2 }, 12, 9).HIT, 0, "hit cap: already over cap")
    near(S.Share({ STR = 10 }, ns.Role.FindProfile("WARRIOR", "WARRIOR_ARMS").weights, ns.MAX_WEIGHTS), 1, "share: STR is fully an arms stat")
    eq(S.Share({}, {}, ns.MAX_WEIGHTS), 0, "share: empty item")

    eq(ns.Judge.BindNote(ns.Judge.BIND_EQUIP, false) ~= nil, true, "bind note for BoE")
    eq(ns.Judge.BindNote(ns.Judge.BIND_PICKUP, true), nil, "no bind note for BoP")
    eq(ns.Judge.BindNote(nil, false), nil, "no bind note when unknown")

    local why = ns.Judge.WhyText({ diff = rows })
    check(why and why:find("+22 Healing", 1, true), "why text names the stat", why)
    eq(ns.Judge.WhyText({ diff = {} }), nil, "no why text without changes")
    check(ns.Judge.WhyText({ diff = { { stat = "HIT", delta = 1, points = 16 } } }):find("+1% Hit", 1, true), "percent stats show %")
end

do -- Evaluate fills the diff
    reset("DRUID", "Druid")
    EQUIPPED[1] = item("oldHead2", "INVTYPE_HEAD", ARMOR, 2, { ITEM_MOD_INTELLECT_SHORT = 10, ITEM_MOD_SPIRIT_SHORT = 5 })
    local new = item("newHead2", "INVTYPE_HEAD", ARMOR, 2, { ITEM_MOD_INTELLECT_SHORT = 8 },
        { "Equip: Increases healing done by spells and effects by up to 22." })
    local r = evaluate(new, "DRUID_RESTO")
    eq(r.diff[1].stat, "HEAL", "evaluate: why leads with healing")
end

do -- Hit cap in a real comparison
    reset("ROGUE", "Rogue")
    EQUIPPED[1] = item("hitHead", "INVTYPE_HEAD", ARMOR, 2, { ITEM_MOD_HIT_RATING_SHORT = 4 })
    EQUIPPED[5] = item("hitChest", "INVTYPE_CHEST", ARMOR, 2, { ITEM_MOD_HIT_RATING_SHORT = 4 })
    EQUIPPED[11] = item("agiRing1", "INVTYPE_FINGER", ARMOR, 0, { ITEM_MOD_AGILITY_SHORT = 10 })
    EQUIPPED[12] = item("agiRing2", "INVTYPE_FINGER", ARMOR, 0, { ITEM_MOD_AGILITY_SHORT = 10 })
    local hitRing = item("hitRing", "INVTYPE_FINGER", ARMOR, 0, { ITEM_MOD_HIT_RATING_SHORT = 3 })
    local capped = evaluate(hitRing, "ROGUE_COMBAT")
    eq(capped.hitCapped, true, "rogue at 8% hit: ring's hit is capped")
    near(capped.newScore, 17, "only 1% hit counts (17 per %)")
    ns.db.hitCap = false
    local uncapped = evaluate(hitRing, "ROGUE_COMBAT")
    near(uncapped.newScore, 51, "cap off: all 3% count")
    ns.db.hitCap = true
    eq(ns.Compare.EquippedHit(), 8, "equipped hit adds up")
    eq(ns.Compare.HitCapFor(ns.Role.FindProfile("MAGE", "MAGE_FIRE")), 16, "casters use the spell cap")
    eq(ns.Compare.HitCapFor(ns.Role.FindProfile("ROGUE", "ROGUE_COMBAT")), 9, "melee use the melee cap")
end

do -- Group check (who else wants it)
    local agiLeather = { AGI = 15, STA = 8 }
    local W = ns.Judge.MemberWants
    check(W(agiLeather, "INVTYPE_CHEST", ARMOR, 2, "ROGUE", 60, nil) ~= nil, "group: rogue wants agility leather")
    check(W(agiLeather, "INVTYPE_CHEST", ARMOR, 2, "DRUID", 60, "DPS") ~= nil, "group: cat druid wants it")
    eq(W(agiLeather, "INVTYPE_CHEST", ARMOR, 2, "DRUID", 60, "HEALER"), nil, "group: resto druid doesn't")
    eq(W(agiLeather, "INVTYPE_CHEST", ARMOR, 2, "MAGE", 60, nil), nil, "group: mage can't wear leather")
    eq(W(agiLeather, "INVTYPE_CHEST", ARMOR, 2, "WARRIOR", 60, nil), nil, "group: lvl 60 warrior skips leather")
    local spellCloth = { SP = 20, INT = 10 }
    check(W(spellCloth, "INVTYPE_HEAD", ARMOR, 1, "MAGE", 60, nil) ~= nil, "group: mage wants spell cloth")
    eq(W({ STA = 5 }, "INVTYPE_FINGER", ARMOR, 0, "MAGE", 60, "DPS"), nil, "group: stamina-only ring isn't a caster item")
end

do -- Announce Need rolls in group chat
    reset("DRUID", "Druid")
    local resto = ns.Role.FindProfile("DRUID", "DRUID_RESTO")
    local diff = { { stat = "HEAL", delta = 22, points = 22 }, { stat = "INT", delta = 8, points = 4.8 },
                   { stat = "SPI", delta = -5, points = -0.75 } }
    local up = { link = "[Robe of Testing]", display = "UPGRADE", pct = 14.2, profile = resto, diff = diff }
    local msg = ns.Judge.AnnounceText(up)
    eq(msg, "[Loot Herald] Need on [Robe of Testing]: +14% upgrade for my Restoration Druid (+22 Healing, +8 Int, -5 Spirit)",
       "announce: upgrade message")
    check(msg and not msg:find("|", 1, true), "announce: no colour codes in chat text")
    local eqRes = { link = "[Ring]", display = "EQUAL", pct = 1, profile = resto }
    eq(ns.Judge.AnnounceText(eqRes), "[Loot Herald] Need on [Ring]: about equal (+1%) for my Restoration Druid", "announce: equal, no why")
    local empty = { link = "[Cloak]", display = "UPGRADE", pct = 100, emptySlot = true, profile = resto, diff = diff }
    check(ns.Judge.AnnounceText(empty):find("fills an empty slot", 1, true), "announce: empty slot wording")
    eq(ns.Judge.AnnounceText({ link = "[X]", display = "DOWNGRADE", pct = -20, profile = resto }), nil, "announce: never for downgrades")
    eq(ns.Judge.AnnounceText({ link = "[X]", display = "OFFSPEC", pct = -5, profile = resto }), nil, "announce: never for off-spec")
    local long = { link = "[" .. string.rep("A", 170) .. "]", display = "UPGRADE", pct = 5, profile = resto, diff = diff }
    local longMsg = ns.Judge.AnnounceText(long)
    check(#longMsg <= 255, "announce: trims the why to fit 255 chars", #longMsg)
    check(longMsg:find("(+22 Healing", 1, true), "announce: keeps the top stat when trimming")

    local A = ns.Announce
    local pat = A.PatternFromFormat("You have selected Need for: %s")
    check(("You have selected Need for: |cff0070dd|Hitem:1234::::|h[Thing]|h|r"):match(pat) ~= nil, "announce: need chat pattern matches")
    check(("You have selected Greed for: [Thing]"):match(pat) == nil, "announce: greed line ignored")
    eq(A.ItemID("|cff0070dd|Hitem:1234::::|h[Thing]|h|r"), 1234, "announce: item id from link")
    eq(A.PickChannel(true, true, true), "INSTANCE_CHAT", "announce: instance group chat first")
    eq(A.PickChannel(false, true, true), "RAID", "announce: raid")
    eq(A.PickChannel(false, false, true), "PARTY", "announce: party")
    eq(A.PickChannel(false, false, false), nil, "announce: solo posts nothing")
    eq(ns.defaults.announceNeed, false, "announce: off by default")
end

do -- Maintenance helpers
    local T = ns.SelfTest
    eq(T.IsNewer("1.61.0", "1.60.1"), true, "selftest: newer minor")
    eq(T.IsNewer("1.60.1", "1.60.1"), false, "selftest: same version")
    eq(T.IsNewer("1.60.1", "1.61.0"), false, "selftest: older")
    eq(T.IsNewer("1.60.10", "1.60.9"), true, "selftest: numeric, not text, comparison")
    check(type(ns.DATA_REVIEWED_FOR) == "string", "data reviewed-for version is set")

    local L = ns.ItemReader.LooksLikeMissedStat
    eq(L("Equip: Increases spell penetration by up to 10."), true, "missed stat: 'by up to N'")
    eq(L("Equip: Improves your haste by 2%."), true, "missed stat: 'by N%'")
    eq(L("Equip: +15 Haste."), true, "missed stat: '+N'")
    eq(L("Equip: Increases your movement speed slightly."), false, "special effect isn't a missed stat")
    eq(L("Use: Restores 375 to 625 mana."), false, "Use: lines ignored")

    local _, _, unknown = ns.ItemReader.Merge({ ITEM_MOD_STAMINA_SHORT = 5, ITEM_MOD_NEW_THING_SHORT = 7 }, {})
    eq(#unknown, 1, "merge reports unknown API stat keys")
    eq(unknown[1], "ITEM_MOD_NEW_THING_SHORT", "unknown key name")
end

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 and os and os.exit then os.exit(1) end
