local LibStub, AddonName, Namespace = LibStub, ...

Namespace.Libs = {
    AceLocale = LibStub('AceLocale-3.0'),
    AceAddon = LibStub('AceAddon-3.0'),
    ScrollingTable = LibStub('ScrollingTable'),
    --AceConfig = LibStub('AceConfig-3.0'),
    AceSerializer = LibStub('AceSerializer-3.0'),
    LibCompress = LibStub('LibCompress'),
}

Namespace.Addon = Namespace.Libs.AceAddon:NewAddon(AddonName)
