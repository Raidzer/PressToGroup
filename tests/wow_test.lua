local PTG = {}
unpack = unpack or table.unpack
local checks = 0
local function check(value, message)
    assert(value, message)
    checks = checks + 1
end
local now, grouped, combat, chatLocked, queueMessage = 100, false, false, false, nil
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
    GetSpecialization = function() return 2 end,
    GetSpecializationInfo = function() return 257, "Свет", "", 0, "HEALER" end,
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
    local frame = {scripts = {}}
    function frame:RegisterEvent() end
    function frame:SetScript(key, callback) self.scripts[key] = callback end
    frames[#frames + 1] = frame
    return frame
end
local function emit(event, ...)
    for _, frame in ipairs(frames) do frame.scripts.OnEvent(frame, event, ...) end
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
        return {TANK = 1, HEALER = 0, DAMAGER = 2, HEALER_REMAINING = results[id].remaining or 1}
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

for _, file in ipairs({"Locale", "Filters", "Input", "Engine"}) do
    assert(loadfile(root .. "/" .. file .. ".lua"))("PressToGroup", PTG)
end
function PTG:BuildUI() end
function PTG:RefreshUI() end
assert(loadfile(root .. "/WoW.lua"))("PressToGroup", PTG)
emit("ADDON_LOADED", "PressToGroup")
check(PTG.engine ~= nil and not PTG.engine.running, "loads without deprecated specialization globals; starts OFF")
check(PTG.db.role == "HEALER", "current specialization role")
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
print("wow: " .. checks .. " checks passed")
