local BattlegroundCommander = LibStub('AceAddon-3.0'):NewAddon('BattlegroundCommander', 'AceEvent-3.0', 'AceTimer-3.0', 'AceComm-3.0')
local L = LibStub('AceLocale-3.0'):GetLocale('BattlegroundCommander')
local ScrollingTable = LibStub('ScrollingTable')
local Serializer = LibStub:GetLibrary("AceSerializer-3.0")
local Compressor = LibStub:GetLibrary("LibCompress")
local libCE = Compressor:GetAddonEncodeTable()

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
local UnitName = UnitName
local UnitDebuff = UnitDebuff
local UnitIsPlayer = UnitIsPlayer
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local GetTime = GetTime
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local DEBUFF_MAX_DISPLAY = DEBUFF_MAX_DISPLAY
local ceil = math.ceil
local format = string.format
local pairs = pairs

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

local tableRefreshSeconds = 10
local readyCheckStateResetSeconds = 10
local requestMercenaryDurationDelay = 5
local showGroupQueueFrame = false
local playerTableCache = {}
local readyCheckClearTimeout

local CommunicationEvent = {
    NotifyMercenaryDuration = 'Bgc:notifyMerc',
    RequestMercenaryDuration = 'Bgc:requestMerc',
    packData = function (data)
        return libCE:Encode(Compressor:CompressHuffman(Serializer:Serialize(data)))
    end,
    unpackData = function (raw)
        local decompressed = Compressor:Decompress(libCE:Decode(raw))
        if not decompressed then
            return
        end

        local success, data = Serializer:Deserialize(decompressed)
        if not success then
            return
        end

        return data
    end
}

local ColorList = {
    Bad = { r = 1.0, g = 0, b = 0, a = 1.0 },
    Good = { r = 0, g = 1.0, b = 0, a = 1.0 },
    Warning = { r = 1.0, g = 1.0, b = 0, a = 1.0 },
    UnknownClass = { r = 0.7, g = 0.7, b = 0.7, a = 1.0 },
}

local playerData = {
    --[playerName] = {
    --    name = playerName,
    --    unit = 'unit',
    --    class = 'CLASS',
    --    readyState = ReadyCheckState.Nothing,
    --    deserterExpiry = -1,
    --    mercenaryExpiry = -1,
    --    hasAddon = false,
    --},
}

local notifyMercenaryDuration = function (expirationTime)
    BattlegroundCommander:SendCommMessage(
        CommunicationEvent.NotifyMercenaryDuration,
        CommunicationEvent.packData({ remaining = expirationTime - GetTime() }),
        'PARTY'
    )
end

local getPlayerDataByUnit = function (unit)
    for _, data in pairs(playerData) do
        if data.unit == unit then return data end
    end

    return nil
end

local resetPlayersReadyState = function ()
    for _, player in pairs(playerData) do
        player.readyState = ReadyCheckState.Nothing
    end
end

--@debug@
function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k,v in pairs(o) do
            if type(k) ~= 'number' then k = '\''..k..'\'' end
            s = s .. '['..k..'] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end
--@end-debug@

local canDoReadyCheck = function ()
    if not UnitIsGroupLeader('player') and not UnitIsGroupAssistant('player') then
        return false
    end

    local _, instanceType = GetInstanceInfo()

    return instanceType ~= 'pvp' and instanceType ~= 'arena'
end

local createTableRow = function (player)
    local _, class = UnitClass(player.unit)
    local colors = class and RAID_CLASS_COLORS[class] or ColorList.UnknownClass
    local nameColumn = {
        value = player.name,
        color = { r = colors.r, g = colors.g, b = colors.b, a = colors.a },
    }

    local mercenaryColumn = {
        value = function(data, _, realRow, column)
            local columnData = data[realRow].cols[column]
            if not player.hasAddon then
                columnData.color = ColorList.Warning
                return '?'
            end

            columnData.color = nil
            local remaining = player.mercenaryExpiry - GetTime()
            if remaining < 1 then
                return L['no']
            end

            return format('<%dm', ceil(remaining / 60))
        end,
    }

    local deserterColumn = {
        value = function(data, _, realRow, column)
            local columnData = data[realRow].cols[column]
            local remaining = player.deserterExpiry - GetTime()
            if remaining < 1 then
                columnData.color = ColorList.Good
                return L['no']
            end

            columnData.color = ColorList.Bad
            return format('<%dm', ceil(remaining / 60))
        end,
    }

    local readyCheckColumn = {
        value = function(data, _, realRow, column)
            local columnData = data[realRow].cols[column]
            local readyState = player.readyState;
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

local refreshPlayerTable = function ()
    if not BgcQueueFrame or not showGroupQueueFrame then return end

    BgcQueueFrame.PlayerTable:Refresh()
end

local updatePlayerTableData = function ()
    if not BgcQueueFrame or not showGroupQueueFrame then return end

    BgcQueueFrame.PlayerTable:SetData(playerTableCache)
end

local triggerDeserterUpdate = function (player)
    if player.deserterExpiry > 0 and player.deserterExpiry <= GetTime() then
        player.deserterExpiry = -1
    end

    if player.deserterExpiry > -1 then
        -- only re-check if the player doesn't have it already
        return
    end

    for i = 1, DEBUFF_MAX_DISPLAY do
        local _, _, _, _, _, expirationTime, _, _, _, spellId = UnitDebuff(player.unit, i)
        if spellId == SpellIds.DeserterDebuff then
            player.deserterExpiry = expirationTime

            return
        end
    end
end

local unitOrder = { 'player', 'party1', 'party2', 'party3', 'party4' }
local triggerStateUpdates = function ()
    if BgcReadyCheckButton then BgcReadyCheckButton:SetEnabled(canDoReadyCheck()) end

    local tableCache = {}
    local index = 0

    for _, unit in pairs(unitOrder) do
        if UnitExists(unit) and UnitIsPlayer(unit) then
            local name, realm = UnitName(unit)
            if realm ~= '' and realm ~= nil then
                name = name .. '-' .. realm
            end

            if not playerData[name] then
                playerData[name] = {
                    name = name,
                    unit = unit,
                    readyState = ReadyCheckState.Nothing,
                    deserterExpiry = -1,
                    mercenaryExpiry = -1,
                }
            else
                playerData[name].unit = unit
            end

            local player = playerData[name]

            triggerDeserterUpdate(player)

            index = index + 1
            tableCache[index] = createTableRow(player)
        end
    end

    playerTableCache = tableCache

    updatePlayerTableData()
end

local updateQueuesFrameVisibility = function ()
    if not BgcQueueFrame then return end

    if showGroupQueueFrame then
        BgcQueueFrame:Show()
    else
        BgcQueueFrame:Hide()
    end

    updatePlayerTableData()
end

local initializeBattlegroundModeCheckbox = function ()
    local checkbox = CreateFrame('CheckButton', 'BgcBattlegroundModeCheckbox', PVPUIFrame, 'UICheckButtonTemplate')
    checkbox:SetPoint('BOTTOMRIGHT', PVEFrame, 'BOTTOMRIGHT', -2, 2)
    checkbox:SetSize(24, 24)
    checkbox:SetChecked(showGroupQueueFrame)
    checkbox:HookScript('OnClick', function (self)
        if not BgcQueueFrame then return end

        showGroupQueueFrame = self:GetChecked()
        updateQueuesFrameVisibility()

        if showGroupQueueFrame then
            PlaySound(CharacterPanelOpenSound)
        else
            PlaySound(CharacterPanelCloseSound)
        end
    end)
    checkbox:Show()

    PVEFrame.BattlegroundModeCheckbox = checkbox

    local text = checkbox:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
    text:SetText(L['Group Mode'])
    text:SetPoint('RIGHT', checkbox, 'LEFT')
    text:SetWordWrap(false)

    checkbox.Text = text
end

function BattlegroundCommander:OnInitialize()
    self:RegisterEvent('ADDON_LOADED')
    self:RegisterEvent('READY_CHECK')
    self:RegisterEvent('READY_CHECK_CONFIRM')
    self:RegisterEvent('READY_CHECK_FINISHED')
    self:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')

    self:RegisterEvent('GROUP_ROSTER_UPDATE', triggerStateUpdates);
    self:RegisterEvent('PLAYER_ENTERING_WORLD', triggerStateUpdates);

    self:RegisterComm(CommunicationEvent.NotifyMercenaryDuration, function (_, text, _, sender)
        local data = CommunicationEvent.unpackData(text);
        if not data or data.remaining == nil or not playerData[sender] then return end

        playerData[sender].hasAddon = true
        playerData[sender].mercenaryExpiry = data.remaining + GetTime()

        refreshPlayerTable()
    end)

    self:RegisterComm(CommunicationEvent.RequestMercenaryDuration, function ()
        local _, _, _, _, _, expirationTime = GetPlayerAuraBySpellID(SpellIds.MercenaryContractBuff)
        notifyMercenaryDuration(expirationTime or -1)
    end)

    self:ScheduleTimer(function ()
        BattlegroundCommander:SendCommMessage(CommunicationEvent.RequestMercenaryDuration, '1', 'PARTY')
    end, requestMercenaryDurationDelay)
end

function BattlegroundCommander:COMBAT_LOG_EVENT_UNFILTERED()
    local _, subEvent, _, sourceGUID, _, _, _, _, _, _, _, spellId  = CombatLogGetCurrentEventInfo()
    if spellId ~= SpellIds.MercenaryContractBuff or sourceGUID ~= UnitGUID('player') then return end

    if subEvent == 'SPELL_AURA_APPLIED' or subEvent == 'SPELL_AURA_REFRESH' then
        local _, _, _, _, _, expirationTime = GetPlayerAuraBySpellID(SpellIds.MercenaryContractBuff)
        notifyMercenaryDuration(expirationTime)
    elseif  subEvent == 'SPELL_AURA_REMOVED' then
        notifyMercenaryDuration(-1)
    end
end

function BattlegroundCommander:READY_CHECK(_, initiatedByName)
    for name, data in pairs(playerData) do
        data.readyState = initiatedByName == name and ReadyCheckState.Ready or ReadyCheckState.Waiting
    end

    refreshPlayerTable()
end

function BattlegroundCommander:READY_CHECK_CONFIRM(_, unit, ready)
    local data = getPlayerDataByUnit(unit)

    if not data then return end

    if readyCheckClearTimeout then
        self:CancelTimer(readyCheckClearTimeout)
        readyCheckClearTimeout = nil
    end

    data.readyState = ready and ReadyCheckState.Ready or ReadyCheckState.Declined

    refreshPlayerTable()
end

function BattlegroundCommander:READY_CHECK_FINISHED()
    for _, data in pairs(playerData) do
        if data.readyState == ReadyCheckState.Waiting then
            -- in case of expired ready check no confirmation means declined
            data.readyState = ReadyCheckState.Declined
        end
    end

    readyCheckClearTimeout = self:ScheduleTimer(function ()
        resetPlayersReadyState()
        refreshPlayerTable()
        readyCheckClearTimeout = nil
    end, readyCheckStateResetSeconds)
end

local initializeGroupQueueFrame = function()
    local queueFrame = CreateFrame('Frame', 'BgcQueueFrame', PVPUIFrame, 'ButtonFrameTemplate')
    queueFrame:SetSize(350, PVPUIFrame:GetHeight() - 2)
    queueFrame:SetPoint('TOPLEFT', PVPUIFrame, 'TOPRIGHT', 11, 0)
    queueFrame:SetPoint('BOTTOMLEFT', PVPUIFrame, 'BOTTOMRIGHT', 11, 0)
    queueFrame.TitleText:SetText(L['Group Information'])
    queueFrame.CloseButton:HookScript('OnClick', function ()
        PlaySound(CharacterPanelCloseSound)
        showGroupQueueFrame = false
        BgcBattlegroundModeCheckbox:SetChecked(false)
    end)
    queueFrame:SetPortraitToAsset([[Interface\LFGFrame\UI-LFR-PORTRAIT]]);
    PVPUIFrame.QueueFrame = queueFrame

    local table = ScrollingTable:CreateST(tableStructure, nil, 24, nil, queueFrame)
    table.frame:SetBackdropColor(0, 0, 0, 0)
    table.frame:SetBackdropBorderColor(0, 0, 0, 0)
    table:RegisterEvents({}, true)

    table.frame:HookScript('OnShow', function (self)
        self.refreshTimer = BattlegroundCommander:ScheduleRepeatingTimer(refreshPlayerTable, tableRefreshSeconds)
    end)
    table.frame:HookScript('OnHide', function (self)
        BattlegroundCommander:CancelTimer(self.refreshTimer)
    end)

    queueFrame.PlayerTable = table

    local readyCheckButton = CreateFrame('Button', 'BgcReadyCheckButton', queueFrame, 'UIPanelButtonTemplate')
    readyCheckButton:SetText(L['Ready Check'])
    readyCheckButton:SetPoint('BOTTOM', 0, 3)
    readyCheckButton:SetSize(120, 22)
    readyCheckButton:HookScript('OnClick', function () DoReadyCheck() end)

    queueFrame.ReadyCheckButton = readyCheckButton

    triggerStateUpdates()
end

function BattlegroundCommander:ADDON_LOADED(_, addonName)
    if addonName == 'Blizzard_PVPUI' then
        initializeBattlegroundModeCheckbox()
        initializeGroupQueueFrame()
        PVPUIFrame:HookScript('OnShow', function () updateQueuesFrameVisibility() end)
    end
end
