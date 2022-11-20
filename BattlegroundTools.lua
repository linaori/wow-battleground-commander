local _G, ModuleName, Private, AddonName, Namespace = _G, 'BattlegroundTools', {}, ...
local Addon = Namespace.Addon
local Module = Addon:NewModule(ModuleName, 'AceEvent-3.0', 'AceTimer-3.0', 'AceComm-3.0')
local L = Namespace.Libs.AceLocale:GetLocale(AddonName)
local LSM = Namespace.Libs.LibSharedMedia
local LibDD = Namespace.Libs.LibDropDown

Namespace.BattlegroundTools = Module

local Channel = Namespace.Communication.Channel
local GetGroupLeaderData = Namespace.PlayerData.GetGroupLeaderData
local GetPlayerDataByUnit = Namespace.PlayerData.GetPlayerDataByUnit
local Role = Namespace.PlayerData.Role
local GetMessageDestination = Namespace.Communication.GetMessageDestination
local GroupType = Namespace.Utils.GroupType
local GetGroupType = Namespace.Utils.GetGroupType
local ForEachUnitData = Namespace.PlayerData.ForEachUnitData
local InActiveBattleground = Namespace.Battleground.InActiveBattleground
local QueueStatus = Namespace.Battleground.QueueStatus
local Zones = Namespace.Battleground.Zones
local GetCurrentZoneId = Namespace.Battleground.GetCurrentZoneId
local CreateFrame = CreateFrame
local FlashClientIcon = FlashClientIcon
local GetTime = GetTime
local ReplaceIconAndGroupExpressions = C_ChatInfo.ReplaceIconAndGroupExpressions
local GetRealUnitName = Namespace.Utils.GetRealUnitName
local PromoteToLeader = PromoteToLeader
local PromoteToAssistant = PromoteToAssistant
local DemoteAssistant = DemoteAssistant
local PlaySound = PlaySound
local UnitIsGroupLeader = UnitIsGroupLeader
local SendChatMessage = SendChatMessage
local SetRaidTarget = SetRaidTarget
local ReadyCheckSound = SOUNDKIT.READY_CHECK
local ActivateWarmodeSound = SOUNDKIT.UI_WARMODE_ACTIVATE
local DeactivateWarmodeSound = SOUNDKIT.UI_WARMODE_DECTIVATE
local UNKNOWNOBJECT = UNKNOWNOBJECT
local concat = table.concat
local format = string.format
local floor = math.floor
local min = math.min
local pairs = pairs
local TimeDiff = Namespace.Utils.TimeDiff

local CommunicationEvent = {
    WantBattlegroundLead = 'bgc:wantLead',
    AcknowledgeWantBattlegroundLead = 'bgc:wantLeadAck',
}

local Memory = {
    currentZoneId = nil,

    WantBattlegroundLead = {
        wantLeadTimer = nil,
        DialogFrame = nil,
        dropdownSelection = {},
        requestedBy = {},
        recentlyRejected = {},
        requestedByCount = 0,
        ackTimer = nil,
        ackLeader = nil,
    },

    InstructionFrame = nil,
    RaidWarningLogs = {
        last = nil,
        list = {
            -- {time, message},
        },
        size = 0,
        timer = nil,
    },
}

function Private.ApplyFont(textObject, fontConfig)
    textObject:SetFont(LSM:Fetch('font', fontConfig.family), fontConfig.size, fontConfig.flags)
    textObject:SetTextColor(fontConfig.color.r, fontConfig.color.g, fontConfig.color.b)
    textObject:SetShadowColor(fontConfig.shadowColor.r, fontConfig.shadowColor.g, fontConfig.shadowColor.b, fontConfig.shadowColor.a)
    textObject:SetShadowOffset(fontConfig.shadowOffset.x, fontConfig.shadowOffset.y)
    textObject:SetJustifyH('LEFT')
    textObject:SetJustifyV(fontConfig.topToBottom and 'TOP' or 'BOTTOM')
end

function Private.ApplyFrameSettings()
    local settings = Namespace.Database.profile.BattlegroundTools.InstructionFrame.settings
    local frame = Memory.InstructionFrame
    frame:SetBackdrop({
        bgFile = LSM:Fetch('background', settings.backgroundTexture),
        edgeFile = LSM:Fetch('border', settings.borderTexture),
        edgeSize = settings.borderSize,
        insets = {
            left = settings.backgroundInset,
            right = settings.backgroundInset,
            top = settings.backgroundInset,
            bottom = settings.backgroundInset,
        }
    })

    local bgColor = settings.backgroundColor
    local borderColor = settings.borderColor

    frame:SetBackdropColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
    frame:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
end

function Module:SetFontSetting(setting, value)
    local fontConfig = Namespace.Database.profile.BattlegroundTools.InstructionFrame.font
    fontConfig[setting] = value

    Private.ApplyFont(Memory.InstructionFrame.Text, fontConfig)
end

function Module:GetFontSetting(setting)
    return Namespace.Database.profile.BattlegroundTools.InstructionFrame.font[setting]
end

function Module:SetFrameSetting(setting, value)
    Namespace.Database.profile.BattlegroundTools.InstructionFrame.settings[setting] = value
    Private.ApplyFrameSettings()
end

function Module:GetFrameSetting(setting)
    return Namespace.Database.profile.BattlegroundTools.InstructionFrame.settings[setting]
end

function Private.ResetLogs()
    local logs = Memory.RaidWarningLogs
    logs.last = nil
    logs.list = {}
    logs.size = 0
end

function Private.AddLog(message)
    local logs = Memory.RaidWarningLogs
    if message == logs.last then
        logs.list[logs.size].time = floor(GetTime())
        return
    end

    logs.size = logs.size + 1
    logs.list[logs.size] = {
        time = GetTime(),
        message = ReplaceIconAndGroupExpressions(message),
    }
    logs.last = message
end

function Private.ApplyLogs(textObject)
    local frameConfig = Namespace.Database.profile.BattlegroundTools.InstructionFrame
    local colorHighlight = frameConfig.font.colorHighlight
    local colorTime = frameConfig.font.colorTime
    local maxInstructions = frameConfig.settings.maxInstructions

    local count, directionModifier
    if frameConfig.font.topToBottom then
        count = 0
        directionModifier = 1
    else
        count = min(maxInstructions, Memory.RaidWarningLogs.size) + 1
        directionModifier = -1
    end

    local timePrefix = format('|cff%.2x%.2x%.2x', colorTime.r * 255, colorTime.g * 255, colorTime.b * 255)
    local now = floor(GetTime())
    local list = Memory.RaidWarningLogs.list
    local messages = {}
    for i = Memory.RaidWarningLogs.size, Memory.RaidWarningLogs.size - maxInstructions + 1, -1 do
        count = count + directionModifier
        local log = list[i]
        if not log then break end

        local diff = TimeDiff(now, log.time)
        if i == Memory.RaidWarningLogs.size then
            log = concat({
                timePrefix,
                diff.format(),
                '|r ',
                format('|cff%.2x%.2x%.2x', colorHighlight.r * 255, colorHighlight.g * 255, colorHighlight.b * 255),
                log.message,
                '|r',
            })
        else
            log = concat({ timePrefix, diff.format(), '|r ', log.message })
        end

        messages[count] = log
    end

    textObject:SetText(concat(messages, "\n"))
end

function Private.InitializeInstructionFrame()
    if Memory.InstructionFrame then return Memory.InstructionFrame end

    local instructionFrame = CreateFrame('Frame', 'bgcInstructionFrame', _G.UIParent, _G.BackdropTemplateMixin and 'BackdropTemplate')
    instructionFrame:SetFrameStrata('LOW')
    instructionFrame:SetResizeBounds(100, 50)
    instructionFrame:SetClampedToScreen(true)
    instructionFrame:SetMovable(true)
    instructionFrame:RegisterForDrag('LeftButton')
    instructionFrame:SetResizable(true)

    local moveOverlay = CreateFrame('Button', nil, instructionFrame)
    moveOverlay:SetPoint('TOPLEFT')
    moveOverlay:SetPoint('BOTTOMRIGHT', -16, 0)
    moveOverlay:SetScript('OnMouseDown', function(self)
        if not Namespace.Database.profile.BattlegroundTools.InstructionFrame.move then return end
        self:GetParent():StartMoving()
    end)
    moveOverlay:SetScript('OnMouseUp', function(self)
        local parent = self:GetParent()
        parent:StopMovingOrSizing()

        local position = Namespace.Database.profile.BattlegroundTools.InstructionFrame.position
        local anchor, _, _, x, y = parent:GetPoint(1)

        position.anchor, position.x, position.y = anchor, x, y
    end)

    local resizeButton = CreateFrame('Button', nil, instructionFrame)
    resizeButton:SetPoint('BOTTOMRIGHT')
    resizeButton:SetSize(16, 16)
    resizeButton:SetNormalTexture([[Interface\ChatFrame\UI-ChatIM-SizeGrabber-Down]])
    resizeButton:SetHighlightTexture([[Interface\ChatFrame\UI-ChatIM-SizeGrabber-Highlight]])
    resizeButton:SetPushedTexture([[Interface\ChatFrame\UI-ChatIM-SizeGrabber-Up]])
    resizeButton:SetScript('OnMouseDown', function(self)
        self:GetParent():StartSizing('BOTTOMRIGHT')
    end)
    resizeButton:SetScript('OnMouseUp', function(self)
        local parent = self:GetParent()
        parent:StopMovingOrSizing()
        local size = Namespace.Database.profile.BattlegroundTools.InstructionFrame.size
        size.width, size.height = parent:GetSize()
    end)

    local text = instructionFrame:CreateFontString(nil, 'OVERLAY')
    Private.ApplyFont(text, Namespace.Database.profile.BattlegroundTools.InstructionFrame.font)
    text:SetPoint('TOPLEFT', 7, -7)
    text:SetPoint('BOTTOMRIGHT', -17, 7)

    instructionFrame.MoveOverlay = moveOverlay
    instructionFrame.ResizeButton = resizeButton
    instructionFrame.Text = text

    Memory.InstructionFrame = instructionFrame
end

function Module:OnInitialize()
    self:RegisterEvent('ADDON_LOADED')

    Private.InitializeInstructionFrame()
end

function Private.TriggerUpdateWantBattlegroundLeadDialogFrame(forceHide)
    local mem = Memory.WantBattlegroundLead
    local dialog = mem.DialogFrame
    if not dialog then return end

    -- when PromoteToLeader is called in the same update as UnitIsGroupLeader, it still returns true :(
    if forceHide or mem.requestedByCount == 0 or not UnitIsGroupLeader('player') then
        return dialog:SetShown(false)
    end

    dialog:SetShown(true)

    local dropdown = dialog.Dropdown
    local lastName
    local count = 0
    LibDD:UIDropDownMenu_Initialize(dropdown, function ()
        for name, _ in pairs(mem.requestedBy) do
            if not mem.dropdownSelection[name] then
                mem.dropdownSelection[name] = false
            end

            lastName = name
            count = count + 1

            local info = LibDD:UIDropDownMenu_CreateInfo()
            info.text = name
            info.checked = mem.dropdownSelection[name]
            info.isNotRadio = true
            info.keepShownOnClick = true
            info.arg1 = name
            info.func = dialog.Dropdown.OnSelect
            LibDD:UIDropDownMenu_AddButton(info)
        end
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
end

function Private.TriggerUpdateInstructionFrame()
    local frameConfig = Namespace.Database.profile.BattlegroundTools.InstructionFrame
    local currentZoneId = GetCurrentZoneId()
    if frameConfig.show and frameConfig.zones[currentZoneId] then
        Module:ShowInstructionsFrame()
    else
        Module:HideInstructionsFrame()
    end
end

function Private.RequestRaidLeadListener(_, _, newRole)
    if newRole ~= Role.Leader then return end

    Private.RequestRaidLead()
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

function Private.UpdateRaidLeaderIconListener(playerData, _, newRole)
    if newRole ~= Role.Leader or not playerData.units.player then return end
    if not InActiveBattleground() then return end

    SetRaidTarget('player', Namespace.Database.profile.BattlegroundTools.LeaderTools.leaderIcon)

    Private.MarkRaidMembers()
end

--- this listener in specific deals with automatic promotion and demotion of players when PLAYER gets lead
function Private.PromoteAssistantsWhenPlayerBecomesLeaderListener(playerData, _, newRole)
    if newRole ~= Role.Leader or not playerData.units.player then return end
    if not InActiveBattleground() or GetGroupType() ~= GroupType.InstanceRaid then return end

    local leaderTools = Namespace.Database.profile.BattlegroundTools.LeaderTools
    local automaticAssist = leaderTools.automaticAssist
    local demoteUnlisted = leaderTools.demoteUnlisted
    local promoteListed = leaderTools.promoteListed

    if not promoteListed and not demoteUnlisted then return end

    ForEachUnitData(function (data)
        if promoteListed and data.role == Role.Member and automaticAssist[data.name] then
            PromoteToAssistant(data.units.primary)
        elseif demoteUnlisted and data.role == Role.Assist and not automaticAssist[data.name] then
            DemoteAssistant(data.units.primary)
        end
    end)
end

--- this listener in specific deals with new members becoming assistant
function Private.PromoteNewMemberToAssistantListener(playerData, oldRole, newRole)
    if oldRole or newRole ~= Role.Member or playerData.units.player then return end

    local leaderTools = Namespace.Database.profile.BattlegroundTools.LeaderTools
    if not leaderTools.promoteListed then return end

    if not InActiveBattleground() or GetGroupType() ~= GroupType.InstanceRaid then return end

    local leader = GetGroupLeaderData()
    if not leader or not leader.units.player then return end

    if leaderTools.automaticAssist[playerData.name] then
        PromoteToAssistant(playerData.name)
    end
end

function Private.MarkRaidMembers()
    local config = Namespace.Database.profile.BattlegroundTools.LeaderTools
    local icons = {}
    local iconCount = 0
    local assignedCount = 0
    for markerIndex, enabled in pairs(config.availableIcons) do
        if enabled then
            iconCount = iconCount + 1
            icons[iconCount] = markerIndex
        end
    end

    ForEachUnitData(function(playerData)
        if iconCount == assignedCount then return false end

        local shouldMark = config.alsoMarkListedAssists and config.automaticAssist[playerData.name] or config.automaticIcon[playerData.name]
        if shouldMark then
            assignedCount = assignedCount + 1
            SetRaidTarget(playerData.units.primary, icons[assignedCount])
        end
    end)
end

function Private.MarkRaidMembersIfLeadingBackground()
    if not InActiveBattleground() then return end

    local leader = GetGroupLeaderData()
    if not leader or not leader.units.player then return end

    Private.MarkRaidMembers()
end

function Private.DetectBattlegroundExit(previousState, newState)
    if previousState.status ~= QueueStatus.Active then return end
    if newState.status ~= QueueStatus.None then return end

    if Namespace.Database.profile.BattlegroundTools.InstructionFrame.settings.clearFrameOnExitBattleground then
        Private.ResetLogs()
    end

    Private.TriggerUpdateInstructionFrame()
    Private.TriggerUpdateWantBattlegroundLeadDialogFrame()
end

function Private.DetectBattlegroundEntryAfterConfirm(previousState, newState)
    if previousState.status ~= QueueStatus.Confirm then return end
    if newState.status ~= QueueStatus.Active then return end

    Private.AddLog(format(L['Entered %s'], Zones[GetCurrentZoneId()]))

    local wantLead = Memory.WantBattlegroundLead
    wantLead.requestedBy = {}
    wantLead.recentlyRejected = {}
    wantLead.requestedByCount = 0
    wantLead.ackLeader = nil

    Private.TriggerUpdateInstructionFrame()
    Private.RequestRaidLead()
end

function Module:OnEnable()
    self:RegisterEvent('CHAT_MSG_RAID_WARNING')
    self:RegisterEvent('PLAYER_ENTERING_WORLD')

    self:RegisterComm(CommunicationEvent.WantBattlegroundLead, Private.OnWantBattlegroundLead)
    self:RegisterComm(CommunicationEvent.AcknowledgeWantBattlegroundLead, Private.OnAcknowledgeWantBattlegroundLead)

    Namespace.Database.RegisterCallback(self, 'OnProfileChanged', 'RefreshConfig')
    Namespace.Database.RegisterCallback(self, 'OnProfileCopied', 'RefreshConfig')
    Namespace.Database.RegisterCallback(self, 'OnProfileReset', 'RefreshConfig')

    Private.InitializeBattlegroundLeaderDialog()

    Namespace.PlayerData.RegisterOnRoleChange('request_raid_lead', Private.RequestRaidLeadListener)
    Namespace.PlayerData.RegisterOnRoleChange('play_leader_sound', Private.PlayLeaderSoundListener)
    Namespace.PlayerData.RegisterOnRoleChange('update_raid_leader_icon', Private.UpdateRaidLeaderIconListener)
    Namespace.PlayerData.RegisterOnRoleChange('promote_assistant_when_player_becomes_leader', Private.PromoteAssistantsWhenPlayerBecomesLeaderListener)
    Namespace.PlayerData.RegisterOnRoleChange('promote_new_member_to_assistant', Private.PromoteNewMemberToAssistantListener)

    Namespace.PlayerData.RegisterOnUpdate('mark_players', Private.MarkRaidMembersIfLeadingBackground)

    Namespace.Battleground.RegisterQueueStateListener('reset_logs', Private.DetectBattlegroundExit)
    Namespace.Battleground.RegisterQueueStateListener('clean_pre_bg_group_info', Private.DetectBattlegroundEntryAfterConfirm)

    self:RefreshConfig()

    Private.AddLog(L['Battleground Commander loaded'])
    if Namespace.Database.profile.BattlegroundTools.InstructionFrame.firstTime then
        Private.AddLog(L['You can access the configuration via /bgc or through the interface options'])
        Namespace.Database.profile.BattlegroundTools.InstructionFrame.firstTime = false
    end

    Private.ApplyLogs(Memory.InstructionFrame.Text)
end

function Module:PLAYER_ENTERING_WORLD(_, isLogin, isReload)
    if not isLogin and not isReload then return end

    Private.TriggerUpdateInstructionFrame()
    Private.RequestRaidLead()
end

function Module.AutomaticallyPromoteTargetAssistant()
    local data = GetPlayerDataByUnit('target')
    if not data then return Addon:Print(L['Select a target and then run /bgca to add them to the auto assist list']) end
    if data.units.player then return end

    Namespace.Database.profile.BattlegroundTools.LeaderTools.automaticAssist[data.name] = true

    if data.role == Role.Member then PromoteToAssistant(data.units.primary) end

    Addon:Print(format(L['%s will now automatically be promoted to assistant in battlegrounds'], data.name))
end

function Module.AutomaticallyMarkTarget()
    local data = GetPlayerDataByUnit('target')
    if not data then return Addon:Print(L['Select a target and then run /bgcm to add them to the automatic marking list']) end
    if data.units.player then return end

    Namespace.Database.profile.BattlegroundTools.LeaderTools.automaticIcon[data.name] = true

    Private.MarkRaidMembersIfLeadingBackground()

    Addon:Print(format(L['%s will now automatically be marked in battlegrounds'], data.name))
end

function Module:CHAT_MSG_RAID_WARNING(_, message)
    Private.AddLog(message)
end

function Module:RefreshConfig()
    local frameConfig = Namespace.Database.profile.BattlegroundTools.InstructionFrame

    Memory.InstructionFrame:SetSize(frameConfig.size.width, frameConfig.size.height)
    Memory.InstructionFrame:ClearAllPoints()
    Memory.InstructionFrame:SetPoint(frameConfig.position.anchor, _G.UIParent, frameConfig.position.anchor, frameConfig.position.x, frameConfig.position.y)
    Memory.InstructionFrame.ResizeButton:SetShown(frameConfig.move)

    Private.TriggerUpdateWantBattlegroundLeadDialogFrame()
    Private.TriggerUpdateInstructionFrame()
end

function Module:ShowInstructionsFrame()
    Private.ApplyFont(Memory.InstructionFrame.Text, Namespace.Database.profile.BattlegroundTools.InstructionFrame.font)
    Private.ApplyFrameSettings()
    Memory.InstructionFrame:Show()

    if Memory.InstructionFrame.timer then return end
    Memory.InstructionFrame.timer = self:ScheduleRepeatingTimer(function ()
        Private.ApplyLogs(Memory.InstructionFrame.Text)
    end, 0.2)
end

function Module:HideInstructionsFrame()
    Memory.InstructionFrame:Hide()

    if not Memory.InstructionFrame.timer then return end
    self:CancelTimer(Memory.InstructionFrame.timer)
    Memory.InstructionFrame.timer = nil
end

function Module:SetInstructionFrameState(enableState)
    local frameConfig = Namespace.Database.profile.BattlegroundTools.InstructionFrame
    frameConfig.show = enableState

    Private.TriggerUpdateInstructionFrame()
end

function Module:GetInstructionFrameState()
    return Namespace.Database.profile.BattlegroundTools.InstructionFrame.show
end

function Module:SetInstructionFrameMoveState(enableState)
    Namespace.Database.profile.BattlegroundTools.InstructionFrame.move = enableState
    Memory.InstructionFrame.ResizeButton:SetShown(enableState)
end

function Module:GetInstructionFrameMoveState()
    return Namespace.Database.profile.BattlegroundTools.InstructionFrame.move
end

function Module:SetZoneId(zoneId, value)
    Namespace.Database.profile.BattlegroundTools.InstructionFrame.zones[zoneId] = value

    Private.TriggerUpdateInstructionFrame()
end

function Module:GetZoneId(zoneId)
    return Namespace.Database.profile.BattlegroundTools.InstructionFrame.zones[zoneId]
end

function Private.OnAcknowledgeWantBattlegroundLead(_, _, _, sender)
    if sender == GetRealUnitName('player') then return end

    local mem = Memory.WantBattlegroundLead
    if not mem.ackTimer then return end

    Module:CancelTimer(mem.ackTimer)
    mem.ackTimer = nil
    mem.ackLeader = nil
end

function Private.CanRequestLead()
    if not Namespace.Database.profile.BattlegroundTools.WantBattlegroundLead.wantLead then return false end
    if UnitIsGroupLeader('player') then return false end

    return InActiveBattleground()
end

function Private.OnWantBattlegroundLead(_, _, _, sender)
    if sender == GetRealUnitName('player') then return end
    if not UnitIsGroupLeader('player') then return end

    local channel = GetMessageDestination()
    if channel == Channel.Whisper then return end

    Module:SendCommMessage(CommunicationEvent.AcknowledgeWantBattlegroundLead, '1', channel)

    local config = Namespace.Database.profile.BattlegroundTools.WantBattlegroundLead
    if config.wantLead then return end
    if config.automaticallyAccept[sender] then
        PromoteToLeader(sender)
        Addon:Print(format(L['Automatically giving lead to %s'], sender))

        return Private.TriggerUpdateWantBattlegroundLeadDialogFrame(true)
    end

    local mem = Memory.WantBattlegroundLead
    if config.automaticallyReject[sender] or mem.recentlyRejected[sender] then return end

    if not mem.requestedBy[sender] then
        mem.requestedBy[sender] = true
        mem.requestedByCount = mem.requestedByCount + 1
    end

    Private.TriggerUpdateWantBattlegroundLeadDialogFrame()
end

function Private.SendManualChatMessages()
    local mem = Memory.WantBattlegroundLead
    local config = Namespace.Database.profile.BattlegroundTools.WantBattlegroundLead

    mem.ackTimer = nil
    if not config.enableManualRequest or not Private.CanRequestLead() then return end

    local groupLeader = GetGroupLeaderData()
    if not groupLeader then return end

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

function Private.SendWantBattlegroundLead()
    local mem = Memory.WantBattlegroundLead
    mem.wantLeadTimer = nil

    if not Private.CanRequestLead() then return end

    local channel = GetMessageDestination()
    if channel == Channel.Whisper then return end

    if Namespace.Database.profile.BattlegroundTools.WantBattlegroundLead.enableManualRequest then
        local groupLeader = GetGroupLeaderData()
        if groupLeader and (mem.ackLeader == nil or groupLeader.name ~= mem.ackLeader) then
            -- re-buffer the timer each time the leader changes to give them enough time to reply
            if mem.ackTimer then Module:CancelTimer(mem.ackTimer) end

            mem.ackLeader = groupLeader.name
            mem.ackTimer = Module:ScheduleTimer(Private.SendManualChatMessages, 5)
        end
    end

    Module:SendCommMessage(CommunicationEvent.WantBattlegroundLead, '1', channel)
end

function Private.RequestRaidLead()
    local mem = Memory.WantBattlegroundLead

    if mem.wantLeadTimer then return end
    if not Private.CanRequestLead() then return end

    mem.wantLeadTimer = Module:ScheduleTimer(Private.SendWantBattlegroundLead, 4)
end

function Private.ProcessDropDownOptions(onNameSelected)
    local mem = Memory.WantBattlegroundLead
    local found = 0
    local total = 0
    local lastName
    local names = {}
    for name, isChecked in pairs(mem.dropdownSelection) do
        if mem.requestedBy[name] then
            found = found + 1
            lastName = name
            if isChecked then
                total = total + 1
                names[total] = name
            end
        end
    end

    if found == 1 and total == 0 then
        -- automatically pick the only option
        names[1] = lastName
    end

    for _, name in pairs(names) do
        if onNameSelected(name) then break end
    end
end

function Private.AcceptManualBattlegroundLeaderRequest()
    local mem = Memory.WantBattlegroundLead
    local remember = mem.DialogFrame.RememberNameCheckbox:GetChecked()
    local automaticallyAccept = Namespace.Database.profile.BattlegroundTools.WantBattlegroundLead.automaticallyAccept

    local forceHide = false
    Private.ProcessDropDownOptions(function (name)
        mem.requestedBy[name] = nil
        mem.requestedByCount = mem.requestedByCount - 1
        if remember then automaticallyAccept[name] = true end

        PromoteToLeader(name)
        forceHide = true

        return true -- only ever attempt once
    end)

    Private.TriggerUpdateWantBattlegroundLeadDialogFrame(forceHide)
end

function Private.RejectManualBattlegroundLeaderRequest()
    local mem = Memory.WantBattlegroundLead
    local remember = mem.DialogFrame.RememberNameCheckbox:GetChecked()
    local automaticallyReject = Namespace.Database.profile.BattlegroundTools.WantBattlegroundLead.automaticallyReject
    Private.ProcessDropDownOptions(function (name)
        mem.requestedBy[name] = nil
        mem.recentlyRejected[name] = true
        mem.requestedByCount = mem.requestedByCount - 1
        if remember then
            automaticallyReject[name] = true
        end

        return false
    end)

    Private.TriggerUpdateWantBattlegroundLeadDialogFrame()
end

function Private.UpdateAcceptRejectButtonState()
    local frame = Memory.WantBattlegroundLead.DialogFrame
    if not frame then return end

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
    dialog:SetScript('OnShow', function(self)
        if not self:IsVisible() then return end
        PlaySound(ReadyCheckSound)
        FlashClientIcon()
    end)

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

    dialog:Hide()

    Memory.WantBattlegroundLead.DialogFrame = dialog
end

function Private.InitializeBattlegroundLeaderCheckbox()
    local honorFrame = _G.HonorFrame
    local checkbox = CreateFrame('CheckButton', 'BgcBattlegroundLeaderCheckbox', honorFrame, 'UICheckButtonTemplate')
    checkbox:SetPoint('LEFT', _G.HonorFrameQueueButton, 'RIGHT', 2, 0)
    checkbox:SetSize(24, 24)
    checkbox:SetChecked(Namespace.Database.profile.BattlegroundTools.WantBattlegroundLead.wantLead)
    checkbox:SetScript('OnEnter', function (self)
        local tooltip = _G.GameTooltip
        tooltip:SetOwner(self, 'ANCHOR_RIGHT')
        tooltip:SetText(L['Requests lead upon entering or enabling this option'], nil, nil, nil, nil, true)
        tooltip:Show()
    end)
    checkbox:SetScript('OnLeave', function () _G.GameTooltip:Hide() end)
    checkbox:SetScript('OnClick', function (self)
        local wantLead = self:GetChecked()

        Namespace.Database.profile.BattlegroundTools.WantBattlegroundLead.wantLead = wantLead
        if wantLead then
            PlaySound(ActivateWarmodeSound)
            Private.RequestRaidLead()
        else
            PlaySound(DeactivateWarmodeSound)
        end
    end)
    checkbox:Show()

    honorFrame.BattlegroundModeCheckbox = checkbox

    local text = checkbox:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
    text:SetText(L['As BG Leader'])
    text:SetPoint('LEFT', checkbox, 'RIGHT')
    text:SetWordWrap(false)

    checkbox.Text = text
end

function Module:ADDON_LOADED(_, addonName)
    if addonName == 'Blizzard_PVPUI' then
        Private.InitializeBattlegroundLeaderCheckbox()

        self:UnregisterEvent('ADDON_LOADED')
    end
end

function Module:SetWantLeadSetting(key, table)
    Namespace.Database.profile.BattlegroundTools.WantBattlegroundLead[key] = table
end

function Module:GetWantLeadSetting(key)
    return Namespace.Database.profile.BattlegroundTools.WantBattlegroundLead[key]
end

function Module:SetLeaderToolsSetting(key, value)
    local config = Namespace.Database.profile.BattlegroundTools.LeaderTools
    if key ~= 'leaderIcon' then
        config[key] = value
        return
    end

    -- swap around values
    local oldValue = config.leaderIcon
    config.availableIcons[oldValue] = config.availableIcons[value]
    config.availableIcons[value] = false
    config.leaderIcon = value
end

function Module:GetLeaderToolsSetting(key)
    return Namespace.Database.profile.BattlegroundTools.LeaderTools[key]
end

function Module:SetMarkerIndexSetting(markerIndex, value)
    local config = Namespace.Database.profile.BattlegroundTools.LeaderTools
    if value and config.leaderIcon == markerIndex then return end

    config.availableIcons[markerIndex] = value
end

function Module:GetMarkerIndexSetting(markerIndex)
    return Namespace.Database.profile.BattlegroundTools.LeaderTools.availableIcons[markerIndex]
end
