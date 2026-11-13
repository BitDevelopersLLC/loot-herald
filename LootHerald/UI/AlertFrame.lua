-- Loot Herald: the on-screen loot alert.
-- One alert per roll; several stack under a movable anchor. Buttons call the
-- normal roll function - the addon never rolls for you on its own.
local _, ns = ...

local Alert = {}
ns.Alert = Alert

local WIDTH, HEIGHT = 410, 150
local MAX_SHOWN = 5
local pool, shown = {}, {}
local anchor

local function SavePosition()
    local point, _, relPoint, x, y = anchor:GetPoint(1)
    ns.db.alertPos = { point = point, relPoint = relPoint, x = x, y = y }
end

local function GetAnchor()
    if anchor then return anchor end
    anchor = CreateFrame("Frame", "LootHeraldAlertAnchor", UIParent)
    anchor:SetSize(WIDTH, 10)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    Alert.RestorePosition()
    return anchor
end

function Alert.RestorePosition()
    if not anchor then return GetAnchor() end
    anchor:ClearAllPoints()
    local p = ns.db and ns.db.alertPos
    if p and p.point then
        anchor:SetPoint(p.point, UIParent, p.relPoint or p.point, p.x or 0, p.y or 0)
    else
        anchor:SetPoint("TOP", UIParent, "TOP", 0, -160)
    end
    anchor:SetScale((ns.db and ns.db.alertScale) or 1)
end

function Alert.ResetPosition()
    ns.db.alertPos = nil
    Alert.RestorePosition()
end

local function Reflow()
    local prev
    for _, f in ipairs(shown) do
        f:ClearAllPoints()
        if prev then
            f:SetPoint("TOP", prev, "BOTTOM", 0, -6)
        else
            f:SetPoint("TOP", anchor, "TOP", 0, 0)
        end
        prev = f
    end
end

function Alert.Release(f)
    f:Hide()
    if f.pulse then f.pulse:Stop() end
    f.rollID, f.link, f.endTime = nil, nil, nil
    for i, g in ipairs(shown) do
        if g == f then table.remove(shown, i) break end
    end
    pool[#pool + 1] = f
    Reflow()
end

function Alert.HideRoll(rollID)
    for i = #shown, 1, -1 do
        if shown[i].rollID == rollID then Alert.Release(shown[i]) end
    end
end

function Alert.HideAll()
    for i = #shown, 1, -1 do Alert.Release(shown[i]) end
end

local function DoRoll(f, rollType, label)
    if f.test or not f.rollID or f.rollID <= 0 then
        ns.Print("(test) You would roll %s on %s.", label, f.link or "this item")
        if rollType == 1 and ns.db.announceNeed and f.res then ns.Announce.Preview(f.res) end
    elseif RollOnLoot then
        RollOnLoot(f.rollID, rollType)
    end
    Alert.Release(f)
end

local function MakeButton(parent, text)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(72, 22)
    b:SetText(text)
    return b
end

local function CreateAlert()
    local f = CreateFrame("Frame", nil, GetAnchor(), "BackdropTemplate")
    f:SetSize(WIDTH, HEIGHT)
    f:SetFrameStrata("HIGH")
    ns.Theme.ApplyBackdrop(f)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() anchor:StartMoving() end)
    f:SetScript("OnDragStop", function() anchor:StopMovingOrSizing() SavePosition() end)

    -- Item icon (hover for tooltip, shift-click to link in chat)
    local ib = CreateFrame("Button", nil, f)
    ib:SetSize(46, 46)
    ib:SetPoint("TOPLEFT", 20, -20)
    f.icon = ib:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.iconBorder = ib:CreateTexture(nil, "OVERLAY")
    f.iconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
    f.iconBorder:SetAllPoints()
    f.glow = ib:CreateTexture(nil, "OVERLAY", nil, 1)
    f.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    f.glow:SetBlendMode("ADD")
    f.glow:SetSize(96, 96)
    f.glow:SetPoint("CENTER")
    ib:SetScript("OnEnter", function(self)
        if f.link then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(f.link)
            GameTooltip:Show()
        end
    end)
    ib:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ib:SetScript("OnClick", function()
        if f.link and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
            ChatEdit_InsertLink(f.link)
        end
    end)
    f.iconButton = ib

    local textWidth = WIDTH - 110
    f.title = ns.Theme.TitleText(f, 21)
    f.title:SetPoint("TOPLEFT", ib, "TOPRIGHT", 12, 2)

    f.advice = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.advice:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -2)
    f.advice:SetWidth(textWidth)
    f.advice:SetJustifyH("LEFT")

    f.itemName = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.itemName:SetPoint("TOPLEFT", f.advice, "BOTTOMLEFT", 0, -5)
    f.itemName:SetWidth(textWidth)
    f.itemName:SetJustifyH("LEFT")
    f.itemName:SetWordWrap(false)

    f.detail = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.detail:SetPoint("TOPLEFT", f.itemName, "BOTTOMLEFT", 0, -3)
    f.detail:SetWidth(textWidth)
    f.detail:SetJustifyH("LEFT")

    f.why = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.why:SetPoint("TOPLEFT", f.detail, "BOTTOMLEFT", 0, -3)
    f.why:SetWidth(textWidth)
    f.why:SetJustifyH("LEFT")

    f.group = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.group:SetPoint("TOPLEFT", f.why, "BOTTOMLEFT", 0, -3)
    f.group:SetWidth(textWidth)
    f.group:SetJustifyH("LEFT")

    f.note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.note:SetPoint("TOPLEFT", f.group, "BOTTOMLEFT", 0, -3)
    f.note:SetWidth(textWidth)
    f.note:SetJustifyH("LEFT")

    -- Roll buttons
    f.pass = MakeButton(f, PASS or "Pass")
    f.pass:SetPoint("BOTTOMRIGHT", -18, 22)
    f.greed = MakeButton(f, GREED or "Greed")
    f.greed:SetPoint("RIGHT", f.pass, "LEFT", -6, 0)
    f.need = MakeButton(f, NEED or "Need")
    f.need:SetPoint("RIGHT", f.greed, "LEFT", -6, 0)
    f.need:SetScript("OnClick", function() DoRoll(f, 1, "Need") end)
    f.greed:SetScript("OnClick", function() DoRoll(f, 2, "Greed") end)
    f.pass:SetScript("OnClick", function() DoRoll(f, 0, "Pass") end)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() Alert.Release(f) end)

    -- Roll timer
    f.timer = CreateFrame("StatusBar", nil, f)
    f.timer:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    f.timer:SetStatusBarColor(ns.Theme.GOLD[1], ns.Theme.GOLD[2], ns.Theme.GOLD[3], 0.9)
    f.timer:SetPoint("BOTTOMLEFT", 16, 13)
    f.timer:SetPoint("BOTTOMRIGHT", -16, 13)
    f.timer:SetHeight(5)

    -- Animations: fade in, pulsing glow for upgrades
    f.fadeIn = f:CreateAnimationGroup()
    local fade = f.fadeIn:CreateAnimation("Alpha")
    fade:SetFromAlpha(0)
    fade:SetToAlpha(1)
    fade:SetDuration(0.3)
    f.pulse = f.glow:CreateAnimationGroup()
    f.pulse:SetLooping("BOUNCE")
    local pulse = f.pulse:CreateAnimation("Alpha")
    pulse:SetFromAlpha(0.2)
    pulse:SetToAlpha(1)
    pulse:SetDuration(0.7)

    f:SetScript("OnUpdate", function(self, elapsed)
        self.acc = (self.acc or 0) + elapsed
        if self.acc < 0.1 then return end
        self.acc = 0
        if not self.endTime then return end
        local left = self.endTime - GetTime()
        if self.rollID and self.rollID > 0 and GetLootRollTimeLeft then
            local ok, ms = pcall(GetLootRollTimeLeft, self.rollID)
            if ok and type(ms) == "number" then left = ms / 1000 end
        end
        if left <= 0 then
            Alert.Release(self)
        else
            self.timer:SetValue(left)
        end
    end)
    return f
end

local function QualityColor(link)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local getColor = (C_Item and C_Item.GetItemQualityColor) or GetItemQualityColor
    if not (getInfo and getColor) then return 1, 1, 1 end
    local ok, _, _, quality = pcall(getInfo, link)
    if ok and quality then
        local r, g, b = getColor(quality)
        if r then return r, g, b end
    end
    return 1, 1, 1
end

local function BuildDetail(res)
    local who = ns.Role.Label(res.profile)
    local d = res.display
    if d == "UPGRADE" or d == "EQUAL" then
        local amount = res.emptySlot and ("Fills your empty " .. (res.slotName or "slot") .. " slot")
            or (ns.FormatPct(res.pct) .. " for " .. who)
        if not res.emptySlot and res.replaced and res.replaced[1] then
            amount = amount .. " - replaces " .. res.replaced[1]
        end
        return amount
    elseif d == "OFFSPEC" then
        local parts = {}
        for _, o in ipairs(res.offspec or {}) do
            parts[#parts + 1] = o.profile.name .. " " .. (o.empty and "(empty slot)" or ns.FormatPct(o.pct))
        end
        return "Not an upgrade for " .. who .. ". Upgrade for: " .. table.concat(parts, ", ")
    elseif d == "REVIEW" then
        return res.reason or "Read the item's tooltip"
    end
    return res.reason or ""
end

local function BuildNote(res, roll)
    local notes = {}
    if roll.test then notes[#notes + 1] = "TEST alert - buttons won't roll" end
    if res.cantNeed then notes[#notes + 1] = "The game won't let you Need this item" end
    if res.bindNote then notes[#notes + 1] = res.bindNote end
    if res.auto then notes[#notes + 1] = "Role auto-detected - /lh role to confirm" end
    if res.note then notes[#notes + 1] = res.note end
    if res.display ~= "REVIEW" and res.specials and #res.specials > 0 then
        notes[#notes + 1] = "Has a special effect that isn't scored"
    end
    if res.replacedHasSpecial then notes[#notes + 1] = "Your current item has an effect that isn't scored" end
    return table.concat(notes, ". ")
end

-- res: result from ns.Judge.Item; roll: { rollID, rollTime (ms), canNeed, canGreed, test }
function Alert.Show(res, roll)
    roll = roll or {}
    GetAnchor()
    if roll.rollID then Alert.HideRoll(roll.rollID) end
    while #shown >= MAX_SHOWN do Alert.Release(shown[1]) end

    local f = table.remove(pool) or CreateAlert()
    f.rollID, f.link, f.test, f.res = roll.rollID, res.link, roll.test, res

    local title, advice = ns.Judge.Headline(res)
    local r, g, b = ns.Theme.VerdictRGB(res.display)
    f.title:SetText(title)
    f.title:SetTextColor(r, g, b)
    f.advice:SetText(advice)
    f.icon:SetTexture(res.icon or 134400) -- 134400 = question mark icon
    f.iconBorder:SetVertexColor(QualityColor(res.link))
    f.itemName:SetText(res.link or "")
    f.detail:SetText(BuildDetail(res))
    local why = ns.db.showWhy and ns.Judge.WhyText(res, 4) or nil
    f.why:SetText(why and ("Why: " .. why) or "")
    f.group:SetText(ns.Judge.GroupText(res) or "")
    f.note:SetText(BuildNote(res, roll))

    -- Grow to fit the text (an empty line still takes a little space).
    local textHeight = 0
    for _, fs in ipairs({ f.title, f.advice, f.itemName, f.detail, f.why, f.group, f.note }) do
        local t = fs:GetText()
        textHeight = textHeight + ((t and t ~= "") and fs:GetStringHeight() or 0) + 3
    end
    f:SetHeight(math.max(HEIGHT, textHeight + 24 + 52))

    local hasRoll = roll.rollID ~= nil
    f.need:SetShown(hasRoll)
    f.greed:SetShown(hasRoll)
    f.pass:SetShown(hasRoll)
    if hasRoll then
        f.need:SetEnabled(roll.canNeed ~= false)
        f.greed:SetEnabled(roll.canGreed ~= false)
    end

    local seconds = roll.rollTime and (roll.rollTime / 1000) or 20
    f.timer:SetMinMaxValues(0, seconds)
    f.timer:SetValue(seconds)
    f.timer:SetShown(roll.rollTime ~= nil)
    f.endTime = GetTime() + seconds

    if res.display == "UPGRADE" then
        f.glow:Show()
        f.glow:SetVertexColor(r, g, b)
        f.pulse:Play()
    else
        f.glow:Hide()
    end

    shown[#shown + 1] = f
    Reflow()
    f:SetAlpha(1)
    f:Show()
    f.fadeIn:Play()

    ns.Theme.PlaySound(res.display)
    if res.display == "UPGRADE" then
        ns.Theme.RaidWarning(string.format("%s is an upgrade - roll NEED!", res.link or "Item"), "UPGRADE")
    end
    return f
end
