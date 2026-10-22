local _, PTG = ...

local fullWidth, fullHeight, compactWidth, compactHeight = 440, 620, 300, 72

local function savePosition(frame)
    local left, top = frame:GetLeft(), frame:GetTop()
    if not left or not top then return end
    local x, y = left - UIParent:GetLeft(), top - UIParent:GetTop()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
    PTG.db.position = { point = "TOPLEFT", x = x, y = y }
end

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
    frame.drag = drag
    drag:SetPoint("TOPLEFT", 8, -5)
    drag:SetPoint("TOPRIGHT", -44, -5)
    drag:SetHeight(25)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() frame:StartMoving() end)
    drag:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        if frame == PTG.ui then savePosition(frame) end
    end)
    frame.title = label(drag, "GameFontNormalLarge", width - 40)
    frame.title:SetPoint("TOPLEFT", 7, -4)
    return frame
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

local accent = { 12 / 255, 210 / 255, 157 / 255 }
local tones = {
    ready = accent, waiting = { 0.48, 0.72, 1 }, paused = { 1, 0.76, 0.38 },
    error = { 1, 0.46, 0.46 }, invited = { 1, 0.85, 0.45 },
    stopped = { 0.66, 0.68, 0.7 }, unknown = { 0.76, 0.76, 0.76 },
}
local stateKinds = {
    ready_search = "ready", ready_apply = "ready", ready_cancel = "ready", ready_cancel_role_full = "ready",
    ready_cancel_company_full = "ready", filters_changed = "ready",
    searching = "waiting", waiting_search = "waiting", search_empty = "waiting", full = "waiting",
    no_candidates = "waiting", wait_apply = "waiting", wait_cancel = "waiting", wait_roles = "waiting",
    apply_sent = "waiting", cancel_sent = "waiting", invited = "invited",
    off = "stopped", grouped = "stopped", manual_search = "paused", no_query = "paused",
    no_dungeons_selected = "paused", no_role = "paused", chat_lockdown = "paused", native_pause = "paused",
    unavailable = "paused", cooldown = "paused", search_failed = "error", search_timeout = "error",
    search_conflict = "error", operation_unknown = "error", unsupported = "error", error = "error",
    company_changed = "stopped", company_not_leader = "paused", company_raid = "paused", company_full = "paused",
    company_instance = "paused", company_unknown = "paused", company_roles_unknown = "paused",
    company_roles_invalid = "paused", company_offline = "paused",
}

local function hoverText(widget)
    widget:EnableMouse(true)
    local function show(self)
        if not self.tooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltip, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end
    widget:SetScript("OnEnter", show)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
    widget:SetScript("OnHide", function(self)
        if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
    end)
end

local function setHoverText(widget, text)
    widget.tooltip = text
    if GameTooltip:IsShown() and GameTooltip:GetOwner() == widget then
        if text then GameTooltip:SetText(text, 1, 1, 1, 1, true) else GameTooltip:Hide() end
    end
end

local function surface(parent, width, height, x, y)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetPoint("TOPLEFT", x, y)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    frame:SetBackdropColor(0.1, 0.09, 0.08, 1)
    frame:SetBackdropBorderColor(1, 1, 1, 0.09)
    return frame
end

local function actionButton(parent, width, callback, primary)
    local control = CreateFrame("Button", nil, parent, "BackdropTemplate")
    control:SetSize(width, 30)
    control:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    control:SetBackdropColor(unpack(primary and { 0.04, 0.25, 0.2, 1 } or { 0.12, 0.11, 0.1, 1 }))
    control:SetBackdropBorderColor(unpack(primary and { accent[1], accent[2], accent[3], 0.8 } or { 1, 1, 1, 0.16 }))
    control:SetNormalFontObject("GameFontHighlight")
    control:SetDisabledFontObject("GameFontDisable")
    control:SetScript("OnClick", callback)
    control:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(accent)) end)
    control:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(primary and { accent[1], accent[2], accent[3], 0.8 } or { 1, 1, 1, 0.16 }))
    end)
    return control
end

local function check(parent, callback)
    local control = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
    control:SetSize(360, 32)
    control:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    control:SetBackdropColor(0.12, 0.11, 0.1, 1)
    control:SetBackdropBorderColor(1, 1, 1, 0.12)
    local box = control:CreateTexture(nil, "BACKGROUND")
    box:SetSize(18, 18)
    box:SetPoint("LEFT", 8, 0)
    box:SetColorTexture(0.035, 0.035, 0.03, 1)
    control:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    control:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    for _, texture in ipairs({control:GetCheckedTexture(), control:GetDisabledCheckedTexture()}) do
        texture:ClearAllPoints()
        texture:SetSize(18, 18)
        texture:SetPoint("LEFT", 8, 0)
        texture:SetVertexColor(unpack(accent))
    end
    control:GetDisabledCheckedTexture():SetAlpha(0.45)
    control.text = label(control, "GameFontHighlight", 314)
    control.text:SetPoint("TOPLEFT", 34, -8)
    control.text:SetWordWrap(true)
    control:SetScript("OnClick", callback)
    control:SetScript("OnEnter", function(self)
        if self:IsEnabled() then self:SetBackdropBorderColor(unpack(accent)) end
    end)
    control:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(1, 1, 1, 0.12) end)
    return control
end

local function choiceStyle(control, selected)
    control.selected = selected
    control:SetBackdropColor(unpack(selected and {0.04, 0.25, 0.2, 1} or {0.12, 0.11, 0.1, 1}))
    control:SetBackdropBorderColor(unpack(selected and {accent[1], accent[2], accent[3], 0.8} or {1, 1, 1, 0.16}))
    control:SetDisabledFontObject(selected and "GameFontHighlight" or "GameFontDisable")
end

local function settingsChoice(parent, callback)
    local control = actionButton(parent, 116, callback)
    control:SetScript("OnLeave", function(self) choiceStyle(self, self.selected) end)
    return control
end

local function settingsInput(parent)
    local control = CreateFrame("EditBox", nil, parent, "InputBoxScriptTemplate,BackdropTemplate")
    control:SetSize(84, 28)
    control:SetFontObject("GameFontHighlight")
    control:SetTextInsets(10, 8, 0, 0)
    control:SetAutoFocus(false)
    control:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    control:SetBackdropColor(0.055, 0.05, 0.045, 1)
    control:SetBackdropBorderColor(1, 1, 1, 0.25)
    control:HookScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(unpack(accent)) end)
    -- Blizzard clears focus on mouse-down before the collapse click can discard drafts.
    function control:HasStickyFocus()
        local collapse = PTG.ui and PTG.ui.collapse
        return not PTG.db.compactMode and collapse and collapse:IsVisible() and collapse:IsMouseOver()
    end
    return control
end

local function finishBindingCapture(message)
    local capture = PTG.bindingCapture
    if not capture then return end
    capture.phase, capture.pending = "release", nil
    if message then PTG.settingsUI.bindingMessage = message end
    if not next(capture.down) then
        capture.listener:SetScript("OnKeyDown", nil)
        capture.listener:SetScript("OnKeyUp", nil)
        capture.listener:SetScript("OnUpdate", nil)
        capture.listener:EnableKeyboard(false)
        capture.listener:Hide()
        PTG.bindingCapture = nil
    end
    PTG:RefreshUI()
end

function PTG:CancelBindingCapture()
    finishBindingCapture("binding_cancelled")
end

local function bindingKeyText(key)
    return key and GetBindingText(key) or PTG:L("binding_none")
end

local function beginBindingCapture(settings)
    if InCombatLockdown() then
        settings.bindingMessage = "binding_combat"
        PTG:RefreshUI()
        return
    end
    PTG:CancelBindingCapture()
    if PTG.bindingCapture then return end
    local focus = GetCurrentKeyBoardFocus()
    if focus then focus:ClearFocus() end
    local listener = settings.bindingListener
    local capture = { phase = "capture", down = {}, listener = listener }
    PTG.bindingCapture, settings.bindingMessage = capture, nil
    listener:SetPropagateKeyboardInput(false)
    listener:SetScript("OnKeyDown", function(_, input)
        capture.down[input] = true
        if input == "ESCAPE" then
            PTG:CancelBindingCapture()
        elseif capture.phase == "capture" then
            local key = GetConvertedKeyOrButton(input)
            if IsKeyPressIgnoredForBinding(key) then return end
            key = CreateKeyChordStringUsingMetaKeyState(key)
            local action, currentSet = PTG.Input.GetStepKeyAction(key)
            if action == nil then
                finishBindingCapture(currentSet)
            elseif action == "" or action == "PRESSTOGROUP_STEP" then
                local _, reason = PTG.Input.AssignStepKey(key, action, currentSet)
                finishBindingCapture(reason)
            else
                capture.phase = "conflict"
                capture.pending = { key = key, action = action, currentSet = currentSet }
                PTG:RefreshUI()
            end
        end
    end)
    listener:SetScript("OnKeyUp", function(_, key)
        capture.down[key] = nil
        if capture.phase == "release" then finishBindingCapture() else PTG:RefreshUI() end
    end)
    listener:SetScript("OnUpdate", function()
        if type(IsKeyDown) ~= "function" then return end
        local released = false
        for key in pairs(capture.down) do
            local ok, down = pcall(IsKeyDown, key)
            if ok and not (type(issecretvalue) == "function" and issecretvalue(down))
                and type(down) == "boolean" and not down then
                capture.down[key], released = nil, true
            end
        end
        if released then
            if capture.phase == "release" then finishBindingCapture() else PTG:RefreshUI() end
        end
    end)
    listener:Show()
    listener:EnableKeyboard(true)
    PTG:RefreshUI()
end

local function buildSettings()
    local settings = panel("PressToGroupSettings", 440, 620)
    settings:SetPoint("CENTER", UIParent, "CENTER", 450, 0)
    settings:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    settings:SetBackdropColor(0.069, 0.058, 0.047, 0.98)
    settings:SetBackdropBorderColor(1, 1, 1, 0.16)
    settings.title:SetTextColor(1, 1, 1)
    settings.title:SetWidth(360)
    settings:Hide()
    PTG.settingsUI = settings
    tinsert(UISpecialFrames, "PressToGroupSettings")
    settings.subtitle = label(settings, "GameFontHighlightSmall", 384)
    settings.subtitle:SetPoint("TOPLEFT", 16, -40)
    settings.subtitle:SetTextColor(0.7, 0.7, 0.7)
    settings.dismiss = actionButton(settings, 24, function() settings:Hide() end)
    settings.dismiss:SetPoint("TOPRIGHT", -12, -8)
    settings.dismiss:SetHeight(24)
    settings.dismiss:SetText("×")
    hoverText(settings.dismiss)
    settings.close = actionButton(settings, 112, function() settings:Hide() end)
    settings.close:SetPoint("BOTTOMRIGHT", -16, 14)
    settings.close:SetHeight(28)
    settings.log = actionButton(settings, 112, function() PTG:PrintLog() end)
    settings.log:SetPoint("BOTTOMLEFT", 16, 14)
    settings.log:SetHeight(28)
    settings.saved = label(settings, "GameFontHighlightSmall", 160)
    settings.saved:SetPoint("BOTTOMLEFT", 140, 14)
    settings.saved:SetHeight(28)
    settings.saved:SetJustifyH("CENTER")
    settings.saved:SetJustifyV("MIDDLE")
    settings.saved:SetWordWrap(true)
    settings.saved:SetTextColor(0.7, 0.7, 0.7)

    local scroll = CreateFrame("ScrollFrame", "PressToGroupSettingsScroll", settings, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -66)
    scroll:SetPoint("BOTTOMRIGHT", -35, 54)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(384, 1)
    scroll:SetScrollChild(content)
    settings.content = content
    settings.sections = {}
    for _, key in ipairs({"role", "composition", "dungeons", "languages"}) do
        local card = surface(content, 384, 1, 0, 0)
        card.heading = label(card, "GameFontHighlight", 360)
        card.heading:SetPoint("TOPLEFT", 12, -12)
        card.heading:SetTextColor(unpack(accent))
        settings.sections[key] = card
    end
    local roleSection, compositionSection, dungeonSection, languageSection = settings.sections.role, settings.sections.composition,
        settings.sections.dungeons, settings.sections.languages
    local function hint(parent)
        local text = label(parent, "GameFontHighlightSmall", 360)
        text:SetTextColor(0.7, 0.7, 0.7)
        return text
    end
    settings.inputModeLabel = label(roleSection, "GameFontHighlightSmall", 360)
    settings.inputModeButtons = {}
    for i, mode in ipairs({ "auto", "key" }) do
        local choice = settingsChoice(roleSection, function() PTG:SetInputMode(mode) end)
        choice:SetWidth(174)
        choice.mode = mode
        settings.inputModeButtons[i] = choice
    end
    settings.inputModeHint = hint(roleSection)
    settings.bindingPrimary, settings.bindingSecondary = hint(roleSection), hint(roleSection)
    settings.bindingAssign = actionButton(roleSection, 174, function() beginBindingCapture(settings) end)
    settings.bindingClear = actionButton(roleSection, 174, function()
        if PTG.bindingCapture then return end
        local _, reason = PTG.Input.ClearStepKey()
        settings.bindingMessage = reason
        PTG:RefreshUI()
    end)
    settings.bindingStatus, settings.bindingScope = hint(roleSection), hint(roleSection)
    settings.bindingConfirm = actionButton(roleSection, 174, function()
        local capture = PTG.bindingCapture
        local pending = capture and capture.pending
        if not pending or next(capture.down) then return end
        local _, reason = PTG.Input.AssignStepKey(pending.key, pending.action, pending.currentSet)
        finishBindingCapture(reason)
    end, true)
    settings.bindingCancel = actionButton(roleSection, 174, function() PTG:CancelBindingCapture() end)
    settings.bindingListener = CreateFrame("Frame", nil, UIParent)
    settings.bindingListener:SetFrameStrata("FULLSCREEN_DIALOG")
    settings.bindingListener:EnableKeyboard(false)
    settings.bindingListener:Hide()
    settings.localeLabel = label(languageSection, "GameFontHighlightSmall", 360)
    settings.localeButtons = {}
    for i, locale in ipairs({ "auto", "ruRU", "enUS" }) do
        local choice = settingsChoice(languageSection, function()
            PTG.db.locale = locale
            changed()
        end)
        choice.locale = locale
        settings.localeButtons[i] = choice
    end
    settings.roleLabel = label(roleSection, "GameFontHighlightSmall", 360)
    settings.autoRole = check(roleSection, function(widget)
        PTG.db.autoRole = widget:GetChecked() == true
        PTG:SyncRole()
        PTG:RefreshUI()
    end)
    settings.roleButtons = {}
    for i, role in ipairs({ "TANK", "HEALER", "DAMAGER" }) do
        local choice = settingsChoice(roleSection, function()
            PTG.db.autoRole = false
            PTG:SetRole(role)
            PTG:RefreshUI()
        end)
        choice.role = role
        settings.roleButtons[i] = choice
    end
    settings.ratingLabel = label(roleSection, "GameFontHighlight", 260)
    settings.rating = settingsInput(roleSection)
    settings.rating:SetNumeric(true)
    settings.rating:SetMaxLetters(5)
    settings.rating:SetScript("OnEnterPressed", function(edit) edit:ClearFocus() end)
    settings.rating:SetScript("OnEscapePressed", function(edit)
        edit:SetNumber(PTG.db.minRating)
        edit:ClearFocus()
    end)
    settings.rating:SetScript("OnEditFocusLost", function(edit)
        edit:SetBackdropBorderColor(1, 1, 1, 0.25)
        local value = math.max(0, math.floor(tonumber(edit:GetText()) or 0))
        edit:SetNumber(value)
        if PTG.db.minRating ~= value then
            PTG.db.minRating = value
            changed()
        end
    end)
    settings.replaceAfterLabel = label(roleSection, "GameFontHighlight", 260)
    settings.replaceAfter = settingsInput(roleSection)
    -- Validate raw text so a sign or decimal cannot be stripped into a different value.
    settings.replaceAfter:SetScript("OnEnterPressed", function(edit) edit:ClearFocus() end)
    settings.replaceAfter:SetScript("OnEscapePressed", function(edit)
        edit:SetNumber(PTG.db.replaceAfter)
        edit:ClearFocus()
    end)
    settings.replaceAfter:SetScript("OnEditFocusLost", function(edit)
        edit:SetBackdropBorderColor(1, 1, 1, 0.25)
        local value = PTG.Engine.ParseReplacementAge(edit:GetText())
        if value then PTG.db.replaceAfter = value end
        edit:SetNumber(PTG.db.replaceAfter)
        PTG:RefreshUI()
    end)
    settings.replaceAfterHint = hint(roleSection)
    settings.compositionLabel = compositionSection.heading
    settings.compositionChecks = {}
    for i, item in ipairs({
        { "requireTank", "require_tank" }, { "requireLust", "require_lust" }, { "requireBrez", "require_brez" },
    }) do
        local control = check(compositionSection, function(widget)
            PTG.db[item[1]] = widget:GetChecked() == true
            changed()
        end)
        control.setting, control.key = item[1], item[2]
        settings.compositionChecks[i] = control
    end
    settings.compositionHint = hint(compositionSection)
    settings.dungeonLabel = dungeonSection.heading
    settings.dungeonLabel:SetWidth(260)
    settings.allDungeons = actionButton(dungeonSection, 65, function()
        wipe(PTG.db.dungeons)
        for _, dungeon in ipairs(PTG:GetDungeons()) do
            PTG.db.dungeons[dungeon.id] = true
        end
        PTG.db.dungeonsInitialized = true
        changed()
    end)
    settings.allDungeons:SetHeight(26)
    settings.dungeonHint = hint(dungeonSection)
    settings.dungeonEmpty = hint(dungeonSection)
    settings.dungeonChecks = {}
    settings.languageLabel = label(languageSection, "GameFontHighlightSmall", 360)
    settings.languageHint = hint(languageSection)
    settings.languageEmpty = hint(languageSection)
    settings.languageChecks = {}

    function settings:Refresh()
        local db, top, y, section = PTG.db, 0
        self.title:SetText(PTG:L("settings"))
        self.subtitle:SetText(PTG:L("title"))
        self.close:SetText(PTG:L("close"))
        self.log:SetText(PTG:L("log"))
        self.saved:SetText(PTG:L("settings_saved"))
        setHoverText(self.dismiss, PTG:L("close"))
        local function begin(card, key)
            section, y = card, -42
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", content, "TOPLEFT", 0, top)
            card.heading:SetText(PTG:L(key))
        end
        local function finish()
            local height = -y + 12
            section:SetHeight(height)
            top = top - height - 12
        end
        local function place(widget, height, x)
            widget:ClearAllPoints()
            widget:SetPoint("TOPLEFT", section, "TOPLEFT", x or 12, y)
            y = y - height
        end
        local function placeCheck(control)
            local height = math.max(32, control.text:GetStringHeight() + 16)
            control:SetHeight(height)
            place(control, height + 6)
        end

        begin(roleSection, "settings_role_search")
        self.inputModeLabel:SetText(PTG:L("input_mode"))
        place(self.inputModeLabel, 20)
        for i, choice in ipairs(self.inputModeButtons) do
            choice:ClearAllPoints()
            choice:SetPoint("TOPLEFT", section, "TOPLEFT", 12 + (i - 1) * 186, y)
            choice:SetText(PTG:L("input_mode_" .. choice.mode))
            choice:SetEnabled(db.inputMode ~= choice.mode)
            choiceStyle(choice, db.inputMode == choice.mode)
        end
        y = y - 42
        self.inputModeHint:SetText(PTG:L(db.inputMode == "key" and "input_mode_key_hint" or "input_mode_auto_hint"))
        place(self.inputModeHint, self.inputModeHint:GetStringHeight() + 12)
        local key1, key2, keyError = PTG.Input.GetStepKeys()
        self.bindingPrimary:SetText(keyError and PTG:L(keyError) or PTG:L("binding_primary", bindingKeyText(key1)))
        place(self.bindingPrimary, self.bindingPrimary:GetStringHeight() + 8)
        self.bindingSecondary:SetText(PTG:L("binding_secondary", bindingKeyText(key2)))
        place(self.bindingSecondary, self.bindingSecondary:GetStringHeight() + 12)
        local capture = PTG.bindingCapture
        local pending = capture and capture.pending
        local combat = InCombatLockdown()
        self.bindingAssign:SetText(PTG:L("binding_assign"))
        self.bindingAssign:SetEnabled(not combat and not capture)
        self.bindingClear:SetText(PTG:L("binding_clear"))
        self.bindingClear:SetEnabled(not combat and not capture and key1 ~= nil and not keyError)
        self.bindingAssign:ClearAllPoints()
        self.bindingAssign:SetPoint("TOPLEFT", section, "TOPLEFT", 12, y)
        self.bindingClear:ClearAllPoints()
        self.bindingClear:SetPoint("TOPLEFT", section, "TOPLEFT", 198, y)
        y = y - 42
        local message = self.bindingMessage or (combat and "binding_combat" or "binding_hint")
        if pending then
            local actionName = GetBindingName(pending.action)
            self.bindingStatus:SetText(PTG:L("binding_conflict", bindingKeyText(pending.key), actionName))
        elseif capture then
            self.bindingStatus:SetText(PTG:L(capture.phase == "capture" and "binding_capture" or "binding_release"))
        else
            self.bindingStatus:SetText(PTG:L(message))
        end
        place(self.bindingStatus, self.bindingStatus:GetStringHeight() + 12)
        self.bindingConfirm:SetShown(pending ~= nil)
        self.bindingCancel:SetShown(capture ~= nil)
        self.bindingConfirm:SetEnabled(not combat and pending ~= nil and not next(capture and capture.down or {}))
        self.bindingConfirm:SetText(PTG:L("binding_replace"))
        self.bindingCancel:SetText(PTG:L("cancel"))
        if capture then
            self.bindingConfirm:ClearAllPoints()
            self.bindingConfirm:SetPoint("TOPLEFT", section, "TOPLEFT", 12, y)
            self.bindingCancel:ClearAllPoints()
            self.bindingCancel:SetPoint("TOPLEFT", section, "TOPLEFT", pending and 198 or 12, y)
            y = y - 42
        end
        self.bindingScope:SetText(PTG:L("binding_scope"))
        place(self.bindingScope, self.bindingScope:GetStringHeight() + 20)
        self.roleLabel:SetText(PTG:L("role"))
        place(self.roleLabel, 20)
        self.autoRole.text:SetText(PTG:L("auto_role"))
        self.autoRole:SetChecked(db.autoRole == true)
        placeCheck(self.autoRole)
        for i, choice in ipairs(self.roleButtons) do
            choice:ClearAllPoints()
            choice:SetPoint("TOPLEFT", section, "TOPLEFT", 12 + (i - 1) * 122, y)
            choice:SetText(PTG:L(choice.role))
            choice:SetEnabled(db.autoRole == true or db.role ~= choice.role)
            choiceStyle(choice, db.role == choice.role)
        end
        y = y - 46
        self.ratingLabel:SetText(PTG:L("min_rating"))
        self.rating:ClearAllPoints()
        self.rating:SetPoint("TOPLEFT", section, "TOPLEFT", 288, y + 6)
        if not self.rating:HasFocus() then self.rating:SetNumber(db.minRating or 0) end
        place(self.ratingLabel, 42)
        self.replaceAfterLabel:SetText(PTG:L("replace_after"))
        self.replaceAfter:ClearAllPoints()
        self.replaceAfter:SetPoint("TOPLEFT", section, "TOPLEFT", 288, y + 6)
        if not self.replaceAfter:HasFocus() then self.replaceAfter:SetNumber(db.replaceAfter) end
        place(self.replaceAfterLabel, 28)
        self.replaceAfterHint:SetText(PTG:L("replace_after_hint"))
        place(self.replaceAfterHint, self.replaceAfterHint:GetStringHeight() + 12)
        finish()

        begin(compositionSection, "composition")
        for _, control in ipairs(self.compositionChecks) do
            control.text:SetText(PTG:L(control.key))
            control:SetChecked(db[control.setting])
            placeCheck(control)
        end
        self.compositionHint:SetText(PTG:L("composition_hint"))
        place(self.compositionHint, self.compositionHint:GetStringHeight() + 12)
        finish()

        begin(dungeonSection, "dungeons")
        self.allDungeons:ClearAllPoints()
        self.allDungeons:SetPoint("TOPRIGHT", section, "TOPRIGHT", -12, -8)
        self.allDungeons:SetText(PTG:L("all_dungeons"))
        self.dungeonHint:SetText(PTG:L("dungeons_hint"))
        place(self.dungeonHint, self.dungeonHint:GetStringHeight() + 12)
        for _, control in pairs(self.dungeonChecks) do control:Hide() end
        local dungeons = PTG:GetDungeons()
        self.dungeonEmpty:SetShown(#dungeons == 0)
        if #dungeons == 0 then
            self.dungeonEmpty:SetText(PTG:L("no_dungeons"))
            place(self.dungeonEmpty, self.dungeonEmpty:GetStringHeight() + 12)
        end
        local hasUncheckedDungeon = false
        for _, dungeon in ipairs(dungeons) do
            local control = self.dungeonChecks[dungeon.id]
            if not control then
                control = check(dungeonSection, function(widget)
                    db.dungeons[dungeon.id] = widget:GetChecked() and true or nil
                    db.dungeonsInitialized = true
                    changed()
                end)
                self.dungeonChecks[dungeon.id] = control
            end
            control.text:SetText(dungeon.name)
            control:SetChecked(db.dungeons[dungeon.id] == true)
            if db.dungeons[dungeon.id] ~= true then hasUncheckedDungeon = true end
            control:Show()
            placeCheck(control)
        end
        self.allDungeons:SetEnabled(hasUncheckedDungeon)
        finish()

        begin(languageSection, "settings_languages")
        self.localeLabel:SetText(PTG:L("interface_language"))
        place(self.localeLabel, 20)
        for i, choice in ipairs(self.localeButtons) do
            choice:ClearAllPoints()
            choice:SetPoint("TOPLEFT", section, "TOPLEFT", 12 + (i - 1) * 122, y)
            choice:SetText(choice.locale == "auto" and PTG:L("automatic") or (choice.locale == "ruRU" and "RU" or "EN"))
            local selected = (db.locale or "auto") == choice.locale
            choice:SetEnabled(not selected)
            choiceStyle(choice, selected)
        end
        y = y - 46
        self.languageLabel:SetText(PTG:L("languages"))
        place(self.languageLabel, 20)
        self.languageHint:SetText(PTG:L("languages_hint"))
        place(self.languageHint, self.languageHint:GetStringHeight() + 12)
        for _, control in pairs(self.languageChecks) do control:Hide() end
        local languages = PTG:GetLanguages()
        self.languageEmpty:SetShown(#languages == 0)
        if #languages == 0 then
            self.languageEmpty:SetText(PTG:L("no_languages"))
            place(self.languageEmpty, self.languageEmpty:GetStringHeight() + 12)
        end
        for _, language in ipairs(languages) do
            local control = self.languageChecks[language.id]
            if not control then
                control = check(languageSection, function(widget)
                    db.languages[language.id] = widget:GetChecked() and true or nil
                    changed()
                end)
                self.languageChecks[language.id] = control
            end
            control.text:SetText(language.name .. (language.mandatory and " (" .. PTG:L("mandatory") .. ")" or ""))
            local shade = language.mandatory and 0.65 or 0.92
            control.text:SetTextColor(shade, shade, shade)
            control:SetChecked(language.mandatory or language.selected)
            control:SetEnabled(not language.mandatory)
            control:Show()
            placeCheck(control)
        end
        finish()
        content:SetHeight(-top)
    end
    settings:SetScript("OnShow", function() settings:Refresh() end)
    settings:HookScript("OnHide", function() PTG:CancelBindingCapture() end)
end

function PTG:BuildGroupFinderButton()
    local search = LFGListFrame and LFGListFrame.SearchPanel
    if not search then return end
    if not self.groupFinderButton then
        local control = button(search, 44, function() PTG:ToggleWindow() end)
        control:SetHeight(20)
        control:SetText("PTG")
        control:RegisterForClicks("LeftButtonUp")
        hoverText(control)
        self.groupFinderButton = control
        search:HookScript("OnShow", function() PTG:BuildGroupFinderButton() end)
    end
    local control = self.groupFinderButton
    control:ClearAllPoints()
    if UsePGFButton and UsePGFButton:GetParent() == search then
        control:SetPoint("RIGHT", UsePGFButton, "LEFT", -8, 0)
    else
        control:SetPoint("TOPRIGHT", search, "TOPRIGHT", -8, -6)
    end
    setHoverText(control, self:L("title") .. "\n" .. self:L("binding_window"))
end

function PTG:SetCompactMode(compact)
    compact = compact == true
    local frame = self.ui
    if not frame or self.db.compactMode == compact then return end
    savePosition(frame)
    self.db.compactMode = compact
    if compact and self.settingsUI then
        -- Losing focus must not apply unfinished filter edits when collapsing.
        self.settingsUI.rating:SetNumber(self.db.minRating)
        self.settingsUI.rating:ClearFocus()
        self.settingsUI.replaceAfter:SetNumber(self.db.replaceAfter)
        self.settingsUI.replaceAfter:ClearFocus()
        self.settingsUI:Hide()
    end
    frame:SetSize(compact and compactWidth or fullWidth, compact and compactHeight or fullHeight)
    savePosition(frame)
    self:RefreshUI()
end

function PTG:BuildUI()
    if self.ui then return end
    local compact = self.db.compactMode == true
    local frame = panel("PressToGroupFrame", compact and compactWidth or fullWidth, compact and compactHeight or fullHeight)
    self.ui = frame
    frame:HookScript("OnHide", function() PTG:CancelBindingCapture() end)
    tinsert(UISpecialFrames, "PressToGroupFrame")
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    frame:SetBackdropColor(0.069, 0.058, 0.047, 0.98)
    frame:SetBackdropBorderColor(1, 1, 1, 0.16)
    frame.title:SetTextColor(1, 1, 1)
    frame.title:SetWidth(360)
    local position = self.db.position or {}
    frame:SetPoint(position.point or "CENTER", UIParent, position.point or "CENTER", position.x or 0, position.y or 0)
    frame.full = CreateFrame("Frame", nil, frame)
    frame.full:SetSize(fullWidth, fullHeight)
    frame.full:SetPoint("TOPLEFT", 0, 0)
    frame.searchPanel = surface(frame.full, 408, 24, 16, -44)
    frame.search = label(frame.searchPanel, "GameFontHighlightSmall", 384)
    frame.search:SetPoint("TOPLEFT", 12, -5)
    frame.search:SetHeight(14)
    frame.search:SetWordWrap(false)
    hoverText(frame.searchPanel)

    frame.statusPanel = surface(frame.full, 408, 82, 16, -76)
    frame.statusAccent = frame.statusPanel:CreateTexture(nil, "ARTWORK")
    frame.statusAccent:SetPoint("TOPLEFT", 0, 0)
    frame.statusAccent:SetPoint("BOTTOMLEFT", 0, 0)
    frame.statusAccent:SetWidth(3)
    frame.statusHeading = label(frame.statusPanel, "GameFontHighlight", 176)
    frame.statusHeading:SetPoint("TOPLEFT", 14, -9)
    frame.statusHeading:SetHeight(16)
    frame.role = label(frame.statusPanel, "GameFontHighlightSmall", 196)
    frame.role:SetPoint("TOPRIGHT", -12, -9)
    frame.role:SetHeight(16)
    frame.role:SetJustifyH("RIGHT")
    frame.role:SetWordWrap(false)
    frame.status = label(frame.statusPanel, "GameFontHighlightSmall", 380)
    frame.status:SetPoint("TOPLEFT", 14, -29)
    frame.status:SetHeight(30)
    frame.response = label(frame.statusPanel, "GameFontHighlightSmall", 380)
    frame.response:SetPoint("TOPLEFT", 14, -63)
    frame.response:SetHeight(12)
    frame.response:SetTextColor(0.7, 0.7, 0.7)
    hoverText(frame.statusPanel)

    frame.metrics = {}
    for i, key in ipairs({ "found_label", "eligible_label", "applications" }) do
        local metric = surface(frame.full, 130, 52, 16 + (i - 1) * 139, -170)
        metric.key = key
        metric.caption = label(metric, "GameFontHighlightSmall", 110)
        metric.caption:SetPoint("TOPLEFT", 10, -7)
        metric.caption:SetTextColor(0.72, 0.72, 0.72)
        metric.value = label(metric, "GameFontHighlightLarge", 110)
        metric.value:SetPoint("TOPLEFT", 10, -25)
        metric.value:SetHeight(22)
        frame.metrics[i] = metric
    end

    frame.candidatePanel = surface(frame.full, 408, 88, 16, -234)
    frame.candidateLabel = label(frame.candidatePanel, "GameFontHighlightSmall", 384)
    frame.candidateLabel:SetPoint("TOPLEFT", 12, -9)
    frame.candidateLabel:SetTextColor(0.72, 0.72, 0.72)
    frame.candidate = label(frame.candidatePanel, "GameFontHighlight", 384)
    frame.candidate:SetPoint("TOPLEFT", 12, -29)
    frame.candidate:SetHeight(17)
    frame.candidate:SetWordWrap(false)
    frame.candidateDetails = label(frame.candidatePanel, "GameFontHighlightSmall", 384)
    frame.candidateDetails:SetPoint("TOPLEFT", 12, -51)
    frame.candidateDetails:SetHeight(28)
    frame.candidateDetails:SetTextColor(0.78, 0.78, 0.78)
    frame.activation = CreateFrame("Frame", nil, frame.candidatePanel)
    frame.activation:SetSize(408, 88)
    frame.activation:SetPoint("TOPLEFT", 0, 0)
    frame.activation.heading = label(frame.activation, "GameFontHighlightSmall", 384)
    frame.activation.heading:SetPoint("TOPLEFT", 12, -9)
    frame.activation.heading:SetHeight(12)
    frame.activation.steps = {}
    for i = 1, 4 do
        local text = label(frame.activation, "GameFontHighlightSmall", 384)
        text:SetPoint("TOPLEFT", 12, -29 - (i - 1) * 14)
        text:SetHeight(12)
        text:SetWordWrap(false)
        frame.activation.steps[i] = text
    end
    hoverText(frame.candidatePanel)

    frame.applicationLabel = label(frame.full, "GameFontHighlight", 408)
    frame.applicationLabel:SetPoint("TOPLEFT", 16, -334)
    frame.empty = label(frame.full, "GameFontHighlightSmall", 408)
    frame.empty:SetPoint("TOPLEFT", 16, -411)
    frame.empty:SetJustifyH("CENTER")
    frame.empty:SetTextColor(0.7, 0.7, 0.7)
    frame.rows = {}
    for i = 1, 5 do
        local row = surface(frame.full, 408, 34, 16, -356 - (i - 1) * 36)
        row.name = label(row, "GameFontHighlightSmall", 304)
        row.name:SetPoint("TOPLEFT", 10, -4)
        row.name:SetWordWrap(false)
        row.name:SetHeight(14)
        row.details = label(row, "GameFontHighlightSmall", 304)
        row.details:SetPoint("TOPLEFT", 10, -19)
        row.details:SetWordWrap(false)
        row.details:SetHeight(12)
        row.cancel = actionButton(row, 68, function()
            if row.application and row.application.owned then PTG:Cancel(row.application.id) end
        end)
        row.cancel:SetHeight(22)
        row.cancel:SetPoint("RIGHT", -7, 0)
        hoverText(row)
        frame.rows[i] = row
    end
    frame.toggle = actionButton(frame.full, 200, function()
        if PTG:GetView().running then PTG:Stop() else PTG:Start() end
    end, true)
    frame.toggle:SetPoint("TOPLEFT", 16, -550)
    frame.step = actionButton(frame.full, 200, function() PTG:OnPress() end)
    frame.step:SetPoint("TOPLEFT", 224, -550)
    frame.open = actionButton(frame.full, 200, function() PTG:OpenSearch() end)
    frame.open:SetPoint("BOTTOMLEFT", 16, 14)
    frame.open:SetHeight(22)
    frame.settings = actionButton(frame.full, 200, function()
        PTG.settingsUI:SetShown(not PTG.settingsUI:IsShown())
    end)
    frame.settings:SetPoint("BOTTOMRIGHT", -16, 14)
    frame.settings:SetHeight(22)
    frame.close = actionButton(frame, 24, function() frame:Hide() end)
    frame.close:SetPoint("TOPRIGHT", -12, -8)
    frame.close:SetHeight(24)
    frame.close:SetText("×")
    hoverText(frame.close)
    frame.collapse = actionButton(frame, 24, function() PTG:SetCompactMode(not PTG.db.compactMode) end)
    frame.collapse:SetHeight(24)
    hoverText(frame.collapse)
    frame.compactApplications = label(frame, "GameFontHighlightSmall", 268)
    frame.compactApplications:SetPoint("TOPLEFT", 16, -42)
    frame.compactApplications:SetHeight(16)
    hoverText(frame.drag)
    buildSettings()
    local minimap = CreateFrame("Button", "PressToGroupMinimapButton", Minimap)
    self.minimapButton = minimap
    minimap:SetSize(32, 32)
    minimap:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -8, 8)
    minimap:SetNormalTexture("Interface\\AddOns\\PressToGroup\\Media\\Icon")
    minimap.icon = minimap:GetNormalTexture()
    minimap:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    minimap:RegisterForClicks("LeftButtonUp")
    minimap:SetScript("OnClick", function() PTG:ToggleWindow() end)
    minimap:SetScript("OnEnter", function(widget)
        GameTooltip:SetOwner(widget, "ANCHOR_LEFT")
        GameTooltip:SetText(PTG:L("title"))
        GameTooltip:AddLine(PTG:L("binding_window"), 1, 1, 1)
        GameTooltip:Show()
    end)
    minimap:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self:BuildGroupFinderButton()
    self:RefreshUI()
end

function PTG:RefreshUI()
    local frame = self.ui
    if not frame then return end
    local view = self:GetView()
    local compact = self.db.compactMode == true
    frame.full:SetShown(not compact)
    frame.close:SetShown(not compact)
    frame.compactApplications:SetShown(compact)
    frame.collapse:ClearAllPoints()
    frame.collapse:SetPoint("TOPRIGHT", compact and -12 or -44, -8)
    frame.collapse:SetText(compact and "+" or "−")
    setHoverText(frame.collapse, self:L(compact and "expand_window" or "compact_window"))
    frame.drag:ClearAllPoints()
    frame.drag:SetPoint("TOPLEFT", 8, -5)
    frame.drag:SetPoint("TOPRIGHT", compact and -44 or -76, -5)
    frame.title:SetWidth(compact and 232 or 328)
    local kind = stateKinds[view.state] or "unknown"
    frame.title:SetText(compact and self:L("status_" .. kind) or "|TInterface\\AddOns\\PressToGroup\\Media\\Icon:22:22|t " .. self:L("title"))
    if compact then frame.title:SetTextColor(unpack(tones[kind])) else frame.title:SetTextColor(1, 1, 1) end
    frame.statusHeading:SetText(self:L("status_" .. kind))
    frame.statusHeading:SetTextColor(unpack(tones[kind]))
    frame.statusAccent:SetColorTexture(unpack(tones[kind]))
    frame.status:SetText(self:L(view.state or "off", unpack(view.stateArgs or {})))
    frame.compactApplications:SetText(self:L("compact_applications", view.active or 0, view.limit or 5))
    local values = { view.found or 0, view.eligible or 0, string.format("%d/%d", view.active or 0, view.limit or 5) }
    for i, metric in ipairs(frame.metrics) do
        metric.caption:SetText(self:L(metric.key))
        metric.value:SetText(tostring(values[i]))
    end
    local response = self:L("never")
    if view.lastResponse then
        local seconds = math.floor(math.max(0, view.lastResponse))
        response = self:L("elapsed", math.floor(seconds / 60), seconds % 60)
    end
    frame.response:SetText(self:L("last_response", response))
    local roleText = self:L("current_role", self:L(self.db.role or "role_unknown"), self:L(self.db.autoRole and "role_auto" or "role_manual"))
    local roleTooltip, companyTooltip = roleText
    if view.companySize and view.companySize > 1 then
        local roles = view.companyRoles
        local companyText = roles and self:L("company_summary", view.companySize, roles.TANK, roles.HEALER, roles.DAMAGER)
            or self:L("company_summary_unknown", view.companySize)
        local leaderKey = view.companyLeader == true and "company_leader"
            or view.companyLeader == false and "company_other_leader" or "company_leader_unknown"
        companyTooltip = companyText .. "\n" .. roleText .. "\n" .. self:L(leaderKey) .. "\n" .. self:L("company_help")
        roleTooltip = companyTooltip
        frame.role:SetText(companyText)
    else
        frame.role:SetText(roleText)
    end
    setHoverText(frame.statusPanel, roleTooltip .. "\n" .. frame.status:GetText() .. "\n" .. frame.response:GetText())
    setHoverText(frame.drag, compact and frame.status:GetText() .. "\n" .. frame.compactApplications:GetText()
        .. (companyTooltip and "\n" .. companyTooltip or "") or nil)
    frame.search:SetText(view.searchText and view.searchText ~= "" and self:L("search_text", view.searchText) or self:L("search_unset"))
    setHoverText(frame.searchPanel, frame.search:GetText())
    local candidate = view.nextCandidate
    frame.candidateLabel:SetText(self:L("next_candidate"))
    frame.candidate:SetText(candidate and candidate.name or self:L("no_next_group"))
    frame.candidateDetails:SetText(candidate and self:L("candidate_details", candidate.dungeon or "", age(candidate.age), tostring(candidate.leaderRating or 0)) or "")
    local activationStep
    if not candidate and (view.state == "off" or view.state == "no_query" or view.state == "manual_search") then
        if not view.searchText or view.searchText == "" then activationStep = 1
        elseif view.groupFinderVisible then activationStep = 2
        elseif not view.running then activationStep = 3 end
    end
    frame.activation:SetShown(activationStep ~= nil)
    frame.candidateLabel:SetShown(activationStep == nil)
    frame.candidate:SetShown(activationStep == nil)
    frame.candidateDetails:SetShown(activationStep == nil)
    if activationStep then
        frame.activation.heading:SetText(self:L("activation_heading", activationStep))
        local tooltip = {frame.activation.heading:GetText() or ""}
        for i, text in ipairs(frame.activation.steps) do
            text:SetText(self:L("activation_" .. i))
            text:SetTextColor(unpack(i == activationStep and accent or {0.7, 0.7, 0.7}))
            tooltip[#tooltip + 1] = text:GetText() or ""
        end
        setHoverText(frame.candidatePanel, table.concat(tooltip, "\n"))
    else
        setHoverText(frame.candidatePanel, (frame.candidate:GetText() or "") .. "\n" .. (frame.candidateDetails:GetText() or ""))
    end
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
            if application.pending then
                if application.pending == "applied" then key = "application_sending"
                elseif application.pending == "cancelled" then key = "application_cancelling"
                else key = "application_pending" end
            end
            local status = self:L(key)
            if status == key then status = self:L("application_unknown") end
            row.details:SetText(self:L("application_details", status, age(application.age), self:L(application.owned and "own_application" or "manual_application")))
            local tone = application.pending and tones.waiting
                or (application.status == "invited" or application.status == "inviteaccepted") and tones.invited
                or tones.stopped
            row.details:SetTextColor(unpack(tone))
            setHoverText(row, (row.name:GetText() or "") .. "\n" .. (row.details:GetText() or ""))
            row.cancel:SetText(self:L("cancel"))
            row.cancel:SetEnabled(application.owned == true)
        else
            setHoverText(row, nil)
        end
    end
    frame.toggle:SetText(self:L(view.running and "stop" or "start"))
    frame.step:SetText(self:L("step"))
    frame.step:SetEnabled(view.running and not self.bindingCapture)
    frame.open:SetText(self:L("open_search"))
    frame.settings:SetText(self:L("settings"))
    setHoverText(frame.close, self:L("hide_window"))
    if self.groupFinderButton then
        setHoverText(self.groupFinderButton, self:L("title") .. "\n" .. self:L("binding_window"))
    end
    if self.settingsUI and self.settingsUI:IsShown() then self.settingsUI:Refresh() end
end
