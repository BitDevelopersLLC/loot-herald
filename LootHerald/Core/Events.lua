-- Loot Herald: game events - load settings, notice dungeons, judge loot rolls.
local ADDON_NAME, ns = ...

local frame = CreateFrame("Frame")
ns.eventFrame = frame
local handlers = {}

-- Registering an event the client doesn't have is an error, so be careful.
local function SafeRegister(event)
    local ok = pcall(frame.RegisterEvent, frame, event)
    if ok then return true end
    return false
end

function ns.InJudgedInstance()
    local inInstance, instanceType = IsInInstance()
    if not inInstance then return false end
    return instanceType == "party" or (instanceType == "raid" and ns.db.includeRaids)
end

function ns.ShouldJudgeRolls()
    if not ns.db or not ns.db.enabled then return false end
    if not ns.db.onlyInInstances then return true end
    return ns.InJudgedInstance()
end

function ns.PrintVerdict(res)
    local text = ns.Judge.ShortText(res)
    if not text then return end
    ns.Print("%s %s", res.link or "?", text)
    local why = ns.db.showWhy and ns.Judge.WhyText(res, 5)
    if why then print("   " .. why) end
    local group = ns.Judge.GroupText(res)
    if group then print("   " .. group) end
end

-- Extra checks that only matter for a real drop: group check and bind warning.
function ns.AddRollContext(res, link, roll)
    if res.verdict == "NOT_GEAR" then return end
    local ok, wants = pcall(ns.Judge.GroupWants, link)
    if ok then res.groupWants = wants else ns.Debug("group check: %s", tostring(wants)) end
    if ns.db.bindWarning then
        res.bindNote = ns.Judge.BindNote(ns.Judge.BindType(link), roll and roll.bop)
    end
end

function ns.JudgeRoll(link, roll)
    local res = ns.Judge.Item(link)
    if (res.display == "UPGRADE" or res.display == "EQUAL") and roll.canNeed == false then
        res.cantNeed = true
    end
    ns.AddRollContext(res, link, roll)
    ns.Announce.Remember(roll.rollID, res, roll)
    ns.Judge.Record(res)
    if ns.db.chatSummary then ns.PrintVerdict(res) end
    if ns.Judge.ShouldAlert(res, ns.db) then ns.Alert.Show(res, roll) end
end

function ns.HandleRoll(rollID, rollTime, attempt)
    if not ns.ShouldJudgeRolls() then return end
    local link = GetLootRollItemLink(rollID)
    if not link then
        attempt = (attempt or 0) + 1
        if attempt <= 10 then
            C_Timer.After(0.3, function() ns.HandleRoll(rollID, rollTime, attempt) end)
        end
        return
    end
    local _, _, _, quality, bindOnPickUp, canNeed, canGreed = GetLootRollItemInfo(rollID)
    local roll = { rollID = rollID, rollTime = rollTime, canNeed = canNeed, canGreed = canGreed,
                   quality = quality, bop = bindOnPickUp }
    ns.ItemReader.WhenLoaded(link, function()
        local ok, err = pcall(ns.JudgeRoll, link, roll)
        if not ok then ns.Print("|cffff4444Error judging %s:|r %s", link, tostring(err)) end
    end)
end

-- ---------------------------------------------------------------------------
local lastInstanceKey

local function CheckInstance()
    if not ns.db or not ns.db.enabled then return end
    if ns.InJudgedInstance() then
        local name, _, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
        local key = tostring(instanceID) .. ":" .. tostring(difficultyID)
        if key ~= lastInstanceKey then
            lastInstanceKey = key
            ns.Role.OnEnterDungeon(name)
        end
    else
        lastInstanceKey = nil
        if ns.RolePicker then ns.RolePicker.Hide() end
    end
end

function handlers.ADDON_LOADED(name)
    if name ~= ADDON_NAME then return end
    LootHeraldDB = LootHeraldDB or {}
    LootHeraldCharDB = LootHeraldCharDB or {}
    ns.db = ns.ApplyDefaults(LootHeraldDB, ns.defaults)
    ns.char = ns.ApplyDefaults(LootHeraldCharDB, ns.charDefaults)
    ns.Options.Create()
    ns.Tooltip.Init()
    ns.Announce.Init()
    frame:UnregisterEvent("ADDON_LOADED")
end

function handlers.PLAYER_LOGIN()
    if not ns.db.welcomed then
        ns.db.welcomed = true
        ns.Print("v%s loaded. You'll be asked for your role when you enter a dungeon. Type |cffffd100/lh|r for help.", ns.VERSION)
    end
end

function handlers.PLAYER_ENTERING_WORLD()
    C_Timer.After(1, CheckInstance)
end
handlers.ZONE_CHANGED_NEW_AREA = handlers.PLAYER_ENTERING_WORLD

function handlers.START_LOOT_ROLL(rollID, rollTime)
    ns.HandleRoll(rollID, rollTime)
end

function handlers.CANCEL_LOOT_ROLL(rollID)
    ns.Alert.HideRoll(rollID)
end

local function SignalsChanged()
    ns.Role.OnSignalsMaybeChanged()
end
handlers.CHARACTER_POINTS_CHANGED = SignalsChanged
handlers.PLAYER_TALENT_UPDATE = SignalsChanged
handlers.ACTIVE_TALENT_GROUP_CHANGED = SignalsChanged
handlers.PLAYER_SPECIALIZATION_CHANGED = SignalsChanged
handlers.TRAIT_CONFIG_UPDATED = SignalsChanged
handlers.PLAYER_ROLES_ASSIGNED = SignalsChanged
handlers.ROLE_CHANGED_INFORM = SignalsChanged

for event in pairs(handlers) do SafeRegister(event) end

frame:SetScript("OnEvent", function(_, event, ...)
    local h = handlers[event]
    if h then h(...) end
end)
