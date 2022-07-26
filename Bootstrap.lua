local LibStub, AddonName, Namespace = LibStub, ...

local InterfaceOptionsFrame_OpenToCategory = InterfaceOptionsFrame_OpenToCategory
local format = string.format
local print = print

local Memory = {
    OptionsFrames = {},
}

Namespace.Meta = {
    nameShort = 'BG Commander',
    name = 'Battleground Commander',
    version = [[@project-version@]],
    date = [[@project-date-iso@]],
    chatTemplate = '[Battleground Commander] %s',
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
    LibDropDown = LibStub('LibUIDropDownMenu-4.0'),
}

local Addon = Namespace.Libs.AceAddon:NewAddon(AddonName, 'AceConsole-3.0')

Namespace.Addon = Addon

function Addon:PrintMessage(message)
    print(self:PrependChatTemplate(message))
end

function Addon:PrependChatTemplate(message)
    return format(Namespace.Meta.chatTemplate, message)
end

function Addon:OnInitialize()
    local configurationSetup = Namespace.Config.GetConfigurationSetup()

    Namespace.Database = Namespace.Libs.AceDB:New('BattlegroundCommanderDatabase', Namespace.Config.GetDefaultConfiguration(), true)
    configurationSetup.args.Profiles = Namespace.Libs.AceDBOptions:GetOptionsTable(Namespace.Database)

    Namespace.Libs.AceConfig:RegisterOptionsTable(AddonName, configurationSetup)

    local ACD = Namespace.Libs.AceConfigDialog

    Memory.OptionsFrames = {
        Information = ACD:AddToBlizOptions(AddonName, Namespace.Meta.nameShort, nil, 'Information'),
        QueueTools = ACD:AddToBlizOptions(AddonName, configurationSetup.args.QueueTools.name, Namespace.Meta.nameShort, 'QueueTools'),
        BattlegroundTools = ACD:AddToBlizOptions(AddonName, configurationSetup.args.BattlegroundTools.name, Namespace.Meta.nameShort, 'BattlegroundTools'),
        Profiles = ACD:AddToBlizOptions(AddonName, configurationSetup.args.Profiles.name, Namespace.Meta.nameShort, 'Profiles'),
    }

    self:RegisterChatCommand('bgc', 'ChatCommand')
    self:RegisterChatCommand('battlegroundcommander', 'ChatCommand')

    Namespace.Database.RegisterCallback(self, 'OnProfileChanged', 'MigrateConfig')
    Namespace.Database.RegisterCallback(self, 'OnProfileCopied', 'MigrateConfig')
    Namespace.Database.RegisterCallback(self, 'OnProfileReset', 'MigrateConfig')

    self:MigrateConfig()
end

function Addon:MigrateConfig()
    local inspectQueue = Namespace.Database.profile.QueueTools.InspectQueue
    if inspectQueue.doReadyCheck == false then
        inspectQueue.doReadyCheckOnQueuePause = false
        inspectQueue.doReadyCheck = nil
    end
end

function Addon:OpenSettingsPanel()
    local frames = Memory.OptionsFrames

    InterfaceOptionsFrame_OpenToCategory(frames.Profiles)
    InterfaceOptionsFrame_OpenToCategory(frames.Profiles)
    InterfaceOptionsFrame_OpenToCategory(frames.Information)
end

function Addon:ChatCommand(input)
    if not input or input:trim() == '' then return self:OpenSettingsPanel() end

    Namespace.Libs.AceConfigCmd:HandleCommand(AddonName, AddonName, input)
end
