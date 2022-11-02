local _, Namespace = ...

Namespace.Utils = {}

local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
local GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID
local UnitIsGroupLeader = UnitIsGroupLeader
local UnitIsGroupAssistant = UnitIsGroupAssistant
local UnitNameUnmodified = UnitNameUnmodified
local LE_PARTY_CATEGORY_HOME = LE_PARTY_CATEGORY_HOME
local LE_PARTY_CATEGORY_INSTANCE = LE_PARTY_CATEGORY_INSTANCE
local floor = math.floor
local ceil = math.ceil
local format = string.format

Namespace.Utils.GroupType = {
    Solo = 1,
    Party = 2,
    Raid = 3,
    InstanceParty = 4,
    InstanceRaid = 5,
}

local GroupType = Namespace.Utils.GroupType

Namespace.Utils.ReadyCheckState = {
    Nothing = 0,
    Waiting = 1,
    Ready = 2,
    Declined = 3,
}

Namespace.Utils.BattlegroundStatus = {
    Nothing = 0,
    Waiting = 1,
    Declined = 2,
    Entered = 3,
}

Namespace.Utils.RoleCheckStatus = {
    Nothing = 0,
    Waiting = 1,
    Ready = 2,
}

Namespace.Utils.RaidMarker = {
    YellowStar = '{rt1}',
    OrangeCircle = '{rt2}',
    PurpleDiamond = '{rt3}',
    GreenTriangle = '{rt4}',
    SilverMoon = '{rt5}',
    BlueSquare = '{rt6}',
    RedCross = '{rt7}',
    WhiteSkull = '{rt8}',
}

function Namespace.Utils.TimeDiff(a, b)
    local secondsDiff = a - b
    local fullSeconds = secondsDiff

    local rounder = secondsDiff > 0 and floor or ceil
    local minutesDiff = rounder(secondsDiff / 60)
    local hoursDiff = rounder(minutesDiff / 60)

    local fullHours, fullMinutes = hoursDiff, minutesDiff
    minutesDiff = minutesDiff - hoursDiff * 60
    secondsDiff = secondsDiff - (minutesDiff * 60 + hoursDiff * 60 * 60)

    return {
        fullSeconds = fullSeconds,
        fullMinutes = fullMinutes,
        fullHours = fullHours,
        seconds = secondsDiff,
        minutes = minutesDiff,
        hours = hoursDiff,
        format = function()
            if hoursDiff > 0 then
                return format('%dh %dm %ds', hoursDiff, minutesDiff, secondsDiff)
            end

            if minutesDiff > 0 then
                return format('%dm %ds', minutesDiff, secondsDiff)
            end

            return format('%ds', secondsDiff)
        end,
    }
end

function Namespace.Utils.GetGroupType()
    if IsInRaid() then
        return (not IsInRaid(LE_PARTY_CATEGORY_HOME) and IsInRaid(LE_PARTY_CATEGORY_INSTANCE)) and GroupType.InstanceRaid or GroupType.Raid
    end

    if IsInGroup() then
        return (not IsInGroup(LE_PARTY_CATEGORY_HOME) and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) and GroupType.InstanceParty or GroupType.Party
    end

    return GroupType.solo
end

--- Same as GetGroupType, but enforces it to detect your non-instanced group type
function Namespace.Utils.GetLocalGroupType()
    if IsInRaid(LE_PARTY_CATEGORY_HOME) then return GroupType.Raid end
    if IsInGroup(LE_PARTY_CATEGORY_HOME) then return GroupType.Party end

    return GroupType.solo
end

function Namespace.Utils.IsLeaderOrAssistant(unit)
    return UnitIsGroupLeader(unit) or UnitIsGroupAssistant(unit)
end

function Namespace.Utils.GetRealUnitName(unit)
    local name, realm = UnitNameUnmodified(unit)
    if realm == nil then return name end

    return name .. '-' .. realm
end

function Namespace.Utils.GetPlayerAuraExpiration(spellId)
    local aura = GetPlayerAuraBySpellID(spellId)

    return aura and aura.expirationTime or nil
end
