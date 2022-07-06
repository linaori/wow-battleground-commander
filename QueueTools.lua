local _G, ModuleName, Private, AddonName, Namespace = _G, 'QueueTools', {}, ...
local Module = Namespace.Addon:NewModule(ModuleName, 'AceEvent-3.0', 'AceTimer-3.0', 'AceComm-3.0')
local L = Namespace.Libs.AceLocale:GetLocale(AddonName)
local ScrollingTable = Namespace.Libs.ScrollingTable

Namespace.QueueTools = Module

local PackData = Namespace.Communication.PackData
local UnpackData = Namespace.Communication.UnpackData
local GetMessageDestination = Namespace.Communication.GetMessageDestination
local GroupType = Namespace.Utils.GroupType
local GetGroupType = Namespace.Utils.GetGroupType
local DoReadyCheck = DoReadyCheck
local UnitIsGroupLeader = UnitIsGroupLeader
local UnitIsGroupAssistant = UnitIsGroupAssistant
local GetInstanceInfo = GetInstanceInfo
local CreateFrame = CreateFrame
local PlaySound = PlaySound
local CharacterPanelOpenSound = SOUNDKIT.IG_CHARACTER_INFO_OPEN
local CharacterPanelCloseSound = SOUNDKIT.IG_CHARACTER_INFO_CLOSE
local GetPlayerAuraBySpellID = GetPlayerAuraBySpellID
local GetNumGroupMembers = GetNumGroupMembers
local GetBattlefieldStatus = GetBattlefieldStatus
local GetUnitName = GetUnitName
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local UnitClass = UnitClass
local UnitDebuff = UnitDebuff
local UnitIsPlayer = UnitIsPlayer
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local GetTime = GetTime
local SendChatMessage = SendChatMessage
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local DEBUFF_MAX_DISPLAY = DEBUFF_MAX_DISPLAY
local UNKNOWNOBJECT = UNKNOWNOBJECT
local TimeDiff = Namespace.Utils.TimeDiff
local max = math.max
local ceil = math.ceil
local format = string.format
local pairs = pairs
local print = Namespace.Debug.print

local SpellIds = {
    DeserterDebuff = 26013,
    MercenaryContractBuff = 193475,
}

local ReadyCheckState = {
    Nothing = 0,
    Waiting = 1,
    Ready = 2,
    Declined = 3,
}

local tableStructure = {
    {
        name = '',
        width = 25,
    },
    {
        name = '',
        width = 110,
        align = 'LEFT',
    },
    {
        name = ' ' .. L['Merc'],
        width = 55,
        align = 'CENTER',
    },
    {
        name = ' ' .. L['Deserter'],
        width = 55,
        align = 'CENTER',
    },
    {
        name = ' ' .. L['Ready'],
        width = 55,
        align = 'CENTER',
    }
}

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

local Config = {
    tableRefreshSeconds = 10,
    readyCheckStateResetSeconds = 10,
}

local Memory = {
    currentZoneId = nil,

    -- seems like you can't do a second ready check for about 5~6 seconds, even if the "finished" event is faster
    readyCheckGracePeriod = 6,

    -- keep track of last ready check and when it finished to update the button and icons properly
    lastReadyCheckTime = 0,
    lastReadyCheckDuration = 0,
    readyCheckButtonTicker = nil,
    readyCheckClearTimeout = nil,

    -- used to track whether or not the queue is paused
    queueStatusTicker = nil,
    queueStatus = {
        --[0] = suspendedQueue boolean,
    },

    playerTableCache = {},
    playerData = {
        --[GUID] = {
        --    name = playerName,
        --    units = {[1] => first unit, first unit = true, second unit = true},
        --    class = 'CLASS',
        --    readyState = ReadyCheckState.Nothing,
        --    deserterExpiry = -1,
        --    mercenaryExpiry = -1,
        --    hasAddon = false,
        --},
    },

    -- the data that should be send next mercenary sync event
    sendMercenaryDataPayloadBuffer = nil,
}

local CommunicationEvent = {
    NotifyMercenaryDuration = 'Bgc:notifyMerc',
    ReadyCheckHeartbeat = 'Bgc:rchb',
}

local ColorList = {
    Bad = { r = 1.0, g = 0, b = 0, a = 1.0 },
    Good = { r = 0, g = 1.0, b = 0, a = 1.0 },
    Warning = { r = 1.0, g = 1.0, b = 0, a = 1.0 },
    UnknownClass = { r = 0.7, g = 0.7, b = 0.7, a = 1.0 },
}

function Private.DoSendMercenaryDuration()
    if Memory.sendMercenaryDataPayloadBuffer == nil then return end

    local channel, player = GetMessageDestination()
    local payload = PackData(Memory.sendMercenaryDataPayloadBuffer)

    Module:SendCommMessage(CommunicationEvent.NotifyMercenaryDuration, payload, channel, player)
    Memory.sendMercenaryDataPayloadBuffer = nil
end

function Private.ScheduleSendMercenaryDuration()
    local expirationTime = Private.GetPlayerAuraExpiryTime(SpellIds.MercenaryContractBuff)
    local shouldSchedule = Memory.sendMercenaryDataPayloadBuffer == nil
    local remaining = expirationTime == -1 and -1 or expirationTime - GetTime()
    Memory.sendMercenaryDataPayloadBuffer = { remaining = remaining }

    if not shouldSchedule then return end
    Module:ScheduleTimer(Private.DoSendMercenaryDuration, ceil(GetNumGroupMembers() * 0.1))
end

function Private.GetPlayerDataByUnit(unit)
    for _, data in pairs(Memory.playerData) do
        if data.units[unit] then return data end
    end

    return nil
end

function Private.GetPlayerDataByName(name)
    for _, data in pairs(Memory.playerData) do
        if data.units.primary and (data.name == UNKNOWNOBJECT or data.name == nil) then
            data.name = GetUnitName(data.units.primary, true)
        end

        if data.name == name then
            return data
        end
    end

    return nil
end

function Private.IsLeaderOrAssistant(unit)
    return UnitIsGroupLeader(unit) or UnitIsGroupAssistant(unit)
end

function Private.CanDoReadyCheck()
    if Memory.lastReadyCheckTime + Memory.lastReadyCheckDuration > GetTime() then
        return false
    end

    if not Private.IsLeaderOrAssistant('player') then
        return false
    end

    local _, instanceType = GetInstanceInfo()

    return instanceType ~= 'pvp' and instanceType ~= 'arena'
end

function Private.TriggerDeserterUpdate(data)
    if data.deserterExpiry > 0 and data.deserterExpiry <= GetTime() then
        data.deserterExpiry = -1
    end

    if data.deserterExpiry > -1 then
        -- only re-check if the player doesn't have it already
        return
    end

    for i = 1, DEBUFF_MAX_DISPLAY do
        local _, _, _, _, _, expirationTime, _, _, _, spellId = UnitDebuff(data.units.primary, i)
        if spellId == SpellIds.DeserterDebuff then
            data.deserterExpiry = expirationTime

            return
        end
    end
end

function Private.CreateTableRow(index, data)
    local nameColumn = {
        value = function(tableData, _, realRow, column)
            local columnData = tableData[realRow].cols[column]

            if data.name == UNKNOWNOBJECT or data.name == nil then
                -- try to update the name as it wasn't available on initial check
                data.name = GetUnitName(data.units.primary, true)
            end

            local name, color
            if data.name == UNKNOWNOBJECT then
                name = '...'
                color = ColorList.UnknownClass
            else
                local _, class = UnitClass(data.units.primary)
                name = data.name

                color = class and RAID_CLASS_COLORS[class] or ColorList.UnknownClass
            end

            columnData.color = { r = color.r, g = color.g, b = color.b, a = color.a }
            return name
        end,
    }

    local mercenaryColumn = {
        value = function(tableData, _, realRow, column)
            local columnData = tableData[realRow].cols[column]
            if not data.hasAddon then
                columnData.color = ColorList.Warning
                return '?'
            end

            columnData.color = nil
            local timeDiff = TimeDiff(data.mercenaryExpiry, GetTime())
            if timeDiff.fullSeconds < 1 then
                return L['no']
            end

            if timeDiff.fullMinutes < 4 then
                columnData.color = ColorList.Bad
            elseif timeDiff.fullMinutes < 9 then
                columnData.color = ColorList.Warning
            end

            return format('%dm', timeDiff.fullMinutes)
        end,
    }

    local deserterColumn = {
        value = function(tableData, _, realRow, column)
            local columnData = tableData[realRow].cols[column]
            Private.TriggerDeserterUpdate(data)

            local timeDiff = TimeDiff(data.deserterExpiry, GetTime())
            if timeDiff.fullSeconds < 1 then
                columnData.color = ColorList.Good
                return L['no']
            end

            columnData.color = ColorList.Bad
            return format('%dm', timeDiff.fullMinutes)
        end,
    }

    local readyCheckColumn = {
        value = function(tableData, _, realRow, column)
            local columnData = tableData[realRow].cols[column]
            local readyState = data.readyState;
            if readyState == ReadyCheckState.Waiting then
                columnData.color = nil
                return '...'
            end

            if readyState == ReadyCheckState.Declined then
                columnData.color = ColorList.Bad
                return L['no']
            end

            if readyState == ReadyCheckState.Ready then
                columnData.color = ColorList.Good
                return L['yes']
            end

            columnData.color = nil
            return '-'
        end,
    }

    return { cols = {
        {value = index},
        nameColumn,
        mercenaryColumn,
        deserterColumn,
        readyCheckColumn,
    }}
end

function Private.RefreshPlayerTable()
    if not _G.BgcQueueFrame or not Namespace.Database.profile.QueueTools.showGroupQueueFrame then return end

    _G.BgcQueueFrame.PlayerTable:Refresh()
end

function Private.UpdatePlayerTableData()
    if not _G.BgcQueueFrame or not Namespace.Database.profile.QueueTools.showGroupQueueFrame then return end

    _G.BgcQueueFrame.PlayerTable:SetData(Memory.playerTableCache)
end

function Private.GetPlayerAuraExpiryTime(auraId)
    local _, _, _, _, _, expirationTime = GetPlayerAuraBySpellID(auraId)

    return expirationTime ~= nil and expirationTime or -1
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

function Private.EnterZone()
    local _, instanceType, _, _, _, _, _, currentZoneId = GetInstanceInfo()
    if instanceType == 'none' then currentZoneId = 0 end
    Memory.currentZoneId = currentZoneId
end

function Private.TriggerStateUpdates()
    if _G.BgcReadyCheckButton then _G.BgcReadyCheckButton:SetEnabled(Private.CanDoReadyCheck()) end

    for _, data in pairs(Memory.playerData) do
        data.units = {}
    end

    local tableCache = {}
    for index, unit in pairs(Private.GetUnitListForCurrentGroupType()) do
        if UnitExists(unit) and UnitIsPlayer(unit) then
            local dataIndex = UnitGUID(unit)
            local data = Memory.playerData[dataIndex]
            if not data then
                data = {
                    name = GetUnitName(unit, true),
                    readyState = ReadyCheckState.Nothing,
                    deserterExpiry = -1,
                    mercenaryExpiry = -1,
                    units = {primary = unit, [unit] = true},
                }

                Memory.playerData[dataIndex] = data
                tableCache[index] = Private.CreateTableRow(index, data)
            else
                if not data.units.primary then
                    data.units.primary = unit
                    tableCache[index] = Private.CreateTableRow(index, data)
                end

                data.units[unit] = true
            end
        end
    end

    Memory.playerTableCache = tableCache
    Private.ScheduleSendMercenaryDuration()
    Private.UpdatePlayerTableData()
end

function Private.UpdateQueueFrameVisibility(newVisibility)
    if not _G.BgcQueueFrame then return end

    if newVisibility then
        _G.BgcQueueFrame:Show()
    else
        _G.BgcQueueFrame:Hide()
    end

    Private.UpdatePlayerTableData()
end

function Private.InitializeBattlegroundModeCheckbox()
    local PVPUIFrame = _G.PVPUIFrame
    local checkbox = CreateFrame('CheckButton', 'BgcBattlegroundModeCheckbox', PVPUIFrame, 'UICheckButtonTemplate')
    checkbox:SetPoint('BOTTOMRIGHT', _G.PVEFrame, 'BOTTOMRIGHT', -2, 2)
    checkbox:SetSize(24, 24)
    checkbox:SetChecked(Namespace.Database.profile.QueueTools.showGroupQueueFrame)
    checkbox:SetScript('OnClick', function (self)
        local newVisibility = self:GetChecked()

        Namespace.Database.profile.QueueTools.showGroupQueueFrame = newVisibility
        Private.UpdateQueueFrameVisibility(newVisibility)
        if newVisibility then
            PlaySound(CharacterPanelOpenSound)
        else
            PlaySound(CharacterPanelCloseSound)
        end
    end)
    checkbox:Show()

    PVPUIFrame.BattlegroundModeCheckbox = checkbox

    local text = checkbox:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
    text:SetText(L['Group Mode'])
    text:SetPoint('RIGHT', checkbox, 'LEFT')
    text:SetWordWrap(false)

    checkbox.Text = text
end

function Private.OnNotifyMercenaryDuration(_, text, _, sender)
    local payload = UnpackData(text);
    if not payload or payload.remaining == nil then return end

    local data = Private.GetPlayerDataByName(sender)
    if not data then return print('OnNotifyMercenaryDuration', 'Missing player for sender', sender) end

    data.hasAddon = true
    data.mercenaryExpiry = payload.remaining + GetTime()

    Private.RefreshPlayerTable()
end

function Private.OnReadyCheckHeartbeat()
    _G.ReadyCheckFrameYesButton:Click()
end

function Module:OnInitialize()
    self:RegisterEvent('ADDON_LOADED')
end

function Module:OnEnable()
    self:RegisterEvent('READY_CHECK')
    self:RegisterEvent('READY_CHECK_CONFIRM')
    self:RegisterEvent('READY_CHECK_FINISHED')
    self:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
    self:RegisterEvent('UPDATE_BATTLEFIELD_STATUS')

    self:RegisterEvent('GROUP_ROSTER_UPDATE')
    self:RegisterEvent('PLAYER_ENTERING_WORLD')

    self:RegisterComm(CommunicationEvent.NotifyMercenaryDuration, Private.OnNotifyMercenaryDuration)
    self:RegisterComm(CommunicationEvent.ReadyCheckHeartbeat, Private.OnReadyCheckHeartbeat)

    Namespace.Database.RegisterCallback(self, 'OnProfileChanged', 'RefreshConfig')
    Namespace.Database.RegisterCallback(self, 'OnProfileCopied', 'RefreshConfig')
    Namespace.Database.RegisterCallback(self, 'OnProfileReset', 'RefreshConfig')

    self:RefreshConfig()
end

function Module:GROUP_ROSTER_UPDATE()
    Private.TriggerStateUpdates()
end

function Module:PLAYER_ENTERING_WORLD()
    Private.EnterZone()
    Private.TriggerStateUpdates()
end

function Module:UPDATE_BATTLEFIELD_STATUS(_, id)
    local config = Namespace.Database.profile.QueueTools.InspectQueue

    if Memory.currentZoneId ~= 0 then return end
    if GetNumGroupMembers() == 0 then return end
    if config.onlyAsLeader and not Private.IsLeaderOrAssistant('player') then return end

    local status, mapName, _, _, suspendedQueue = GetBattlefieldStatus(id)
    if status == 'queued' then
        local previousSuspendedQueue = Memory.queueStatus[id]
        if suspendedQueue == true and previousSuspendedQueue == false  then
            local channel
            if config.sendPausedMessage then
                channel = GetMessageDestination()
                local message = format(Namespace.Meta.chatTemplate, format(L['Queue paused for for %s'], mapName))
                SendChatMessage(message, channel)
            end

            if config.doReadyCheck and Private.CanDoReadyCheck() then
                DoReadyCheck()
                channel = channel or GetMessageDestination()

                self:SendCommMessage(CommunicationEvent.ReadyCheckHeartbeat, 'ping', channel)
            end
        elseif config.sendResumedMessage and suspendedQueue == false and previousSuspendedQueue == true then
            local channel = GetMessageDestination()
            local message = format(Namespace.Meta.chatTemplate, format(L['Queue resumed for %s'], mapName))
            SendChatMessage(message, channel)
        end

        Memory.queueStatus[id] = suspendedQueue
    else
        Memory.queueStatus[id] = nil
    end
end

function Module:RefreshConfig()
    Private.UpdateQueueFrameVisibility(Namespace.Database.profile.QueueTools.showGroupQueueFrame)
end

function Module:COMBAT_LOG_EVENT_UNFILTERED()
    local _, subEvent, _, sourceGUID, _, _, _, _, _, _, _, spellId  = CombatLogGetCurrentEventInfo()
    if spellId ~= SpellIds.MercenaryContractBuff or sourceGUID ~= UnitGUID('player') then return end

    if subEvent == 'SPELL_AURA_APPLIED' or subEvent == 'SPELL_AURA_REFRESH' or subEvent == 'SPELL_AURA_REMOVED' then
        Private.ScheduleSendMercenaryDuration()
    end
end

function Module:READY_CHECK(_, initiatedByName, duration)
    Memory.lastReadyCheckTime = GetTime()
    Memory.lastReadyCheckDuration = duration

    for _, data in pairs(Memory.playerData) do
        data.readyState = ReadyCheckState.Waiting
    end

    local initiatedByData = Private.GetPlayerDataByName(initiatedByName)
    if initiatedByData then
        initiatedByData.readyState = ReadyCheckState.Ready
    else
        print(_, 'Missing player for initiatedByName', initiatedByName)
    end

    Memory.readyCheckButtonTicker = self:ScheduleRepeatingTimer(function ()
        local readyCheckButton = _G.BgcReadyCheckButton
        if not readyCheckButton then return end

        readyCheckButton:SetEnabled(Private.CanDoReadyCheck())
        local timeLeft = max(0, ceil(Memory.lastReadyCheckTime + Memory.lastReadyCheckDuration - GetTime()))
        if timeLeft > 0 then
            return readyCheckButton:SetText(L['Ready Check'] .. ' ' .. timeLeft)
        end

        readyCheckButton:SetText(L['Ready Check'])
        Module:CancelTimer(Memory.readyCheckButtonTicker)
        Memory.readyCheckButtonTicker = nil
    end, 0.1)

    Private.TriggerStateUpdates()
    Private.RefreshPlayerTable()
end

function Module:READY_CHECK_CONFIRM(_, unit, ready)
    -- ready check can give "target" instead as unit if you have a party/raid member selected during the confirmation
    local data = unit == 'target' and Private.GetPlayerDataByName(GetUnitName('target', true)) or Private.GetPlayerDataByUnit(unit)
    if not data then return print(_, 'Missing unit', unit) end

    data.readyState = ready and ReadyCheckState.Ready or ReadyCheckState.Declined

    Private.RefreshPlayerTable()
end

function Module:READY_CHECK_FINISHED()
    if Memory.lastReadyCheckTime + Memory.readyCheckGracePeriod >= GetTime() then
        -- finish was before grace period, should still count down until this is passed
        Memory.lastReadyCheckDuration = Memory.readyCheckGracePeriod
    else
        Memory.lastReadyCheckDuration = 0
    end

    for _, data in pairs(Memory.playerData) do
        if data.readyState == ReadyCheckState.Waiting then
            -- in case of expired ready check no confirmation means declined
            data.readyState = ReadyCheckState.Declined
        end
    end

    self:ScheduleTimer(function ()
        -- new ready check has been initiated, don't do anything anymore
        if Memory.lastReadyCheckTime + Memory.lastReadyCheckDuration > GetTime() then return end

        for _, player in pairs(Memory.playerData) do
            player.readyState = ReadyCheckState.Nothing
        end

        Private.RefreshPlayerTable()
        Memory.readyCheckClearTimeout = nil
    end, Config.readyCheckStateResetSeconds)

    Private.RefreshPlayerTable()
end

function Private.InitializeGroupQueueFrame()
    local PVPUIFrame = _G.PVPUIFrame

    local queueFrame = CreateFrame('Frame', 'BgcQueueFrame', PVPUIFrame, 'ButtonFrameTemplate')
    queueFrame:SetSize(350, PVPUIFrame:GetHeight() - 2)
    queueFrame:SetPoint('TOPLEFT', PVPUIFrame, 'TOPRIGHT', 11, 0)
    queueFrame:SetPoint('BOTTOMLEFT', PVPUIFrame, 'BOTTOMRIGHT', 11, 0)
    queueFrame.TitleText:SetText(L['Group Information'])
    queueFrame.CloseButton:SetScript('OnClick', function ()
        Namespace.Database.profile.QueueTools.showGroupQueueFrame = false
        Private.UpdateQueueFrameVisibility(false)
        _G.BgcBattlegroundModeCheckbox:SetChecked(false)
        PlaySound(CharacterPanelCloseSound)
    end)
    queueFrame:SetPortraitToAsset([[Interface\LFGFrame\UI-LFR-PORTRAIT]]);
    PVPUIFrame.QueueFrame = queueFrame

    local playerTable = ScrollingTable:CreateST(tableStructure, 14, 24, nil, queueFrame)
    playerTable.frame:SetBackdropColor(0, 0, 0, 0)
    playerTable.frame:SetBackdropBorderColor(0, 0, 0, 0)
    playerTable.frame:SetPoint('TOPRIGHT', -4, -58)
    playerTable:RegisterEvents({}, true)

    playerTable.frame:SetScript('OnShow', function (self)
        self.refreshTimer = Module:ScheduleRepeatingTimer(Private.RefreshPlayerTable, Config.tableRefreshSeconds)
    end)
    playerTable.frame:SetScript('OnHide', function (self)
        Module:CancelTimer(self.refreshTimer)
    end)

    queueFrame.PlayerTable = playerTable

    local readyCheckButton = CreateFrame('Button', 'BgcReadyCheckButton', queueFrame, 'UIPanelButtonTemplate')
    readyCheckButton:SetText(L['Ready Check'])
    readyCheckButton:SetPoint('BOTTOM', 0, 3)
    readyCheckButton:SetSize(120, 22)
    readyCheckButton:SetScript('OnClick', function () DoReadyCheck() end)

    queueFrame.ReadyCheckButton = readyCheckButton

    Private.TriggerStateUpdates()
end

function Module:ADDON_LOADED(_, addonName)
    if addonName == 'Blizzard_PVPUI' then
        Private.InitializeBattlegroundModeCheckbox()
        Private.InitializeGroupQueueFrame()
        _G.PVPUIFrame:HookScript('OnShow', function ()
            Private.UpdateQueueFrameVisibility(Namespace.Database.profile.QueueTools.showGroupQueueFrame)
        end)
        self:UnregisterEvent('ADDON_LOADED')
    end
end

function Module:SetQueueInspectionSetting(setting, value)
    local config = Namespace.Database.profile.QueueTools.InspectQueue
    config[setting] = value
end

function Module:GetQueueInspectionSetting(setting)
    return Namespace.Database.profile.QueueTools.InspectQueue[setting]
end
