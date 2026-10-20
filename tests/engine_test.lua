local PTG = {}
local source = arg and arg[0] and arg[0]:gsub("\\", "/") or "tests/engine_test.lua"
local root = source:match("^(.*)/tests/[^/]+$") or "."
assert(loadfile(root .. "/Filters.lua"))("PressToGroup", PTG)
assert(loadfile(root .. "/Engine.lua"))("PressToGroup", PTG)

local passed, failed = 0, 0
local function test(name, run)
    local ok, reason = pcall(run)
    if ok then passed = passed + 1
    else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(reason)) end
end

local function group(id, age)
    return {id = id, identity = "Party-" .. id, activityID = 100,
        age = age, leaderRating = 3000, numMembers = 3,
        isDelisted = false, hasSelf = false, eligible = true,
        roleCounts = {TANK = 1, HEALER = 0, DAMAGER = 2}}
end

local function fixture()
    local api = {now = 100, apps = {}, groups = {group(2, 20), group(1, 5)},
        calls = {}, reliable = true, limit = 5, unknown = {}, sounds = 0}
    function api:Now() return self.now end
    function api:Context() return self.context end
    function api:Player() return {role = "HEALER", class = "PRIEST", specID = 257} end
    function api:ReadGroup(id)
        for _, value in ipairs(self.groups) do if value.id == id then return value end end
    end
    function api:ReadResults() return self.groups, #self.groups end
    function api:ReadApplication(id)
        if self.unknown[id] then return nil end
        local value = self.apps[id]
        if value then return value end
        local entry = self:ReadGroup(id)
        return {id = id, identity = entry and entry.identity, status = "none"}
    end
    function api:ReadApplications()
        local apps, count = {}, 0
        for _, value in pairs(self.apps) do
            apps[#apps + 1] = value
            if value.pending or value.status == "applied" or value.status == "invited"
                or value.status == "inviteaccepted" then count = count + 1 end
        end
        return apps, self.countOverride or count, self.reliable, self.limit
    end
    function api:Search()
        self.calls[#self.calls + 1] = {kind = "search"}
        return true
    end
    function api:Apply(id, role)
        self.calls[#self.calls + 1] = {kind = "apply", id = id, role = role}
        local entry = self:ReadGroup(id)
        self.apps[id] = {id = id, identity = entry.identity, status = "none", pending = "applied"}
        return true
    end
    function api:Cancel(id)
        self.calls[#self.calls + 1] = {kind = "cancel", id = id}
        self.apps[id].pending = "cancelled"
        return true
    end
    function api:InviteSound() self.sounds = self.sounds + 1 end
    return PTG.Engine.New(api, {role = "HEALER"}), api
end

local function press(engine, api, advance)
    api.now = api.now + (advance or 0.5)
    local before = #api.calls
    engine:Press()
    assert(#api.calls - before <= 1, "one press must perform at most one operation")
    return api.calls[#api.calls]
end

local function search(engine, api)
    engine:Start()
    assert(press(engine, api).kind == "search", "first step searches")
    assert(not engine.lastResponse, "sending a request is not a received response")
    engine:SearchReceived()
    assert(engine.lastResponse == api.now, "timestamp belongs to the received response")
end

local function confirm(engine, api, id)
    api.apps[id].status, api.apps[id].pending = "applied", nil
    engine:Tick()
    assert(engine.owned[api.apps[id].identity], "client confirmation grants ownership")
    return engine.owned[api.apps[id].identity].at
end

local function manual(api, first, last)
    for id = first, last do
        api.apps[id] = {id = id, identity = "Manual-" .. id, status = "applied"}
    end
end

test("newest candidate and confirmation", function()
    local e, api = fixture()
    search(e, api)
    local call = press(e, api)
    assert(call.kind == "apply" and call.id == 1 and call.role == "HEALER")
    assert(not next(e.owned), "a sent request does not grant ownership")
    local before = #api.calls
    press(e, api)
    assert(#api.calls == before, "a pending application blocks another operation")
    confirm(e, api, 1)
    call = press(e, api)
    assert(call.kind == "apply" and call.id == 2, "no immediate duplicate application")
end)

test("manual applications consume the native limit", function()
    local e, api = fixture()
    manual(api, 101, 105)
    search(e, api)
    local before = #api.calls
    press(e, api)
    assert(#api.calls == before and e.active == 5, "five manual applications fill all slots")
    api.apps[105].status = "declined"
    assert(press(e, api).kind == "apply", "a confirmed refusal frees a native slot")
end)

test("replacement starts at confirmed age 180 and takes separate presses", function()
    local e, api = fixture()
    search(e, api)
    press(e, api)
    api.now = api.now + 5
    local at = confirm(e, api, 1)
    manual(api, 101, 104)
    api.now = at + 179
    assert(press(e, api, 0).kind == "search", "old results require a new search")
    e:SearchReceived()
    local before = #api.calls
    api.now = at + 179.4
    press(e, api, 0)
    assert(#api.calls == before, "an application younger than 180 seconds stays")
    api.now = at + 180
    local call = press(e, api, 0)
    assert(call.kind == "cancel" and call.id == 1, "only the owned old application is cancelled")
    before = #api.calls
    press(e, api)
    assert(#api.calls == before and e.active == 5, "pending cancellation does not free a slot")
    api.apps[1].status, api.apps[1].pending = "cancelled", nil
    e:Tick()
    before = #api.calls
    e:Tick()
    assert(#api.calls == before, "confirmation and timer ticks cannot submit applications")
    call = press(e, api)
    assert(call.kind == "apply" and call.id == 2)
end)

test("stop preserves applications and supports explicit own cancellation", function()
    local e, api = fixture()
    search(e, api)
    press(e, api)
    confirm(e, api, 1)
    e:Stop()
    local before = #api.calls
    press(e, api, 300)
    assert(#api.calls == before and api.apps[1].status == "applied")
    e:Cancel(1)
    assert(#api.calls == before + 1 and api.calls[#api.calls].kind == "cancel")
end)

test("reload grants no ownership of existing applications", function()
    local e, api = fixture()
    manual(api, 101, 105)
    e:Tick()
    assert(not e.running and not next(e.owned))
    e:Cancel(101)
    assert(#api.calls == 0, "unknown-origin applications cannot be cancelled")
    search(e, api)
    press(e, api, 500)
    for _, call in ipairs(api.calls) do assert(call.kind == "search") end
end)

for _, status in ipairs({"declined", "declined_full", "declined_delisted", "failed", "timedout"}) do
    test("terminal application before confirmation: " .. status, function()
        local e, api = fixture()
        search(e, api)
        press(e, api)
        api.apps[1].status, api.apps[1].pending = status, nil
        e:Tick()
        assert(not e.pending and e.running, "a definite refusal is not an unknown operation")
        assert(e.blocked["Party-1"] and not e.owned["Party-1"])
        local call = press(e, api)
        assert(call.kind == "apply" and call.id == 2)
    end)
end

test("unacknowledged operation times out without granting ownership", function()
    local e, api = fixture()
    search(e, api)
    press(e, api)
    api.unknown[1], api.apps[1] = true, nil
    local before = #api.calls
    api.now = api.now + 11
    e:Tick()
    press(e, api)
    assert(not e.running and e.problem == "operation_unknown")
    assert(not e.owned["Party-1"] and e.blocked["Party-1"] and #api.calls == before)
end)

test("invitation pauses all operations and sounds once", function()
    local e, api = fixture()
    search(e, api)
    press(e, api)
    confirm(e, api, 1)
    api.apps[1].status = "invited"
    local before = #api.calls
    press(e, api, 200)
    e:Tick()
    e:Cancel(1)
    assert(#api.calls == before and e.state == "invited" and api.sounds == 1)
end)

test("leaving a group requires explicit restart", function()
    local e, api = fixture()
    search(e, api)
    api.context = "grouped"
    local before = #api.calls
    press(e, api)
    assert(not e.running)
    api.context = nil
    press(e, api)
    assert(#api.calls == before)
    e:Start()
    assert(press(e, api).kind == "search")
end)

test("changed filters discard an outstanding response", function()
    local e, api = fixture()
    e:Start()
    press(e, api)
    e:SettingsChanged()
    e:SearchReceived()
    assert(not e.validAt and not e.lastResponse and #e.results == 0)
    press(e, api, 8)
    assert(#api.calls == 2 and api.calls[2].kind == "search")
    e:SearchReceived()
    assert(press(e, api).kind == "apply")
end)

test("manual search pauses and requires fresh results after closing", function()
    local e, api = fixture()
    search(e, api)
    api.context = "manual_search"
    local before = #api.calls
    press(e, api)
    assert(#api.calls == before and not e.validAt)
    api.context = nil
    assert(press(e, api, 8).kind == "search")
end)

test("an isolated manual search is drained without claiming its results", function()
    local e, api = fixture()
    search(e, api)
    api.context = "manual_search"
    e:Tick()
    e:ForeignSearch(true)
    e:SearchReceived()
    assert(not e.conflict and not e.validAt and #e.results == 0)
    api.context = nil
    assert(press(e, api, 8).kind == "search")
end)

test("chat lockdown pauses without reading protected application data", function()
    local e, api = fixture()
    search(e, api)
    local read = api.ReadApplications
    api.ReadApplications = function() error("protected application read") end
    api.context = "chat_lockdown"
    local before = #api.calls
    press(e, api)
    assert(#api.calls == before and e.context == "chat_lockdown" and not e.validAt)
    api.context, api.ReadApplications = nil, read
    assert(press(e, api, 8).kind == "search", "unlocking requires fresh results")
end)

test("foreign search conflict survives stop and start", function()
    local e, api = fixture()
    e:Start()
    press(e, api)
    e:ForeignSearch()
    e:SearchReceived()
    assert(not e.validAt and not e.lastResponse)
    e:Stop()
    e:Start()
    local before = #api.calls
    press(e, api, 20)
    assert(e.conflict and #api.calls == before)
end)

test("search timeout stays conflicted even after a late response or restart", function()
    local e, api = fixture()
    e:Start()
    press(e, api)
    api.now = api.now + 13
    e:Tick()
    assert(e.conflict and not e.validAt, "an uncorrelated timeout is a conflict")
    e:SearchReceived()
    assert(not e.validAt and not e.lastResponse, "the late response cannot authorize applications")
    e:Start()
    local before = #api.calls
    press(e, api)
    assert(e.conflict and #api.calls == before)
    local reloaded = PTG.Engine.New(api, {role = "HEALER"})
    reloaded:Start()
    assert(press(reloaded, api).kind == "search", "a new session starts with no conflict")
end)

test("explicit search failures retry only on input with exponential backoff", function()
    local e, api = fixture()
    e:Start()
    press(e, api)
    for _, delay in ipairs({8, 16, 32, 60, 60}) do
        local at = api.now
        e:SearchFailed("throttled")
        assert(not e.conflict and not e.lastResponse and e.nextSearch - at == delay)
        local before = #api.calls
        press(e, api, delay - 0.5)
        assert(#api.calls == before, "input during backoff cannot search")
        api.now = e.nextSearch
        e:Tick()
        assert(#api.calls == before, "a timer cannot retry a search")
        assert(press(e, api, 0).kind == "search" and #api.calls == before + 1)
    end
end)

test("unreliable application list blocks every automatic operation", function()
    local e, api = fixture()
    search(e, api)
    api.reliable = false
    local before = #api.calls
    press(e, api)
    assert(#api.calls == before)
end)

test("a remapped application ID keeps confirmed ownership and age", function()
    local e, api = fixture()
    search(e, api)
    press(e, api)
    local at = confirm(e, api, 1)
    api.apps[91], api.apps[1] = {id = 91, identity = "Party-1", status = "applied"}, nil
    e:Tick()
    assert(e.applications[1].owned and e.owned["Party-1"].id == 91)
    assert(e.owned["Party-1"].at == at)
end)

test("an application remapped before confirmation uses its current ID", function()
    local e, api = fixture()
    search(e, api)
    press(e, api)
    local sentAt = api.now
    assert(not e.owned["Party-1"])
    api.apps[91], api.apps[1] = {id = 91, identity = "Party-1", status = "applied"}, nil
    api.now = api.now + 4
    e:Tick()
    local own = e.owned["Party-1"]
    assert(not e.pending and own and own.id == 91, "confirmation follows the stable party identity")
    assert(own.at == api.now and own.at > sentAt, "replacement age starts at client confirmation")
    e:Cancel(91)
    local call = api.calls[#api.calls]
    assert(call.kind == "cancel" and call.id == 91, "later operations use the confirmed current ID")
end)

test("failed explicit cancellation pauses further automatic actions", function()
    local e, api = fixture()
    search(e, api)
    press(e, api)
    confirm(e, api, 1)
    function api:Cancel() return false end
    e:Cancel(1)
    assert(not e.running and e.problem == "operation_unknown" and not e.validAt)
    local before = #api.calls
    press(e, api, 20)
    assert(#api.calls == before, "a failed manual cancel cannot silently resume actions")
end)

test("remapping during cancellation does not falsely acknowledge a free slot", function()
    local e, api = fixture()
    search(e, api)
    press(e, api)
    confirm(e, api, 1)
    e:Cancel(1)
    api.apps[91], api.apps[1] = {id = 91, identity = "Party-1", status = "applied"}, nil
    e:Tick()
    assert(e.pending and e.pending.kind == "cancel" and e.active == 1)
    assert(e.owned["Party-1"].id == 91, "same party is still active on its new ID")
    api.apps[91].status = "cancelled"
    e:Tick()
    assert(not e.pending and e.active == 0 and not e.owned["Party-1"])
end)

print("engine: " .. passed .. " scenarios passed, " .. failed .. " failed")
assert(failed == 0, "engine scenarios failed")
