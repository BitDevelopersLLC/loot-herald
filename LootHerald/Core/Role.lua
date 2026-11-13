-- Loot Herald: which class/spec/role profile is the player using?
--
-- Detection is only a suggestion. The player confirms it in the role picker
-- (shown when entering a dungeon) and can change it at any time with /lh role.
local _, ns = ...

local Role = {}
ns.Role = Role

local ROLE_FROM_GAME = { TANK = "TANK", HEALER = "HEALER", DAMAGER = "DPS", DPS = "DPS" }

function Role.PlayerClass()
    local localized, classFile = UnitClass("player")
    return classFile, localized
end

function Role.GetClassProfiles(classFile)
    return ns.Profiles[classFile] or ns.GenericProfiles
end

function Role.FindProfile(classFile, key)
    if not key then return nil end
    for _, p in ipairs(Role.GetClassProfiles(classFile)) do
        if p.key == key then return p end
    end
    return nil
end

-- PURE: pick the most likely profile from talent tree, spec name and group role.
function Role.ChooseProfile(profiles, tree, specName, assignedRole)
    local best, bestScore
    for i, p in ipairs(profiles) do
        local s = 0
        if tree and p.tree == tree then s = s + 4 end
        if specName then
            if p.name == specName then s = s + 4 end
            for _, alias in ipairs(p.aliases or {}) do
                if alias == specName then s = s + 4 end
            end
        end
        if assignedRole and p.role == assignedRole then s = s + 3 end
        if p.default then s = s + 1 end
        s = s - i * 0.01 -- stable tie-break: earlier profile wins
        if not bestScore or s > bestScore then best, bestScore = p, s end
    end
    return best
end

-- PURE: GetTalentTabInfo changed shape across game versions.
--   Vanilla style: name, icon, pointsSpent, ...
--   Later style:   id, name, description, icon, pointsSpent, ...
function Role.PointsFromTabInfo(...)
    local first = ...
    if type(first) == "string" then return (select(3, ...)) end
    if type(first) == "number" then return (select(5, ...)) end
    return nil
end

-- GAME: returns talentTree (1-3 or nil), specName (or nil), role (TANK/HEALER/DPS or nil)
function Role.DetectSignals()
    local tree, specName, specRole

    if GetSpecialization and GetSpecializationInfo then
        local ok, idx = pcall(GetSpecialization)
        if ok and type(idx) == "number" and idx > 0 then
            local ok2, _, name, _, _, role = pcall(GetSpecializationInfo, idx)
            if ok2 and type(name) == "string" then
                specName, specRole = name, ROLE_FROM_GAME[role]
            end
        end
    end

    if GetNumTalentTabs and GetTalentTabInfo then
        local okN, n = pcall(GetNumTalentTabs)
        if okN and type(n) == "number" then
            local bestPts = 0
            for i = 1, n do
                local ok, a, b, c, d, e = pcall(GetTalentTabInfo, i)
                if ok then
                    local pts = Role.PointsFromTabInfo(a, b, c, d, e)
                    if type(pts) == "number" and pts > bestPts then bestPts, tree = pts, i end
                end
            end
        end
    end

    local assigned
    if UnitGroupRolesAssigned then
        local ok, r = pcall(UnitGroupRolesAssigned, "player")
        if ok then assigned = ROLE_FROM_GAME[r] end
    end
    return tree, specName, assigned or specRole
end

function Role.Suggest()
    local classFile = Role.PlayerClass()
    local tree, specName, role = Role.DetectSignals()
    return Role.ChooseProfile(Role.GetClassProfiles(classFile), tree, specName, role), tree, specName, role
end

-- Active profile: the player's choice, else the suggestion. Second return is
-- true when it was auto-detected (not confirmed by the player).
function Role.GetActive()
    local classFile = Role.PlayerClass()
    local chosen = ns.char and Role.FindProfile(classFile, ns.char.profileKey)
    if chosen then return chosen, false end
    return (Role.Suggest()), true
end

function Role.GetWeights(profile)
    local overrides = ns.db and ns.db.customWeights and ns.db.customWeights[profile.key]
    return ns.Scoring.MergeWeights(profile.weights, overrides)
end

function Role.Label(profile)
    if not profile then return "?" end
    local _, localizedClass = Role.PlayerClass()
    if profile.key:find("^GENERIC_") then return profile.name end
    return string.format("%s %s", profile.name, localizedClass or "")
end

function Role.LabelWithRole(profile)
    return string.format("%s (%s)", Role.Label(profile), ns.ROLE_LABELS[profile.role] or profile.role)
end

function Role.SetProfile(key, dontAsk)
    local tree, specName, role = Role.DetectSignals()
    ns.char.profileKey = key
    ns.char.dontAsk = dontAsk and true or false
    ns.char.lastTree, ns.char.lastSpecName, ns.char.lastAssigned = tree, specName, role
    local p = Role.FindProfile(Role.PlayerClass(), key)
    if p then ns.Print("Judging loot for |cff%s%s|r.", ns.GOLD, Role.LabelWithRole(p)) end
end

-- Have talents or the group role changed since the player picked?
function Role.SignalsChanged()
    local tree, specName, role = Role.DetectSignals()
    local c = ns.char
    return (tree ~= c.lastTree) or (specName ~= c.lastSpecName) or (role ~= nil and role ~= c.lastAssigned)
end

function Role.OnEnterDungeon(instanceName)
    local c = ns.char
    local mustAsk = (not c.profileKey) or (not c.dontAsk) or Role.SignalsChanged()
    if ns.db.askRoleOnEnter and mustAsk then
        C_Timer.After(2, function() ns.RolePicker.Show(instanceName) end)
    else
        local p, auto = Role.GetActive()
        ns.Print("Entering %s - judging loot for |cff%s%s|r%s. Type /lh role to change.",
            instanceName or "dungeon", ns.GOLD, Role.LabelWithRole(p), auto and " (auto)" or "")
    end
end

-- Talents or group role changed while inside a dungeon.
local pending = false
function Role.OnSignalsMaybeChanged()
    if pending or not ns.char or not ns.char.profileKey then return end
    pending = true
    C_Timer.After(1.5, function()
        pending = false
        if not ns.InJudgedInstance() or not Role.SignalsChanged() then return end
        local suggested = Role.Suggest()
        if suggested and suggested.key ~= ns.char.profileKey then
            ns.Print("Your talents or group role changed. Suggested: |cff%s%s|r.", ns.GOLD, Role.LabelWithRole(suggested))
            if ns.db.askRoleOnEnter then ns.RolePicker.Show() end
        end
    end)
end
