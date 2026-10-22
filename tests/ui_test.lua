local PTG = {}
local source = arg and arg[0] and arg[0]:gsub("\\", "/") or "tests/ui_test.lua"
local root = source:match("^(.*)/tests/[^/]+$") or "."
local checks = 0
local function check(value, message)
    assert(value, message)
    checks = checks + 1
end
local function paint(widget)
    return table.concat(widget.background or {}, ",") .. ";" .. table.concat(widget.border or {}, ",")
end

GetLocale = function() return "ruRU" end
IsShiftKeyDown = function() return false end
local combat, modifiers = false, ""
local keyboardDown = {}
IsKeyDown = function(key) return keyboardDown[key] == true end
InCombatLockdown = function() return combat end
GetBindingText = function(key) return key end
GetBindingName = function(action) return "Action: " .. action end
GetConvertedKeyOrButton = function(key) return key end
IsKeyPressIgnoredForBinding = function(key)
    return key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" or key == "LSHIFT" or key == "RSHIFT"
end
CreateKeyChordStringUsingMetaKeyState = function(key) return modifiers .. key end
local stepKey1, stepKey2, stepKeyError, bindingAction, bindingSet = "F8", "F9", nil, "", 1
local assignCalls, clearCalls, bindingFailure = {}, 0, nil
PTG.Input = {
    GetStepKeys = function() return stepKey1, stepKey2, stepKeyError end,
    GetStepKeyAction = function() return bindingAction, bindingSet end,
    AssignStepKey = function(key, action, currentSet)
        assignCalls[#assignCalls + 1] = { key = key, action = action, currentSet = currentSet }
        if bindingFailure then return false, bindingFailure end
        return true, "binding_saved"
    end,
    ClearStepKey = function()
        clearCalls = clearCalls + 1
        if bindingFailure then return false, bindingFailure end
        return true, "binding_cleared"
    end,
}
unpack = unpack or table.unpack
tinsert = table.insert
UISpecialFrames = {}
wipe = function(values) for key in pairs(values) do values[key] = nil end end

local Widget = {}
Widget.__index = Widget
function Widget:new() return setmetatable({ scripts = {}, shown = true, enabled = true }, self) end
function Widget:SetScript(event, callback) self.scripts[event] = callback end
function Widget:HookScript(event, callback)
    local previous = self.scripts[event]
    self.scripts[event] = function(...)
        if previous then previous(...) end
        callback(...)
    end
end
function Widget:SetText(text) self.text = text end
function Widget:GetText()
    if self.kind == "FontString" and (self.text == nil or self.text == "") then return nil end
    return self.text or ""
end
function Widget:SetNumber(number) self:SetText(tostring(number)) end
function Widget:SetHeight(height) self.height = height end
function Widget:SetSize(width, height) self.width, self.height = width, height end
function Widget:SetPoint(...)
    self.point = { ... }
    self.points = self.points or {}
    self.points[#self.points + 1] = self.point
end
function Widget:ClearAllPoints() self.point, self.points = nil, {} end
function Widget:SetNormalTexture(texture) self.normalTexture = { texture = texture } end
function Widget:GetNormalTexture() return self.normalTexture end
function Widget:RegisterForClicks(...) self.clicks = { ... } end
function Widget:SetOwner(owner, anchor) self.owner, self.anchor = owner, anchor end
function Widget:AddLine(text) self.line = text end
function Widget:SetChecked(checked) self.checked = checked end
function Widget:GetChecked() return self.checked end
local function checkedTexture(control, texture)
    assert(control.kind == "CheckButton", "checked textures belong to native check buttons")
    if type(texture) == "string" then
        local region = Widget:new()
        region.kind, region.parent, region.texture = "Texture", control, texture
        return region
    end
    assert(texture == nil or (type(texture) == "table" and texture.kind == "Texture"), "expected a texture path or region")
    return texture
end
function Widget:SetCheckedTexture(texture) self.checkedTexture = checkedTexture(self, texture) end
function Widget:GetCheckedTexture() return self.checkedTexture end
function Widget:SetDisabledCheckedTexture(texture) self.disabledCheckedTexture = checkedTexture(self, texture) end
function Widget:GetDisabledCheckedTexture() return self.disabledCheckedTexture end
function Widget:SetEnabled(enabled) self.enabled = enabled end
function Widget:IsEnabled() return self.enabled end
function Widget:SetAlpha(alpha) self.alpha = alpha end
local function visibilityEvent(widget, event)
    if widget.scripts[event] then widget.scripts[event](widget) end
    for _, child in ipairs(widget.children or {}) do
        if child.shown then visibilityEvent(child, event) end
    end
end
function Widget:Show()
    local wasVisible = self:IsVisible()
    self.shown = true
    if not wasVisible and self:IsVisible() then visibilityEvent(self, "OnShow") end
end
function Widget:Hide()
    local wasVisible = self:IsVisible()
    self.shown = false
    if wasVisible then visibilityEvent(self, "OnHide") end
end
function Widget:SetShown(shown) if shown then self:Show() else self:Hide() end end
function Widget:IsShown() return self.shown end
function Widget:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Widget:IsMouseOver() return self.mouseOver == true end
function Widget:GetWidth() return self.width or 0 end
function Widget:GetHeight() return self.height or 0 end
local anchors = {
    TOPLEFT = {0, 1}, TOP = {0.5, 1}, TOPRIGHT = {1, 1},
    LEFT = {0, 0.5}, CENTER = {0.5, 0.5}, RIGHT = {1, 0.5},
    BOTTOMLEFT = {0, 0}, BOTTOM = {0.5, 0}, BOTTOMRIGHT = {1, 0},
}
local function geometry(widget)
    -- shortcut: only the final anchor is resolved; extend before testing stretched frame geometry.
    local point = widget.point
    if not point then return widget.left or 0, widget.top or 0 end
    local relative, relativePoint, x, y
    if type(point[2]) == "number" then
        relative, relativePoint, x, y = widget.parent, point[1], point[2], point[3]
    else
        relative, relativePoint, x, y = point[2] or widget.parent, point[3] or point[1], point[4], point[5]
    end
    local own, target = assert(anchors[point[1]]), assert(anchors[relativePoint])
    return relative:GetLeft() + relative:GetWidth() * target[1] + (x or 0) - widget:GetWidth() * own[1],
        relative:GetTop() - relative:GetHeight() * (1 - target[2]) + (y or 0) + widget:GetHeight() * (1 - own[2])
end
function Widget:GetLeft() local left = geometry(self); return left end
function Widget:GetTop() local _, top = geometry(self); return top end
function Widget:GetCenter() return self:GetLeft() + self:GetWidth() / 2, self:GetTop() - self:GetHeight() / 2 end
function Widget:GetParent() return self.parent end
function Widget:GetStringHeight() return self.stringHeight or 12 end
local focusedWidget
GetCurrentKeyBoardFocus = function() return focusedWidget end
function Widget:HasFocus() return self == focusedWidget end
function Widget:SetFocus()
    assert(self.kind == "EditBox", "only edit boxes receive text focus")
    if focusedWidget == self then return end
    if focusedWidget then focusedWidget:ClearFocus() end
    focusedWidget = self
    if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end
end
function Widget:ClearFocus()
    if focusedWidget ~= self then return end
    focusedWidget = nil
    if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
end
local function globalMouseDown()
    -- Blizzard's GLOBAL_MOUSE_DOWN handler runs this focus check before button OnClick.
    if focusedWidget and not (focusedWidget.HasStickyFocus and focusedWidget:HasStickyFocus()) then
        focusedWidget:ClearFocus()
    end
end
function Widget:HighlightText(first, last)
    assert(self.kind == "EditBox", "only edit boxes highlight editable text")
    self.selection = {first or 0, last or #self:GetText()}
end
function Widget:SetTextInsets(...) self.textInsets = { ... } end
function Widget:SetFontObject(font) self.font = font end
function Widget:SetWordWrap(wrap) self.wordWrap = wrap end
function Widget:CreateFontString()
    local widget = Widget:new()
    widget.kind, widget.parent = "FontString", self
    return widget
end
function Widget:CreateTexture()
    local widget = Widget:new()
    widget.kind, widget.parent = "Texture", self
    return widget
end
function Widget:GetOwner() return self.owner end
function Widget:SetTextColor(...) self.color = { ... } end
function Widget:SetColorTexture(...) self.color = { ... } end
function Widget:SetVertexColor(...) self.vertexColor = { ... } end
function Widget:SetBackdropColor(...) self.background = { ... } end
function Widget:SetBackdropBorderColor(...) self.border = { ... } end
function Widget:EnableKeyboard(enabled) self.keyboardEnabled = enabled end
function Widget:SetPropagateKeyboardInput(propagate) self.propagateKeyboard = propagate end
for _, method in ipairs({ "SetJustifyH", "SetJustifyV", "SetWidth", "SetFrameStrata",
    "SetBackdrop", "SetClampedToScreen", "SetMovable", "EnableMouse",
    "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "SetAutoFocus", "SetNumeric", "SetMaxLetters",
    "SetScrollChild", "SetHighlightTexture",
    "SetNormalFontObject", "SetDisabledFontObject" }) do
    Widget[method] = function() end
end
function Widget:SetWidth(width) self.width = width end
CreateFrame = function(kind, name, parent, template)
    local widget = Widget:new()
    widget.kind, widget.name, widget.parent, widget.template = kind, name, parent, template
    if kind == "EditBox" and template and template:find("InputBoxScriptTemplate", 1, true) then
        widget:SetScript("OnEditFocusGained", function(edit) edit:HighlightText() end)
        widget:SetScript("OnEditFocusLost", function(edit) edit:HighlightText(0, 0) end)
        widget:SetScript("OnEscapePressed", function(edit) edit:ClearFocus() end)
        widget:SetScript("OnTabPressed", function(edit)
            if edit.previousEditBox and IsShiftKeyDown() then edit.previousEditBox:SetFocus()
            elseif edit.nextEditBox then edit.nextEditBox:SetFocus() end
        end)
    end
    if parent then
        parent.children = parent.children or {}
        table.insert(parent.children, widget)
    end
    return widget
end
UIParent = Widget:new()
UIParent:SetSize(1920, 1080)
UIParent.left, UIParent.top = 0, 1080
Minimap = Widget:new()
GameTooltip = Widget:new()

assert(loadfile(root .. "/Locale.lua"))("PressToGroup", PTG)
assert(loadfile(root .. "/Engine.lua"))("PressToGroup", PTG)
local dictionaries
for i = 1, 10 do
    local key, value = debug.getupvalue(PTG.L, i)
    if not key then break end
    if key == "strings" then dictionaries = value end
end
check(dictionaries ~= nil, "locale dictionaries are accessible for parity check")
local function formats(text)
    local result = {}
    for item in text:gmatch("%%[^%%]-[cdeEfgGiouXxqs]") do result[#result + 1] = item end
    return table.concat(result, ";")
end
for key, value in pairs(dictionaries.enUS) do
    check(dictionaries.ruRU[key] ~= nil, "missing Russian key: " .. key)
    check(formats(value) == formats(dictionaries.ruRU[key]), "format mismatch: " .. key)
end
for key in pairs(dictionaries.ruRU) do
    check(dictionaries.enUS[key] ~= nil, "missing English key: " .. key)
end
for _, key in ipairs({ "filters_changed", "off", "grouped", "chat_lockdown", "unsupported", "manual_search",
    "unavailable", "no_query", "no_role", "no_dungeons_selected", "search_conflict", "search_timeout", "search_failed", "search_empty", "no_candidates",
    "wait_apply", "wait_cancel", "apply_sent", "cancel_sent", "wait_roles", "ready_cancel_company_full", "cancel_company_full",
    "company_changed", "company_not_leader", "company_raid", "company_full", "company_instance", "company_unknown",
    "company_roles_unknown", "company_roles_invalid", "company_offline" }) do
    check(dictionaries.enUS[key] ~= nil, "unlocalized dynamic state: " .. key)
end

PTG.db = { locale = "auto", role = "HEALER", autoRole = true, compactMode = false, inputMode = "auto", minRating = 3000, replaceAfter = 180,
    dungeons = { [101] = true }, languages = { enUS = true } }
local view = { state = "waiting_search", stateArgs = { 6 }, running = false, found = 9, eligible = 2,
    active = 2, limit = 5, lastResponse = 65, searchText = "12", nextCandidate = {
        id = 1, name = "Next group", dungeon = "Dungeon", age = 10, leaderRating = 3000,
    }, applications = {
        { id = 1, name = "Own group", status = "applied", owned = true, age = 60 },
        { id = 2, name = "Manual group", status = "invited", owned = false },
    } }
function PTG:GetView() return view end
function PTG:GetDungeons() return { { id = 101, name = "First dungeon" }, { id = 102, name = "Second dungeon" } } end
function PTG:GetLanguages()
    return { { id = "ruRU", name = "Russian", mandatory = true, selected = true },
        { id = "enUS", name = "English", mandatory = false, selected = self.db.languages.enUS } }
end
function PTG:SettingsChanged() self.settingsChanged = (self.settingsChanged or 0) + 1 end
function PTG:SetRole(role) self.selectedRole, self.db.role = role, role end
function PTG:SyncRole()
    self.roleSyncs = (self.roleSyncs or 0) + 1
    if self.db.autoRole then self:SetRole(self.specRole) end
end
function PTG:SetInputMode(mode)
    self:CancelBindingCapture()
    self.db.inputMode = mode
    self:RefreshUI()
end
PTG.specRole = "HEALER"
function PTG:OnPress() self.steps = (self.steps or 0) + 1 end
function PTG:Cancel(id) self.cancelled = id end
function PTG:Start() self.started = true end
function PTG:Stop() self.stopped = true end
function PTG:OpenSearch() self.searchOpened = true end
function PTG:PrintLog() self.logOpened = true end
function PTG:ToggleWindow() self.windowToggles = (self.windowToggles or 0) + 1 end

assert(loadfile(root .. "/UI.lua"))("PressToGroup", PTG)
check(PTG:ShowWelcome() == false and PTG.welcomeUI == nil, "welcome waits until the main UI exists")
local initialCandidate, initialApplications = view.nextCandidate, view.applications
view.nextCandidate, view.applications = nil, {}
PTG:BuildUI()
check(not PTG.ui:IsShown() and PTG.welcomeUI == nil and not PTG.stopped,
    "initial main window is hidden without stopping and welcome is built only on demand")
check(PTG.dungeonPicker and not PTG.dungeonPicker:IsShown(), "quick dungeon selection starts closed")
PTG:RefreshUI()
check(not PTG.ui:IsShown(), "regular UI refresh does not open the initial main window")
PTG.ui:Show()
check(PTG.ui.toggle.text == PTG:L("start") and PTG.ui.step.text == PTG:L("step")
    and PTG.ui.settings.text == PTG:L("settings"), "initial empty search completes button labels")
check(PTG.ui.empty:IsShown() and not PTG.ui.rows[1]:IsShown() and not PTG.ui.rows[5]:IsShown(),
    "initial empty search hides every unused application row")
check(PTG.ui.open.text == PTG:L("open_search") and PTG.ui.log == nil,
    "main footer labels its search button without a diagnostics control")
PTG.ui.settings.scripts.OnClick()
check(PTG.settingsUI:IsShown(), "the settings button opens settings from the initial empty search")
check(PTG.settingsUI.close.text == PTG:L("close") and PTG.settingsUI.dismiss and PTG.settingsUI.dismiss.text == "×",
    "the initial settings page labels both close controls")
check(PTG.settingsUI.log.parent == PTG.settingsUI and PTG.settingsUI.log.text == PTG:L("log"),
    "diagnostics belongs to Settings and is labeled on first opening")
PTG.ui.settings.scripts.OnClick()
check(not PTG.settingsUI:IsShown(), "the settings button can hide settings again")
for _, close in ipairs({PTG.settingsUI.close, PTG.settingsUI.dismiss}) do
    PTG.settingsUI:Show()
    local changedBefore = PTG.settingsChanged
    close.scripts.OnClick()
    check(not PTG.settingsUI:IsShown() and not PTG.started and not PTG.stopped and not PTG.steps
        and PTG.settingsChanged == changedBefore, "either settings close control only hides the page")
end
PTG.ui.open.scripts.OnClick()
PTG.settingsUI.log.scripts.OnClick()
check(PTG.searchOpened and PTG.logOpened and not PTG.started and not PTG.stopped and not PTG.steps,
    "opening native search and diagnostics does not perform an assistant step")
PTG.ui.toggle.scripts.OnClick()
check(PTG.started and not PTG.stopped, "the start button is usable from the initial empty search")
view.running = true
PTG.ui.toggle.scripts.OnClick()
check(PTG.stopped, "the same control stops a running assistant")
view.running = false
PTG.started, PTG.stopped, PTG.searchOpened, PTG.logOpened = nil, nil, nil, nil
view.nextCandidate, view.applications = initialCandidate, initialApplications
PTG:RefreshUI()
local minimap = PTG.minimapButton
check(minimap.kind == "Button" and minimap.name == "PressToGroupMinimapButton" and minimap.parent == Minimap
    and minimap.width >= 20, "named minimap button is discoverable by EllesmereUI without its API")
check(minimap.icon.texture == "Interface\\AddOns\\PressToGroup\\Media\\Icon", "minimap uses the approved icon")
check(minimap.clicks[1] == "LeftButtonUp" and #minimap.clicks == 1, "minimap registers only left-click release")
minimap.scripts.OnClick()
check(PTG.windowToggles == 1 and not PTG.steps and not PTG.started and not PTG.stopped,
    "minimap click only invokes the existing window toggle")
minimap.scripts.OnEnter(minimap)
check(GameTooltip.owner == minimap and GameTooltip:IsShown() and GameTooltip.line == PTG:L("binding_window"),
    "minimap tooltip explains the window action in the current language")
minimap.scripts.OnLeave()
check(not GameTooltip:IsShown(), "leaving the minimap button hides its tooltip")
PTG:BuildUI()
check(PTG.minimapButton == minimap, "building UI twice does not duplicate the minimap button")
local escapes, settingsEscapes = 0, 0
for _, name in ipairs(UISpecialFrames) do
    if name == "PressToGroupFrame" then escapes = escapes + 1 end
    if name == "PressToGroupSettings" then settingsEscapes = settingsEscapes + 1 end
end
check(escapes == 1, "the stopped main window is registered for Escape exactly once")
check(settingsEscapes == 1, "settings remain registered for Escape exactly once")
check(PTG.ui.width == 440 and PTG.ui.height == 620, "search window has room for readable sections and five rows")
local drag
for _, child in ipairs(PTG.ui.children) do
    if child.height == 25 and child.scripts.OnDragStart then drag = child end
end
check(drag and PTG.ui.width + drag.point[2] < PTG.ui.width + PTG.ui.close.point[2] - PTG.ui.close.width,
    "the title drag area ends before the close button's mouse area")
PTG.ui.close.scripts.OnClick()
check(not PTG.ui:IsShown() and not PTG.started and not PTG.stopped and not PTG.steps,
    "closing the stopped window does not call Stop again")
PTG.ui:Show()
check(PTG.ui.status.text == PTG:L("waiting_search", 6), "state arguments are formatted")
check(PTG.ui.role.text == "Роль: Лекарь / Авто", "main window shows the effective role and auto mode in Russian")
check(PTG.ui.statusHeading.width + 14 < PTG.ui.statusPanel.width - 12 - PTG.ui.role.width,
    "role indicator has its own space beside the state heading")
check(PTG.ui.metrics[1].value.text == "9" and PTG.ui.metrics[2].value.text == "2"
    and PTG.ui.metrics[3].value.text == "2/5", "search counts and application limit are separate readable values")
check(PTG.ui.status.point[3] - PTG.ui.status.height > PTG.ui.response.point[3], "status does not overlap response time")
check(PTG.ui.rows[5].point[3] - PTG.ui.rows[5].height > PTG.ui.toggle.point[3], "five application rows do not overlap actions")
check(PTG.ui.response.text:find("1 мин 05 с", 1, true), "elapsed response time is displayed")
check(PTG.ui.rows[2].details.text:find(PTG:L("unknown_age"), 1, true), "unknown application age is not displayed as zero")
PTG.ui.step.scripts.OnClick()
check(PTG.steps == 1, "step click invokes exactly one input step")
PTG.ui.rows[1].cancel.scripts.OnClick()
check(PTG.cancelled == 1, "owned application can be cancelled")
PTG.cancelled = nil
PTG.ui.rows[2].cancel.scripts.OnClick()
check(PTG.cancelled == nil and not PTG.ui.rows[2].cancel.enabled, "unknown ownership cannot be cancelled")
PTG.settingsUI:Show()
local autoRole = PTG.settingsUI.autoRole
check(autoRole:GetChecked() and PTG.settingsUI.roleButtons[2].enabled,
    "auto mode is checked and the current role remains available for manual override")
check(paint(PTG.settingsUI.roleButtons[2]) ~= paint(PTG.settingsUI.roleButtons[1]),
    "the effective role has a selected visual even when all role buttons remain clickable")
check(paint(PTG.settingsUI.localeButtons[1]) ~= paint(PTG.settingsUI.localeButtons[3]),
    "the chosen interface language has an explicit selected visual")
local settingsChanged = PTG.settingsChanged
PTG.settingsUI.roleButtons[2].scripts.OnClick()
check(PTG.db.autoRole == false and PTG.selectedRole == "HEALER" and not autoRole:GetChecked()
    and not PTG.settingsUI.roleButtons[2].enabled,
    "clicking the current role disables auto and refreshes manual controls")
check(PTG.ui.role.text == "Роль: Лекарь / Вручную", "manual override is reflected in the main window")
check(paint(PTG.settingsUI.roleButtons[2]) ~= paint(PTG.settingsUI.roleButtons[3]),
    "the selected manual role remains visually distinct when its button is disabled")
autoRole:SetChecked(true)
autoRole.scripts.OnClick(autoRole)
check(PTG.db.autoRole and PTG.roleSyncs == 1 and PTG.db.role == "HEALER",
    "enabling auto immediately requests the specialization role")
PTG.specRole = "TANK"
autoRole:SetChecked(false)
autoRole.scripts.OnClick(autoRole)
check(not PTG.db.autoRole and PTG.db.role == "HEALER", "disabling auto keeps the effective role")
autoRole:SetChecked(true)
autoRole.scripts.OnClick(autoRole)
check(PTG.db.autoRole and PTG.selectedRole == "TANK" and PTG.db.role == "TANK",
    "re-enabling auto follows the current specialization instead of a remembered manual role")
check(PTG.settingsChanged == settingsChanged, "role controls delegate role changes without invalidating search directly")
local replacement = PTG.settingsUI.replaceAfter
check(replacement:GetText() == "180", "replacement age defaults to 180 seconds in settings")
replacement:SetText("90")
replacement.scripts.OnEditFocusLost(replacement)
check(PTG.db.replaceAfter == 90 and replacement:GetText() == "90" and PTG.settingsChanged == settingsChanged,
    "replacement age changes without invalidating search settings")
for _, invalid in ipairs({ "", "0", "-20", "1.5", "invalid", "1e999" }) do
    replacement:SetText(invalid)
    replacement.scripts.OnEditFocusLost(replacement)
    check(PTG.db.replaceAfter == 90 and replacement:GetText() == "90" and PTG.settingsChanged == settingsChanged,
        "invalid replacement age restores the previous value: " .. invalid)
end
replacement:SetText("30")
replacement.scripts.OnEscapePressed(replacement)
check(PTG.db.replaceAfter == 90 and replacement:GetText() == "90", "Escape discards an uncommitted replacement age")
check(PTG.ui.width == 440 and PTG.ui.height == 620, "replacement setting keeps the main window unchanged")
check(not PTG.settingsUI.languageChecks.ruRU.enabled, "mandatory language cannot be changed")
check(PTG.settingsUI.dungeonChecks[101]:GetChecked() and not PTG.settingsUI.dungeonChecks[102]:GetChecked(), "dungeon checkboxes show only explicit selections")
check(PTG.settingsUI.allDungeons.enabled, "all dungeons is available when a visible dungeon is unchecked")
PTG.settingsUI.localeButtons[3].scripts.OnClick()
check(PTG.db.locale == "enUS" and PTG.db.languages.enUS and PTG.db.dungeons[101], "UI language preserves search selections")
check(paint(PTG.settingsUI.localeButtons[3]) ~= paint(PTG.settingsUI.localeButtons[1]),
    "selecting another interface language moves the selected visual")
minimap.scripts.OnEnter(minimap)
check(GameTooltip.line == PTG:L("binding_window"), "minimap tooltip follows a language change")
minimap.scripts.OnLeave()
check(PTG.settingsUI.replaceAfterLabel.text == PTG:L("replace_after")
    and PTG.settingsUI.replaceAfterHint.text == PTG:L("replace_after_hint") and replacement:GetText() == "90",
    "replacement controls follow interface language without changing the saved age")
check(PTG.ui.role.text == "Role: Tank / Auto", "role indicator follows the interface language")
PTG.settingsUI.roleButtons[1].scripts.OnClick()
check(PTG.db.role == "TANK" and not PTG.db.autoRole and PTG.db.languages.enUS and PTG.db.dungeons[101], "manual role preserves other settings")
local dungeon = PTG.settingsUI.dungeonChecks[102]
dungeon:SetChecked(true)
dungeon.scripts.OnClick(dungeon)
check(PTG.db.dungeons[102] and PTG.db.dungeons[101], "dungeon selection adds only its own ID")
check(not PTG.settingsUI.allDungeons.enabled, "all dungeons is disabled when every visible dungeon is selected")
local firstDungeon = PTG.settingsUI.dungeonChecks[101]
firstDungeon:SetChecked(false)
firstDungeon.scripts.OnClick(firstDungeon)
check(PTG.db.dungeons[101] == nil and PTG.db.dungeons[102], "unchecking a dungeon preserves the other selection")
check(PTG.settingsUI.allDungeons.enabled, "all dungeons becomes available after unchecking a dungeon")
PTG.db.dungeonsInitialized = nil
dungeon:SetChecked(false)
dungeon.scripts.OnClick(dungeon)
PTG:RefreshUI()
check(next(PTG.db.dungeons) == nil and not firstDungeon:GetChecked() and not dungeon:GetChecked(), "zero checked dungeons remains an empty selection after refresh")
check(PTG.db.dungeonsInitialized, "explicit unchecking prevents late data from restoring the default selection")
check(PTG.settingsUI.allDungeons.enabled, "all dungeons can recover from an empty selection")
view.state, view.stateArgs = "no_dungeons_selected", {}
PTG:RefreshUI()
check(PTG.ui.status.text == PTG:L("no_dungeons_selected"), "empty dungeon selection has a localized paused status")
PTG.db.dungeons[999] = true
PTG.settingsUI.allDungeons.scripts.OnClick()
check(PTG.db.dungeons[101] and PTG.db.dungeons[102] and PTG.db.dungeons[999] == nil, "all dungeons explicitly selects the current season IDs")
check(firstDungeon:GetChecked() and dungeon:GetChecked() and not PTG.settingsUI.allDungeons.enabled, "all dungeons restores every checkbox")
check(PTG.db.dungeonsInitialized, "all dungeons preserves the initialized selection semantics")
PTG.settingsUI.rating:SetText("-12")
PTG.settingsUI.rating.scripts.OnEditFocusLost(PTG.settingsUI.rating)
check(PTG.db.minRating == 0, "rating is nonnegative")
view.applications = {}
PTG:RefreshUI()
check(PTG.ui.empty:IsShown() and not PTG.ui.rows[1]:IsShown(), "empty applications hide stale rows")
check(PTG:L("start") == "Start", "manual English override works on Russian client")
PTG.db.locale = "auto"
check(PTG:L("start") == "Включить", "automatic language follows client")
PTG.db.locale = "deDE"
check(PTG:L("start") == "Start", "unsupported locale falls back to English")
PTG.db.locale = "ruRU"
local frame = PTG.ui
for state, expected in pairs({ ready_search = "ready", ready_apply = "ready", ready_cancel = "ready", ready_cancel_role_full = "ready",
    ready_cancel_company_full = "ready", searching = "waiting", wait_apply = "waiting", wait_cancel = "waiting", wait_roles = "waiting", full = "waiting",
    manual_search = "paused", chat_lockdown = "paused", no_role = "paused", no_dungeons_selected = "paused",
    company_changed = "stopped", company_not_leader = "paused", company_raid = "paused", company_full = "paused",
    company_instance = "paused", company_unknown = "paused", company_roles_unknown = "paused", company_roles_invalid = "paused", company_offline = "paused",
    search_timeout = "error", search_conflict = "error", operation_unknown = "error",
    invited = "invited", off = "stopped", future_state = "unknown" }) do
    view.state, view.stateArgs = state, {}
    PTG:RefreshUI()
    check(frame.statusHeading.text == PTG:L("status_" .. expected),
        "state has an explicit visual category: " .. state)
end
PTG.db.role, PTG.db.autoRole = nil, true
view.state, view.stateArgs = "no_role", {}
PTG:RefreshUI()
check(frame.role.text == "Роль: Не определена / Авто" and frame.status.text == PTG:L("no_role"),
    "unknown specialization role is shown explicitly with its recovery instructions")
frame.statusPanel.scripts.OnEnter(frame.statusPanel)
check(GameTooltip.text:find(frame.role.text, 1, true), "status tooltip includes the full effective role and mode")
frame.statusPanel.scripts.OnLeave()
PTG.db.role = "HEALER"
local nativeReason = string.rep("Длинная штатная причина приостановки поиска. ", 12)
view.state, view.stateArgs = "native_pause", { nativeReason }
PTG:RefreshUI()
frame.statusPanel.scripts.OnEnter(frame.statusPanel)
check(GameTooltip.text:find(nativeReason, 1, true), "full native pause reason remains available in its tooltip")
frame.statusPanel.scripts.OnLeave()
view.nextCandidate.name = string.rep("Длинное название группы ", 12)
view.applications = {}
for i = 1, 5 do
    view.applications[i] = { id = i, name = string.rep("Long application name ", 12) .. i,
        status = "applied", owned = i == 1, age = i * 30 }
end
PTG:RefreshUI()
frame.candidatePanel.scripts.OnEnter(frame.candidatePanel)
check(GameTooltip.text:find(view.nextCandidate.name, 1, true), "candidate tooltip preserves a long full name")
frame.candidatePanel.scripts.OnLeave()
for i, row in ipairs(frame.rows) do
    check(row:IsShown() and row.tooltip:find(view.applications[i].name, 1, true), "all five long application names have full tooltips")
end
local row = frame.rows[1]
row.scripts.OnEnter(row)
view.applications[1] = { id = 91, name = "Заявка ожидает отправки", status = "none", pending = "applied", owned = false }
PTG:RefreshUI()
check(row.details.text:find(PTG:L("application_sending"), 1, true)
    and not row.details.text:find(PTG:L("application_none"), 1, true), "pending submission is not reported as no application")
check(GameTooltip.text:find(view.applications[1].name, 1, true)
    and not GameTooltip.text:find("Long application name", 1, true), "tooltip updates when a hovered row is reused")
check(row.details.text:find(PTG:L("unknown_age"), 1, true) and not row.cancel.enabled,
    "an unknown application age is preserved and pending applications cannot be cancelled")
view.applications[1].status, view.applications[1].pending = "applied", "cancelled"
PTG:RefreshUI()
check(row.details.text:find(PTG:L("application_cancelling"), 1, true), "pending cancellation has a transitional label")
view.applications[1].pending = "future_pending_state"
PTG:RefreshUI()
check(row.details.text:find(PTG:L("application_pending"), 1, true), "unknown pending status does not claim success")
view.applications[1].status, view.applications[1].pending, view.applications[1].age = "invited", nil, 65
PTG:RefreshUI()
check(row.details.text:find(PTG:L("application_invited"), 1, true)
    and row.details.text:find(PTG:L("age", 1, 5), 1, true) and not row.cancel.enabled,
    "an invitation preserves known age without granting ownership")
PTG.db.locale = "enUS"
PTG:RefreshUI()
check(GameTooltip.text:find("Invited", 1, true), "hovered application tooltip follows interface language changes")
view.applications = {}
PTG:RefreshUI()
check(not GameTooltip:IsShown() and row.tooltip == nil and not row:IsShown(), "removing a hovered row clears its tooltip")
view.nextCandidate = {name = "", dungeon = "", id = 7}
view.applications = {{id = 7, name = "", status = "applied", owned = true}}
PTG:RefreshUI()
check(row.cancel.text == PTG:L("cancel") and frame.toggle.text == PTG:L("start"),
    "empty native candidate and application names do not interrupt button updates")

PTG:BuildGroupFinderButton()
check(PTG.groupFinderButton == nil, "a missing Group Finder does not block addon startup")
local nativeShows = 0
local search = Widget:new()
search:SetScript("OnShow", function() nativeShows = nativeShows + 1 end)
LFGListFrame = {SearchPanel = search}
PTG:BuildGroupFinderButton()
local groupFinder = PTG.groupFinderButton
check(groupFinder and groupFinder.parent == search and groupFinder.text == "PTG"
    and groupFinder.clicks[1] == "LeftButtonUp", "the native search gets a PTG toggle without PGF")
check(groupFinder.point[1] == "TOPRIGHT" and groupFinder.point[5] == -6,
    "without PGF the toggle stays above the search and filter row")
local toggles, steps, started, stopped = PTG.windowToggles, PTG.steps, PTG.started, PTG.stopped
groupFinder.scripts.OnClick()
check(PTG.windowToggles == toggles + 1 and PTG.steps == steps and PTG.started == started and PTG.stopped == stopped,
    "the native PTG button only toggles the window")
UsePGFButton = Widget:new()
UsePGFButton.parent = search
search:Hide()
search:Show()
check(nativeShows == 1 and groupFinder.point[1] == "RIGHT" and groupFinder.point[2] == UsePGFButton
    and groupFinder.point[4] == -8, "late PGF positioning preserves the native OnShow handler and leaves a mouse gap")
PTG:BuildGroupFinderButton()
check(PTG.groupFinderButton == groupFinder and #search.children == 1, "repeated native integration creates one button")
groupFinder.scripts.OnEnter(groupFinder)
check(GameTooltip.text:find(PTG:L("binding_window"), 1, true), "the native PTG button explains its window toggle")
PTG.db.locale = "ruRU"
PTG:RefreshUI()
check(GameTooltip.text:find(PTG:L("binding_window"), 1, true), "the hovered native toggle follows the interface language")
groupFinder.scripts.OnLeave()

local settings = PTG.settingsUI
settings:Show()
check(settings.log:GetLeft() + settings.log.width < settings.saved:GetLeft()
    and settings.saved:GetLeft() + settings.saved.width < settings.close:GetLeft(),
    "settings footer separates diagnostics, the saved hint, and close without overlap")
check(settings.width == 440 and settings.height == 620 and settings.content.width == 384,
    "settings use the same window size as the main page with a bounded scrolling column")
local function offsets(widget)
    local point = assert(widget.point, "positioned widget")
    if type(point[2]) == "number" then return point[2], point[3] end
    return point[4], point[5]
end
local function checkCards(message)
    local previous, lastY
    for _, key in ipairs({"role", "composition", "dungeons", "languages"}) do
        local section = assert(settings.sections[key], "missing settings section: " .. key)
        local x, y = offsets(section)
        check(section.width == 384 and section.height > 0 and section.background and section.border,
            "each settings section is a full-width styled card: " .. key .. " / " .. message)
        check(x >= 0 and x + section.width <= settings.content.width,
            "settings cards stay within the scroll column: " .. key .. " / " .. message)
        if previous then
            check(lastY - previous.height >= y, "settings cards do not overlap: " .. key .. " / " .. message)
        end
        previous, lastY = section, y
    end
    check(settings.content.height >= -lastY + previous.height, "scroll content includes the last card: " .. message)
end
checkCards("initial lists")
local controls = {settings.autoRole, settings.compositionChecks[1], settings.compositionChecks[2],
    settings.compositionChecks[3], settings.dungeonChecks[101], settings.languageChecks.ruRU}
for _, control in ipairs(controls) do
    local textX = offsets(control.text)
    check(control.kind == "CheckButton" and control.width == 360 and control.height >= 30,
        "checkbox labels are inside a full-row native check button hit area")
    check(control.text.parent == control and textX >= 30 and textX + control.text.width <= control.width,
        "checkbox labels have room after the check mark inside the clickable row")
    check(control:GetCheckedTexture().texture == "Interface\\Buttons\\UI-CheckBox-Check"
        and control:GetDisabledCheckedTexture().texture == "Interface\\Buttons\\UI-CheckBox-Check",
        "enabled and disabled native checked states use the custom check mark")
end
local mandatory = settings.languageChecks.ruRU
check(mandatory:GetChecked() and not mandatory.enabled and mandatory.text.font ~= "GameFontDisableSmall",
    "mandatory search language stays checked and readable while disabled")
for _, edit in ipairs({settings.rating, settings.replaceAfter}) do
    check(edit.template:find("InputBoxScriptTemplate", 1, true) and edit.template:find("BackdropTemplate", 1, true)
        and edit.font and edit.textInsets
        and edit.textInsets[1] >= 6 and edit.textInsets[2] >= 6,
        "numeric controls have their own backdrop, font, and readable text insets")
end
local previousRating, changedBeforeFocus = PTG.db.minRating, PTG.settingsChanged
local idlePaint = paint(settings.rating)
settings.rating:SetFocus()
check(paint(settings.rating) ~= idlePaint, "focused rating input has an explicit focus highlight")
check(settings.rating.selection[1] == 0 and settings.rating.selection[2] == #tostring(previousRating),
    "rating focus retains the inherited full-number text selection")
settings.rating:SetText("4321")
PTG:RefreshUI()
check(settings.rating:GetText() == "4321" and PTG.db.minRating == previousRating and settings.rating:HasFocus(),
    "refresh preserves the focused rating draft without committing it")
settings.rating.scripts.OnTabPressed(settings.rating)
check(settings.rating:HasFocus() and settings.rating:GetText() == "4321" and PTG.db.minRating == previousRating
    and PTG.settingsChanged == changedBeforeFocus, "native Tab without another edit box preserves the focused rating draft")
settings.rating.scripts.OnEscapePressed(settings.rating)
check(not settings.rating:HasFocus() and settings.rating:GetText() == tostring(previousRating)
    and PTG.db.minRating == previousRating and PTG.settingsChanged == changedBeforeFocus,
    "Escape discards a focused rating draft without changing search settings")
local previousReplacement = PTG.db.replaceAfter
settings.replaceAfter:SetFocus()
check(settings.replaceAfter.selection[1] == 0 and settings.replaceAfter.selection[2] == #tostring(previousReplacement),
    "replacement-age focus retains the inherited full-number text selection")
settings.replaceAfter:SetText("75")
PTG:RefreshUI()
check(settings.replaceAfter:GetText() == "75" and PTG.db.replaceAfter == previousReplacement
    and settings.replaceAfter:HasFocus(), "refresh preserves the focused replacement-age draft")
settings.replaceAfter.scripts.OnTabPressed(settings.replaceAfter)
check(settings.replaceAfter:HasFocus() and settings.replaceAfter:GetText() == "75"
    and PTG.db.replaceAfter == previousReplacement and PTG.settingsChanged == changedBeforeFocus,
    "native Tab without another edit box preserves the focused replacement-age draft")
settings.replaceAfter.scripts.OnEnterPressed(settings.replaceAfter)
check(not settings.replaceAfter:HasFocus() and PTG.db.replaceAfter == 75
    and settings.replaceAfter:GetText() == "75" and PTG.settingsChanged == changedBeforeFocus,
    "Enter commits a focused replacement age without invalidating search settings")

local getDungeons, getLanguages = PTG.GetDungeons, PTG.GetLanguages
function PTG:GetDungeons() return {} end
function PTG:GetLanguages() return {} end
PTG:RefreshUI()
check(settings.dungeonEmpty:IsShown() and settings.languageEmpty:IsShown()
    and not settings.dungeonChecks[101]:IsShown() and not settings.languageChecks.ruRU:IsShown()
    and not settings.allDungeons.enabled, "temporarily empty native lists show hints and hide cached rows")
checkCards("empty lists")
local dungeonName = string.rep("Длинное название подземелья ", 5)
local languageName = string.rep("Длинное название языка ", 5)
function PTG:GetDungeons() return {{id = 301, name = dungeonName}, {id = 302, name = "Позднее подземелье"}} end
function PTG:GetLanguages() return {{id = "late", name = languageName, mandatory = true, selected = true}} end
PTG:RefreshUI()
local lateDungeon, lateLanguage = settings.dungeonChecks[301], settings.languageChecks.late
lateDungeon.text.stringHeight, lateLanguage.text.stringHeight = 48, 36
PTG:RefreshUI()
check(not settings.dungeonEmpty:IsShown() and not settings.languageEmpty:IsShown()
    and lateDungeon:IsShown() and lateLanguage:IsShown(), "late native lists replace empty hints with their new rows")
check(lateDungeon.text:GetText() == dungeonName and lateDungeon.text.wordWrap ~= false
    and lateDungeon.height >= lateDungeon.text:GetStringHeight() + 16,
    "long dungeon names remain complete and expand their full clickable row")
check(lateLanguage.text:GetText():find(languageName, 1, true) and lateLanguage.text.wordWrap ~= false
    and lateLanguage.height >= lateLanguage.text:GetStringHeight() + 16
    and lateLanguage:GetChecked() and not lateLanguage.enabled,
    "long mandatory language names remain complete, checked, and readable")
local _, firstY = offsets(lateDungeon)
local _, secondY = offsets(settings.dungeonChecks[302])
check(firstY - lateDungeon.height >= secondY, "the next dungeon row moves below a wrapped long name")
checkCards("wrapped late lists")
lateDungeon:SetChecked(true)
lateDungeon.scripts.OnClick(lateDungeon)
check(PTG.db.dungeons[301] and lateDungeon:GetChecked(), "clicking the full late dungeon row updates its explicit selection")
PTG.GetDungeons, PTG.GetLanguages = getDungeons, getLanguages
PTG:RefreshUI()
check(not lateDungeon:IsShown() and not lateLanguage:IsShown() and settings.dungeonChecks[101]:IsShown()
    and settings.languageChecks.ruRU:IsShown() and PTG.db.dungeons[301],
    "returning native lists hide stale rows without erasing saved selections")

settings:Hide()
local activation = assert(frame.activation, "the candidate panel contains the activation guide")
local guideX, guideY = offsets(activation)
check(frame.width == 440 and frame.height == 620 and frame.candidatePanel.height == 88
    and activation.parent == frame.candidatePanel and guideX >= 0 and guideY <= 0
    and guideX + activation.width <= frame.candidatePanel.width
    and -guideY + activation.height <= frame.candidatePanel.height,
    "the activation guide stays inside the existing candidate panel and main-window geometry")
local guideLabels = {activation.heading, unpack(activation.steps)}
for _, text in ipairs(guideLabels) do
    local x, y = offsets(text)
    check(text.parent == activation and x >= 0 and y <= 0 and x + text.width <= activation.width
        and -y + text.height <= activation.height, "each activation line fits inside its guide frame")
end
local refreshSteps, refreshStarts, refreshStops, refreshSettings = PTG.steps, PTG.started, PTG.stopped, PTG.settingsChanged
local nativeFinder = LFGListFrame
LFGListFrame = {IsVisible = function() error("the UI must use view.groupFinderVisible") end}
view.nextCandidate, view.stateArgs = nil, {}
view.applications = {}
for i = 1, 5 do
    view.applications[i] = {id = i, name = "Existing application " .. i, status = "applied", owned = false}
end
local function checkGuide(current, message)
    check(activation:IsShown() == (current ~= nil)
        and frame.candidateLabel:IsShown() == (current == nil)
        and frame.candidate:IsShown() == (current == nil)
        and frame.candidateDetails:IsShown() == (current == nil), "guide and candidate content are mutually exclusive: " .. message)
    if not current then return end
    check(activation.heading:GetText() == PTG:L("activation_heading", current)
        and activation.heading:GetText():find(current .. "/4", 1, true), "activation heading includes its current step: " .. message)
    for i, text in ipairs(activation.steps) do
        local expected = i == current and {12 / 255, 210 / 255, 157 / 255} or {0.7, 0.7, 0.7}
        check(text:GetText() == PTG:L("activation_" .. i) and text.color[1] == expected[1]
            and text.color[2] == expected[2] and text.color[3] == expected[3],
            "activation text and current-step color stay in sync: " .. i .. " / " .. message)
    end
end
PTG.db.locale = "ruRU"
for _, state in ipairs({"off", "no_query", "manual_search"}) do
    for _, scenario in ipairs({
        {query = nil, visible = false, running = false, current = 1},
        {query = "", visible = true, running = true, current = 1},
        {query = "+19", visible = true, running = false, current = 2},
        {query = "+19", visible = false, running = false, current = 3},
        {query = "+19", visible = false, running = true},
    }) do
        view.state, view.searchText, view.groupFinderVisible, view.running = state, scenario.query, scenario.visible, scenario.running
        PTG:RefreshUI()
        checkGuide(scenario.current, state .. " / " .. tostring(scenario.current))
    end
end
for _, state in ipairs({"invited", "grouped", "no_role", "no_dungeons_selected", "chat_lockdown", "native_pause",
    "ready_search", "ready_apply", "ready_cancel", "ready_cancel_role_full", "filters_changed", "searching",
    "waiting_search", "search_empty", "full", "no_candidates", "wait_apply", "wait_cancel", "cooldown",
    "search_failed", "search_timeout", "search_conflict", "operation_unknown", "unsupported", "error", "future_state",
    "wait_roles", "ready_cancel_company_full", "company_changed", "company_not_leader", "company_raid", "company_full",
    "company_instance", "company_unknown", "company_roles_unknown", "company_roles_invalid", "company_offline"}) do
    view.state, view.searchText, view.groupFinderVisible, view.running = state, nil, true, false
    PTG:RefreshUI()
    checkGuide(nil, "a blocker or active state takes priority: " .. state)
end
view.state = nil
PTG:RefreshUI()
checkGuide(nil, "an absent state does not activate preparation instructions")
PTG.db.locale = "enUS"
view.state, view.searchText, view.groupFinderVisible, view.running = "off", "+19", false, false
PTG:RefreshUI()
checkGuide(3, "English preparation guide")
check(frame.statusPanel:IsShown() and frame.rows[1]:IsShown() and frame.rows[5]:IsShown()
    and frame.rows[5].name:GetText() == "Existing application 5", "the guide keeps status and all five existing applications visible")
view.searchText = nil
PTG:RefreshUI()
frame.candidatePanel.scripts.OnEnter(frame.candidatePanel)
local firstHeading = activation.heading:GetText()
check(GameTooltip.text:find(firstHeading, 1, true), "the guide tooltip contains the current heading")
for i = 1, 4 do
    check(GameTooltip.text:find(PTG:L("activation_" .. i), 1, true), "the guide tooltip preserves its full instruction: " .. i)
end
view.state, view.searchText, view.groupFinderVisible = "manual_search", "+19", true
PTG:RefreshUI()
checkGuide(2, "a hovered guide advances to closing Group Finder")
check(GameTooltip.text:find(activation.heading:GetText(), 1, true) and not GameTooltip.text:find(firstHeading, 1, true),
    "the hovered guide tooltip follows a changed current step")
view.nextCandidate = {id = 99, name = "Useful candidate", dungeon = "Dungeon", age = 10, leaderRating = 3000}
PTG:RefreshUI()
checkGuide(nil, "a useful candidate takes priority over preparation instructions")
check(frame.candidate:GetText() == "Useful candidate" and GameTooltip.text:find("Useful candidate", 1, true)
    and not GameTooltip.text:find(PTG:L("activation_heading", 2), 1, true), "hiding the hovered guide restores the candidate tooltip")
view.nextCandidate, view.state, view.running, view.groupFinderVisible = nil, "ready_search", true, false
PTG:RefreshUI()
checkGuide(nil, "a running assistant with a ready search uses the action instruction")
check(frame.status:GetText() == PTG:L("ready_search") and frame.status:GetText():find(PTG:L("step"), 1, true)
    and frame.toggle:GetText() == PTG:L("stop") and GameTooltip.text:find(PTG:L("no_next_group"), 1, true),
    "ready search gives an explicit input instruction and handles an empty candidate tooltip")
frame.candidatePanel.scripts.OnLeave()
LFGListFrame = nativeFinder
check(PTG.steps == refreshSteps and PTG.started == refreshStarts and PTG.stopped == refreshStops
    and PTG.settingsChanged == refreshSettings, "refreshing guide transitions never starts, stops, steps, or changes search settings")

PTG.db.locale = "ruRU"
view.state, view.stateArgs, view.active, view.limit = "ready_apply", {}, 3, 5
local originalFrame = frame
local compactSteps, compactStarts, compactStops, compactSettings, compactCancel =
    PTG.steps, PTG.started, PTG.stopped, PTG.settingsChanged, PTG.cancelled
frame:ClearAllPoints()
frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 220, -110)
local left, top = frame:GetLeft(), frame:GetTop()
frame.rows[1].scripts.OnEnter(frame.rows[1])
frame.collapse.scripts.OnClick()
check(not GameTooltip:IsShown(), "collapsing clears a tooltip owned by the hidden full-content container")
check(PTG.ui == originalFrame and PTG.db.compactMode == true and frame.width == 300 and frame.height == 72,
    "collapse keeps the same frame and saves the compact mode")
check(frame:GetLeft() == left and frame:GetTop() == top and PTG.db.position.point == "TOPLEFT"
    and PTG.db.position.x == 220 and PTG.db.position.y == -110,
    "changing mode preserves and saves the upper left corner without requiring a drag")
check(not frame.full:IsShown() and frame.close:IsVisible() and frame.collapse:IsVisible()
    and frame.collapse:GetText() == "+" and frame.compactApplications:IsVisible(),
    "compact mode exposes close, restore and count while hiding full-window content")
check(frame.drag.point[2] < frame.collapse.point[2] - frame.collapse.width,
    "the compact drag area leaves the restore button clickable")
for _, control in ipairs({frame.searchPanel, frame.statusPanel, frame.candidatePanel, frame.applicationLabel,
    frame.toggle, frame.step, frame.open, frame.settings, frame.rows[1], frame.rows[5]}) do
    check(not control:IsVisible(), "full-window controls inherit compact-mode hiding")
end
check(frame.title:GetText() == PTG:L("status_ready") and frame.compactApplications:GetText() == "Заявки: 3/5",
    "the compact panel shows only a short status and the existing application count")
frame.drag.scripts.OnEnter(frame.drag)
check(GameTooltip:IsShown() and GameTooltip.owner == frame.drag
    and GameTooltip:GetText():find(PTG:L("ready_apply"), 1, true), "the compact status tooltip contains the detailed action")
local nativePause = string.rep("Подробная причина приостановки. ", 8)
view.state, view.stateArgs = "native_pause", {nativePause}
PTG:RefreshUI()
check(frame.title:GetText() == PTG:L("status_paused") and GameTooltip:GetText():find(nativePause, 1, true),
    "a hovered compact tooltip updates with the complete native pause reason")
for state, kind in pairs({invited = "invited", search_timeout = "error", future_state = "unknown"}) do
    view.state, view.stateArgs = state, {}
    PTG:RefreshUI()
    check(PTG.db.compactMode and frame.width == 300 and not frame.full:IsVisible()
        and frame.title:GetText() == PTG:L("status_" .. kind)
        and table.concat(frame.title.color, ",") == table.concat(frame.statusHeading.color, ","),
        "invitation, error, and unknown states update compact status without expanding: " .. state)
end
PTG.db.locale, view.state = "enUS", "invited"
view.active, view.limit = 4, 6
PTG:RefreshUI()
check(frame.compactApplications:GetText() == "Applications: 4/6" and frame.title:GetText() == "Invitation"
    and GameTooltip:GetText():find(PTG:L("invited"), 1, true),
    "compact counts use the live limit and the hovered tooltip follows the interface language")
UIParent:Hide()
check(not GameTooltip:IsShown(), "temporarily hiding the interface also hides the compact tooltip")
UIParent:Show()
check(frame:IsShown() and PTG.db.compactMode and frame.width == 300 and not frame.full:IsVisible(),
    "temporarily hiding the interface preserves the compact representation")
view.applications = {}
for i = 1, 5 do
    view.applications[i] = {id = 100 + i, name = "Updated compact application " .. i, status = "applied", owned = i == 1}
end
view.active, view.limit, view.state = 5, 5, "full"
PTG:RefreshUI()
check(not frame.rows[1]:IsVisible() and not frame.rows[5]:IsVisible()
    and frame.compactApplications:GetText() == "Applications: 5/5", "regular updates cannot expose application rows in compact mode")
frame.collapse.scripts.OnClick()
check(not PTG.db.compactMode and frame.width == 440 and frame.height == 620
    and frame.full:IsVisible() and frame.close:IsVisible() and not frame.compactApplications:IsVisible()
    and frame.collapse:GetText() == "-", "restore returns the complete full-size interface")
check(frame.drag.point[2] < frame.collapse.point[2] - frame.collapse.width,
    "the full drag area leaves the collapse button clickable")
check(not GameTooltip:IsShown() and frame:GetLeft() == left and frame:GetTop() == top,
    "restoring clears the compact tooltip and keeps the upper left corner")
for i, row in ipairs(frame.rows) do
    check(row:IsVisible() and row.name:GetText() == view.applications[i].name,
        "restoring immediately shows the current application: " .. i)
end
for _ = 1, 3 do PTG:SetCompactMode(true); PTG:SetCompactMode(false) end
check(frame:GetLeft() == left and frame:GetTop() == top, "repeated mode changes do not accumulate position drift")

for _, item in ipairs({{field = settings.rating, setting = "minRating", draft = "9999"},
    {field = settings.replaceAfter, setting = "replaceAfter", draft = "120"}}) do
    settings:Show()
    local saved = PTG.db[item.setting]
    local savedRating, savedReplacement, savedSettings = PTG.db.minRating, PTG.db.replaceAfter, PTG.settingsChanged
    item.field:SetFocus()
    item.field:SetText(item.draft)
    frame.collapse.mouseOver = true
    globalMouseDown()
    check(item.field:HasFocus() and item.field:GetText() == item.draft
        and PTG.db.minRating == savedRating and PTG.db.replaceAfter == savedReplacement and PTG.settingsChanged == savedSettings,
        "mouse-down over collapse preserves the draft before OnClick: " .. item.setting)
    frame.collapse.mouseOver = false
    PTG:RefreshUI()
    check(item.field:HasFocus() and item.field:GetText() == item.draft and settings:IsVisible()
        and PTG.db[item.setting] == saved and PTG.settingsChanged == savedSettings,
        "an abandoned collapse click leaves the draft intact: " .. item.setting)
    frame.collapse.mouseOver = true
    globalMouseDown()
    frame.collapse.scripts.OnClick()
    frame.collapse.mouseOver = false
    check(not settings:IsShown() and not item.field:HasFocus() and PTG.db[item.setting] == saved
        and item.field:GetText() == tostring(saved) and PTG.db.minRating == savedRating
        and PTG.db.replaceAfter == savedReplacement and PTG.settingsChanged == savedSettings,
        "collapsing cancels the unconfirmed settings draft after global mouse-down: " .. item.setting)
    PTG:SetCompactMode(false)
    check(not settings:IsShown(), "restoring does not reopen settings: " .. item.setting)
end
check(PTG.steps == compactSteps and PTG.started == compactStarts and PTG.stopped == compactStops
    and PTG.settingsChanged == compactSettings and PTG.cancelled == compactCancel and view.running,
    "mode changes and draft cancellation never step, start, stop, cancel, or invalidate search settings")

for _, item in ipairs({{field = settings.rating, setting = "minRating", mouseValue = 4567, enterValue = 4568},
    {field = settings.replaceAfter, setting = "replaceAfter", mouseValue = 135, enterValue = 150}}) do
    settings:Show()
    local changedBefore = PTG.settingsChanged
    local expectedChanges = item.setting == "minRating" and 1 or 0
    item.field:SetFocus()
    item.field:SetText(tostring(item.mouseValue))
    globalMouseDown()
    check(not item.field:HasFocus() and PTG.db[item.setting] == item.mouseValue and not PTG.db.compactMode
        and PTG.settingsChanged == changedBefore + expectedChanges,
        "ordinary mouse-down elsewhere still commits the numeric edit: " .. item.setting)
    item.field:SetFocus()
    item.field:SetText(tostring(item.enterValue))
    frame.collapse.mouseOver = true
    item.field.scripts.OnEnterPressed(item.field)
    check(not item.field:HasFocus() and PTG.db[item.setting] == item.enterValue and not PTG.db.compactMode
        and PTG.settingsChanged == changedBefore + 2 * expectedChanges,
        "Enter still commits when the cursor happens to be over collapse: " .. item.setting)
    frame.collapse.mouseOver = false
end

PTG:SetCompactMode(true)
frame:ClearAllPoints()
frame:SetPoint("CENTER", UIParent, "CENTER", -120, 150)
left, top = frame:GetLeft(), frame:GetTop()
frame.drag.scripts.OnDragStop(frame.drag)
check(PTG.db.position.point == "TOPLEFT" and PTG.db.position.x == left - UIParent:GetLeft()
    and PTG.db.position.y == top - UIParent:GetTop(), "dragging compact mode saves its actual upper left corner")
local function rebuildWindow()
    PTG.ui:Hide()
    for index = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[index] == PTG.dungeonPicker.name then table.remove(UISpecialFrames, index) end
    end
    PTG.ui, PTG.settingsUI, PTG.minimapButton, PTG.groupFinderButton = nil, nil, nil, nil
    PTG.dungeonPicker = nil
    PTG:BuildUI()
    frame = PTG.ui
end
view.running = false
rebuildWindow()
check(PTG.db.compactMode and frame.width == 300 and frame.height == 72
    and frame:GetLeft() == left and frame:GetTop() == top and not frame.full:IsShown() and not frame:IsShown()
    and not PTG.dungeonPicker:IsShown(),
    "a new UI session restores compact size and position while remaining hidden")
frame:Show()
check(frame:IsVisible() and not frame.full:IsVisible(), "manually opening a restored compact window preserves its representation")
PTG:SetCompactMode(false)
rebuildWindow()
check(not PTG.db.compactMode and frame.width == 440 and frame.height == 620
    and frame:GetLeft() == left and frame:GetTop() == top and frame.full:IsShown() and not frame:IsShown(),
    "a mode change without a drag restores a hidden full UI session without position drift")
frame:Show()
check(frame.full:IsVisible(), "manually opening a restored full window exposes the existing content")
PTG.db.position = {point = "CENTER", x = 75, y = -45}
rebuildWindow()
local centerX, centerY = frame:GetCenter()
check(centerX == 1035 and centerY == 495 and frame.width == 440 and frame.height == 620,
    "legacy center-based positions retain their original full-window location")
left, top = frame:GetLeft(), frame:GetTop()
PTG:SetCompactMode(true)
rebuildWindow()
check(frame:GetLeft() == left and frame:GetTop() == top and frame.width == 300 and frame.height == 72,
    "collapsing and reloading a legacy center position preserves its upper left corner")
do
    PTG:SetCompactMode(false)
    PTG.ui:Show()
    settings = PTG.settingsUI
    settings:Show()
    PTG.db.locale = "ruRU"
    view.running, view.state, view.nextCandidate = true, "ready_search", nil
    PTG:RefreshUI()
    local savedSteps, savedStarts, savedStops, savedChanges, savedCancel =
        PTG.steps, PTG.started, PTG.stopped, PTG.settingsChanged, PTG.cancelled
    check(#settings.inputModeButtons == 2 and settings.inputModeButtons[1].selected
        and not settings.inputModeButtons[1]:IsEnabled(), "input offers two modes with automatic selected")
    local function checkBindingBlock(shown)
        for _, name in ipairs({"bindingPrimary", "bindingSecondary", "bindingAssign", "bindingClear", "bindingStatus", "bindingScope"}) do
            check(settings[name]:IsShown() == shown, "binding block visibility follows input mode: " .. name)
        end
        if not shown then
            check(not settings.bindingConfirm:IsShown() and not settings.bindingCancel:IsShown(),
                "automatic mode also hides binding confirmation and cancellation")
        end
    end
    checkBindingBlock(false)
    local _, automaticRoleY = offsets(settings.roleLabel)
    local _, automaticHintY = offsets(settings.inputModeHint)
    check(automaticRoleY == automaticHintY - settings.inputModeHint:GetStringHeight() - 12,
        "automatic mode leaves no empty binding area before role settings")
    settings.inputModeButtons[2].scripts.OnClick()
    check(PTG.db.inputMode == "key" and settings.inputModeButtons[2].selected
        and not settings.inputModeButtons[2]:IsEnabled(), "key mode delegates selection to SetInputMode")
    checkBindingBlock(true)
    local _, keyRoleY = offsets(settings.roleLabel)
    check(keyRoleY < automaticRoleY, "key mode expands the card for binding settings")
    check(settings.bindingPrimary:GetText():find("F8", 1, true)
        and settings.bindingSecondary:GetText():find("F9", 1, true), "settings show both existing step keys")
    check(settings.bindingScope:GetText() == PTG:L("binding_scope")
        and settings.bindingClear:GetText() == PTG:L("binding_clear"), "binding scope and primary-only clearing are explicit")
    check(PTG.ui.status:GetText():find("F8", 1, true)
        and PTG:L("activation_4"):find("F8", 1, true), "key-mode search and activation hints name the current primary key")
    stepKey1, stepKey2 = nil, nil
    PTG:RefreshUI()
    check(PTG:L("ready_search") == PTG:L("ready_search_key_unbound")
        and PTG:L("activation_4") == PTG:L("activation_4_key_unbound")
        and not settings.bindingClear:IsEnabled(), "unassigned key mode explains assignment and preserves the manual alternative")
    stepKey2 = "F9"
    PTG:RefreshUI()
    check(PTG:L("ready_search"):find("F9", 1, true), "a remaining additional key is usable in the mode hint")
    stepKeyError = "binding_error"
    PTG:RefreshUI()
    check(settings.bindingPrimary:GetText() == PTG:L("binding_error")
        and PTG:L("ready_search") == PTG:L("ready_search_key_unavailable"), "unreadable bindings are not reported as unassigned")
    stepKey1, stepKey2, stepKeyError = "F8", "F9", nil
    local function startCapture()
        assert(settings.bindingAssign:IsVisible(), "assignment starts from the visible key-mode block")
        settings.bindingAssign.scripts.OnClick()
        check(PTG.bindingCapture and PTG.bindingCapture.phase == "capture"
            and settings.bindingListener.keyboardEnabled and settings.bindingListener.propagateKeyboard == false,
            "explicit assignment enables a swallowing keyboard listener")
        check(not settings.bindingAssign:IsEnabled() and not settings.bindingClear:IsEnabled()
            and not PTG.ui.step:IsEnabled(), "binding capture blocks step and binding editing controls")
    end
    local function keyDown(key)
        keyboardDown[key] = true
        local listener = settings.bindingListener
        assert(listener.scripts.OnKeyDown, "keyboard listener is active")(listener, key)
    end
    local function keyUp(key)
        keyboardDown[key] = nil
        local listener = settings.bindingListener
        assert(listener.scripts.OnKeyUp, "key-release listener is active")(listener, key)
    end
    local function stoppedCapture(message)
        check(not PTG.bindingCapture and not settings.bindingListener.keyboardEnabled
            and not settings.bindingListener:IsShown() and not settings.bindingListener.scripts.OnKeyDown
            and not settings.bindingListener.scripts.OnKeyUp and not settings.bindingListener.scripts.OnUpdate, message)
    end
    settings.rating:SetFocus()
    startCapture()
    check(not settings.rating:HasFocus(), "starting assignment clears current edit focus")
    local capture = PTG.bindingCapture
    PTG:RefreshUI()
    check(PTG.bindingCapture == capture and settings.bindingStatus:GetText() == PTG:L("binding_capture"),
        "regular refresh preserves the capture session")
    local callsBefore = #assignCalls
    keyDown("K")
    check(#assignCalls == callsBefore + 1 and assignCalls[#assignCalls].key == "K"
        and assignCalls[#assignCalls].action == "" and assignCalls[#assignCalls].currentSet == 1,
        "a free key is passed to the binding helper with its observed action and active set")
    check(PTG.bindingCapture and PTG.bindingCapture.phase == "release"
        and settings.bindingStatus:GetText() == PTG:L("binding_release"), "successful assignment still consumes the assigning press")
    keyUp("K")
    stoppedCapture("release removes keyboard scripts and clears the shared input guard")
    check(settings.bindingStatus:GetText() == PTG:L("binding_saved"), "assignment success is visible after release")
    for _, item in ipairs({{"LCTRL", "CTRL-"}, {"LALT", "ALT-"}, {"LSHIFT", "SHIFT-"}}) do
        startCapture()
        callsBefore, modifiers = #assignCalls, item[2]
        keyDown(item[1])
        check(#assignCalls == callsBefore and PTG.bindingCapture.phase == "capture", "a modifier alone does not complete assignment")
        keyDown("K")
        check(assignCalls[#assignCalls].key == item[2] .. "K", "capture uses native chord normalization: " .. item[2])
        keyUp("K")
        check(PTG.bindingCapture ~= nil, "assignment remains guarded until the modifier is released")
        keyUp(item[1])
        stoppedCapture("modifier release ends capture")
        modifiers = ""
    end
    bindingAction, bindingSet = "ACTIONBUTTON1", 2
    startCapture()
    callsBefore = #assignCalls
    keyDown("X")
    capture = PTG.bindingCapture
    check(capture.phase == "conflict" and capture.pending.key == "X" and #assignCalls == callsBefore
        and settings.bindingStatus:GetText():find("Action: ACTIONBUTTON1", 1, true),
        "occupied key shows its action before calling any mutation helper")
    check(not settings.bindingConfirm:IsEnabled(), "conflict confirmation waits for key release")
    settings.bindingConfirm.scripts.OnClick()
    check(#assignCalls == callsBefore, "premature confirmation cannot apply a held key")
    PTG:RefreshUI()
    check(PTG.bindingCapture == capture and settings.bindingConfirm:IsShown(), "refresh preserves the pending conflict")
    checkCards("binding conflict")
    keyUp("X")
    check(settings.bindingConfirm:IsEnabled(), "released conflict can be confirmed")
    settings.bindingConfirm.scripts.OnClick()
    check(#assignCalls == callsBefore + 1 and assignCalls[#assignCalls].key == "X"
        and assignCalls[#assignCalls].action == "ACTIONBUTTON1" and assignCalls[#assignCalls].currentSet == 2,
        "confirmation supplies the original conflicting action and binding set for revalidation")
    stoppedCapture("confirming a released key ends the session")
    startCapture()
    keyDown("X")
    keyUp("X")
    callsBefore = #assignCalls
    settings.bindingCancel.scripts.OnClick()
    stoppedCapture("rejecting the conflict ends capture")
    check(#assignCalls == callsBefore and settings.bindingStatus:GetText() == PTG:L("binding_cancelled"),
        "conflict rejection never calls the assignment helper")
    startCapture()
    keyDown("X")
    keyUp("X")
    bindingAction, bindingSet, bindingFailure = "ACTIONBUTTON2", 1, "binding_changed"
    settings.bindingConfirm.scripts.OnClick()
    check(assignCalls[#assignCalls].action == "ACTIONBUTTON1" and assignCalls[#assignCalls].currentSet == 2
        and settings.bindingStatus:GetText() == PTG:L("binding_changed"), "a stale conflict keeps the original consent snapshot and displays helper refusal")
    bindingAction, bindingSet, bindingFailure = "", 1, nil
    for _, reason in ipairs({"binding_error", "binding_restore_failed", "binding_already"}) do
        bindingFailure = reason
        startCapture()
        keyDown("K")
        keyUp("K")
        check(settings.bindingStatus:GetText() == PTG:L(reason), "assignment helper result is shown without claiming success: " .. reason)
    end
    bindingFailure = nil
    bindingAction, bindingSet = nil, "binding_error"
    startCapture()
    callsBefore = #assignCalls
    keyDown("K")
    keyUp("K")
    check(#assignCalls == callsBefore and settings.bindingStatus:GetText() == PTG:L("binding_error"),
        "failed conflict lookup cannot mutate a binding")
    bindingAction, bindingSet = "", 1
    for _, conflict in ipairs({false, true}) do
        bindingAction = conflict and "ACTIONBUTTON1" or ""
        startCapture()
        if conflict then keyDown("X"); keyUp("X") end
        callsBefore = #assignCalls
        keyDown("ESCAPE")
        check(PTG.bindingCapture and PTG.bindingCapture.phase == "release" and #assignCalls == callsBefore,
            "Escape cancels capture or conflict while consuming its own press")
        keyUp("ESCAPE")
        stoppedCapture("Escape release removes the listener")
    end
    bindingAction = ""
    startCapture()
    keyDown("LCTRL")
    PTG:CancelBindingCapture()
    keyDown("K")
    callsBefore = #assignCalls
    keyUp("LCTRL")
    check(PTG.bindingCapture and #assignCalls == callsBefore, "a key pressed during cancellation remains swallowed until release")
    keyUp("K")
    stoppedCapture("all keys released after cancellation clear the guard")
    for _, window in ipairs({settings, PTG.ui}) do
        settings:Show()
        PTG.ui:Show()
        startCapture()
        keyDown("LCTRL")
        local wasRunning = view.running
        if window == PTG.ui then view.running = false end
        window:Hide()
        view.running = wasRunning
        check(PTG.bindingCapture and PTG.bindingCapture.phase == "release", "hiding either PTG window cancels the pending assignment")
        keyUp("LCTRL")
        stoppedCapture("hidden windows keep release cleanup alive on the separate listener")
    end
    settings:Show()
    PTG.ui:Show()
    startCapture()
    keyDown("LCTRL")
    settings:Hide()
    keyboardDown.LCTRL = nil
    settings.bindingListener.scripts.OnUpdate()
    stoppedCapture("polling recovers a key release lost while a PTG window is hidden")
    settings:Show()
    bindingFailure = "binding_error"
    startCapture()
    keyDown("K")
    local nativeIsKeyDown = IsKeyDown
    local secretState = {}
    issecretvalue = function(value) return value == secretState end
    for _, read in ipairs({function() error("unavailable") end, function() return nil end,
        function() return secretState end}) do
        IsKeyDown = read
        settings.bindingListener.scripts.OnUpdate()
        check(PTG.bindingCapture and PTG.bindingCapture.down.K, "unknown or secret key state cannot release the input guard")
    end
    IsKeyDown = nil
    settings.bindingListener.scripts.OnUpdate()
    check(PTG.bindingCapture ~= nil, "missing key-state API cannot release the input guard")
    IsKeyDown, issecretvalue, keyboardDown.K = nativeIsKeyDown, nil, nil
    settings.bindingListener.scripts.OnUpdate()
    stoppedCapture("polling recovers a lost release after assignment failure")
    check(settings.bindingStatus:GetText() == PTG:L("binding_error"), "lost-release recovery preserves the assignment error")
    bindingFailure, bindingAction = nil, "ACTIONBUTTON1"
    startCapture()
    callsBefore = #assignCalls
    keyDown("X")
    keyboardDown.X = nil
    settings.bindingListener.scripts.OnUpdate()
    check(PTG.bindingCapture and PTG.bindingCapture.phase == "conflict"
        and settings.bindingConfirm:IsEnabled() and #assignCalls == callsBefore,
        "polling a released conflict key enables confirmation without accepting or mutating it")
    PTG:CancelBindingCapture()
    bindingAction = ""
    PTG.ui:Show()
    settings:Show()
    startCapture()
    PTG:SetCompactMode(true)
    stoppedCapture("collapsing the main window cancels key capture")
    PTG:SetCompactMode(false)
    settings:Show()
    bindingAction = "ACTIONBUTTON1"
    startCapture()
    keyDown("X")
    callsBefore = #assignCalls
    local clearsBefore = clearCalls
    settings.inputModeButtons[1].scripts.OnClick()
    checkBindingBlock(false)
    check(PTG.bindingCapture and PTG.bindingCapture.phase == "release" and not PTG.bindingCapture.pending
        and #assignCalls == callsBefore and clearCalls == clearsBefore,
        "automatic mode discards a pending conflict without editing bindings and keeps the release guard")
    keyUp("X")
    stoppedCapture("switching input modes cancels capture")
    settings.inputModeButtons[2].scripts.OnClick()
    bindingAction = ""
    checkBindingBlock(true)
    check(settings.bindingPrimary:GetText():find("F8", 1, true)
        and settings.bindingSecondary:GetText():find("F9", 1, true)
        and #assignCalls == callsBefore and clearCalls == clearsBefore,
        "returning to key mode restores both displayed bindings without assigning or clearing")
    startCapture()
    keyDown("LCTRL")
    combat = true
    PTG:CancelBindingCapture()
    check(PTG.bindingCapture and PTG.bindingCapture.phase == "release"
        and not settings.bindingAssign:IsEnabled() and not settings.bindingClear:IsEnabled(),
        "combat cancels capture and disables editing while consuming a held key")
    keyUp("LCTRL")
    stoppedCapture("a held key can finish cancellation in combat")
    settings.bindingAssign.scripts.OnClick()
    check(not PTG.bindingCapture and settings.bindingStatus:GetText() == PTG:L("binding_combat"), "assignment cannot start in combat")
    combat = false
    PTG:RefreshUI()
    callsBefore = clearCalls
    settings.bindingClear.scripts.OnClick()
    check(clearCalls == callsBefore + 1 and settings.bindingStatus:GetText() == PTG:L("binding_cleared"),
        "clear primary delegates to the binding helper and displays its result")
    bindingFailure = "binding_error"
    settings.bindingClear.scripts.OnClick()
    check(settings.bindingStatus:GetText() == PTG:L("binding_error"), "clear failure is visible")
    bindingFailure = nil
    view.running = false
    PTG:RefreshUI()
    check(not PTG.ui.step:IsEnabled(), "Next step is unavailable while the assistant is stopped")
    for _, locale in ipairs({"ruRU", "enUS"}) do
        PTG.db.locale = locale
        settings.inputModeButtons[2].scripts.OnClick()
        PTG:RefreshUI()
        checkBindingBlock(true)
        check(settings.inputModeButtons[2]:GetText() == PTG:L("input_mode_key")
            and settings.bindingPrimary:GetText() == PTG:L("binding_primary", "F8"), "mode and key labels follow interface language: " .. locale)
        settings.inputModeButtons[1].scripts.OnClick()
        checkBindingBlock(false)
        checkCards("automatic mode / " .. locale)
        check(PTG:L("ready_search") == dictionaries[locale].ready_search
            and PTG:L("activation_4") == dictionaries[locale].activation_4, "automatic hints mention abilities, movement and jump: " .. locale)
    end
    check(PTG.steps == savedSteps and PTG.started == savedStarts and PTG.stopped == savedStops
        and PTG.settingsChanged == savedChanges and PTG.cancelled == savedCancel,
        "mode selection and binding UI never step, start, stop, cancel or invalidate LFG state")
end
do
    local savedSteps, savedStarts, savedStops, savedChanges, savedCancel =
        PTG.steps, PTG.started, PTG.stopped, PTG.settingsChanged, PTG.cancelled
    PTG:SetCompactMode(false)
    frame = PTG.ui
    frame:Show()
    PTG.db.role, PTG.db.autoRole = "HEALER", true
    view.state, view.stateArgs, view.running, view.nextCandidate = "wait_roles", {}, true, nil
    local groupStates = {
        wait_roles = "waiting", ready_cancel_company_full = "ready", company_changed = "stopped",
        company_not_leader = "paused", company_raid = "paused", company_full = "paused", company_instance = "paused",
        company_unknown = "paused", company_roles_unknown = "paused", company_roles_invalid = "paused", company_offline = "paused",
    }
    for _, locale in ipairs({"ruRU", "enUS"}) do
        PTG.db.locale = locale
        for size = 2, 5 do
            view.companySize, view.companyLeader = size, true
            view.companyRoles = {TANK = size >= 4 and 1 or 0, HEALER = 1, DAMAGER = size >= 4 and size - 2 or size - 1}
            PTG:RefreshUI()
            local expected = PTG:L("company_summary", size, view.companyRoles.TANK, 1, view.companyRoles.DAMAGER)
            check(frame.role:GetText() == expected, "party size and every known role count fit the existing indicator: " .. locale .. " / " .. size)
            check(frame.width == 440 and frame.height == 620 and frame.role.width == 196,
                "party summary preserves the full-window and role-indicator dimensions")
        end
        frame.statusPanel.scripts.OnEnter(frame.statusPanel)
        check(GameTooltip:GetText():find(PTG:L("current_role", PTG:L("HEALER"), PTG:L("role_auto")), 1, true)
            and GameTooltip:GetText():find(PTG:L("company_leader"), 1, true)
            and GameTooltip:GetText():find(PTG:L("company_help"), 1, true),
            "party tooltip keeps the local role, leader context and manual native confirmation instructions: " .. locale)
        view.companyLeader = false
        PTG:RefreshUI()
        check(GameTooltip:GetText():find(PTG:L("company_other_leader"), 1, true), "hovered party tooltip updates leader context")
        view.companyLeader, view.companyRoles = nil, nil
        PTG:RefreshUI()
        check(frame.role:GetText() == PTG:L("company_summary_unknown", 5)
            and GameTooltip:GetText():find(PTG:L("company_leader_unknown"), 1, true),
            "known party size does not fabricate unknown role counts or leadership")
        frame.statusPanel.scripts.OnLeave()
        for state, kind in pairs(groupStates) do
            view.state = state
            PTG:RefreshUI()
            check(frame.statusHeading:GetText() == PTG:L("status_" .. kind)
                and frame.status:GetText() == PTG:L(state) and not frame.activation:IsShown(),
                "party state keeps its localized reason and category ahead of activation hints: " .. state .. " / " .. locale)
        end
        settings = PTG.settingsUI
        settings:Show()
        check(settings.compositionHint:GetText() == PTG:L("composition_hint")
            and settings.compositionHint:GetText():find(locale == "ruRU" and "компании" or "party", 1, true),
            "capability explanation covers the whole party: " .. locale)
        local original = dictionaries[locale].company_roles_unknown
        local longReason = string.rep(original .. " ", 8)
        dictionaries[locale].company_roles_unknown = longReason
        view.state = "company_roles_unknown"
        PTG:RefreshUI()
        frame.statusPanel.scripts.OnEnter(frame.statusPanel)
        check(GameTooltip:GetText():find(longReason, 1, true) and frame.width == 440 and frame.height == 620,
            "full view preserves an entire long party status in its tooltip without resizing")
        frame.statusPanel.scripts.OnLeave()
        PTG:SetCompactMode(true)
        frame.drag.scripts.OnEnter(frame.drag)
        check(GameTooltip:GetText():find(longReason, 1, true)
            and GameTooltip:GetText():find(PTG:L("company_summary_unknown", 5), 1, true)
            and GameTooltip:GetText():find(PTG:L("company_help"), 1, true),
            "compact tooltip includes the long reason, party size and native-confirmation instructions")
        dictionaries[locale].company_roles_unknown = original
        for state, kind in pairs(groupStates) do
            view.state = state
            PTG:RefreshUI()
            check(frame.title:GetText() == PTG:L("status_" .. kind)
                and GameTooltip:GetText():find(PTG:L(state), 1, true) and frame.width == 300 and frame.height == 72,
                "compact party states preserve the short heading and complete hovered reason: " .. state .. " / " .. locale)
        end
        frame.drag.scripts.OnLeave()
        PTG:SetCompactMode(false)
        for _, size in ipairs({1, 0}) do
            view.companySize, view.companyRoles, view.companyLeader = size == 1 and 1 or nil, nil, nil
            PTG:RefreshUI()
            check(frame.role:GetText() == PTG:L("current_role", PTG:L("HEALER"), PTG:L("role_auto")),
                "solo or unavailable party size preserves the existing role indicator: " .. locale)
        end
    end
    check(PTG.steps == savedSteps and PTG.started == savedStarts and PTG.stopped == savedStops
        and PTG.settingsChanged == savedChanges and PTG.cancelled == savedCancel,
        "rendering party summaries and all party statuses never issues LFG actions or invalidates settings")
end
do
    view.running = false
    local savedSteps, savedStarts, savedStops, savedChanges, savedCancel, savedToggles =
        PTG.steps, PTG.started, PTG.stopped, PTG.settingsChanged, PTG.cancelled, PTG.windowToggles
    PTG:SetCompactMode(true)
    frame = PTG.ui
    frame:Hide()
    local savedPosition, savedLeft, savedTop = PTG.db.position, frame:GetLeft(), frame:GetTop()
    check(PTG:ShowWelcome() == true, "welcome reports that it was shown")
    local welcome = PTG.welcomeUI
    check(welcome and welcome.name == "PressToGroupWelcome" and welcome.parent == UIParent
        and welcome:IsShown() and not frame:IsShown(), "welcome is an independent named panel without opening the assistant")
    for _, locale in ipairs({"ruRU", "enUS"}) do
        PTG.db.locale = locale
        welcome.body.stringHeight = locale == "ruRU" and 180 or 144
        check(PTG:ShowWelcome() == true and PTG.welcomeUI == welcome, "showing welcome again reuses its existing frame")
        check(welcome.title:GetText() == PTG:L("welcome_title") and welcome.body:GetText() == PTG:L("welcome_body")
            and welcome.open:GetText() == PTG:L("welcome_open") and welcome.dismiss:GetText() == PTG:L("welcome_dismiss")
            and welcome.close:GetText() == "×", "welcome title, body and actions follow interface language: " .. locale)
        check(welcome.body:GetText():find("PressToGroup", 1, true) and welcome.body:GetText():find("Mythic+", 1, true)
            and welcome.body:GetText():find(PTG:L("input_mode_auto"), 1, true)
            and welcome.body:GetText():find(PTG:L("input_mode_key"), 1, true), "welcome explains the purpose and both existing input modes")
        check(welcome.width == 420 and welcome.body.width == 388 and welcome.body.wordWrap == true
            and welcome.height == welcome.body.stringHeight + 114 and welcome.body.height == welcome.body.stringHeight,
            "welcome height follows the wrapped localized body")
        check(welcome.body:GetTop() - welcome.body.height > welcome.open:GetTop()
            and welcome.open:GetLeft() + welcome.open.width < welcome.dismiss:GetLeft()
            and welcome.dismiss:GetLeft() + welcome.dismiss.width < welcome:GetLeft() + welcome.width,
            "welcome body and footer have separate bounded areas without overlap")
        welcome.close.scripts.OnEnter(welcome.close)
        check(GameTooltip:GetText() == PTG:L("close"), "welcome close tooltip follows interface language")
        welcome.close.scripts.OnLeave()
        PTG:RefreshUI()
        check(not frame:IsShown() and welcome:IsShown(), "refresh neither opens the assistant nor dismisses welcome")
    end
    local registered = 0
    for _, name in ipairs(UISpecialFrames) do
        if name == "PressToGroupWelcome" then registered = registered + 1 end
    end
    check(registered == 1, "the reused welcome panel is registered for Escape exactly once")
    for _, dismiss in ipairs({welcome.close, welcome.dismiss}) do
        PTG:ShowWelcome()
        dismiss.scripts.OnClick()
        check(not welcome:IsShown() and not frame:IsShown(), "welcome close and Got it dismiss only welcome")
    end
    PTG:ShowWelcome()
    welcome:Hide()
    check(not welcome:IsShown() and not frame:IsShown(), "the registered Escape hide path leaves the assistant hidden")
    PTG:ShowWelcome()
    welcome.open.scripts.OnClick()
    check(frame:IsShown() and not welcome:IsShown() and PTG.db.compactMode
        and frame.width == 300 and frame.height == 72 and frame:GetLeft() == savedLeft and frame:GetTop() == savedTop
        and PTG.db.position == savedPosition, "welcome CTA explicitly opens the saved compact window at its saved position")
    PTG:ShowWelcome()
    welcome.open.scripts.OnClick()
    check(frame:IsShown() and not welcome:IsShown() and PTG.windowToggles == savedToggles,
        "welcome CTA keeps an already opened assistant visible without toggling")
    PTG:ShowWelcome()
    welcome.dismiss.scripts.OnClick()
    check(frame:IsShown() and not welcome:IsShown(), "dismissing welcome does not hide an already opened assistant")
    frame:Hide()
    PTG:ShowWelcome()
    frame:Show()
    check(frame:IsShown() and not welcome:IsShown(), "manual main-window opening dismisses welcome")
    check(PTG.steps == savedSteps and PTG.started == savedStarts and PTG.stopped == savedStops
        and PTG.settingsChanged == savedChanges and PTG.cancelled == savedCancel
        and PTG.db.position == savedPosition and PTG.db.compactMode,
        "showing, dismissing and opening from welcome never starts, steps, cancels or changes search settings")
end
do
    local originalStart, originalStop, startCalls, stopCalls = PTG.Start, PTG.Stop, 0, 0
    function PTG:Start()
        startCalls = startCalls + 1
        originalStart(self)
        view.running, view.state = true, "ready_search"
        self:RefreshUI()
    end
    function PTG:Stop()
        stopCalls = stopCalls + 1
        originalStop(self)
        view.running, view.state = false, "off"
        self:RefreshUI()
    end
    local savedSteps, savedChanges, savedCancel = PTG.steps, PTG.settingsChanged, PTG.cancelled
    frame = PTG.ui
    PTG:SetCompactMode(false)
    frame:Show()
    check(not frame.compactToggle:IsShown(), "the compact toggle is absent from the full view")
    view.running, view.state, view.stateArgs = false, "off", {}
    view.applications = {{id = 42, name = "Existing application", status = "applied", owned = true}}
    PTG:SetCompactMode(true)
    local applications, application = view.applications, view.applications[1]
    local position, left, top = PTG.db.position, frame:GetLeft(), frame:GetTop()
    local toggle = frame.compactToggle
    local function checkPhase(running, message)
        check(toggle:IsVisible() and toggle:IsEnabled() and toggle.stopIcon:IsShown() == running
            and toggle.tooltip == PTG:L(running and "compact_stop" or "compact_start"), message)
        for _, strip in ipairs(toggle.startIcon) do
            check(strip:IsShown() == not running, message .. ": play icon visibility")
        end
    end
    check(toggle.width == 24 and toggle.height == 24 and toggle:GetText() == ""
        and toggle.stopIcon.color[1] > toggle.stopIcon.color[2] and #toggle.startIcon == 5,
        "compact toggle uses a 24-pixel control with distinct texture icons instead of glyphs")
    for i, strip in ipairs(toggle.startIcon) do
        check(strip.width == 2 and strip.height == 12 - 2 * i and strip.point[2] == 5 + 2 * i
            and strip.color[2] > strip.color[1], "green texture strips form a right-facing play icon")
    end
    check(toggle:GetLeft() + toggle.width < frame.collapse:GetLeft()
        and frame.collapse:GetLeft() + frame.collapse.width < frame.close:GetLeft()
        and frame.width + frame.drag.point[2] < toggle:GetLeft() - frame:GetLeft()
        and 8 + 7 + frame.title.width < toggle:GetLeft() - frame:GetLeft() and frame.title.wordWrap == false,
        "compact title, drag area, toggle, expand and close controls have separate horizontal space")
    for _, locale in ipairs({"ruRU", "enUS"}) do
        PTG.db.locale = locale
        PTG:RefreshUI()
        checkPhase(false, "stopped compact mode offers Start: " .. locale)
        toggle.scripts.OnEnter(toggle)
        check(GameTooltip:GetText() == PTG:L("compact_start"), "Start tooltip follows interface language: " .. locale)
        local starts, stops = startCalls, stopCalls
        toggle.scripts.OnClick()
        check(startCalls == starts + 1 and stopCalls == stops and view.running,
            "stopped compact toggle calls the existing Start action exactly once")
        checkPhase(true, "running compact mode offers Stop: " .. locale)
        check(GameTooltip:GetText() == PTG:L("compact_stop"), "Start immediately updates the hovered tooltip to Stop")
        view.state = "manual_search"
        PTG:RefreshUI()
        checkPhase(true, "a paused running assistant still offers Stop")
        toggle.scripts.OnClick()
        check(startCalls == starts + 1 and stopCalls == stops + 1 and not view.running,
            "paused compact toggle calls the existing Stop action exactly once")
        checkPhase(false, "Stop restores the enabled Start button")
        check(GameTooltip:GetText() == PTG:L("compact_start"), "Stop immediately updates the hovered tooltip to Start")
    end
    PTG:Start()
    checkPhase(true, "an external Start updates the compact action")
    view.running, view.state = false, "company_changed"
    PTG:RefreshUI()
    checkPhase(false, "an externally stopped assistant offers Start even with a non-off status")
    check(GameTooltip:GetText() == PTG:L("compact_start"), "external state changes update the hovered tooltip")
    PTG.db.locale = "ruRU"
    PTG:RefreshUI()
    check(GameTooltip:GetText() == PTG:L("compact_start"), "hovered tooltip follows a language change without re-entering")
    check(frame:IsShown() and PTG.db.compactMode and frame.width == 300 and frame.height == 72
        and frame:GetLeft() == left and frame:GetTop() == top and PTG.db.position == position
        and view.applications == applications and view.applications[1] == application
        and application.status == "applied" and PTG.settingsChanged == savedChanges and PTG.cancelled == savedCancel
        and PTG.steps == savedSteps, "compact actions preserve the window, mode, position and applications without stepping")
    toggle.scripts.OnLeave()
    check(not GameTooltip:IsShown(), "leaving the compact toggle hides its tooltip")
    toggle.scripts.OnEnter(toggle)
    PTG:SetCompactMode(false)
    check(not toggle:IsShown() and not GameTooltip:IsShown() and frame.width == 440 and frame.collapse:GetText() == "-",
        "returning to full view hides compact toggle and tooltip and preserves the ASCII collapse label")
    PTG:SetCompactMode(true)
    toggle.scripts.OnEnter(toggle)
    frame:Hide()
    check(not GameTooltip:IsShown(), "hiding the compact window hides the toggle tooltip")
    PTG.Start, PTG.Stop = originalStart, originalStop
end
do
    local originalStart, originalStop, startCalls, stopCalls = PTG.Start, PTG.Stop, 0, 0
    function PTG:Start()
        startCalls = startCalls + 1
        originalStart(self)
        view.running, view.state = true, "ready_search"
        self:RefreshUI()
    end
    function PTG:Stop()
        stopCalls = stopCalls + 1
        originalStop(self)
        view.running, view.state = false, "off"
        self:RefreshUI()
    end
    local savedSteps, savedChanges, savedCancel = PTG.steps, PTG.settingsChanged, PTG.cancelled
    for _, locale in ipairs({"ruRU", "enUS"}) do
        PTG.db.locale = locale
        for _, compact in ipairs({false, true}) do
            frame:Show()
            PTG:SetCompactMode(compact)
            PTG:Start()
            local stops = stopCalls
            for _, close in ipairs({PTG.settingsUI.close, PTG.settingsUI.dismiss}) do
                PTG.settingsUI:Show()
                close.scripts.OnClick()
                check(view.running and stopCalls == stops, "closing either settings control keeps the assistant running")
            end
            for _, close in ipairs({PTG.welcomeUI.dismiss, PTG.welcomeUI.close}) do
                PTG:ShowWelcome()
                close.scripts.OnClick()
                check(view.running and stopCalls == stops, "closing welcome keeps the assistant running")
            end
            PTG:ShowWelcome()
            PTG.welcomeUI:Hide()
            check(view.running and stopCalls == stops, "the welcome Escape hide path does not stop the assistant")
            PTG:SetCompactMode(not compact)
            PTG:SetCompactMode(compact)
            check(view.running and stopCalls == stops, "switching full and compact views does not stop the assistant")
            local applications, position = view.applications, PTG.db.position
            local left, top = frame:GetLeft(), frame:GetTop()
            UIParent:Hide()
            check(frame:IsShown() and not frame:IsVisible() and view.running and stopCalls == stops,
                "temporarily hiding UIParent does not close the main window or stop the assistant")
            UIParent:Show()
            check(frame:IsVisible() and view.running and stopCalls == stops,
                "restoring UIParent keeps the assistant running")
            check(frame.close:IsVisible() and frame.close:IsEnabled() and frame.close.width == 24 and frame.close.height == 24,
                "the close button is available in either main view: " .. locale)
            local starts = startCalls
            frame.close.scripts.OnEnter(frame.close)
            check(GameTooltip:GetText() == PTG:L("hide_window"), "close explains stopping with applications kept: " .. locale)
            frame.close.scripts.OnClick()
            check(not frame:IsShown() and not GameTooltip:IsShown() and not view.running and stopCalls == stops + 1
                and startCalls == starts
                and PTG.db.compactMode == compact and PTG.db.position == position
                and frame:GetLeft() == left and frame:GetTop() == top and view.applications == applications
                and PTG.steps == savedSteps
                and PTG.settingsChanged == savedChanges and PTG.cancelled == savedCancel,
                "closing the main window stops once and preserves applications, position and representation")
            frame:Show()
            check(frame:IsVisible() and not view.running and startCalls == starts and stopCalls == stops + 1,
                "ordinary opening preserves the stopped state")
            frame.close.scripts.OnClick()
            frame:Hide()
            check(stopCalls == stops + 1, "closing an already stopped window does not call Stop again")
            frame:Show()
            PTG:Start()
            frame:Hide()
            check(not view.running and stopCalls == stops + 2,
                "a direct main Hide uses the same one-stop lifecycle as the close button")
        end
    end
    local escapes = 0
    for _, name in ipairs(UISpecialFrames) do
        if name == "PressToGroupFrame" then escapes = escapes + 1 end
    end
    check(escapes == 1, "the stopped main window remains registered for Escape exactly once")
    frame:Show()
    check(not view.running and PTG.db.compactMode and frame.width == 300 and frame.height == 72 and frame.close:IsVisible(),
        "reopening preserves the stopped compact representation with its close button")
    PTG.Start, PTG.Stop = originalStart, originalStop
end
do
    local originalStop, stopCalls = PTG.Stop, 0
    function PTG:Stop()
        stopCalls = stopCalls + 1
        originalStop(self)
        view.running, view.state = false, "off"
        self:RefreshUI()
    end
    local windows = {PressToGroupFrame = frame, PressToGroupSettings = PTG.settingsUI, PressToGroupWelcome = PTG.welcomeUI}
    local function escape()
        for _, name in ipairs(UISpecialFrames) do
            local window = windows[name]
            if window and window:IsShown() then window:Hide() end
        end
    end
    local function registrations(name)
        local count = 0
        for _, registered in ipairs(UISpecialFrames) do
            if registered == name then count = count + 1 end
        end
        return count
    end
    tinsert(UISpecialFrames, 1, "ForeignEscapeFirst")
    tinsert(UISpecialFrames, "ForeignEscapeLast")
    local otherEntries = {}
    for _, name in ipairs(UISpecialFrames) do
        if name ~= "PressToGroupFrame" then otherEntries[#otherEntries + 1] = name end
    end
    local savedStarts, savedSteps, savedChanges, savedCancel = PTG.started, PTG.steps, PTG.settingsChanged, PTG.cancelled
    for _, compact in ipairs({false, true}) do
        for _, phase in ipairs({{false, "off"}, {true, "ready_search"}, {true, "manual_search"},
            {true, "search_conflict"}, {false, "company_changed"}}) do
            view.running, view.state = phase[1], phase[2]
            frame:Show()
            for _ = 1, 5 do
                PTG:RefreshUI()
                PTG:SetCompactMode(not compact)
                PTG:SetCompactMode(compact)
            end
            check(registrations("PressToGroupFrame") == (phase[1] and 0 or 1),
                "Escape registration follows running without duplicates across refreshes and view changes: " .. phase[2])
            check(registrations("PressToGroupSettings") > 0 and registrations("PressToGroupWelcome") == 1,
                "settings and welcome retain their Escape registrations")
            local applications, position = view.applications, PTG.db.position
            local left, top = frame:GetLeft(), frame:GetTop()
            PTG.settingsUI:Show()
            PTG:ShowWelcome()
            escape()
            check(frame:IsShown() == phase[1] and view.running == phase[1] and stopCalls == 0,
                "Escape closes only a stopped main window, including after automatic Stop: " .. phase[2])
            check(not PTG.settingsUI:IsShown() and not PTG.welcomeUI:IsShown(),
                "Escape still closes settings and welcome while protecting the running main window")
            check(PTG.db.compactMode == compact and PTG.db.position == position
                and frame:GetLeft() == left and frame:GetTop() == top and view.applications == applications
                and PTG.started == savedStarts and PTG.steps == savedSteps
                and PTG.settingsChanged == savedChanges and PTG.cancelled == savedCancel,
                "Escape preserves the assistant, applications and saved view without starting or stepping")
        end
    end
    local otherIndex = 0
    for _, name in ipairs(UISpecialFrames) do
        if name ~= "PressToGroupFrame" then
            otherIndex = otherIndex + 1
            check(name == otherEntries[otherIndex], "Escape registration keeps other entries in their original order")
        end
    end
    check(otherIndex == #otherEntries, "Escape registration neither adds nor removes other entries")
    PTG.Stop = originalStop
end
do
    local picker, settings = PTG.dungeonPicker, PTG.settingsUI
    local savedDungeons = PTG.GetDungeons
    local actions = {Start = 0, Stop = 0, OnPress = 0, Cancel = 0, SettingsChanged = 0}
    local originals = {}
    for name in pairs(actions) do
        originals[name] = PTG[name]
        PTG[name] = function(self, ...)
            actions[name] = actions[name] + 1
            if name == "Stop" then view.running, view.state = false, "off" end
            return originals[name](self, ...)
        end
    end
    frame:Show()
    view.running, view.state = true, "ready_search"
    PTG.db.dungeons = {[101] = true, [999] = true}
    local applications = view.applications
    for _, locale in ipairs({"ruRU", "enUS"}) do
        PTG.db.locale = locale
        for _, compact in ipairs({false, true}) do
            PTG:SetCompactMode(compact)
            check(frame.dungeons.parent == frame and frame.dungeons:IsVisible()
                and frame.dungeons:GetText() == (locale == "ruRU" and "Подземелья 1/2" or "Dungeons 1/2"),
                "quick selection is available in either view and counts only current dungeon IDs: " .. locale)
            if compact then
                check(frame.compactApplications:GetLeft() + frame.compactApplications.width <= frame.dungeons:GetLeft()
                    and frame.dungeons:GetLeft() + frame.dungeons.width <= frame:GetLeft() + frame.width,
                    "compact application and dungeon counts have separate bounded areas: " .. locale)
            else
                check(frame.open:GetLeft() + frame.open.width <= frame.dungeons:GetLeft()
                    and frame.dungeons:GetLeft() + frame.dungeons.width <= frame.settings:GetLeft()
                    and frame.settings:GetLeft() + frame.settings.width <= frame:GetLeft() + frame.width,
                    "full footer keeps search, dungeons and settings separate: " .. locale)
            end
            frame.dungeons.scripts.OnClick()
            check(picker:IsVisible() and picker.parent == frame and not settings:IsShown(),
                "the quick selection button opens its panel beside the main window")
            frame.dungeons.scripts.OnClick()
            check(not picker:IsShown() and view.running, "the same button dismisses only quick selection")
        end
    end
    check(actions.SettingsChanged == 0 and actions.Stop == 0 and actions.Start == 0
        and actions.OnPress == 0 and actions.Cancel == 0, "opening and closing quick selection never changes filters or acts on LFG")
    PTG:SetCompactMode(false)
    frame.dungeons.scripts.OnClick()
    local function select(id, selected)
        local control = picker.dungeonChecks[id]
        control:SetChecked(selected)
        control.scripts.OnClick(control)
    end
    select(101, false)
    check(PTG.db.dungeons[101] == nil and PTG.db.dungeons[999] and picker:IsShown()
        and actions.SettingsChanged == 1 and frame.dungeons:GetText() == "Dungeons 0/2",
        "a quick change applies once, updates the count and keeps the panel open")
    select(102, true)
    check(PTG.db.dungeons[102] and picker:IsShown()
        and actions.SettingsChanged == 2, "sequential quick changes share the existing dungeon selection")
    settings:Show()
    check(not picker:IsShown() and settings:IsShown() and not settings.dungeonChecks[101]:GetChecked()
        and settings.dungeonChecks[102]:GetChecked(), "opening settings dismisses quick selection and displays its current selections")
    settings.dungeonChecks[101]:SetChecked(true)
    settings.dungeonChecks[101].scripts.OnClick(settings.dungeonChecks[101])
    check(picker.dungeonChecks[101]:GetChecked() and frame.dungeons:GetText() == "Dungeons 2/2"
        and not picker.allDungeons:IsEnabled(), "settings changes refresh the hidden picker and main count")
    PTG:SetInputMode("key")
    settings.bindingAssign.scripts.OnClick()
    check(PTG.bindingCapture ~= nil, "key capture is active before opening quick selection")
    frame.dungeons.scripts.OnClick()
    check(picker:IsShown() and not settings:IsShown() and not PTG.bindingCapture,
        "opening quick selection hides settings and cancels unfinished key capture")
    select(101, false)
    local changed = actions.SettingsChanged
    picker.allDungeons.scripts.OnClick()
    check(PTG.db.dungeons[101] and PTG.db.dungeons[102] and PTG.db.dungeons[999] == nil
        and PTG.db.dungeonsInitialized and picker:IsShown() and not picker.allDungeons:IsEnabled()
        and actions.SettingsChanged == changed + 1, "quick All selects only current IDs and applies once")
    select(101, false)
    select(102, false)
    check(next(PTG.db.dungeons) == nil and PTG.db.dungeonsInitialized and picker:IsShown()
        and picker.allDungeons:IsEnabled() and frame.dungeons:GetText() == "Dungeons 0/2",
        "quick selection permits an intentional empty filter instead of restoring every dungeon")
    function PTG:GetDungeons() return {} end
    PTG:RefreshUI()
    check(picker.dungeonEmpty:IsShown() and not picker.dungeonChecks[101]:IsShown()
        and not picker.dungeonChecks[102]:IsShown() and not picker.allDungeons:IsEnabled()
        and frame.dungeons:GetText() == "Dungeons 0/0", "missing season data hides stale quick rows and updates the count")
    local late = {}
    for id = 301, 320 do late[#late + 1] = {id = id, name = string.rep("Длинное название подземелья ", 5) .. id} end
    function PTG:GetDungeons() return late end
    PTG:RefreshUI()
    local longRow = picker.dungeonChecks[301]
    longRow.text.stringHeight = 72
    PTG:RefreshUI()
    local _, longY = offsets(longRow)
    local _, nextY = offsets(picker.dungeonChecks[302])
    check(not picker.dungeonEmpty:IsShown() and not picker.dungeonChecks[101]:IsShown()
        and longRow:IsShown() and frame.dungeons:GetText() == "Dungeons 0/20",
        "late season data replaces old quick rows without counting saved IDs")
    check(longRow.text:GetText() == late[1].name and longRow.text.wordWrap ~= false
        and longRow.height >= longRow.text:GetStringHeight() + 16 and longY - longRow.height >= nextY,
        "quick selection preserves complete wrapped names and separates expanded rows")
    check(picker.width == 384 and picker.height <= 480 and picker.content.height > picker.height
        and picker.scroll and picker.content.width == 328, "a long quick list uses bounded scroll content")
    UIParent:SetHeight(240)
    PTG:RefreshUI()
    check(picker.height <= UIParent:GetHeight(), "the quick panel also fits a shorter UIParent")
    UIParent:SetHeight(1080)
    PTG.GetDungeons = savedDungeons
    PTG:RefreshUI()
    check(not longRow:IsShown() and picker.dungeonChecks[101]:IsShown(), "returning season data hides cached quick rows")
    local left, top = frame:GetLeft(), frame:GetTop()
    for _, compact in ipairs({true, false}) do
        PTG:SetCompactMode(compact)
        check(picker:IsShown() and picker:IsVisible() and picker.point[2] == frame
            and frame:GetLeft() == left and frame:GetTop() == top,
            "view changes retain the open quick panel anchored to the main window")
    end
    changed = actions.SettingsChanged
    UIParent:Hide()
    check(picker:IsShown() and not picker:IsVisible() and frame:IsShown() and view.running and actions.Stop == 0,
        "Alt-Z temporarily hides quick selection without changing its shown state or stopping")
    UIParent:Show()
    check(picker:IsVisible() and view.running, "restoring the interface restores the open quick selection")
    picker.close.scripts.OnClick()
    check(not picker:IsShown() and view.running and actions.Stop == 0 and actions.SettingsChanged == changed,
        "the picker close control only dismisses its own panel")
    local registered = 0
    for _, name in ipairs(UISpecialFrames) do if name == picker.name then registered = registered + 1 end end
    check(picker.name and registered == 1, "quick selection has its own single Escape registration")
    for _, running in ipairs({true, false}) do
        view.running = running
        frame:Show()
        PTG:RefreshUI()
        frame.dungeons.scripts.OnClick()
        for _, name in ipairs(UISpecialFrames) do
            if name == picker.name then picker:Hide()
            elseif name == frame.name then frame:Hide() end
        end
        check(not picker:IsShown() and frame:IsShown() == running and view.running == running and actions.Stop == 0,
            "Escape closes quick selection while preserving the main window's running rule")
    end
    frame:Show()
    view.running = true
    PTG:RefreshUI()
    frame.dungeons.scripts.OnClick()
    frame.close.scripts.OnClick()
    check(not frame:IsShown() and not picker:IsShown() and not view.running and actions.Stop == 1,
        "explicit main closure dismisses quick selection and stops once")
    frame:Show()
    check(not picker:IsShown() and actions.Stop == 1 and not view.running,
        "reopening the main window keeps quick selection closed and the assistant stopped")
    check(view.applications == applications and actions.Start == 0 and actions.OnPress == 0 and actions.Cancel == 0
        and actions.SettingsChanged == changed, "quick panel lifecycle preserves applications without LFG actions or extra filter changes")
    for name, original in pairs(originals) do PTG[name] = original end
end
print("ui_test: " .. checks .. " checks passed")
