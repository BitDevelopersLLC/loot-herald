-- Loot Herald: /lh selftest - a quick health check to run after every game
-- patch. It reports what a patch may have broken, in a form you can paste
-- straight into a GitHub issue:
--   * game functions the addon relies on that have gone missing
--   * item stat keys the game reports that we don't recognise
--   * "Equip:" tooltip lines that look like stats but weren't read
--     (usually means Blizzard changed the wording)
--   * stat weights last reviewed for an older game version
local _, ns = ...

local SelfTest = {}
ns.SelfTest = SelfTest

-- PURE: is version a ("1.61.0") newer than version b ("1.60.1")?
function SelfTest.IsNewer(a, b)
    local function parts(v)
        local t = {}
        for n in tostring(v or ""):gmatch("%d+") do t[#t + 1] = tonumber(n) end
        return t
    end
    local pa, pb = parts(a), parts(b)
    for i = 1, math.max(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then return x > y end
    end
    return false
end

-- Functions the addon needs. Each entry: label, check function.
local function Has(path)
    local cur = _G
    for part in path:gmatch("[^%.]+") do
        if type(cur) ~= "table" then return false end
        cur = cur[part]
    end
    return cur ~= nil
end

SelfTest.REQUIRED = {
    { "Item info", function() return Has("C_Item.GetItemInfoInstant") or Has("GetItemInfoInstant") end },
    { "Item stats", function() return Has("C_Item.GetItemStats") or Has("GetItemStats") end },
    { "Tooltip data", function() return Has("C_TooltipInfo.GetHyperlink") or Has("GameTooltip") end },
    { "Loot roll link", function() return Has("GetLootRollItemLink") end },
    { "Loot roll info", function() return Has("GetLootRollItemInfo") end },
    { "Roll on loot", function() return Has("RollOnLoot") end },
    { "Confirm loot roll", function() return Has("ConfirmLootRoll") end },
    { "Equipped items", function() return Has("GetInventoryItemLink") end },
    { "Talents or specs", function() return Has("GetTalentTabInfo") or Has("GetSpecialization") end },
    { "Group roles", function() return Has("UnitGroupRolesAssigned") end },
    { "Tooltip hook", function() return Has("TooltipDataProcessor.AddTooltipPostCall") or Has("GameTooltip.HookScript") end },
    { "Settings panel", function() return Has("Settings.RegisterCanvasLayoutCategory") or Has("InterfaceOptions_AddCategory") end },
    { "Item loading", function() return Has("Item.CreateFromItemLink") end },
    { "Chat lockdown check", function() return Has("C_ChatInfo.InChatMessagingLockdown") end, optional = true },
}

function SelfTest.Run()
    local version, build, _, iface = "?", "?", nil, "?"
    if GetBuildInfo then version, build, _, iface = GetBuildInfo() end
    local problems = 0
    ns.Print("Self-test - Loot Herald %s, game %s.%s (interface %s), data reviewed for %s",
        ns.VERSION, tostring(version), tostring(build), tostring(iface), ns.DATA_REVIEWED_FOR)

    -- 1. Game functions
    local missing = {}
    for _, req in ipairs(SelfTest.REQUIRED) do
        local ok, present = pcall(req[2])
        if not (ok and present) then
            missing[#missing + 1] = req[1] .. (req.optional and " (optional)" or "")
            if not req.optional then problems = problems + 1 end
        end
    end
    print(#missing == 0 and "  Game functions: OK" or ("  |cffff5555Missing game functions:|r " .. table.concat(missing, ", ")))

    -- 2. Role detection
    local tree, specName, role = ns.Role.DetectSignals()
    local suggested = ns.Role.Suggest()
    print(string.format("  Role signals: talent tree %s, spec %s, group role %s -> %s",
        tostring(tree), tostring(specName), tostring(role), suggested and ns.Role.LabelWithRole(suggested) or "?"))

    -- 3. Read every equipped item
    ns.ItemReader.ClearCache()
    local items, apiCount, tipCount = 0, 0, 0
    local unknownKeys, missed, seen = {}, {}, {}
    for slot = 1, 18 do
        local link = GetInventoryItemLink("player", slot)
        if link then
            items = items + 1
            local _, loc = ns.Compare.ItemInstant(link)
            local info = ns.ItemReader.GetStats(link, loc)
            for _, src in pairs(info.sources) do
                if src == "tooltip" then tipCount = tipCount + 1 else apiCount = apiCount + 1 end
            end
            for _, key in ipairs(info.unknown or {}) do unknownKeys[key] = (unknownKeys[key] or 0) + 1 end
            for _, line in ipairs(info.specials or {}) do
                if ns.ItemReader.LooksLikeMissedStat(line) and not seen[line] then
                    seen[line] = true
                    missed[#missed + 1] = line
                end
            end
        end
    end
    print(string.format("  Gear scan: %d items, %d stats from the game API, %d from tooltip text", items, apiCount, tipCount))
    if not ns.ItemReader.CanParseTooltips() then
        print("  Note: tooltip reading is English-only, so this client uses game API stats only.")
    end

    local keys = {}
    for k, n in pairs(unknownKeys) do keys[#keys + 1] = string.format("%s (x%d)", k, n) end
    table.sort(keys)
    if #keys > 0 then
        problems = problems + 1
        print("  |cffff9933Unknown stat keys from the game:|r " .. table.concat(keys, ", "))
    end
    if #missed > 0 then
        problems = problems + 1
        print("  |cffff9933Equip lines that look like stats but weren't read (new wording?):|r")
        for _, line in ipairs(missed) do print("     " .. line) end
    end

    -- 4. Data freshness
    if SelfTest.IsNewer(version, ns.DATA_REVIEWED_FOR) then
        problems = problems + 1
        print(string.format("  |cffff9933Stat weights were last reviewed for %s; the game is %s.|r Check for a Loot Herald update.",
            ns.DATA_REVIEWED_FOR, tostring(version)))
    end

    if problems == 0 then
        ns.Print("|cff1eff00All checks passed.|r")
    else
        ns.Print("|cffff9933%d thing(s) to report.|r Please paste this into an issue at github.com/BitDevelopersLLC/loot-herald", problems)
    end
    return problems
end
