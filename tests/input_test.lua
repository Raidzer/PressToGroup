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

print("input: " .. checks .. " checks passed")
