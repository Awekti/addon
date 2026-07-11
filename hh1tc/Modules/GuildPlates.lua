if not GuildPlatesDB then GuildPlatesDB = {} end
if not GuildPlatesSettings then GuildPlatesSettings = { enabled = true, iconSize = 40, iconOffset = 25, gX = 0, gY = 25, gFontSize = 12, showSyncChat = false } end

local function SettingEnabled(value)
    return value == true or value == 1 or value == "1"
end

local function NormalizeGuildPlatesSettings()
    if GuildPlatesSettings.enabled == nil then
        GuildPlatesSettings.enabled = true
    else
        GuildPlatesSettings.enabled = SettingEnabled(GuildPlatesSettings.enabled)
    end
    if GuildPlatesSettings.showSyncChat ~= nil then
        GuildPlatesSettings.showSyncChat = SettingEnabled(GuildPlatesSettings.showSyncChat)
    end
end

NormalizeGuildPlatesSettings()
if not GuildFilter then GuildFilter = {} end
if not GuildColors then GuildColors = {} end

local function SyncGuildFilterToDB()
    if not HH1TCDB then HH1TCDB = {} end
    HH1TCDB.GuildFilter = HH1TCDB.GuildFilter or {}
    wipe(HH1TCDB.GuildFilter)
    for k, v in pairs(GuildFilter) do
        HH1TCDB.GuildFilter[k] = v
    end
    HH1TCDB.GuildColors = HH1TCDB.GuildColors or {}
    wipe(HH1TCDB.GuildColors)
    for k, v in pairs(GuildColors) do
        HH1TCDB.GuildColors[k] = v
    end
end

local function RestoreGuildFilterFromDB()
    if not HH1TCDB then return end
    local hasGlobal = next(GuildFilter) ~= nil
    local hasDB = HH1TCDB.GuildFilter and next(HH1TCDB.GuildFilter) ~= nil
    if not hasGlobal and hasDB then
        for k, v in pairs(HH1TCDB.GuildFilter) do
            GuildFilter[k] = v
        end
    end
    if HH1TCDB.GuildColors then
        for k, v in pairs(HH1TCDB.GuildColors) do
            if GuildColors[k] == nil then
                GuildColors[k] = v
            end
        end
    end
    if hasGlobal and not hasDB then
        SyncGuildFilterToDB()
    end
end

local function NormalizeGuildFilter()
    if type(GuildFilter) ~= "table" then
        GuildFilter = {}
        return
    end
    local hasNumericKeys = false
    for k in pairs(GuildFilter) do
        if type(k) == "number" then
            hasNumericKeys = true
            break
        end
    end
    if not hasNumericKeys then return end
    local normalized = {}
    for k, v in pairs(GuildFilter) do
        if type(k) == "string" and v then
            normalized[k] = true
        elseif type(k) == "number" and type(v) == "string" and v ~= "" then
            normalized[v] = true
        end
    end
    GuildFilter = normalized
end

RestoreGuildFilterFromDB()
NormalizeGuildFilter()

local SS = HH1TC

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
frame:RegisterEvent("RAID_TARGET_UPDATE")

local sendQueue, syncCounter, lastSenderName = {}, 0, ""
local syncTimerTotal, sendTimer = 0, 0
local lockTimer = 0
local refreshPending = 0
local platesNeedRefresh = false
local forceRaidRefresh = false
local guildFilterLookup = {}

local ColorList = {
    {1, 0.8, 0}, {0.1, 1, 0.1}, {1, 0.1, 0.1}, {0.2, 0.7, 1}, 
    {1, 0.5, 0}, {1, 0.3, 0.8}, {0.6, 0.2, 1}, {1, 1, 1}, 
    {0.1, 1, 0.8}, {0.7, 1, 0.1}, {0.5, 0.5, 0.5}, {1, 0.9, 0.6}
}

local function RebuildGuildFilterLookup()
    for k in pairs(guildFilterLookup) do guildFilterLookup[k] = nil end
    for fg in pairs(GuildFilter) do
        guildFilterLookup[fg:lower()] = fg
    end
end

RebuildGuildFilterLookup()

local function RequestPlateRefresh(forceRaid)
    platesNeedRefresh = true
    if forceRaid then forceRaidRefresh = true end
end

local function CleanName(n) return n and string.match(n, "([^%-]+)") or n end

local function GetSyncChannel()
    if GetNumRaidMembers() > 0 then return "RAID" end
    if GetNumPartyMembers() > 0 then return "PARTY" end
    if IsInGuild() then return "GUILD" end
    return nil
end

local function ShareFullDB(targetChan)
    if not GuildPlatesDB then return end
    local chan = targetChan or GetSyncChannel()
    if not chan then return end
    for k in pairs(sendQueue) do sendQueue[k] = nil end

    local count = 0
    for name, tag in pairs(GuildPlatesDB) do
        count = count + 1
        if count > 500 then break end
        table.insert(sendQueue, { n = name, t = tag, c = chan })
    end
end

local lastRequestTime = 0
local function RequestData()
    if GetTime() - lastRequestTime < 30 then return end

    local chan = GetSyncChannel()
    if chan then
        SendAddonMessage("GP_SYNC", "GET_DATA", chan)
        lastRequestTime = GetTime()
    end
end

local function HandleSyncMessage(msg, channel, sender)
    sender = CleanName(sender)
    if not sender or sender == CleanName(UnitName("player")) then return end

    if msg == "GET_DATA" then
        ShareFullDB(channel)
        return
    end

    local colon = msg and msg:find(":")
    if not colon then return end

    local name = msg:sub(1, colon - 1)
    local tag = msg:sub(colon + 1)
    if name == "" or tag == "" then return end

    name = CleanName(name)
    if not GuildPlatesDB[name] then
        syncCounter = syncCounter + 1
        lastSenderName = sender
    end
    GuildPlatesDB[name] = tag
    RequestPlateRefresh()
end


local function IsExcludedFrame(f)
    local n = f:GetName()
    if not n then return false end
    if n:find("HH1TC") or n:find("^GP_") or n:find("^SRC_") or n:find("^SQ_")
        or n:find("^LT_") or n:find("^SB_") or n:find("^RP_") or n:find("LootTimer")
        or n:find("SirusQuest") or n:find("WorldFrame") then
        return true
    end
    return false
end

local function FrameHasHealthBar(f, depth)
    if not f or depth > 4 then return false end
    for i = 1, f:GetNumChildren() do
        local child = select(i, f:GetChildren())
        if child then
            if child:GetObjectType() == "StatusBar" and child:IsShown() then
                return true
            end
            if FrameHasHealthBar(child, depth + 1) then
                return true
            end
        end
    end
    return false
end

local function IsPlateFrame(f)
    if not f or not f.IsVisible or IsExcludedFrame(f) then return false end
    if f.IsForbidden and f:IsForbidden() then return false end
    if not FrameHasHealthBar(f, 0) then return false end

    local fname = f:GetName()
    if not fname then return true end

    if fname:find("NamePlate") or fname:find("namePlate") or fname:find("Plate")
        or fname:find("Compact") or fname:find("Health") or fname:find("Sirus") then
        return true
    end

    for i = 1, f:GetNumRegions() do
        local r = select(i, f:GetRegions())
        if r and r:GetObjectType() == "FontString" and r:IsShown() then
            local t = r:GetText()
            if t and t ~= "" and not t:match("^%d+$") and not t:match("^<%s*.-%s*>$") and #t < 28 then
                return true
            end
        end
    end

    return false
end

local function GetNameRegion(f)
    if f.gpNameRegion and f.gpNameRegion.GetText then return f.gpNameRegion end

    local best, bestLen = nil, 999

    local function scan(frame, depth)
        if depth > 4 then return end
        for i = 1, frame:GetNumRegions() do
            local r = select(i, frame:GetRegions())
            if r and r:GetObjectType() == "FontString" and r:IsShown() then
                local t = r:GetText()
                if t and t ~= "" and not t:match("^%d+$") and not t:match("^<%s*.-%s*>$") then
                    local len = #t
                    if len < bestLen and len < 28 then
                        best = r
                        bestLen = len
                    end
                end
            end
        end
        for i = 1, frame:GetNumChildren() do
            local child = select(i, frame:GetChildren())
            if child and child.GetNumRegions then
                scan(child, depth + 1)
            end
        end
    end

    scan(f, 0)
    if best then f.gpNameRegion = best end
    return best
end

local RAID_MARK_TEXTURE_HINTS = {
    "RaidTargeting", "raidtargeting", "RAIDTARGETICON", "RaidTarget", "RaidIcon",
}

local function IsRaidMarkTexture(tex)
    if not tex then return false end
    local path = type(tex) == "string" and tex or tostring(tex)
    for _, hint in ipairs(RAID_MARK_TEXTURE_HINTS) do
        if path:find(hint) then return true end
    end
    return false
end

local function IsRaidMarkFrame(frame)
    if not frame or not frame.GetName then return false end
    local n = frame:GetName()
    if not n then return false end
    n = n:lower()
    return (n:find("raid") and (n:find("icon") or n:find("target") or n:find("mark")))
        or n:find("targetingicon")
end

local function GetRaidIconAnchor(f)
    local nameRegion = GetNameRegion(f)
    if nameRegion then return nameRegion, "TOP" end
    return f, "TOP"
end

local function ApplyRaidIconSize(target, size)
    if target.SetSize then
        target:SetSize(size, size)
    end
    if target.SetWidth and target.SetHeight then
        target:SetWidth(size)
        target:SetHeight(size)
    end
end

local function CollectRaidIcons(f, forceRescan)
    if f.gpRaidIcons and not forceRescan then
        if #f.gpRaidIcons > 0 then return f.gpRaidIcons end
    else
        f.gpRaidIcons = nil
    end

    local icons = {}
    local seen = {}

    local function addIcon(r, wrapper)
        if not r or seen[r] then return end
        seen[r] = true
        table.insert(icons, { texture = r, wrapper = wrapper })
    end

    local function scan(frame, depth)
        if not frame or depth > 7 then return end

        if IsRaidMarkFrame(frame) then
            for i = 1, frame:GetNumRegions() do
                local r = select(i, frame:GetRegions())
                if r and r.GetObjectType and r:GetObjectType() == "Texture" then
                    addIcon(r, frame)
                end
            end
            for i = 1, frame:GetNumChildren() do
                local child = select(i, frame:GetChildren())
                if child and child.GetObjectType and child:GetObjectType() == "Texture" then
                    addIcon(child, frame)
                end
            end
        end

        for i = 1, frame:GetNumRegions() do
            local r = select(i, frame:GetRegions())
            if r and r.GetObjectType and r:GetObjectType() == "Texture" then
                if IsRaidMarkTexture(r:GetTexture()) then
                    local parent = r.GetParent and r:GetParent()
                    addIcon(r, IsRaidMarkFrame(parent) and parent or nil)
                end
            end
        end

        for i = 1, frame:GetNumChildren() do
            local child = select(i, frame:GetChildren())
            if child then scan(child, depth + 1) end
        end
    end

    scan(f, 0)
    f.gpRaidIcons = icons
    return icons
end

local function ApplyRaidIcons(f, forceRescan)
    local size = GuildPlatesSettings.iconSize or 40
    local offset = (GuildPlatesSettings.iconOffset or 25) + 15
    local needRescan = forceRescan
        or f.gpLastIconSize ~= size
        or f.gpLastIconOffset ~= offset
        or not f.gpRaidIcons
        or #f.gpRaidIcons == 0

    local icons = CollectRaidIcons(f, needRescan)
    if #icons == 0 then
        f.gpRaidIcons = nil
        return
    end

    local anchor, anchorPoint = GetRaidIconAnchor(f)
    for _, entry in ipairs(icons) do
        local r = entry.texture
        local wrapper = entry.wrapper
        if wrapper then
            ApplyRaidIconSize(wrapper, size)
        end
        ApplyRaidIconSize(r, size)
        if r.ClearAllPoints then
            r:ClearAllPoints()
            r:SetPoint("BOTTOM", anchor, anchorPoint, 0, offset)
        end
    end

    f.gpLastIconSize = size
    f.gpLastIconOffset = offset
end

local function ForEachRaidIcon(f, callback)
    for _, entry in ipairs(CollectRaidIcons(f)) do
        callback(entry.texture, entry.wrapper)
    end
end

local function UpdatePlateStyle(f, force)
    if not f:IsVisible() then
        if f.gpG then f.gpG:Hide() end
        return
    end

    local nameRegion = GetNameRegion(f)
    local name = nameRegion and nameRegion:GetText()

    if GuildPlatesSettings.enabled then
        if not name or not GuildPlatesDB[name] then
            if f.gpG then f.gpG:Hide() end
            f.gpLastMatched = nil
        end

        if not force and f.gpLastMatched == name and f.gpG and f.gpG:IsVisible() then
            -- гильдия уже отрисована, метки обновим ниже
        else
            local tag = name and GuildPlatesDB[name]
            if tag then
                local rawG = string.match(tag, "<(.+)>")
                local ok, clr = false, ColorList[1]
                local filterKey = rawG and guildFilterLookup[(rawG or ""):lower()]
                if filterKey then
                    ok = true
                    clr = ColorList[GuildColors[filterKey] or 1]
                end
                if ok then
                    if not f.gpG then f.gpG = f:CreateFontString(nil, "OVERLAY") end
                    f.gpG:SetFont("Fonts\\FRIZQT__.TTF", GuildPlatesSettings.gFontSize or 12, "OUTLINE")
                    f.gpG:SetShadowColor(0, 0, 0, 1)
                    f.gpG:SetShadowOffset(2, -2)
                    f.gpG:ClearAllPoints()
                    local anchor = nameRegion or f
                    local anchorPoint = nameRegion and "TOP" or "TOP"
                    f.gpG:SetPoint("BOTTOM", anchor, anchorPoint, GuildPlatesSettings.gX or 0, GuildPlatesSettings.gY or 25)
                    f.gpG:SetText(tag)
                    f.gpG:SetTextColor(clr[1], clr[2], clr[3])
                    f.gpG:Show()
                    f.gpLastMatched = name
                elseif f.gpG then
                    f.gpG:Hide()
                    f.gpLastMatched = nil
                end
            elseif f.gpG then
                f.gpG:Hide()
                f.gpLastMatched = nil
            end
        end
    else
        if f.gpG then f.gpG:Hide() end
        f.gpLastMatched = nil
    end

    ApplyRaidIcons(f, force)
end

local hookedPlates = {}

local function HookPlate(f)
    if not IsPlateFrame(f) or f.gpHooked then return end
    f:HookScript("OnShow", function(self)
        self.gpRaidIcons = nil
        self.gpLastIconSize = nil
        self.gpLastIconOffset = nil
        UpdatePlateStyle(self, true)
    end)
    f:HookScript("OnHide", function(self)
        self.gpLastMatched = nil
        self.gpNameRegion = nil
        self.gpRaidIcons = nil
        self.gpLastIconSize = nil
        self.gpLastIconOffset = nil
        if self.gpG then self.gpG:Hide() end
    end)
    f.gpHooked = true
    hookedPlates[f] = true
    if f:IsVisible() then UpdatePlateStyle(f, true) end
end

local function ScanPlates(parent, depth)
    if not parent or depth > 5 then return end
    local count = parent:GetNumChildren()
    for i = 1, count do
        local child = select(i, parent:GetChildren())
        if child then
            if IsPlateFrame(child) then
                HookPlate(child)
            end
            ScanPlates(child, depth + 1)
        end
    end
end

local function RefreshVisiblePlates()
    local forceRaid = forceRaidRefresh
    forceRaidRefresh = false
    for plate in pairs(hookedPlates) do
        if plate.IsVisible and plate:IsVisible() then
            if forceRaid then
                plate.gpLastIconSize = nil
                plate.gpLastIconOffset = nil
                plate.gpRaidIcons = nil
            end
            UpdatePlateStyle(plate, true)
        end
    end
    platesNeedRefresh = false
    refreshPending = 0
end

local function HookPlates()
    ScanPlates(WorldFrame, 0)
end


-- ============================================================== ИНТЕРФЕЙС ==============================================================
local GuildPlatesUI = {}

local function BuildGuildPlatesPanel(parent)
    local panel = parent
    local PANEL_H = 340
    panel:SetHeight(PANEL_H)

    local function SetFont(obj, role)
        if obj then
            SS:StyleFont(obj, role or "description")
        end
    end

    local function StyleCheckbox(cb, text)
        local label = _G[cb:GetName().."Text"]
        label:SetText(text)
        SetFont(label, "description")
    end

    local function CreateSlider(name, text, min, max, key, anchor, y)
        local s = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
        s:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y)
        s:SetMinMaxValues(min, max)
        s:SetValueStep(1)
        s:SetSize(240, 20)
        if s.SetObeyStepOnDrag then
            s:SetObeyStepOnDrag(true)
        end
        local label = _G[s:GetName().."Text"]
        local function ApplyValue(v)
            v = math.floor(v + 0.5)
            GuildPlatesSettings[key] = v
            label:SetText(text..": "..v)
            if key == "iconSize" or key == "iconOffset" then
                RequestPlateRefresh(true)
            else
                RequestPlateRefresh()
            end
        end
        s:SetScript("OnValueChanged", function(self, v)
            ApplyValue(v)
        end)
        SS:StyleFont(label, "description")
        ApplyValue(GuildPlatesSettings[key] or min)
        s:SetValue(GuildPlatesSettings[key] or min)
        return s
    end

    local cb = CreateFrame("CheckButton", "GP_EnabledCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    StyleCheckbox(cb, "Отображать гильдии над ником")
    cb:SetScript("OnClick", function(self)
        GuildPlatesSettings.enabled = SettingEnabled(self:GetChecked())
        RequestPlateRefresh()
    end)

    local cbChat = CreateFrame("CheckButton", "GP_ChatCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    cbChat:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 0, -4)
    StyleCheckbox(cbChat, "Оповещения в чат")
    cbChat:SetScript("OnClick", function(self)
        GuildPlatesSettings.showSyncChat = SettingEnabled(self:GetChecked())
    end)

    local sGX = CreateSlider("GP_GX", "Смещение гильдии X", -150, 150, "gX", cbChat, -24)
    local sGY = CreateSlider("GP_GY", "Смещение гильдии Y", -100, 150, "gY", sGX, -40)
    local sGFont = CreateSlider("GP_GFont", "Размер шрифта на нике", 8, 30, "gFontSize", sGY, -40)

    local filterLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    filterLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 320, 4)
    filterLabel:SetText("Фильтр гильдий:")
    SetFont(filterLabel, "header")

    local eb = CreateFrame("EditBox", "GP_AddEditBox", panel, "InputBoxTemplate")
    eb:SetSize(180, 28)
    eb:SetPoint("TOPLEFT", filterLabel, "BOTTOMLEFT", 0, -8)
    eb:SetAutoFocus(false)
    SetFont(eb, "description")

    local btnAdd = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnAdd:SetSize(95, 26)
    btnAdd:SetPoint("TOPLEFT", eb, "BOTTOMLEFT", 0, -6)
    btnAdd:SetText("Добавить")
    SetFont(btnAdd:GetFontString(), "description")

    local btnRem = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnRem:SetSize(95, 26)
    btnRem:SetPoint("LEFT", btnAdd, "RIGHT", 6, 0)
    btnRem:SetText("Удалить")
    SetFont(btnRem:GetFontString(), "description")

    local scrollFrame = CreateFrame("ScrollFrame", "GP_Scroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(280, 150)
    scrollFrame:SetPoint("TOPLEFT", btnAdd, "BOTTOMLEFT", 0, -8)
    scrollFrame:EnableMouse(true)
    scrollFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {4, 4, 4, 4},
    })
    scrollFrame:SetBackdropColor(0, 0, 0, 0.7)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(270, 1)
    content:EnableMouse(false)
    scrollFrame:SetScrollChild(content)
    local buttons = {}

    local LIST_ROW_STEP = 28
    local LIST_ROW_PAD = 5
    local LIST_BTN_H = 26
    local filterControlsLevel = panel:GetFrameLevel() + 30

    eb:SetFrameLevel(filterControlsLevel)
    btnAdd:SetFrameLevel(filterControlsLevel)
    btnRem:SetFrameLevel(filterControlsLevel)

    local function UpdateListButtonMouse()
        local scroll = scrollFrame:GetVerticalScroll() or 0
        local viewH = scrollFrame:GetHeight() or 150
        local visibleTop = scroll
        local visibleBottom = scroll + viewH

        for idx, btn in ipairs(buttons) do
            if btn:IsShown() then
                local btnTop = (idx - 1) * LIST_ROW_STEP + LIST_ROW_PAD
                local btnBottom = btnTop + LIST_BTN_H
                local inView = btnBottom > visibleTop and btnTop < visibleBottom
                btn:EnableMouse(inView)
            else
                btn:EnableMouse(false)
            end
        end
    end

    local function RefreshGuildFilterScroll()
        local h = content:GetHeight() or 30
        content:SetHeight(h)
        scrollFrame:SetVerticalScroll(0)
        local cur = scrollFrame:GetVerticalScroll()
        scrollFrame:SetVerticalScroll(cur + 1)
        scrollFrame:SetVerticalScroll(cur)
        UpdateListButtonMouse()
    end

    local function UpdateList()
        for _, b in ipairs(buttons) do b:Hide() end
        local i, sorted = 0, {}
        for g in pairs(GuildFilter) do table.insert(sorted, g) end
        table.sort(sorted)
        for _, gName in ipairs(sorted) do
            i = i + 1
            if not buttons[i] then
                buttons[i] = CreateFrame("Button", nil, content)
                buttons[i]:SetSize(260, 26)
                buttons[i]:SetFrameLevel(scrollFrame:GetFrameLevel() + 1)
                local label = buttons[i]:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                buttons[i]:SetFontString(label)
                label:SetPoint("LEFT", 4, 0)
                label:SetJustifyH("LEFT")
                buttons[i]:SetScript("OnClick", function(self, btn)
                    if btn == "LeftButton" then
                        eb:SetText(self.g)
                    else
                        local cur = GuildColors[self.g] or 1
                        GuildColors[self.g] = (cur >= #ColorList) and 1 or (cur + 1)
                        SyncGuildFilterToDB()
                        UpdateList()
                        RequestPlateRefresh()
                    end
                end)
                buttons[i]:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            end
            buttons[i]:SetPoint("TOPLEFT", 5, -(i - 1) * 28 - 5)
            buttons[i].g = gName
            local clr = ColorList[GuildColors[gName] or 1]
            buttons[i]:SetText("- "..gName)
            local fs = buttons[i]:GetFontString()
            if fs then
                SetFont(fs, "description")
                fs:SetShadowColor(0, 0, 0, 1)
                fs:SetShadowOffset(1, -1)
                fs:SetTextColor(clr[1], clr[2], clr[3])
            end
            buttons[i]:Show()
        end
        content:SetHeight(math.max(30, i * 28 + 10))
        RefreshGuildFilterScroll()
        UpdateListButtonMouse()
    end

    scrollFrame:SetScript("OnVerticalScroll", function()
        UpdateListButtonMouse()
    end)

    local scrollBar = _G[scrollFrame:GetName().."ScrollBar"]
    if scrollBar and scrollBar.HookScript then
        scrollBar:HookScript("OnValueChanged", function()
            UpdateListButtonMouse()
        end)
    end

    local function RequestListRefresh()
        UpdateList()
        UpdateListButtonMouse()
    end

    local function AddGuild()
        local v = eb:GetText()
        if v and v ~= "" then
            GuildFilter[v] = true
            GuildColors[v] = 1
            RebuildGuildFilterLookup()
            eb:SetText("")
            SyncGuildFilterToDB()
            UpdateList()
            RequestPlateRefresh()
        end
    end

    local function RemoveGuild()
        local v = eb:GetText()
        if v and v ~= "" then
            GuildFilter[v] = nil
            GuildColors[v] = nil
            RebuildGuildFilterLookup()
            SyncGuildFilterToDB()
            UpdateList()
            RequestPlateRefresh()
        end
    end

    btnAdd:SetScript("OnClick", AddGuild)
    btnRem:SetScript("OnClick", RemoveGuild)
    eb:SetScript("OnEnterPressed", function(self)
        AddGuild()
        self:ClearFocus()
    end)

    GuildPlatesUI.UpdateList = UpdateList
    GuildPlatesUI.scrollFrame = scrollFrame
    GuildPlatesUI.scrollContent = content

    panel:SetScript("OnShow", RequestListRefresh)

    local listRefreshFrame = CreateFrame("Frame")
    listRefreshFrame:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        RequestListRefresh()
    end)

    local btnClean = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnClean:SetSize(100, 22)
    btnClean:SetPoint("TOPLEFT", sGFont, "BOTTOMLEFT", 0, -28)
    btnClean:SetText("Очистить базу")
    SetFont(btnClean:GetFontString(), "description")
    btnClean:SetScript("OnClick", function()
        GuildPlatesDB = {}
        UpdateList()
        RequestPlateRefresh()
    end)

    local btnSync = CreateFrame("Button", "GP_SyncButton", panel, "UIPanelButtonTemplate")
    btnSync:SetSize(105, 22)
    btnSync:SetPoint("LEFT", btnClean, "RIGHT", 8, 0)
    btnSync:SetText("Синхронизация")
    SetFont(btnSync:GetFontString(), "description")
    btnSync:SetScript("OnClick", function(self)
        if frame.lockTimer > 0 then return end
        if RequestData then RequestData() end
        if ShareFullDB then ShareFullDB() end
        frame.lockTimer = 30
        self:Disable()
        if GuildPlatesSettings.showSyncChat then
            DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00GP:|r Запрос и отправка базы...")
        end
    end)

    GuildPlatesUI.btnSync = btnSync
    GuildPlatesUI.cb = cb
    GuildPlatesUI.cbChat = cbChat

    GuildPlatesUI.refresh = function()
        cb:SetChecked(GuildPlatesSettings.enabled)
        cbChat:SetChecked(GuildPlatesSettings.showSyncChat)
        sGX:SetValue(GuildPlatesSettings.gX)
        sGY:SetValue(GuildPlatesSettings.gY)
        sGFont:SetValue(GuildPlatesSettings.gFontSize)
        if frame.lockTimer > 0 then
            btnSync:Disable()
        else
            btnSync:Enable()
            btnSync:SetText("Синхронизация")
        end
        UpdateList()
    end

    GuildPlatesUI.GetPanelHeight = function()
        return PANEL_H
    end

    UpdateList()
    GuildPlatesUI.refresh()
end

local function BuildRaidMarksPanel(parent)
    parent:SetHeight(130)

    local function SetFont(obj, role)
        if obj then
            SS:StyleFont(obj, role or "description")
        end
    end

    local function CreateSlider(name, text, min, max, key, anchor, y)
        local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
        s:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y)
        s:SetMinMaxValues(min, max)
        s:SetValueStep(1)
        s:SetSize(240, 20)
        if s.SetObeyStepOnDrag then
            s:SetObeyStepOnDrag(true)
        end
        local label = _G[s:GetName().."Text"]
        local function ApplyValue(v)
            v = math.floor(v + 0.5)
            GuildPlatesSettings[key] = v
            label:SetText(text..": "..v)
            if key == "iconSize" or key == "iconOffset" then
                RequestPlateRefresh(true)
            else
                RequestPlateRefresh()
            end
        end
        s:SetScript("OnValueChanged", function(self, v)
            ApplyValue(v)
        end)
        SS:StyleFont(label, "description")
        ApplyValue(GuildPlatesSettings[key] or min)
        s:SetValue(GuildPlatesSettings[key] or min)
        return s
    end

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 0, 0)
    hint:SetText("Настройки иконок рейда на nameplate.")
    SetFont(hint, "description")

    local sSize = CreateSlider("GP_IconSize", "Размер меток", 40, 150, "iconSize", hint, -20)
    local sOff = CreateSlider("GP_IconOff", "Высота меток", -150, 100, "iconOffset", sSize, -40)

    local bottomSpacer = parent:CreateFontString(nil, "OVERLAY")
    bottomSpacer:SetPoint("TOPLEFT", sOff, "BOTTOMLEFT", 0, -8)
    bottomSpacer:SetHeight(8)

    GuildPlatesUI.raidRefresh = function()
        sSize:SetValue(GuildPlatesSettings.iconSize)
        sOff:SetValue(GuildPlatesSettings.iconOffset)
    end
end

HH1TC:RegisterModule("indicators", "guildplates", {
    title = "GuildPlates",
    order = 1,
    estimatedHeight = 340,
    BuildPanel = BuildGuildPlatesPanel,
    GetPanelHeight = function()
        return GuildPlatesUI.GetPanelHeight and GuildPlatesUI.GetPanelHeight() or 340
    end,
    OnShow = function()
        if GuildPlatesUI.UpdateList then GuildPlatesUI.UpdateList() end
        if GuildPlatesUI.refresh then GuildPlatesUI.refresh() end
    end,
    refresh = function()
        if GuildPlatesUI.refresh then GuildPlatesUI.refresh() end
    end,
})

HH1TC:RegisterModule("indicators", "raidmarks", {
    title = "Метки рейда",
    order = 2,
    estimatedHeight = 130,
    BuildPanel = BuildRaidMarksPanel,
    OnShow = function()
        if GuildPlatesUI.raidRefresh then GuildPlatesUI.raidRefresh() end
    end,
    refresh = function()
        if GuildPlatesUI.raidRefresh then GuildPlatesUI.raidRefresh() end
    end,
})

-- ===================================================================================================================

frame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)
    if event == "ADDON_LOADED" and arg1 == "hh1tc" then
        NormalizeGuildPlatesSettings()
        RestoreGuildFilterFromDB()
        NormalizeGuildFilter()
        RebuildGuildFilterLookup()
        SyncGuildFilterToDB()
        HookPlates()
        RequestPlateRefresh()
        if GuildPlatesUI.UpdateList then
            GuildPlatesUI.UpdateList()
        end
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, msg, channel, sender = arg1, arg2, arg3, arg4
        if prefix == "GP_SYNC" then
            HandleSyncMessage(msg, channel, sender)
        end
    elseif event == "RAID_TARGET_UPDATE" then
        for plate in pairs(hookedPlates) do
            if plate.IsVisible and plate:IsVisible() then
                plate.gpRaidIcons = nil
                plate.gpLastIconSize = nil
                plate.gpLastIconOffset = nil
                ApplyRaidIcons(plate, true)
            end
        end
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        if UnitIsPlayer("mouseover") then
            local n, g = UnitName("mouseover"), GetGuildInfo("mouseover")
            if n then
                local match = false
                if g and g ~= "" and guildFilterLookup[g:lower()] then
                    match = true
                    GuildPlatesDB[n] = "<"..g..">"
                end
                
                if not match and GuildPlatesDB[n] then
                    GuildPlatesDB[n] = nil
                    RequestPlateRefresh()
                elseif match then
                    RequestPlateRefresh()
                end
            end
        end
    end
end)

collectgarbage("setpause", 110); collectgarbage("setstepmul", 200)
frame.lockTimer = 0

frame:SetScript("OnUpdate", function(self, elapsed)
    -- collectgarbage("step", 2)
    
    if self.lockTimer and self.lockTimer > 0 then
        self.lockTimer = self.lockTimer - elapsed
        if self.lockTimer <= 0 then 
            self.lockTimer = 0 
        end
        
        if GuildPlatesUI.btnSync and GuildPlatesUI.btnSync:IsVisible() then
            if self.lockTimer > 0 then
                GuildPlatesUI.btnSync:SetText(string.format("Ждите: %d", math.ceil(self.lockTimer)))
                if GuildPlatesUI.btnSync:IsEnabled() then GuildPlatesUI.btnSync:Disable() end
            else
                GuildPlatesUI.btnSync:Enable()
                GuildPlatesUI.btnSync:SetText("Синхронизация")
            end
        end
    elseif GuildPlatesUI.btnSync and GuildPlatesUI.btnSync:IsVisible() and not GuildPlatesUI.btnSync:IsEnabled() then
        GuildPlatesUI.btnSync:Enable()
        GuildPlatesUI.btnSync:SetText("Синхронизация")
    end

    if #sendQueue > 0 then
        sendTimer = sendTimer + elapsed
        if sendTimer > 1 then 
            local d = table.remove(sendQueue, 1)
            if d and d.n then
                SendAddonMessage("GP_SYNC", d.n .. ":" .. d.t, d.c)
            end
            sendTimer = 0 
        end
    end

    syncTimerTotal = syncTimerTotal + elapsed
    if syncTimerTotal > 4 then
        HookPlates()

        if syncCounter > 0 and GuildPlatesSettings.showSyncChat then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00GP:|r + "..syncCounter.." новых записей от "..lastSenderName)
            syncCounter = 0
        end
        syncTimerTotal = 0
    end

    if platesNeedRefresh then
        refreshPending = refreshPending + elapsed
        if refreshPending >= 0.25 then
            RefreshVisiblePlates()
        end
    elseif GuildPlatesSettings.enabled then
        refreshTimer = (refreshTimer or 0) + elapsed
        if refreshTimer > 1.0 then
            RefreshVisiblePlates()
            refreshTimer = 0
        end
    else
        raidRefreshTimer = (raidRefreshTimer or 0) + elapsed
        if raidRefreshTimer > 0.75 then
            for plate in pairs(hookedPlates) do
                if plate.IsVisible and plate:IsVisible() then
                    ApplyRaidIcons(plate, true)
                end
            end
            raidRefreshTimer = 0
        end
    end
end)


SLASH_GUILDPLATES1 = "/gp"
SlashCmdList["GUILDPLATES"] = function(msg)
    if msg and msg:lower() == "debug" then
        local found = 0
        local function scan(parent, depth)
            if not parent or depth > 5 then return end
            for i = 1, parent:GetNumChildren() do
                local child = select(i, parent:GetChildren())
                if child and IsPlateFrame(child) then
                    found = found + 1
                    local n = GetNameRegion(child)
                    print(string.format("|cff00ff00[GP]|r #%d name=%s frame=%s hooked=%s",
                        found, (n and n:GetText()) or "?", child:GetName() or "<anon>", tostring(child.gpHooked)))
                    local raidIcons = CollectRaidIcons(child, true)
                    if #raidIcons > 0 then
                        for j, entry in ipairs(raidIcons) do
                            local tex = entry.texture:GetTexture()
                            print(string.format("  raid #%d tex=%s wrapper=%s", j, tostring(tex),
                                (entry.wrapper and entry.wrapper:GetName()) or "nil"))
                        end
                    end
                end
                if child then scan(child, depth + 1) end
            end
        end
        scan(WorldFrame, 0)
        print("|cff00ff00[GP]|r Найдено nameplate-фреймов: "..found)
        return
    end
    HH1TC:Open("indicators")
end

