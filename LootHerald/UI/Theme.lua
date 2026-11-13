-- Loot Herald: Warcraft-style look built only from the game's own UI art
-- and fonts (nothing copyrighted is shipped with the addon).
local _, ns = ...

local Theme = {}
ns.Theme = Theme

Theme.TITLE_FONT = "Fonts\\MORPHEUS.TTF"   -- the quest-title / book font
Theme.BODY_FONT = "Fonts\\FRIZQT__.TTF"     -- the standard UI font

Theme.GOLD = { 1.0, 0.82, 0.0 }
Theme.PARCHMENT = { 0.96, 0.89, 0.72 }

Theme.BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

Theme.ROLE_ICON = "Interface\\LFGFrame\\UI-LFG-ICON-ROLES"
Theme.ROLE_TEXCOORD = {
    TANK   = { 0, 0.26171875, 0.26171875, 0.5234375 },
    HEALER = { 0.26171875, 0.5234375, 0, 0.26171875 },
    DPS    = { 0.26171875, 0.5234375, 0.26171875, 0.5234375 },
}

local function HexToRGB(hex)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end
Theme.HexToRGB = HexToRGB

function Theme.VerdictRGB(display)
    return HexToRGB(ns.VERDICT_COLORS[display] or "ffd100")
end

function Theme.ApplyBackdrop(frame)
    if frame.SetBackdrop then
        frame:SetBackdrop(Theme.BACKDROP)
        frame:SetBackdropColor(1, 1, 1, 0.95)
        frame:SetBackdropBorderColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
    end
end

-- Font string in the Warcraft title font, falling back to the template font.
function Theme.TitleText(parent, size, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormalLarge")
    fs:SetFont(Theme.TITLE_FONT, size or 18, "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    return fs
end

-- The classic gold banner header used by Blizzard dialogs.
function Theme.AddHeader(frame, text, width)
    local header = frame:CreateTexture(nil, "ARTWORK")
    header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    header:SetSize(width or 300, 64)
    header:SetPoint("TOP", 0, 12)
    local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOP", header, "TOP", 0, -14)
    fs:SetText(text)
    frame.headerText = fs
    return header, fs
end

function Theme.PlaySound(kind)
    if not (ns.db and ns.db.playSound) or not PlaySound or not SOUNDKIT then return end
    local id
    if kind == "UPGRADE" then
        id = SOUNDKIT.RAID_WARNING or SOUNDKIT.READY_CHECK
    else
        id = SOUNDKIT.IG_QUEST_LIST_OPEN or SOUNDKIT.IG_MAINMENU_OPEN
    end
    if id then pcall(PlaySound, id, "Master") end
end

function Theme.RaidWarning(text, display)
    if not (ns.db and ns.db.raidWarning) then return end
    if RaidNotice_AddMessage and RaidWarningFrame then
        local r, g, b = Theme.VerdictRGB(display)
        pcall(RaidNotice_AddMessage, RaidWarningFrame, text, { r = r, g = g, b = b })
    end
end
