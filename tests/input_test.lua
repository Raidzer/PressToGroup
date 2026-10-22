local PTG = {}
local source = arg and arg[0] and arg[0]:gsub("\\", "/") or "tests/input_test.lua"
local root = source:match("^(.*)/tests/[^/]+$") or "."
assert(loadfile(root .. "/Input.lua"))("PressToGroup", PTG)
local Input = PTG.Input
local checks = 0
local cvarKeyDown = false
local secretValue = setmetatable({}, { __eq = function() error("secret was compared") end })

function issecretvalue(value) return rawequal(value, secretValue) end
function SecureActionButton_ShouldUseOnKeyDown(button)
    local value = button:GetAttribute("useOnKeyDown")
    if value == nil then return cvarKeyDown end
    return value
end

local function button(name, action, attributes)
    return {
        name = name or "ActionButton1", action = action or 1, attributes = attributes or {},
        GetName = function(self) return self.name end,
        GetAttribute = function(self, name) return self.attributes[name] end,
    }
end

local function accept(expected, frame, inputButton, down, key, secure)
    assert(Input.Accept(frame, inputButton, down, key, secure) == expected, "input check " .. (checks + 1))
    checks = checks + 1
end

local function phasePair(frame, key, expectedDown)
    accept(expectedDown, frame, "LeftButton", true, key, true)
    accept(not expectedDown, frame, "LeftButton", false, key, true)
end

local frame = button()
phasePair(frame, true, false)
cvarKeyDown = true
phasePair(frame, true, true)
phasePair(button(nil, nil, { useOnKeyDown = false }), true, false)
cvarKeyDown = false
phasePair(button(nil, nil, { useOnKeyDown = true }), true, true)
phasePair(button(nil, nil, { pressAndHoldAction = true }), true, true)
phasePair(frame, false, false)
cvarKeyDown = true
phasePair(button(nil, nil, { useOnKeyDown = true, pressAndHoldAction = true }), false, false)

for _, name in ipairs({ "ActionButton12", "MultiBarBottomLeftButton1", "MultiBarBottomRightButton12",
    "MultiBarLeftButton1", "MultiBarRightButton12", "MultiBar5Button1", "MultiBar6Button1",
    "MultiBar7Button1", "OverrideActionBarButton6", "ExtraActionButton1" }) do
    accept(true, button(name), "LeftButton", false, false, true)
end
for _, name in ipairs({ "CustomButton1", "PetActionButton1", "StanceButton1", "SpellFlyoutButton1",
    "MultiBarCustomButton1", "ActionButton1Suffix", "PrefixActionButton1", "ActionButton" }) do
    accept(false, button(name), "LeftButton", false, false, true)
end
accept(false, frame, "RightButton", false, false, true)
accept(false, frame, "MiddleButton", false, false, true)
accept(false, frame, "LeftButton", false, false, false)
accept(false, frame, "LeftButton", false, false, nil)
accept(false, frame, "LeftButton", false, nil, true)
accept(false, frame, "LeftButton", nil, true, true)
accept(false, frame, "LeftButton", 0, true, true)
accept(false, nil, "LeftButton", false, false, true)
accept(false, {}, "LeftButton", false, false, true)
accept(false, "ActionButton1", "LeftButton", false, false, true)
for _, action in ipairs({ 0, -1, 0.5, math.huge, 0 / 0, "1" }) do
    local invalid = button()
    invalid.action = action
    accept(false, invalid, "LeftButton", false, false, true)
end
local missingAction = button()
missingAction.action = nil
accept(false, missingAction, "LeftButton", false, false, true)

QuickKeybindFrame = { IsShown = function() return true end }
accept(false, frame, "LeftButton", true, true, true)
accept(false, frame, "LeftButton", false, false, true)
QuickKeybindFrame.IsShown = function() return false end
accept(true, frame, "LeftButton", false, false, true)
QuickKeybindFrame = {}
accept(true, frame, "LeftButton", false, false, true)
QuickKeybindFrame = nil

for index = 1, 5 do
    local values = { frame, "LeftButton", true, true, true }
    values[index] = secretValue
    accept(false, values[1], values[2], values[3], values[4], values[5])
end
for _, field in ipairs({ "action", "name", "GetName", "GetAttribute" }) do
    local invalid = button()
    invalid[field] = secretValue
    accept(false, invalid, "LeftButton", true, true, true)
end
accept(false, button(nil, nil, { pressAndHoldAction = secretValue }), "LeftButton", true, true, true)
local originalShouldUseOnKeyDown = SecureActionButton_ShouldUseOnKeyDown
SecureActionButton_ShouldUseOnKeyDown = function() return secretValue end
accept(false, frame, "LeftButton", true, true, true)
SecureActionButton_ShouldUseOnKeyDown = originalShouldUseOnKeyDown
QuickKeybindFrame = { IsShown = function() return secretValue end }
accept(false, frame, "LeftButton", true, true, true)
QuickKeybindFrame = secretValue
accept(false, frame, "LeftButton", true, true, true)
QuickKeybindFrame = nil

issecretvalue = nil
accept(true, frame, "LeftButton", false, false, true)
SecureActionButton_ShouldUseOnKeyDown = nil
accept(false, frame, "LeftButton", true, true, true)
accept(true, frame, "LeftButton", false, false, true)

issecretvalue = function(value) return rawequal(value, secretValue) end
local function check(value, message)
    assert(value, message)
    checks = checks + 1
end

for _, active in ipairs({true, secretValue, {}}) do
    PTG.bindingCapture = active
    check(Input.IsBinding(), "PTG capture suppresses input")
    accept(false, frame, "LeftButton", false, false, true)
end
PTG.bindingCapture = nil
for _, name in ipairs({"QuickKeybindFrame", "KeybindListener"}) do
    local method = name == "QuickKeybindFrame" and "IsShown" or "IsListening"
    for _, value in ipairs({true, secretValue, "true"}) do
        _G[name] = {[method] = function() return value end}
        check(Input.IsBinding(), "active or untrusted binding state suppresses input: " .. name)
    end
    _G[name] = {[method] = function() return false end}
    check(not Input.IsBinding(), "inactive binding state permits input: " .. name)
    for _, value in ipairs({secretValue, "invalid", true}) do
        _G[name] = value
        check(Input.IsBinding(), "untrusted binding object suppresses input: " .. name)
    end
    _G[name] = {[method] = secretValue}
    check(Input.IsBinding(), "secret method suppresses input: " .. name)
    _G[name] = {[method] = function() error("binding state failed") end}
    check(Input.IsBinding(), "binding state errors suppress input: " .. name)
    _G[name] = setmetatable({}, {__index = function() error("binding method failed") end})
    check(Input.IsBinding(), "binding method lookup errors suppress input: " .. name)
    _G[name] = nil
end
QuickKeybindFrame = {}
check(not Input.IsBinding(), "an empty legacy QuickKeybindFrame remains harmless")
QuickKeybindFrame = nil
KeybindListener = {}
check(Input.IsBinding(), "an existing native listener without its method fails closed")
KeybindListener = nil

local STEP, OTHER = "PRESSTOGROUP_STEP", "OTHER_ACTION"
local bindingContext, bindingSet, combat = "test-context", 1, false
local bindings, persisted, writes, saves, setFailures, saveFailures, skipWrite
local failureKind, failReadback
local function state()
    return table.concat(bindings[STEP] or {}, ",") .. "|" .. table.concat(bindings[OTHER] or {}, ",")
        .. "|" .. table.concat(bindings.UNRELATED or {}, ",")
end
local function reset(stepKeys, otherKeys)
    bindings = {[STEP] = stepKeys or {"P", "S"}, [OTHER] = otherKeys or {"X", "Y"}, UNRELATED = {"U"}}
    persisted, writes, saves = state(), 0, 0
    setFailures, saveFailures, skipWrite = {}, {}, nil
    failureKind, failReadback, bindingSet, combat, bindingContext = "false", nil, 1, false, "test-context"
end
C_KeyBindings = {GetBindingContextForAction = function(action)
    assert(action == STEP, "the step action selects the native context")
    return bindingContext
end}
GetBindingKey = function(action, ignored, actualContext)
    assert(ignored == nil and actualContext == bindingContext, "GetBindingKey uses the native step context")
    if failReadback and writes > 0 then failReadback = nil; return secretValue end
    local found = bindings[action] or {}
    return found[1], found[2]
end
GetBindingAction = function(key, ignored, actualContext)
    assert(ignored == nil and actualContext == bindingContext, "GetBindingAction uses the native step context")
    for action, found in pairs(bindings) do
        for _, boundKey in ipairs(found) do if key == boundKey then return action end end
    end
    return ""
end
GetCurrentBindingSet = function() return bindingSet end
InCombatLockdown = function() return combat end
SetBinding = function(key, action, actualContext)
    assert(actualContext == bindingContext, "SetBinding uses the native step context")
    writes = writes + 1
    local failed = setFailures[writes]
    if failed and failureKind ~= "after" then
        if failureKind == "throw" then error("SetBinding failed") end
        return false
    end
    if skipWrite ~= writes then
        for _, found in pairs(bindings) do
            for index = #found, 1, -1 do if found[index] == key then table.remove(found, index) end end
        end
        if action then
            bindings[action] = bindings[action] or {}
            table.insert(bindings[action], key)
        end
    end
    if failed then error("SetBinding failed after a partial change") end
    return true
end
SaveBindings = function(set)
    assert(set == bindingSet, "SaveBindings preserves the active account or character set")
    saves = saves + 1
    if saveFailures[saves] then
        if failureKind == "after" then persisted = state(); error("SaveBindings failed after saving") end
        if failureKind == "throw" then error("SaveBindings failed") end
        return false
    end
    persisted = state()
end

reset()
local first, second, reason = Input.GetStepKeys()
check(first == "P" and second == "S" and reason == nil, "read both native step bindings")
local action, set = Input.GetStepKeyAction("N")
check(action == "" and set == 1, "preview a free key and the active set")
action, set = Input.GetStepKeyAction("X")
check(action == OTHER and set == 1, "preview a conflicting action without mutating bindings")
check(writes == 0 and saves == 0, "previews never write or save bindings")
for _, value in ipairs({"", false, 12, {}, secretValue}) do
    local preview, previewReason = Input.GetStepKeyAction(value)
    local assigned, assignedReason = Input.AssignStepKey(value, "", 1)
    check(preview == nil and previewReason == "binding_error" and not assigned and assignedReason == "binding_error",
        "reject invalid or secret keys before mutation")
end
check(select(2, Input.GetStepKeyAction(nil)) == "binding_error", "reject a missing preview key")
check(not Input.AssignStepKey("N", secretValue, 1) and not Input.AssignStepKey("N", "", secretValue),
    "reject untrusted confirmation snapshots")
check(writes == 0 and saves == 0, "invalid keys never mutate bindings")

local function result(expected, expectedReason, ...)
    local ok, why = ...
    check(ok == expected and why == expectedReason, "binding result: " .. expectedReason .. ", got " .. tostring(why))
end
for _, activeSet in ipairs({1, 2}) do
    reset()
    bindingSet = activeSet
    result(true, "binding_saved", Input.AssignStepKey("N", "", activeSet))
    check(state() == "N,S|X,Y|U" and persisted == state() and saves == 1,
        "replace the primary, preserve the secondary and save the active set")
    result(true, "binding_cleared", Input.ClearStepKey())
    check(state() == "S|X,Y|U" and persisted == state(), "clear only the primary and promote the secondary")
end
for _, target in ipairs({"X", "Y"}) do
    reset()
    result(true, "binding_saved", Input.AssignStepKey(target, OTHER, 1))
    check(state() == (target == "X" and "X,S|Y|U" or "Y,S|X|U") and persisted == state(),
        "confirmed conflicts preserve the conflicting action's remaining key")
end
reset({"P"}, {"X"})
result(true, "binding_saved", Input.AssignStepKey("X", OTHER, 1))
check(state() == "X||U", "a conflicting action can lose its only confirmed binding")
reset({}, {})
result(true, "binding_saved", Input.AssignStepKey("N", "", 1))
check(state() == "N||U", "assign the first binding to an unbound step")
result(true, "binding_cleared", Input.ClearStepKey())
local oldWrites, oldSaves = writes, saves
result(true, "binding_cleared", Input.ClearStepKey())
check(writes == oldWrites and saves == oldSaves, "clearing an unbound step is a no-op")
for _, target in ipairs({"P", "S"}) do
    reset()
    result(true, "binding_already", Input.AssignStepKey(target, STEP, 1))
    check(state() == "P,S|X,Y|U" and writes == 0 and saves == 0, "existing primary or secondary never reorder or duplicate")
end
reset()
result(false, "binding_changed", Input.AssignStepKey("X", "", 1))
result(false, "binding_changed", Input.AssignStepKey("N", OTHER, 1))
result(false, "binding_changed", Input.AssignStepKey("N", "", 2))
result(false, "binding_changed", Input.AssignStepKey("P", STEP, 2))
check(writes == 0 and saves == 0 and state() == "P,S|X,Y|U", "stale action and set confirmations never mutate")
combat = true
result(false, "binding_combat", Input.AssignStepKey("N", "", 1))
result(false, "binding_combat", Input.ClearStepKey())
check(writes == 0 and saves == 0, "combat rejects assignment and clearing before writes")

for _, kind in ipairs({"false", "throw", "after"}) do
    for failedAt = 1, 4 do
        reset()
        failureKind, setFailures[failedAt] = kind, true
        result(false, "binding_error", Input.AssignStepKey("X", OTHER, 1))
        check(state() == "P,S|X,Y|U" and persisted == state(),
            "each failed assignment write restores both actions and their exact order: " .. kind .. failedAt)
    end
    reset()
    failureKind, setFailures[1] = kind, true
    result(false, "binding_error", Input.ClearStepKey())
    check(state() == "P,S|X,Y|U" and persisted == state(), "a failed primary clear restores both keys: " .. kind)
end
for _, kind in ipairs({"false", "throw", "after"}) do
    for _, clear in ipairs({false, true}) do
        reset()
        failureKind, saveFailures[1] = kind, true
        if clear then result(false, "binding_error", Input.ClearStepKey())
        else result(false, "binding_error", Input.AssignStepKey("X", OTHER, 1)) end
        check(state() == "P,S|X,Y|U" and persisted == state(), "failed saving restores and persists the original order")
    end
end
for _, kind in ipairs({"false", "throw"}) do
    for failedRollback = 1, 8 do
        reset()
        failureKind, setFailures[3], setFailures[3 + failedRollback] = kind, true, true
        result(false, "binding_restore_failed", Input.AssignStepKey("X", OTHER, 1))
        check(persisted == "P,S|X,Y|U" and saves == 0,
            "failed rollback never persists incomplete restoration: " .. kind .. failedRollback)
    end
    reset()
    failureKind, saveFailures[1], saveFailures[2] = kind, true, true
    result(false, "binding_restore_failed", Input.AssignStepKey("X", OTHER, 1))
end
reset()
failReadback = true
result(false, "binding_error", Input.AssignStepKey("X", OTHER, 1))
check(state() == "P,S|X,Y|U" and persisted == state(), "secret readback triggers restoration")
reset()
skipWrite = 1
result(false, "binding_error", Input.AssignStepKey("X", OTHER, 1))
check(state() == "P,S|X,Y|U" and persisted == state(), "successful native returns still require exact readback")

for _, api in ipairs({"GetBindingKey", "GetBindingAction", "GetCurrentBindingSet", "InCombatLockdown", "SetBinding", "SaveBindings"}) do
    local original = _G[api]
    for _, replacement in ipairs({false, secretValue, function() error("native API error") end,
        function() return secretValue end}) do
        reset()
        _G[api] = replacement
        local ok, why = Input.AssignStepKey("N", "", 1)
        check(not ok and (why == "binding_error" or why == "binding_restore_failed"), "unavailable or untrusted API fails: " .. api)
        check(persisted == "P,S|X,Y|U", "API failure cannot persist a destructive partial result: " .. api)
    end
    _G[api] = original
end
reset()
local originalContext = C_KeyBindings
for _, replacement in ipairs({false, secretValue, {}, {GetBindingContextForAction = function() error("context failed") end},
    {GetBindingContextForAction = function() return secretValue end},
    setmetatable({}, {__index = function() error("context lookup failed") end})}) do
    C_KeyBindings = replacement
    first, second, reason = Input.GetStepKeys()
    check(first == nil and second == nil and reason == "binding_error", "invalid context cannot read bindings")
    result(false, "binding_error", Input.AssignStepKey("N", "", 1))
end
C_KeyBindings = originalContext
local originalKeys = GetBindingKey
for _, pair in ipairs({{secretValue}, {""}, {false}, {"P", "P"}, {[2] = "S"}}) do
    GetBindingKey = function() return pair[1], pair[2] end
    first, second, reason = Input.GetStepKeys()
    check(first == nil and second == nil and reason == "binding_error", "untrusted or inconsistent native key pairs fail closed")
end
GetBindingKey = originalKeys
bindingContext = nil
result(true, "binding_saved", Input.AssignStepKey("N", "", 1))
check(state() == "N,S|X,Y|U", "a native nil context is passed through without inventing one")

print("input: " .. checks .. " checks passed")
