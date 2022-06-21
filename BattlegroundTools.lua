local _G, ModuleName, Private, AddonName, Namespace = _G, 'BattlegroundTools', {}, ...
local Module = Namespace.Addon:NewModule(ModuleName, 'AceEvent-3.0', 'AceTimer-3.0')
local L = Namespace.Libs.AceLocale:GetLocale(AddonName)
local LSM = Namespace.Libs.LibSharedMedia

Namespace.BattlegroundTools = Module

local CreateFrame = CreateFrame
local GetTime = GetTime
local ReplaceIconAndGroupExpressions = C_ChatInfo.ReplaceIconAndGroupExpressions
local GetInstanceInfo = GetInstanceInfo
local concat = table.concat
local format = string.format
local floor = math.floor
local TimeDiff = Namespace.Utils.TimeDiff

local Memory = {
    currentZoneId = nil,
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

    local list = Memory.RaidWarningLogs.list
    local messages = {}
    local count = 0
    local timePrefix = format('|cff%.2x%.2x%.2x', colorTime.r * 255, colorTime.g * 255, colorTime.b * 255)
    local now = floor(GetTime())

    for i = Memory.RaidWarningLogs.size, Memory.RaidWarningLogs.size - maxInstructions + 1, -1 do
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

    Private.TriggerUpdateInstructionFrame()
end

function Module:OnEnable()
    self:RegisterEvent('CHAT_MSG_RAID_WARNING')
    self:RegisterEvent('PLAYER_ENTERING_WORLD', Private.EnterZone)

    Namespace.Database.RegisterCallback(self, 'OnProfileChanged', 'RefreshConfig')
    Namespace.Database.RegisterCallback(self, 'OnProfileCopied', 'RefreshConfig')
    Namespace.Database.RegisterCallback(self, 'OnProfileReset', 'RefreshConfig')

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

function Module:RefreshConfig()
    local frameConfig = Namespace.Database.profile.BattlegroundTools.InstructionFrame

    Memory.InstructionFrame:SetSize(frameConfig.size.width, frameConfig.size.height)
    Memory.InstructionFrame:ClearAllPoints()
    Memory.InstructionFrame:SetPoint(frameConfig.position.anchor, _G.UIParent, frameConfig.position.anchor, frameConfig.position.x, frameConfig.position.y)
    Memory.InstructionFrame.ResizeButton:SetShown(frameConfig.move)

    Private.TriggerUpdateInstructionFrame()
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
    Private.ApplyFont(Memory.InstructionFrame.Text, Namespace.Database.profile.BattlegroundTools.InstructionFrame.font)
    Private.ApplyFrameSettings()
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
