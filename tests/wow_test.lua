local PTG = {}
unpack = unpack or table.unpack
local checks = 0
local function check(value, message)
    assert(value, message)
    checks = checks + 1
end
local now, grouped, combat, chatLocked, queueMessage = 100, false, false, false, nil
local specIndex, specID, specRole = 2, 257, "HEALER"
local calls, apps, results, frames = {}, {}, {}, {}
local source = arg and arg[0] and arg[0]:gsub("\\", "/") or "tests/wow_test.lua"
local root = source:match("^(.*)/tests/[^/]+$") or "."
GetTime = function() return now end
GetLocale = function() return "ruRU" end
IsInGroup = function() return grouped end
InCombatLockdown = function() return combat end
UnitClass = function() return "Жрец", "PRIEST" end
GetAverageItemLevel = function() return 180, 175 end
C_SpecializationInfo = {
    GetSpecialization = function() return specIndex end,
    GetSpecializationInfo = function(index)
        assert(index == specIndex and index ~= nil, "read the active specialization index")
        return specID, "Свет", "", 0, specRole
    end,
}
GetSpecialization, GetSpecializationInfo, GetSpecializationRole = nil, nil, nil
issecretvalue = function(value) return value == "SECRET" end
bit = {bor = function(a, b) return a + b end}
Enum = {LFGListFilter = {CurrentSeason = 1, PvE = 2}}
MAX_LFG_LIST_APPLICATIONS = 5
C_ChatInfo = {InChatMessagingLockdown = function() return chatLocked end}
SOUNDKIT = {READY_CHECK = 8960}
PlaySound = function() calls[#calls + 1] = {kind = "sound"} end
SlashCmdList = {}
local text = "+19"
LFGListFrame = {shown = false, parentVisible = true, CategorySelection = {}, SearchPanel = {
    categoryID = 2, SearchBox = {GetText = function() return text end},
}}
function LFGListFrame:IsShown() return self.shown end
function LFGListFrame:IsVisible() return self.shown and self.parentVisible end
LFGListUtil_GetActiveQueueMessage = function() return queueMessage end
PVEFrame_ShowFrame = function() LFGListFrame.shown, LFGListFrame.parentVisible = true, true end
LFGListFrame_SetActivePanel = function() calls[#calls + 1] = {kind = "open"} end
LFGListCategorySelection_SelectCategory = function() error("should preserve the current category") end
LFGListCategorySelection_StartFindGroup = function() error("must not clear the query") end
CreateFrame = function()
    local frame = {scripts = {}, events = {}}
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(key, callback) self.scripts[key] = callback end
    frames[#frames + 1] = frame
    return frame
end
local function emit(event, ...)
    for _, frame in ipairs(frames) do
        if frame.events[event] then frame.scripts.OnEvent(frame, event, ...) end
    end
end
local function update(dt)
    for _, frame in ipairs(frames) do
        if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, dt) end
    end
end
local activities = {
    [101] = {fullName = "Подземелье А", isMythicPlusActivity = true},
    [102] = {fullName = "Подземелье Б", isMythicPlusActivity = true},
    [103] = {fullName = "Героическое", isMythicPlusActivity = false},
}
C_LFGList = {
    GetAvailableActivities = function(category, group, flags)
        check(category == 2 and flags == 3, "current-season PvE activities")
        return {101, 102, 103}
    end,
    GetActivityInfoTable = function(id) return activities[id] end,
    GetAvailableLanguageSearchFilter = function() return {"ruRU", "enUS", "deDE"} end,
    GetDefaultLanguageSearchFilter = function() return {ruRU = true} end,
    GetLanguageSearchFilter = function() return {ruRU = true} end,
    GetAvailableRoles = function() return false, true, true end,
    GetActiveEntryInfo = function() return nil end,
    GetApplications = function()
        local ids = {}
        for id, app in pairs(apps) do if app.status ~= "none" or app.pending then ids[#ids + 1] = id end end
        return ids
    end,
    GetApplicationInfo = function(id)
        local app = apps[id] or {status = "none"}
        return id, app.status, app.pending, 300
    end,
    GetNumApplications = function()
        local count = 0
        for _, app in pairs(apps) do
            if app.status == "applied" or app.pending then count = count + 1 end
        end
        return count, count
    end,
    GetSearchResultInfo = function(id)
        check(not chatLocked, "never read secret search fields during lockdown")
        return results[id]
    end,
    GetSearchResultMemberCounts = function(id)
        return results[id].counts or {TANK = 1, HEALER = 0, DAMAGER = 2,
            TANK_REMAINING = 0, HEALER_REMAINING = results[id].remaining or 1, DAMAGER_REMAINING = 1}
    end,
    GetSearchResultPlayerInfo = function(id, index)
        return {classFilename = index == 1 and "WARRIOR" or "MAGE"}
    end,
    ValidateRequiredDungeonScore = function(score) return score <= 3654 end,
    GetSearchResults = function() return 1, {1} end,
    Search = function(...)
        calls[#calls + 1] = {kind = "search", args = {...}}
    end,
    ApplyToGroup = function(id, tank, healer, damage)
        calls[#calls + 1] = {kind = "apply", id = id, tank = tank, healer = healer, damage = damage}
        apps[id] = {status = "none", pending = "applied"}
    end,
    CancelApplication = function(id)
        calls[#calls + 1] = {kind = "cancel", id = id}
        apps[id].pending = "cancelled"
    end,
}
local casts = 0
SecureActionButton_OnClick = function() casts = casts + 1; return true end
SecureActionButton_ShouldUseOnKeyDown = function() return true end
hooksecurefunc = function(target, key, callback)
    if type(target) == "string" then callback, key, target = key, target, _G end
    local original = target[key]
    target[key] = function(...)
        local result = original(...)
        callback(...)
        return result
    end
end

local nativeSearch, nativeClick = C_LFGList.Search, SecureActionButton_OnClick
local function loadSession(db)
    PTG, frames, PressToGroupDB = {}, {}, db
    C_LFGList.Search, SecureActionButton_OnClick = nativeSearch, nativeClick
    for _, file in ipairs({"Locale", "Filters", "Input", "Engine"}) do
        assert(loadfile(root .. "/" .. file .. ".lua"))("PressToGroup", PTG)
    end
    function PTG:BuildUI() end
    function PTG:BuildGroupFinderButton() self.groupFinderBuilds = (self.groupFinderBuilds or 0) + 1 end
    function PTG:RefreshUI() end
    assert(loadfile(root .. "/WoW.lua"))("PressToGroup", PTG)
    emit("ADDON_LOADED", "PressToGroup")
end
loadSession()
check(PTG.engine ~= nil and not PTG.engine.running, "loads without deprecated specialization globals; starts OFF")
local loadedEngine, loadedCalls = PTG.engine, #calls
emit("ADDON_LOADED", "UnrelatedAddon")
check(PTG.groupFinderBuilds == nil, "unrelated addon loads do not rebuild Group Finder controls")
emit("ADDON_LOADED", "Blizzard_GroupFinder")
emit("ADDON_LOADED", "PremadeGroupsFilter")
check(PTG.groupFinderBuilds == 2 and PTG.engine == loadedEngine and #calls == loadedCalls,
    "late Group Finder and PGF loads attach the toggle without restarting the engine or performing LFG actions")
check(PTG.db.autoRole == true, "new characters default to automatic specialization role")
check(PTG.db.compactMode == false, "new characters default to the full window")
check(PTG.db.role == "HEALER", "current specialization role")
check(PTG.db.replaceAfter == 180, "missing replacement age defaults to 180 seconds")
check(PTG.db.dungeons[101] and PTG.db.dungeons[102] and PTG.db.dungeonsInitialized,
    "all season dungeons are explicitly checked by default")
PTG.db.dungeons, PTG.db.dungeonsInitialized = {[101] = true}, nil
PTG:LoadDungeons()
check(PTG.db.dungeons[101] and not PTG.db.dungeons[102] and PTG.db.dungeonsInitialized,
    "migration preserves a previous explicit subset")
local availableActivities = C_LFGList.GetAvailableActivities
PTG.db.dungeons, PTG.db.dungeonsInitialized = {}, nil
C_LFGList.GetAvailableActivities = function() return {} end
PTG:LoadDungeons()
check(not PTG.db.dungeonsInitialized, "missing initial season data defers default selection")
C_LFGList.GetAvailableActivities = availableActivities
PTG:LoadDungeons()
check(PTG.db.dungeons[101] and PTG.db.dungeons[102] and PTG.db.dungeonsInitialized,
    "legacy empty selection is migrated to checked defaults when data arrives")
local activityInfo = C_LFGList.GetActivityInfoTable
PTG.db.dungeons, PTG.db.dungeonsInitialized = {}, nil
C_LFGList.GetActivityInfoTable = function(id) if id ~= 102 then return activityInfo(id) end end
PTG:LoadDungeons()
check(not PTG.db.dungeonsInitialized and next(PTG.db.dungeons) == nil,
    "partially loaded activity details cannot finalize the default selection")
C_LFGList.GetActivityInfoTable = activityInfo
PTG:LoadDungeons()
check(PTG.db.dungeons[101] and PTG.db.dungeons[102] and PTG.db.dungeonsInitialized,
    "late-loaded activity details also get their default checkmark")
PTG.db.dungeons = {}
PTG:LoadDungeons()
check(next(PTG.db.dungeons) == nil, "intentional empty selection survives settings reload")
local noSelectionCalls = #calls
PTG:Start()
PTG:OnPress()
check(PTG:GetView().state == "no_dungeons_selected" and #calls == noSelectionCalls,
    "zero checked dungeons pauses without sending a wildcard search")
check(not PTG.engine.api:Search(PTG.db) and #calls == noSelectionCalls,
    "the search adapter independently refuses an empty selection")
PTG.db.dungeons[101] = true
PTG:SettingsChanged()
check(#PTG:GetDungeons() == 2 and not PTG.activities[103], "only season M+ dungeons")
PTG.dungeons, PTG.activities = {}, {}
emit("LFG_LIST_AVAILABILITY_UPDATE")
check(#PTG:GetDungeons() == 2, "late native availability refreshes dungeon data")
check(PTG.db.log == PTG.engine.log, "short diagnostics are saved")
PTG.db.languages.enUS = true
local languages = PTG:GetLanguages()
check(languages[1].mandatory and languages[2].selected, "default plus chosen language")
LFGListFrame.shown = true
PTG:Start()
local pausedCalls = #calls
PTG:OnPress()
check(PTG:GetView().state == "manual_search" and #calls == pausedCalls, "visible native finder pauses actions")
LFGListFrame.parentVisible = false
PTG.engine:Plan()
check(PTG:GetView().state == "ready_search", "closing the native parent window releases the search pause")
local action = {action = 1, GetName = function() return "ActionButton1" end, GetAttribute = function() end}
SecureActionButton_OnClick(action, "LeftButton", true, true, true)
check(casts == 1 and calls[#calls].kind == "search", "game action and one LFG step")
local request = calls[#calls].args
check(request[1] == 2 and request[2] == 0 and request[3] == 0, "native category and filter positions")
check(request[4].ruRU and request[4].enUS and not request[4].deDE, "language table in the fourth argument")
check(request[6].difficultyMythicPlus and request[6].needsHealer, "own native advanced filter")
check(#request[7] == 1 and request[7][1] == 101, "only checked dungeon IDs are sent in the seventh argument")
check(not PTG.engine.conflict, "own search hook is not a foreign query")
do
    local finder, originalText = LFGListFrame, text
    local shown, parentVisible = finder.shown, finder.parentVisible
    local engine = PTG.engine
    local state, revision, search, queryText, before = engine.state, engine.revision, engine.search, PTG.queryText, #calls
    text = "+20"
    finder.shown, finder.parentVisible = false, true
    check(PTG:GetView().groupFinderVisible == false, "the view reports a hidden native finder as closed")
    finder.shown = true
    check(PTG:GetView().groupFinderVisible == true, "the view reports a visible native finder as open")
    finder.parentVisible = false
    local view = PTG:GetView()
    check(view.groupFinderVisible == false, "the view accounts for a hidden native parent")
    check(view.searchText == "+20" and PTG.queryText == queryText,
        "the view reads changed query text without synchronizing engine settings")
    LFGListFrame = nil
    view = PTG:GetView()
    check(view.groupFinderVisible == false and view.searchText == nil, "the view tolerates an unloaded native finder")
    LFGListFrame, text = finder, originalText
    finder.shown, finder.parentVisible = shown, parentVisible
    check(engine.state == state and engine.revision == revision and engine.search == search
        and not search.stale and #calls == before,
        "reading native finder visibility preserves the outstanding search and performs no LFG actions")
end
local count = #calls
SecureActionButton_OnClick(action, "LeftButton", false, true, true)
check(casts == 2 and #calls == count, "release keeps spell behavior and does not cause another step")
results[1] = {activityIDs = {101}, partyGUID = "Party-1", age = 15, numMembers = 3,
    isDelisted = false, hasSelf = false, requiredItemLevel = 170,
    requiredDungeonScore = 3000, leaderOverallDungeonScore = 3600, name = "+19 группа"}
now = now + 1
emit("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check(PTG:GetView().eligible == 1 and PTG.engine.lastResponse == now, "own response and fresh candidate")
PTG:OnPress()
check(calls[#calls].kind == "apply" and calls[#calls].healer and not calls[#calls].tank,
    "apply uses the chosen role")
check(not next(PTG.engine.owned), "native call alone does not grant ownership")
apps[1] = {status = "applied"}
emit("LFG_LIST_APPLICATION_STATUS_UPDATED", 1)
check(PTG:GetView().applications[1].owned, "confirmed app is owned")
PTG:Stop()
check(apps[1].status == "applied", "Stop retains applications")
PTG:Cancel(1)
check(calls[#calls].kind == "cancel", "explicit own cancel while stopped")
apps[1] = {status = "none"}
emit("LFG_LIST_APPLICATION_STATUS_UPDATED", 1)
PTG:OpenSearch()
check(text == "+19" and calls[#calls].kind == "open", "opening the same search preserves key text")
LFGListFrame.parentVisible = false

local api = PTG.engine.api
do
    local nativePlayerInfo = C_LFGList.GetSearchResultPlayerInfo
    local classes = {"WARRIOR", "ROGUE", "MONK"}
    local counts = {TANK = 1, HEALER = 0, DAMAGER = 1,
        TANK_REMAINING = 0, HEALER_REMAINING = 1, DAMAGER_REMAINING = 2}
    results[2] = {activityIDs = {101}, partyGUID = "Remaining-Party", age = 15, numMembers = 2,
        isDelisted = false, hasSelf = false, requiredItemLevel = 170,
        requiredDungeonScore = 3000, leaderOverallDungeonScore = 3600, counts = counts}
    C_LFGList.GetSearchResultPlayerInfo = function(id, index)
        if id == 2 then return {classFilename = classes[index]} end
        return nativePlayerInfo(id, index)
    end
    local snapshot = api:ReadGroup(2)
    check(snapshot.roleRemaining ~= snapshot.roleCounts and snapshot.roleRemaining ~= counts
        and snapshot.roleRemaining.TANK == 0 and snapshot.roleRemaining.HEALER == 1
        and snapshot.roleRemaining.DAMAGER == 2 and snapshot.roleCounts.DAMAGER == 1,
        "remaining-role API values form a separate snapshot from actual member counts")
    counts.DAMAGER_REMAINING = 1
    check(snapshot.roleRemaining.DAMAGER == 2, "later native table changes do not mutate a previous snapshot")
    check(PTG.Filters.Eligible(snapshot, {requireLust = true, requireBrez = true}, api:Player()),
        "two public damage slots can supply both missing capabilities after joining")
    snapshot = api:ReadGroup(2)
    check(PTG.Filters.Eligible(snapshot, {requireLust = true}, api:Player())
        and PTG.Filters.Eligible(snapshot, {requireBrez = true}, api:Player())
        and not PTG.Filters.Eligible(snapshot, {requireLust = true, requireBrez = true}, api:Player()),
        "one remaining damage slot cannot supply two distinct missing capabilities")
    counts.DAMAGER_REMAINING = 0
    snapshot = api:ReadGroup(2)
    check(snapshot.eligible and snapshot.roleRemaining.DAMAGER == 0
        and PTG.Filters.Eligible(snapshot, {}, api:Player())
        and not PTG.Filters.Eligible(snapshot, {requireLust = true}, api:Player())
        and not PTG.Filters.Eligible(snapshot, {requireBrez = true}, api:Player()),
        "a public zero reserves damage slots despite geometric space; the joining healer slot is consumed")
    counts.TANK, counts.DAMAGER, counts.TANK_REMAINING = 0, 3, 1
    results[2].numMembers = 3
    snapshot = api:ReadGroup(2)
    check(PTG.Filters.Eligible(snapshot, {requireBrez = true}, api:Player())
        and not PTG.Filters.Eligible(snapshot, {requireLust = true}, api:Player())
        and not PTG.Filters.Eligible(snapshot, {requireLust = true, requireBrez = true}, api:Player()),
        "three damage dealers leave only a battle-resurrection tank slot after the priest joins")
    counts.TANK, counts.DAMAGER, counts.TANK_REMAINING = 1, 2, 0
    for _, invalid in ipairs({{name = "missing"}, {name = "secret", value = "SECRET"},
        {name = "text", value = "2"}, {name = "boolean", value = false}, {name = "table", value = {}}}) do
        counts.TANK_REMAINING, counts.DAMAGER_REMAINING = invalid.value, invalid.value
        snapshot = api:ReadGroup(2)
        check(snapshot and snapshot.eligible and snapshot.roleRemaining.TANK == nil
            and snapshot.roleRemaining.DAMAGER == nil
            and PTG.Filters.Eligible(snapshot, {}, api:Player()),
            "optional unavailable remaining fields preserve usable groups with disabled filters: " .. invalid.name)
        check(not PTG.Filters.Eligible(snapshot, {requireLust = true}, api:Player()),
            "unknown future slots cannot confirm a missing capability: " .. invalid.name)
        classes[2], classes[3] = "MAGE", "WARLOCK"
        snapshot = api:ReadGroup(2)
        check(PTG.Filters.Eligible(snapshot, {requireLust = true, requireBrez = true}, api:Player()),
            "known capability classes do not require optional future fields: " .. invalid.name)
        classes[2], classes[3] = "ROGUE", "MONK"
    end
    counts.TANK_REMAINING = 0
    for _, invalid in ipairs({{name = "negative", value = -1}, {name = "fraction", value = 0.5},
        {name = "NaN", value = 0 / 0}, {name = "infinity", value = math.huge},
        {name = "negative infinity", value = -math.huge}, {name = "over capacity", value = 2}}) do
        counts.DAMAGER_REMAINING = invalid.value
        snapshot = api:ReadGroup(2)
        check(snapshot and snapshot.eligible and type(snapshot.roleRemaining.DAMAGER) == "number"
            and not PTG.Filters.Eligible(snapshot, {requireLust = true}, api:Player()),
            "public numeric remaining fields reach capacity validation: " .. invalid.name)
    end
    counts.DAMAGER_REMAINING = 1
    for _, invalid in ipairs({{name = "missing"}, {name = "secret", value = "SECRET"},
        {name = "text", value = "1"}, {name = "boolean", value = false}}) do
        counts.HEALER_REMAINING = invalid.value
        check(api:ReadGroup(2) == nil,
            "the selected role still requires its own public numeric remaining field: " .. invalid.name)
    end
    counts.HEALER_REMAINING = 0
    snapshot = api:ReadGroup(2)
    check(snapshot and not snapshot.eligible and snapshot.roleRemaining.HEALER == 0,
        "zero selected-role availability is retained and prevents joining")
    C_LFGList.GetSearchResultPlayerInfo, results[2] = nativePlayerInfo, nil
end
results[1].remaining = 0
check(api:IsRoleFull(1, "Party-1", "HEALER") == false,
    "a reserved healer slot does not mean the actual healer role is filled")
results[1].counts = {TANK = 1, HEALER = 1, DAMAGER = 1}
check(api:IsRoleFull(1, "Party-1", "HEALER") == true, "an actual healer fills the role")
check(api:IsRoleFull(1, "Party-1", "DAMAGER") == false, "damage capacity is three actual members")
check(api:IsRoleFull(1, "Other-Party", "HEALER") == nil, "different party identity is unknown")
check(api:IsRoleFull(999, "Party-1", "HEALER") == nil, "missing group data is unknown")
local listing = results[1]
for field, invalid in pairs({partyGUID = "", numMembers = "SECRET", activityIDs = "SECRET",
    isDelisted = "SECRET", hasSelf = "SECRET"}) do
    local original = listing[field]
    listing[field] = invalid
    check(api:IsRoleFull(1, "Party-1", "HEALER") == nil, "invalid composition field: " .. field)
    listing[field] = nil
    check(api:IsRoleFull(1, "Party-1", "HEALER") == nil, "missing composition field: " .. field)
    listing[field] = original
end
for _, field in ipairs({"isDelisted", "hasSelf"}) do
    listing[field] = true
    check(api:IsRoleFull(1, "Party-1", "HEALER") == nil, "unusable listing is unknown: " .. field)
    listing[field] = false
end
for _, invalid in ipairs({"SECRET", {TANK = 1, HEALER = "SECRET", DAMAGER = 1},
    {TANK = 1, HEALER = 1, DAMAGER = 2}, {TANK = 1, HEALER = 0.5, DAMAGER = 1.5}}) do
    listing.counts = invalid
    check(api:IsRoleFull(1, "Party-1", "HEALER") == nil, "secret or inconsistent member counts are unknown")
end
listing.counts = {TANK = 1, HEALER = 1, DAMAGER = 1}
listing.activityIDs = {103}
check(api:IsRoleFull(1, "Party-1", "HEALER") == nil, "a non-M+ activity cannot confirm a filled role")
listing.activityIDs = {"SECRET"}
check(api:IsRoleFull(1, "Party-1", "HEALER") == nil, "a secret activity cannot confirm a filled role")
listing.activityIDs = {102}
check(api:ReadGroup(1) == nil and api:IsRoleFull(1, "Party-1", "HEALER") == true,
    "a known unchecked dungeon still provides actual composition")
listing.activityIDs = {101}
local itemLevel, scoreCheck = GetAverageItemLevel, C_LFGList.ValidateRequiredDungeonScore
GetAverageItemLevel = function() error("filled-role checks do not need player item level") end
C_LFGList.ValidateRequiredDungeonScore = function() error("filled-role checks do not need player rating") end
listing.leaderOverallDungeonScore, listing.requiredDungeonScore, listing.requiredItemLevel = "SECRET", "SECRET", "SECRET"
check(api:IsRoleFull(1, "Party-1", "HEALER") == true,
    "rating, item level, and remaining-slot availability do not control actual composition")
GetAverageItemLevel, C_LFGList.ValidateRequiredDungeonScore = itemLevel, scoreCheck
listing.leaderOverallDungeonScore, listing.requiredDungeonScore, listing.requiredItemLevel = 3600, 3000, 170
local readInfo, readCounts = C_LFGList.GetSearchResultInfo, C_LFGList.GetSearchResultMemberCounts
C_LFGList.GetSearchResultInfo = function() return "SECRET" end
check(api:IsRoleFull(1, "Party-1", "HEALER") == nil, "a secret listing table is unknown")
C_LFGList.GetSearchResultInfo = readInfo
C_LFGList.GetSearchResultMemberCounts = function() error("native member counts unavailable") end
check(api:IsRoleFull(1, "Party-1", "HEALER") == nil, "native read errors leave composition unknown")
chatLocked = true
local lockdownReads = 0
C_LFGList.GetSearchResultInfo = function() lockdownReads = lockdownReads + 1; return listing end
check(api:IsRoleFull(1, "Party-1", "HEALER") == nil and lockdownReads == 0,
    "lockdown skips native composition reads")
chatLocked = false
C_LFGList.GetSearchResultInfo, C_LFGList.GetSearchResultMemberCounts = readInfo, readCounts
listing.counts, listing.remaining = nil, nil
results[1].activityIDs = {102}
check(api:ReadGroup(1) == nil, "an unchecked dungeon is also excluded from returned groups")
results[1].activityIDs = {101}
results[1].remaining = 0
check(api:ReadGroup(1).eligible == false, "reserved healer slot is unavailable")
results[1].remaining = nil
results[1].leaderOverallDungeonScore = nil
check(api:ReadGroup(1) == nil, "unknown leader rating is not a known zero")
results[1].leaderOverallDungeonScore = "SECRET"
check(api:ReadGroup(1) == nil, "secret rating fails closed")
results[1].leaderOverallDungeonScore = 3600
results[1].requiredDungeonScore = 4000
check(api:ReadGroup(1).eligible == false, "player fails the listing rating requirement")
results[1].requiredDungeonScore = 3000
chatLocked = true
check(api:Context() == "chat_lockdown" and api:ReadGroup(1) == nil, "native communication lockdown pauses reads")
PTG:OnPress()
check(PTG:GetView().state == "chat_lockdown", "visible lockdown reason")
chatLocked = false
queueMessage = "Несовместимая очередь"
check(api:Context() == "native_pause", "known native queue restriction")
PTG.engine:Plan()
check(PTG:GetView().stateArgs[1] == queueMessage, "known reason is passed to the interface")
local originalPrint, printed = print, {}
print = function(message) printed[#printed + 1] = message end
PTG:PrintLog()
print = originalPrint
check(printed[1]:find(queueMessage, 1, true), "status command includes the known pause reason")
queueMessage = nil
PTG:Start()
now = now + 9
PTG:OnPress()
check(calls[#calls].kind == "search", "new search after explicit start")
PTG.db.dungeons = {}
PTG:SettingsChanged()
PTG.engine:Plan()
check(PTG.engine.search.stale and PTG:GetView().state == "no_dungeons_selected",
    "unchecking the final dungeon invalidates an in-flight search")
emit("LFG_LIST_SEARCH_RESULTS_RECEIVED")
local clearedCalls = #calls
PTG:OnPress()
check(not PTG.engine.validAt and #calls == clearedCalls, "a response from before clearing cannot authorize an application")
PTG.db.dungeons[101] = true
PTG:SettingsChanged()
now = now + 9
PTG:OnPress()
text = "+20"
PTG.engine:Plan()
check(PTG.engine.search.stale, "changed native query invalidates pending search")
emit("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check(not PTG.engine.validAt, "stale response cannot authorize applications")
LFGListFrame.parentVisible = true
C_LFGList.Search(2, 0, 0, {ruRU = true})
emit("LFG_LIST_SEARCH_RESULTS_RECEIVED")
LFGListFrame.parentVisible = false
check(not PTG.engine.conflict and not PTG.engine.validAt, "isolated manual search is drained, not adopted")
C_LFGList.Search(2, 0, 0, {ruRU = true})
check(PTG.engine.conflict, "foreign hidden search latches conflict")
PTG:Start()
check(PTG.engine.conflict, "Start cannot erase ambiguous search ownership")
check(PTG:L("loaded") ~= "loaded" and PTG:L("native_pause", "x") ~= "native_pause", "new diagnostics localized")

calls, apps, results = {}, {}, {}
LFGListFrame.shown, LFGListFrame.parentVisible, text = false, true, "+19"
local migrated = {role = "DAMAGER", locale = "enUS", minRating = 3000}
loadSession(migrated)
check(PTG.db == migrated and migrated.autoRole == true and migrated.role == "HEALER",
    "existing characters migrate to automatic role instead of keeping a stale saved role")
check(migrated.locale == "enUS" and migrated.minRating == 3000 and not PTG.engine.running,
    "automatic-role migration preserves other settings and starts OFF")

loadSession({autoRole = false, role = "DAMAGER"})
check(PTG.db.autoRole == false and PTG.db.role == "DAMAGER", "explicit manual role survives initialization")
local revision = PTG.engine.revision
specIndex, specID, specRole = 1, 256, "HEALER"
emit("PLAYER_SPECIALIZATION_CHANGED", "player")
emit("PLAYER_ENTERING_WORLD")
update(0.5)
check(PTG.db.role == "DAMAGER" and PTG.engine.revision == revision,
    "specialization events, entering the world, and updates leave manual selection unchanged")
local manual = PTG.db
loadSession(manual)
check(PTG.db == manual and PTG.db.autoRole == false and PTG.db.role == "DAMAGER",
    "manual mode and role survive a new addon session")

loadSession({autoRole = true})
PTG:Start()
PTG:OnPress()
local search, before = PTG.engine.search, #calls
revision = PTG.engine.revision
specIndex, specID, specRole = 3, 258, "DAMAGER"
emit("PLAYER_SPECIALIZATION_CHANGED", "party1")
check(PTG.db.role == "HEALER" and PTG.engine.revision == revision and not search.stale,
    "another unit's specialization event cannot alter this character's role or search")
specIndex, specID, specRole = 2, 257, "HEALER"
emit("PLAYER_SPECIALIZATION_CHANGED", "player")
emit("PLAYER_ENTERING_WORLD")
check(PTG.db.role == "HEALER" and PTG.engine.revision == revision and PTG.engine.search == search and not search.stale,
    "changing between healer specializations and entering the world keep an outstanding search valid")
check(PTG.engine.api:Player().specID == 257 and #calls == before,
    "same-role specialization changes expose the new specialization without performing LFG actions")

specIndex, specID, specRole = 3, 258, "DAMAGER"
emit("PLAYER_SPECIALIZATION_CHANGED", "player")
check(PTG.db.role == "DAMAGER" and PTG.engine.revision == revision + 1 and search.stale,
    "a changed automatic role invalidates the outstanding search exactly once")
check(#calls == before, "changing specialization does not send or cancel an application")
emit("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check(not PTG.engine.validAt and #PTG.engine.results == 0, "an old-role search response cannot authorize new applications")
now = now + 9
PTG:OnPress()
request = calls[#calls].args
check(calls[#calls].kind == "search" and request[6].needsDamage and not request[6].needsHealer and not request[6].needsTank,
    "the next explicit search uses only the new automatic role")
results[1] = {activityIDs = {101}, partyGUID = "Auto-Party", age = 15, numMembers = 3,
    isDelisted = false, hasSelf = false, requiredItemLevel = 170, requiredDungeonScore = 3000,
    leaderOverallDungeonScore = 3600, name = "+19 группа",
    counts = {TANK = 1, HEALER = 1, DAMAGER = 1, HEALER_REMAINING = 0, DAMAGER_REMAINING = 2}}
emit("LFG_LIST_SEARCH_RESULTS_RECEIVED")
now = now + 1
PTG:OnPress()
check(calls[#calls].kind == "apply" and calls[#calls].damage and not calls[#calls].healer and not calls[#calls].tank,
    "new applications use exactly the current automatic role")
check(PTG.engine.pending and PTG.engine.pending.role == "DAMAGER", "the submitted automatic role is captured before confirmation")
before = #calls
specIndex, specID, specRole = 2, 257, "HEALER"
emit("PLAYER_SPECIALIZATION_CHANGED", "player")
check(PTG.db.role == "HEALER" and PTG.engine.pending.role == "DAMAGER" and #calls == before,
    "a specialization change preserves the pending application's submitted role")
apps[1] = {status = "applied"}
emit("LFG_LIST_APPLICATION_STATUS_UPDATED", 1)
check(PTG.engine.owned["Auto-Party"].role == "DAMAGER", "confirmation retains the role used before the specialization change")
now = now + 1
PTG:OnPress()
check(#calls == before and PTG.engine.owned["Auto-Party"],
    "a filled newly selected healer role does not cancel the existing damage application")

revision = PTG.engine.revision
PTG.db.autoRole = false
PTG:SetRole("HEALER")
check(PTG.engine.revision == revision, "switching to manual mode with the same role does not invalidate search state")
specIndex, specID, specRole = 3, 258, "DAMAGER"
emit("PLAYER_SPECIALIZATION_CHANGED", "player")
check(PTG.db.role == "HEALER" and PTG.engine.revision == revision, "manual mode ignores later specialization changes")
PTG.db.autoRole = true
PTG:SyncRole()
check(PTG.db.role == "DAMAGER" and PTG.engine.revision == revision + 1,
    "enabling automatic mode synchronizes immediately and invalidates only the changed role")
revision = PTG.engine.revision
PTG:SyncRole()
check(PTG.engine.revision == revision, "repeated synchronization of the same role preserves search state")
PTG.db.autoRole = false
PTG:SetRole(PTG.db.role)
check(PTG.db.role == "DAMAGER" and PTG.engine.revision == revision,
    "disabling automatic mode keeps its effective role without restoring an earlier manual role")

calls, apps, results = {}, {}, {}
specIndex, specRole = nil, nil
loadSession({role = "HEALER"})
check(PTG.db.autoRole == true and PTG.db.role == nil, "unavailable specialization data cannot fall back to saved role or damage")
PTG:Start()
PTG:OnPress()
check(PTG:GetView().state == "no_role" and #calls == 0 and PTG.engine.running,
    "unknown automatic role pauses a running assistant without sending LFG actions")
check(not PTG.engine.api:Search(PTG.db) and not PTG.engine.api:Apply(1, nil) and #calls == 0,
    "native adapters independently reject an unknown search or application role")
update(0.5)
check(PTG.db.role == nil and #calls == 0, "an update with unavailable specialization data only plans")
specIndex, specID, specRole = 2, 257, "HEALER"
update(0.25)
check(PTG.db.role == nil, "automatic-role retry respects the existing update interval")
update(0.25)
check(PTG.db.role == "HEALER" and PTG:GetView().state == "ready_search" and #calls == 0,
    "late specialization data recovers on the existing update without an automatic LFG action")
check(not PTG.engine.api:Apply(1, "INVALID") and #calls == 0,
    "the application adapter rejects an invalid submitted role even when the effective role is valid")
local invalidSettings = {role = "INVALID", dungeons = PTG.db.dungeons, languages = PTG.db.languages}
check(not PTG.engine.api:Search(invalidSettings) and #calls == 0, "the search adapter rejects an invalid role without a wildcard query")
revision = PTG.engine.revision
specRole = "INVALID"
emit("PLAYER_SPECIALIZATION_CHANGED", "player")
check(PTG.db.role == nil and PTG:GetView().state == "no_role" and PTG.engine.revision == revision + 1,
    "an invalid specialization role removes the old role and invalidates once")
emit("PLAYER_SPECIALIZATION_CHANGED", "player")
check(PTG.engine.revision == revision + 1 and #calls == 0, "repeated unknown-role events do not repeatedly invalidate search state")
specRole = "HEALER"
emit("PLAYER_ENTERING_WORLD")
check(PTG.db.role == "HEALER" and PTG:GetView().state == "ready_search" and #calls == 0,
    "entering the world retries role discovery without sending a request")
local specializationInfo = C_SpecializationInfo.GetSpecializationInfo
C_SpecializationInfo.GetSpecializationInfo = function() error("specialization data is not ready") end
emit("PLAYER_SPECIALIZATION_CHANGED", "player")
check(PTG.db.role == nil and PTG:GetView().state == "no_role" and PTG.engine.running and not PTG.engine.problem,
    "native specialization read errors pause safely instead of stopping the assistant with an error")
C_SpecializationInfo.GetSpecializationInfo = specializationInfo
update(0.5)
check(PTG.db.role == "HEALER" and #calls == 0, "a recovered native role read resumes planning only")

loadSession({autoRole = false})
check(PTG.db.role == nil and PTG.engine.api:Context() == "no_role", "a missing manual role remains unknown until explicitly selected")
emit("PLAYER_ENTERING_WORLD")
update(0.5)
check(PTG.db.role == nil and #calls == 0, "unknown manual mode does not silently resume automatic role selection")

local specializationIndex = C_SpecializationInfo.GetSpecialization
for _, unavailable in ipairs({"details error", "index error", "missing index"}) do
    calls, apps, results = {}, {}, {}
    specIndex, specID, specRole = 2, 257, "HEALER"
    C_SpecializationInfo.GetSpecialization = specializationIndex
    C_SpecializationInfo.GetSpecializationInfo = specializationInfo
    if unavailable == "details error" then
        C_SpecializationInfo.GetSpecializationInfo = function() error("specialization details are not ready") end
    elseif unavailable == "index error" then
        C_SpecializationInfo.GetSpecialization = function() error("specialization index is not ready") end
    else
        specIndex = nil
    end
    loadSession({autoRole = true})
    PTG:Start()
    PTG:OnPress()
    check(PTG.db.role == nil and PTG:GetView().state == "no_role" and #calls == 0,
        "unavailable specialization pauses automatic mode: " .. unavailable)
    PTG.db.autoRole = false
    PTG:SetRole("HEALER")
    local player = PTG.engine.api:Player()
    check(player.class == "PRIEST" and player.role == "HEALER" and player.specID == nil,
        "manual role remains readable without guessing a specialization: " .. unavailable)
    PTG:OnPress()
    check(calls[#calls].kind == "search" and calls[#calls].args[6].needsHealer,
        "manual fallback can search while specialization remains unavailable: " .. unavailable)
    results[1] = {activityIDs = {101}, partyGUID = "Manual-Fallback", age = 15, numMembers = 3,
        isDelisted = false, hasSelf = false, requiredItemLevel = 170, requiredDungeonScore = 3000,
        leaderOverallDungeonScore = 3600, name = "+19 группа"}
    emit("LFG_LIST_SEARCH_RESULTS_RECEIVED")
    now = now + 1
    PTG:OnPress()
    check(PTG.engine.running and not PTG.engine.problem and calls[#calls].kind == "apply"
        and calls[#calls].healer and PTG.engine.pending.role == "HEALER",
        "manual fallback reaches application without a specialization read error: " .. unavailable)
end
C_SpecializationInfo.GetSpecialization = specializationIndex
C_SpecializationInfo.GetSpecializationInfo = specializationInfo

specIndex, specID, specRole = 2, 257, "HEALER"
for _, invalid in ipairs({
    {name = "zero", value = 0}, {name = "negative", value = -1}, {name = "fraction", value = 1.5},
    {name = "NaN", value = 0 / 0}, {name = "infinity", value = math.huge},
    {name = "negative infinity", value = -math.huge}, {name = "text", value = "invalid"},
    {name = "table", value = {}},
}) do
    loadSession({replaceAfter = invalid.value})
    check(PTG.db.replaceAfter == 180, "invalid saved replacement age defaults to 180 seconds: " .. invalid.name)
end
local replacementSettings = {replaceAfter = 90}
loadSession(replacementSettings)
check(PTG.db.replaceAfter == 90, "a valid saved replacement age is preserved")
loadSession(replacementSettings)
check(PTG.db == replacementSettings and PTG.db.replaceAfter == 90,
    "the replacement age survives a new addon session")
loadSession({replaceAfter = "90"})
check(PTG.db.replaceAfter == 90 and type(PTG.db.replaceAfter) == "number",
    "a numeric saved replacement age is normalized to a number")
for _, invalid in ipairs({"true", 1, 0, {}}) do
    loadSession({compactMode = invalid})
    check(PTG.db.compactMode == false, "non-boolean saved compact modes normalize to the full window")
end
for _, compact in ipairs({true, false}) do
    local savedWindow = {compactMode = compact, position = {point = "TOPLEFT", x = 220, y = -110}}
    loadSession(savedWindow)
    check(PTG.db == savedWindow and PTG.db.compactMode == compact and not PTG.engine.running
        and PTG.db.position.x == 220 and PTG.db.position.y == -110,
        "initialization preserves the saved window mode and position without starting the assistant")
    PTG.ui = {shown = true}
    function PTG.ui:IsShown() return self.shown end
    function PTG.ui:SetShown(shown) self.shown = shown end
    local pendingOperation = {kind = "apply", id = 42}
    PTG.engine.running, PTG.engine.pending = true, pendingOperation
    local windowCalls, windowRevision = #calls, PTG.engine.revision
    SlashCmdList.PRESSTOGROUP("")
    check(not PTG.ui:IsShown() and PTG.db.compactMode == compact, "/ptg hides the current representation without changing its mode")
    SlashCmdList.PRESSTOGROUP("")
    check(PTG.ui:IsShown() and PTG.db.compactMode == compact and #calls == windowCalls
        and PTG.engine.revision == windowRevision and PTG.engine.running and PTG.engine.pending == pendingOperation,
        "/ptg preserves the running assistant and pending operation without performing LFG actions")
    loadSession(savedWindow)
    check(PTG.db.compactMode == compact and PTG.db.position.point == "TOPLEFT",
        "the chosen window mode survives another addon session")
end
print("wow: " .. checks .. " checks passed")
