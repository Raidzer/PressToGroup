local PTG = {}
local source = arg and arg[0] and arg[0]:gsub("\\", "/") or "tests/ui_test.lua"
local root = source:match("^(.*)/tests/[^/]+$") or "."
local checks = 0
local function check(value, message)
    assert(value, message)
    checks = checks + 1
end

GetLocale = function() return "ruRU" end
unpack = unpack or table.unpack
tinsert = table.insert
UISpecialFrames = {}
wipe = function(values) for key in pairs(values) do values[key] = nil end end

local Widget = {}
Widget.__index = Widget
function Widget:new() return setmetatable({ scripts = {}, shown = true, enabled = true }, self) end
function Widget:SetScript(event, callback) self.scripts[event] = callback end
function Widget:SetText(text) self.text = text end
function Widget:GetText() return self.text or "" end
function Widget:SetNumber(number) self:SetText(tostring(number)) end
function Widget:SetHeight(height) self.height = height end
function Widget:SetSize(width, height) self.width, self.height = width, height end
function Widget:SetPoint(...) self.point = { ... } end
function Widget:SetChecked(checked) self.checked = checked end
function Widget:GetChecked() return self.checked end
function Widget:SetEnabled(enabled) self.enabled = enabled end
function Widget:Show()
    local wasShown = self.shown
    self.shown = true
    if not wasShown and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function Widget:Hide() self.shown = false end
function Widget:SetShown(shown) if shown then self:Show() else self:Hide() end end
function Widget:IsShown() return self.shown end
function Widget:GetCenter() return 100, 100 end
function Widget:GetStringHeight() return 12 end
function Widget:HasFocus() return false end
function Widget:CreateFontString() return Widget:new() end
for _, method in ipairs({ "SetJustifyH", "SetJustifyV", "SetWidth", "SetFrameStrata",
    "SetBackdrop", "SetClampedToScreen", "SetMovable", "EnableMouse", "ClearAllPoints",
    "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "SetAutoFocus", "SetNumeric", "SetMaxLetters",
    "SetScrollChild", "SetFontObject", "SetWordWrap", "ClearFocus" }) do
    Widget[method] = function() end
end
CreateFrame = function() return Widget:new() end
UIParent = Widget:new()

assert(loadfile(root .. "/Locale.lua"))("PressToGroup", PTG)
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
    "unavailable", "no_query", "no_dungeons_selected", "search_conflict", "search_timeout", "search_failed", "search_empty", "no_candidates",
    "wait_apply", "wait_cancel", "apply_sent", "cancel_sent" }) do
    check(dictionaries.enUS[key] ~= nil, "unlocalized dynamic state: " .. key)
end

PTG.db = { locale = "auto", role = "HEALER", minRating = 3000,
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
function PTG:OnPress() self.steps = (self.steps or 0) + 1 end
function PTG:Cancel(id) self.cancelled = id end
function PTG:Start() self.started = true end
function PTG:Stop() self.stopped = true end
function PTG:OpenSearch() self.searchOpened = true end
function PTG:PrintLog() self.logOpened = true end

assert(loadfile(root .. "/UI.lua"))("PressToGroup", PTG)
PTG:BuildUI()
check(PTG.ui.status.text == PTG:L("waiting_search", 6), "state arguments are formatted")
check(PTG.ui.counts.text:find("\n", 1, true), "counts use two explicit lines")
check(PTG.ui.counts.point[3] - PTG.ui.counts.height > PTG.ui.response.point[3], "counts do not overlap response time")
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
check(not PTG.settingsUI.languageChecks.ruRU.enabled, "mandatory language cannot be changed")
check(PTG.settingsUI.dungeonChecks[101]:GetChecked() and not PTG.settingsUI.dungeonChecks[102]:GetChecked(), "dungeon checkboxes show only explicit selections")
check(PTG.settingsUI.allDungeons.enabled, "all dungeons is available when a visible dungeon is unchecked")
PTG.settingsUI.localeButtons[3].scripts.OnClick()
check(PTG.db.locale == "enUS" and PTG.db.languages.enUS and PTG.db.dungeons[101], "UI language preserves search selections")
PTG.settingsUI.roleButtons[1].scripts.OnClick()
check(PTG.db.role == "TANK" and PTG.db.languages.enUS and PTG.db.dungeons[101], "role preserves other settings")
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
print("ui_test: " .. checks .. " checks passed")
