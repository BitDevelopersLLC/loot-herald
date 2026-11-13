-- Loot Herald: add a verdict line to item tooltips (bags, chat links,
-- quest rewards, the auction house - anywhere an item tooltip appears).
local _, ns = ...

local Tooltip = {}
ns.Tooltip = Tooltip

local function GetLink(tooltip)
    if TooltipUtil and TooltipUtil.GetDisplayedItem then
        local _, link = TooltipUtil.GetDisplayedItem(tooltip)
        if link then return link end
    end
    if tooltip.GetItem then
        local _, link = tooltip:GetItem()
        return link
    end
end

local function Add(tooltip)
    if not ns.db or not ns.db.enabled or not ns.db.tooltipLine then return end
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
    local link = GetLink(tooltip)
    if not link or (issecretvalue and issecretvalue(link)) then return end
    local res = ns.Judge.Item(link)
    local text = ns.Judge.ShortText(res)
    if text then
        tooltip:AddLine("|cffd4af37Loot Herald:|r " .. text, 1, 1, 1, true)
        local v = res.verdict
        if ns.db.showWhy and (v == "UPGRADE" or v == "EQUAL" or v == "DOWNGRADE") then
            local why = ns.Judge.WhyText(res, 3)
            if why then tooltip:AddLine("   " .. why, 1, 1, 1, true) end
        end
    end
end

function Tooltip.Init()
    if Tooltip.done then return end
    Tooltip.done = true
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
            local ok, err = pcall(Add, tooltip)
            if not ok then ns.Debug("tooltip: %s", tostring(err)) end
        end)
    elseif GameTooltip and GameTooltip.HookScript then
        local function hook(tt)
            local ok, err = pcall(Add, tt)
            if not ok then ns.Debug("tooltip: %s", tostring(err)) end
        end
        GameTooltip:HookScript("OnTooltipSetItem", hook)
        if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", hook) end
    end
end
