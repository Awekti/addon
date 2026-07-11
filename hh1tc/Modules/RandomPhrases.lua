local defaultData = {
    currentCategory = "Цитаты",
    categories = {
        ["Цитаты"] = {
            "Виноваты, конечно, всегда другие…",
            "Воздух не чувствуется пока его не испортят.",
            "Никто не идеален. Даже у рыб бывают косяки.",
            "Тепло, уютно. Мне нравится",
            "Нет смысла нервничать по поводу того, чем ты не в силах управлять",
            "Вы посредственный игрок, мистер.",
            "А это ты грамотно придумал!",
            "Всё, что достаётся с трудом, ценится сильнее.",
            "Закрыл ладошками глаза и стал невидим. Отдыхаю.",
            "Твои действия - это твой выбор.",
            "Ничто хорошее не вечно.",
            "При желании, способ всегда найдётся",
            "Каждый верит в то, что он видит.",
            "Чем больше людей - тем выше шанс предательства.",
            "Мнения не становятся правильными только от того, что с ними многие согласны.",
            "Сначала потом, затем, снова опять",
            "Немой фигни не скажет",
            "Главное чтобы мы оставались мыми",
            "Если план 'А' не сработал, в алфавите еще полно букв.",
            "Не спеши, а то успеешь.",
            "Если всё время работать и не отдыхать, можно стать самым богатым покойником на кладбище.",
            "Никогда не спорьте с дураками, они опустят вас до своего уровня и задавят опытом.",
        },
        ["Игровое"] = {
            "Меньше целей - проще хилить.",
            "Дайте денег.",
            "Наткнулся на груду костей. Не удержался и сплясал.",
            "Тактика для слабаков, интуиция — для героев.",
            "Я не туплю, я анализирую ситуацию под необычным углом.",
            "В любой непонятной ситуации обвиняй лаги.",
            "Я не промахнулся, я напугал землю.",
            "Лужа сама себя не выстоит!",
        },
        ["Юмор"] = {
            "Буря мглою небо кроет, i'm sexy and i know it",
            "Здорово на кухне спать. Холодильник рядом.",
            "Очень привет!",
            "Отличная погода для хвоста.",
            "Немой фигни не скажет",
            "Жуй можжевельник, надувай лягушек, размышляй о смысле жизни.",
            "Мухоморы опасны!",
        },
    },
}

local RandomPhrasesUI = {}

local function InitDB()
    if not RandomPhrasesDB then
        RandomPhrasesDB = defaultData
    elseif not RandomPhrasesDB.categories then
        RandomPhrasesDB.categories = defaultData.categories
    end
end

local function SayRandomPhrase()
    local list = {}
    if RandomPhrasesDB.currentCategory == "ALL" then
        for _, phrases in pairs(RandomPhrasesDB.categories) do
            for _, phrase in ipairs(phrases) do
                table.insert(list, phrase)
            end
        end
    else
        list = RandomPhrasesDB.categories[RandomPhrasesDB.currentCategory]
    end
    if list and #list > 0 then
        SendChatMessage(list[math.random(#list)], "SAY")
    end
end

local menuFrame = CreateFrame("Frame", "RP_MenuFrame", UIParent, "UIDropDownMenuTemplate")

local function InitializeMenu(self, level)
    if not RandomPhrasesDB or not RandomPhrasesDB.categories then return end
    local info = UIDropDownMenu_CreateInfo()

    info.text = "|cFFFFFF00[Случайная из всех]|r"
    info.checked = (RandomPhrasesDB.currentCategory == "ALL")
    info.func = function()
        RandomPhrasesDB.currentCategory = "ALL"
        if RandomPhrasesUI.refresh then RandomPhrasesUI.refresh() end
    end
    UIDropDownMenu_AddButton(info)

    local cats = {}
    for k in pairs(RandomPhrasesDB.categories) do table.insert(cats, k) end
    table.sort(cats)

    for _, catName in ipairs(cats) do
        info.text = catName
        info.checked = (RandomPhrasesDB.currentCategory == catName)
        info.func = function()
            RandomPhrasesDB.currentCategory = catName
            if RandomPhrasesUI.refresh then RandomPhrasesUI.refresh() end
        end
        UIDropDownMenu_AddButton(info)
    end
end

StaticPopupDialogs["ADD_PHRASE_CATEGORY"] = {
    text = "Добавить в [%s]:",
    button1 = "Ок",
    button2 = "Отмена",
    hasEditBox = true,
    OnShow = function(self)
        self.text:SetFormattedText("Добавить в [%s]:", RandomPhrasesDB.currentCategory)
    end,
    OnAccept = function(self)
        local t = self.editBox:GetText()
        if t and t ~= "" and RandomPhrasesDB.currentCategory ~= "ALL" then
            table.insert(RandomPhrasesDB.categories[RandomPhrasesDB.currentCategory], t)
            if RandomPhrasesUI.refresh then RandomPhrasesUI.refresh() end
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

    parent:SetHeight(200)

    local catLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    catLabel:SetPoint("TOPLEFT", 0, 0)
    HH1TC:StyleFont(catLabel, "description")
    catLabel:SetText("Категория:")

    local catBtn = CreateFrame("Button", "RP_CategoryBtn", parent, "UIPanelButtonTemplate")
    catBtn:SetSize(160, 24)
    catBtn:SetPoint("LEFT", catLabel, "RIGHT", 10, 0)
    catBtn:SetText(RandomPhrasesDB.currentCategory or "Цитаты")
    catBtn:SetScript("OnClick", function()
        UIDropDownMenu_Initialize(menuFrame, InitializeMenu, "MENU")
        ToggleDropDownMenu(1, nil, menuFrame, catBtn, 0, 0)
    end)

    local sayBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    sayBtn:SetSize(120, 28)
    sayBtn:SetPoint("TOPLEFT", catLabel, "BOTTOMLEFT", 0, -12)
    sayBtn:SetText("Сказать фразу")
    sayBtn:SetScript("OnClick", SayRandomPhrase)

    local addBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    addBtn:SetSize(120, 28)
    addBtn:SetPoint("LEFT", sayBtn, "RIGHT", 8, 0)
    addBtn:SetText("Добавить фразу")
    addBtn:SetScript("OnClick", function()
        if RandomPhrasesDB.currentCategory == "ALL" then
            UIErrorsFrame:AddMessage("Сначала выберите категорию!", 1, 0, 0)
        else
            StaticPopup_Show("ADD_PHRASE_CATEGORY")
        end
    end)

    local listLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    listLabel:SetPoint("TOPLEFT", sayBtn, "BOTTOMLEFT", 0, -12)
    listLabel:SetWidth(440)
    listLabel:SetJustifyH("LEFT")
    listLabel:SetNonSpaceWrap(false)
    HH1TC:StyleFont(listLabel, "description")

    local function UpdatePhraseList()
        local text = ""
        if RandomPhrasesDB.currentCategory == "ALL" then
            text = "Режим: случайная фраза из всех категорий"
        else
            local phrases = RandomPhrasesDB.categories[RandomPhrasesDB.currentCategory]
            if phrases then
                for i, phrase in ipairs(phrases) do
                    if i <= 5 then
                        text = text .. "- " .. phrase .. "\n"
                    end
                end
                if #phrases > 5 then
                    text = text .. "... ещё " .. (#phrases - 5) .. " фраз"
                end
            end
        end
        listLabel:SetText(text)
        catBtn:SetText(RandomPhrasesDB.currentCategory or "Цитаты")
    end

    RandomPhrasesUI.refresh = UpdatePhraseList
    UpdatePhraseList()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    InitDB()
end)

HH1TC:RegisterModule("other", "randomphrases", {
    title = "RandomPhrases",
    order = 4,
    estimatedHeight = 200,
    BuildPanel = BuildRandomPhrasesPanel,
    OnShow = function()
        if RandomPhrasesUI.refresh then RandomPhrasesUI.refresh() end
    end,
})
