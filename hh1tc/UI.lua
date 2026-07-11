local SS = HH1TC
SS.UI = SS.UI or {}

local function EnsureDB()
    if not HH1TCDB then
        HH1TCDB = {}
    end
    if HH1TCDB.lastCategory == "quests" then
        HH1TCDB.lastCategory = "indicators"
    end
    if not HH1TCDB.lastCategory then
        HH1TCDB.lastCategory = "indicators"
    end
    if not HH1TCDB.expanded then
        HH1TCDB.expanded = {}
    end
    if HH1TCDB.otherExpanded then
        HH1TCDB.expanded.other = HH1TCDB.otherExpanded
        HH1TCDB.otherExpanded = nil
    end
    if type(HH1TCDB.expanded.other) ~= "table" then
        HH1TCDB.expanded.other = {}
    end
    if type(HH1TCDB.expanded.indicators) ~= "table" then
        HH1TCDB.expanded.indicators = {}
    end
end

local function GetExpandedDB(category)
    EnsureDB()
    return HH1TCDB.expanded[category]
end

EnsureDB()

local CATEGORY_ORDER = { "indicators", "other", "settings" }
local ACCORDION_CATEGORIES = { other = true, indicators = true }

local mainWin = CreateFrame("Frame", "HH1TCFrame", UIParent)
mainWin:SetSize(920, 620)
mainWin:SetPoint("CENTER")
mainWin:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
mainWin:SetBackdropColor(0, 0, 0, 0.92)
mainWin:EnableMouse(true)
mainWin:SetMovable(true)
mainWin:RegisterForDrag("LeftButton")
mainWin:SetScript("OnDragStart", mainWin.StartMoving)
mainWin:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    HH1TCDB.point = point
    HH1TCDB.relPoint = relPoint
    HH1TCDB.x = x
    HH1TCDB.y = y
end)
mainWin:Hide()

if HH1TCDB.point then
    mainWin:ClearAllPoints()
    mainWin:SetPoint(HH1TCDB.point, UIParent, HH1TCDB.relPoint or HH1TCDB.point, HH1TCDB.x or 0, HH1TCDB.y or 0)
end

local closeBtn = CreateFrame("Button", nil, mainWin, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", 2, 1)

local title = mainWin:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -14)
SS:StyleFont(title, "title")
title:SetText("hh1tc")

local shellFonts = { navLabels = {}, accordionHeaders = {}, accordionArrows = {} }

function SS.UI.ApplyShellFonts()
    SS:StyleFont(title, "title")
    for _, label in ipairs(shellFonts.navLabels) do
        SS:StyleFont(label, "tab")
    end
    for _, label in ipairs(shellFonts.accordionHeaders) do
        SS:StyleFont(label, "header")
    end
    for _, arrow in ipairs(shellFonts.accordionArrows) do
        SS:StyleFont(arrow, "tab")
    end
end

local navFrame = CreateFrame("Frame", nil, mainWin)
navFrame:SetSize(160, 460)
navFrame:SetPoint("TOPLEFT", 12, -40)

local navButtons = {}
local categoryPanels = {}
local accordionItems = {}

local function RelayoutScroll(scrollChild, items)
    local y = -4
    local totalH = 4
    for _, item in ipairs(items) do
        item.block:SetPoint("TOPLEFT", 4, y)
        local h = 40
        if item.expanded then
            h = h + item.body:GetHeight() + 8
        end
        item.block:SetHeight(h)
        y = y - h - 6
        totalH = totalH + h + 6
    end
    scrollChild:SetHeight(math.max(520, totalH))
end

local function CollapseAccordionItem(category, item)
    if not item.expanded then return end
    item.expanded = false
    GetExpandedDB(category)[item.mod.id] = false
    item.arrow:SetText("►")
    item.body:Hide()
end

local function ToggleAccordionItem(category, item, items, scrollChild)
    EnsureDB()
    local willExpand = not item.expanded
    if willExpand then
        for _, other in ipairs(items) do
            if other ~= item then
                CollapseAccordionItem(category, other)
            end
        end
    end
    item.expanded = willExpand
    GetExpandedDB(category)[item.mod.id] = item.expanded
    if item.expanded then
        item.arrow:SetText("▼")
        item.body:Show()
        if item.mod.GetPanelHeight then
            item.body:SetHeight(item.mod.GetPanelHeight())
        end
        if item.mod.OnShow then item.mod.OnShow() end
    else
        item.arrow:SetText("►")
        item.body:Hide()
    end
    RelayoutScroll(scrollChild, items)
end

local function BuildAccordionCategory(category, container)
    EnsureDB()
    local scrollFrame = CreateFrame("ScrollFrame", "HH1TCScroll_" .. category, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 0)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(740)
    scrollChild:SetHeight(10)
    scrollFrame:SetScrollChild(scrollChild)

    local items = {}
    accordionItems[category] = items
    local expandedOwnerId = nil

    for _, mod in ipairs(SS.modules[category]) do
        if mod.BuildPanel and not mod._built then
            local block = CreateFrame("Frame", nil, scrollChild)
            block:SetWidth(730)

            local header = CreateFrame("Button", nil, block)
            header:SetSize(720, 36)
            header:SetPoint("TOPLEFT", 0, 0)
            header:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 8, edgeSize = 12,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })
            header:SetBackdropColor(0.15, 0.15, 0.15, 0.9)

            local arrow = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            arrow:SetPoint("LEFT", 10, 0)
            SS:StyleFont(arrow, "tab")
            table.insert(shellFonts.accordionArrows, arrow)

            local label = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            label:SetPoint("LEFT", 30, 0)
            SS:StyleFont(label, "header")
            table.insert(shellFonts.accordionHeaders, label)
            label:SetText(mod.title)

            local body = CreateFrame("Frame", nil, block)
            body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 8, -6)
            body:SetWidth(704)
            local bodyHeight = mod.estimatedHeight or 120
            if mod.GetPanelHeight then
                bodyHeight = mod.GetPanelHeight()
            end
            body:SetHeight(bodyHeight)

            mod.BuildPanel(body)
            if mod.GetPanelHeight then
                body:SetHeight(mod.GetPanelHeight())
            end

            local expanded = GetExpandedDB(category)[mod.id] == true
            if expanded then
                if expandedOwnerId then
                    expanded = false
                    GetExpandedDB(category)[mod.id] = false
                else
                    expandedOwnerId = mod.id
                end
            end
            local item = {
                mod = mod,
                block = block,
                header = header,
                arrow = arrow,
                body = body,
                expanded = expanded,
            }

            if expanded then
                arrow:SetText("▼")
                body:Show()
                if mod.OnShow then mod.OnShow() end
            else
                arrow:SetText("►")
                body:Hide()
            end

            header:SetScript("OnClick", function()
                ToggleAccordionItem(category, item, items, scrollChild)
            end)

            header:SetScript("OnEnter", function(self)
                self:SetBackdropColor(0.22, 0.35, 0.22, 0.95)
            end)
            header:SetScript("OnLeave", function(self)
                self:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
            end)

            mod._built = true
            mod._accordionItem = item
            table.insert(items, item)
        end
    end

    RelayoutScroll(scrollChild, items)
    return container
end

local function BuildStandardCategory(category, container)
    local scrollFrame = CreateFrame("ScrollFrame", "HH1TCScroll_" .. category, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 0)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(740)
    scrollChild:SetHeight(10)
    scrollFrame:SetScrollChild(scrollChild)

    local yOffset = -8
    for _, mod in ipairs(SS.modules[category]) do
        if mod.BuildPanel and not mod._built then
            local estHeight = mod.estimatedHeight or 120
            local section, body = SS:CreateSection(scrollChild, mod.title, estHeight)
            section:SetPoint("TOPLEFT", 4, yOffset)
            mod.BuildPanel(body)
            if mod.GetPanelHeight then
                section:SetBodyHeight(mod.GetPanelHeight())
            elseif mod._sectionHeight then
                section:SetBodyHeight(mod._sectionHeight)
            end
            mod._section = section
            mod._built = true
            yOffset = yOffset - section:GetHeight() - 16
        elseif mod._section then
            yOffset = yOffset - mod._section:GetHeight() - 16
        end
    end

    scrollChild:SetHeight(math.max(520, math.abs(yOffset) + 24))
    return container
end

local function BuildCategoryPanel(category)
    if categoryPanels[category] then return categoryPanels[category] end

    local container = CreateFrame("Frame", nil, mainWin)
    container:SetPoint("TOPLEFT", navFrame, "TOPRIGHT", 8, 0)
    container:SetPoint("BOTTOMRIGHT", -16, 16)

    if ACCORDION_CATEGORIES[category] then
        BuildAccordionCategory(category, container)
    else
        BuildStandardCategory(category, container)
    end

    container:Hide()
    categoryPanels[category] = container
    return container
end

local function ExpandModule(category, moduleId)
    local items = accordionItems[category]
    if not items then return end
    for _, item in ipairs(items) do
        if item.mod.id == moduleId then
            if not item.expanded then
                local scrollChild = item.block:GetParent()
                ToggleAccordionItem(category, item, items, scrollChild)
            elseif item.mod.OnShow then
                item.mod.OnShow()
            end
            return
        end
    end
end

local function SelectCategory(category, moduleId)
    EnsureDB()
    SS.currentCategory = category
    HH1TCDB.lastCategory = category

    for _, btn in pairs(navButtons) do
        if btn.category == category then
            btn:SetBackdropColor(0.2, 0.4, 0.2, 0.9)
        else
            btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        end
    end

    for cat, panel in pairs(categoryPanels) do
        panel:Hide()
    end

    local panel = BuildCategoryPanel(category)
    panel:Show()

    if moduleId and ACCORDION_CATEGORIES[category] then
        ExpandModule(category, moduleId)
    end

    SS:Refresh(category)
end

for i, category in ipairs(CATEGORY_ORDER) do
    local btn = CreateFrame("Button", nil, navFrame)
    btn:SetSize(150, 36)
    btn:SetPoint("TOPLEFT", 0, -((i - 1) * 42))
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    btn.category = category

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("CENTER")
    SS:StyleFont(label, "tab")
    table.insert(shellFonts.navLabels, label)
    label:SetText(SS.categoryLabels[category] or category)

    btn:SetScript("OnClick", function()
        SelectCategory(category)
    end)
    navButtons[category] = btn
end

function SS.UI.Show(category, moduleId)
    category = category or HH1TCDB.lastCategory or "indicators"
    if mainWin:IsShown() and SS.currentCategory == category and not moduleId then
        mainWin:Hide()
        return
    end
    mainWin:Show()
    SelectCategory(category, moduleId)
end

function SS.UI.RefreshCategory(category)
    if not categoryPanels[category] then return end
    if ACCORDION_CATEGORIES[category] then
        local items = accordionItems[category]
        if items then
            for _, item in ipairs(items) do
                if item.expanded and item.mod.OnShow then
                    item.mod.OnShow()
                end
                if item.mod.refresh then item.mod.refresh() end
            end
        end
    else
        for _, mod in ipairs(SS.modules[category]) do
            if mod.OnShow then mod.OnShow() end
            if mod.refresh then mod.refresh() end
        end
    end
end

local minimapBtn = CreateFrame("Button", "HH1TCMinimapBtn", Minimap)
minimapBtn:SetSize(31, 31)
minimapBtn:SetFrameStrata("MEDIUM")
minimapBtn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 8, -8)
minimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local icon = minimapBtn:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
icon:SetSize(20, 20)
icon:SetPoint("CENTER")

local border = minimapBtn:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(52, 52)
border:SetPoint("TOPLEFT")

minimapBtn:SetScript("OnClick", function()
    if mainWin:IsShown() then
        mainWin:Hide()
    else
        SS.UI.Show(HH1TCDB.lastCategory)
    end
end)

minimapBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("hh1tc")
    GameTooltip:AddLine("ЛКМ: Открыть настройки", 1, 1, 1)
    GameTooltip:Show()
end)
minimapBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

SLASH_HH1TC1 = "/hh1tc"
SLASH_HH1TC2 = "/hh"
SlashCmdList["HH1TC"] = function()
    SS:Open()
end
