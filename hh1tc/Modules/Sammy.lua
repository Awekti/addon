if not SammyDB then
    SammyDB = {}
end
if SammyDB.enabled == nil then
    SammyDB.enabled = false
end

local SAMMY_NPC_ID = 78892
local SAMMY_NAMES = {
    ["Сэмми"] = true,
    ["Sammy"] = true,
    ["сэмми"] = true,
    ["sammy"] = true,
}
local GOSSIP_INDEX = { [1] = 1, [10] = 2, [100] = 3, [1000] = 4 }
local AMOUNTS = { 1, 10, 100, 1000 }

local amountButtons = {}
local hintHideAt = 0
local wasSammyTarget = false
local skipNextOnClick = false
local selectedAmount = nil
local pendingGossipIndex = nil

local function GetNpcIdFromGuid(guid)
    if not guid then return nil end

    if guid:find("-") then
        local unitType, _, _, _, _, npcId = strsplit("-", guid)
        if unitType == "Creature" or unitType == "Vehicle" then
            return tonumber(npcId)
        end
        return nil
    end

    if guid:sub(1, 2) == "0x" then
        local id = tonumber(guid:sub(7, 10), 16)
        if id and id > 0 then return id end
        id = tonumber(guid:sub(9, 12), 16)
        if id and id > 0 then return id end
        id = tonumber(guid:sub(5, 8), 16)
        if id and id > 0 then return id end
    end

    return nil
end

local function GetTargetNpcId()
    return GetNpcIdFromGuid(UnitGUID("target"))
end

local function IsSammyByName()
    if not UnitExists("target") then return false end
    local name = UnitName("target")
    return name and SAMMY_NAMES[name] == true
end

local function IsSammyTarget()
    if not UnitExists("target") then return false end
    if UnitIsPlayer("target") then return false end
    if GetTargetNpcId() == SAMMY_NPC_ID then return true end
    return IsSammyByName()
end

local function GetSelectedGossipIndex()
    if not selectedAmount then return nil end
    return GOSSIP_INDEX[selectedAmount]
end

local centerHint = CreateFrame("Frame", "SammyCenterHint", UIParent)
centerHint:SetSize(460, 56)
centerHint:SetPoint("CENTER", 0, 60)
centerHint:SetFrameStrata("FULLSCREEN_DIALOG")
centerHint:SetFrameLevel(300)
centerHint:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
centerHint:SetBackdropColor(0, 0, 0, 0.85)
centerHint:Hide()

local centerHintText = centerHint:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
centerHintText:SetPoint("CENTER")
centerHintText:SetWidth(430)
centerHintText:SetJustifyH("CENTER")
centerHintText:SetText("Отключите модуль: Другое - Сэмми")

local function ShowCenterHint()
    centerHint:Show()
    hintHideAt = GetTime() + 4
end

local function UpdateHighlights()
    for _, amount in ipairs(AMOUNTS) do
        local btn = amountButtons[amount]
        if not btn then
        elseif selectedAmount == amount then
            if btn.selectedBg then btn.selectedBg:Show() end
            if btn.normalTex then btn.normalTex:SetVertexColor(0.55, 1, 0.55) end
            if btn.label then btn.label:SetTextColor(0.2, 1, 0.2) end
        else
            if btn.selectedBg then btn.selectedBg:Hide() end
            if btn.normalTex then btn.normalTex:SetVertexColor(1, 1, 1) end
            if btn.label then btn.label:SetTextColor(1, 0.82, 0) end
        end
        if btn and btn.label then
            btn.label:SetText(tostring(amount))
        end
    end
end

local bar = CreateFrame("Frame", "SammyButtonBar", UIParent)
bar:SetSize(220, 40)
bar:SetPoint("CENTER", 0, -120)
bar:SetFrameStrata("HIGH")
bar:SetFrameLevel(200)
bar:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
bar:SetBackdropColor(0, 0, 0, 0.75)
bar:Hide()

bar:SetScript("OnUpdate", function(self, elapsed)
    if hintHideAt > 0 and GetTime() >= hintHideAt then
        hintHideAt = 0
        centerHint:Hide()
    end

    if not SammyDB.enabled then return end
    self.checkElapsed = (self.checkElapsed or 0) + elapsed
    if self.checkElapsed < 0.3 then return end
    self.checkElapsed = 0

    local shouldShow = IsSammyTarget()
    if shouldShow and not self:IsShown() then
        self:Show()
        UpdateHighlights()
    elseif not shouldShow and self:IsShown() then
        self:Hide()
    end
end)

for i, amount in ipairs(AMOUNTS) do
    local btnAmount = amount
    local gossipIndex = GOSSIP_INDEX[btnAmount]

    local btn = CreateFrame("Button", "SammyBtn"..btnAmount, bar, "SecureActionButtonTemplate")
    btn:SetSize(48, 26)
    btn:SetPoint("LEFT", bar, "LEFT", 8 + (i - 1) * 52, 0)
    btn:SetAttribute("type", "macro")
    btn:RegisterForClicks("AnyUp")

    btn.selectedBg = btn:CreateTexture(nil, "BACKGROUND")
    btn.selectedBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    btn.selectedBg:SetVertexColor(0.1, 0.55, 0.1, 0.95)
    btn.selectedBg:SetPoint("TOPLEFT", -2, 2)
    btn.selectedBg:SetPoint("BOTTOMRIGHT", 2, -2)
    btn.selectedBg:Hide()

    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
    tex:SetTexCoord(0, 0.625, 0, 0.6875)
    tex:SetAllPoints()
    btn:SetNormalTexture(tex)
    btn.normalTex = tex

    local pushed = btn:CreateTexture(nil, "ARTWORK")
    pushed:SetTexture("Interface\\Buttons\\UI-Panel-Button-Down")
    pushed:SetTexCoord(0, 0.625, 0, 0.6875)
    pushed:SetAllPoints()
    btn:SetPushedTexture(pushed)

    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
    highlight:SetTexCoord(0, 0.625, 0, 0.6875)
    highlight:SetAllPoints()
    btn:SetHighlightTexture(highlight)

    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.label:SetDrawLayer("OVERLAY", 7)
    btn.label:SetPoint("CENTER", 0, 1)
    btn.label:SetTextColor(1, 0.82, 0)
    btn.label:SetText(tostring(btnAmount))

    btn:SetScript("PreClick", function(self)
        if not SammyDB.enabled or not IsSammyTarget() then
            self:SetAttribute("macrotext", "")
            ShowCenterHint()
            return
        end

        if selectedAmount == btnAmount then
            selectedAmount = nil
            pendingGossipIndex = nil
            UpdateHighlights()
            self:SetAttribute("macrotext", "")
            skipNextOnClick = true
            return
        end

        selectedAmount = btnAmount
        pendingGossipIndex = gossipIndex
        UpdateHighlights()

        if GossipFrame and GossipFrame:IsShown() and GetNumGossipOptions() >= gossipIndex then
            self:SetAttribute("macrotext", "/run SelectGossipOption("..gossipIndex..")")
        else
            self:SetAttribute("macrotext", "/run if InteractUnit then InteractUnit('target') end")
        end
    end)

    btn:SetScript("PostClick", function()
        UpdateHighlights()
    end)

    btn:SetScript("OnClick", function()
        if skipNextOnClick then
            skipNextOnClick = false
            UpdateHighlights()
            return
        end
        if not SammyDB.enabled or not IsSammyTarget() then
            ShowCenterHint()
            return
        end
        UpdateHighlights()
    end)

    amountButtons[btnAmount] = btn
end

local function UpdateBar()
    if SammyDB.enabled and IsSammyTarget() then
        bar:Show()
    else
        bar:Hide()
    end
    UpdateHighlights()
end

local function TrySelectGossipOption()
    if not SammyDB.enabled or not IsSammyTarget() then return end
    local index = pendingGossipIndex or GetSelectedGossipIndex()
    if not index then return end
    if GossipFrame and GossipFrame:IsShown() and index <= GetNumGossipOptions() then
        SelectGossipOption(index)
        pendingGossipIndex = nil
    end
end

local function ScheduleUpdateBar()
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        UpdateBar()
    end)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GOSSIP_SHOW")
eventFrame:RegisterEvent("GOSSIP_CLOSED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "hh1tc" then
        ScheduleUpdateBar()
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        ScheduleUpdateBar()
    elseif event == "PLAYER_TARGET_CHANGED" then
        local isSammy = IsSammyTarget()
        if SammyDB.enabled and wasSammyTarget and not isSammy then
            ShowCenterHint()
        end
        wasSammyTarget = isSammy
        UpdateBar()
    elseif event == "GOSSIP_SHOW" then
        TrySelectGossipOption()
    elseif event == "GOSSIP_CLOSED" then
        pendingGossipIndex = nil
    end
end)

local function BuildSammyPanel(parent)
    parent:SetHeight(90)

    local cb = CreateFrame("CheckButton", "Sammy_EnabledCheck", parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 0, 0)
    _G[cb:GetName().."Text"]:SetText("Включить")
    HH1TC:StyleFont(_G[cb:GetName().."Text"], "description")
    cb:SetScript("OnClick", function(self)
        SammyDB.enabled = self:GetChecked() and true or false
        centerHint:Hide()
        hintHideAt = 0
        UpdateBar()
    end)

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 0, -8)
    hint:SetWidth(620)
    hint:SetJustifyH("LEFT")
    HH1TC:StyleFont(hint, "description")
    hint:SetText("Быстрый выбор пожертвования для Сэмми.")

    cb:SetChecked(SammyDB.enabled == true)
    UpdateBar()
end

HH1TC:RegisterModule("other", "sammy", {
    title = "Сэмми",
    order = 2,
    estimatedHeight = 90,
    BuildPanel = BuildSammyPanel,
    OnShow = function()
        if _G["Sammy_EnabledCheck"] then
            _G["Sammy_EnabledCheck"]:SetChecked(SammyDB.enabled == true)
        end
        UpdateBar()
    end,
})

SLASH_SAMMY1 = "/sammy"
SlashCmdList["SAMMY"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "debug" then
        local guid = UnitGUID("target")
        local name = UnitName("target")
        print("|cff00ff00[Сэмми debug]|r enabled:", SammyDB.enabled, "name:", name or "nil", "guid:", guid or "nil", "npcId:", GetTargetNpcId() or "nil", "match:", IsSammyTarget())
        return
    end
    HH1TC:Open("other", "sammy")
end

ScheduleUpdateBar()
