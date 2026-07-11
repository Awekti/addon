HH1TC = HH1TC or {}

if SirusSuiteDB then
    if not HH1TCDB then
        HH1TCDB = SirusSuiteDB
    else
        for k, v in pairs(SirusSuiteDB) do
            if HH1TCDB[k] == nil then
                HH1TCDB[k] = v
            end
        end
    end
end
if not HH1TCDB then
    HH1TCDB = {}
end

local SS = HH1TC

SS.modules = {
    indicators = {},
    other = {},
    settings = {},
}

SS.categoryLabels = {
    indicators = "Индикаторы игроков",
    other = "Другое",
    settings = "Настройки",
}

SS.FONT_DEFAULTS = {
    title = 18,
    tab = 14,
    header = 15,
    description = 14,
}

SS.fontRegistry = {}

SS.currentCategory = "indicators"

function SS:EnsureFontDB()
    if not HH1TCDB then HH1TCDB = {} end
    if not HH1TCDB.fonts then
        HH1TCDB.fonts = {}
    end
end

function SS:GetFontSize(role)
    self:EnsureFontDB()
    if HH1TCDB.fonts[role] then
        return HH1TCDB.fonts[role]
    end
    return self.FONT_DEFAULTS[role] or 14
end

function SS:StyleFont(fontString, role)
    if not fontString or not fontString.SetFont then return end
    role = role or "description"
    fontString:SetFont("Fonts\\FRIZQT__.TTF", self:GetFontSize(role), "OUTLINE")
    self.fontRegistry[role] = self.fontRegistry[role] or {}
    for _, fs in ipairs(self.fontRegistry[role]) do
        if fs == fontString then return end
    end
    table.insert(self.fontRegistry[role], fontString)
end

function SS:ApplyFonts()
    for role, list in pairs(self.fontRegistry) do
        local size = self:GetFontSize(role)
        for _, fs in ipairs(list) do
            if fs and fs.SetFont then
                fs:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
            end
        end
    end
    if self.UI and self.UI.ApplyShellFonts then
        self.UI.ApplyShellFonts()
    end
end

function SS:RegisterModule(category, id, opts)
    if not self.modules[category] then return end
    opts.id = id
    opts.order = opts.order or 100
    opts._built = false
    table.insert(self.modules[category], opts)
    table.sort(self.modules[category], function(a, b)
        return a.order < b.order
    end)
    if self.OnModuleRegistered then
        self:OnModuleRegistered(category, id)
    end
end

function SS:Refresh(category)
    category = category or self.currentCategory
    if self.UI and self.UI.RefreshCategory then
        self.UI.RefreshCategory(category)
    end
end

function SS:Open(category, moduleId)
    if not HH1TCDB then HH1TCDB = {} end
    category = category or HH1TCDB.lastCategory or "indicators"
    if self.UI and self.UI.Show then
        self.UI.Show(category, moduleId)
    end
end

function SS:CreateSection(parent, title, estimatedHeight)
    local section = CreateFrame("Frame", nil, parent)
    section:SetWidth(parent:GetWidth() > 0 and parent:GetWidth() or 540)

    local header = section:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 8, -4)
    self:StyleFont(header, "header")
    header:SetText(title)

    local body = CreateFrame("Frame", nil, section)
    body:SetPoint("TOPLEFT", 8, -28)
    body:SetPoint("RIGHT", section, "RIGHT", -8, 0)
    body:SetHeight(estimatedHeight or 100)

    section.body = body
    section.header = header
    section:SetHeight((estimatedHeight or 100) + 36)

    function section:SetBodyHeight(h)
        body:SetHeight(h)
        self:SetHeight(h + 36)
    end

    return section, body
end
