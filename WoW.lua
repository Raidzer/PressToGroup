local addonName, PTG = ...
_G.PressToGroup = PTG
local API = {}
local C = C_LFGList
local CATEGORY = 2

local function public(value, kind)
    return not (issecretvalue and issecretvalue(value)) and type(value) == kind
end

local function locked()
    return C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
end

local function native(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return value end
end

local function query()
    local panel = LFGListFrame and LFGListFrame.SearchPanel
    if not panel or not panel.SearchBox then return nil end
    local text = panel.SearchBox:GetText()
    if public(text, "string") then return text end
end

function API:Now() return GetTime() end

function API:Context()
    if IsInGroup() then return "grouped" end
    if locked() then return "chat_lockdown" end
    if not C or not C.Search or not C.GetSearchResultPlayerInfo then return "unsupported" end
    if LFGListFrame and LFGListFrame:IsShown() then return "manual_search" end
    if not PTG.activities or not next(PTG.activities) then return "unavailable" end
    local text = query()
    if not text or text == "" then return "no_query" end
    if PTG.queryText ~= text then
        PTG.queryText = text
        if PTG.engine then PTG.engine:SettingsChanged() end
    end
    local queueMessage = LFGListUtil_GetActiveQueueMessage and LFGListUtil_GetActiveQueueMessage(true)
    if public(queueMessage, "string") then
        PTG.nativeReason = queueMessage
        return "native_pause"
    end
    local tank, healer, damage = C.GetAvailableRoles()
    local available = {TANK = tank, HEALER = healer, DAMAGER = damage}
    if available[PTG.db.role] ~= true then return "unavailable" end
    if C.GetActiveEntryInfo and C.GetActiveEntryInfo() then return "grouped" end
end

function API:Player()
    local _, class = UnitClass("player")
    local spec = C_SpecializationInfo.GetSpecialization()
    return {class = class, specID = spec and C_SpecializationInfo.GetSpecializationInfo(spec), role = PTG.db.role}
end

function PTG:GetDungeons()
    return self.dungeons or {}
end

function PTG:LoadDungeons()
    self.dungeons, self.activities = {}, {}
    if not C or not Enum.LFGListFilter then return end
    local flags = bit.bor(Enum.LFGListFilter.CurrentSeason, Enum.LFGListFilter.PvE)
    for _, id in ipairs(native(C.GetAvailableActivities, CATEGORY, nil, flags) or {}) do
        local info = native(C.GetActivityInfoTable, id)
        if info and info.isMythicPlusActivity == true then
            self.activities[id] = true
            self.dungeons[#self.dungeons + 1] = {id = id, name = info.fullName}
        end
    end
    table.sort(self.dungeons, function(a, b) return a.name < b.name end)
end

function PTG:GetLanguages()
    local result = {}
    local mandatory = native(C.GetDefaultLanguageSearchFilter) or {}
    for _, id in ipairs(native(C.GetAvailableLanguageSearchFilter) or {}) do
        result[#result + 1] = {id = id, name = _G["LFG_LIST_LANGUAGE_" .. id:upper()] or id,
            mandatory = mandatory[id] == true, selected = self.db.languages[id] == true}
    end
    return result
end

local function readGroup(id)
    if locked() then return nil end
    local info = C.GetSearchResultInfo(id)
    if not info or not public(info, "table") then return nil end
    local fields = {age = "number", numMembers = "number", isDelisted = "boolean",
        hasSelf = "boolean", activityIDs = "table", requiredItemLevel = "number", partyGUID = "string"}
    for field, kind in pairs(fields) do
        if not public(info[field], kind) then return nil end
    end
    local activityID
    local selected = next(PTG.db.dungeons) ~= nil
    for _, activity in ipairs(info.activityIDs) do
        if public(activity, "number") and PTG.activities[activity]
            and (not selected or PTG.db.dungeons[activity]) then activityID = activity; break end
    end
    if not activityID then return nil end
    local rating = info.leaderOverallDungeonScore
    local requiredScore = info.requiredDungeonScore
    if requiredScore == nil then requiredScore = 0 end
    if not public(rating, "number") or not public(requiredScore, "number") then return nil end
    local ilvl = GetAverageItemLevel()
    if not public(ilvl, "number") then return nil end
    local meetsScore = C.ValidateRequiredDungeonScore(requiredScore)
    if not public(meetsScore, "boolean") then return nil end
    local counts = C.GetSearchResultMemberCounts(id)
    if not public(counts, "table") then return nil end
    local roleCounts = {}
    for _, role in ipairs({"TANK", "HEALER", "DAMAGER"}) do
        if not public(counts[role], "number") then return nil end
        roleCounts[role] = counts[role]
    end
    local remaining = counts[PTG.db.role .. "_REMAINING"]
    if not public(remaining, "number") then return nil end
    local members, complete = {}, true
    for index = 1, info.numMembers do
        local member = C.GetSearchResultPlayerInfo(id, index)
        if public(member, "table") and public(member.classFilename, "string") then
            members[index] = {class = member.classFilename}
        else complete = false end
    end
    local activity = C.GetActivityInfoTable(activityID)
    return {id = id, identity = info.partyGUID, activityID = activityID,
        name = public(info.name, "string") and info.name or (activity and activity.fullName or ""),
        dungeon = activity and activity.fullName or "", age = info.age,
        leaderRating = rating, numMembers = info.numMembers, hasSelf = info.hasSelf,
        isDelisted = info.isDelisted, eligible = remaining > 0 and ilvl >= info.requiredItemLevel and meetsScore,
        roleCounts = roleCounts, members = members, complete = complete}
end

function API:ReadGroup(id)
    local ok, group = pcall(readGroup, id)
    if ok then return group end
end

function API:ReadResults()
    if locked() then return nil end
    local ok, count, ids = pcall(C.GetSearchResults)
    if not ok or not public(count, "number") or not public(ids, "table") then return nil end
    local groups = {}
    for _, id in ipairs(ids) do
        local group = self:ReadGroup(id)
        if group then groups[#groups + 1] = group end
    end
    return groups, count
end

function API:ReadApplication(id)
    if locked() or not C then return nil end
    local ok, _, status, pending = pcall(C.GetApplicationInfo, id)
    if not ok or not public(status, "string") then return nil end
    if pending ~= nil and not public(pending, "string") then return nil end
    local info = native(C.GetSearchResultInfo, id)
    local identity = info and public(info.partyGUID, "string") and info.partyGUID or nil
    local name = info and public(info.name, "string") and info.name or ""
    return {id = id, status = status, pending = pending, identity = identity, name = name}
end

function API:ReadApplications()
    if locked() or not C then return {}, 0, false end
    local ids = native(C.GetApplications)
    if not public(ids, "table") then return {}, 0, false end
    local apps, reliable, pendingCount = {}, true, 0
    for _, id in ipairs(ids) do
        local app = self:ReadApplication(id)
        if app then
            apps[#apps + 1] = app
            if app.pending or app.status == "applied" or app.status == "invited"
                or app.status == "inviteaccepted" then pendingCount = pendingCount + 1 end
        else reliable = false end
    end
    local ok, _, count = pcall(C.GetNumApplications)
    if not ok or not public(count, "number") then reliable = false; count = pendingCount end
    return apps, math.max(count, pendingCount), reliable, MAX_LFG_LIST_APPLICATIONS or 5
end

function API:Search(settings)
    local languages, activities = {}, {}
    for _, language in ipairs(PTG:GetLanguages()) do
        languages[language.id] = language.mandatory or language.selected
    end
    for id in pairs(PTG.activities) do
        if not next(settings.dungeons) or settings.dungeons[id] then activities[#activities + 1] = id end
    end
    if #activities == 0 or not next(languages) then return false, "unavailable" end
    table.sort(activities)
    local filters = {activities = {}, difficultyMythicPlus = true, minimumRating = settings.minRating,
        needsTank = settings.role == "TANK", needsHealer = settings.role == "HEALER",
        needsDamage = settings.role == "DAMAGER"}
    PTG.issuingSearch = true
    local ok, reason = pcall(C.Search, CATEGORY, 0, 0, languages, nil, filters, activities)
    PTG.issuingSearch = false
    if not ok and public(reason, "string") then PTG.engine:Log("native_error", reason) end
    return ok
end

function API:Apply(id, role)
    if self:Context() then return false end
    local ok, reason = pcall(C.ApplyToGroup, id, role == "TANK", role == "HEALER", role == "DAMAGER")
    if not ok and public(reason, "string") then PTG.engine:Log("native_error", reason) end
    return ok
end

function API:Cancel(id)
    if locked() or IsInGroup() then return false end
    local app = self:ReadApplication(id)
    if not app or app.status ~= "applied" or app.pending then return false end
    local ok, reason = pcall(C.CancelApplication, id)
    if not ok and public(reason, "string") then PTG.engine:Log("native_error", reason) end
    return ok
end

function API:InviteSound()
    PlaySound(SOUNDKIT.READY_CHECK or 8960, "Master")
end

local function reportError(reason)
    if PTG.engine then
        PTG.engine:Stop("error")
        PTG.engine.problem = "error"
        PTG.engine:Log("error")
        if public(reason, "string") then PTG.engine:Log("native_error", reason) end
    end
end

function PTG:Start()
    self.engine:Start()
    self.engine:Plan()
    self:RefreshUI()
end

function PTG:Stop()
    self.engine:Stop()
    self:RefreshUI()
end

function PTG:OnPress()
    if not self.engine or self.inPress then return end
    self.inPress = true
    local ok, reason = pcall(self.engine.Press, self.engine)
    self.inPress = false
    if not ok then reportError(reason) end
    self:RefreshUI()
end

function PTG:Cancel(id)
    local ok, reason = pcall(self.engine.Cancel, self.engine, id)
    if not ok then reportError(reason) end
    self:RefreshUI()
end

function PTG:SettingsChanged()
    self.engine:SettingsChanged()
    self:BindsLocale()
end

function PTG:GetView()
    local engine = self.engine
    local apps = {}
    for _, app in ipairs(engine.applications) do
        if app.pending or app.status == "applied" or app.status == "invited" or app.status == "inviteaccepted" then
            apps[#apps + 1] = app
        end
    end
    return {running = engine.running, state = engine.state,
        stateArgs = engine.state == "native_pause" and {self.nativeReason} or engine.stateArgs,
        found = engine.found, eligible = engine.eligible, active = engine.active, limit = engine.limit,
        lastResponse = engine.lastResponse and math.max(0, GetTime() - engine.lastResponse),
        nextCandidate = engine.nextCandidate, applications = apps, searchText = query()}
end

function PTG:OpenSearch()
    if InCombatLockdown() then
        print("PressToGroup: " .. self:L("open_after_combat"))
        return
    end
    PVEFrame_ShowFrame("GroupFinderFrame", "LFGListPVEStub")
    if LFGListFrame.SearchPanel.categoryID == CATEGORY then
        LFGListFrame_SetActivePanel(LFGListFrame, LFGListFrame.SearchPanel)
        return
    end
    LFGListCategorySelection_SelectCategory(LFGListFrame.CategorySelection, CATEGORY, 0, 0)
    LFGListCategorySelection_StartFindGroup(LFGListFrame.CategorySelection)
end

function PTG:ToggleWindow()
    if self.ui then self.ui:SetShown(not self.ui:IsShown()) end
end

function PTG:BindsLocale()
    BINDING_HEADER_PRESSTOGROUP = "PressToGroup"
    BINDING_NAME_PRESSTOGROUP_STEP = self:L("binding_step")
    BINDING_NAME_PRESSTOGROUP_WINDOW = self:L("binding_window")
end

function PTG:PrintLog()
    local view = self:GetView()
    print("PressToGroup 0.1.0: " .. self:L(view.state, unpack(view.stateArgs or {})))
    for _, entry in ipairs(self.engine.log) do
        print(string.format("[%0.1f] %s", entry.at, self:L(entry.key, unpack(entry.args))))
    end
end

local function initialize()
    PressToGroupDB = type(PressToGroupDB) == "table" and PressToGroupDB or {}
    PTG.db = PressToGroupDB
    local db = PTG.db
    db.locale = (db.locale == "ruRU" or db.locale == "enUS") and db.locale or "auto"
    local spec = C_SpecializationInfo.GetSpecialization()
    db.role = db.role or (spec and select(5, C_SpecializationInfo.GetSpecializationInfo(spec))) or "DAMAGER"
    if db.role ~= "TANK" and db.role ~= "HEALER" and db.role ~= "DAMAGER" then db.role = "DAMAGER" end
    db.minRating = math.max(0, tonumber(db.minRating) or 0)
    db.dungeons = type(db.dungeons) == "table" and db.dungeons or {}
    if type(db.languages) ~= "table" then
        db.languages = native(C.GetLanguageSearchFilter) or {}
    end
    PTG:LoadDungeons()
    PTG.engine = PTG.Engine.New(API, db)
    db.log = type(db.log) == "table" and db.log or {}
    PTG.engine.log = db.log
    PTG.engine:Log("loaded")
    PTG.queryText = query()
    PTG:BindsLocale()
    PTG:BuildUI()
    if type(SecureActionButton_OnClick) == "function" then
        hooksecurefunc("SecureActionButton_OnClick", function(...)
            if PTG.engine.running and PTG.Input.Accept(...) then PTG:OnPress() end
        end)
    end
    hooksecurefunc(C, "Search", function()
        if not PTG.issuingSearch then
            PTG.engine:ForeignSearch(LFGListFrame and LFGListFrame:IsShown())
        end
    end)
    SLASH_PRESSTOGROUP1 = "/ptg"
    SlashCmdList.PRESSTOGROUP = function(command)
        command = (command or ""):lower():match("^%s*(.-)%s*$")
        if command == "start" then PTG:Start()
        elseif command == "stop" then PTG:Stop()
        elseif command == "status" or command == "log" then PTG:PrintLog()
        else PTG:ToggleWindow() end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addonName or PTG.engine then return end
        initialize()
        for _, value in ipairs({"PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "LFG_LIST_SEARCH_RESULTS_RECEIVED",
            "LFG_LIST_SEARCH_FAILED", "LFG_LIST_SEARCH_RESULT_UPDATED", "LFG_LIST_APPLICATION_STATUS_UPDATED",
            "LFG_LIST_AVAILABILITY_UPDATE"}) do
            events:RegisterEvent(value)
        end
        return
    end
    local ok, reason = pcall(function()
        if event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" then PTG.engine:SearchReceived()
        elseif event == "LFG_LIST_SEARCH_FAILED" then PTG.engine:SearchFailed(public(name, "string") and name or nil)
        elseif event == "PLAYER_ENTERING_WORLD" or event == "LFG_LIST_AVAILABILITY_UPDATE" then
            PTG:LoadDungeons()
        end
        PTG.engine:Plan()
    end)
    if not ok then reportError(reason) end
    PTG:RefreshUI()
end)

local elapsed = 0
events:SetScript("OnUpdate", function(_, dt)
    if not PTG.engine then return end
    elapsed = elapsed + dt
    if elapsed < 0.5 then return end
    elapsed = 0
    local ok, reason = pcall(PTG.engine.Plan, PTG.engine)
    if not ok then reportError(reason) end
    PTG:RefreshUI()
end)
