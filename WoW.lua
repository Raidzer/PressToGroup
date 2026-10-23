local addonName, PTG = ...
_G.PressToGroup = PTG
local API = {}
local C = C_LFGList
local CATEGORY = 2
local MOVEMENT_ACTIONS = {
    MOVEFORWARD = true, MOVEBACKWARD = true, STRAFELEFT = true, STRAFERIGHT = true,
    TURNLEFT = true, TURNRIGHT = true, JUMP = true,
}

local function public(value, kind)
    return not (issecretvalue and issecretvalue(value)) and type(value) == kind
end

local function validRole(role)
    return public(role, "string") and (role == "TANK" or role == "HEALER" or role == "DAMAGER")
end

local function nonnegative(value)
    return public(value, "number") and value >= 0 and value < math.huge
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

local function readCompany()
    local instance = native(IsInGroup, LE_PARTY_CATEGORY_INSTANCE)
    local grouped = native(IsInGroup, LE_PARTY_CATEGORY_HOME)
    if not public(instance, "boolean") or not public(grouped, "boolean") then return nil, "company_unknown" end
    if instance then return {scope = "instance", size = 0, signature = ""}, "company_instance" end
    if not grouped then return {scope = "solo", signature = "", size = 1, leader = true} end
    local raid = native(IsInRaid, LE_PARTY_CATEGORY_HOME)
    if not public(raid, "boolean") then return nil, "company_unknown" end
    if raid then return {scope = "raid", size = 0, signature = ""}, "company_raid" end
    local size = native(GetNumGroupMembers, LE_PARTY_CATEGORY_HOME)
    if not public(size, "number") or size % 1 ~= 0 or size < 2 or size > 5 then return nil, "company_unknown" end
    local company = {size = size, members = {}, roles = {TANK = 0, HEALER = 0, DAMAGER = 0}}
    local guids, signatures, seen, leader, offline, unknownRole = {}, {}, {}, nil, false, false
    for index = 1, size do
        local unit = index == 1 and "player" or "party" .. (index - 1)
        local guid = native(UnitGUID, unit)
        local isLeader = native(UnitIsGroupLeader, unit, LE_PARTY_CATEGORY_HOME)
        if not public(guid, "string") or guid == "" or seen[guid] or not public(isLeader, "boolean") then
            return nil, "company_unknown"
        end
        seen[guid], guids[index] = true, guid
        if isLeader then
            if leader then return nil, "company_unknown" end
            leader = guid
        end
        if index == 1 then company.leader = isLeader end
        local connected = native(UnitIsConnected, unit)
        if not public(connected, "boolean") then return nil, "company_unknown" end
        if not connected then offline = true end
        local role = PTG.db.role
        if index > 1 then role = native(UnitGroupRolesAssigned, unit) end
        if validRole(role) then
            company.roles[role] = company.roles[role] + 1
            signatures[#signatures + 1] = guid .. ":" .. role
        else unknownRole = true end
        local class = native(function() return select(2, UnitClass(unit)) end)
        company.members[index] = {unit = unit, class = public(class, "string") and class or nil}
    end
    if not leader then return nil, "company_unknown" end
    table.sort(guids)
    company.scope = leader .. "|" .. table.concat(guids, "|")
    if not unknownRole then
        table.sort(signatures)
        company.signature = table.concat(signatures, "|")
    else company.roles = nil end
    if size == 5 then return company, "company_full" end
    if not company.leader then return company, "company_not_leader" end
    if offline then return company, "company_offline" end
    if unknownRole then return company, "company_roles_unknown" end
    if company.roles.TANK > 1 or company.roles.HEALER > 1 or company.roles.DAMAGER > 3 then
        return company, "company_roles_invalid"
    end
    return company
end

function API:Company()
    local ok, company, reason = pcall(readCompany)
    if ok then return company, reason end
    return nil, "company_unknown"
end

local function applyingReason(company)
    if company.size <= 1 then return end
    local applying = native(C.IsCurrentlyApplying)
    if not public(applying, "boolean") then return "company_unknown" end
    if applying then return "wait_roles" end
end

function API:Context()
    if locked() then return "chat_lockdown" end
    local company, reason = self:Company()
    if reason then return reason end
    if not C or not C.Search or not C.GetSearchResultPlayerInfo then return "unsupported" end
    if LFGListFrame and LFGListFrame:IsVisible() then return "manual_search" end
    if not validRole(PTG.db.role) then return "no_role" end
    if not PTG.activities or not next(PTG.activities) then return "unavailable" end
    local selected = false
    for id in pairs(PTG.activities) do
        if PTG.db.dungeons[id] == true then selected = true; break end
    end
    if not selected then return "no_dungeons_selected" end
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
    return applyingReason(company)
end

function API:Player()
    local _, class = UnitClass("player")
    local spec = native(C_SpecializationInfo and C_SpecializationInfo.GetSpecialization)
    local specID
    if public(spec, "number") then specID = native(C_SpecializationInfo.GetSpecializationInfo, spec) end
    local company = self:Company()
    return {class = class, specID = public(specID, "number") and specID or nil,
        role = PTG.db.role, company = company}
end

function PTG:GetDungeons()
    return self.dungeons or {}
end

function PTG:LoadDungeons()
    self.dungeons, self.activities = {}, {}
    if not C or not Enum.LFGListFilter then return end
    local flags = bit.bor(Enum.LFGListFilter.CurrentSeason, Enum.LFGListFilter.PvE)
    local complete = true
    for _, id in ipairs(native(C.GetAvailableActivities, CATEGORY, nil, flags) or {}) do
        local info = native(C.GetActivityInfoTable, id)
        if not info then complete = false end
        if info and info.isMythicPlusActivity == true then
            self.activities[id] = true
            self.dungeons[#self.dungeons + 1] = {id = id, name = info.fullName}
        end
    end
    table.sort(self.dungeons, function(a, b) return a.name < b.name end)
    if not self.db.dungeonsInitialized and complete and #self.dungeons > 0 then
        if not next(self.db.dungeons) then
            for _, dungeon in ipairs(self.dungeons) do self.db.dungeons[dungeon.id] = true end
        end
        self.db.dungeonsInitialized = true
    end
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
    if locked() or not validRole(PTG.db.role) then return nil end
    local info = C.GetSearchResultInfo(id)
    if not info or not public(info, "table") then return nil end
    local fields = {age = "number", numMembers = "number", isDelisted = "boolean",
        hasSelf = "boolean", activityIDs = "table", requiredItemLevel = "number", partyGUID = "string"}
    for field, kind in pairs(fields) do
        if not public(info[field], kind) then return nil end
    end
    local activityID
    for _, activity in ipairs(info.activityIDs) do
        if public(activity, "number") and PTG.activities[activity]
            and PTG.db.dungeons[activity] == true then activityID = activity; break end
    end
    if not activityID then return nil end
    local rating = info.leaderOverallDungeonScore
    local requiredScore = info.requiredDungeonScore
    if requiredScore == nil then requiredScore = 0 end
    if not nonnegative(rating) or not nonnegative(requiredScore) or not nonnegative(info.requiredItemLevel) then return nil end
    local company, companyReason = API:Company()
    if not company or companyReason then return nil end
    local ilvl, meetsScore
    if company.size == 1 then
        ilvl = GetAverageItemLevel()
        meetsScore = C.ValidateRequiredDungeonScore(requiredScore)
    else
        ilvl = native(C_PartyInfo and C_PartyInfo.GetMinItemLevel, Enum.AvgItemLevelCategories.Base)
        meetsScore = requiredScore == 0
        if requiredScore > 0 then
            meetsScore = true
            for _, member in ipairs(company.members) do
                local summary = native(C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary, member.unit)
                if not public(summary, "table") or not nonnegative(summary.currentSeasonScore)
                    or summary.currentSeasonScore < requiredScore then meetsScore = false; break end
            end
        end
    end
    if not nonnegative(ilvl) or not public(meetsScore, "boolean") then return nil end
    local counts = C.GetSearchResultMemberCounts(id)
    if not public(counts, "table") then return nil end
    local roleCounts, roleRemaining = {}, {}
    for _, role in ipairs({"TANK", "HEALER", "DAMAGER"}) do
        if not public(counts[role], "number") then return nil end
        roleCounts[role] = counts[role]
        local remaining = counts[role .. "_REMAINING"]
        if public(remaining, "number") then roleRemaining[role] = remaining end
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
        roleCounts = roleCounts, roleRemaining = roleRemaining, members = members, complete = complete}
end

function API:ReadGroup(id)
    local ok, group = pcall(readGroup, id)
    if ok then return group end
end

local function applicationGroup(id, identity)
    if locked() or not public(identity, "string") or identity == "" then return nil end
    local info = C.GetSearchResultInfo(id)
    if not public(info, "table") then return nil end
    for field, kind in pairs({ partyGUID = "string", numMembers = "number", isDelisted = "boolean",
        hasSelf = "boolean", activityIDs = "table" }) do
        if not public(info[field], kind) then return nil end
    end
    if info.partyGUID ~= identity or info.isDelisted or info.hasSelf then return nil end
    local mythicPlus = false
    for _, activityID in ipairs(info.activityIDs) do
        if public(activityID, "number") and PTG.activities and PTG.activities[activityID] then
            mythicPlus = true
            break
        end
    end
    if not mythicPlus then return nil end
    local counts = C.GetSearchResultMemberCounts(id)
    if not public(counts, "table") then return nil end
    local roleCounts = {}
    for _, memberRole in ipairs({ "TANK", "HEALER", "DAMAGER" }) do
        if not public(counts[memberRole], "number") then return nil end
        roleCounts[memberRole] = counts[memberRole]
    end
    return {numMembers = info.numMembers, roleCounts = roleCounts}
end

function API:IsRoleFull(id, identity, role)
    local ok, full = pcall(function() return PTG.Filters.IsRoleFull(applicationGroup(id, identity), role) end)
    if ok then return full end
end

function API:IsPartyFull(id, identity, size)
    local ok, full = pcall(function() return PTG.Filters.IsPartyFull(applicationGroup(id, identity), size) end)
    if ok then return full end
end

function API:RoleCheckPending(id)
    if locked() then return false end
    local app = self:ReadApplication(id)
    if not app or app.pending ~= "applied" then return false end
    local active = native(C.GetRoleCheckInfo)
    if public(active, "boolean") and active then return true end
    -- A local role dialog can close while companions are still confirming.
    local pending = PTG.engine.pending
    if not pending or not pending.waitingRoles or pending.identity ~= app.identity then return false end
    local applying = native(C.IsCurrentlyApplying)
    return public(applying, "boolean") and applying
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
    if not validRole(settings.role) then return false, "no_role" end
    local company, reason = self:Company()
    if locked() or reason then return false, reason end
    if applyingReason(company) then return false end
    local languages, activities = {}, {}
    for _, language in ipairs(PTG:GetLanguages()) do
        languages[language.id] = language.mandatory or language.selected
    end
    for id in pairs(PTG.activities) do
        if settings.dungeons[id] == true then activities[#activities + 1] = id end
    end
    if #activities == 0 or not next(languages) then return false, "unavailable" end
    table.sort(activities)
    local filters = {activities = {}, difficultyMythicPlus = true, minimumRating = settings.minRating,
        needsTank = company.size == 1 and settings.role == "TANK",
        needsHealer = company.size == 1 and settings.role == "HEALER",
        needsDamage = company.size == 1 and settings.role == "DAMAGER"}
    PTG.issuingSearch = true
    local ok, reason = pcall(C.Search, CATEGORY, 0, 0, languages, nil, filters, activities)
    PTG.issuingSearch = false
    if not ok and public(reason, "string") then PTG.engine:Log("native_error", reason) end
    return ok
end

function API:Apply(id, role)
    if not validRole(role) then return false, "no_role" end
    if self:Context() then return false end
    local company, reason = self:Company()
    if reason then return false end
    if applyingReason(company) then return false end
    if company.size > 1 then
        if not PTG.engine.scopeKnown or company.scope ~= PTG.engine.scope then return false end
        local group = self:ReadGroup(id)
        if not group or not PTG.Filters.Eligible(group, PTG.db, self:Player()) then return false end
    end
    local ok, reason = pcall(C.ApplyToGroup, id, role == "TANK", role == "HEALER", role == "DAMAGER")
    if not ok and public(reason, "string") then PTG.engine:Log("native_error", reason) end
    return ok
end

function API:Cancel(id)
    if locked() then return false end
    local company, reason = self:Company()
    if reason then return false end
    if applyingReason(company) then return false end
    if company.size > 1 and (not PTG.engine.scopeKnown or company.scope ~= PTG.engine.scope) then return false end
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
    if self.ui then self.ui:Show() end
    self.engine:Start()
    self.engine:Plan()
    self:RefreshUI()
end

function PTG:Stop()
    self.engine:Stop()
    self:RefreshUI()
end

function PTG:OnPress()
    if not self.engine or self.inPress or self.Input.IsBinding() then return end
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

function PTG:SetInputMode(mode)
    mode = public(mode, "string") and mode == "key" and "key" or "auto"
    if self.db.inputMode == mode then return end
    if self.CancelBindingCapture then self:CancelBindingCapture() end
    self.db.inputMode = mode
    self:RefreshUI()
end

function PTG:SetRole(role)
    if not validRole(role) then role = nil end
    if self.db.role == role then return end
    self.db.role = role
    if self.engine then self:SettingsChanged() end
end

function PTG:SyncRole()
    if not self.db.autoRole then return end
    local spec = native(C_SpecializationInfo and C_SpecializationInfo.GetSpecialization)
    local role
    if public(spec, "number") then
        role = native(function() return select(5, C_SpecializationInfo.GetSpecializationInfo(spec)) end)
    end
    self:SetRole(role)
end

function PTG:GetView()
    local engine = self.engine
    local company = engine.company
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
        nextCandidate = engine.nextCandidate, applications = apps, searchText = query(),
        companySize = company and company.size, companyRoles = company and company.roles,
        companyLeader = company and company.leader,
        groupFinderVisible = LFGListFrame and LFGListFrame:IsVisible() or false}
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
    if not self.ui then return end
    self.ui:SetShown(not self.ui:IsShown())
    -- OnHide may not fire again while UIParent is already hidden.
    if not self.ui:IsShown() then
        if self.dungeonPicker then self.dungeonPicker:Hide() end
        if self.engine.running then self:Stop() end
    end
end

function PTG:BindsLocale()
    BINDING_HEADER_PRESSTOGROUP = "PressToGroup"
    BINDING_NAME_PRESSTOGROUP_STEP = self:L("binding_step")
    BINDING_NAME_PRESSTOGROUP_WINDOW = self:L("binding_window")
end

function PTG:PrintLog()
    local view = self:GetView()
    print("PressToGroup 0.1.29-beta.1: " .. self:L(view.state, unpack(view.stateArgs or {})))
    for _, entry in ipairs(self.engine.log) do
        print(string.format("[%0.1f] %s", entry.at, self:L(entry.key, unpack(entry.args))))
    end
end

local function buildMovementInput()
    local frame = CreateFrame("Frame", "PressToGroupMovementInput", UIParent,
        "InsecureKeyboardInputPropagatorTemplate")
    PTG.movementInput = frame
    local held = {}
    frame:EnableKeyboard(true)
    frame:SetScript("OnKeyDown", function(_, key)
        if not public(key, "string") or held[key] then return end
        held[key] = true
        if not PTG.engine.running or PTG.db.inputMode ~= "auto" or PTG.Input.IsBinding()
            or type(GetCurrentKeyBoardFocus) ~= "function" then return end
        local ok, focus = pcall(GetCurrentKeyBoardFocus)
        if not ok or (issecretvalue and issecretvalue(focus)) or focus ~= nil then return end
        local action = native(GetBindingFromInput, key)
        if public(action, "string") and MOVEMENT_ACTIONS[action] then PTG:OnPress() end
    end)
    frame:SetScript("OnKeyUp", function(_, key)
        if public(key, "string") then held[key] = nil end
    end)
    function frame:ReconcileKeys()
        for key in pairs(held) do
            local down = native(IsKeyDown, key)
            -- Recover a missed release without turning a held key into repeated actions.
            if public(down, "boolean") and not down then held[key] = nil end
        end
    end
end

local function initialize()
    PressToGroupDB = type(PressToGroupDB) == "table" and PressToGroupDB or {}
    PTG.db = PressToGroupDB
    local db = PTG.db
    db.locale = (db.locale == "ruRU" or db.locale == "enUS") and db.locale or "auto"
    db.compactMode = db.compactMode == true
    db.inputMode = public(db.inputMode, "string") and db.inputMode == "key" and "key" or "auto"
    db.autoRole = db.autoRole ~= false
    if db.autoRole then PTG:SyncRole() else PTG:SetRole(db.role) end
    db.minRating = math.max(0, tonumber(db.minRating) or 0)
    db.replaceAfter = PTG.Engine.ParseReplacementAge(db.replaceAfter) or 180
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
    buildMovementInput()
    if type(SecureActionButton_OnClick) == "function" then
        hooksecurefunc("SecureActionButton_OnClick", function(...)
            if PTG.engine.running and PTG.db.inputMode == "auto" and PTG.Input.Accept(...) then PTG:OnPress() end
        end)
    end
    hooksecurefunc(C, "Search", function()
        if not PTG.issuingSearch then
            PTG.engine:ForeignSearch(LFGListFrame and LFGListFrame:IsVisible())
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
events:SetScript("OnEvent", function(_, event, name, isReloadingUi)
    if event == "ADDON_LOADED" then
        if name ~= addonName then
            if PTG.engine and (name == "Blizzard_GroupFinder" or name == "PremadeGroupsFilter") then
                PTG:BuildGroupFinderButton()
            end
            return
        end
        if PTG.engine then return end
        initialize()
        for _, value in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "PLAYER_SPECIALIZATION_CHANGED", "GROUP_ROSTER_UPDATE", "LFG_LIST_SEARCH_RESULTS_RECEIVED",
            "LFG_LIST_SEARCH_FAILED", "LFG_LIST_SEARCH_RESULT_UPDATED", "LFG_LIST_APPLICATION_STATUS_UPDATED",
            "LFG_LIST_AVAILABILITY_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UPDATE_BINDINGS",
            "PARTY_LEADER_CHANGED", "PLAYER_ROLES_ASSIGNED", "ROLE_CHANGED_INFORM", "LFG_LIST_JOINED_GROUP",
            "LFG_ROLE_CHECK_SHOW", "LFG_ROLE_CHECK_UPDATE", "LFG_ROLE_CHECK_HIDE", "LFG_ROLE_CHECK_DECLINED",
            "LFG_ROLE_CHECK_ROLE_CHOSEN", "LFG_ROLE_UPDATE"}) do
            events:RegisterEvent(value)
        end
        return
    end
    if event == "PLAYER_LOGOUT" then
        PTG.db.reopenOnReload = PTG.engine.running == true
        return
    end
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" or event == "UPDATE_BINDINGS" then
        if event == "PLAYER_REGEN_DISABLED" and PTG.CancelBindingCapture then PTG:CancelBindingCapture() end
        PTG:RefreshUI()
        return
    end
    local ok, reason = pcall(function()
        if event == "PLAYER_ENTERING_WORLD" or (event == "PLAYER_SPECIALIZATION_CHANGED" and public(name, "string") and name == "player") then
            PTG:SyncRole()
        end
        if event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" then PTG.engine:SearchReceived()
        elseif event == "LFG_LIST_SEARCH_FAILED" then PTG.engine:SearchFailed(public(name, "string") and name or nil)
        elseif event == "LFG_LIST_JOINED_GROUP" then PTG.engine:Stop("company_changed")
        elseif event == "PLAYER_ENTERING_WORLD" or event == "LFG_LIST_AVAILABILITY_UPDATE" then
            PTG:LoadDungeons()
        end
        PTG.engine:Plan()
        if event == "PLAYER_ENTERING_WORLD" then
            local reopen = isReloadingUi == true and PTG.db.reopenOnReload == true
            PTG.db.reopenOnReload = nil
            if PressToGroupWelcomeShown ~= true and PTG:ShowWelcome() then
                PressToGroupWelcomeShown = true
            elseif reopen then
                PTG.ui:Show()
            end
        end
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
    local ok, reason = pcall(function()
        PTG.movementInput:ReconcileKeys()
        if PTG.db.autoRole and PTG.db.role == nil then PTG:SyncRole() end
        PTG.engine:Plan()
    end)
    if not ok then reportError(reason) end
    PTG:RefreshUI()
end)
