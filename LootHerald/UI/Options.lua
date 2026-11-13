-- Loot Herald: settings panel (Game Menu > Options > AddOns > Loot Herald).
local _, ns = ...

local Options = {}
ns.Options = Options

-- Two columns of checkboxes. Labels are kept short to fit.
local CHECKS = {
    { key = "enabled", label = "Enable Loot Herald" },
    { key = "onlyInInstances", label = "Only judge rolls in dungeons" },
    { key = "includeRaids", label = "Also judge rolls in raids" },
    { key = "askRoleOnEnter", label = "Ask my role on dungeon entry" },
    { key = "alertOnEqual", label = "Alert for about-equal items" },
    { key = "alertOffSpec", label = "Alert for off-spec upgrades" },
    { key = "alertOnUnscored", label = "Alert for unscored effects" },
    { key = "respectArmorType", label = "Skip armor below my type" },
    { key = "showWhy", label = "Show why (stat changes)" },
    { key = "groupCheck", label = "Group check (who else can use it)" },
    { key = "bindWarning", label = "Bind on Equip reminder" },
    { key = "hitCap", label = "Stop valuing Hit past the cap" },
    { key = "playSound", label = "Play a sound" },
    { key = "raidWarning", label = "Big centre-screen text" },
    { key = "chatSummary", label = "Chat line for every drop" },
    { key = "tooltipLine", label = "Verdict on item tooltips" },
    { key = "announceNeed", label = "Post my Need rolls + why in group chat" },
}

local panel, widgets = nil, {}

local function Refresh()
    if not panel or not ns.db then return end
    for _, w in ipairs(widgets) do w:Refresh() end
end

local function MakeCheck(parent, def, x, y)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb:SetPoint("TOPLEFT", x, y)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(def.label)
    cb:SetScript("OnClick", function(self)
        ns.db[def.key] = self:GetChecked() and true or false
    end)
    function cb:Refresh() self:SetChecked(ns.db[def.key] and true or false) end
    widgets[#widgets + 1] = cb
    return cb
end

local function MakeButton(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 140, 24)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function MakeStepper(parent, y, label, get, set, step, min, max, fmt)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", 20, y)
    local function Round(v) return math.floor(v / step + 0.5) * step end
    local minus = MakeButton(parent, "-", 26, function()
        set(Round(math.max(min, get() - step))) Refresh()
    end)
    local plus = MakeButton(parent, "+", 26, function()
        set(Round(math.min(max, get() + step))) Refresh()
    end)
    minus:SetPoint("TOPLEFT", 330, y + 4)
    plus:SetPoint("LEFT", minus, "RIGHT", 4, 0)
    local holder = { }
    function holder:Refresh() text:SetText(string.format(label .. ": " .. fmt, get())) end
    widgets[#widgets + 1] = holder
end

function Options.Create()
    if panel then return end
    panel = CreateFrame("Frame")
    panel.name = ns.TITLE

    local title = ns.Theme.TitleText(panel, 26)
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(ns.TITLE)
    title:SetTextColor(ns.Theme.GOLD[1], ns.Theme.GOLD[2], ns.Theme.GOLD[3])

    local sub = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetText("Version " .. ns.VERSION .. "  -  Tells you when a drop is an upgrade for your role, so you know when to roll Need.")

    local role = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    role:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -12)
    local roleHolder = {}
    function roleHolder:Refresh()
        local p, auto = ns.Role.GetActive()
        role:SetText("Current role: |cffffffff" .. ns.Role.LabelWithRole(p) .. (auto and " (auto-detected)" or "") .. "|r")
    end
    widgets[#widgets + 1] = roleHolder

    local half = math.ceil(#CHECKS / 2)
    for i, def in ipairs(CHECKS) do
        local col, row = (i <= half) and 0 or 1, (i <= half) and (i - 1) or (i - half - 1)
        MakeCheck(panel, def, 16 + col * 300, -96 - row * 26)
    end
    local y = -96 - half * 26

    y = y - 8
    MakeStepper(panel, y, "Upgrade threshold", function() return ns.db.threshold end,
        function(v) ns.db.threshold = v end, 1, 0, 25, "%d%%")
    y = y - 30
    MakeStepper(panel, y, "Alert size", function() return ns.db.alertScale end,
        function(v) ns.db.alertScale = v ns.Alert.RestorePosition() end, 0.1, 0.6, 2.0, "%.1f")

    y = y - 40
    local b1 = MakeButton(panel, "Choose role...", 140, function() ns.RolePicker.Show() end)
    b1:SetPoint("TOPLEFT", 16, y)
    local b2 = MakeButton(panel, "Test alert", 120, function() ns.RunTest() end)
    b2:SetPoint("LEFT", b1, "RIGHT", 8, 0)
    local b3 = MakeButton(panel, "Reset alert position", 160, function() ns.Alert.ResetPosition() end)
    b3:SetPoint("LEFT", b2, "RIGHT", 8, 0)

    local help = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    help:SetPoint("TOPLEFT", b1, "BOTTOMLEFT", 0, -14)
    help:SetWidth(560)
    help:SetJustifyH("LEFT")
    help:SetText("Drag an alert to move it. Commands: /lh role, /lh test, /lh check <item>, /lh debug <item>, "
        .. "/lh weights, /lh weight <STAT> <value>, /lh history. Upgrade threshold: an item at least this much "
        .. "better is an Upgrade; within this much either way it is About Equal.")

    panel:SetScript("OnShow", Refresh)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, ns.TITLE)
        Settings.RegisterAddOnCategory(category)
        Options.category = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

function Options.Open()
    if Options.category and Settings and Settings.OpenToCategory then
        local id = Options.category.GetID and Options.category:GetID() or Options.category.ID
        local ok = pcall(Settings.OpenToCategory, id)
        if ok then return end
    end
    if InterfaceOptionsFrame_OpenToCategory and panel then
        InterfaceOptionsFrame_OpenToCategory(panel)
        return
    end
    ns.Print("Couldn't open the options window - use /lh help for commands.")
end
