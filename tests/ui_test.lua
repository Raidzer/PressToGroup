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
    "wait_apply", "wait_cancel", "apply_sent", "cancel_sent" }) do
    check(dictionaries.enUS[key] ~= nil, "unlocalized dynamic state: " .. key)
end

PTG.db = { locale = "auto", role = "HEALER", autoRole = true, compactMode = false, minRating = 3000, replaceAfter = 180,
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
PTG.specRole = "HEALER"
function PTG:OnPress() self.steps = (self.steps or 0) + 1 end
function PTG:Cancel(id) self.cancelled = id end
function PTG:Start() self.started = true end
function PTG:Stop() self.stopped = true end
function PTG:OpenSearch() self.searchOpened = true end
function PTG:PrintLog() self.logOpened = true end
function PTG:ToggleWindow() self.windowToggles = (self.windowToggles or 0) + 1 end

assert(loadfile(root .. "/UI.lua"))("PressToGroup", PTG)
local initialCandidate, initialApplications = view.nextCandidate, view.applications
view.nextCandidate, view.applications = nil, {}
PTG:BuildUI()
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
check(escapes == 1, "main window is registered for Escape once")
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
    "closing the window only hides it without changing the assistant")
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
check(GameTooltip.line == "Show / hide the assistant window", "minimap tooltip follows a language change")
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
    searching = "waiting", wait_apply = "waiting", wait_cancel = "waiting", full = "waiting",
    manual_search = "paused", chat_lockdown = "paused", no_role = "paused", no_dungeons_selected = "paused",
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
    "search_failed", "search_timeout", "search_conflict", "operation_unknown", "unsupported", "error", "future_state"}) do
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
check(not frame.full:IsShown() and not frame.close:IsVisible() and frame.collapse:IsVisible()
    and frame.collapse:GetText() == "+" and frame.compactApplications:IsVisible(),
    "compact mode exposes its restore control and count while hiding full-window content")
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
frame:Hide()
check(not GameTooltip:IsShown(), "hiding the compact window also hides its child's active tooltip")
frame:Show()
check(PTG.db.compactMode and frame.width == 300 and not frame.full:IsVisible(),
    "hiding and showing the window preserves the compact representation")
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
    and frame.collapse:GetText() == "−", "restore returns the complete full-size interface")
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
    PTG.ui, PTG.settingsUI, PTG.minimapButton, PTG.groupFinderButton = nil, nil, nil, nil
    PTG:BuildUI()
    frame = PTG.ui
end
rebuildWindow()
check(PTG.db.compactMode and frame.width == 300 and frame.height == 72
    and frame:GetLeft() == left and frame:GetTop() == top and not frame.full:IsVisible(),
    "a new UI session restores the compact size and position directly")
PTG:SetCompactMode(false)
rebuildWindow()
check(not PTG.db.compactMode and frame.width == 440 and frame.height == 620
    and frame:GetLeft() == left and frame:GetTop() == top and frame.full:IsVisible(),
    "a mode change without a drag survives a new full UI session without position drift")
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
print("ui_test: " .. checks .. " checks passed")
