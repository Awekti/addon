local TARGET_BUTTON_NAME = "PVPLadderInfoFrameCentralContainerScrollFrameButton1ReplayPlayButton"

local function PlayReplay()
    local target = _G[TARGET_BUTTON_NAME]
    if target then
        target:Click()
    else
        print("|cff00ff00[ArenaReplay]:|r Кнопка реплея не найдена. Сначала открой окно ладдера.")
    end
end

local function BuildArenaReplayPanel(parent)
    parent:SetHeight(70)

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hint:SetPoint("TOPLEFT", 0, 0)
    hint:SetWidth(420)
    hint:SetJustifyH("LEFT")
    HH1TC:StyleFont(hint, "description")
    hint:SetText("Откройте окно PVP-ладдера, затем нажмите кнопку ниже для запуска реплея.")

    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(140, 28)
    btn:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -10)
    btn:SetText("Запустить реплей")
    btn:SetScript("OnClick", PlayReplay)
end

HH1TC:RegisterModule("other", "arenareplay", {
    title = "ArenaReplay",
    order = 5,
    estimatedHeight = 70,
    BuildPanel = BuildArenaReplayPanel,
})
