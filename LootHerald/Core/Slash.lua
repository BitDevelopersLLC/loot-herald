-- Loot Herald: slash commands (/lh or /lootherald) and the test alert.
local _, ns = ...

local function ExtractLink(msg)
    return msg:match("(|c[^|]*|Hitem:.-|h.-|h|r)") or msg:match("(|Hitem:.-|h.-|h)")
end

-- Show sample alerts using the player's own equipped items.
function ns.RunTest()
    local sample
    for _, slot in ipairs({ 1, 5, 7, 3, 16, 10, 8, 15 }) do
        sample = GetInventoryItemLink("player", slot)
        if sample then break end
    end
    local profile, auto = ns.Role.GetActive()
    local _, _, icon = ns.Compare.ItemInstant(sample or "item:6948")
    local base = { link = sample or "Hearthstone", icon = icon, profile = profile, auto = auto, specials = {} }

    -- A sample "why" from the role's three most important stats.
    local top = {}
    for stat, w in pairs(profile.weights) do
        if w > 0 and not ns.PERCENT_STAT[stat] and stat ~= "DPS" and stat ~= "RDPS" then top[#top + 1] = { stat = stat, w = w } end
    end
    table.sort(top, function(a, b) return a.w > b.w end)
    local diff = {}
    for i = 1, math.min(3, #top) do
        local delta = (i < 3) and (12 - i * 3) or -4
        diff[#diff + 1] = { stat = top[i].stat, delta = delta, points = delta * top[i].w }
    end
    base.diff = diff

    local up = {}
    for k, v in pairs(base) do up[k] = v end
    up.display, up.verdict, up.pct, up.replaced = "UPGRADE", "UPGRADE", 12.4, { sample }
    up.groupWants = { { name = "Example", classFile = "ROGUE", className = "Rogue", profile = { name = "Combat" } } }
    ns.Alert.Show(up, { rollID = -1, rollTime = 30000, test = true })

    local eq = {}
    for k, v in pairs(base) do eq[k] = v end
    eq.display, eq.verdict, eq.pct, eq.replaced = "EQUAL", "EQUAL", 1.2, { sample }
    eq.bindNote = ns.Judge.BindNote(ns.Judge.BIND_EQUIP, false)
    ns.Alert.Show(eq, { rollID = -2, rollTime = 30000, test = true })

    local others = {}
    for _, p in ipairs(ns.Role.GetClassProfiles(ns.Role.PlayerClass())) do
        if p.key ~= profile.key then others[#others + 1] = p end
    end
    if others[1] then
        local off = {}
        for k, v in pairs(base) do off[k] = v end
        off.display, off.verdict, off.pct = "OFFSPEC", "DOWNGRADE", -8
        off.offspec = { { profile = others[1], pct = 9 } }
        ns.Alert.Show(off, { rollID = -3, rollTime = 30000, test = true })
    end
    ns.Print("Showing test alerts. Drag one to move them all.")
end

local function PrintDebug(link)
    local _, equipLoc = ns.Compare.ItemInstant(link)
    local info = ns.ItemReader.GetStats(link, equipLoc)
    local profile = ns.Role.GetActive()
    local weights = ns.Role.GetWeights(profile)
    ns.Print("Debug %s (slot %s) for %s", link, tostring(equipLoc), ns.Role.Label(profile))
    print("  Raw API stats:")
    for k, v in pairs(info.api or {}) do print(string.format("    %s = %s", tostring(k), tostring(v))) end
    print("  Tooltip lines read:")
    for _, e in ipairs(info.log or {}) do
        print(string.format("    %s  ->  %s", e.line, e.special and "|cffff9933special (not scored)|r" or e.stat))
    end
    print("  Score breakdown:")
    local total = 0
    for _, r in ipairs(ns.Scoring.Breakdown(info.stats, weights)) do
        total = total + r.points
        print(string.format("    %-10s %7.2f x %6.3f = %7.2f  [%s]", r.stat, r.value, r.weight, r.points,
            info.sources[r.stat] or "?"))
    end
    print(string.format("  Total score: %.2f", total))
    local res = ns.Judge.Item(link)
    print("  Verdict: " .. (ns.Judge.ShortText(res) or res.verdict))
end

local function PrintWeights()
    local profile = ns.Role.GetActive()
    local w = ns.Role.GetWeights(profile)
    local custom = ns.db.customWeights[profile.key] or {}
    local keys = {}
    for k in pairs(w) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return w[a] > w[b] end)
    ns.Print("Weights for %s (|cff66b3ff*|r = your override):", ns.Role.LabelWithRole(profile))
    for _, k in ipairs(keys) do
        if w[k] ~= 0 then
            print(string.format("  %-10s %6.3f %s  %s", k, w[k], custom[k] and "|cff66b3ff*|r" or " ", ns.STAT_LABELS[k] or ""))
        end
    end
end

local function SetWeight(args)
    local profile = ns.Role.GetActive()
    local stat, value = args:match("^(%S+)%s*(%S*)")
    if not stat or stat == "" then
        ns.Print("Usage: /lh weight <STAT> <value>   or   /lh weight reset [STAT]")
        return
    end
    stat = stat:upper()
    ns.db.customWeights[profile.key] = ns.db.customWeights[profile.key] or {}
    local custom = ns.db.customWeights[profile.key]
    if stat == "RESET" then
        local which = value ~= "" and value:upper() or nil
        if which then custom[which] = nil else ns.db.customWeights[profile.key] = nil end
        ns.Print("Weights reset%s for %s.", which and (" (" .. which .. ")") or "", ns.Role.Label(profile))
        return
    end
    if not ns.STAT_LABELS[stat] then
        ns.Print("Unknown stat %s. Known: STR AGI STA INT SPI ARMOR AP RAP SP HEAL SPDMG SPFIRE SPFROST SPSHADOW SPARCANE SPNATURE SPHOLY MP5 HP5 HIT CRIT DEF DODGE PARRY BLOCK BLOCKVALUE DPS RDPS", stat)
        return
    end
    local n = tonumber(value)
    if not n then ns.Print("Give a number, e.g. /lh weight %s 1.2", stat) return end
    custom[stat] = n
    ns.Print("%s weight for %s set to %.3f.", stat, ns.Role.Label(profile), n)
end

local function Help()
    local p, auto = ns.Role.GetActive()
    ns.Print("v%s - judging loot for |cffffd100%s|r%s", ns.VERSION, ns.Role.LabelWithRole(p), auto and " (auto)" or "")
    print("  /lh role  - choose your class role (spec)")
    print("  /lh test  - show sample alerts (drag to move)")
    print("  /lh check <shift-click item>  - is this an upgrade?")
    print("  /lh debug <shift-click item>  - show exactly how it was scored")
    print("  /lh weights  - show stat weights for your role")
    print("  /lh weight <STAT> <value> | reset [STAT]  - override a weight")
    print("  /lh history  - last drops judged")
    print("  /lh hitcap <melee> <spell> [talent bonus]  - set hit caps")
    print("  /lh announce  - turn posting your Need rolls (and why) to group chat on/off")
    print("  /lh post  - post a Need message the game blocked (you press Enter)")
    print("  /lh selftest  - health check after a game patch (paste results into an issue)")
    print("  /lh on | off  - enable or disable")
    print("  /lh options  - settings window")
    print("  /lh resetpos  - move alerts back to the default spot")
end

SLASH_LOOTHERALD1 = "/lh"
SLASH_LOOTHERALD2 = "/lootherald"
SlashCmdList.LOOTHERALD = function(msg)
    msg = msg or ""
    local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()

    if cmd == "" or cmd == "help" then
        Help()
    elseif cmd == "role" or cmd == "spec" then
        ns.RolePicker.Show()
    elseif cmd == "test" then
        ns.RunTest()
    elseif cmd == "check" or cmd == "debug" then
        local link = ExtractLink(rest)
        if not link then
            ns.Print("Shift-click an item into the command, e.g. /lh %s [Item]", cmd)
            return
        end
        ns.ItemReader.WhenLoaded(link, function()
            if cmd == "debug" then
                PrintDebug(link)
            else
                local res = ns.Judge.Item(link)
                ns.AddRollContext(res, link, nil)
                if ns.Judge.ShortText(res) then ns.PrintVerdict(res) else ns.Print("%s isn't gear.", link) end
                if ns.Judge.ShouldAlert(res, ns.db) then ns.Alert.Show(res, {}) end
            end
        end)
    elseif cmd == "announce" then
        ns.db.announceNeed = not ns.db.announceNeed
        ns.Print("Posting Need rolls to group chat is now %s.", ns.db.announceNeed and "|cff1eff00ON|r" or "|cffff5555OFF|r")
        if ns.db.announceNeed then
            print("  Only for drops Loot Herald calls an Upgrade or About Equal, one line per Need roll.")
            print("  Try /lh test and click Need to see an example.")
        end
    elseif cmd == "post" then
        ns.Announce.PostManually()
    elseif cmd == "selftest" then
        ns.SelfTest.Run()
    elseif cmd == "hitcap" then
        local melee, spell, bonus = rest:match("^(%S*)%s*(%S*)%s*(%S*)")
        if tonumber(melee) then ns.db.hitCapMelee = tonumber(melee) end
        if tonumber(spell) then ns.db.hitCapSpell = tonumber(spell) end
        if tonumber(bonus) then ns.db.hitBonus = tonumber(bonus) end
        ns.Print("Hit cap %s: melee/ranged %.1f%%, spell %.1f%%, bonus from talents %.1f%%. Your gear + bonus: %.1f%%.",
            ns.db.hitCap and "ON" or "OFF", ns.db.hitCapMelee, ns.db.hitCapSpell, ns.db.hitBonus, ns.Compare.EquippedHit())
        print("  Usage: /lh hitcap <melee> <spell> [talent bonus]   e.g. /lh hitcap 9 16 3")
    elseif cmd == "weights" then
        PrintWeights()
    elseif cmd == "weight" then
        SetWeight(rest)
    elseif cmd == "history" then
        ns.Judge.PrintHistory(tonumber(rest) or 10)
    elseif cmd == "on" then
        ns.db.enabled = true
        ns.Print("Enabled.")
    elseif cmd == "off" then
        ns.db.enabled = false
        ns.Alert.HideAll()
        ns.Print("Disabled. /lh on to turn back on.")
    elseif cmd == "options" or cmd == "config" or cmd == "settings" then
        ns.Options.Open()
    elseif cmd == "resetpos" then
        ns.Alert.ResetPosition()
        ns.Print("Alert position reset.")
    elseif cmd == "debugmode" then
        ns.debugMode = not ns.debugMode
        ns.Print("Debug messages %s.", ns.debugMode and "on" or "off")
    else
        Help()
    end
end
