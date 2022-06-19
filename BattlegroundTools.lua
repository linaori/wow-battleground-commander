local ModuleName, Private, AddonName, Namespace = 'BattlegroundTools', {}, ...
local Module = Namespace.Addon:NewModule(ModuleName, 'AceEvent-3.0', 'AceTimer-3.0', 'AceComm-3.0')
local L = Namespace.Libs.AceLocale:GetLocale(AddonName)
local LSM = Namespace.Libs.LibSharedMedia

Namespace.BattlegroundTools = Module

local CreateFrame = CreateFrame
local GetTime = GetTime
local ReplaceIconAndGroupExpressions = C_ChatInfo.ReplaceIconAndGroupExpressions
local concat = table.concat
local format = string.format
local floor = math.floor
local print = Namespace.Debug.print
local TimeDiff = Namespace.Utils.TimeDiff

local Zone = {
    AlteracValley = 30,
    KorraksRevenge = 2197,
    Ashran = 1191,
    IsleOfConquest = 628,
    Wintergrasp = 2118,
}

local Memory = {
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
end

function Module:SetFontFamily(newFont)
    local fontConfig = Namespace.Database.profile.BattlegroundTools.InstructionFrame.font
    fontConfig.family = newFont

    Private.ApplyFont(Memory.InstructionFrame.Text, fontConfig)
end

function Module:GetFontFamily()
    return Namespace.Database.profile.BattlegroundTools.InstructionFrame.font.family
end

function Module:SetFontFlags(newFlags)
    local fontConfig = Namespace.Database.profile.BattlegroundTools.InstructionFrame.font
    fontConfig.flags = newFlags

    Private.ApplyFont(Memory.InstructionFrame.Text, fontConfig)
end

function Module:GetFontFlags()
    return Namespace.Database.profile.BattlegroundTools.InstructionFrame.font.flags
end

function Module:SetFontColor(r, g, b)
    local fontConfig = Namespace.Database.profile.BattlegroundTools.InstructionFrame.font
    fontConfig.color.r, fontConfig.color.g, fontConfig.color.b = r, g, b

    Private.ApplyFont(Memory.InstructionFrame.Text, fontConfig)
end

function Module:GetFontColor()
    local color = Namespace.Database.profile.BattlegroundTools.InstructionFrame.font.color
    return color.r, color.g, color.b
end

function Module:SetHighlightFontColor(r, g, b)
    local fontConfig = Namespace.Database.profile.BattlegroundTools.InstructionFrame.font
    fontConfig.colorHighlight.r, fontConfig.colorHighlight.g, fontConfig.colorHighlight.b = r, g, b

    Private.ApplyFont(Memory.InstructionFrame.Text, fontConfig)
end

function Module:GetHighlightFontColor()
    local color = Namespace.Database.profile.BattlegroundTools.InstructionFrame.font.colorHighlight
    return color.r, color.g, color.b
end

function Module:SetTimerFontColor(r, g, b)
    local fontConfig = Namespace.Database.profile.BattlegroundTools.InstructionFrame.font
    fontConfig.colorTime.r, fontConfig.colorTime.g, fontConfig.colorTime.b = r, g, b

    Private.ApplyFont(Memory.InstructionFrame.Text, fontConfig)
end

function Module:GetTimerFontColor()
    local color = Namespace.Database.profile.BattlegroundTools.InstructionFrame.font.colorTime
    return color.r, color.g, color.b
end

function Private.AddLog(message)
    local logs = Memory.RaidWarningLogs
    if message == logs.last then
        logs.list[logs.size].time = floor(GetTime())
        return
    end

    logs.size = logs.size + 1
    logs.list[logs.size] = { time = GetTime(), message = message }
    logs.last = message
end

function Private.ApplyLogs(textObject)
    local frameConfig = Namespace.Database.profile.BattlegroundTools.InstructionFrame
    local colorHighlight = frameConfig.font.colorHighlight
    local colorTime = frameConfig.font.colorTime
    local maxMessages = frameConfig.messageCount

    local list = Memory.RaidWarningLogs.list
    local messages = {}
    local count = 0
    local timePrefix = format('|cff%.2x%.2x%.2x', colorTime.r * 255, colorTime.g * 255, colorTime.b * 255)
    local now = floor(GetTime())

    for i = Memory.RaidWarningLogs.size, Memory.RaidWarningLogs.size - maxMessages, -1 do
        count = count + 1
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

        messages[count] = ReplaceIconAndGroupExpressions(log)
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
    instructionFrame:SetBackdrop({
        bgFile = LSM:Fetch('background', 'Blizzard Dialog Background Dark'),
        edgeFile = LSM:Fetch('border', 'Blizzard Dialog'),
        edgeSize = 4,
    })
    instructionFrame:SetBackdropColor(1, 1, 1, 0.8)
    instructionFrame:SetBackdropBorderColor(1, 1, 1, 0.5)
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
        position.anchor, _, _, position.x, position.y = parent:GetPoint(1)
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
    text:SetPoint('TOPLEFT', 5, -5)
    text:SetPoint('BOTTOMRIGHT', -17, 5)
    text:SetJustifyH('LEFT')
    text:SetJustifyV('TOP')

    instructionFrame.MoveOverlay = moveOverlay
    instructionFrame.ResizeButton = resizeButton
    instructionFrame.Text = text

    Memory.InstructionFrame = instructionFrame
end

function Module:OnInitialize()
    Private.InitializeInstructionFrame()
end

function Module:OnEnable()
    self:RegisterEvent('CHAT_MSG_RAID_WARNING')

    Namespace.Database.RegisterCallback(self, 'OnProfileChanged', 'RefreshConfig')
    Namespace.Database.RegisterCallback(self, 'OnProfileCopied', 'RefreshConfig')
    Namespace.Database.RegisterCallback(self, 'OnProfileReset', 'RefreshConfig')

    self:RefreshConfig()

    Private.ApplyLogs(Memory.InstructionFrame.Text)

    Memory.InstructionFrame.timer = self:ScheduleRepeatingTimer(function ()
        Private.ApplyLogs(Memory.InstructionFrame.Text)
    end , 0.2)
end

function Module:CHAT_MSG_RAID_WARNING(_, message)
    Private.AddLog(message)
end

function Module:RefreshConfig()
    local frameConfig = Namespace.Database.profile.BattlegroundTools.InstructionFrame

    Memory.InstructionFrame:SetSize(frameConfig.size.width, frameConfig.size.height)
    Memory.InstructionFrame:ClearAllPoints()
    Memory.InstructionFrame:SetPoint(frameConfig.position.anchor, _G.UIParent, frameConfig.position.anchor, frameConfig.position.x, frameConfig.position.y)

    if frameConfig.show then
        self:ShowInstructionsFrame()
    else
        self:HideInstructionsFrame()
    end

    Private.AddLog('Establishing battlefield control, standby...')
end

function Module:OnDisable()
    Memory.InstructionFrame:Hide()

    Namespace.Database.UnregisterCallback(self, 'OnProfileChanged')
    Namespace.Database.UnregisterCallback(self, 'OnProfileCopied')
    Namespace.Database.UnregisterCallback(self, 'OnProfileReset')

    self:UnregisterEvent('CHAT_MSG_RAID_WARNING')

    self:HideInstructionsFrame()
end

function Module:ShowInstructionsFrame()
    Memory.InstructionFrame:Show()

    if Memory.InstructionFrame.timer then return end
    Memory.InstructionFrame.timer = self:ScheduleRepeatingTimer(function ()
        Private.ApplyLogs(Memory.InstructionFrame.Text)
    end , 0.2)
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

    if frameConfig.show then
        self:ShowInstructionsFrame()
    else
        self:HideInstructionsFrame()
    end
end

function Module:GetInstructionFrameState()
    return Namespace.Database.profile.BattlegroundTools.InstructionFrame.show
end

function Module:SetInstructionFrameMoveState(enableState)
    Namespace.Database.profile.BattlegroundTools.InstructionFrame.move = enableState
end

function Module:GetInstructionFrameMoveState()
    return Namespace.Database.profile.BattlegroundTools.InstructionFrame.move
end
