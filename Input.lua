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

    local quickbind = QuickKeybindFrame
    if secret(quickbind) then return false end
    if quickbind then
        local isShown = quickbind.IsShown
        if secret(isShown) then return false end
        if type(isShown) == "function" then
            local shown = quickbind:IsShown()
            if secret(shown) or shown then return false end
        end
    end

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
