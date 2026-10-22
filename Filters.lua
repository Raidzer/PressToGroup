local _, PTG = ...
local F = {}
PTG.Filters = F

local CAPACITY = { TANK = 1, HEALER = 1, DAMAGER = 3 }
local TANK_SPECS = {
    [73] = "WARRIOR", [66] = "PALADIN", [250] = "DEATHKNIGHT",
    [104] = "DRUID", [268] = "MONK", [581] = "DEMONHUNTER",
}
local LUST_CLASSES = { SHAMAN = true, MAGE = true, HUNTER = true, EVOKER = true }
local BREZ_CLASSES = { DRUID = true, DEATHKNIGHT = true, WARLOCK = true, PALADIN = true }

-- Class capabilities do not confirm cooldowns, selected talents, or the active pet.
function F.Capabilities(classFile, specID)
    return classFile ~= nil and TANK_SPECS[specID] == classFile,
        LUST_CLASSES[classFile] == true, BREZ_CLASSES[classFile] == true
end

local function number(value)
    return type(value) == "number" and value >= 0 and value < math.huge
end

local function count(value)
    return number(value) and value % 1 == 0
end

local function composition(group)
    if type(group) ~= "table" or not count(group.numMembers)
        or group.numMembers == 0 or group.numMembers > 5 then return nil end
    local counts = group.roleCounts
    if type(counts) ~= "table" then return nil end
    local total = 0
    for memberRole, capacity in pairs(CAPACITY) do
        if not count(counts[memberRole]) or counts[memberRole] > capacity then return nil end
        total = total + counts[memberRole]
    end
    if total ~= group.numMembers then return nil end
    return counts
end

function F.IsRoleFull(group, role)
    if not CAPACITY[role] then return nil end
    local counts = composition(group)
    if not counts then return nil end
    return counts[role] >= CAPACITY[role]
end

function F.IsPartyFull(group, size)
    if not count(size) or size < 2 or size > 4 or not composition(group) then return nil end
    return group.numMembers + size > 5
end

function F.Eligible(group, settings, player)
    settings, player = settings or {}, player or {}
    if type(group) ~= "table" then return false, "unknown_group" end
    if group.isDelisted == true then return false, "delisted" end
    if group.hasSelf == true then return false, "has_self" end
    if group.eligible == false then return false, "player_requirements" end
    if group.isDelisted ~= false or group.hasSelf ~= false or group.eligible ~= true
        or not count(group.id) or group.id == 0
        or type(group.identity) ~= "string" or group.identity == ""
        or not count(group.activityID) or group.activityID == 0
        or not number(group.age) or not number(group.leaderRating)
        or not count(group.numMembers) or group.numMembers == 0 then
        return false, "unknown_group"
    end
    if group.numMembers >= 5 then return false, "full" end

    local role = settings.role or player.role
    if not CAPACITY[role] then return false, "unknown_role" end
    local counts = composition(group)
    if not counts then return false, "unknown_group" end
    local company, size, roles = player.company, 1, {[role] = 1}
    if company ~= nil then
        if type(company) ~= "table" then return false, "unknown_group" end
        if company.size == 1 then
            company = nil
        else
            size, roles = company.size, company.roles
            if not count(size) or size < 2 or size > 4 or type(roles) ~= "table" then
                return false, "unknown_group"
            end
            local total = 0
            for memberRole, capacity in pairs(CAPACITY) do
                if not count(roles[memberRole]) or roles[memberRole] > capacity then
                    return false, "unknown_group"
                end
                total = total + roles[memberRole]
            end
            if total ~= size then return false, "unknown_group" end
            if group.numMembers + size > 5 then return false, "full" end
        end
    end
    for memberRole, capacity in pairs(CAPACITY) do
        local joining = roles[memberRole] or 0
        if counts[memberRole] + joining > capacity then return false, "role_full" end
        if company and joining > 0 then
            local available = type(group.roleRemaining) == "table" and group.roleRemaining[memberRole]
            if not count(available) or available > capacity - counts[memberRole] then
                return false, "unknown_group"
            end
            if available < joining then return false, "role_full" end
        end
    end

    if settings.dungeons and settings.dungeons[group.activityID] ~= true then return false, "dungeon" end
    local minRating = settings.minRating or 0
    if not number(minRating) then return false, "unknown_rating" end
    if group.leaderRating < minRating then return false, "rating" end
    if settings.requireTank and counts.TANK == 0 and (roles.TANK or 0) == 0 then
        return false, "no_tank"
    end

    if settings.requireLust or settings.requireBrez then
        local _, lust, brez = F.Capabilities(player.class, player.specID)
        local complete = group.complete == true and type(group.members) == "table"
        if company then
            lust, brez = false, false
            for index = 1, size do
                local member = type(company.members) == "table" and company.members[index]
                if type(member) == "table" and type(member.class) == "string" and member.class ~= "" then
                    local _, memberLust, memberBrez = F.Capabilities(member.class, member.specID)
                    lust, brez = lust or memberLust, brez or memberBrez
                else
                    complete = false
                end
            end
        end
        for index = 1, group.numMembers do
            local member = group.members and group.members[index]
            if type(member) == "table" and type(member.class) == "string" and member.class ~= "" then
                local _, memberLust, memberBrez = F.Capabilities(member.class, member.specID)
                lust, brez = lust or memberLust, brez or memberBrez
            else
                complete = false
            end
        end
        local needLust, needBrez = settings.requireLust and not lust, settings.requireBrez and not brez
        if needLust or needBrez then
            local remaining = group.roleRemaining
            if type(remaining) ~= "table" then return false, "unknown_group" end
            local slots, lustSlots, knownSlots = 0, 0, true
            for memberRole, capacity in pairs(CAPACITY) do
                local available = remaining[memberRole]
                local joining = roles[memberRole] or 0
                if count(available) and available <= capacity - counts[memberRole]
                    and available >= joining then
                    available = available - joining
                    slots = slots + available
                    if memberRole ~= "TANK" then lustSlots = lustSlots + available end
                else
                    if joining > 0 then return false, "unknown_group" end
                    knownSlots = false
                end
            end
            -- No class in our capability model supplies both effects, so each needs its own slot.
            local needed = (needLust and 1 or 0) + (needBrez and 1 or 0)
            if slots >= needed and (not needLust or lustSlots > 0) then return true end
            if not complete then return false, "unknown_members" end
            if not knownSlots then return false, "unknown_group" end
            if needLust and lustSlots == 0 then return false, "no_lust" end
            return false, "no_brez"
        end
    end
    return true
end

function F.Sort(groups)
    table.sort(groups, function(a, b)
        local ageA, ageB = a.age or math.huge, b.age or math.huge
        if ageA ~= ageB then return ageA < ageB end
        local ratingA, ratingB = a.leaderRating or 0, b.leaderRating or 0
        if ratingA ~= ratingB then return ratingA > ratingB end
        return a.id < b.id
    end)
    return groups
end
