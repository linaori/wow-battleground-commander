local _G, ModuleName, Private, AddonName, Namespace = _G, 'BattlegroundTools', {}, ...
local Module = Namespace.Addon:NewModule(ModuleName, 'AceEvent-3.0', 'AceTimer-3.0', 'AceComm-3.0')
local L = Namespace.Libs.AceLocale:GetLocale(AddonName)
local LSM = Namespace.Libs.LibSharedMedia
local LibDD = Namespace.Libs.LibDropDown

Namespace.BattlegroundTools = Module

local Channel = Namespace.Communication.Channel
local GetGroupLeaderUnit = Namespace.Utils.GetGroupLeaderUnit
local GetMessageDestination = Namespace.Communication.GetMessageDestination
local GroupType = Namespace.Utils.GroupType
local GetGroupType = Namespace.Utils.GetGroupType
local CreateFrame = CreateFrame
local GetTime = GetTime
local ReplaceIconAndGroupExpressions = C_ChatInfo.ReplaceIconAndGroupExpressions
local GetInstanceInfo = GetInstanceInfo
local GetUnitName = GetUnitName
local PromoteToLeader = PromoteToLeader
local PlaySound = PlaySound
local UnitIsGroupLeader = UnitIsGroupLeader
local SendChatMessage = SendChatMessage
local ActivateWarmodeSound = SOUNDKIT.UI_WARMODE_ACTIVATE
local DeactivateWarmodeSound = SOUNDKIT.UI_WARMODE_DECTIVATE
local concat = table.concat
local format = string.format
local floor = math.floor
local min = math.min
local pairs = pairs
local TimeDiff = Namespace.Utils.TimeDiff
--local print = Namespace.Debug.print

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

Namespace.BattlegroundTools.Zones = {
    [0]    = L['Open World'],
    [30]   = L['Alterac Valley'],
    [2197] = L['Alterac Valley (Korrak\'s Revenge)'],
    [1191] = L['Ashran'],
    [2118] = L['Battle for Wintergrasp'],
    [628]  = L['Isle of Conquest'],
    [2107] = L['Arathi Basin'],
    [529]  = L['Arathi Basin (Classic)'],
    [1681] = L['Arathi Basin (Winter)'],
    [2177] = L['Arathi Basin Comp Stomp'],
    [1105] = L['Deepwind Gorge'],
    [566]  = L['Eye of the Storm'],
    [968]  = L['Eye of the Storm (Rated)'],
    [1803] = L['Seething Shore'],
    [727]  = L['Silvershard Mines'],
    [607]  = L['Strand of the Ancients'],
    [998]  = L['Temple of Kotmogu'],
    [761]  = L['The Battle for Gilneas'],
    [726]  = L['Twin Peaks'],
    [489]  = L['Warsong Gulch'],
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

    Memory.InstructionFrame:SetBackdrop({
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

    Memory.InstructionFrame:SetBackdropColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
    Memory.InstructionFrame:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
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
    instructionFrame:SetMinResize(100, 50)
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

function Private.TriggerUpdateWantBattlegroundLeadDialogFrame()
    local mem = Memory.WantBattlegroundLead
    local dialog = mem.DialogFrame
    if not dialog then return end

    dialog:SetShown(mem.requestedByCount > 0)
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
    if frameConfig.show and frameConfig.zones[Memory.currentZoneId] then
        Module:ShowInstructionsFrame()
    else
        Module:HideInstructionsFrame()
    end
end

function Private.EnterZone()
    local _, instanceType, _, _, _, _, _, currentZoneId = GetInstanceInfo()
    if instanceType == 'none' then currentZoneId = 0 end

    Memory.currentZoneId = currentZoneId
    Memory.WantBattlegroundLead.requestedBy = {}
    Memory.WantBattlegroundLead.recentlyRejected = {}
    Memory.WantBattlegroundLead.requestedByCount = 0
    Memory.WantBattlegroundLead.ackLeader = nil

    Private.TriggerUpdateInstructionFrame()
    Private.TriggerUpdateWantBattlegroundLeadDialogFrame()
    Private.RequestRaidLead()
end

function Module:OnEnable()
    self:RegisterEvent('CHAT_MSG_RAID_WARNING')
    self:RegisterEvent('GROUP_ROSTER_UPDATE')
    self:RegisterEvent('PLAYER_ENTERING_WORLD', Private.EnterZone)

    self:RegisterComm(CommunicationEvent.WantBattlegroundLead, Private.OnWantBattlegroundLead)
    self:RegisterComm(CommunicationEvent.AcknowledgeWantBattlegroundLead, Private.OnAcknowledgeWantBattlegroundLead)

    Namespace.Database.RegisterCallback(self, 'OnProfileChanged', 'RefreshConfig')
    Namespace.Database.RegisterCallback(self, 'OnProfileCopied', 'RefreshConfig')
    Namespace.Database.RegisterCallback(self, 'OnProfileReset', 'RefreshConfig')

    Private.InitializeBattlegroundLeaderDialog()

    self:RefreshConfig()

    Private.AddLog(L['Battleground Commander loaded'])
    if Namespace.Database.profile.BattlegroundTools.InstructionFrame.firstTime then
        Private.AddLog(L['You can access the configuration via /bgc or through the interface options'])
        Namespace.Database.profile.BattlegroundTools.InstructionFrame.firstTime = false
    end

    Private.ApplyLogs(Memory.InstructionFrame.Text)
end

function Module:CHAT_MSG_RAID_WARNING(_, message)
    Private.AddLog(message)
end

function Module:GROUP_ROSTER_UPDATE()
    Private.RequestRaidLead()
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
    if sender == GetUnitName('player', true) then return end

    local mem = Memory.WantBattlegroundLead
    if not mem.ackTimer then return end

    Module:CancelTimer(mem.ackTimer)
    mem.ackTimer = nil
    mem.ackLeader = nil
end

function Private.OnWantBattlegroundLead(_, _, _, sender)
    if sender == GetUnitName('player', true) then return end

    local config = Namespace.Database.profile.BattlegroundTools.WantBattlegroundLead
    if config.wantLead then return end
    if config.automaticallyAccept[sender] then
        PromoteToLeader(sender)
        return Namespace.Addon:PrintMessage(format(L['Automatically giving lead to %s'], sender))
    end
    if config.automaticallyReject[sender] or Memory.WantBattlegroundLead.recentlyRejected[sender] then return end

    local mem = Memory.WantBattlegroundLead
    mem.requestedBy[sender] = true
    mem.requestedByCount = mem.requestedByCount + 1

    local channel = GetMessageDestination()
    if channel == Channel.Whisper then return end

    Module:SendCommMessage(CommunicationEvent.AcknowledgeWantBattlegroundLead, '1', channel)

    Private.TriggerUpdateWantBattlegroundLeadDialogFrame()
end

function Private.SendManualChatMessages()
    local mem = Memory.WantBattlegroundLead
    local config = Namespace.Database.profile.BattlegroundTools.WantBattlegroundLead

    mem.ackTimer = nil
    if not config.enableManualRequest or not config.wantLead then return end

    mem.ackLeader = GetUnitName(GetGroupLeaderUnit(), true)

    local message = config.manualRequestMessage:gsub('{leader}', mem.ackLeader)
    if config.sendWhisper then SendChatMessage(message, Channel.Whisper, nil, mem.ackLeader) end
    if config.sendSay and Memory.currentZoneId ~= 0 then SendChatMessage(message, Channel.Say) end
    if config.sendRaid and GetGroupType() == GroupType.Raid then SendChatMessage(message, Channel.Raid) end
end

function Private.SendWantBattlegroundLead()
    local mem = Memory.WantBattlegroundLead
    mem.wantLeadTimer = nil

    local channel = GetMessageDestination()
    if channel == Channel.Whisper then return end

    if Namespace.Database.profile.BattlegroundTools.WantBattlegroundLead.enableManualRequest then
        local groupLeader = GetUnitName(GetGroupLeaderUnit(), true)
        if mem.ackLeader == nil or groupLeader ~= mem.ackLeader then
            if mem.ackTimer then Module:CancelTimer(mem.ackTimer) end

            mem.ackTimer = Module:ScheduleTimer(Private.SendManualChatMessages, 5)
        end
    end

    Module:SendCommMessage(CommunicationEvent.WantBattlegroundLead, '1', channel)
end

function Private.GetRaidLeaderUnit()
    local groupType, maxSize, type = GetGroupType(), 6, 'party'
    if groupType == 'solo' then return nil end

    if groupType == GroupType.InstanceRaid or groupType == GroupType.Raid then
        maxSize, type = 40, 'raid'
    end

    for i = 1, maxSize do
        local unit = type .. i
        if UnitIsGroupLeader(unit) then
            return unit
        end
    end

    return nil
end

function Private.RequestRaidLead()
    local mem = Memory.WantBattlegroundLead

    if mem.wantLeadTimer then return end
    if Memory.currentZoneId == 0 then return end
    if not Namespace.BattlegroundTools.Zones[Memory.currentZoneId] then return end
    if not Namespace.Database.profile.BattlegroundTools.WantBattlegroundLead.wantLead then return end
    if UnitIsGroupLeader('player') then return end

    mem.wantLeadTimer = Module:ScheduleTimer(Private.SendWantBattlegroundLead, 3)
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

    Private.ProcessDropDownOptions(function (name)
        mem.requestedBy[name] = nil
        mem.requestedByCount = mem.requestedByCount - 1
        if remember then automaticallyAccept[name] = true end

        PromoteToLeader(name)

        return true -- only ever attempt once
    end)

    Private.TriggerUpdateWantBattlegroundLeadDialogFrame()
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
    dialog:SetBackdropColor(0.5, 0.5, 0.5, 1);
    dialog:SetBackdropBorderColor(0.7, 0.7, 0.7, 1)
    dialog:SetScript('OnMouseDown', function(self) self:StartMoving() end)
    dialog:SetScript('OnMouseUp', function(self) self:StopMovingOrSizing() end)

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

    dialog.Text = dialogText
    dialog.Dropdown = dropdown
    dialog.AcceptButton = acceptButton
    dialog.RejectButton = rejectButton
    dialog.RememberNameCheckbox = checkbox

    dialog:Hide()

    Memory.WantBattlegroundLead.DialogFrame = dialog
end

function Private.InitializeBattlegroundLeaderCheckbox()
    local PVPUIFrame = _G.PVPUIFrame
    local checkbox = CreateFrame('CheckButton', 'BgcBattlegroundLeaderCheckbox', PVPUIFrame, 'UICheckButtonTemplate')
    checkbox:SetPoint('LEFT', _G.HonorFrameQueueButton, 'RIGHT', 2, 0)
    checkbox:SetSize(24, 24)
    checkbox:SetChecked(Namespace.Database.profile.BattlegroundTools.WantBattlegroundLead.wantLead)
    checkbox:SetScript('OnEnter', function (self)
        _G.GameTooltip:SetOwner(self, 'ANCHOR_RIGHT');
        _G.GameTooltip:SetText(L['Requests lead upon entering or enabling this option'], nil, nil, nil, nil, true);
    end)
    checkbox:SetScript('OnLeave', function ()
        _G.GameTooltip:Hide();
    end)
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

    PVPUIFrame.BattlegroundModeCheckbox = checkbox

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
