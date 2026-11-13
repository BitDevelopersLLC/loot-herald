-- Loot Herald: the verdict for one item, plus chat/tooltip wording and history.
local _, ns = ...

local Judge = {}
ns.Judge = Judge

-- Evaluate an item for the active profile, then check the class's other
-- profiles (off-spec) when it isn't an upgrade for the main one.
function Judge.Item(link)
    local profile, auto = ns.Role.GetActive()
    local res = ns.Compare.Evaluate(link, profile, ns.Role.GetWeights(profile))
    res.auto = auto

    local v = res.verdict
    if v ~= "UPGRADE" and v ~= "EQUAL" and v ~= "NOT_GEAR" then
        local classFile = ns.Role.PlayerClass()
        for _, p in ipairs(ns.Role.GetClassProfiles(classFile)) do
            if p.key ~= profile.key then
                local r2 = ns.Compare.Evaluate(link, p, ns.Role.GetWeights(p))
                if r2.verdict == "UPGRADE" then
                    res.offspec = res.offspec or {}
                    res.offspec[#res.offspec + 1] = { profile = p, pct = r2.pct, empty = r2.emptySlot }
                end
            end
        end
    end

    if (v == "UPGRADE" or v == "EQUAL") then
        res.display = v
    elseif res.offspec then
        res.display = "OFFSPEC"
    else
        res.display = v
    end
    return res
end

-- Should a loot roll for this result pop up an alert?
function Judge.ShouldAlert(res, db)
    local d = res.display
    if d == "UPGRADE" then return true end
    if d == "EQUAL" then return db.alertOnEqual end
    if d == "OFFSPEC" then return db.alertOffSpec end
    if d == "REVIEW" then return db.alertOnUnscored end
    return false
end

local function PctText(res)
    if res.emptySlot then return "fills an empty slot" end
    return ns.FormatPct(res.pct)
end

-- Headline + advice used by the alert frame.
function Judge.Headline(res)
    local d = res.display
    if d == "UPGRADE" then return "Upgrade!", "Consider rolling NEED" end
    if d == "EQUAL" then return "About Equal", "Need if you want it - it's a sidegrade" end
    if d == "OFFSPEC" then
        if res.groupWants then return "Off-Spec Upgrade", "Roll GREED - someone in your group can use it for their role" end
        return "Off-Spec Upgrade", "Roll GREED unless your group is fine with it"
    end
    if d == "REVIEW" then return "Take a Look", "This item has an effect that can't be scored" end
    return "Not an Upgrade", "Greed or Pass"
end

-- One line for chat and item tooltips. Returns nil when there's nothing to say.
function Judge.ShortText(res)
    local v = res.verdict
    if v == "NOT_GEAR" or res.isEquipped then return nil end
    local who = ns.Role.Label(res.profile)
    local c = ns.VERDICT_COLORS
    local text
    if v == "UPGRADE" then
        text = ns.Color(c.UPGRADE, "Upgrade " .. PctText(res)) .. " for " .. who
    elseif v == "EQUAL" then
        text = ns.Color(c.EQUAL, "About equal (" .. ns.FormatPct(res.pct) .. ")") .. " for " .. who
    elseif v == "DOWNGRADE" then
        text = ns.Color(c.DOWNGRADE, "Not an upgrade (" .. ns.FormatPct(res.pct) .. ") for " .. who)
    elseif v == "REVIEW" then
        text = ns.Color(c.REVIEW, "Has an unscored effect - check it") .. " (" .. who .. ")"
    elseif v == "NOT_USABLE" then
        text = ns.Color(c.NOT_USABLE, res.reason or "Not for you")
    else
        text = ns.Color(c.NONE, (res.reason or "No useful stats") .. " for " .. who)
    end
    if res.offspec then
        local parts = {}
        for _, o in ipairs(res.offspec) do
            parts[#parts + 1] = string.format("%s %s", o.profile.name, o.empty and "(empty slot)" or ns.FormatPct(o.pct))
        end
        text = text .. "  " .. ns.Color(c.OFFSPEC, "Off-spec: " .. table.concat(parts, ", "))
    end
    return text
end

-- ---------------------------------------------------------------------------
-- Feature: the plain-English "why"  (+22 Healing, +8 Int, -5 Spirit)
-- ---------------------------------------------------------------------------
local function FormatNumber(v)
    if math.abs(v - math.floor(v + 0.5)) < 0.05 then return string.format("%d", math.floor(v + 0.5)) end
    return string.format("%.1f", v)
end

local function WhyParts(res, maxItems, colored)
    if not res.diff or #res.diff == 0 then return nil end
    local parts = {}
    for i = 1, math.min(maxItems or 4, #res.diff) do
        local row = res.diff[i]
        local sign = row.delta >= 0 and "+" or "-"
        local amount = FormatNumber(math.abs(row.delta)) .. (ns.PERCENT_STAT[row.stat] and "%" or "")
        local text = sign .. amount .. " " .. (ns.STAT_SHORT[row.stat] or row.stat)
        parts[#parts + 1] = colored and ns.Color(row.points >= 0 and "1eff00" or "ff5555", text) or text
    end
    return parts
end

function Judge.WhyText(res, maxItems)
    local parts = WhyParts(res, maxItems, true)
    if not parts then return nil end
    local out = table.concat(parts, ", ")
    if res.hitCapped then out = out .. ns.Color("9d9d9d", " (Hit over the cap counts as 0)") end
    return out
end

-- Same, with no colour codes (safe to send in chat).
function Judge.WhyPlain(res, maxItems)
    local parts = WhyParts(res, maxItems, false)
    return parts and table.concat(parts, ", ") or nil
end

-- ---------------------------------------------------------------------------
-- Feature: announce Need rolls in group chat (opt-in)
-- ---------------------------------------------------------------------------
Judge.CHAT_LIMIT = 255

-- PURE: the group-chat line for a Need roll, or nil when Loot Herald didn't
-- recommend Need (we never post "this wasn't an upgrade" about the player).
function Judge.AnnounceText(res)
    if not res or not res.link then return nil end
    local d = res.display
    if d ~= "UPGRADE" and d ~= "EQUAL" then return nil end
    local verdict
    if d == "UPGRADE" then
        verdict = res.emptySlot and "fills an empty slot" or (ns.FormatPct(res.pct) .. " upgrade")
    else
        verdict = "about equal (" .. ns.FormatPct(res.pct) .. ")"
    end
    local head = string.format("[Loot Herald] Need on %s: %s for my %s", res.link, verdict, ns.Role.Label(res.profile))
    for n = 4, 1, -1 do
        local why = Judge.WhyPlain(res, n)
        if why then
            local msg = head .. " (" .. why .. ")"
            if #msg <= Judge.CHAT_LIMIT then return msg end
        end
    end
    return head
end

-- ---------------------------------------------------------------------------
-- Feature: group check - who else in the party could use this?
-- Uses only what the game shows about party members (class, level, assigned
-- role). No addon messages, which WoW Forever blocks inside instances.
-- ---------------------------------------------------------------------------
Judge.SHARE_THRESHOLD = 0.5

-- PURE: does a player of this class/level/role want an item with these stats?
-- Returns the profile that wants it most, or nil.
function Judge.MemberWants(stats, equipLoc, classID, subclassID, classFile, level, role)
    local ok = ns.Compare.CheckUsable(classFile, level, equipLoc, classID, subclassID, true)
    if not ok then return nil end
    local bestProfile, bestShare
    for _, p in ipairs(ns.Role.GetClassProfiles(classFile)) do
        if not role or p.role == role then
            local share = ns.Scoring.Share(stats, p.weights, ns.MAX_WEIGHTS)
            if share >= Judge.SHARE_THRESHOLD and (not bestShare or share > bestShare) then
                bestProfile, bestShare = p, share
            end
        end
    end
    return bestProfile, bestShare
end

local ROLE_FROM_GAME = { TANK = "TANK", HEALER = "HEALER", DAMAGER = "DPS" }

local function SafeUnit(fn, unit)
    local ok, a, b = pcall(fn, unit)
    if not ok then return nil end
    if issecretvalue and (issecretvalue(a) or issecretvalue(b)) then return nil end
    return a, b
end

-- GAME: list of { name, classFile, className, profile } for party/raid members.
function Judge.GroupWants(link)
    if not (ns.db and ns.db.groupCheck) or not IsInGroup or not IsInGroup() then return nil end
    local _, equipLoc, _, classID, subclassID = ns.Compare.ItemInstant(link)
    if not equipLoc or equipLoc == "" then return nil end
    local stats = ns.ItemReader.GetStats(link, equipLoc).stats
    local units = {}
    if IsInRaid and IsInRaid() then
        for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do units[#units + 1] = "raid" .. i end
    else
        for i = 1, 4 do units[#units + 1] = "party" .. i end
    end
    local out = {}
    for _, unit in ipairs(units) do
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local className, classFile = SafeUnit(UnitClass, unit)
            local name = SafeUnit(UnitName, unit)
            local level = SafeUnit(UnitLevel, unit)
            local role = UnitGroupRolesAssigned and ROLE_FROM_GAME[(SafeUnit(UnitGroupRolesAssigned, unit))]
            if classFile and name then
                local p = Judge.MemberWants(stats, equipLoc, classID, subclassID, classFile, level or 60, role)
                if p then
                    out[#out + 1] = { name = name, classFile = classFile, className = className, profile = p }
                end
            end
        end
    end
    return (#out > 0) and out or nil
end

local function ClassColored(entry)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[entry.classFile]
    if c and c.colorStr then return "|c" .. c.colorStr .. entry.name .. "|r" end
    return entry.name
end

function Judge.GroupText(res)
    if not res.groupWants then return nil end
    local parts = {}
    for _, e in ipairs(res.groupWants) do
        parts[#parts + 1] = string.format("%s (%s %s)", ClassColored(e), e.profile.name, e.className or "")
    end
    return "Also good for: " .. table.concat(parts, ", ")
end

-- ---------------------------------------------------------------------------
-- Feature: bind warning
-- ---------------------------------------------------------------------------
Judge.BIND_PICKUP, Judge.BIND_EQUIP = 1, 2

-- PURE. Most dungeon drops bind on pickup, so only Bind on Equip gets a note.
function Judge.BindNote(bindType, rollSaysBoP)
    if not rollSaysBoP and bindType == Judge.BIND_EQUIP then
        return "Bind on Equip: it can be traded or sold. Need it only if you will wear it"
    end
    return nil
end

-- GAME
function Judge.BindType(link)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not getInfo then return nil end
    local ok, _, _, _, _, _, _, _, _, _, _, _, _, _, bindType = pcall(getInfo, link)
    if ok then return bindType end
    return nil
end

-- ---------------------------------------------------------------------------
-- History (last 50 judged drops, per character)
-- ---------------------------------------------------------------------------
local MAX_HISTORY = 50

function Judge.Record(res)
    if not ns.char then return end
    local h = ns.char.history
    table.insert(h, 1, {
        t = time and time() or 0,
        link = res.link,
        verdict = res.display,
        pct = res.pct,
        profile = res.profile and res.profile.key,
        zone = GetInstanceInfo and (GetInstanceInfo()) or nil,
    })
    while #h > MAX_HISTORY do table.remove(h) end
end

function Judge.PrintHistory(count)
    local h = ns.char and ns.char.history or {}
    if #h == 0 then ns.Print("No drops judged yet.") return end
    ns.Print("Last %d drops:", math.min(count or 10, #h))
    for i = 1, math.min(count or 10, #h) do
        local e = h[i]
        local when = date and date("%m/%d %H:%M", e.t) or ""
        local color = ns.VERDICT_COLORS[e.verdict] or "ffffff"
        print(string.format("  %s  %s  %s %s  %s", when, e.link or "?",
            ns.Color(color, e.verdict or "?"), e.pct and ns.FormatPct(e.pct) or "", e.zone or ""))
    end
end
