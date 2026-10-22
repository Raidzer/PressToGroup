local PTG = {}
local source = arg and arg[0] and arg[0]:gsub("\\", "/") or "tests/filters_test.lua"
local root = source:match("^(.*)/tests/[^/]+$") or "."
assert(loadfile(root .. "/Filters.lua"))("PressToGroup", PTG)
local F = PTG.Filters
local checks = 0

local player = { role = "HEALER", class = "PRIEST", specID = 257 }
local function group()
    return {
        id = 1, identity = "Party-1", name = "Example", activityID = 100,
        age = 10, leaderRating = 3000, numMembers = 3,
        isDelisted = false, hasSelf = false, eligible = true, complete = true,
        roleCounts = { TANK = 1, HEALER = 0, DAMAGER = 2 },
        roleRemaining = { TANK = 0, HEALER = 1, DAMAGER = 1 },
        members = {
            { class = "WARRIOR", specID = 73, role = "TANK" },
            { class = "MAGE", specID = 63, role = "DAMAGER" },
            { class = "WARLOCK", specID = 267, role = "DAMAGER" },
        },
    }
end

local function eligible(snapshot, settings, expected, reason, who)
    local actual, actualReason = F.Eligible(snapshot, settings or {}, who or player)
    assert(actual == expected, "eligibility: " .. tostring(actualReason))
    assert(actualReason == reason, "reason: expected " .. tostring(reason) .. ", got " .. tostring(actualReason))
    checks = checks + 1
end

local function roleFull(snapshot, role, expected)
    assert(F.IsRoleFull(snapshot, role) == expected, "actual composition for role " .. tostring(role))
    checks = checks + 1
end

roleFull(group(), "HEALER", false)
roleFull(group(), "TANK", true)
roleFull(group(), "DAMAGER", false)
roleFull(nil, "HEALER", nil)
roleFull(group(), "NONE", nil)
roleFull(group(), nil, nil)
local composition = {numMembers = 5, roleCounts = {TANK = 1, HEALER = 1, DAMAGER = 3}, eligible = false}
for _, role in ipairs({"TANK", "HEALER", "DAMAGER"}) do roleFull(composition, role, true) end
for _, value in ipairs({0, -1, 0.5, math.huge, 0 / 0, "3"}) do
    local invalid = group()
    invalid.numMembers = value
    roleFull(invalid, "HEALER", nil)
end
for _, value in ipairs({-1, 0.5, math.huge, 0 / 0, "0", 2}) do
    local invalid = group()
    invalid.roleCounts.HEALER = value
    roleFull(invalid, "HEALER", nil)
end
for role, value in pairs({TANK = 2, HEALER = 2, DAMAGER = 4}) do
    local invalid = group()
    invalid.roleCounts[role] = value
    roleFull(invalid, "HEALER", nil)
    invalid.roleCounts[role] = nil
    roleFull(invalid, "HEALER", nil)
end
roleFull({numMembers = 3}, "HEALER", nil)
roleFull({numMembers = 4, roleCounts = group().roleCounts}, "HEALER", nil)

eligible(group(), {}, true)
eligible(group(), { role = "HEALER", minRating = 3000, dungeons = { [100] = true },
    requireTank = true, requireLust = true, requireBrez = true }, true)
eligible(group(), { minRating = 3001 }, false, "rating")
eligible(group(), { dungeons = { [101] = true } }, false, "dungeon")
eligible(group(), { dungeons = { [101] = false } }, false, "dungeon")
eligible(group(), { dungeons = {} }, false, "dungeon")
eligible(group(), { dungeons = { [100] = false, [101] = true } }, false, "dungeon")
eligible(group(), { role = "NONE" }, false, "unknown_role")
eligible(group(), { role = "TANK" }, false, "role_full")

local snapshot = group()
snapshot.roleCounts.HEALER, snapshot.roleCounts.DAMAGER = 1, 1
eligible(snapshot, {}, false, "role_full")
eligible(snapshot, { role = "DAMAGER" }, true)

snapshot = group()
snapshot.numMembers, snapshot.roleCounts.DAMAGER = 4, 3
eligible(snapshot, { role = "DAMAGER" }, false, "role_full")
eligible(snapshot, { role = "HEALER" }, true)
snapshot.numMembers, snapshot.roleCounts.HEALER = 5, 1
eligible(snapshot, {}, false, "full")

snapshot = group()
snapshot.roleCounts.TANK, snapshot.roleCounts.DAMAGER = 0, 3
eligible(snapshot, { requireTank = true }, false, "no_tank")
eligible(snapshot, { role = "TANK", requireTank = true }, true,
    nil, { role = "TANK", class = "WARRIOR", specID = 73 })

snapshot = group()
snapshot.members[2] = { class = "ROGUE", specID = 260, role = "DAMAGER" }
eligible(snapshot, { requireLust = true }, true)
snapshot.roleRemaining.DAMAGER = 0
eligible(snapshot, { requireLust = true }, false, "no_lust")
eligible(snapshot, { requireLust = true }, true,
    nil, { role = "HEALER", class = "SHAMAN", specID = 264 })
snapshot.complete = false
eligible(snapshot, { requireLust = true }, false, "unknown_members")
eligible(snapshot, { requireLust = true }, true,
    nil, { role = "HEALER", class = "SHAMAN", specID = 264 })
eligible(snapshot, {}, true)
snapshot.members[2] = { class = "MAGE", role = "DAMAGER" }
eligible(snapshot, { requireLust = true }, true)

snapshot = group()
snapshot.members[3] = { class = "ROGUE", specID = 260, role = "DAMAGER" }
eligible(snapshot, { requireBrez = true }, true)
snapshot.roleRemaining.DAMAGER = 0
eligible(snapshot, { requireBrez = true }, false, "no_brez")
eligible(snapshot, { requireBrez = true }, true,
    nil, { role = "HEALER", class = "DRUID", specID = 105 })
snapshot.members[3] = {}
eligible(snapshot, { requireBrez = true }, false, "unknown_members")
snapshot.members = nil
eligible(snapshot, { requireLust = true }, false, "unknown_members")

local function plainGroup(counts, remaining)
    local result = group()
    result.numMembers, result.members, result.roleCounts, result.roleRemaining = 0, {}, {}, {}
    for _, role in ipairs({"TANK", "HEALER", "DAMAGER"}) do
        result.roleCounts[role], result.roleRemaining[role] = counts[role], remaining[role]
        result.numMembers = result.numMembers + counts[role]
        for _ = 1, counts[role] do
            result.members[#result.members + 1] = {class = role == "TANK" and "WARRIOR" or role == "HEALER" and "PRIEST" or "ROGUE", role = role}
        end
    end
    return result
end

local recruitmentCases = {
    {role = "TANK", counts = {TANK = 0, HEALER = 1, DAMAGER = 1}, remaining = {TANK = 1, HEALER = 0, DAMAGER = 2}},
    {role = "HEALER", counts = {TANK = 1, HEALER = 0, DAMAGER = 1}, remaining = {TANK = 0, HEALER = 1, DAMAGER = 2}},
    {role = "DAMAGER", counts = {TANK = 1, HEALER = 0, DAMAGER = 1}, remaining = {TANK = 0, HEALER = 1, DAMAGER = 2}},
}
eligible(plainGroup({TANK = 1, HEALER = 0, DAMAGER = 0}, {TANK = 0, HEALER = 1, DAMAGER = 3}),
    {requireLust = true, requireBrez = true}, true)
for _, case in ipairs(recruitmentCases) do
    snapshot = plainGroup(case.counts, case.remaining)
    local settings = {role = case.role, requireLust = true, requireBrez = true}
    eligible(snapshot, settings, true)
    snapshot.roleRemaining.DAMAGER = 1
    eligible(snapshot, settings, false, "no_brez")
    eligible(snapshot, {role = case.role, requireLust = true}, true)
    eligible(snapshot, {role = case.role, requireBrez = true}, true)
    snapshot.roleRemaining = {TANK = 0, HEALER = 0, DAMAGER = 0}
    snapshot.roleRemaining[case.role] = 1
    eligible(snapshot, settings, false, "no_lust")
    eligible(snapshot, {role = case.role, requireBrez = true}, false, "no_brez")
    snapshot.complete = false
    eligible(snapshot, settings, false, "unknown_members")
end

snapshot = plainGroup({TANK = 0, HEALER = 0, DAMAGER = 2}, {TANK = 1, HEALER = 1, DAMAGER = 1})
eligible(snapshot, {role = "DAMAGER", requireLust = true, requireBrez = true}, true)
snapshot.roleCounts.HEALER, snapshot.numMembers = 1, 3
snapshot.members[3] = {class = "PRIEST", role = "HEALER"}
snapshot.roleRemaining.HEALER = 0
eligible(snapshot, {role = "DAMAGER", requireLust = true}, false, "no_lust")
eligible(snapshot, {role = "DAMAGER", requireBrez = true}, true)

for _, role in ipairs({"TANK", "HEALER", "DAMAGER"}) do
    local counts = {TANK = 1, HEALER = 1, DAMAGER = 3}
    counts[role] = counts[role] - 1
    local remaining = {TANK = 0, HEALER = 0, DAMAGER = 0}
    remaining[role] = 1
    snapshot = plainGroup(counts, remaining)
    eligible(snapshot, {role = role, requireLust = true}, false, "no_lust")
    eligible(snapshot, {role = role, requireBrez = true}, false, "no_brez")
end

for _, invalid in ipairs({{value = nil}, {value = "1"}, {value = false}, {value = {}}, {value = -1},
    {value = 0.5}, {value = math.huge}, {value = -math.huge}, {value = 0 / 0}, {value = 4}, {value = 0}}) do
    for _, case in ipairs(recruitmentCases) do
        snapshot = plainGroup(case.counts, case.remaining)
        snapshot.roleRemaining[case.role] = invalid.value
        eligible(snapshot, {role = case.role, requireLust = true}, false, "unknown_group")
    end
end
snapshot.complete = false
eligible(snapshot, {role = "DAMAGER", requireLust = true}, false, "unknown_group")

for _, invalid in ipairs({{value = nil}, {value = "0"}, {value = false}, {value = {}}, {value = -1},
    {value = 0.5}, {value = math.huge}, {value = -math.huge}, {value = 0 / 0}, {value = 2}}) do
    snapshot = plainGroup({TANK = 0, HEALER = 0, DAMAGER = 1}, {TANK = 1, HEALER = 1, DAMAGER = 2})
    snapshot.roleRemaining.TANK = invalid.value
    eligible(snapshot, {requireLust = true, requireBrez = true}, true)
    snapshot.complete, snapshot.members[1] = false, {}
    eligible(snapshot, {requireLust = true, requireBrez = true}, true)
    snapshot.complete, snapshot.members[1], snapshot.roleRemaining.DAMAGER = true, {class = "ROGUE"}, 1
    eligible(snapshot, {requireLust = true, requireBrez = true}, false, "unknown_group")
    snapshot.complete = false
    eligible(snapshot, {requireLust = true, requireBrez = true}, false, "unknown_members")
end

snapshot = plainGroup({TANK = 1, HEALER = 0, DAMAGER = 2}, {TANK = 0, HEALER = 1, DAMAGER = 0})
snapshot.roleRemaining.TANK = nil
eligible(snapshot, {requireLust = true}, false, "unknown_group")
snapshot.roleRemaining = {TANK = 0, HEALER = 1, DAMAGER = 2}
eligible(snapshot, {requireLust = true}, false, "unknown_group")

for _, invalid in ipairs({{value = nil}, {value = "unknown"}, {value = false}, {value = {}}}) do
    snapshot = group()
    snapshot.roleRemaining = invalid.value
    eligible(snapshot, {requireLust = true, requireBrez = true}, true)
    snapshot.members, snapshot.complete = nil, false
    eligible(snapshot, {requireLust = true}, true, nil, {role = "HEALER", class = "SHAMAN", specID = 264})
    eligible(snapshot, {requireBrez = true}, true, nil, {role = "HEALER", class = "DRUID", specID = 105})
    eligible(snapshot, {requireLust = true}, false, "unknown_group")
    eligible(snapshot, {}, true)
end

for _, case in ipairs({{role = "TANK", class = "DEATHKNIGHT", specID = 250},
    {role = "HEALER", class = "DRUID", specID = 105}, {role = "DAMAGER", class = "WARLOCK", specID = 267}}) do
    local counts = {TANK = 1, HEALER = 1, DAMAGER = 3}
    counts[case.role] = counts[case.role] - 1
    snapshot = plainGroup(counts, {TANK = 0, HEALER = 0, DAMAGER = 0})
    snapshot.roleRemaining = nil
    eligible(snapshot, {role = case.role, requireBrez = true}, true, nil, case)
end
snapshot = plainGroup({TANK = 0, HEALER = 0, DAMAGER = 3}, {TANK = 1, HEALER = 1, DAMAGER = 0})
eligible(snapshot, {requireLust = true, requireBrez = true}, true, nil, {role = "HEALER", class = "SHAMAN", specID = 264})
snapshot.members[1] = {class = "MAGE", role = "DAMAGER"}
eligible(snapshot, {requireLust = true, requireBrez = true}, true)

for _, field in ipairs({ "id", "identity", "activityID", "age", "leaderRating", "numMembers",
    "isDelisted", "hasSelf", "eligible", "roleCounts" }) do
    snapshot = group()
    snapshot[field] = nil
    eligible(snapshot, {}, false, "unknown_group")
end
for _, value in ipairs({ -1, 0.5, math.huge }) do
    snapshot = group()
    snapshot.roleCounts.TANK = value
    eligible(snapshot, {}, false, "unknown_group")
end
snapshot = group()
snapshot.roleCounts.HEALER = nil
eligible(snapshot, {}, false, "unknown_group")
snapshot = group()
snapshot.numMembers = 4
eligible(snapshot, {}, false, "unknown_group")
for field, reason in pairs({ isDelisted = "delisted", hasSelf = "has_self" }) do
    snapshot = group()
    snapshot[field] = true
    eligible(snapshot, {}, false, reason)
end
snapshot = group()
snapshot.eligible = false
eligible(snapshot, {}, false, "player_requirements")

for _, class in ipairs({ "SHAMAN", "MAGE", "HUNTER", "EVOKER" }) do
    local _, lust = F.Capabilities(class)
    assert(lust, class .. " lust")
    checks = checks + 1
end
for _, class in ipairs({ "DRUID", "DEATHKNIGHT", "PALADIN", "WARLOCK" }) do
    local _, _, brez = F.Capabilities(class)
    assert(brez, class .. " brez")
    checks = checks + 1
end
for specID, class in pairs({ [73] = "WARRIOR", [66] = "PALADIN", [250] = "DEATHKNIGHT",
    [104] = "DRUID", [268] = "MONK", [581] = "DEMONHUNTER" }) do
    assert(F.Capabilities(class, specID), class .. " tank")
    assert(not F.Capabilities("PRIEST", specID), "spec must match class")
    checks = checks + 1
end
local tank, lust, brez = F.Capabilities(nil, nil)
assert(tank == false and lust == false and brez == false, "unknown capabilities")
checks = checks + 1

local groups = {
    { id = 4, age = 20, leaderRating = 4000 },
    { id = 3, age = 5, leaderRating = 3000 },
    { id = 2, age = 5, leaderRating = 3500 },
    { id = 1, age = 5, leaderRating = 3500 },
}
assert(F.Sort(groups) == groups, "sort mutates its input")
for index, id in ipairs({ 1, 2, 3, 4 }) do
    assert(groups[index].id == id, "newest, then rating, then id")
    checks = checks + 1
end
print("filters: " .. checks .. " checks passed")
