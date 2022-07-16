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
local GetLFGRoleUpdate = GetLFGRoleUpdate
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

local QueueStatus = {
    Queued = 'queued',
    Confirm = 'confirm',
    Active = 'active',
    None = 'none',
    Error = 'error',
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
    readyCheckHeartbeatTimout = nil,

    queueState = {
        --[0] = {
        --    status = QueueStatus,
        --    queueSuspended = boolean
        --},
    },
    queueStateChangeListeners = {},

    playerTableCache = {},
    playerData = {
        --[GUID] = {
        --    name = playerName,
        --    units = {[1] => first unit, first unit = true, second unit = true},
        --    class = 'CLASS',
        --    readyState = ReadyCheckState.Nothing,
        --    deserterExpiry = -1,
        --    mercenaryExpiry = -1,
        --    addonVersion = 'whatever remote version',
        --},
    },

    -- the data that should be send next data sync event
    sendDurationDataPayloadBuffer = nil,
}

local CommunicationEvent = {
    SyncData = 'Bgc:syncData',
    NotifyMercDuration = 'Bgc:notifyMerc', -- replaced by Bgc:syncData
    ReadyCheckHeartbeat = 'Bgc:rchb',
}

local ColorList = {
    Bad = { r = 1.0, g = 0, b = 0, a = 1.0 },
    Good = { r = 0, g = 1.0, b = 0, a = 1.0 },
    Warning = { r = 1.0, g = 1.0, b = 0, a = 1.0 },
    UnknownClass = { r = 0.7, g = 0.7, b = 0.7, a = 1.0 },
}

function Private.SendSyncData()
    if Memory.sendDurationDataPayloadBuffer == nil then return end

    local channel, player = GetMessageDestination()
    local payload = PackData(Memory.sendDurationDataPayloadBuffer)

    Module:SendCommMessage(CommunicationEvent.NotifyMercDuration, payload, channel, player) -- remove in future
    Module:SendCommMessage(CommunicationEvent.SyncData, payload, channel, player)
    Memory.sendDurationDataPayloadBuffer = nil
end

function Private.ScheduleSendSyncData()
    Memory.sendDurationDataPayloadBuffer = {
        addonVersion = Namespace.Meta.version,
        remainingMercenary = Private.GetRemainingAuraTime(SpellIds.MercenaryContractBuff),
        remainingDeserter = Private.GetRemainingAuraTime(SpellIds.DeserterDebuff),
    }

    if not Memory.sendDurationDataPayloadBuffer == nil then return end

    Module:ScheduleTimer(Private.SendSyncData, ceil(GetNumGroupMembers() * 0.1))
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
        -- this ensures the "guess" here is a fallback vs what
        -- the addon comms say.
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
            if not data.addonVersion then
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
            local readyState = data.readyState
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
    }, originalData = data }
end

function Private.RefreshPlayerTable()
    if not _G.BgcQueueFrame or not Namespace.Database.profile.QueueTools.showGroupQueueFrame then return end

    _G.BgcQueueFrame.PlayerTable:Refresh()
end

function Private.UpdatePlayerTableData()
    if not _G.BgcQueueFrame or not Namespace.Database.profile.QueueTools.showGroupQueueFrame then return end

    _G.BgcQueueFrame.PlayerTable:SetData(Memory.playerTableCache)
end

function Private.GetRemainingAuraTime(auraId)
    local _, _, _, _, _, expirationTime = GetPlayerAuraBySpellID(auraId)

    if not expirationTime then return -1 end

    return expirationTime - GetTime()
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
    Private.ScheduleSendSyncData()
    Private.UpdatePlayerTableData()
end

function Private.UpdateQueueFrameVisibility(newVisibility)
    if not _G.BgcQueueFrame then return end

    _G.BgcQueueFrame:SetShown(newVisibility)

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

function Private.OnSyncData(_, text, _, sender)
    local payload = UnpackData(text)
    if not payload then return end

    local data = Private.GetPlayerDataByName(sender)
    if not data then return print('OnSyncData', 'Missing player for sender', sender) end

    local time = GetTime()

    -- renamed after 1.4.0, remove "remaining" index in the future
    data.mercenaryExpiry = (payload.remainingMercenary or payload.remaining) + time
    if payload.remainingDeserter then
        -- added after 1.4.0, remove if check in the future
        data.deserterExpiry = payload.remainingDeserter + time
    end

    data.addonVersion = payload.addonVersion or '<=1.4.1' -- added after 1.4.1

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
    self:RegisterEvent('LFG_ROLE_CHECK_SHOW')

    self:RegisterEvent('GROUP_ROSTER_UPDATE')
    self:RegisterEvent('PLAYER_ENTERING_WORLD')

    self:RegisterComm(CommunicationEvent.NotifyMercDuration, Private.OnSyncData)
    self:RegisterComm(CommunicationEvent.SyncData, Private.OnSyncData)
    self:RegisterComm(CommunicationEvent.ReadyCheckHeartbeat, Private.OnReadyCheckHeartbeat)

    Namespace.Database.RegisterCallback(self, 'OnProfileChanged', 'RefreshConfig')
    Namespace.Database.RegisterCallback(self, 'OnProfileCopied', 'RefreshConfig')
    Namespace.Database.RegisterCallback(self, 'OnProfileReset', 'RefreshConfig')

    Memory.queueStateChangeListeners = {
        Private.DetectQueuePause,
        Private.DetectQueueResume,
        Private.DetectQueueCancelAfterConfirm,
    }

    self:RefreshConfig()
end

function Module:LFG_ROLE_CHECK_SHOW()
    if not Namespace.Database.profile.QueueTools.Automation.acceptRoleSelection then return end

    local _, _, _, _, _, bgQueue = GetLFGRoleUpdate()
    if not bgQueue then return end

    local button = _G.LFDRoleCheckPopupAcceptButton
    if not button then return end

    button:Click()
end

function Module:GROUP_ROSTER_UPDATE()
    Private.TriggerStateUpdates()
end

function Module:PLAYER_ENTERING_WORLD()
    Private.EnterZone()
    Private.TriggerStateUpdates()
end

function Private.SendReadyCheckHeartbeat()
    if not Private.CanDoReadyCheck() then return end

    DoReadyCheck()
    Module:SendCommMessage(CommunicationEvent.ReadyCheckHeartbeat, 'ping', GetMessageDestination())

    if Memory.readyCheckHeartbeatTimout ~= nil then
        -- ensure it's always cancelled as it might have been called directly
        Module:CancelTimer(Memory.readyCheckHeartbeatTimout)
        Memory.readyCheckHeartbeatTimout = nil
    end
end

function Private.ScheduleReadyCheckHeartbeat(delay)
    if delay == nil then delay = 0 end

    if Memory.readyCheckHeartbeatTimout ~= nil then
        Module:CancelTimer(Memory.readyCheckHeartbeatTimout)
    end

    Memory.readyCheckHeartbeatTimout = Module:ScheduleTimer(Private.SendReadyCheckHeartbeat, delay)
end

function Private.DetectQueuePause(previousState, newState, mapName)
    if previousState.queueStatus ~= QueueStatus.Queued then return end
    if newState.queueStatus ~= QueueStatus.Queued then return end
    if previousState.suspendedQueue == true then return end
    if newState.suspendedQueue == false then return end

    local config = Namespace.Database.profile.QueueTools.InspectQueue
    if config.onlyAsLeader and not Private.IsLeaderOrAssistant('player') then return end

    if config.sendPausedMessage then
        local message = format(Namespace.Meta.chatTemplate, format(L['Queue paused for for %s'], mapName))
        SendChatMessage(message, GetMessageDestination())
    end

    if config.doReadyCheckOnQueuePause then
        Private.SendReadyCheckHeartbeat()
    end
end

function Private.DetectQueueResume(previousState, newState, mapName)
    if previousState.queueStatus ~= QueueStatus.Queued then return end
    if newState.queueStatus ~= QueueStatus.Queued then return end
    if previousState.suspendedQueue == false then return end
    if newState.suspendedQueue == true then return end

    local config = Namespace.Database.profile.QueueTools.InspectQueue
    if config.onlyAsLeader and not Private.IsLeaderOrAssistant('player') then return end
    if not config.sendResumedMessage then return end

    local message = format(Namespace.Meta.chatTemplate, format(L['Queue resumed for %s'], mapName))

    SendChatMessage(message, GetMessageDestination())
end

function Private.DetectQueueCancelAfterConfirm(previousState, newState)
    if previousState.queueStatus ~= QueueStatus.Confirm then return end
    if newState.queueStatus ~= QueueStatus.None then return end

    local config = Namespace.Database.profile.QueueTools.InspectQueue
    if not config.doReadyCheckOnQueueCancelAfterConfirm then return end
    if config.onlyAsLeader and not Private.IsLeaderOrAssistant('player') then return end

    -- wait a few seconds as not everyone will have cancelled as fast
    Private.ScheduleReadyCheckHeartbeat(3)
end

function Module:UPDATE_BATTLEFIELD_STATUS(_, queueId)
    if Memory.currentZoneId ~= 0 then return end
    if GetNumGroupMembers() == 0 then return end

    local previousState = Memory.queueState[queueId] or {}
    local status, mapName, _, _, suspendedQueue = GetBattlefieldStatus(queueId)
    local newState = { status = status, suspendedQueue = suspendedQueue }

    if newState.status == previousState.status and newState.suspendedQueue == previousState.suspendedQueue then return end

    for _, listener in pairs(Memory.queueStateChangeListeners) do
        listener(previousState, newState, mapName)
    end

    Memory.queueState[queueId] = newState
end

function Module:RefreshConfig()
    Private.UpdateQueueFrameVisibility(Namespace.Database.profile.QueueTools.showGroupQueueFrame)
end

function Module:COMBAT_LOG_EVENT_UNFILTERED()
    local _, subEvent, _, sourceGUID, _, _, _, _, _, _, _, spellId  = CombatLogGetCurrentEventInfo()
    if (spellId ~= SpellIds.MercenaryContractBuff and spellId ~= SpellIds.DeserterDebuff) or sourceGUID ~= UnitGUID('player') then return end

    if subEvent == 'SPELL_AURA_APPLIED' or subEvent == 'SPELL_AURA_REFRESH' or subEvent == 'SPELL_AURA_REMOVED' then
        Private.ScheduleSendSyncData()
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
    queueFrame:SetPortraitToAsset([[Interface\LFGFrame\UI-LFR-PORTRAIT]])
    PVPUIFrame.QueueFrame = queueFrame

    local playerTable = ScrollingTable:CreateST(tableStructure, 14, 24, nil, queueFrame)
    playerTable.frame:SetBackdropColor(0, 0, 0, 0)
    playerTable.frame:SetBackdropBorderColor(0, 0, 0, 0)
    playerTable.frame:SetPoint('TOPRIGHT', -4, -58)
    playerTable:RegisterEvents({
        onEnter = function (rowFrame, _, data, _, _, realRow, _)
            if not data[realRow] then return end

            local originalData = data[realRow].originalData
            if not originalData.addonVersion then return end

            _G.GameTooltip:SetOwner(rowFrame, 'ANCHOR_NONE')
            _G.GameTooltip:SetPoint('LEFT', rowFrame, 'RIGHT')
            _G.GameTooltip:SetText(format(L['Addon version: %s'], originalData.addonVersion), nil, nil, nil, nil, true)
        end,
        onLeave = function () _G.GameTooltip:Hide() end,
    }, true)

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

    local settingsButton = CreateFrame('Button', nil, queueFrame, 'UIPanelButtonTemplate')
    settingsButton:SetWidth(24)
    settingsButton:SetHeight(24)
    settingsButton:SetPoint('BOTTOMRIGHT', queueFrame, 'BOTTOMRIGHT', -2, 3)
    settingsButton:SetNormalTexture([[Interface\WorldMap\Gear_64.png]])
    settingsButton:SetHighlightTexture([[Interface\WorldMap\Gear_64.png]])
    settingsButton:SetPushedTexture([[Interface\WorldMap\Gear_64.png]])

    settingsButton:SetScript('OnEnter', function (self)
        _G.GameTooltip:SetOwner(self, 'ANCHOR_TOP')
        _G.GameTooltip:SetText(L['Open Battleground Commander Settings'], nil, nil, nil, nil, true)
    end)
    settingsButton:SetScript('OnLeave', function () _G.GameTooltip:Hide() end)
    settingsButton:SetScript('OnClick', function () Namespace.Addon:OpenSettingsPanel() end)

    local settingsButtonHighlightTexture = settingsButton:GetHighlightTexture()
    settingsButtonHighlightTexture:SetPoint('TOPLEFT', 4, -4)
    settingsButtonHighlightTexture:SetPoint('BOTTOMRIGHT', -4, 4)
    settingsButtonHighlightTexture:SetTexCoord(0, 0.50, 0, 0.50)

    local settingsButtonPushedTexture = settingsButton:GetPushedTexture()
    settingsButtonPushedTexture:ClearAllPoints()
    settingsButtonPushedTexture:SetPoint('TOPLEFT', 5, -6)
    settingsButtonPushedTexture:SetPoint('BOTTOMRIGHT', -5, 6)
    settingsButtonPushedTexture:SetTexCoord(0, 0.50, 0, 0.50)

    local settingsButtonTexture = settingsButton:GetNormalTexture()
    settingsButtonTexture:SetPoint('TOPLEFT', 4, -4)
    settingsButtonTexture:SetPoint('BOTTOMRIGHT', -4, 4)
    settingsButtonTexture:SetTexCoord(0, 0.50, 0, 0.50)
    settingsButtonTexture:SetVertexColor(1.0, 0.82, 0, 1.0)

    queueFrame.SettingsButton = settingsButton

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
    Namespace.Database.profile.QueueTools.InspectQueue[setting] = value
end

function Module:GetQueueInspectionSetting(setting)
    return Namespace.Database.profile.QueueTools.InspectQueue[setting]
end

function Module:SetAutomationSetting(setting, value)
    Namespace.Database.profile.QueueTools.Automation[setting] = value
end

function Module:GetAutomationSetting(setting)
    return Namespace.Database.profile.QueueTools.Automation[setting]
end
