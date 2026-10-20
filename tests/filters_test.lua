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

eligible(group(), {}, true)
eligible(group(), { role = "HEALER", minRating = 3000, dungeons = { [100] = true },
    requireTank = true, requireLust = true, requireBrez = true }, true)
eligible(group(), { minRating = 3001 }, false, "rating")
eligible(group(), { dungeons = { [101] = true } }, false, "dungeon")
eligible(group(), { dungeons = { [101] = false } }, true)
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
eligible(snapshot, { requireBrez = true }, false, "no_brez")
eligible(snapshot, { requireBrez = true }, true,
    nil, { role = "HEALER", class = "DRUID", specID = 105 })
snapshot.members[3] = {}
eligible(snapshot, { requireBrez = true }, false, "unknown_members")
snapshot.members = nil
eligible(snapshot, { requireLust = true }, false, "unknown_members")

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
