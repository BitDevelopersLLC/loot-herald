-- Loot Herald: "Choose Your Role" window, shown when entering a dungeon.
local _, ns = ...

local Picker = {}
ns.RolePicker = Picker

local frame
local buttons = {}
local ROW_HEIGHT = 34

local function Create()
    frame = CreateFrame("Frame", "LootHeraldRolePicker", UIParent, "BackdropTemplate")
    frame:SetSize(360, 200)
    frame:SetPoint("CENTER", 0, 120)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    ns.Theme.ApplyBackdrop(frame)
    ns.Theme.AddHeader(frame, "Loot Herald", 260)
    tinsert(UISpecialFrames, "LootHeraldRolePicker") -- Escape closes it

    frame.title = ns.Theme.TitleText(frame, 22)
    frame.title:SetPoint("TOP", 0, -30)
    frame.title:SetText("Choose Your Role")
    frame.title:SetTextColor(ns.Theme.GOLD[1], ns.Theme.GOLD[2], ns.Theme.GOLD[3])

    frame.sub = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.sub:SetPoint("TOP", frame.title, "BOTTOM", 0, -6)
    frame.sub:SetWidth(310)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    frame.remember = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    frame.remember:SetSize(24, 24)
    frame.rememberText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.rememberText:SetPoint("LEFT", frame.remember, "RIGHT", 2, 0)
    frame.rememberText:SetWidth(280)
    frame.rememberText:SetJustifyH("LEFT")
    frame.rememberText:SetText("Don't ask again unless my talents or group role change")
end

local function GetButton(i)
    if buttons[i] then return buttons[i] end
    local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    b:SetSize(300, ROW_HEIGHT - 6)
    b.roleIcon = b:CreateTexture(nil, "OVERLAY")
    b.roleIcon:SetSize(22, 22)
    b.roleIcon:SetPoint("LEFT", 6, 0)
    b.roleIcon:SetTexture(ns.Theme.ROLE_ICON)
    buttons[i] = b
    return b
end

function Picker.Show(instanceName)
    if not frame then Create() end
    local classFile = ns.Role.PlayerClass()
    local profiles = ns.Role.GetClassProfiles(classFile)
    local suggested = ns.Role.Suggest()
    local current = ns.char and ns.char.profileKey

    frame.sub:SetText(instanceName
        and string.format("Entering %s. Which role should loot be judged for?", instanceName)
        or "Which role should loot be judged for?")

    local top = -78
    for i, p in ipairs(profiles) do
        local b = GetButton(i)
        b:ClearAllPoints()
        b:SetPoint("TOP", frame, "TOP", 0, top - (i - 1) * ROW_HEIGHT)
        local label = ns.Role.LabelWithRole(p)
        if suggested and p.key == suggested.key then label = label .. "  |cff1eff00(suggested)|r" end
        if current == p.key then label = "|cffffd100> |r" .. label .. "|cffffd100 <|r" end
        b:SetText(label)
        local tc = ns.Theme.ROLE_TEXCOORD[p.role]
        if tc then b.roleIcon:SetTexCoord(tc[1], tc[2], tc[3], tc[4]) end
        b:SetScript("OnClick", function()
            ns.Role.SetProfile(p.key, frame.remember:GetChecked())
            frame:Hide()
        end)
        b:Show()
    end
    for i = #profiles + 1, #buttons do buttons[i]:Hide() end

    local listBottom = top - #profiles * ROW_HEIGHT
    frame.remember:ClearAllPoints()
    frame.remember:SetPoint("TOPLEFT", frame, "TOPLEFT", 26, listBottom - 4)
    frame.remember:SetChecked(ns.char and ns.char.dontAsk or false)
    frame:SetHeight(-listBottom + 46)
    frame:Show()
end

function Picker.Hide()
    if frame then frame:Hide() end
end
