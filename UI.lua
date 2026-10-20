local _, PTG = ...

local function label(parent, font, width)
    local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    if width then text:SetWidth(width) end
    return text
end

local function button(parent, width, callback)
    local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    control:SetSize(width, 24)
    control:SetScript("OnClick", callback)
    return control
end

local function panel(name, width, height)
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    local drag = CreateFrame("Frame", nil, frame)
    drag:SetPoint("TOPLEFT", 8, -5)
    drag:SetPoint("TOPRIGHT", -8, -5)
    drag:SetHeight(25)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() frame:StartMoving() end)
    drag:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        if frame == PTG.ui then
            local x, y = frame:GetCenter()
            local parentX, parentY = UIParent:GetCenter()
            PTG.db.position = { point = "CENTER", x = x - parentX, y = y - parentY }
        end
    end)
    frame.title = label(drag, "GameFontNormalLarge", width - 40)
    frame.title:SetPoint("TOPLEFT", 7, -4)
    return frame
end

local function check(parent, callback)
    local control = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    control:SetSize(24, 24)
    control.text = label(control, "GameFontHighlightSmall", 302)
    control.text:SetPoint("LEFT", control, "RIGHT", 2, 0)
    control:SetScript("OnClick", callback)
    return control
end

local function age(seconds)
    seconds = tonumber(seconds)
    if not seconds then return PTG:L("unknown_age") end
    seconds = math.floor(math.max(0, seconds))
    return PTG:L("age", math.floor(seconds / 60), seconds % 60)
end

local function changed()
    PTG:SettingsChanged()
    PTG:RefreshUI()
end

local function buildSettings()
    local settings = panel("PressToGroupSettings", 400, 550)
    settings:SetPoint("CENTER", UIParent, "CENTER", 375, 0)
    settings:Hide()
    PTG.settingsUI = settings
    tinsert(UISpecialFrames, "PressToGroupSettings")
    settings.close = button(settings, 100, function() settings:Hide() end)
    settings.close:SetPoint("BOTTOM", 0, 13)

    local scroll = CreateFrame("ScrollFrame", "PressToGroupSettingsScroll", settings, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -40)
    scroll:SetPoint("BOTTOMRIGHT", -35, 46)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(345, 1)
    scroll:SetScrollChild(content)
    settings.content = content
    settings.localeLabel = label(content, "GameFontNormal", 335)
    settings.localeButtons = {}
    for i, locale in ipairs({ "auto", "ruRU", "enUS" }) do
        local choice = button(content, 108, function()
            PTG.db.locale = locale
            changed()
        end)
        choice.locale = locale
        settings.localeButtons[i] = choice
    end
    settings.roleLabel = label(content, "GameFontNormal", 335)
    settings.roleButtons = {}
    for i, role in ipairs({ "TANK", "HEALER", "DAMAGER" }) do
        local choice = button(content, 108, function()
            PTG.db.role = role
            changed()
        end)
        choice.role = role
        settings.roleButtons[i] = choice
    end
    settings.ratingLabel = label(content, "GameFontHighlightSmall", 245)
    settings.rating = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    settings.rating:SetSize(70, 24)
    settings.rating:SetAutoFocus(false)
    settings.rating:SetNumeric(true)
    settings.rating:SetMaxLetters(5)
    settings.rating:SetScript("OnEnterPressed", function(edit) edit:ClearFocus() end)
    settings.rating:SetScript("OnEscapePressed", function(edit)
        edit:SetNumber(PTG.db.minRating)
        edit:ClearFocus()
    end)
    settings.rating:SetScript("OnEditFocusLost", function(edit)
        local value = math.max(0, math.floor(tonumber(edit:GetText()) or 0))
        edit:SetNumber(value)
        if PTG.db.minRating ~= value then
            PTG.db.minRating = value
            changed()
        end
    end)
    settings.compositionLabel = label(content, "GameFontNormal", 335)
    settings.compositionChecks = {}
    for i, item in ipairs({
        { "requireTank", "require_tank" }, { "requireLust", "require_lust" }, { "requireBrez", "require_brez" },
    }) do
        local control = check(content, function(widget)
            PTG.db[item[1]] = widget:GetChecked() == true
            changed()
        end)
        control.setting, control.key = item[1], item[2]
        settings.compositionChecks[i] = control
    end
    settings.compositionHint = label(content, "GameFontDisableSmall", 335)
    settings.dungeonLabel = label(content, "GameFontNormal", 260)
    settings.allDungeons = button(content, 65, function()
        wipe(PTG.db.dungeons)
        changed()
    end)
    settings.dungeonHint = label(content, "GameFontDisableSmall", 335)
    settings.dungeonEmpty = label(content, "GameFontDisableSmall", 335)
    settings.dungeonChecks = {}
    settings.languageLabel = label(content, "GameFontNormal", 335)
    settings.languageHint = label(content, "GameFontDisableSmall", 335)
    settings.languageEmpty = label(content, "GameFontDisableSmall", 335)
    settings.languageChecks = {}

    function settings:Refresh()
        local db, y = PTG.db, -2
        self.title:SetText(PTG:L("settings"))
        self.close:SetText(PTG:L("close"))
        local function place(widget, height, x)
            widget:ClearAllPoints()
            widget:SetPoint("TOPLEFT", content, "TOPLEFT", x or 0, y)
            y = y - height
        end
        self.localeLabel:SetText(PTG:L("interface_language"))
        place(self.localeLabel, 22)
        for i, choice in ipairs(self.localeButtons) do
            choice:ClearAllPoints()
            choice:SetPoint("TOPLEFT", content, "TOPLEFT", (i - 1) * 114, y)
            choice:SetText(choice.locale == "auto" and PTG:L("automatic") or (choice.locale == "ruRU" and "RU" or "EN"))
            choice:SetEnabled((db.locale or "auto") ~= choice.locale)
        end
        y = y - 38
        self.roleLabel:SetText(PTG:L("role"))
        place(self.roleLabel, 22)
        for i, choice in ipairs(self.roleButtons) do
            choice:ClearAllPoints()
            choice:SetPoint("TOPLEFT", content, "TOPLEFT", (i - 1) * 114, y)
            choice:SetText(PTG:L(choice.role))
            choice:SetEnabled(db.role ~= choice.role)
        end
        y = y - 40
        self.ratingLabel:SetText(PTG:L("min_rating"))
        self.rating:ClearAllPoints()
        self.rating:SetPoint("TOPLEFT", content, "TOPLEFT", 267, y + 5)
        if not self.rating:HasFocus() then self.rating:SetNumber(db.minRating or 0) end
        place(self.ratingLabel, 36)
        self.compositionLabel:SetText(PTG:L("composition"))
        place(self.compositionLabel, 21)
        for _, control in ipairs(self.compositionChecks) do
            control.text:SetText(PTG:L(control.key))
            control:SetChecked(db[control.setting])
            place(control, 27)
        end
        self.compositionHint:SetText(PTG:L("composition_hint"))
        place(self.compositionHint, self.compositionHint:GetStringHeight() + 17)
        self.dungeonLabel:SetText(PTG:L("dungeons"))
        self.allDungeons:ClearAllPoints()
        self.allDungeons:SetPoint("TOPLEFT", content, "TOPLEFT", 273, y + 5)
        self.allDungeons:SetText(PTG:L("all_dungeons"))
        self.allDungeons:SetEnabled(next(db.dungeons) ~= nil)
        place(self.dungeonLabel, 26)
        self.dungeonHint:SetText(PTG:L("dungeons_hint"))
        place(self.dungeonHint, self.dungeonHint:GetStringHeight() + 8)
        for _, control in pairs(self.dungeonChecks) do control:Hide() end
        local dungeons = PTG:GetDungeons()
        self.dungeonEmpty:SetShown(#dungeons == 0)
        if #dungeons == 0 then
            self.dungeonEmpty:SetText(PTG:L("no_dungeons"))
            place(self.dungeonEmpty, 28)
        end
        for _, dungeon in ipairs(dungeons) do
            local control = self.dungeonChecks[dungeon.id]
            if not control then
                control = check(content, function(widget)
                    db.dungeons[dungeon.id] = widget:GetChecked() and true or nil
                    changed()
                end)
                self.dungeonChecks[dungeon.id] = control
            end
            control.text:SetText(dungeon.name)
            control:SetChecked(db.dungeons[dungeon.id] == true)
            control:Show()
            place(control, math.max(27, control.text:GetStringHeight() + 6))
        end
        y = y - 14
        self.languageLabel:SetText(PTG:L("languages"))
        place(self.languageLabel, 22)
        self.languageHint:SetText(PTG:L("languages_hint"))
        place(self.languageHint, self.languageHint:GetStringHeight() + 9)
        for _, control in pairs(self.languageChecks) do control:Hide() end
        local languages = PTG:GetLanguages()
        self.languageEmpty:SetShown(#languages == 0)
        if #languages == 0 then
            self.languageEmpty:SetText(PTG:L("no_languages"))
            place(self.languageEmpty, 28)
        end
        for _, language in ipairs(languages) do
            local control = self.languageChecks[language.id]
            if not control then
                control = check(content, function(widget)
                    db.languages[language.id] = widget:GetChecked() and true or nil
                    changed()
                end)
                self.languageChecks[language.id] = control
            end
            control.text:SetText(language.name .. (language.mandatory and " (" .. PTG:L("mandatory") .. ")" or ""))
            control.text:SetFontObject(language.mandatory and "GameFontDisableSmall" or "GameFontHighlightSmall")
            control:SetChecked(language.mandatory or language.selected)
            control:SetEnabled(not language.mandatory)
            control:Show()
            place(control, math.max(27, control.text:GetStringHeight() + 6))
        end
        content:SetHeight(-y + 8)
    end
    settings:SetScript("OnShow", function() settings:Refresh() end)
end

function PTG:BuildUI()
    if self.ui then return end
    local frame = panel("PressToGroupFrame", 370, 526)
    self.ui = frame
    local position = self.db.position or {}
    frame:SetPoint(position.point or "CENTER", UIParent, position.point or "CENTER", position.x or 0, position.y or 0)
    frame.status = label(frame, "GameFontHighlight", 338)
    frame.status:SetPoint("TOPLEFT", 16, -38)
    frame.status:SetHeight(44)
    frame.counts = label(frame, "GameFontNormalSmall", 338)
    frame.counts:SetPoint("TOPLEFT", 16, -88)
    frame.counts:SetHeight(28)
    frame.response = label(frame, "GameFontDisableSmall", 338)
    frame.response:SetPoint("TOPLEFT", 16, -121)
    frame.search = label(frame, "GameFontHighlightSmall", 338)
    frame.search:SetPoint("TOPLEFT", 16, -143)
    frame.search:SetHeight(29)
    frame.candidate = label(frame, "GameFontNormal", 338)
    frame.candidate:SetPoint("TOPLEFT", 16, -178)
    frame.candidate:SetHeight(17)
    frame.candidate:SetWordWrap(false)
    frame.candidateDetails = label(frame, "GameFontHighlightSmall", 338)
    frame.candidateDetails:SetPoint("TOPLEFT", 16, -199)
    frame.candidateDetails:SetHeight(29)
    frame.applicationLabel = label(frame, "GameFontNormal", 338)
    frame.applicationLabel:SetPoint("TOPLEFT", 16, -238)
    frame.empty = label(frame, "GameFontDisableSmall", 338)
    frame.empty:SetPoint("TOPLEFT", 16, -265)
    frame.rows = {}
    for i = 1, 5 do
        local row = CreateFrame("Frame", nil, frame)
        row:SetSize(338, 36)
        row:SetPoint("TOPLEFT", 16, -260 - (i - 1) * 37)
        row.name = label(row, "GameFontHighlightSmall", 256)
        row.name:SetPoint("TOPLEFT", 0, 0)
        row.name:SetWordWrap(false)
        row.name:SetHeight(14)
        row.details = label(row, "GameFontDisableSmall", 256)
        row.details:SetPoint("TOPLEFT", 0, -16)
        row.details:SetWordWrap(false)
        row.details:SetHeight(14)
        row.cancel = button(row, 74, function()
            if row.application and row.application.owned then PTG:Cancel(row.application.id) end
        end)
        row.cancel:SetPoint("RIGHT", 0, 0)
        frame.rows[i] = row
    end
    frame.toggle = button(frame, 104, function()
        if PTG:GetView().running then PTG:Stop() else PTG:Start() end
    end)
    frame.toggle:SetPoint("BOTTOMLEFT", 16, 46)
    frame.step = button(frame, 112, function() PTG:OnPress() end)
    frame.step:SetPoint("BOTTOMLEFT", 126, 46)
    frame.open = button(frame, 110, function() PTG:OpenSearch() end)
    frame.open:SetPoint("BOTTOMRIGHT", -16, 46)
    frame.settings = button(frame, 164, function()
        PTG.settingsUI:SetShown(not PTG.settingsUI:IsShown())
    end)
    frame.settings:SetPoint("BOTTOMLEFT", 16, 14)
    frame.log = button(frame, 164, function() PTG:PrintLog() end)
    frame.log:SetPoint("BOTTOMRIGHT", -16, 14)
    buildSettings()
    self:RefreshUI()
end

function PTG:RefreshUI()
    local frame = self.ui
    if not frame then return end
    local view = self:GetView()
    frame.title:SetText(self:L("title"))
    frame.status:SetText(self:L(view.state or "off", unpack(view.stateArgs or {})))
    frame.counts:SetText(self:L("counts", view.found or 0, view.eligible or 0, view.active or 0, view.limit or 5))
    local response = self:L("never")
    if view.lastResponse then
        local seconds = math.floor(math.max(0, view.lastResponse))
        response = self:L("elapsed", math.floor(seconds / 60), seconds % 60)
    end
    frame.response:SetText(self:L("last_response", response))
    frame.search:SetText(view.searchText and view.searchText ~= "" and self:L("search_text", view.searchText) or self:L("search_unset"))
    local candidate = view.nextCandidate
    frame.candidate:SetText(candidate and self:L("next_group", candidate.name or "") or self:L("no_next_group"))
    frame.candidateDetails:SetText(candidate and self:L("candidate_details", candidate.dungeon or "", age(candidate.age), tostring(candidate.leaderRating or 0)) or "")
    frame.applicationLabel:SetText(self:L("applications"))
    local applications = view.applications or {}
    frame.empty:SetText(self:L("no_applications"))
    frame.empty:SetShown(#applications == 0)
    for i, row in ipairs(frame.rows) do
        local application = applications[i]
        row.application = application
        row:SetShown(application ~= nil)
        if application then
            row.name:SetText(application.name or "")
            local key = "application_" .. (application.status or "unknown")
            local status = self:L(key)
            if status == key then status = self:L("application_unknown") end
            row.details:SetText(self:L("application_details", status, age(application.age), self:L(application.owned and "own_application" or "manual_application")))
            row.cancel:SetText(self:L("cancel"))
            row.cancel:SetEnabled(application.owned == true)
        end
    end
    frame.toggle:SetText(self:L(view.running and "stop" or "start"))
    frame.step:SetText(self:L("step"))
    frame.open:SetText(self:L("open_search"))
    frame.settings:SetText(self:L("settings"))
    frame.log:SetText(self:L("log"))
    if self.settingsUI and self.settingsUI:IsShown() then self.settingsUI:Refresh() end
end
