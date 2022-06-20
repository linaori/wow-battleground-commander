local LibStub, AddonName, Namespace = LibStub, ...

local InterfaceOptionsFrame_OpenToCategory = InterfaceOptionsFrame_OpenToCategory
local format = string.format

_G.BattlegroundCommander = Namespace

Namespace.Meta = {
    nameShort = 'BG Commander',
    name    = 'Battleground Commander',
    version = [[@project-version@]],
    date    = [[@project-date-iso@]],
}

Namespace.Libs = {
    AceAddon = LibStub('AceAddon-3.0'),
    AceConfig = LibStub('AceConfig-3.0'),
    AceConfigCmd = LibStub('AceConfigCmd-3.0'),
    AceConfigDialog = LibStub('AceConfigDialog-3.0'),
    AceDB = LibStub('AceDB-3.0'),
    AceDBOptions = LibStub('AceDBOptions-3.0'),
    AceLocale = LibStub('AceLocale-3.0'),
    AceSerializer = LibStub('AceSerializer-3.0'),
    LibCompress = LibStub('LibCompress'),
    LibSharedMedia = LibStub('LibSharedMedia-3.0'),
    ScrollingTable = LibStub('ScrollingTable'),
}

local defaultConfig = {
    profile = {
        QueueTools = {
            showGroupQueueFrame = false,
        },
        BattlegroundTools = {
            InstructionFrame = {
                show = true,
                move = true,
                size = { width = 150, height = 50 },
                position = { anchor = 'CENTER', x = 0, y = 0 },
                messageCount = 5,
                zones = {
                    [0]    = false,
                    [30]   = true,
                    [2197] = true,
                    [1191] = true,
                    [2118] = true,
                    [628]  = true,
                    [2107] = true,
                    [529]  = true,
                    [1681] = true,
                    [2177] = true,
                    [1105] = true,
                    [566]  = true,
                    [968]  = true,
                    [628]  = true,
                    [1803] = true,
                    [727]  = true,
                    [607]  = true,
                    [998]  = true,
                    [761]  = true,
                    [726]  = true,
                    [489]  = true,
                },
                font = {
                    family = Namespace.Libs.LibSharedMedia:GetDefault('font'),
                    size = 12,
                    flags = '',
                    colorTime = { r = 0.5, g = 0.5, b = 0.5 },
                    colorHighlight = { r = 1, g = 0.28, b = 0 },
                    color = { r = 0.7, g = 0.5, b = 0 },
                    shadowColor = { 0, 0, 0, 1 },
                    shadowOffset = { x = 1, y = -1 },
                },
            },
        }
    },
}

local addonOptions
local function getOptions()
    if not addonOptions then
        local L = Namespace.Libs.AceLocale:GetLocale(AddonName)
        local fontFlagList = { [''] = 'None', ['OUTLINE'] = 'Outline', ['OUTLINE, MONOCHROME'] = 'Outline Monochrome' }
        local LibSharedMediaFonts = Namespace.Libs.LibSharedMedia:HashTable('font')

        addonOptions = {
            name = Namespace.Meta.name,
            type = 'group',
            args = {
                information = {
                    name = L['Addon Information'],
                    type = 'group',
                    order = 1,
                    args = {
                        version = {
                            name =  format(L['Version'] .. ': %s (%s)', Namespace.Meta.version, Namespace.Meta.date),
                            type = 'description',
                            width = 'full',
                            fontSize = 'medium',
                        },
                    }
                },
                battleground_tools = {
                    name = L['Battleground Tools'],
                    type = 'group',
                    order = 2,
                    args = {
                        instructions_frame = {
                            name = L['Instructions Frame'],
                            type = 'group',
                            inline = true,
                            order = 2.1,
                            args = {
                                enable = {
                                    name = L['Enable'],
                                    desc = L['Enables or disables the instructions frame that captures raid warnings'],
                                    type = 'toggle',
                                    set = function (_, value) Namespace.BattlegroundTools:SetInstructionFrameState(value) end,
                                    get = function () return Namespace.BattlegroundTools:GetInstructionFrameState() end,
                                    order = 2.111,
                                },
                                reposition = {
                                    name = L['Allow Repositioning'],
                                    desc = L['Enable to be able to drag the frame around to reposition'],
                                    type = 'toggle',
                                    set = function (_, value) Namespace.BattlegroundTools:SetInstructionFrameMoveState(value) end,
                                    get = function () return Namespace.BattlegroundTools:GetInstructionFrameMoveState() end,
                                    order = 2.112,
                                },
                                enableFiller = {
                                    name = ' ',
                                    type = 'description',
                                    width = 'full',
                                    order = 2.113,
                                },
                                font = {
                                    name = L['Font'],
                                    desc = L['Font used for the text inside the frame'],
                                    type = 'select',
                                    dialogControl = 'LSM30_Font',
                                    values = LibSharedMediaFonts,
                                    set = function (_, value) Namespace.BattlegroundTools:SetFontSetting('family', value) end,
                                    get = function () return Namespace.BattlegroundTools:GetFontSetting('family') end,
                                    order = 2.121,
                                },
                                fontFlags = {
                                    name = L['Font Flags'],
                                    desc = L['Adjust the font flags'],
                                    type = 'select',
                                    values = fontFlagList,
                                    set = function (_, value) Namespace.BattlegroundTools:SetFontSetting('flags', value) end,
                                    get = function () return Namespace.BattlegroundTools:GetFontSetting('flags') end,
                                    order = 2.122,
                                },
                                fontSize = {
                                    name = L['Font Size'],
                                    desc = L['Adjust the font size for the messages and time'],
                                    type = 'range',
                                    min = 4,
                                    max = 50,
                                    softMin = 8,
                                    softMax = 20,
                                    step = 1,
                                    set = function (_, value) Namespace.BattlegroundTools:SetFontSetting('size', value) end,
                                    get = function () return Namespace.BattlegroundTools:GetFontSetting('size') end,
                                    order = 2.123,

                                },
                                fontFiller = {
                                    name = ' ',
                                    type = 'description',
                                    width = 'full',
                                    order = 2.124,
                                },
                                highlightColor = {
                                    name = L['Highlight Color'],
                                    desc = L['Color of the most recent text message'],
                                    type = 'color',
                                    set = function (_, r, g, b)
                                        Namespace.BattlegroundTools:SetFontSetting('colorHighlight', { r = r, g = g, b = b })
                                    end,
                                    get = function ()
                                        local color = Namespace.BattlegroundTools:GetFontSetting('colorHighlight')
                                        return color.r, color.g, color.b
                                    end,
                                    order = 2.131,
                                },
                                color = {
                                    name = L['Text Color'],
                                    desc = L['Color of the remaining text messages'],
                                    type = 'color',
                                    set = function (_, r, g, b) Namespace.BattlegroundTools:SetFontSetting('color', { r = r, g = g, b = b }) end,
                                    get = function ()
                                        local color = Namespace.BattlegroundTools:GetFontSetting('color')
                                        return color.r, color.g, color.b
                                    end,
                                    order = 2.132,
                                },
                                timerColor = {
                                    name = L['Time Color'],
                                    desc = L['Color of the time text'],
                                    type = 'color',
                                    set = function (_, r, g, b )Namespace.BattlegroundTools:SetFontSetting('colorTime', { r = r, g = g, b = b }) end,
                                    get = function ()
                                        local color = Namespace.BattlegroundTools:GetFontSetting('colorTime')
                                        return color.r, color.g, color.b
                                    end,
                                    order = 2.133,
                                },
                                zones = {
                                    name = L['Enabled in Zones'],
                                    desc = L['Select the battlegrounds where the frame should appear'],
                                    type = 'multiselect',
                                    values = Namespace.BattlegroundTools.Zones,
                                    set = function (_, zoneId, value) Namespace.BattlegroundTools:SetZoneId(zoneId, value) end,
                                    get = function (_, zoneId) return Namespace.BattlegroundTools:GetZoneId(zoneId) end,
                                    order = 2.141,
                                }
                            },
                        },
                    },
                },
            },
        }
    end

    return addonOptions
end

local Addon = Namespace.Libs.AceAddon:NewAddon(AddonName, 'AceConsole-3.0')

Namespace.Addon = Addon

function Addon:OnInitialize()
    local options = getOptions()

    Namespace.Database = Namespace.Libs.AceDB:New('BattlegroundCommanderDatabase', defaultConfig, true)
    options.args.profiles = Namespace.Libs.AceDBOptions:GetOptionsTable(Namespace.Database)

    Namespace.Libs.AceConfig:RegisterOptionsTable(AddonName, options)

    local ACD = Namespace.Libs.AceConfigDialog;
    self.optionsFrame = {
        information = ACD:AddToBlizOptions(AddonName, Namespace.Meta.nameShort, nil, 'information'),
        battleground_tools = ACD:AddToBlizOptions(AddonName, options.args.battleground_tools.name, Namespace.Meta.nameShort, 'battleground_tools'),
        profiles = ACD:AddToBlizOptions(AddonName, options.args.profiles.name, Namespace.Meta.nameShort, 'profiles'),
    }

    self:RegisterChatCommand('bgc', 'ChatCommand')
    self:RegisterChatCommand('battlegroundcommander', 'ChatCommand')
end

function Addon:ChatCommand(input)
    if not input or input:trim() == '' then
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrame.profiles)
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrame.profiles)
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrame.information)
        return
    end

    Namespace.Libs.AceConfigCmd:HandleCommand(AddonName, AddonName, input)
end
