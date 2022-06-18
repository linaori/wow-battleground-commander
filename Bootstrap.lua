local LibStub, AddonName, Namespace = LibStub, ...

Namespace.Libs = {
    AceLocale = LibStub('AceLocale-3.0'),
    AceAddon = LibStub('AceAddon-3.0'),
    ScrollingTable = LibStub('ScrollingTable'),
    AceDB = LibStub('AceDB-3.0'),
    AceSerializer = LibStub('AceSerializer-3.0'),
    LibCompress = LibStub('LibCompress'),
    LibSharedMedia = LibStub('LibSharedMedia-3.0'),
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
                messageCount = 5,
                font = {
                    family = 'Friz Quadrata TT',
                    size = 10,
                    flags = '',
                    colorTime = { r = 0.5, g = 0.5, b = 0.5 },
                    colorHighlight = { r = 1, g = 0.28, b = 0 },
                    color = { r = 0.7, g = 0.5, b = 0 },
                    shadowColor = { 0, 0, 0, 1 },
                    shadowOffset = { x = 1, y = -1 },
                }
            },
        }
    },
}

Namespace.Addon = Namespace.Libs.AceAddon:NewAddon(AddonName)

function Namespace.Addon:OnInitialize()
    Namespace.Database = Namespace.Libs.AceDB:New('BattlegroundCommanderDatabase', defaultConfig, true)
end
