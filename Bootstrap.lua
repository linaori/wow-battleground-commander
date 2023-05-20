local LibStub, AddonName, Namespace = LibStub, ...

local Settings = Settings
local format = string.format
local pairs = pairs
local tonumber = tonumber
local strsplit = strsplit

local Memory = {
    OptionsFrames = {},
}

Namespace.Meta = {
    nameShort = 'BG Commander',
    name = 'Battleground Commander',
    version = [[@project-version@]],
    versionIncrement = 0,
    date = [[@project-date-iso@]],
    chatTemplate = '[Battleground Commander] %s',
    discord = 'https://discord.gg/7tKEKMCkGq',
}

Namespace.Libs = {
    AceAddon = LibStub('AceAddon-3.0'),
    AceConfig = LibStub('AceConfig-3.0'),
    AceConfigRegistry = LibStub('AceConfigRegistry-3.0'),
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
    LibDropDownExtension = LibStub('LibDropDownExtension-1.0'),
}

local Addon = Namespace.Libs.AceAddon:NewAddon(AddonName, 'AceConsole-3.0', 'AceEvent-3.0')

Namespace.Addon = Addon

function Addon:PrependChatTemplate(message)
    return format(Namespace.Meta.chatTemplate, message)
end

function Addon:ExtractVersionIncrement(version)
    local _, increment = strsplit('-', version, 2)

    return increment == 'dev' and 99999 or tonumber(increment)
end

function Addon:OnInitialize()
    Namespace.Meta.versionIncrement = self:ExtractVersionIncrement(Namespace.Meta.version)

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

    self:RegisterEvent('GROUP_ROSTER_UPDATE', Namespace.PlayerData.RebuildPlayerData)
    self:RegisterEvent('PARTY_LEADER_CHANGED', Namespace.PlayerData.RebuildRoleData)

    self:RegisterChatCommand('bgc', 'ChatCommand')
    self:RegisterChatCommand('battlegroundcommander', 'ChatCommand')

    Namespace.Database.RegisterCallback(self, 'OnProfileChanged', 'MigrateConfig')
    Namespace.Database.RegisterCallback(self, 'OnProfileCopied', 'MigrateConfig')
    Namespace.Database.RegisterCallback(self, 'OnProfileReset', 'MigrateConfig')

    self:MigrateConfig()

    Addon:InitializePlayerConfig()
end

function Addon:InitializePlayerConfig()
    local configurationSetup = Namespace.Config.GetConfigurationSetup()

    local PlayerManagement = configurationSetup.args.BattlegroundTools.args.PlayerManagement
    for playerName, config in pairs(Namespace.BattlegroundTools:GetAllPlayerConfig()) do
        PlayerManagement.args[playerName] = Namespace.Config.CreatePlayerConfigNode(config)
    end

    Namespace.Libs.AceConfigRegistry:NotifyChange(AddonName)
end

function Addon:MigrateConfig()
    local inspectQueue = Namespace.Database.profile.QueueTools.InspectQueue
    if inspectQueue.doReadyCheck == false then
        inspectQueue.doReadyCheckOnQueuePause = false
        inspectQueue.doReadyCheck = nil
    end

    local config = Namespace.Database.profile.BattlegroundTools
    config.InstructionFrame.zones[0] = nil
    config.LeaderTools.promoteListed = nil

    local BattlegroundTools = Namespace.BattlegroundTools
    if config.LeaderTools.automaticAssist then
        for playerName, _ in pairs(config.LeaderTools.automaticAssist) do
            BattlegroundTools:SetPlayerConfigValue(playerName, 'promoteToAssistant', true)
            if config.LeaderTools.alsoMarkListedAssists then
                BattlegroundTools:SetPlayerConfigValue(playerName, 'markBehavior', BattlegroundTools.MarkBehavior.AnyAvailable)
            end
        end

        config.LeaderTools.alsoMarkListedAssists = nil
        config.LeaderTools.automaticAssist = nil
    end

    if config.LeaderTools.automaticIcon then
        for playerName, _ in pairs(config.LeaderTools.automaticIcon) do
            BattlegroundTools:SetPlayerConfigValue(playerName, 'markBehavior', BattlegroundTools.MarkBehavior.AnyAvailable)
        end

        config.LeaderTools.automaticIcon = nil
    end

    if config.WantBattlegroundLead.automaticallyAccept then
        for playerName, _ in pairs(config.WantBattlegroundLead.automaticallyAccept) do
            BattlegroundTools:SetPlayerConfigValue(playerName, 'giveLeadBehavior', BattlegroundTools.GiveLeadBehavior.GiveLead)
        end

        config.WantBattlegroundLead.automaticallyAccept = nil
    end

    if config.WantBattlegroundLead.automaticallyReject then
        for playerName, _ in pairs(config.WantBattlegroundLead.automaticallyReject) do
            BattlegroundTools:SetPlayerConfigValue(playerName, 'giveLeadBehavior', BattlegroundTools.GiveLeadBehavior.RejectLead)
        end

        config.WantBattlegroundLead.automaticallyReject = nil
    end
end

function Addon:OpenSettingsPanel()
    Settings.OpenToCategory(Memory.OptionsFrames.Information.name)
end

_G.BattlegroundCommander_OnAddonCompartmentClick = Addon.OpenSettingsPanel

function Addon:OpenPlayerConfig(playerName)
    Namespace.Config.AddPlayerConfig(playerName)

    local ACD = Namespace.Libs.AceConfigDialog
    ACD:Open(AddonName, nil, 'BattlegroundTools', 'PlayerManagement')
    ACD:SelectGroup(AddonName, 'BattlegroundTools', 'PlayerManagement', playerName)
end

function Addon:ChatCommand(input)
    if not input or input:trim() == '' then return self:OpenSettingsPanel() end

    Namespace.Libs.AceConfigCmd:HandleCommand(AddonName, AddonName, input)
end
