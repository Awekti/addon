local SS = HH1TC

local FONT_KEYS = {
    { key = "title", label = "Заголовок окна", min = 12, max = 28, default = 18 },
    { key = "tab", label = "Вкладки", min = 10, max = 22, default = 14 },
    { key = "header", label = "Заголовки секций", min = 11, max = 24, default = 15 },
    { key = "description", label = "Описания", min = 10, max = 22, default = 14 },
}

local sliders = {}

local function BuildFontsPanel(parent)
    parent:SetHeight(220)

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hint:SetPoint("TOPLEFT", 0, 0)
    hint:SetWidth(640)
    hint:SetJustifyH("LEFT")
    SS:StyleFont(hint, "description")
    hint:SetText("Размеры шрифтов интерфейса hh1tc. Изменения применяются сразу.")

    local anchor = hint
    for i, cfg in ipairs(FONT_KEYS) do
        local s = CreateFrame("Slider", "SS_Font_"..cfg.key, parent, "OptionsSliderTemplate")
        s:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, i == 1 and -20 or -36)
        s:SetMinMaxValues(cfg.min, cfg.max)
        s:SetValueStep(1)
        s:SetSize(280, 20)
        if s.SetObeyStepOnDrag then
            s:SetObeyStepOnDrag(true)
        end

        local label = _G[s:GetName().."Text"]
        local function ApplyValue(v)
            v = math.floor(v + 0.5)
            SS:EnsureFontDB()
            HH1TCDB.fonts[cfg.key] = v
            label:SetText(cfg.label..": "..v)
            SS:StyleFont(label, "description")
            SS:ApplyFonts()
        end

        s:SetScript("OnValueChanged", function(self, v)
            ApplyValue(v)
        end)

        SS:StyleFont(label, "description")
        ApplyValue(SS:GetFontSize(cfg.key))
        s:SetValue(SS:GetFontSize(cfg.key))
        sliders[cfg.key] = s
        anchor = s
    end
end

local function RefreshFontsPanel()
    for _, cfg in ipairs(FONT_KEYS) do
        local s = sliders[cfg.key]
        if s then
            local v = SS:GetFontSize(cfg.key)
            s:SetValue(v)
            local label = _G[s:GetName().."Text"]
            if label then
                label:SetText(cfg.label..": "..v)
            end
        end
    end
end

SS:RegisterModule("settings", "fonts", {
    title = "Шрифты",
    order = 1,
    estimatedHeight = 220,
    BuildPanel = BuildFontsPanel,
    OnShow = RefreshFontsPanel,
})
