local PREFIX = "SRC_DATA"
local playersStatus = {}
local isInvited = false

local frame = CreateFrame("Frame", "SRC_MainFrame", UIParent)
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
frame:RegisterEvent("RAID_ROSTER_UPDATE")
frame:RegisterEvent("BATTLEFIELD_MGR_QUEUE_INVITE")
frame:RegisterEvent("BATTLEFIELD_MGR_EJECTED")
frame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, msg, channel, sender = ...
        if prefix ~= PREFIX then return end
        sender = string.gsub(sender, "%-.+", "")
        if string.find(msg, "STAT:") then
            playersStatus[sender] = string.sub(msg, 6)
            if SRC_UpdateList then SRC_UpdateList() end
        end
    elseif event == "BATTLEFIELD_MGR_QUEUE_INVITE" then
        isInvited = true
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        isInvited = false
    end
end)

local lastUpdate = 0
frame:SetScript("OnUpdate", function(self, elapsed)
    lastUpdate = lastUpdate + elapsed
    if lastUpdate > 1.5 then
        local inQueue = "НЕТ"

        for i = 1, 10 do
            local status = GetBattlefieldStatus(i)
            if status == "active" then inQueue = "БОЙ" break
            elseif status == "confirm" then inQueue = "ПРИНЯТЬ!" break
            elseif status == "queued" then inQueue = "В РЕГЕ" end
        end

        if isInvited and inQueue ~= "БОЙ" then inQueue = "ПРИНЯТЬ!" end

        local isInstance, instanceType = IsInInstance()
        if isInstance and (instanceType == "pvp" or instanceType == "arena") then
            inQueue = "БОЙ"
        end

        local numRaid = GetNumRaidMembers()
        local numParty = GetNumPartyMembers()
        local chan = (numRaid > 0) and "RAID" or (numParty > 0 and "PARTY")

        if chan then
            SendAddonMessage(PREFIX, "STAT:"..inQueue, chan)
        else
            playersStatus[UnitName("player")] = inQueue
            if SRC_UpdateList then SRC_UpdateList() end
        end
        lastUpdate = 0
    end
end)

local playerListText

function SRC_UpdateList()
    if not playerListText then return end

    local text = ""
    local numRaid = GetNumRaidMembers()
    local total = numRaid > 0 and numRaid or GetNumPartyMembers()

    if total > 0 then
        for i = 1, total do
            local name = (numRaid > 0) and GetRaidRosterInfo(i) or UnitName("party"..i)
            if name then
                local status = playersStatus[name] or "???"
                local color = "|cffff0000"
                if status == "В РЕГЕ" then color = "|cff00ff00"
                elseif status == "ПРИНЯТЬ!" then color = "|cffffff00"
                elseif status == "БОЙ" then color = "|cff00ffff" end
                text = text .. name .. ": " .. color .. status .. "|r\n"
            end
        end
    else
        local myName = UnitName("player")
        local status = playersStatus[myName] or "НЕТ"
        local color = (status == "В РЕГЕ") and "|cff00ff00"
            or (status == "БОЙ" and "|cff00ffff"
            or (status == "ПРИНЯТЬ!" and "|cffffff00" or "|cffff0000"))
        text = "|cff888888(Соло тест)|r\n" .. myName .. ": " .. color .. status .. "|r"
    end
    playerListText:SetText(text)
end

local function BuildRegControlPanel(parent)
    parent:SetHeight(220)

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hint:SetPoint("TOPLEFT", 0, 0)
    HH1TC:StyleFont(hint, "description")
    hint:SetText("Статус регистрации на БГ/арену в группе или рейде:")

    local scrollFrame = CreateFrame("ScrollFrame", "SRC_Scroll", parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(420, 180)
    scrollFrame:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8)
    scrollFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    scrollFrame:SetBackdropColor(0, 0, 0, 0.5)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(400, 1)
    scrollFrame:SetScrollChild(content)

    playerListText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    playerListText:SetPoint("TOPLEFT", 8, -8)
    playerListText:SetWidth(380)
    playerListText:SetJustifyH("LEFT")
    playerListText:SetSpacing(4)
    HH1TC:StyleFont(playerListText, "description")

    SRC_UpdateList()
end

HH1TC:RegisterModule("other", "sirusregcontrol", {
    title = "Регистрация на БГ",
    order = 6,
    estimatedHeight = 220,
    BuildPanel = BuildRegControlPanel,
    OnShow = function()
        SRC_UpdateList()
    end,
})

SLASH_SRCC1 = "/src"
SlashCmdList["SRCC"] = function()
    HH1TC:Open("other", "sirusregcontrol")
end
