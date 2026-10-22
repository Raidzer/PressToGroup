local _, PTG = ...
local Input = {}
PTG.Input = Input

local ACTION_BARS = {
    Action = true,
    MultiBarBottomLeft = true, MultiBarBottomRight = true,
    MultiBarLeft = true, MultiBarRight = true,
    MultiBar5 = true, MultiBar6 = true, MultiBar7 = true,
    OverrideActionBar = true, ExtraAction = true,
}

local function secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local STEP = "PRESSTOGROUP_STEP"

local function native(func, ...)
    if secret(func) or type(func) ~= "function" then return false end
    local ok, first, second = pcall(func, ...)
    if not ok or secret(first) or secret(second) then return false end
    return true, first, second
end

local function validKey(key)
    return not secret(key) and type(key) == "string" and key ~= ""
end

local function context()
    if secret(C_KeyBindings) or type(C_KeyBindings) ~= "table" then return false end
    local ok, method = pcall(function() return C_KeyBindings.GetBindingContextForAction end)
    if not ok then return false end
    return native(method, STEP)
end

local function keys(action, bindingContext)
    local ok, first, second = native(GetBindingKey, action, nil, bindingContext)
    if not ok or (first ~= nil and not validKey(first)) or (second ~= nil and not validKey(second))
        or (second ~= nil and (first == nil or first == second)) then return false end
    return true, first, second
end

local function actionAndSet(key, bindingContext)
    local ok, action = native(GetBindingAction, key, nil, bindingContext)
    if not ok or type(action) ~= "string" then return nil, "binding_error" end
    local read, set = native(GetCurrentBindingSet)
    if not read or (set ~= 1 and set ~= 2) then return nil, "binding_error" end
    return action, set
end

function Input.GetStepKeys()
    local ok, bindingContext = context()
    if not ok then return nil, nil, "binding_error" end
    local read, first, second = keys(STEP, bindingContext)
    if not read then return nil, nil, "binding_error" end
    return first, second
end

function Input.GetStepKeyAction(key)
    if not validKey(key) then return nil, "binding_error" end
    local ok, bindingContext = context()
    if not ok then return nil, "binding_error" end
    return actionAndSet(key, bindingContext)
end

local function editStepKey(key, expectedAction, expectedSet, clear)
    local ok, combat = native(InCombatLockdown)
    if not ok or type(combat) ~= "boolean" then return false, "binding_error" end
    if combat then return false, "binding_combat" end
    local available, bindingContext = context()
    if not available then return false, "binding_error" end
    local read, first, second = keys(STEP, bindingContext)
    if not read then return false, "binding_error" end
    if clear then
        if not first then return true, "binding_cleared" end
        key = first
    elseif not validKey(key) or secret(expectedAction) or type(expectedAction) ~= "string"
        or secret(expectedSet) or (expectedSet ~= 1 and expectedSet ~= 2) then
        return false, "binding_error"
    end
    local currentAction, set = actionAndSet(key, bindingContext)
    if not currentAction then return false, set end
    if not clear and (currentAction ~= expectedAction or set ~= expectedSet) then return false, "binding_changed" end
    if not clear and (key == first or key == second) then return true, "binding_already" end
    if secret(SetBinding) or type(SetBinding) ~= "function" or secret(SaveBindings)
        or type(SaveBindings) ~= "function" then return false, "binding_error" end

    local snapshots = {{action = STEP, before = {first, second}, after = clear and {second} or {key, second}}}
    if currentAction ~= "" and currentAction ~= STEP then
        local found, otherFirst, otherSecond = keys(currentAction, bindingContext)
        if not found or (key ~= otherFirst and key ~= otherSecond) then return false, "binding_error" end
        local remaining = otherFirst
        if key == otherFirst then remaining = otherSecond end
        snapshots[2] = {action = currentAction, before = {otherFirst, otherSecond}, after = {remaining}}
    end
    local touched = {[key] = true}
    for _, snapshot in ipairs(snapshots) do
        for _, oldKey in ipairs(snapshot.before) do touched[oldKey] = true end
    end
    local function matches(which)
        for _, snapshot in ipairs(snapshots) do
            local found, one, two = keys(snapshot.action, bindingContext)
            local expected = snapshot[which]
            if not found or one ~= expected[1] or two ~= expected[2] then return false end
        end
        for changedKey in pairs(touched) do
            local expected = ""
            for _, snapshot in ipairs(snapshots) do
                for _, boundKey in ipairs(snapshot[which]) do
                    if changedKey == boundKey then expected = snapshot.action end
                end
            end
            local found, action = native(GetBindingAction, changedKey, nil, bindingContext)
            if not found or action ~= expected then return false end
        end
        return true
    end
    if not matches("before") then return false, "binding_error" end
    local function bind(boundKey, action)
        local success, result = native(SetBinding, boundKey, action, bindingContext)
        return success and result == true
    end
    local function save()
        local readSet, currentSet = native(GetCurrentBindingSet)
        if not readSet or currentSet ~= set then return false end
        local success, result = native(SaveBindings, currentSet)
        return success and (result == nil or result == true)
    end
    local function restore()
        local readSet, currentSet = native(GetCurrentBindingSet)
        if not readSet or currentSet ~= set then return false end
        local restored = true
        for changedKey in pairs(touched) do
            if not bind(changedKey, nil) then restored = false end
        end
        for _, snapshot in ipairs(snapshots) do
            for _, oldKey in ipairs(snapshot.before) do
                if not bind(oldKey, snapshot.action) then restored = false end
            end
        end
        return restored and matches("before") and save() and matches("before")
    end

    local applied = not first or bind(first, nil)
    if not clear then
        if applied and second then applied = bind(second, nil) end
        if applied then applied = bind(key, STEP) end
        if applied and second then applied = bind(second, STEP) end
    end
    if not applied or not matches("after") or not save() or not matches("after") then
        return false, restore() and "binding_error" or "binding_restore_failed"
    end
    return true, clear and "binding_cleared" or "binding_saved"
end

function Input.AssignStepKey(key, expectedAction, expectedSet)
    return editStepKey(key, expectedAction, expectedSet, false)
end

function Input.ClearStepKey()
    return editStepKey(nil, nil, nil, true)
end

function Input.IsBinding()
    if secret(PTG.bindingCapture) or PTG.bindingCapture then return true end
    for _, item in ipairs({{QuickKeybindFrame, "IsShown"}, {KeybindListener, "IsListening"}}) do
        local object = item[1]
        if secret(object) then return true end
        if object ~= nil then
            if type(object) ~= "table" and type(object) ~= "userdata" then return true end
            local ok, method = pcall(function() return object[item[2]] end)
            if not ok or secret(method) then return true end
            if method == nil then
                if item[2] == "IsListening" then return true end
            else
                local success, active = native(method, object)
                if not success or type(active) ~= "boolean" or active then return true end
            end
        end
    end
    return false
end

function Input.Accept(button, inputButton, down, isKeyPress, isSecureAction)
    if secret(button) or secret(inputButton) or secret(down)
        or secret(isKeyPress) or secret(isSecureAction) then return false end
    if isSecureAction ~= true or inputButton ~= "LeftButton" or type(down) ~= "boolean"
        or type(isKeyPress) ~= "boolean" then return false end
    if type(button) ~= "table" and type(button) ~= "userdata" then return false end

    local getName, action = button.GetName, button.action
    if secret(getName) or secret(action) then return false end
    if type(getName) ~= "function" or type(action) ~= "number"
        or action <= 0 or action >= math.huge or action % 1 ~= 0 then return false end
    local name = button:GetName()
    if secret(name) or type(name) ~= "string" then return false end
    if not ACTION_BARS[name:match("^(.-)Button%d+$")] then return false end

    if Input.IsBinding() then return false end

    if not isKeyPress then return down == false end
    local getAttribute = button.GetAttribute
    if secret(getAttribute) or type(getAttribute) ~= "function"
        or type(SecureActionButton_ShouldUseOnKeyDown) ~= "function" then return false end
    local useOnKeyDown = SecureActionButton_ShouldUseOnKeyDown(button)
    if secret(useOnKeyDown) then return false end
    local hold = button:GetAttribute("pressAndHoldAction")
    if secret(hold) then return false end
    local useOnDown = (useOnKeyDown or hold) and true or false
    return down == useOnDown
end
