std='lua51'
exclude_files = {
    '**/Libs/**/*.lua',
    '.luacheckrc',
}

ignore = {
    '212/self',
    '631',
}

globals = {
    'LibStub',
    'Namespace',
    '_G',

    'BattlegroundCommanderDatabase',

    'C_ChatInfo',
    'C_ClassColor',
    'C_PvP',
    'C_UnitAuras',
    'CombatLogGetCurrentEventInfo',
    'CreateAtlasMarkup',
    'CreateColor',
    'CreateFrame',
    'DemoteAssistant',
    'DoReadyCheck',
    'FlashClientIcon',
    'GetBattlefieldStatus',
    'GetInstanceInfo',
    'GetInstanceInfo',
    'GetLFGRoleUpdate',
    'GetLocale',
    'GetMaxBattlefieldID',
    'GetNormalizedRealmName',
    'GetNumGroupMembers',
    'GetPlayerAuraBySpellID',
    'GetTime',
    'GetUnitName',
    'InCombatLockdown',
    'IsInGroup',
    'IsInRaid',
    'IsShiftKeyDown',
    'PlaySound',
    'PromoteToAssistant',
    'PromoteToLeader',
    'SendChatMessage',
    'SetRaidTarget',
    'Settings',
    'strsplit',
    'tinsert',
    'UISpecialFrames',
    'UnitAffectingCombat',
    'UnitClass',
    'UnitDebuff',
    'UnitExists',
    'UnitFactionGroup',
    'UnitFullName',
    'UnitGUID',
    'UnitIsConnected',
    'UnitIsGroupAssistant',
    'UnitIsGroupLeader',
    'UnitIsMercenary',
    'UnitIsPlayer',
    'UnitNameUnmodified',

    'DEBUFF_MAX_DISPLAY',
    'LE_PARTY_CATEGORY_HOME',
    'LE_PARTY_CATEGORY_INSTANCE',
    'SOUNDKIT',
    'UNKNOWNOBJECT',

    'date',
    'math',
    'pairs',
    'print',
    'select',
    'string',
    'table',
    'tonumber',
    'tostring',
    'type',
}
