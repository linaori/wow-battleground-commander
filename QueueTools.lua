local _G, ModuleName, Private, AddonName, Namespace = _G, 'QueueTools', {}, ...
local Addon = Namespace.Addon
local Module = Addon:NewModule(ModuleName, 'AceEvent-3.0', 'AceTimer-3.0', 'AceComm-3.0')
local L = Namespace.Libs.AceLocale:GetLocale(AddonName)
local ScrollingTable = Namespace.Libs.ScrollingTable

Namespace.QueueTools = Module

local GetPlayerDataByUnit = Namespace.PlayerData.GetPlayerDataByUnit
local GetPlayerDataByName = Namespace.PlayerData.GetPlayerDataByName
local RebuildPlayerData = Namespace.PlayerData.RebuildPlayerData
local ForEachPlayerData = Namespace.PlayerData.ForEachPlayerData
local ForEachUnitData = Namespace.PlayerData.ForEachUnitData
local ReadyCheckState = Namespace.Utils.ReadyCheckState
local BattlegroundStatus = Namespace.Utils.BattlegroundStatus
local IsLeaderOrAssistant = Namespace.Utils.IsLeaderOrAssistant
local RaidMarker = Namespace.Utils.RaidMarker
local PackData = Namespace.Communication.PackData
local UnpackData = Namespace.Communication.UnpackData
local GetMessageDestination = Namespace.Communication.GetMessageDestination
local DoReadyCheck = DoReadyCheck
local GetInstanceInfo = GetInstanceInfo
local CreateFrame = CreateFrame
local PlaySound = PlaySound
local CharacterPanelOpenSound = SOUNDKIT.IG_CHARACTER_INFO_OPEN
local CharacterPanelCloseSound = SOUNDKIT.IG_CHARACTER_INFO_CLOSE
local GetPlayerAuraBySpellID = GetPlayerAuraBySpellID
local GetNumGroupMembers = GetNumGroupMembers
local GetBattlefieldStatus = GetBattlefieldStatus
local GetMaxBattlefieldID = GetMaxBattlefieldID
local GetLFGRoleUpdate = GetLFGRoleUpdate
local GetUnitName = GetUnitName
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local UnitClass = UnitClass
local UnitDebuff = UnitDebuff
local UnitGUID = UnitGUID
local GetTime = GetTime
local IsShiftKeyDown = IsShiftKeyDown
local SendChatMessage = SendChatMessage
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local DEBUFF_MAX_DISPLAY = DEBUFF_MAX_DISPLAY
local UNKNOWNOBJECT = UNKNOWNOBJECT
local TimeDiff = Namespace.Utils.TimeDiff
local max = math.max
local ceil = math.ceil
local format = string.format
local pairs = pairs
local concat = table.concat
--local print = Namespace.Debug.print
local log = Namespace.Debug.log

local locale = GetLocale()

local SpellIds = {
    DeserterDebuff = 26013,
    MercenaryContractBuff = 193475,
}

local tableStructure = {
    {
        name = '',
        width = 25,
    },
    {
        name = '',
        width = 100,
        align = 'LEFT',
    },
    {
        name = L['Auto Queue'],
        width = 40,
        align = 'CENTER',
    },
    {
        name = ' ' .. L['Merc'],
        width = 40,
        align = 'CENTER',
    },
    {
        name = ' ' .. L['Deserter'],
        width = 50,
        align = 'CENTER',
    },
    {
        name = ' ' .. L['Status'],
        width = 50,
        align = 'CENTER',
    }
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
    stateInitializedTimout = nil,
    disableEntryButtonTicker = nil,

    queueState = {
        --[0] = {
        --    status = QueueStatus,
        --    queueSuspended = boolean
        --},
    },
    queueStateChangeListeners = {},

    playerTableCache = {},

    -- the data that should be send next data sync event
    syncDataPayloadBuffer = nil,
}

local CommunicationEvent = {
    SyncData = 'Bgc:syncData',
    NotifyMercDuration = 'Bgc:notifyMerc', -- replaced by Bgc:syncData
    ReadyCheckHeartbeat = 'Bgc:rchb',
    EnterBattleground = 'Bgc:enterBg',
    DeclineBattleground = 'Bgc:declineBg',
}

local ColorList = {
    Bad = { r = 1.0, g = 0, b = 0, a = 1.0 },
    Good = { r = 0, g = 1.0, b = 0, a = 1.0 },
    Warning = { r = 1.0, g = 1.0, b = 0, a = 1.0 },
    UnknownClass = { r = 0.7, g = 0.7, b = 0.7, a = 1.0 },
}

function Private.SendSyncData()
    if Memory.syncDataPayloadBuffer == nil then return end

    local channel, player = GetMessageDestination()
    local payload = PackData(Memory.syncDataPayloadBuffer)

    Module:SendCommMessage(CommunicationEvent.NotifyMercDuration, payload, channel, player) -- remove in future
    Module:SendCommMessage(CommunicationEvent.SyncData, payload, channel, player)
    Memory.syncDataPayloadBuffer = nil
end

function Private.ScheduleSendSyncData()
    local shouldSchedule = Memory.syncDataPayloadBuffer == nil

    Memory.syncDataPayloadBuffer = {
        addonVersion = Namespace.Meta.version,
        remainingMercenary = Private.GetRemainingAuraTime(SpellIds.MercenaryContractBuff),
        remainingDeserter = Private.GetRemainingAuraTime(SpellIds.DeserterDebuff),
        autoAcceptRole = Namespace.Database.profile.QueueTools.Automation.acceptRoleSelection,
    }

    if not shouldSchedule then return end

    Module:ScheduleTimer(Private.SendSyncData, ceil(GetNumGroupMembers() * 0.1) + 1)
end

function Private.CanDoReadyCheck()
    if Memory.lastReadyCheckTime + Memory.lastReadyCheckDuration > GetTime() then
        return false
    end

    if not IsLeaderOrAssistant('player') then
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

    local autoAcceptRoleColumn = {
        value = function(tableData, _, realRow, column)
            local columnData = tableData[realRow].cols[column]
            if data.autoAcceptRole == nil then
                columnData.color = ColorList.Warning
                return '?'
            end

            columnData.color = nil

            return data.autoAcceptRole and L['yes'] or L['no']
        end,
    }

    local mercenaryColumn = {
        value = function(tableData, _, realRow, column)
            local columnData = tableData[realRow].cols[column]
            if not data.mercenaryExpiry then
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
            local battlegroundStatus = data.battlegroundStatus

            if battlegroundStatus == BattlegroundStatus.Declined then
                columnData.color = nil
                return L['Declined']
            end

            if battlegroundStatus == BattlegroundStatus.Entered then
                columnData.color = nil
                return L['Entered']
            end

            if readyState == ReadyCheckState.Declined then
                columnData.color = ColorList.Bad
                return L['Not Ready']
            end

            if readyState == ReadyCheckState.Ready then
                columnData.color = ColorList.Good
                return L['Ready']
            end

            if readyState == ReadyCheckState.Waiting or battlegroundStatus == BattlegroundStatus.Waiting then
                columnData.color = ColorList.Warning
                return '...'
            end

            columnData.color = nil
            return '-'
        end,
    }

    return { cols = {
        {value = index},
        nameColumn,
        autoAcceptRoleColumn,
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

function Private.EnterZone()
    local _, instanceType, _, _, _, _, _, currentZoneId = GetInstanceInfo()
    if instanceType == 'none' then currentZoneId = 0 end
    Memory.currentZoneId = currentZoneId
end

function Private.ScheduleStateUpdates(delay)
    if Memory.stateInitializedTimout then return end

    Memory.stateInitializedTimout = Module:ScheduleTimer(Private.TriggerStateUpdates, delay)
end

function Private.TriggerStateUpdates()
    if _G.BgcReadyCheckButton then _G.BgcReadyCheckButton:SetEnabled(Private.CanDoReadyCheck()) end

    local tableCache, count = {}, 0
    for _, playerData in pairs(RebuildPlayerData()) do
        count = count + 1
        tableCache[count] = Private.CreateTableRow(count, playerData)
    end

    Memory.stateInitializedTimout = nil
    Memory.playerTableCache = tableCache

    Private.ScheduleSendSyncData()
    Private.UpdatePlayerTableData()
    Private.RefreshPlayerTable()
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
    checkbox:SetScript('OnEnter', function (self)
        local tooltip = _G.GameTooltip
        tooltip:SetOwner(self, 'ANCHOR_RIGHT')
        tooltip:SetText(L['Show or hide the Battleground Commander group information window'], nil, nil, nil, nil, true)
        tooltip:Show()
    end)
    checkbox:SetScript('OnLeave', function () _G.GameTooltip:Hide() end)
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
    text:SetText(L['Group Info'])
    text:SetPoint('RIGHT', checkbox, 'LEFT')
    text:SetWordWrap(false)

    checkbox.Text = text
end

function Private.ProcessSyncData(payload, data)
    local time = GetTime()
    -- renamed after 1.4.0, remove "remaining" index in the future
    data.mercenaryExpiry = (payload.remainingMercenary or payload.remaining) + time
    if payload.remainingDeserter then
        -- added after 1.4.0, remove if check in the future
        data.deserterExpiry = payload.remainingDeserter + time
    end

    data.addonVersion = payload.addonVersion or '<=1.4.1' -- added after 1.4.1
    data.autoAcceptRole = payload.autoAcceptRole

    Private.RefreshPlayerTable()
end

function Private.OnSyncData(_, text, _, sender)
    local payload = UnpackData(text)
    if not payload then return end

    local data = GetPlayerDataByName(sender)
    if data then return Private.ProcessSyncData(payload, data) end

    -- in some cases after initial login the realm names are missing from
    -- GetUnitName. Delaying in the hopes this is available when retrying
    return Module:ScheduleTimer(function ()
        data = GetPlayerDataByName(sender)
        if not data then return log('Unable to find data for sender: ', sender) end

        Private.ProcessSyncData(payload, data)
    end, 5)
end

function Private.OnReadyCheckHeartbeat(_, text, _, sender)
    if sender == GetUnitName('player', true) then return end

    local acceptReadyCheck = function (skipVisibility)
        if not skipVisibility and not _G.ReadyCheckFrameYesButton:IsVisible() then return end

        _G.ReadyCheckFrameYesButton:Click()
        Addon:PrintMessage(format(L['Accepted automated ready check with message: "%s"'], text))
    end

    -- due to the async nature, the ready check might come later than the
    -- message to click the button, postpone click if not visible yet
    if _G.ReadyCheckFrameYesButton:IsVisible() then
        return acceptReadyCheck(true)
    end

    Module:ScheduleTimer(acceptReadyCheck, 0.055)
end

function Module:OnInitialize()
    self:RegisterEvent('ADDON_LOADED')
end

function Private.OnClickEnterBattleground()
    local channel, player = GetMessageDestination()
    Module:SendCommMessage(CommunicationEvent.EnterBattleground, '1', channel, player)

    if not IsLeaderOrAssistant('player') then return end

    local config = Namespace.Database.profile.QueueTools.InspectQueue
    if config.sendMessageOnBattlegroundEntry then
        local message = concat({RaidMarker.GreenTriangle, Private.TwoLanguages('Enter'), RaidMarker.GreenTriangle}, ' ')
        SendChatMessage(Addon:PrependChatTemplate(message), channel)
    end
end

function Private.OnEnterBattleground(_, _, _, sender)
    local data = GetPlayerDataByName(sender)
    if not data then return end

    if data.battlegroundStatus == BattlegroundStatus.Waiting then
        data.battlegroundStatus = BattlegroundStatus.Entered
    end

    Private.RefreshPlayerTable()
end

function Private.RestoreEntryButton()
    local button = _G.PVPReadyDialogEnterBattleButton
    if not button:IsEnabled() and button:GetText() == L['Hold Shift'] then
        button:SetEnabled(true)
        button:SetText(Memory.disableEntryButtonOriginalText)
    end

    if Memory.disableEntryButtonTicker == nil then return end

    Module:CancelTimer(Memory.disableEntryButtonTicker)
    Memory.disableEntryButtonTicker = nil
end

function Private.DisableEntryButton()
    if not Namespace.Database.profile.QueueTools.Automation.disableEntryButtonOnCancel then return end
    if Memory.disableEntryButtonTicker then return end

    local button = _G.PVPReadyDialogEnterBattleButton
    if not button:IsEnabled() then return end
    button:SetEnabled(false)
    button:SetText(L['Hold Shift'])

    Memory.disableEntryButtonTicker = Module:ScheduleRepeatingTimer(function ()
        if IsShiftKeyDown() then Private.RestoreEntryButton() end
    end, 0.2)
end

Module.DisableEntryButton = Private.DisableEntryButton

function Private.OnDeclineBattleground(_, _, _, sender)
    local data = GetPlayerDataByName(sender)
    if not data then return end

    if data.battlegroundStatus == BattlegroundStatus.Waiting then
        data.battlegroundStatus = BattlegroundStatus.Declined
    end

    if sender ~= GetUnitName('player', true) and IsLeaderOrAssistant(data.units.primary) then
        Private.DisableEntryButton()
    end

    Private.RefreshPlayerTable()
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
    self:RegisterComm(CommunicationEvent.EnterBattleground, Private.OnEnterBattleground)
    self:RegisterComm(CommunicationEvent.DeclineBattleground, Private.OnDeclineBattleground)

    Namespace.Database.RegisterCallback(self, 'OnProfileChanged', 'RefreshConfig')
    Namespace.Database.RegisterCallback(self, 'OnProfileCopied', 'RefreshConfig')
    Namespace.Database.RegisterCallback(self, 'OnProfileReset', 'RefreshConfig')

    Memory.queueStateChangeListeners = {
        Private.DetectQueueEntry,
        Private.DetectQueuePop,
        Private.DetectBattlegroundExit,
        Private.DetectQueuePause,
        Private.DetectQueueResume,
        Private.DetectQueueCancelAfterConfirm,
        Private.DetectBattlegroundEntryAfterConfirm,
    }

    self:RefreshConfig()

    local enterButton = _G.PVPReadyDialogEnterBattleButton
    enterButton:HookScript('OnClick', Private.OnClickEnterBattleground)
    Memory.disableEntryButtonOriginalText = enterButton:GetText()
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
    Private.ScheduleStateUpdates(1)
end

function Module:PLAYER_ENTERING_WORLD(_, isLogin, isReload)
    Private.EnterZone()
    if isLogin then
        Private.ScheduleStateUpdates(5)
    elseif isReload then
        Private.ScheduleStateUpdates(2)
    else
        Private.TriggerStateUpdates()
    end

    if not isLogin and not isReload then return end

    -- when logging in or reloading mid-queue, the first queue status mutation
    -- is inaccurate if not set before it happens
    for queueId = 1, GetMaxBattlefieldID() do
        local status, _, _, _, suspendedQueue = GetBattlefieldStatus(queueId)
        Memory.queueState[queueId] = { status = status, suspendedQueue = suspendedQueue }
    end
end

function Private.SendReadyCheckHeartbeat(message)
    if not Private.CanDoReadyCheck() then return end

    DoReadyCheck()
    Addon:PrintMessage(format(L['Sending automated ready check with message: "%s"'], message))
    Module:SendCommMessage(CommunicationEvent.ReadyCheckHeartbeat, message, GetMessageDestination())
end

function Private.ScheduleReadyCheckHeartbeat(message, delay, preventReadyCheckCallback)
    if delay == nil then delay = 0 end

    if Memory.readyCheckHeartbeatTimout ~= nil then return end
    Memory.readyCheckHeartbeatTimout = Module:ScheduleTimer(function ()
        if preventReadyCheckCallback and preventReadyCheckCallback() then return end

        Private.SendReadyCheckHeartbeat(message)
        Memory.readyCheckHeartbeatTimout = nil
    end, delay)
end

function Private.DetectQueuePop(previousState, newState)
    if previousState.status ~= QueueStatus.Queued then return end
    if newState.status ~= QueueStatus.Confirm then return end

    ForEachUnitData(function(data) data.battlegroundStatus = BattlegroundStatus.Waiting end)

    Private.RefreshPlayerTable()
end

function Private.DetectQueueEntry(previousState, newState)
    if previousState.status ~= QueueStatus.None then return end
    if newState.status ~= QueueStatus.Queued then return end

    ForEachPlayerData(function(data) data.battlegroundStatus = BattlegroundStatus.None end)

    Private.RestoreEntryButton()
    Private.RefreshPlayerTable()
end

function Private.DetectBattlegroundExit(previousState, newState)
    if previousState.status ~= QueueStatus.Active then return end
    if newState.status ~= QueueStatus.None then return end

    -- force refreshing the player data
    Private.TriggerStateUpdates()

    ForEachPlayerData(function(data) data.battlegroundStatus = BattlegroundStatus.Nothing end)
end

function Private.DetectQueuePause(previousState, newState, mapName)
    if previousState.status ~= QueueStatus.Queued then return end
    if newState.status ~= QueueStatus.Queued then return end
    if previousState.suspendedQueue == true then return end
    if newState.suspendedQueue == false then return end

    local config = Namespace.Database.profile.QueueTools.InspectQueue
    local isLeader = IsLeaderOrAssistant('player')
    if config.onlyAsLeader and not isLeader then return end

    if config.sendPausedMessage then
        local message = Private.TwoLanguages('Queue paused for %s', mapName)
        if GetNumGroupMembers() == 0 then
            -- just return, you got no friends to do a ready check with anyway
            return Addon:PrintMessage(message)
        end

        local channel = GetMessageDestination()
        SendChatMessage(Addon:PrependChatTemplate(message), channel)
    end

    if isLeader and config.doReadyCheckOnQueuePause then
        Private.ScheduleReadyCheckHeartbeat('Detected queue pause')
    end
end

function Private.DetectQueueResume(previousState, newState, mapName)
    if previousState.status ~= QueueStatus.Queued then return end
    if newState.status ~= QueueStatus.Queued then return end
    if previousState.suspendedQueue == false then return end
    if newState.suspendedQueue == true then return end

    local config = Namespace.Database.profile.QueueTools.InspectQueue
    if config.onlyAsLeader and not IsLeaderOrAssistant('player') then return end
    if not config.sendResumedMessage then return end

    local message = Private.TwoLanguages('Queue resumed for %s', mapName)
    if GetNumGroupMembers() == 0 then
        return Addon:PrintMessage(message)
    end

    local channel = GetMessageDestination()
    SendChatMessage(Addon:PrependChatTemplate(message), channel)
end

function Private.DetectQueueCancelAfterConfirm(previousState, newState)
    if previousState.status ~= QueueStatus.Confirm then return end
    if newState.status ~= QueueStatus.None then return end

    Module:SendCommMessage(CommunicationEvent.DeclineBattleground, '1', GetMessageDestination())
    Private.RestoreEntryButton()

    if not IsLeaderOrAssistant('player') then return end

    local config = Namespace.Database.profile.QueueTools.InspectQueue
    if config.doReadyCheckOnQueueCancelAfterConfirm then
        -- wait a few seconds as not everyone will have cancelled as fast
        Private.ScheduleReadyCheckHeartbeat('Confirm nobody entered', 4, function ()
            local preventReadyCheck = true
            ForEachUnitData(function (data)
                if data.battlegroundStatus == BattlegroundStatus.Waiting then
                    preventReadyCheck = false
                    return false
                end
            end)

            return preventReadyCheck
        end)
    end

    if config.sendMessageOnQueueCancelAfterConfirm then
        local channel = GetMessageDestination()
        local message = concat({RaidMarker.RedCross, Private.TwoLanguages('Cancel'), RaidMarker.RedCross}, ' ')
        SendChatMessage(Addon:PrependChatTemplate(message), channel)
    end
end

function Private.DetectBattlegroundEntryAfterConfirm(previousState, newState)
    if previousState.status ~= QueueStatus.Confirm then return end
    if newState.status ~= QueueStatus.Active then return end

    ForEachPlayerData(function(data) data.battlegroundStatus = BattlegroundStatus.Nothing end)
end

function Module:UPDATE_BATTLEFIELD_STATUS(_, queueId)
    local previousState = Memory.queueState[queueId] or { status = QueueStatus.None, suspendedQueue = false }
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
    Private.ScheduleSendSyncData()
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

    -- occupy the heartbeat timeout so it won't send anything shortly after this ready check
    Memory.readyCheckHeartbeatTimout = self:ScheduleTimer(function() Memory.readyCheckHeartbeatTimout = nil end, duration)

    ForEachUnitData(function(data) data.readyState = ReadyCheckState.Waiting end)

    local initiatedByData = GetPlayerDataByName(initiatedByName)
    if initiatedByData then
        initiatedByData.readyState = ReadyCheckState.Ready
    else
        log('READY_CHECK', 'Missing player for initiatedByName', initiatedByName)
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

    Private.ScheduleStateUpdates(1)
    Private.RefreshPlayerTable()
end

function Module:READY_CHECK_CONFIRM(_, unit, ready)
    local data = GetPlayerDataByUnit(unit)
    if not data then return log('READY_CHECK_CONFIRM', 'Missing unit', unit) end

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

    ForEachUnitData(function(data)
        if data.readyState == ReadyCheckState.Waiting then
            -- in case of expired ready check no confirmation means declined
            data.readyState = ReadyCheckState.Declined
        end
    end)

    self:ScheduleTimer(function ()
        -- new ready check has been initiated, don't do anything anymore
        if Memory.lastReadyCheckTime + Memory.lastReadyCheckDuration > GetTime() then return end

        ForEachPlayerData(function(data) data.readyState = ReadyCheckState.Nothing end)

        Private.RefreshPlayerTable()
        Memory.readyCheckClearTimeout = nil
    end, 10)

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
        self.refreshTimer = Module:ScheduleRepeatingTimer(Private.RefreshPlayerTable, 10)
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
    readyCheckButton:SetEnabled(false)

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

    Private.ScheduleStateUpdates(1)
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
    local Automation = Namespace.Database.profile.QueueTools.Automation
    if setting == 'acceptRoleSelection' and value ~= Automation[setting] then
        -- notify through sync data when this setting changed
        Automation[setting] = value
        return Private.ScheduleSendSyncData()
    end

    Automation[setting] = value
end

function Module:GetAutomationSetting(setting)
    return Namespace.Database.profile.QueueTools.Automation[setting]
end

--- Creates a formatted message based on the translation key for both the
--- user locale, and English
function Private.TwoLanguages(translationKey, ...)
    local translated = format(L[translationKey], ...)
    if locale == 'enUS' then return translated end

    local english = format(translationKey, ...)
    if english == translated then return translated end

    return concat({english, '/' , translated}, ' ')
end
