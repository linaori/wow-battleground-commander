local ModuleName, Private, AddonName, Namespace = 'QueueTools', {}, ...
local Module = Namespace.Addon:NewModule(ModuleName, 'AceEvent-3.0', 'AceTimer-3.0', 'AceComm-3.0')
local L = Namespace.Libs.AceLocale:GetLocale(AddonName)
local ScrollingTable = Namespace.Libs.ScrollingTable
local AceSerializer = Namespace.Libs.AceSerializer
local LibCompress = Namespace.Libs.LibCompress
local Encoder = LibCompress:GetAddonEncodeTable()

local DoReadyCheck = DoReadyCheck
local UnitIsGroupLeader = UnitIsGroupLeader
local UnitIsGroupAssistant = UnitIsGroupAssistant
local GetInstanceInfo = GetInstanceInfo
local CreateFrame = CreateFrame
local PlaySound = PlaySound
local CharacterPanelOpenSound = SOUNDKIT.IG_CHARACTER_INFO_OPEN
local CharacterPanelCloseSound = SOUNDKIT.IG_CHARACTER_INFO_CLOSE
local GetPlayerAuraBySpellID = GetPlayerAuraBySpellID
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local UnitClass = UnitClass
local UnitFullName = UnitFullName
local GetNumGroupMembers = GetNumGroupMembers
local UnitDebuff = UnitDebuff
local UnitIsPlayer = UnitIsPlayer
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local IsInGroup = IsInGroup
local GetTime = GetTime
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local DEBUFF_MAX_DISPLAY = DEBUFF_MAX_DISPLAY
local UNKNOWNOBJECT = UNKNOWNOBJECT
local LE_PARTY_CATEGORY_HOME = LE_PARTY_CATEGORY_HOME
local max = math.max
local ceil = math.ceil
local format = string.format
local pairs = pairs
--local print, log = Namespace.Debug.print, Namespace.Debug.log

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
        width = 120,
        align = 'LEFT',
    },
    {
        name = ' ' .. L['Merc'],
        width = 60,
        align = 'CENTER',
    },
    {
        name = ' ' .. L['Deserter'],
        width = 60,
        align = 'CENTER',
    },
    {
        name = ' ' .. L['Ready'],
        width = 60,
        align = 'CENTER',
    }
}

local Config = {
    tableRefreshSeconds = 10,
    readyCheckStateResetSeconds = 10,
    sendMercenaryDurationDelay = 1,
}

local Memory = {
    me = {
        name = nil,
        realm = nil,
    },
    -- seems like you can't do a second ready check for about 5~6 seconds, even if the "finished" event is faster
    readyCheckGracePeriod = 6,

    -- keep track of last ready check and when it finished to update the button and icons properly
    lastReadyCheckTime = 0,
    lastReadyCheckDuration = 0,
    readyCheckButtonTicker = nil,
    readyCheckClearTimeout = nil,

    showGroupQueueFrame = false,
    playerTableCache = {},
    playerData = {
        --[GUID] = {
        --    name = playerName,
        --    realm = playerRealm,
        --    unit = 'unit',
        --    class = 'CLASS',
        --    readyState = ReadyCheckState.Nothing,
        --    deserterExpiry = -1,
        --    mercenaryExpiry = -1,
        --    hasAddon = false,
        --},
    },

    -- the data that should be send next mercenary sync event
    sendMercenaryDataPayloadBuffer = nil,

    -- used to reduce the amount of hidden chat calls
    previousGroupSize = 0,
}

function Private.SetGroupQueueVisibility(newValue)
    Memory.showGroupQueueFrame = newValue
    Namespace.Database.profile.QueueTools.showGroupQueueFrame = newValue
end

local CommunicationEvent = {
    NotifyMercenaryDuration = 'Bgc:notifyMerc',
    packData = function (data)
        return Encoder:Encode(LibCompress:CompressHuffman(AceSerializer:Serialize(data)))
    end,
    unpackData = function (raw)
        local decompressed = LibCompress:Decompress(Encoder:Decode(raw))
        if not decompressed then return end

        local success, data = AceSerializer:Deserialize(decompressed)
        if not success then return end

        return data
    end,
    getMessageDestination = function ()
        local channel, player = 'PARTY', nil
        if not IsInGroup(LE_PARTY_CATEGORY_HOME) then
            -- handle communication over whisper to self when PARTY is not available
            channel = 'WHISPER'
            player = Memory.me.name
        end

        return channel, player
    end,
}

local ColorList = {
    Bad = { r = 1.0, g = 0, b = 0, a = 1.0 },
    Good = { r = 0, g = 1.0, b = 0, a = 1.0 },
    Warning = { r = 1.0, g = 1.0, b = 0, a = 1.0 },
    UnknownClass = { r = 0.7, g = 0.7, b = 0.7, a = 1.0 },
}

function Private.DoSendMercenaryDuration()
    if Memory.sendMercenaryDataPayloadBuffer == nil then return end

    local channel, player = CommunicationEvent.getMessageDestination()
    local payload = CommunicationEvent.packData(Memory.sendMercenaryDataPayloadBuffer)

    Module:SendCommMessage(CommunicationEvent.NotifyMercenaryDuration, payload, channel, player)
    Memory.sendMercenaryDataPayloadBuffer = nil
end

function Private.ScheduleSendMercenaryDuration(expirationTime)
    local shouldSchedule = Memory.sendMercenaryDataPayloadBuffer == nil
    local remaining = expirationTime == -1 and -1 or expirationTime - GetTime()
    Memory.sendMercenaryDataPayloadBuffer = { remaining = remaining }

    if not shouldSchedule then return end
    Module:ScheduleTimer(Private.DoSendMercenaryDuration, Config.sendMercenaryDurationDelay)
end

function Private.GetPlayerDataByUnit(unit)
    for _, data in pairs(Memory.playerData) do
        if data.unit == unit then return data end
    end

    return nil
end

--- can be used as
--- - GetPlayerDataByName('Linaori')
--- - GetPlayerDataByName('Linaori-Ragnaros)
--- - GetPlayerDataByName('Linaori', 'Ragnaros)
function Private.GetPlayerDataByName(name, realm)
    if realm == nil then
        local splitName, splitRealm = name:match('(.-)-(.+)')
        if splitName ~= nil then
            name = splitName
            realm = splitRealm
        end
    end

    local totalPotentialMatches, potentialMatch = 0

    for _, data in pairs(Memory.playerData) do
        if data.name == UNKNOWNOBJECT or data.name == nil or data.realm == nil then
            data.name, data.realm = UnitFullName(data.unit)
        end

        if data.name == name then
            if realm == nil then
                potentialMatch = data
                totalPotentialMatches = totalPotentialMatches + 1
            elseif data.realm == realm then
                return data
            end
        end
    end

    if totalPotentialMatches == 1 then
        return potentialMatch
    end

    return nil
end

function Private.CanDoReadyCheck()
    if Memory.lastReadyCheckTime + Memory.lastReadyCheckDuration > GetTime() then
        return false
    end

    if not UnitIsGroupLeader('player') and not UnitIsGroupAssistant('player') then
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
        local _, _, _, _, _, expirationTime, _, _, _, spellId = UnitDebuff(data.unit, i)
        if spellId == SpellIds.DeserterDebuff then
            data.deserterExpiry = expirationTime

            return
        end
    end
end

function Private.CreateTableRow(data)
    local nameColumn = {
        value = function(tableData, _, realRow, column)
            local columnData = tableData[realRow].cols[column]

            if data.name == UNKNOWNOBJECT or data.name == nil or data.realm == nil then
                -- try to update the name as it wasn't available on initial check
                data.name, data.realm = UnitFullName(data.unit)
            end

            local name, color
            if data.name == UNKNOWNOBJECT then
                name = '...'
                color = ColorList.UnknownClass
            else
                local _, class = UnitClass(data.unit)
                name = data.name
                if data.realm ~= nil and data.realm ~= Memory.me.realm then
                    name = name .. '-' .. data.realm
                end

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
            local remaining = data.mercenaryExpiry - GetTime()
            if remaining < 1 then
                return L['no']
            end

            remaining = ceil(remaining / 60)
            if remaining < 4 then
                columnData.color = ColorList.Bad
            elseif remaining < 9 then
                columnData.color = ColorList.Warning
            end

            return format('%dm', remaining)
        end,
    }

    local deserterColumn = {
        value = function(tableData, _, realRow, column)
            local columnData = tableData[realRow].cols[column]
            Private.TriggerDeserterUpdate(data)
            local remaining = data.deserterExpiry - GetTime()
            if remaining < 1 then
                columnData.color = ColorList.Good
                return L['no']
            end

            columnData.color = ColorList.Bad
            return format('%dm', ceil(remaining / 60))
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
        nameColumn,
        mercenaryColumn,
        deserterColumn,
        readyCheckColumn,
    }}
end

function Private.RefreshPlayerTable()
    if not _G.BgcQueueFrame or not Memory.showGroupQueueFrame then return end

    _G.BgcQueueFrame.PlayerTable:Refresh()
end

function Private.UpdatePlayerTableData()
    if not _G.BgcQueueFrame or not Memory.showGroupQueueFrame then return end

    _G.BgcQueueFrame.PlayerTable:SetData(Memory.playerTableCache)
end

function Private.GetPlayerAuraExpiryTime(auraId)
    local _, _, _, _, _, expirationTime = GetPlayerAuraBySpellID(auraId)

    return expirationTime ~= nil and expirationTime or -1
end

function Private.TriggerStateUpdates(forceSync)
    if _G.BgcReadyCheckButton then _G.BgcReadyCheckButton:SetEnabled(Private.CanDoReadyCheck()) end
    if Memory.me.realm == nil then Memory.me.name, Memory.me.realm = UnitFullName('player') end

    local newGroupSize = GetNumGroupMembers(LE_PARTY_CATEGORY_HOME)

    -- player is solo
    if newGroupSize == 0 then newGroupSize = 1 end

    -- when leader is passed around, no need to re-sync
    if not forceSync and newGroupSize == Memory.previousGroupSize then return end
    if Memory.previousGroupSize > 1 and newGroupSize == 1 then
        -- player left the group, clear up data
        Memory.playerData = {}
    end
    Memory.previousGroupSize = newGroupSize

    local tableCache = {}
    for index, unit in pairs({ 'player', 'party1', 'party2', 'party3', 'party4' }) do
        if index <= newGroupSize and UnitExists(unit) and UnitIsPlayer(unit)then
            local dataIndex = UnitGUID(unit)
            local data = Memory.playerData[dataIndex]
            if not data then
                Memory.playerData[dataIndex] = {
                    name = UNKNOWNOBJECT,
                    readyState = ReadyCheckState.Nothing,
                    deserterExpiry = -1,
                    mercenaryExpiry = -1,
                }

                data = Memory.playerData[dataIndex]
            end

            data.unit = unit

            tableCache[index] = Private.CreateTableRow(data)
        end
    end

    Memory.playerTableCache = tableCache

    Private.ScheduleSendMercenaryDuration(Private.GetPlayerAuraExpiryTime(SpellIds.MercenaryContractBuff))

    Private.UpdatePlayerTableData()
end

function Private.UpdateQueuesFrameVisibility()
    if not _G.BgcQueueFrame then return end

    if Memory.showGroupQueueFrame then
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
    checkbox:SetChecked(Memory.showGroupQueueFrame)
    checkbox:HookScript('OnClick', function (self)
        Private.SetGroupQueueVisibility(self:GetChecked())
        Private.UpdateQueuesFrameVisibility()

        if Memory.showGroupQueueFrame then
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
    local payload = CommunicationEvent.unpackData(text);
    if not payload or payload.remaining == nil then return end

    local data = Private.GetPlayerDataByName(sender)
    if not data then return end

    data.hasAddon = true
    data.mercenaryExpiry = payload.remaining + GetTime()

    Private.RefreshPlayerTable()
end

function Module:OnInitialize()
    self:RegisterEvent('ADDON_LOADED')
end

function Module:OnEnable()
    self:RegisterEvent('READY_CHECK')
    self:RegisterEvent('READY_CHECK_CONFIRM')
    self:RegisterEvent('READY_CHECK_FINISHED')
    self:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')

    local update = function () Private.TriggerStateUpdates(false) end
    self:RegisterEvent('GROUP_ROSTER_UPDATE', update);
    self:RegisterEvent('PLAYER_ENTERING_WORLD', update);

    self:RegisterComm(CommunicationEvent.NotifyMercenaryDuration, Private.OnNotifyMercenaryDuration)

    Namespace.Database.RegisterCallback(self, 'OnProfileChanged', 'RefreshConfig')
    Namespace.Database.RegisterCallback(self, 'OnProfileCopied', 'RefreshConfig')
    Namespace.Database.RegisterCallback(self, 'OnProfileReset', 'RefreshConfig')

    self:RefreshConfig()
end

function Module:RefreshConfig()
    Memory.showGroupQueueFrame = Namespace.Database.profile.QueueTools.showGroupQueueFrame
end

function Module:COMBAT_LOG_EVENT_UNFILTERED()
    local _, subEvent, _, sourceGUID, _, _, _, _, _, _, _, spellId  = CombatLogGetCurrentEventInfo()
    if spellId ~= SpellIds.MercenaryContractBuff or sourceGUID ~= UnitGUID('player') then return end

    if subEvent == 'SPELL_AURA_APPLIED' or subEvent == 'SPELL_AURA_REFRESH' or subEvent == 'SPELL_AURA_REMOVED' then
        Private.ScheduleSendMercenaryDuration(Private.GetPlayerAuraExpiryTime(SpellIds.MercenaryContractBuff))
    end
end

function Module:READY_CHECK(_, initiatedByName, duration)
    Memory.lastReadyCheckTime = GetTime()
    Memory.lastReadyCheckDuration = duration

    for _, data in pairs(Memory.playerData) do
        data.readyState = ReadyCheckState.Waiting
    end

    local initiatedByData = Private.GetPlayerDataByName(initiatedByName)
    if initiatedByData ~= nil then
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

    Private.TriggerStateUpdates(true)
    Private.RefreshPlayerTable()
end

function Module:READY_CHECK_CONFIRM(_, unit, ready)
    local data = Private.GetPlayerDataByUnit(unit)
    if not data then return end

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
    queueFrame.CloseButton:HookScript('OnClick', function ()
        PlaySound(CharacterPanelCloseSound)
        Private.SetGroupQueueVisibility(false)
        _G.BgcBattlegroundModeCheckbox:SetChecked(false)
    end)
    queueFrame:SetPortraitToAsset([[Interface\LFGFrame\UI-LFR-PORTRAIT]]);
    PVPUIFrame.QueueFrame = queueFrame

    local playerTable = ScrollingTable:CreateST(tableStructure, nil, 24, nil, queueFrame)
    playerTable.frame:SetBackdropColor(0, 0, 0, 0)
    playerTable.frame:SetBackdropBorderColor(0, 0, 0, 0)
    playerTable:RegisterEvents({}, true)

    playerTable.frame:HookScript('OnShow', function (self)
        self.refreshTimer = Module:ScheduleRepeatingTimer(Private.RefreshPlayerTable, Config.tableRefreshSeconds)
    end)
    playerTable.frame:HookScript('OnHide', function (self)
        Module:CancelTimer(self.refreshTimer)
    end)

    queueFrame.PlayerTable = playerTable

    local readyCheckButton = CreateFrame('Button', 'BgcReadyCheckButton', queueFrame, 'UIPanelButtonTemplate')
    readyCheckButton:SetText(L['Ready Check'])
    readyCheckButton:SetPoint('BOTTOM', 0, 3)
    readyCheckButton:SetSize(120, 22)
    readyCheckButton:HookScript('OnClick', function () DoReadyCheck() end)

    queueFrame.ReadyCheckButton = readyCheckButton

    Private.TriggerStateUpdates(false)
end

function Module:ADDON_LOADED(_, addonName)
    if addonName == 'Blizzard_PVPUI' then
        Private.InitializeBattlegroundModeCheckbox()
        Private.InitializeGroupQueueFrame()
        _G.PVPUIFrame:HookScript('OnShow', function () Private.UpdateQueuesFrameVisibility() end)
        self:UnregisterEvent('ADDON_LOADED')
    end
end
