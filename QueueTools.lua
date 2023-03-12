local _G, ModuleName, Private, AddonName, Namespace = _G, 'QueueTools', {}, ...
local Addon = Namespace.Addon
local Module = Addon:NewModule(ModuleName, 'AceEvent-3.0', 'AceTimer-3.0', 'AceComm-3.0')
local L = Namespace.Libs.AceLocale:GetLocale(AddonName)
local ACD = Namespace.Libs.AceConfigDialog
local ScrollingTable = Namespace.Libs.ScrollingTable

Namespace.QueueTools = Module

local Faction = Namespace.PlayerData.Faction
local GetPlayerDataByUnit = Namespace.PlayerData.GetPlayerDataByUnit
local GetPlayerDataByName = Namespace.PlayerData.GetPlayerDataByName
local GetGroupLeaderData = Namespace.PlayerData.GetGroupLeaderData
local RebuildPlayerData = Namespace.PlayerData.RebuildPlayerData
local ForEachPlayerData = Namespace.PlayerData.ForEachPlayerData
local RefreshMissingData = Namespace.PlayerData.RefreshMissingData
local ForEachUnitData = Namespace.PlayerData.ForEachUnitData
local Role = Namespace.PlayerData.Role
local ReadyCheckState = Namespace.Utils.ReadyCheckState
local BattlegroundStatus = Namespace.Utils.BattlegroundStatus
local RoleCheckStatus = Namespace.Utils.RoleCheckStatus
local IsLeaderOrAssistant = Namespace.Utils.IsLeaderOrAssistant
local GetPlayerAuraExpiration = Namespace.Utils.GetPlayerAuraExpiration
local RaidIconChatStyle = Namespace.Utils.RaidIconChatStyle
local PackData = Namespace.Communication.PackData
local UnpackData = Namespace.Communication.UnpackData
local GetMessageDestination = Namespace.Communication.GetMessageDestination
local InActiveBattleground = Namespace.Battleground.InActiveBattleground
local AllowQueuePause = Namespace.Battleground.AllowQueuePause
local QueueStatus = Namespace.Battleground.QueueStatus
local CreateAtlasMarkup = CreateAtlasMarkup
local DoReadyCheck = DoReadyCheck
local GetInstanceInfo = GetInstanceInfo
local CreateFrame = CreateFrame
local PlaySound = PlaySound
local CharacterPanelOpenSound = SOUNDKIT.IG_CHARACTER_INFO_OPEN
local CharacterPanelCloseSound = SOUNDKIT.IG_CHARACTER_INFO_CLOSE
local GetNumGroupMembers = GetNumGroupMembers
local GetLFGRoleUpdate = GetLFGRoleUpdate
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local UnitDebuff = UnitDebuff
local UnitAffectingCombat = UnitAffectingCombat
local GetTime = GetTime
local IsShiftKeyDown = IsShiftKeyDown
local SendChatMessage = SendChatMessage
local DEBUFF_MAX_DISPLAY = DEBUFF_MAX_DISPLAY
local UNKNOWNOBJECT = UNKNOWNOBJECT
local TimeDiff = Namespace.Utils.TimeDiff
local max = math.max
local ceil = math.ceil
local format = string.format
local pairs = pairs
local concat = table.concat
local sort = table.sort
local locale = GetLocale()

local SpellIds = {
    DeserterDebuff = 26013,
    MercenaryContractAlliance = 193472,
    MercenaryContractHorde = 193475,
}

local tableStructure = {
    {
        name = '',
        width = 20,
    },
    {
        name = '',
        width = 110,
        align = 'LEFT',
    },
    {
        name = L['Auto Queue'],
        width = 45,
        align = 'CENTER',
    },
    {
        name = ' ' .. L['Merc'],
        width = 50,
        align = 'CENTER',
    },
    {
        name = ' ' .. L['Status'],
        width = 75,
        align = 'CENTER',
    },
    {
        name = '',
        width = 22,
        align = 'LEFT',
    }
}

local Memory = {
    -- seems like you can't do a second ready check for about 5~6 seconds, even if the "finished" event is faster
    readyCheckGracePeriod = 6,

    -- keep track of last ready check and when it finished to update the button and icons properly
    lastReadyCheckTime = 0,
    lastReadyCheckDuration = 0,
    readyCheckButtonTicker = nil,
    readyCheckClearTimeout = nil,
    readyCheckHeartbeatTimout = nil,
    disableEntryButtonTicker = nil,

    playerTableCache = {},

    -- the data that should be send next data sync event
    syncDataPayloadBuffer = nil,
}

local NameFormat = {
    RealmWhenPlayer = 1,
    RealmAlways = 2,
    RealmNever = 3,
}

Namespace.QueueTools.NameFormat = NameFormat

local CommunicationEvent = {
    SyncData = 'Bgc:syncData',
    ReadyCheckHeartbeat = 'Bgc:rchb',
    EnterBattleground = 'Bgc:enterBg',
    DeclineBattleground = 'Bgc:declineBg',
}

local ColorList = {
    None = { r = nil, g = nil, b = nil, a = 1},
    White = { r = 1, g = 1, b = 1, a = 1 },
    Bad = { r = 1, g = 0, b = 0, a = 1 },
    Good = { r = 0, g = 1, b = 0, a = 1 },
    Warning = { r = 1, g = 1, b = 0, a = 1 },
    UnknownClass = { r = 0.7, g = 0.7, b = 0.7, a = 1 },
}

function Private.SendSyncData()
    if Memory.syncDataPayloadBuffer == nil then return end

    local channel, player = GetMessageDestination()
    local payload = PackData(Memory.syncDataPayloadBuffer)

    Module:SendCommMessage(CommunicationEvent.SyncData, payload, channel, player)
    Memory.syncDataPayloadBuffer = nil
end

function Private.ScheduleSendSyncData()
    local shouldSchedule = Memory.syncDataPayloadBuffer == nil

    local remainingMercenary = Private.GetRemainingAuraTime(SpellIds.MercenaryContractHorde)
    if remainingMercenary == -1 then
        remainingMercenary = Private.GetRemainingAuraTime(SpellIds.MercenaryContractAlliance)
    end

    Memory.syncDataPayloadBuffer = {
        addonVersion = Namespace.Meta.version,
        remainingMercenary = remainingMercenary,
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

function Private.CreateTableRow(data)
    local indexColumn = {
        value = function ()
            if data.role == Role.Leader then
                return [[|TInterface\GroupFrame\UI-Group-LeaderIcon:17|t]]
            elseif data.role == Role.Assist then
                return [[|TInterface\GroupFrame\UI-Group-AssistantIcon:17|t]]
            end

            return ''
        end,
    }

    local nameColumn = {
        value = function(tableData, _, realRow, column)
            local columnData = tableData[realRow].cols[column]

            RefreshMissingData(data)

            local name = Module:GetPlayerNameForDisplay(data)
            local color = data.classColor or ColorList.UnknownClass

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
            local currentTime = GetTime()
            local leader = GetGroupLeaderData()
            local timeDiff = TimeDiff(data.mercenaryExpiry, currentTime)
            local shouldCheckStatus = data ~= leader and data.faction == (leader or data).faction
            local leaderHasMercenary = (leader or data).mercenaryExpiry > currentTime

            columnData.color = nil

            if timeDiff.fullSeconds < 1 then
                if shouldCheckStatus and leaderHasMercenary then
                    columnData.color = ColorList.Bad
                end

                return L['no']
            end

            -- it's a guesstimate
            if timeDiff.fullMinutes > 60 then
                if shouldCheckStatus and not leaderHasMercenary and leader.addonVersion then
                    columnData.color = ColorList.Bad
                else
                    columnData.color = ColorList.UnknownClass
                end

                return L['yes']
            end

            if shouldCheckStatus and not leaderHasMercenary then
                columnData.color = leader.addonVersion and ColorList.Bad or ColorList.Warning

                return L['yes']
            end

            if timeDiff.fullMinutes < 4 then
                columnData.color = ColorList.Bad
            elseif timeDiff.fullMinutes < 9 then
                columnData.color = ColorList.Warning
            end

            return format('%dm', timeDiff.fullMinutes)
        end,
    }

    local readyCheckColumn = {
        value = function(tableData, _, realRow, column)
            local columnData = tableData[realRow].cols[column]

            if not data.isConnected then
                columnData.color = ColorList.Bad
                return L['Offline']
            end

            Private.TriggerDeserterUpdate(data)

            local timeDiff = TimeDiff(data.deserterExpiry, GetTime())
            if timeDiff.fullSeconds > 0 then
                columnData.color = ColorList.Bad
                return format('%dm', timeDiff.fullMinutes) .. ' ' .. L['Deserter']
            end

            local battlegroundStatus = data.battlegroundStatus
            if battlegroundStatus == BattlegroundStatus.Entered then
                columnData.color = nil
                return L['Entered']
            end

            local roleCheckStatus = data.roleCheckStatus
            if roleCheckStatus == RoleCheckStatus.Waiting then
                columnData.color = ColorList.Warning
                return L['Role Check']
            end

            if roleCheckStatus == RoleCheckStatus.Accepted then
                columnData.color = ColorList.Good
                return L['Accepted']
            end

            local readyState = data.readyState
            if readyState == ReadyCheckState.Declined then
                columnData.color = ColorList.Bad
                return L['Not Ready']
            end

            if readyState == ReadyCheckState.Ready then
                columnData.color = ColorList.Good
                return L['Ready']
            end

            if battlegroundStatus == BattlegroundStatus.Declined then
                columnData.color = nil
                return L['Declined']
            end

            columnData.color = nil
            if readyState == ReadyCheckState.Waiting then
                return L['Ready Check']
            end

            if battlegroundStatus == BattlegroundStatus.Waiting then
                return L['Queue Pop']
            end

            return L['OK']
        end,
    }

    local factionColumn = {
        value = function ()
            local faction = data.faction
            if faction == Faction.Horde then
                return CreateAtlasMarkup('Warfronts-FieldMapIcons-Horde-Banner-Minimap', 20, 20)
            end

            if faction == Faction.Alliance then
                return CreateAtlasMarkup('Warfronts-FieldMapIcons-Alliance-Banner-Minimap', 20, 20)
            end

            return CreateAtlasMarkup('Warfronts-FieldMapIcons-Empty-Banner-Minimap', 20, 20)
        end,
    }

    return { cols = {
        indexColumn,
        nameColumn,
        autoAcceptRoleColumn,
        mercenaryColumn,
        readyCheckColumn,
        factionColumn,
    }, originalData = data }
end

function Private.RefreshGroupInfoFrame()
    if not _G.BgcQueueFrame or not Namespace.Database.profile.QueueTools.showGroupQueueFrame then return end

    Private.UpdateReadyCheckButtonState()
    Private.UpdateAddonUsersLabel()

    _G.BgcQueueFrame.PlayerTable:Refresh()
end

function Private.GetRemainingAuraTime(spellId)
    local expirationTime = GetPlayerAuraExpiration(spellId)

    return expirationTime and expirationTime - GetTime() or -1
end

function Private.UpdateReadyCheckButtonState()
    if _G.BgcReadyCheckButton then _G.BgcReadyCheckButton:SetEnabled(Private.CanDoReadyCheck()) end
end

function Private.UpdateAddonUsersLabel()
    if not _G.BgcAddonUsersLabel then return end

    local withAddon, total = 0, 0
    ForEachUnitData(function (data)
        total = total + 1
        withAddon = withAddon + (data.addonVersion and 1 or 0)
    end)

    local text = _G.BgcAddonUsersLabel.Text
    text:SetText(format(L['BGC: %d/%d'], withAddon, total))

    local color = withAddon == total and ColorList.White or ColorList.Warning
    text:SetTextColor(color.r, color.g, color.b, color.a)
end

function Private.RebuildGroupInformationTable(unitPlayerData)
    local tableCache, count = {}, 0
    for _, playerData in pairs(unitPlayerData) do
        count = count + 1
        tableCache[count] = Private.CreateTableRow(playerData)
    end

    Memory.playerTableCache = tableCache

    if _G.BgcQueueFrame and Namespace.Database.profile.QueueTools.showGroupQueueFrame then
        _G.BgcQueueFrame.PlayerTable:SetData(tableCache)
        Private.UpdateReadyCheckButtonState()
        Private.UpdateAddonUsersLabel()
    end

    Private.ScheduleSendSyncData()
end

function Private.UpdateGroupInfoVisibility(newVisibility)
    RebuildPlayerData()

    if not _G.BgcQueueFrame then return end

    _G.BgcQueueFrame:SetShown(newVisibility)
end

function Private.InitializeBattlegroundModeCheckbox()
    local checkbox = CreateFrame('CheckButton', 'BgcBattlegroundModeCheckbox', _G.PVPUIFrame, 'UICheckButtonTemplate')
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
        Private.UpdateGroupInfoVisibility(newVisibility)
        if newVisibility then
            PlaySound(CharacterPanelOpenSound)
        else
            PlaySound(CharacterPanelCloseSound)
        end
    end)
    checkbox:Show()

    _G.PVPUIFrame.BattlegroundModeCheckbox = checkbox

    local text = checkbox:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
    text:SetText(L['Group Info'])
    text:SetPoint('RIGHT', checkbox, 'LEFT')
    text:SetWordWrap(false)

    checkbox.Text = text
end

function Private.InitializeAutoQueueCheckbox()
    local checkbox = CreateFrame('CheckButton', 'BgcAutoQueueCheckbox', _G.HonorFrame.TankIcon, 'UICheckButtonTemplate')
    checkbox:SetPoint('BOTTOMLEFT', _G.HonorFrame.TankIcon, 'TOPLEFT', -5, 8)
    checkbox:SetSize(24, 24)
    checkbox:SetChecked(Module:GetAutomationSetting('acceptRoleSelection'))
    checkbox:SetScript('OnEnter', function (self)
        local tooltip = _G.GameTooltip
        tooltip:SetOwner(self, 'ANCHOR_RIGHT')
        tooltip:SetText(L['Accepts the pre-selected role when your group applies for a battleground'], nil, nil, nil, nil, true)
        tooltip:Show()
    end)
    checkbox:SetScript('OnLeave', function () _G.GameTooltip:Hide() end)
    checkbox:SetScript('OnClick', function (self) Module:SetAutomationSetting('acceptRoleSelection', self:GetChecked()) end)
    checkbox:Show()

    _G.HonorFrame.TankIcon.AutoQueueCheckbox = checkbox

    local text = checkbox:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
    text:SetText(L['Auto Accept Role'])
    text:SetPoint('LEFT', checkbox, 'RIGHT', 3, 0)
    text:SetWordWrap(false)

    checkbox.Text = text
end

function Private.ProcessSyncData(payload, data)
    local time = GetTime()

    data.mercenaryExpiry = payload.remainingMercenary + time
    data.deserterExpiry = payload.remainingDeserter + time
    data.addonVersion = payload.addonVersion
    data.autoAcceptRole = payload.autoAcceptRole

    Private.RefreshGroupInfoFrame()
end

function Private.OnSyncData(_, text, _, sender)
    local payload = UnpackData(text)
    if not payload then return end

    local data = GetPlayerDataByName(payload.sender or sender)
    if not data then return end

    Private.ProcessSyncData(payload, data)
end

function Private.OnReadyCheckHeartbeat(_, text, _, sender)
    local payload = UnpackData(text)
    text = payload and payload.message or text
    sender = payload and payload.sender or sender

    local playerData = GetPlayerDataByName(sender)
    if not playerData or playerData.units.player then return end

    local acceptReadyCheck = function (skipVisibility)
        if not skipVisibility and not _G.ReadyCheckFrameYesButton:IsVisible() then return end

        _G.ReadyCheckFrameYesButton:Click()
        Addon:Print(format(L['Accepted automated ready check with message: "%s"'], text))
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
    Module:SendCommMessage(CommunicationEvent.EnterBattleground, PackData({}), channel, player)

    if not IsLeaderOrAssistant('player') then return end

    local config = Namespace.Database.profile.QueueTools.InspectQueue
    if config.sendMessageOnBattlegroundEntry then
        local message = concat({RaidIconChatStyle.GreenTriangle, Private.TwoLanguages('Enter'), RaidIconChatStyle.GreenTriangle}, ' ')
        SendChatMessage(Addon:PrependChatTemplate(message), channel)
    end
end

function Private.OnEnterBattleground(_, text, _, sender)
    local payload = UnpackData(text)
    sender = payload and payload.sender or sender

    local data = GetPlayerDataByName(sender)
    if not data then return end

    if data.battlegroundStatus == BattlegroundStatus.Waiting then
        data.battlegroundStatus = BattlegroundStatus.Entered
    end

    local units = data.units
    if not units.player
        and units.primary
        and Namespace.Database.profile.QueueTools.Automation.disableEntryButtonOnQueuePop
        and IsLeaderOrAssistant(units.primary)
    then
        Private.RestoreEntryButton()
    end

    Private.RefreshGroupInfoFrame()
end

function Private.RestoreEntryButton()
    local button = _G.PVPReadyDialogEnterBattleButton
    button:SetEnabled(true)
    button:SetText(Memory.disableEntryButtonOriginalText)

    if Memory.disableEntryButtonTicker == nil then return end

    Module:CancelTimer(Memory.disableEntryButtonTicker)
    Memory.disableEntryButtonTicker = nil
end

function Private.DisableEntryButton(text)
    local button = _G.PVPReadyDialogEnterBattleButton
    button:SetEnabled(false)
    button:SetText(text)

    if Memory.disableEntryButtonTicker then return end
    Memory.disableEntryButtonTicker = Module:ScheduleRepeatingTimer(function ()
        if IsShiftKeyDown() then Private.RestoreEntryButton() end
    end, 0.3)
end

function Private.OnDeclineBattleground(_, text, _, sender)
    local payload = UnpackData(text)
    sender = payload and payload.sender or sender

    local data = GetPlayerDataByName(sender)
    if not data then return end

    if data.battlegroundStatus == BattlegroundStatus.Waiting then
        data.battlegroundStatus = BattlegroundStatus.Declined
    end

    local units = data.units
    if not units.player
        and units.primary
        and Namespace.Database.profile.QueueTools.Automation.disableEntryButtonOnCancel
        and IsLeaderOrAssistant(units.primary)
    then
        Private.DisableEntryButton([[|TInterface\RaidFrame\ReadyCheck-NotReady:15|t ]] .. L['Cancel (Shift)'])
    end

    Private.RefreshGroupInfoFrame()
end

function Module:OnEnable()
    self:RegisterEvent('READY_CHECK')
    self:RegisterEvent('READY_CHECK_CONFIRM')
    self:RegisterEvent('READY_CHECK_FINISHED')
    self:RegisterEvent('PLAYER_REGEN_ENABLED')
    self:RegisterEvent('PLAYER_REGEN_DISABLED')
    self:RegisterEvent('LFG_ROLE_CHECK_SHOW')
    self:RegisterEvent('LFG_ROLE_CHECK_ROLE_CHOSEN')
    self:RegisterEvent('LFG_ROLE_CHECK_DECLINED')
    self:RegisterEvent('LFG_ROLE_CHECK_UPDATE')
    self:RegisterEvent('UNIT_CONNECTION')

    self:RegisterComm(CommunicationEvent.SyncData, Private.OnSyncData)
    self:RegisterComm(CommunicationEvent.ReadyCheckHeartbeat, Private.OnReadyCheckHeartbeat)
    self:RegisterComm(CommunicationEvent.EnterBattleground, Private.OnEnterBattleground)
    self:RegisterComm(CommunicationEvent.DeclineBattleground, Private.OnDeclineBattleground)

    Namespace.PlayerData.RegisterOnUpdate('rebuild_group_information', Private.RebuildGroupInformationTable)

    Namespace.Database.RegisterCallback(self, 'OnProfileChanged', 'RefreshConfig')
    Namespace.Database.RegisterCallback(self, 'OnProfileCopied', 'RefreshConfig')
    Namespace.Database.RegisterCallback(self, 'OnProfileReset', 'RefreshConfig')

    Namespace.Battleground.RegisterQueueStateListener('update_group_information', Private.DetectQueueEntry)
    Namespace.Battleground.RegisterQueueStateListener('protect_entry_button', Private.DetectQueuePop)
    Namespace.Battleground.RegisterQueueStateListener('rebuild_post_bg_group_info', Private.DetectBattlegroundExit)
    Namespace.Battleground.RegisterQueueStateListener('alert_queue_paused', Private.DetectQueuePause)
    Namespace.Battleground.RegisterQueueStateListener('notify_queue_resume', Private.DetectQueueResume)
    Namespace.Battleground.RegisterQueueStateListener('ensure_nobody_entered', Private.DetectQueueCancelAfterConfirm)
    Namespace.Battleground.RegisterQueueStateListener('clean_pre_bg_group_info', Private.DetectBattlegroundEntryAfterConfirm)
    Namespace.Battleground.RegisterQueueStateListener('update_mercenary_aura_tracking', Private.UpdateAuraTracking)

    Private.UpdateAuraTracking()

    self:RefreshConfig()

    local enterButton = _G.PVPReadyDialogEnterBattleButton
    enterButton:HookScript('OnClick', Private.OnClickEnterBattleground)
    Memory.disableEntryButtonOriginalText = enterButton:GetText()
end

function Module:UNIT_CONNECTION(_, unitTarget, isConnected)
    local playerData = GetPlayerDataByUnit(unitTarget)
    if not playerData then return end

    playerData.isConnected = isConnected
end

function Module:LFG_ROLE_CHECK_ROLE_CHOSEN(_, sender)
    local data = GetPlayerDataByName(sender)
    if not data then return end

    data.roleCheckStatus = RoleCheckStatus.Accepted

    if data.role == Role.Leader then
        -- The leader does not get a LFG_ROLE_CHECK_SHOW event so sync the info
        -- here for just the leader
        Private.ScheduleSendSyncData()
    end

    Private.RefreshGroupInfoFrame()
end

function Module:LFG_ROLE_CHECK_DECLINED()
    ForEachPlayerData(function(data) data.roleCheckStatus = RoleCheckStatus.Nothing end)

    Private.RefreshGroupInfoFrame()
end

function Module:LFG_ROLE_CHECK_UPDATE()
    local doRefresh = false
    ForEachUnitData(function(data)
        if data.roleCheckStatus == RoleCheckStatus.Nothing then
            data.roleCheckStatus = RoleCheckStatus.Waiting
            doRefresh = true
        end
    end)

    if not doRefresh then return end

    Private.RefreshGroupInfoFrame()
end

function Module:LFG_ROLE_CHECK_SHOW()
    local _, _, _, _, _, bgQueue = GetLFGRoleUpdate()
    if not bgQueue then return end

    -- always schedule sending your data when the queue popup happens
    -- this means the leader has more accurate information
    Private.ScheduleSendSyncData()

    if not Namespace.Database.profile.QueueTools.Automation.acceptRoleSelection then return end

    local button = _G.LFDRoleCheckPopupAcceptButton
    if not button then return end

    button:Click()
end

function Private.SendReadyCheckHeartbeat(message)
    if not Private.CanDoReadyCheck() then return end

    DoReadyCheck()
    Addon:Print(format(L['Sending automated ready check with message: "%s"'], message))
    Module:SendCommMessage(CommunicationEvent.ReadyCheckHeartbeat, PackData({ message = message }), GetMessageDestination())
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

    if Namespace.Database.profile.QueueTools.Automation.disableEntryButtonOnQueuePop
        and GetNumGroupMembers() > 1
        and not IsLeaderOrAssistant('player')
    then
        Private.DisableEntryButton([[|TInterface\RaidFrame\ReadyCheck-Waiting:15|t ]] .. L['Waiting (Shift)'])
    end

    Private.RefreshGroupInfoFrame()
end

function Private.DetectQueueEntry(previousState, newState)
    if previousState.status ~= QueueStatus.None then return end
    if newState.status ~= QueueStatus.Queued then return end

    ForEachPlayerData(function(data)
        data.battlegroundStatus = BattlegroundStatus.Nothing
        data.roleCheckStatus = RoleCheckStatus.Nothing
    end)

    Private.RestoreEntryButton()
    Private.RefreshGroupInfoFrame()
end

function Private.DetectBattlegroundExit(previousState, newState)
    if previousState.status ~= QueueStatus.Active then return end
    if newState.status ~= QueueStatus.None then return end

    RebuildPlayerData()
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

    if AllowQueuePause() then return end

    if config.sendPausedMessage then
        local message = Private.TwoLanguages('Queue paused for %s', mapName)
        if GetNumGroupMembers() == 0 then
            -- just return, you got no friends to do a ready check with anyway
            return Addon:Print(message)
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
        return Addon:Print(message)
    end

    local channel = GetMessageDestination()
    SendChatMessage(Addon:PrependChatTemplate(message), channel)
end

function Private.DetectQueueCancelAfterConfirm(previousState, newState)
    if previousState.status ~= QueueStatus.Confirm then return end
    if newState.status ~= QueueStatus.None then return end

    Module:SendCommMessage(CommunicationEvent.DeclineBattleground, PackData({}), GetMessageDestination())
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
        local message = concat({RaidIconChatStyle.RedCross, Private.TwoLanguages('Cancel'), RaidIconChatStyle.RedCross}, ' ')
        SendChatMessage(Addon:PrependChatTemplate(message), channel)
    end
end

function Private.DetectBattlegroundEntryAfterConfirm(previousState, newState)
    if previousState.status ~= QueueStatus.Confirm then return end
    if newState.status ~= QueueStatus.Active then return end

    ForEachPlayerData(function(data) data.battlegroundStatus = BattlegroundStatus.Nothing end)
end

function Module:RefreshConfig()
    Private.UpdateGroupInfoVisibility(Namespace.Database.profile.QueueTools.showGroupQueueFrame)
    Private.ScheduleSendSyncData()
end

function Private.UpdateAuraTracking()
    if UnitAffectingCombat('player') or InActiveBattleground() then
        return Module:UnregisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
    end

    -- only track outside of combat and outside of battlegrounds
    Module:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
end

function Module:PLAYER_REGEN_ENABLED()
    Private.UpdateAuraTracking()
end

function Module:PLAYER_REGEN_DISABLED()
    Private.UpdateAuraTracking()
end

function Module:COMBAT_LOG_EVENT_UNFILTERED()
    local _, _, _, _, _, _, _, _, _, _, _, spellId  = CombatLogGetCurrentEventInfo()

    if spellId ~= SpellIds.MercenaryContractHorde and spellId ~= SpellIds.MercenaryContractAlliance then return end
    Private.ScheduleSendSyncData()
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

    Private.RefreshGroupInfoFrame()
    Private.ScheduleSendSyncData()
end

function Module:READY_CHECK_CONFIRM(_, unit, ready)
    local data = GetPlayerDataByUnit(unit)
    if not data then return end

    data.readyState = ready and ReadyCheckState.Ready or ReadyCheckState.Declined

    Private.RefreshGroupInfoFrame()
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

        Private.RefreshGroupInfoFrame()
        Memory.readyCheckClearTimeout = nil
    end, 10)

    Private.RefreshGroupInfoFrame()
end

function Private.CalculateVersion(addonVersion)
    local increment, addonColor = 0, ColorList.Bad

    if addonVersion then
        increment = Namespace.Addon:ExtractVersionIncrement(addonVersion)
        local myVersion = Namespace.Meta.versionIncrement
        if myVersion == 99999 or increment == myVersion then
            addonColor = ColorList.White
        else
            addonColor = ColorList.Warning
        end
    end

    return increment, addonColor
end

function Private.InitializeGroupQueueFrame()
    local PVPUIFrame = _G.PVPUIFrame
    local queueFrame = CreateFrame('Frame', 'BgcQueueFrame', PVPUIFrame, 'ButtonFrameTemplate')
    local width = 36
    for _, header in pairs(tableStructure) do
        width = width + header.width
    end

    queueFrame:SetSize(width, PVPUIFrame:GetHeight() - 2)
    queueFrame:SetPoint('TOPLEFT', PVPUIFrame, 'TOPRIGHT', 11, 0)
    queueFrame:SetPoint('BOTTOMLEFT', PVPUIFrame, 'BOTTOMRIGHT', 11, 0)
    queueFrame:SetTitle(L['Group Information'])
    queueFrame.CloseButton:SetScript('OnClick', function ()
        Namespace.Database.profile.QueueTools.showGroupQueueFrame = false
        Private.UpdateGroupInfoVisibility(false)
        _G.BgcBattlegroundModeCheckbox:SetChecked(false)
        PlaySound(CharacterPanelCloseSound)
    end)
    queueFrame:SetPortraitToAsset([[Interface\LFGFrame\UI-LFR-PORTRAIT]])
    PVPUIFrame.QueueFrame = queueFrame

    local playerTable = ScrollingTable:CreateST(tableStructure, 14, 24, nil, queueFrame)
    playerTable.frame:SetBackdropColor(0, 0, 0, 0)
    playerTable.frame:SetBackdropBorderColor(0, 0, 0, 0)
    playerTable.frame:SetPoint('TOPLEFT', 2, -58)
    playerTable:RegisterEvents({
        onEnter = function (rowFrame, _, data, _, _, realRow, _)
            if not data[realRow] then return end

            local originalData = data[realRow].originalData
            local tooltip = _G.GameTooltip
            local classColor = originalData.classColor or {}

            local _, addonColor = Private.CalculateVersion(originalData.addonVersion)

            tooltip:SetOwner(rowFrame, 'ANCHOR_NONE')
            tooltip:SetPoint('LEFT', rowFrame, 'RIGHT')
            tooltip:ClearLines()
            tooltip:AddLine(originalData.name, classColor.r, classColor.g, classColor.b)
            tooltip:AddDoubleLine(originalData.units.primary, originalData.addonVersion or L['No Addon'], nil, nil, nil, addonColor.r, addonColor.g, addonColor.b)
            tooltip:Show()

        end,
        onLeave = function () _G.GameTooltip:Hide() end,
    }, true)

    playerTable.frame:SetScript('OnShow', function (self)
        self.refreshTimer = Module:ScheduleRepeatingTimer(Private.RefreshGroupInfoFrame, 5)
    end)
    playerTable.frame:SetScript('OnHide', function (self)
        Module:CancelTimer(self.refreshTimer)
    end)

    queueFrame.PlayerTable = playerTable

    local readyCheckButton = CreateFrame('Button', 'BgcReadyCheckButton', queueFrame, 'UIPanelButtonTemplate')
    readyCheckButton:SetText(L['Ready Check'])
    readyCheckButton:SetPoint('BOTTOM', 0, 3)
    readyCheckButton:SetSize(144, 22)
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
    settingsButton:SetScript('OnClick', function () ACD:Open(AddonName) end)

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

    local addonUsersLabel = CreateFrame('Frame', 'BgcAddonUsersLabel', queueFrame)
    addonUsersLabel:SetPoint('BOTTOMLEFT', queueFrame, 'BOTTOMLEFT', 8, 8)
    addonUsersLabel:SetSize(60, 24)

    addonUsersLabel:SetScript('OnEnter', function (self)
        local tooltip = _G.GameTooltip
        tooltip:SetOwner(self, 'ANCHOR_NONE')
        tooltip:SetPoint('BOTTOM', self, 'TOP')
        tooltip:ClearLines()

        local index = 0
        local mapped = {}
        local addonVersions = {}
        ForEachUnitData(function (data)
            local version = data.addonVersion or L['No Addon']
            if not mapped[version] then
                index = index + 1
                mapped[version] = index

                local increment, addonColor = Private.CalculateVersion(data.addonVersion)
                addonVersions[index] = {
                    increment = increment,
                    version = version,
                    color = addonColor,
                    names = { Module:GetPlayerNameForDisplay(data) },
                }
            else
                local names = addonVersions[mapped[version]].names
                names[#names + 1] = Module:GetPlayerNameForDisplay(data)
            end
        end)

        sort(addonVersions, function (left, right) return left.increment > right.increment end)

        tooltip:AddLine(L['Addon Information'])
        for _, addonVersionData in pairs(addonVersions) do
            local color = addonVersionData.color
            tooltip:AddLine(' ')
            tooltip:AddLine(format('%s:', addonVersionData.version), color.r, color.g, color.b, true)
            tooltip:AddLine(concat(addonVersionData.names, ', '), 1, 1, 1, true)
        end

        tooltip:Show()
    end)

    addonUsersLabel:SetScript('OnLeave',  function () _G.GameTooltip:Hide() end)

    local addonUsersLabelText = addonUsersLabel:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
    addonUsersLabelText:SetPoint('BOTTOMLEFT')
    addonUsersLabelText:SetWordWrap(false)

    addonUsersLabel.Text = addonUsersLabelText
    queueFrame.AddonUsersLabel = addonUsersLabel
end

function Module:ADDON_LOADED(_, addonName)
    if addonName == 'Blizzard_PVPUI' then
        Private.InitializeAutoQueueCheckbox()
        Private.InitializeBattlegroundModeCheckbox()
        Private.InitializeGroupQueueFrame()
        _G.PVPUIFrame:HookScript('OnShow', function ()
            Private.UpdateGroupInfoVisibility(Namespace.Database.profile.QueueTools.showGroupQueueFrame)
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
        if _G.BgcAutoQueueCheckbox then
            _G.BgcAutoQueueCheckbox:SetChecked(value)
        end
        return Private.ScheduleSendSyncData()
    end

    Automation[setting] = value
end

function Module:GetAutomationSetting(setting)
    return Namespace.Database.profile.QueueTools.Automation[setting]
end

function Module:SetGroupInfoSetting(setting, value)
    Namespace.Database.profile.QueueTools.GroupInfo[setting] = value

    Private.RefreshGroupInfoFrame()
end

function Module:GetGroupInfoSetting(setting)
    return Namespace.Database.profile.QueueTools.GroupInfo[setting]
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

function Module:GetPlayerNameForDisplay(data)
    local name = data.name
    if name == UNKNOWNOBJECT then return '...' end

    local nickname = Namespace.BattlegroundTools:GetPlayerConfigValue(name, 'playerNickname')
    if nickname ~= nil and nickname ~= '' then return nickname end

    local nameFormat = self:GetGroupInfoSetting('nameFormat')

    if nameFormat == NameFormat.RealmAlways then return name end
    if nameFormat == NameFormat.RealmNever then return data.firstName or name end
    if nameFormat == NameFormat.RealmWhenPlayer then
        if data.units.player then return data.firstName end
        if data.firstName and data.realmName and data.firstName ~= UNKNOWNOBJECT then
            local player = GetPlayerDataByUnit('player')
            if player and player.realmName == data.realmName then
                return data.firstName
            end
        end
    end

    return name
end