if not LootTimerDB then
    LootTimerDB = {
        itemId = "45072",
        duration = 75,
        showFrame = true,
    }
end

local f = CreateFrame("Frame", "LootTimerAnchor", UIParent)
f:SetSize(100, 40)
f:SetPoint("CENTER", 0, 0)
f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
f:SetBackdropColor(0, 0, 0, 0.5)
f:EnableMouse(true)
f:SetMovable(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)

local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
label:SetPoint("TOP", f, "TOP", 0, 5)
label:SetText("LootTimer")

local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
text:SetPoint("CENTER", f, "CENTER", 0, 0)
text:SetText("")

local timeLeft = 0

local function UpdateFrameVisibility()
    if LootTimerDB.showFrame then
        if timeLeft > 0 then
            f:Show()
            f:SetAlpha(1)
        else
            f:Hide()
        end
    else
        f:Hide()
    end
end

f:Hide()

f:SetScript("OnUpdate", function(self, elapsed)
    if timeLeft > 0 then
        timeLeft = timeLeft - elapsed
        if LootTimerDB.showFrame then
            text:SetText(string.format("%.1f", timeLeft))
            self:Show()
            self:SetAlpha(1)
        else
            text:SetText("")
            self:Hide()
        end
    else
        timeLeft = 0
        text:SetText("")
        self:Hide()
    end
end)

f:RegisterEvent("CHAT_MSG_LOOT")
f:SetScript("OnEvent", function(self, event, msg)
    if msg:find("item:" .. LootTimerDB.itemId) then
        timeLeft = LootTimerDB.duration
        UpdateFrameVisibility()
    end
end)

local LootTimerUI = {}

local function BuildLootTimerPanel(parent)
    parent:SetHeight(135)

    local cbShow = CreateFrame("CheckButton", "LT_ShowCheck", parent, "InterfaceOptionsCheckButtonTemplate")
    cbShow:SetPoint("TOPLEFT", 0, 0)
    _G[cbShow:GetName().."Text"]:SetText("Включить")
    HH1TC:StyleFont(_G[cbShow:GetName().."Text"], "description")
    cbShow:SetScript("OnClick", function(self)
        LootTimerDB.showFrame = self:GetChecked()
        UpdateFrameVisibility()
    end)

    local idLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    idLabel:SetPoint("TOPLEFT", cbShow, "BOTTOMLEFT", 0, -12)
    idLabel:SetText("ID отслеживаемого предмета:")
    HH1TC:StyleFont(idLabel, "description")

    local idBox = CreateFrame("EditBox", "LT_ItemIdBox", parent, "InputBoxTemplate")
    idBox:SetSize(120, 24)
    idBox:SetPoint("TOPLEFT", idLabel, "BOTTOMLEFT", 0, -8)
    idBox:SetAutoFocus(false)
    idBox:SetText(LootTimerDB.itemId)
    idBox:SetScript("OnEnterPressed", function(self)
        local v = self:GetText()
        if v and v ~= "" then LootTimerDB.itemId = v end
        self:ClearFocus()
    end)
    idBox:SetScript("OnEditFocusLost", function(self)
        local v = self:GetText()
        if v and v ~= "" then LootTimerDB.itemId = v end
    end)

    local durSlider = CreateFrame("Slider", "LT_Duration", parent, "OptionsSliderTemplate")
    durSlider:SetPoint("TOPLEFT", idBox, "BOTTOMLEFT", 0, -36)
    durSlider:SetMinMaxValues(5, 120)
    durSlider:SetValueStep(1)
    durSlider:SetSize(200, 20)
    durSlider:SetValue(LootTimerDB.duration)
    local durLabel = _G[durSlider:GetName().."Text"]
    HH1TC:StyleFont(durLabel, "description")
    durLabel:SetText("Длительность: "..LootTimerDB.duration)
    durSlider:SetScript("OnValueChanged", function(self, v)
        LootTimerDB.duration = math.floor(v + 0.5)
        durLabel:SetText("Длительность: "..LootTimerDB.duration)
    end)

    local bottomSpacer = parent:CreateFontString(nil, "OVERLAY")
    bottomSpacer:SetPoint("TOPLEFT", durSlider, "BOTTOMLEFT", 0, -10)
    bottomSpacer:SetHeight(10)

    LootTimerUI.idBox = idBox
    LootTimerUI.durSlider = durSlider
    LootTimerUI.cbShow = cbShow
    LootTimerUI.refresh = function()
        cbShow:SetChecked(LootTimerDB.showFrame)
        idBox:SetText(LootTimerDB.itemId)
        durSlider:SetValue(LootTimerDB.duration)
    end
end

HH1TC:RegisterModule("other", "loottimer", {
    title = "LootTimer",
    order = 1,
    estimatedHeight = 135,
    BuildPanel = BuildLootTimerPanel,
    OnShow = function()
        if LootTimerUI.refresh then LootTimerUI.refresh() end
    end,
})

SLASH_LOOTTIMER1 = "/lt"
SlashCmdList["LOOTTIMER"] = function()
    HH1TC:Open("other", "loottimer")
end
