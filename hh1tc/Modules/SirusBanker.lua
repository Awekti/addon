if not SirusBankerDB then
    SirusBankerDB = { enabled = true }
end

local function MoveToBank()
    if not (UnitExists("npc") or BankFrame:IsVisible()) then
        print("|cff00ff00SirusBanker:|r Сначала открой банк!")
        return
    end

    local bankItems = {}
    for bag = -1, 11 do
        if bag == -1 or bag > 4 then
            local slots = GetContainerNumSlots(bag)
            if slots and slots > 0 then
                for slot = 1, slots do
                    local id = GetContainerItemID(bag, slot)
                    if id then bankItems[id] = true end
                end
            end
        end
    end

    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        if slots and slots > 0 then
            for slot = 1, slots do
                local id = GetContainerItemID(bag, slot)
                if id and bankItems[id] then
                    UseContainerItem(bag, slot)
                end
            end
        end
    end
end

local f = CreateFrame("Button", "UniversalBankerButton", UIParent, "UIPanelButtonTemplate")
f:SetSize(70, 20)
f:SetText("Скласть")
f:Hide()

local function SkinButton()
    if ElvUI then
        local E = unpack(ElvUI)
        if E and E.Skins then
            E.Skins:HandleButton(f)
            if f.Text then f.Text:SetFont(E.media.normFont, 14, "OUTLINE") end
        end
    end
end

f:SetScript("OnClick", MoveToBank)

local function PositionButton()
    if not SirusBankerDB.enabled then
        f:Hide()
        return false
    end

    local parent = (ElvUI_BankContainerFrame and ElvUI_BankContainerFrame:IsVisible() and ElvUI_BankContainerFrame)
        or (CombuctorFrame2 and CombuctorFrame2:IsVisible() and CombuctorFrame2)
        or (CombuctorFrame1 and CombuctorFrame1:IsVisible() and CombuctorFrame1)
        or (BankFrame:IsVisible() and BankFrame)

    if parent then
        local closeButton = parent.CloseButton or _G[parent:GetName().."CloseButton"]
        if closeButton and closeButton:IsVisible() then
            f:SetParent(parent)
            f:ClearAllPoints()
            f:SetPoint("RIGHT", closeButton, "LEFT", -2, 0)
            f:SetFrameLevel(closeButton:GetFrameLevel() + 1)
            SkinButton()
            f:Show()
            return true
        end
    end
    return false
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("BANKFRAME_OPENED")
watcher:RegisterEvent("BANKFRAME_CLOSED")

watcher:SetScript("OnEvent", function(self, event)
    if event == "BANKFRAME_OPENED" then
        local timer = 0
        local waitFrame = CreateFrame("Frame")
        waitFrame:SetScript("OnUpdate", function(this, elapsed)
            timer = timer + elapsed
            if PositionButton() or timer > 2 then
                this:SetScript("OnUpdate", nil)
            end
        end)
    elseif event == "BANKFRAME_CLOSED" then
        f:Hide()
    end
end)

local function BuildSirusBankerPanel(parent)
    parent:SetHeight(60)

    local cb = CreateFrame("CheckButton", "SB_EnabledCheck", parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 0, 0)
    _G[cb:GetName().."Text"]:SetText("Показывать кнопку «Скласть» в банке")
    HH1TC:StyleFont(_G[cb:GetName().."Text"], "description")
    cb:SetScript("OnClick", function(self)
        SirusBankerDB.enabled = self:GetChecked()
        if not SirusBankerDB.enabled then f:Hide() end
    end)

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hint:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 0, -8)
    HH1TC:StyleFont(hint, "description")
    hint:SetText("Перемещает дубликаты предметов из сумок в банк.")

    cb:SetChecked(SirusBankerDB.enabled)
end

HH1TC:RegisterModule("other", "sirusbanker", {
    title = "SirusBanker",
    order = 3,
    estimatedHeight = 60,
    BuildPanel = BuildSirusBankerPanel,
})
