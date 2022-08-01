local Private, _, Namespace = {}, ...

Namespace.PlayerData = {}

local ReadyCheckState = Namespace.Utils.ReadyCheckState
local BattlegroundStatus = Namespace.Utils.BattlegroundStatus
local GroupType = Namespace.Utils.GroupType
local GetGroupType = Namespace.Utils.GetGroupType
local GetRealUnitName = Namespace.Utils.GetRealUnitName
local UnitIsPlayer = UnitIsPlayer
local UnitGUID = UnitGUID
local UnitExists = UnitExists
local UNKNOWNOBJECT = UNKNOWNOBJECT
local pairs = pairs

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

local Memory = {
    AllPlayerData = {
        --[GUID] = {
        --    name = playerName,
        --    units = {[1] => first unit, first unit = true, second unit = true},
        --    class = 'CLASS',
        --    readyState = ReadyCheckState,
        --    deserterExpiry = -1,
        --    mercenaryExpiry = nil,
        --    addonVersion = 'whatever remote version',
        --    autoAcceptRole = false,
        --    battlegroundStatus = BattlegroundStatus
        --},
    },
    UnitPlayerData = {
        -- same as AllPlayerData, but only those with sequentially indexed units
    }
}

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

function Namespace.PlayerData.RebuildPlayerData()
    for _, data in pairs(Memory.AllPlayerData) do
        data.units = {}
    end

    local unitPlayerData = {}
    for _, unit in pairs(Private.GetUnitListForCurrentGroupType()) do
        if UnitExists(unit) and UnitIsPlayer(unit) then
            local dataIndex = UnitGUID(unit)
            local data = Memory.AllPlayerData[dataIndex]
            if not data then
                data = {
                    name = GetRealUnitName(unit),
                    readyState = ReadyCheckState.Nothing,
                    deserterExpiry = -1,
                    units = {primary = unit, [unit] = true},
                    battlegroundStatus = BattlegroundStatus.Nothing,
                }

                Memory.AllPlayerData[dataIndex] = data
            else
                -- always refresh the name whenever possible
                data.name = GetRealUnitName(unit)

                if not data.units.primary then
                    data.units.primary = unit
                end

                data.units[unit] = true
            end

            if not unitPlayerData[dataIndex] then
                unitPlayerData[dataIndex] = data
            end
        end
    end

    Memory.UnitPlayerData = unitPlayerData

    return unitPlayerData
end

function Namespace.PlayerData.GetPlayerDataByUnit(unit)
    for _, data in pairs(Memory.UnitPlayerData) do
        if data.units[unit] then return data end
    end

    -- fallback to getting the name of the unit in case of weird scenarios
    -- where "target" or "nameplate1" is sent
    local name = GetRealUnitName(unit)
    if not name then return nil end

    return Namespace.PlayerData.GetPlayerDataByName(name)
end

function Namespace.PlayerData.GetPlayerDataByName(name)
    for _, data in pairs(Memory.AllPlayerData) do
        if data.units.primary and (data.name == UNKNOWNOBJECT or data.name == nil) then
            data.name = GetRealUnitName(data.units.primary)
        end

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
