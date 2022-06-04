local LibStub, AddonName, Namespace = LibStub, ...

Namespace.Libs = {
    AceLocale = LibStub('AceLocale-3.0'),
    AceAddon = LibStub('AceAddon-3.0'),
    ScrollingTable = LibStub('ScrollingTable'),
    AceDB = LibStub('AceDB-3.0'),
    AceSerializer = LibStub('AceSerializer-3.0'),
    LibCompress = LibStub('LibCompress'),
}

local defaultConfig = {
    profile = {
        QueueTools = {
            showGroupQueueFrame = false,
        },
    },
}

Namespace.Addon = Namespace.Libs.AceAddon:NewAddon(AddonName)

function Namespace.Addon:OnInitialize()
    Namespace.Debug.log(AddonName, 'Initialized')

    Namespace.Database = Namespace.Libs.AceDB:New('BattlegroundCommanderDatabase', defaultConfig, true)
end
