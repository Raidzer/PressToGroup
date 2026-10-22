local _, PTG = ...
local Engine = {}
Engine.__index = Engine
PTG.Engine = Engine

local function active(app)
    return app and (app.pending or app.status == "applied" or app.status == "invited"
        or app.status == "inviteaccepted")
end

local function terminal(app)
    local statuses = {cancelled = true, declined = true, declined_full = true, declined_delisted = true,
        failed = true, timedout = true, invitedeclined = true}
    return app and not app.pending and statuses[app.status] == true
end

function Engine.ParseReplacementAge(value)
    if type(value) ~= "number" and type(value) ~= "string" then return nil end
    value = tonumber(value)
    if value and value > 0 and value < math.huge and value % 1 == 0 then return value end
end

function Engine.New(api, settings)
    return setmetatable({api = api, settings = settings, running = false, revision = 0,
        results = {}, applications = {}, owned = {}, blocked = {}, log = {}, found = 0,
        eligible = 0, active = 0, limit = 5, nextSearch = 0, failures = 0, state = "off"}, Engine)
end

function Engine:SetState(key, ...)
    self.state, self.stateArgs = key, {...}
end

function Engine:Log(key, ...)
    self.log[#self.log + 1] = {at = self.api:Now(), key = key, args = {...}}
    if #self.log > 40 then table.remove(self.log, 1) end
end

function Engine:Invalidate()
    self.revision = self.revision + 1
    self.results, self.found, self.eligible, self.validAt = {}, 0, 0, nil
    if self.search then self.search.stale = true end
end

function Engine:Start()
    self:Invalidate()
    self.running = true
    if not self.conflict then self.problem = nil end
    self:SetState("ready_search")
    self:Log("started")
end

function Engine:Stop(state)
    self.running = false
    self:Invalidate()
    self:SetState(state or "off")
    self:Log("stopped")
end

function Engine:SettingsChanged()
    self:Invalidate()
    self:SetState(self.running and "filters_changed" or "off")
end

function Engine:ForeignSearch(manual)
    self:Invalidate()
    if manual and not self.search and not self.conflict then
        self.search = {at = self.api:Now(), revision = self.revision, stale = true}
        return
    end
    if self.search then self.search.foreign = true end
    self.conflict = true
    self:SetState("search_conflict")
    self:Log("search_conflict")
end

function Engine:SearchReceived()
    local request = self.search
    self.search = nil
    if not request then return end
    if request.stale or request.foreign or request.revision ~= self.revision then
        self:Log("discarded_search")
        return
    end
    local groups, found = self.api:ReadResults()
    if not groups then
        self.search = request
        self:SearchFailed("unavailable")
        return
    end
    self.results, self.found = groups, found or #groups
    self.lastResponse, self.validAt, self.failures = self.api:Now(), self.api:Now(), 0
    PTG.Filters.Sort(self.results)
    self:Log("received", self.found)
    self:SetState(self.found == 0 and "search_empty" or "no_candidates",
        math.max(0, math.ceil(self.nextSearch - self.api:Now())))
end

function Engine:SearchFailed(reason)
    local request = self.search
    if not request then return end
    self.search = nil
    if request and (request.stale or request.foreign) then return end
    self.validAt = nil
    self.failures = math.min(self.failures + 1, 4)
    self.nextSearch = self.api:Now() + math.min(60, 8 * 2 ^ (self.failures - 1))
    self.problem = reason == "throttled" and "cooldown" or "search_failed"
    self:SetState(self.problem)
    self:Log(self.problem)
end

function Engine:Reconcile()
    local apps, count, reliable, limit = self.api:ReadApplications()
    self.applications, self.active, self.reliable = apps or {}, count or 0, reliable == true
    self.limit = limit or 5
    local now, seen = self.api:Now(), {}
    for _, app in ipairs(self.applications) do
        if app.identity then
            seen[app.identity] = app
            if terminal(app) then
                self.blocked[app.identity] = true
            end
        end
    end

    local op = self.pending
    if op then
        local app = seen[op.identity] or self.api:ReadApplication(op.id)
        local same = app and app.identity == op.identity
        if op.kind == "apply" and same and app.status == "applied" and not app.pending then
            self.owned[op.identity] = {id = app.id, at = now, role = op.role}
            self.pending = nil
            self:Log("applied")
        elseif op.kind == "apply" and same and app.status == "invited" then
            self.pending = nil
        elseif op.kind == "apply" and same and terminal(app) then
            self.blocked[op.identity], self.pending = true, nil
        elseif op.kind == "cancel" and app and not active(app)
            and (same or app.status == "none") then
            self.blocked[op.identity], self.owned[op.identity], self.pending = true, nil, nil
            self:Log("cancelled")
        elseif now - op.at >= 10 then
            -- A missing acknowledgement never grants ownership or a free slot.
            self.blocked[op.identity], self.pending = true, nil
            self.running, self.problem = false, "operation_unknown"
            self:Invalidate()
            self:Log("operation_unknown")
        end
    end

    self.invited = false
    for _, app in ipairs(self.applications) do
        local own = app.identity and self.owned[app.identity]
        if own and active(app) then own.id = app.id end
        app.owned = own ~= nil and own.id == app.id and app.status == "applied" and not app.pending
        app.age = own and math.max(0, now - own.at) or nil
        if own and terminal(app) then self.owned[app.identity] = nil end
        if app.status == "invited" or app.status == "inviteaccepted" then
            self.invited = true
            if self.lastInvite ~= app.id then
                self.lastInvite = app.id
                self.api:InviteSound()
                self:Log("invited")
            end
        end
    end
    for identity in pairs(self.owned) do
        if not seen[identity] and self.reliable and not self.pending then
            self.owned[identity], self.blocked[identity] = nil, true
        end
    end
end

function Engine:Tick()
    if self.api:Context() == "chat_lockdown" then
        if not self.locked then self:Invalidate() end
        self.locked, self.context = true, "chat_lockdown"
        return
    end
    self.locked = false
    self:Reconcile()
    local context = self.api:Context()
    if context == "grouped" then
        if self.running then self:Stop("grouped") end
        self.grouped = true
    elseif self.grouped then
        self.grouped = false
        self:SetState("off")
    end
    if context == "manual_search" and not self.manual then self:Invalidate() end
    self.manual = context == "manual_search"
    self.context = context
    if self.search and self.api:Now() - self.search.at >= 12 then
        -- No native request ID: retrying could mistake a late response for a new one.
        self.search, self.conflict, self.problem = nil, true, "search_timeout"
        self:Invalidate()
        self:Log("search_timeout")
    end
end

function Engine:Candidate()
    if not self.validAt or self.api:Now() - self.validAt > 20 then self.eligible = 0; return nil end
    local player, identities = self.api:Player(), {}
    for _, app in ipairs(self.applications) do
        if app.identity and active(app) then identities[app.identity] = true end
    end
    self.eligible = 0
    local first
    for _, old in ipairs(self.results) do
        local group = self.api:ReadGroup(old.id)
        if group and group.identity == old.identity and not self.blocked[group.identity]
            and not identities[group.identity] and not self.owned[group.identity]
            and PTG.Filters.Eligible(group, self.settings, player) then
            local app = self.api:ReadApplication(group.id)
            if app and app.status == "none" and not app.pending then
                self.eligible = self.eligible + 1
                first = first or group
            end
        end
    end
    return first
end

function Engine:Plan()
    self:Tick()
    self.nextCandidate = nil
    if self.invited then self:SetState("invited"); return end
    if self.context then self:SetState(self.context); return end
    if not self.running then self:SetState(self.problem or (self.grouped and "grouped" or "off")); return end
    if self.conflict then self:SetState(self.problem or "search_conflict"); return end
    if not self.reliable then self:SetState("operation_unknown"); return end
    if self.pending then self:SetState(self.pending.kind == "apply" and "wait_apply" or "wait_cancel"); return end
    if self.search then self:SetState("searching"); return end

    for _, app in ipairs(self.applications) do
        local own = app.identity and self.owned[app.identity]
        if app.owned and own and own.role and self.api:IsRoleFull(app.id, app.identity, own.role) == true then
            self:SetState("ready_cancel_role_full")
            return "cancel", app
        end
    end

    local candidate = self:Candidate()
    self.nextCandidate = candidate
    if candidate then
        local replaceAfter = Engine.ParseReplacementAge(self.settings.replaceAfter) or 180
        local oldest
        for _, app in ipairs(self.applications) do
            if app.owned and app.age >= replaceAfter and (not oldest or app.age > oldest.age) then oldest = app end
        end
        if oldest then
            self:SetState("ready_cancel")
            return "cancel", oldest
        elseif self.active < self.limit then
            self:SetState("ready_apply")
            return "apply", candidate
        end
    end
    if self.api:Now() >= self.nextSearch then
        self:SetState("ready_search")
        return "search"
    end
    if self.active >= self.limit then self:SetState("full")
    elseif self.problem then self:SetState(self.problem)
    elseif self.found == 0 and self.lastResponse then
        self:SetState("search_empty", math.ceil(self.nextSearch - self.api:Now()))
    else self:SetState("waiting_search", math.ceil(self.nextSearch - self.api:Now())) end
end

function Engine:Press()
    local kind, group = self:Plan()
    if not kind then return end
    local now = self.api:Now()
    if self.lastAction and now - self.lastAction < 0.35 then return end
    self.lastAction = now
    local ok, reason
    if kind == "search" then
        self.search = {at = now, revision = self.revision}
        self.nextSearch, self.problem = now + 8, nil
        self:SetState("searching")
        self:Log("search_sent")
        ok, reason = self.api:Search(self.settings)
        if not ok then self:SearchFailed(reason) end
    else
        if self.state == "ready_cancel_role_full" then self:Log("cancel_role_full") end
        self.pending = {kind = kind, id = group.id, identity = group.identity, at = now}
        self:SetState(kind == "apply" and "wait_apply" or "wait_cancel")
        self:Log(kind == "apply" and "apply_sent" or "cancel_sent")
        if kind == "apply" then
            self.pending.role = self.settings.role
            ok, reason = self.api:Apply(group.id, self.pending.role)
        else
            ok, reason = self.api:Cancel(group.id)
        end
        if not ok then
            self.pending, self.running, self.problem = nil, false, "operation_unknown"
            self.blocked[group.identity] = true
            self:Log("operation_unknown")
        end
    end
end

function Engine:Cancel(id)
    self:Tick()
    if self.pending or self.invited or self.context == "grouped" or not self.reliable then return end
    for _, app in ipairs(self.applications) do
        if app.id == id and app.owned then
            local current = self.api:ReadApplication(id)
            if current and current.identity == app.identity and current.status == "applied" and not current.pending then
                self.pending = {kind = "cancel", id = id, identity = app.identity, at = self.api:Now()}
                local ok = self.api:Cancel(id)
                if not ok then
                    self.pending, self.running, self.problem = nil, false, "operation_unknown"
                    self:Invalidate()
                    self:Log("operation_unknown")
                end
            end
            return
        end
    end
end
