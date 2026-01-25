local _G, ModuleName, Private, AddonName, Namespace = _G, 'BattlegroundTools', {}, ...
local Addon = Namespace.Addon
local Module = Addon:NewModule(ModuleName, 'AceEvent-3.0', 'AceTimer-3.0')
local L = Namespace.Libs.AceLocale:GetLocale(AddonName)
local LSM = Namespace.Libs.LibSharedMedia
local LibDD = Namespace.Libs.LibDropDown

Namespace.BattlegroundTools = Module

local Channel = Namespace.Communication.Channel
local GetGroupLeaderData = Namespace.PlayerData.GetGroupLeaderData
local GetPlayerDataByUnit = Namespace.PlayerData.GetPlayerDataByUnit
local GetPlayerDataByName = Namespace.PlayerData.GetPlayerDataByName
local Role = Namespace.PlayerData.Role
local GetMessageDestination = Namespace.Communication.GetMessageDestination
local GroupType = Namespace.Utils.GroupType
local GetGroupType = Namespace.Utils.GetGroupType
local ForEachUnitData = Namespace.PlayerData.ForEachUnitData
local InActiveBattleground = Namespace.Battleground.InActiveBattleground
local QueueStatus = Namespace.Battleground.QueueStatus
local CreateFrame = CreateFrame
local FlashClientIcon = FlashClientIcon
local CreateColor = CreateColor
local PromoteToLeader = PromoteToLeader
local PromoteToAssistant = PromoteToAssistant
local DemoteAssistant = DemoteAssistant
local PlaySound = PlaySound
local UnitIsGroupLeader = UnitIsGroupLeader
local SendChatMessage = SendChatMessage
local UISpecialFrames = UISpecialFrames
local ReadyCheckSound = SOUNDKIT.READY_CHECK
local ActivateWarmodeSound = SOUNDKIT.UI_WARMODE_ACTIVATE
local DeactivateWarmodeSound = SOUNDKIT.UI_WARMODE_DECTIVATE
local UNKNOWNOBJECT = UNKNOWNOBJECT
local format = string.format
local pairs = pairs
local tinsert = tinsert

local GiveLeadStatus = {
    None = 0,
    RecentlyAccepted = 1,
    RecentlyRejected = 2,
}

local Memory = {
    currentZoneId = nil,

    WantBattlegroundLead = {
        DialogFrame = nil,
        dropdownSelection = {},
        giveLeadStatus = {},
        ackTimer = nil,
        ackLeader = nil,
    },
}

local GiveLeadBehavior = {
    NoAutomation = 0,
    GiveLead = 1,
    RejectLead = 2,
    OverrideLead = 3,
}

Namespace.BattlegroundTools.GiveLeadBehavior = GiveLeadBehavior

function Module:TriggerUpdateWantBattlegroundLeadDialogFrame(newVisibility)
    local mem = Memory.WantBattlegroundLead
    local dialog = mem.DialogFrame
    if not dialog then return end

    local dropdown = dialog.Dropdown
    local lastName
    local count = 0
    LibDD:UIDropDownMenu_Initialize(dropdown, function ()
        ForEachUnitData(function(data)
            local name = data.name
            if not data.wantLead or data.units.player then
                mem.dropdownSelection[name] = nil
                return
            end

            local recentlyRejected = mem.giveLeadStatus[name] == GiveLeadStatus.RecentlyRejected
            if recentlyRejected or mem.dropdownSelection[name] == nil then
                mem.dropdownSelection[name] = false
            end

            local visibleName = Namespace.QueueTools:GetPlayerNameForDisplay(data)
            lastName = CreateColor(data.classColor.r, data.classColor.g, data.classColor.b, data.classColor.a):WrapTextInColorCode(visibleName)
            count = count + 1

            local info = LibDD:UIDropDownMenu_CreateInfo()
            info.text = lastName
            info.checked = mem.dropdownSelection[name]
            info.isNotRadio = true
            info.keepShownOnClick = true
            info.arg1 = name
            info.arg2 = data.units.primary
            info.func = dialog.Dropdown.OnSelect
            LibDD:UIDropDownMenu_AddButton(info)
        end)
    end)

    local message
    if count == 1 then
        LibDD:UIDropDownMenu_SetWidth(dropdown, 230)
        message = format(L['%s is requesting lead'], lastName)
    else
        LibDD:UIDropDownMenu_SetWidth(dropdown, 190)
        message = format(L['%d people requested lead'], count)
    end

    LibDD:UIDropDownMenu_SetText(dropdown, message)

    Private.UpdateAcceptRejectButtonState()

    if newVisibility ~= nil then
        dialog:SetShown(newVisibility)
    end
end

function Private.RequestRaidLeadListener(_, _, newRole)
    if newRole ~= Role.Leader then return end

    Module:RequestRaidLead()
end

function Private.PlayLeaderSoundListener(playerData, oldRole, newRole)
    if not playerData.units.player then return end
    if not Namespace.Database.profile.BattlegroundTools.LeaderTools.leaderSound then return end
    if not InActiveBattleground() then return end

    if oldRole and newRole == Role.Leader then
        PlaySound(ActivateWarmodeSound)
    elseif newRole and oldRole == Role.Leader then
        PlaySound(DeactivateWarmodeSound)
    end
end

--- this listener in specific deals with automatic promotion and demotion of players when PLAYER gets lead
function Private.PromoteAssistantsWhenPlayerBecomesLeaderListener(playerData, _, newRole)
    if newRole ~= Role.Leader or not playerData.units.player then return end
    if not InActiveBattleground() then return end

    local demoteUnlisted = Namespace.Database.profile.BattlegroundTools.LeaderTools.demoteUnlisted
    ForEachUnitData(function (data)
        if data.role == Role.Member and Module:GetPlayerConfigValue(data.name, 'promoteToAssistant') then
            PromoteToAssistant(data.units.primary)
        elseif demoteUnlisted and data.role == Role.Assist and not Module:GetPlayerConfigValue(data.name, 'promoteToAssistant') then
            DemoteAssistant(data.units.primary)
        end
    end)
end

function Private.TriggerUpdateWantBattlegroundLeadDialogFrameAfterRoleChange(playerData)
    if not playerData.units.player then return end

    Module:TriggerUpdateWantBattlegroundLeadDialogFrame()
end

--- this listener in specific deals with new members becoming assistant
function Private.PromoteNewMemberToAssistantListener(playerData, oldRole, newRole)
    if oldRole or newRole ~= Role.Member or playerData.units.player then return end

    if not InActiveBattleground() then return end

    local leader = GetGroupLeaderData()
    if not leader or not leader.units.player then return end

    if Module:GetPlayerConfigValue(playerData.name, 'promoteToAssistant') then
        PromoteToAssistant(playerData.name)
    end
end

function Private.UpdatePlayerConfigLabels(unitPlayerData)
    local updated = false
    for _, playerData in pairs(unitPlayerData) do
        if playerData.classColor then
            local config = Module:GetPlayerConfig(playerData.name)

            if config and config.playerName == config.groupLabel then
                config.groupLabel = playerData.classColor:WrapTextInColorCode(playerData.name)
                updated = true
            end
        end
    end

    if not updated then return end

    Addon:InitializePlayerConfig()
end

function Private.DetectBattlegroundExit(previousState, newState)
    if previousState.status ~= QueueStatus.Active then return end
    if newState.status ~= QueueStatus.None then return end

    Memory.WantBattlegroundLead.giveLeadStatus = {}
    Memory.WantBattlegroundLead.ackLeader = nil

    Module:TriggerUpdateWantBattlegroundLeadDialogFrame(false)
end

function Private.DetectBattlegroundEntryAfterConfirm(previousState, newState)
    if previousState.status ~= QueueStatus.Confirm then return end
    if newState.status ~= QueueStatus.Active then return end

    Memory.WantBattlegroundLead.giveLeadStatus = {}
    Memory.WantBattlegroundLead.ackLeader = nil

    Module:RequestRaidLead()
end

function Module:OnEnable()
    self:RegisterEvent('PLAYER_ENTERING_WORLD')

    Namespace.Database.RegisterCallback(self, 'OnProfileChanged', 'RefreshConfig')
    Namespace.Database.RegisterCallback(self, 'OnProfileCopied', 'RefreshConfig')
    Namespace.Database.RegisterCallback(self, 'OnProfileReset', 'RefreshConfig')

    Private.InitializeBattlegroundLeaderDialog()

    Namespace.PlayerData.RegisterOnRoleChange('request_raid_lead', Private.RequestRaidLeadListener)
    Namespace.PlayerData.RegisterOnRoleChange('play_leader_sound', Private.PlayLeaderSoundListener)
    Namespace.PlayerData.RegisterOnRoleChange('promote_assistant_when_player_becomes_leader', Private.PromoteAssistantsWhenPlayerBecomesLeaderListener)
    Namespace.PlayerData.RegisterOnRoleChange('update_want_lead_dialog', Private.TriggerUpdateWantBattlegroundLeadDialogFrameAfterRoleChange)
    Namespace.PlayerData.RegisterOnRoleChange('promote_new_member_to_assistant', Private.PromoteNewMemberToAssistantListener)

    Namespace.PlayerData.RegisterOnUpdate('update_player_config_labels', Private.UpdatePlayerConfigLabels)

    Namespace.Battleground.RegisterQueueStateListener('update_leader_status', Private.DetectBattlegroundExit)
    Namespace.Battleground.RegisterQueueStateListener('clean_pre_bg_raid_lead_info', Private.DetectBattlegroundEntryAfterConfirm)

    self:RefreshConfig()

    Namespace.Libs.LibDropDownExtension:RegisterEvent('OnShow OnHide', function (dropdown, event, options)
        local data = dropdown.unit and GetPlayerDataByUnit(dropdown.unit)
        if not data then return end

        if event == 'OnShow' then
            options[1] = {
                text = L['BGC: Configure'],
                func = function ()
                    Namespace.Config.AddPlayerConfig(data.name)
                    Addon:OpenPlayerConfig(data.name, true)
                end
            }
            return true
        elseif event == 'OnHide' then
            options[1] = nil
        end
    end, 1)
end

function Module:PLAYER_ENTERING_WORLD(_, isLogin, isReload)
    if not isLogin and not isReload then return end

    self:RequestRaidLead()
end

function Module:RefreshConfig()
    self:TriggerUpdateWantBattlegroundLeadDialogFrame()
end

function Private.CanRequestLead()
    if not Namespace.Database.profile.BattlegroundTools.WantBattlegroundLead.wantLead then return false end
    if UnitIsGroupLeader('player') then return false end

    return InActiveBattleground()
end

function Private.PromoteToLeader(playerData)
    if not playerData.units.primary then return end

    PromoteToLeader(playerData.units.primary)

    local mem = Memory.WantBattlegroundLead
    mem.giveLeadStatus[playerData.name] = GiveLeadStatus.RecentlyAccepted

    if not mem.DialogFrame then return end
    mem.DialogFrame:Hide()
end

function Module:WantBattlegroundLead(senderData)
    if not InActiveBattleground() then
        return self:TriggerUpdateWantBattlegroundLeadDialogFrame()
    end

    local playerData = GetPlayerDataByUnit('player')
    if playerData == senderData or playerData.role ~= Role.Leader then
        return self:TriggerUpdateWantBattlegroundLeadDialogFrame()
    end

    local channel = GetMessageDestination()
    if channel == Channel.Whisper then
        return self:TriggerUpdateWantBattlegroundLeadDialogFrame()
    end

    local config = Namespace.Database.profile.BattlegroundTools.WantBattlegroundLead
    local mem = Memory.WantBattlegroundLead
    local sender = senderData.name
    local giveLeadBehavior = self:GetPlayerConfigValue(sender, 'giveLeadBehavior')

    if giveLeadBehavior == GiveLeadBehavior.RejectLead or mem.giveLeadStatus[sender] == GiveLeadStatus.RecentlyRejected then
        return self:TriggerUpdateWantBattlegroundLeadDialogFrame()
    end

    if config.wantLead and giveLeadBehavior ~= GiveLeadBehavior.OverrideLead then
        return self:TriggerUpdateWantBattlegroundLeadDialogFrame()
    end

    if giveLeadBehavior == GiveLeadBehavior.GiveLead or giveLeadBehavior == GiveLeadBehavior.OverrideLead then
        Private.PromoteToLeader(senderData)
        Addon:Print(format(L['Automatically giving lead to %s'], sender))

        return self:TriggerUpdateWantBattlegroundLeadDialogFrame()
    end

    if mem.DialogFrame and not mem.DialogFrame:IsVisible() then
        PlaySound(ReadyCheckSound)
        FlashClientIcon()
    end

    self:TriggerUpdateWantBattlegroundLeadDialogFrame(true)
end

function Private.SendManualChatMessages()
    if C_ChatInfo.InChatMessagingLockdown() then return end

    local mem = Memory.WantBattlegroundLead
    local config = Namespace.Database.profile.BattlegroundTools.WantBattlegroundLead

    mem.ackTimer = nil
    if not config.enableManualRequest or not Private.CanRequestLead() then return end

    local groupLeader = GetGroupLeaderData()
    if not groupLeader or groupLeader.addonVersion then return end

    local name = groupLeader.name
    if name == UNKNOWNOBJECT then return end

    local message = config.manualRequestMessage:gsub('{leader}', name)
    if config.sendWhisper then SendChatMessage(message, Channel.Whisper, nil, name) end
    if config.sendSay then SendChatMessage(message, Channel.Say) end

    if config.sendRaid then
        local groupType = GetGroupType()
        if groupType == GroupType.Raid then SendChatMessage(message, Channel.Raid) end
        if groupType == GroupType.InstanceRaid then SendChatMessage(message, Channel.Instance) end
    end
end

function Module:RequestRaidLead()
    Namespace.QueueTools:ScheduleSendSyncData()

    if not Private.CanRequestLead() then return end
    if GetMessageDestination() == Channel.Whisper then return end

    local mem = Memory.WantBattlegroundLead
    if Namespace.Database.profile.BattlegroundTools.WantBattlegroundLead.enableManualRequest then
        local groupLeader = GetGroupLeaderData()
        if groupLeader and not groupLeader.addonVersion and (mem.ackLeader == nil or groupLeader.name ~= mem.ackLeader) then
            -- re-buffer the timer each time the leader changes to give them enough time to reply
            if mem.ackTimer then Module:CancelTimer(mem.ackTimer) end

            mem.ackLeader = groupLeader.name
            mem.ackTimer = Module:ScheduleTimer(Private.SendManualChatMessages, 5)
        end
    end
end

function Private.ProcessDropDownOptions(onPlayerSelected)
    local mem = Memory.WantBattlegroundLead
    local found = 0
    local total = 0
    local lastData
    local players = {}
    for name, isChecked in pairs(mem.dropdownSelection) do
        local data = GetPlayerDataByName(name)
        if data and data.wantLead then
            found = found + 1
            lastData = data
            if isChecked then
                total = total + 1
                players[total] = data
            end
        end
    end

    if found == 1 and total == 0 then
        -- automatically select the only option without having to select it
        players[1] = lastData
    end

    for _, data in pairs(players) do
        if onPlayerSelected(data) then break end
    end
end

function Private.AcceptManualBattlegroundLeaderRequest()
    local mem = Memory.WantBattlegroundLead
    local remember = mem.DialogFrame.RememberNameCheckbox:GetChecked()

    Private.ProcessDropDownOptions(function (data)
        if remember then Module:SetPlayerConfigValue(data.name, 'giveLeadBehavior', GiveLeadBehavior.GiveLead) end

        Private.PromoteToLeader(data)

        return false -- only ever attempt once
    end)

    Module:TriggerUpdateWantBattlegroundLeadDialogFrame()
end

function Private.RejectManualBattlegroundLeaderRequest()
    local mem = Memory.WantBattlegroundLead
    local remember = mem.DialogFrame.RememberNameCheckbox:GetChecked()
    Private.ProcessDropDownOptions(function (data)
        mem.giveLeadStatus[data.name] = GiveLeadStatus.RecentlyRejected

        if remember then Module:SetPlayerConfigValue(data.name, 'giveLeadBehavior', GiveLeadBehavior.RejectLead) end

        return false
    end)

    Module:TriggerUpdateWantBattlegroundLeadDialogFrame()
end

function Private.UpdateAcceptRejectButtonState()
    local frame = Memory.WantBattlegroundLead.DialogFrame
    if not frame then return end

    if GetPlayerDataByUnit('player').role ~= Role.Leader then
        frame.AcceptButton:SetEnabled(false)
        frame.RejectButton:SetEnabled(false)

        return
    end

    local possibilities = 0
    Private.ProcessDropDownOptions(function ()
        possibilities = possibilities + 1

        if possibilities > 1 then return true end
    end)

    frame.AcceptButton:SetEnabled(possibilities == 1)
    frame.RejectButton:SetEnabled(possibilities > 0)
end

function Private.InitializeBattlegroundLeaderDialog()
    local dialog = CreateFrame('Frame', 'BgcBattlegroundLeaderDialog', _G.UIParent, _G.BackdropTemplateMixin and 'BackdropTemplate')
    dialog:SetSize(320, 160)
    dialog:SetFrameStrata('DIALOG')
    dialog:SetPoint('TOP', _G.UIParent, 'TOP', 0, -300)
    dialog:SetMovable(true)
    dialog:SetClampedToScreen(true)
    dialog:SetBackdrop({
        bgFile = LSM:Fetch('background', 'Blizzard Dialog Background Dark'),
        edgeFile = LSM:Fetch('border', 'Blizzard Dialog'),
        tile = true,
        tileSize = 20,
        edgeSize = 20,
        insets = {
            left = 5,
            right = 5,
            top = 5,
            bottom = 5,
        }
    })
    dialog:SetBackdropColor(0.5, 0.5, 0.5, 1)
    dialog:SetBackdropBorderColor(0.7, 0.7, 0.7, 1)
    dialog:SetScript('OnMouseDown', function(self) self:StartMoving() end)
    dialog:SetScript('OnMouseUp', function(self) self:StopMovingOrSizing() end)

    tinsert(UISpecialFrames, dialog:GetName());

    local dialogText = dialog:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
    dialogText:SetText(L['Lead Requested'])
    dialogText:SetPoint('TOP', 0, -12)
    dialogText:SetPoint('LEFT', 0, 0)
    dialogText:SetPoint('RIGHT', 0, 0)

    local dropdown = LibDD:Create_UIDropDownMenu('BgcSelectLeaderDropDown', dialog)
    dropdown:SetPoint('CENTER', dialog, 'CENTER', 0, 10)

    function dropdown:OnSelect(name, _, checked)
        Memory.WantBattlegroundLead.dropdownSelection[name] = checked

        Private.UpdateAcceptRejectButtonState()
    end

    local acceptButton = CreateFrame('Button', nil, dialog, 'UIPanelButtonTemplate')
    acceptButton:SetSize(110, 24)
    acceptButton:SetText('Accept')
    acceptButton:SetPoint('BOTTOMRIGHT', dialog, 'BOTTOM', -2, 8)
    acceptButton:SetScript('OnClick', Private.AcceptManualBattlegroundLeaderRequest)

    local rejectButton = CreateFrame('Button', nil, dialog, 'UIPanelButtonTemplate')
    rejectButton:SetSize(110, 24)
    rejectButton:SetText('Reject')
    rejectButton:SetPoint('BOTTOMLEFT', dialog, 'BOTTOM', 2, 8)
    rejectButton:SetScript('OnClick', Private.RejectManualBattlegroundLeaderRequest)

    local checkbox = CreateFrame('CheckButton', nil, dialog, 'UICheckButtonTemplate')
    local checkboxLabel = checkbox:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
    checkbox:SetPoint('RIGHT', checkboxLabel, 'LEFT', 0, 0)
    checkbox:SetSize(24, 24)
    checkboxLabel:SetText('Remember this choice')
    checkboxLabel:SetPoint('BOTTOM', dialog, 'BOTTOM', 0, 42)

    local closeButton = CreateFrame('Button', nil, dialog, 'UIPanelCloseButton')
    closeButton:SetPoint('TOPRIGHT', dialog, 'TOPRIGHT', -2, -2)

    dialog.Text = dialogText
    dialog.Dropdown = dropdown
    dialog.AcceptButton = acceptButton
    dialog.RejectButton = rejectButton
    dialog.RememberNameCheckbox = checkbox
    dialog.closeButton = closeButton

    Memory.WantBattlegroundLead.DialogFrame = dialog

    dialog:Hide()
end

function Module:SetWantLeadSetting(key, table)
    Namespace.Database.profile.BattlegroundTools.WantBattlegroundLead[key] = table
end

function Module:GetWantLeadSetting(key)
    return Namespace.Database.profile.BattlegroundTools.WantBattlegroundLead[key]
end

function Module:SetLeaderToolsSetting(key, value)
    local config = Namespace.Database.profile.BattlegroundTools.LeaderTools

    config[key] = value
end

function Module:GetLeaderToolsSetting(key)
    return Namespace.Database.profile.BattlegroundTools.LeaderTools[key]
end

function Module:GetPlayerConfig(playerName)
    return Namespace.Database.profile.BattlegroundTools.PlayerManagement[playerName]
end

function Module:GetPlayerConfigValue(playerName, configName)
    local config = Namespace.Database.profile.BattlegroundTools.PlayerManagement[playerName]
    if not config then return nil end

    return config[configName]
end

function Module:SetPlayerConfigValue(playerName, configName, value)
    local config = Namespace.Database.profile.BattlegroundTools.PlayerManagement[playerName] or self:CreatePlayerConfig(playerName)

    config[configName] = value
end

function Module:CreatePlayerConfig(playerName)
    local config = Namespace.Database.profile.BattlegroundTools

    config.playerManagementIndex = config.playerManagementIndex + 1

    local playerConfig = {
        playerName = playerName,
        playerNickname = '',
        groupLabel = playerName,
        giveLeadBehavior = GiveLeadBehavior.NoAutomation,
        promoteToAssistant = false,
        sortOrderIndex = config.playerManagementIndex
    }

    config.PlayerManagement[playerName] = playerConfig

    return playerConfig
end

function Module:DeletePlayerConfig(playerName)
    Namespace.Database.profile.BattlegroundTools.PlayerManagement[playerName] = nil
end

function Module:GetAllPlayerConfig()
    return Namespace.Database.profile.BattlegroundTools.PlayerManagement
end
