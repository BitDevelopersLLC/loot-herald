-- Loot Herald: optional group-chat line when you roll Need, so the group can
-- see why. Example:
--   [Loot Herald] Need on [Robe of the Archmage]: +14% upgrade for my
--   Restoration Druid (+22 Healing, +8 Int, -5 Spirit)
--
-- Rules:
-- * Off by default (opt-in). One line per Need roll, and only for drops Loot
--   Herald judged an Upgrade or About Equal.
-- * Works whether you click Need on our alert or on Blizzard's roll frame.
-- * Respects Blizzard's chat lockdown (boss fights and similar). Locked
--   messages wait; if they still can't be sent, /lh post puts the text in your
--   chat box and you press Enter yourself.
local _, ns = ...

local Announce = {}
ns.Announce = Announce

local NEED = 1
local results = {}   -- rollID -> { t, res, bop, announced }
Announce.results = results
local lastBlocked    -- message we couldn't send automatically

-- ---------------------------------------------------------------------------
-- PURE helpers
-- ---------------------------------------------------------------------------

-- Turn a game string such as "You have selected Need for: %s" into a Lua pattern.
function Announce.PatternFromFormat(fmt)
    if type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("%%%%s", "(.+)")
    return "^" .. p
end

function Announce.ItemID(link)
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

-- PURE: which chat channel to use.
function Announce.PickChannel(inInstanceGroup, inRaid, inGroup)
    if inInstanceGroup then return "INSTANCE_CHAT" end
    if inRaid then return "RAID" end
    if inGroup then return "PARTY" end
    return nil
end

-- ---------------------------------------------------------------------------
-- GAME
-- ---------------------------------------------------------------------------
local function Now() return GetTime and GetTime() or 0 end

function Announce.Remember(rollID, res, roll)
    local now = Now()
    for id, e in pairs(results) do
        if now - e.t > 600 then results[id] = nil end
    end
    results[rollID] = { t = now, res = res, bop = roll and roll.bop }
end

function Announce.Channel()
    local instanceGroup = IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
    return Announce.PickChannel(instanceGroup, IsInRaid and IsInRaid(), IsInGroup and IsInGroup())
end

local function Locked()
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
        local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
        return ok and locked == true
    end
    return false
end

local SLASH_FOR = { INSTANCE_CHAT = "/i ", RAID = "/ra ", PARTY = "/p " }

local queue, busy = {}, false
local MAX_WAIT = 120 -- seconds to wait for a chat lockdown to lift

local function Blocked(msg, why)
    lastBlocked = msg
    ns.Print("Couldn't post your Need message (%s). Type |cffffd100/lh post|r to post it yourself.", why)
end

local function Pump()
    local item = queue[1]
    if not item then busy = false return end
    busy = true
    if Locked() then
        if Now() - item.t < MAX_WAIT then
            C_Timer.After(2, Pump)
            return
        end
        table.remove(queue, 1)
        Blocked(item.msg, "group chat was locked by the game")
    else
        table.remove(queue, 1)
        local channel = Announce.Channel()
        if channel then
            local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
            local ok, err = pcall(send, item.msg, channel)
            if not ok then Blocked(item.msg, tostring(err)) end
        end
    end
    if queue[1] then C_Timer.After(1.2, Pump) else busy = false end
end

function Announce.Send(msg)
    queue[#queue + 1] = { msg = msg, t = Now() }
    if not busy then Pump() end
end

-- Post the Need line for a roll (once).
function Announce.Need(rollID)
    local e = results[rollID]
    if not e or e.announced or not (ns.db and ns.db.announceNeed) then return end
    local msg = ns.Judge.AnnounceText(e.res)
    if not msg then return end
    e.announced = true
    Announce.Send(msg)
end

-- What would be posted (for /lh announce and test alerts).
function Announce.Preview(res)
    local msg = ns.Judge.AnnounceText(res)
    if not msg then
        ns.Print("Nothing would be posted: Loot Herald only announces Upgrades and About Equal items.")
        return
    end
    ns.Print("Would post to %s: %s", Announce.Channel() or "group chat (you're not in a group)", msg)
end

-- /lh post: put the last blocked message in the chat box. You press Enter.
function Announce.PostManually()
    if not lastBlocked then ns.Print("No message waiting to be posted.") return end
    local prefix = SLASH_FOR[Announce.Channel() or "PARTY"] or "/p "
    if ChatFrame_OpenChat then
        ChatFrame_OpenChat(prefix .. lastBlocked)
        lastBlocked = nil
    else
        ns.Print("Copy this into chat: %s", lastBlocked)
    end
end

local function OnRollOnLoot(rollID, rollType)
    if rollType ~= NEED then return end
    local e = results[rollID]
    if not e then return end
    -- Bind-on-pickup rolls ask for confirmation first. Wait for ConfirmLootRoll
    -- (or the "You have selected Need" chat line) so a cancelled roll isn't announced.
    if e.bop then return end
    Announce.Need(rollID)
end

local function OnConfirmLootRoll(rollID, rollType)
    if rollType == NEED then Announce.Need(rollID) end
end

local needPattern
local function OnLootChat(msg)
    if type(msg) ~= "string" or (issecretvalue and issecretvalue(msg)) then return end
    needPattern = needPattern or Announce.PatternFromFormat(LOOT_ROLL_NEED_SELF)
    if not needPattern or not msg:match(needPattern) then return end
    local id = Announce.ItemID(msg)
    if not id then return end
    for rollID, e in pairs(results) do
        if not e.announced and Announce.ItemID(e.res.link) == id then
            Announce.Need(rollID)
            return
        end
    end
end

function Announce.Init()
    if Announce.done then return end
    Announce.done = true
    if hooksecurefunc then
        if type(RollOnLoot) == "function" then
            hooksecurefunc("RollOnLoot", function(...) pcall(OnRollOnLoot, ...) end)
        end
        if type(ConfirmLootRoll) == "function" then
            hooksecurefunc("ConfirmLootRoll", function(...) pcall(OnConfirmLootRoll, ...) end)
        end
    end
    local f = CreateFrame("Frame")
    if pcall(f.RegisterEvent, f, "CHAT_MSG_LOOT") then
        f:SetScript("OnEvent", function(_, _, msg) pcall(OnLootChat, msg) end)
    end
end
