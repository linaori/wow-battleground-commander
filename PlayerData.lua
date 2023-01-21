local Private, _, Namespace = {}, ...

Namespace.PlayerData = {}

local ReadyCheckState = Namespace.Utils.ReadyCheckState
local BattlegroundStatus = Namespace.Utils.BattlegroundStatus
local RoleCheckStatus = Namespace.Utils.RoleCheckStatus
local GroupType = Namespace.Utils.GroupType
local GetGroupType = Namespace.Utils.GetGroupType
local GetRealUnitName = Namespace.Utils.GetRealUnitName
local GetTime = GetTime
local UnitIsPlayer = UnitIsPlayer
local UnitExists = UnitExists
local UnitFactionGroup = UnitFactionGroup
local UnitGUID = UnitGUID
local UnitIsConnected = UnitIsConnected
local UnitIsGroupLeader = UnitIsGroupLeader
local UnitIsGroupAssistant = UnitIsGroupAssistant
local UnitIsMercenary = UnitIsMercenary
local UnitClass = UnitClass
local GetClassColor = C_ClassColor.GetClassColor
local UNKNOWNOBJECT = UNKNOWNOBJECT
local pairs = pairs
local unpack = unpack
local sort = table.sort

local PlayerDataTargets = {
    solo = {'player'},
    party = { 'player', 'party1', 'party2', 'party3', 'party4' },
    raid = {
        'raid1', 'raid2', 'raid3', 'raid4', 'raid5', 'raid6', 'raid7', 'raid8', 'raid9', 'raid10',
        'raid11', 'raid12', 'raid13', 'raid14', 'raid15', 'raid16', 'raid17', 'raid18', 'raid19', 'raid20',
        'raid21', 'raid22', 'raid23', 'raid24', 'raid25', 'raid26', 'raid27', 'raid28', 'raid29', 'raid30',
        'raid31', 'raid32', 'raid33', 'raid34', 'raid35', 'raid36', 'raid37', 'raid38', 'raid39', 'raid40',
        'player', 'party1', 'party2', 'party3', 'party4',
    },
}

local Role = {
    Member = 'Member',
    Assist = 'Assist',
    Leader = 'Leader',
}

local Faction = {
    Horde = 'Horde',
    Alliance = 'Alliance',
    Neutral = 'Neutral',
    None = nil,
}

Namespace.PlayerData.Role = Role
Namespace.PlayerData.Faction = Faction

local Memory = {
    lastKnownGroupType = GetGroupType(),
    AllPlayerData = {
        --[GUID] = {
        --    guid = GUID,
        --    name = playerName,
        --    units = {[1] => first unit, first unit = true, second unit = true},
        --    class = 'CLASS',
        --    readyState = ReadyCheckState,
        --    roleCheckStatus = RoleCheckStatus,
        --    deserterExpiry = -1,
        --    mercenaryExpiry = -1,
        --    addonVersion = 'whatever remote version',
        --    autoAcceptRole = boolean,
        --    battlegroundStatus = BattlegroundStatus
        --    isConnected = boolean,
        --    role = Role,
        --    class = "CLASS",
        --    classColor = ColorMixin,
        --},
    },
    LeaderData = nil, -- the AllPlayerData table for just the leader
    AssistData = {
        -- the AllPlayerData table for all assists
    },
    MembersData = {
        -- the AllPlayerData table for all normal members
    },
    UnitPlayerData = {
        -- same as AllPlayerData, but only those with <unit><index> like raid6
    },
    UnitIndexPlayerData = {
        -- same as UnitPlayerData but indexed per unit, which means duplicate tables may exist
    },
    OnUpdateCallbacks = {
        -- [name] => function,
    },
    OnRoleChangeCallbacks = {
        -- [name] => function
    },
}

--- per name callback with the argument being Memory.AllPlayerData (generated by RebuildPlayerData())
--- @param callback
function Namespace.PlayerData.RegisterOnUpdate(listenerName, callback)
    Memory.OnUpdateCallbacks[listenerName] = callback
end

--- per name callback with the arguments being {PlayerData, oldRole, newRole} (generated by RebuildPlayerData())
--- @param callback
function Namespace.PlayerData.RegisterOnRoleChange(listenerName, callback)
    Memory.OnRoleChangeCallbacks[listenerName] = callback
end

function Private.RefreshMissingData(data)
    local unit = data.units.primary
    if not unit then return end

    if data.name == UNKNOWNOBJECT or not data.name then
        data.name = GetRealUnitName(unit)
    end

    if not data.class or not data.classColor then
        local _, class = UnitClass(data.units.primary)
        data.class = class
        data.classColor = class and GetClassColor(class) or nil
    end
end

Namespace.PlayerData.RefreshMissingData = Private.RefreshMissingData

function Namespace.PlayerData.GetGroupLeaderData()
    return Memory.LeaderData
end

function Private.GetUnitListForCurrentGroupType()
    local groupType = GetGroupType()
    if groupType == GroupType.InstanceRaid or groupType == GroupType.Raid then
        return PlayerDataTargets.raid
    end

    if groupType == GroupType.InstanceParty or groupType == GroupType.Party then
        return PlayerDataTargets.party
    end

    return PlayerDataTargets.solo
end

function Namespace.PlayerData.RebuildRoleData()
    local groupType = GetGroupType()
    if Memory.lastKnownGroupType ~= groupType then
        Memory.LeaderData = nil
        Memory.AssistData = {}
        Memory.MembersData = {}
    end

    Memory.lastKnownGroupType = groupType

    local roleChangeEvents = {}
    local eventIndex = 0
    local leader
    local assists = {}
    local members = {}
    for guid, playerData in pairs(Memory.UnitPlayerData) do
        local unit = playerData.units.primary
        if UnitIsGroupLeader(unit) then
            playerData.role = Role.Leader
            leader = playerData
        elseif UnitIsGroupAssistant(unit) then
            playerData.role = Role.Assist
            assists[guid] = playerData
        else
            playerData.role = Role.Member
            members[guid] = playerData
        end

        local oldRole
        if Memory.LeaderData == playerData then
            oldRole = Role.Leader
        elseif Memory.AssistData[guid] then
            oldRole = Role.Assist
        elseif Memory.MembersData[guid] then
            oldRole = Role.Member
        end

        if oldRole ~= playerData.role then
            eventIndex = eventIndex + 1
            roleChangeEvents[eventIndex] = {playerData, oldRole, playerData.role}
        end
    end

    for _, eventData in pairs(roleChangeEvents) do
        local playerData, oldRole, newRole = unpack(eventData)
        for _, callback in pairs(Memory.OnRoleChangeCallbacks) do
            callback(playerData, oldRole, newRole)
        end
    end

    Memory.LeaderData = leader
    Memory.AssistData = assists
    Memory.MembersData = members
end

function Namespace.PlayerData.RebuildPlayerData()
    for _, data in pairs(Memory.AllPlayerData) do
        data.units = {}
    end

    local unitIndexedPlayerData = {}
    local unitPlayerData = {}
    local currentTime = GetTime()
    for _, unit in pairs(Private.GetUnitListForCurrentGroupType()) do
        if UnitExists(unit) and UnitIsPlayer(unit) then
            local dataIndex = UnitGUID(unit)
            local data = Memory.AllPlayerData[dataIndex]
            if not data then
                local _, class = UnitClass(unit)
                data = {
                    guid = dataIndex,
                    name = GetRealUnitName(unit),
                    readyState = ReadyCheckState.Nothing,
                    deserterExpiry = -1,
                    mercenaryExpiry = UnitIsMercenary(unit) and currentTime + 99999 or -1,
                    units = { primary = unit, [unit] = true },
                    battlegroundStatus = BattlegroundStatus.Nothing,
                    roleCheckStatus = RoleCheckStatus.Nothing,
                    isConnected = UnitIsConnected(unit),
                    role = UnitIsGroupLeader(unit) and Role.Leader or UnitIsGroupAssistant(unit) and Role.Assist or Role.Member,
                    class = class,
                    classColor = class and GetClassColor(class) or nil,
                    faction = UnitFactionGroup(unit)
                }

                Memory.AllPlayerData[dataIndex] = data
            else
                -- add every unit, but only recollect all information once
                data.units[unit] = true

                if not data.units.primary then
                    if (data.mercenaryExpiry == -1 or data.mercenaryExpiry < currentTime) and UnitIsMercenary(unit) then
                        data.mercenaryExpiry = currentTime + 99999
                    end
                    data.role = UnitIsGroupLeader(unit) and Role.Leader or UnitIsGroupAssistant(unit) and Role.Assist or Role.Member
                    data.units.primary = unit
                    data.name = GetRealUnitName(unit)
                    data.isConnected = UnitIsConnected(unit)
                end
            end

            unitPlayerData[dataIndex] = data
            unitIndexedPlayerData[unit] = data
        end
    end

    sort(unitPlayerData)

    Memory.UnitIndexPlayerData = unitIndexedPlayerData
    Memory.UnitPlayerData = unitPlayerData

    for _, callback in pairs(Memory.OnUpdateCallbacks) do
        callback(unitPlayerData)
    end

    Namespace.PlayerData.RebuildRoleData()

    return unitPlayerData
end

function Namespace.PlayerData.GetPlayerDataByUnit(unit)
    local data = Memory.UnitIndexPlayerData[unit]
    if data then return data end

    -- fallback to getting the name of the unit in case of weird scenarios
    -- where "target" or "nameplate1" is sent
    local name = GetRealUnitName(unit)
    if not name then return nil end

    return Namespace.PlayerData.GetPlayerDataByName(name)
end

function Namespace.PlayerData.GetPlayerDataByName(name)
    for _, data in pairs(Memory.AllPlayerData) do
        Private.RefreshMissingData(data)

        if data.name == name then
            return data
        end
    end

    return nil
end

function Namespace.PlayerData.ForEachPlayerData(callback)
    for guid, playerData in pairs(Memory.AllPlayerData) do
        if callback(playerData, guid) == false then return end
    end
end

function Namespace.PlayerData.ForEachUnitData(callback)
    for guid, playerData in pairs(Memory.UnitPlayerData) do
        if callback(playerData, guid) == false then return end
    end
end
