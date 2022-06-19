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
                font = {
                    family = 'Friz Quadrata TT',
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

        addonOptions = {
            name = Namespace.Meta.name,
            type = 'group',
            args = {
                information = {
                    name = L['Addon Information'],
                    type = 'group',
                    inline = true,
                    args = {
                        version = {
                            name =  format(L['Version'] .. ': %s (%s)', Namespace.Meta.version, Namespace.Meta.date),
                            type = 'description',
                            width = 'full',
                        },
                    }
                },
                battleground_tools = {
                    name = L['Battleground Tools'],
                    type = 'group',
                    args = {
                        enable_instructions_frame = {
                            name = L['Enable Instructions Frame'],
                            type = 'toggle',
                            width = 'full',
                            set = function (_, value) Namespace.BattlegroundTools:SetInstructionFrameState(value) end,
                            get = function () return Namespace.BattlegroundTools:GetInstructionFrameState() end,
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
