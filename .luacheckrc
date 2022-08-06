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
    'CombatLogGetCurrentEventInfo',
    'CreateFrame',
    'DoReadyCheck',
    'GetBattlefieldStatus',
    'GetInstanceInfo',
    'GetInstanceInfo',
    'GetLFGRoleUpdate',
    'GetLocale',
    'GetMaxBattlefieldID',
    'GetNumGroupMembers',
    'GetPlayerAuraBySpellID',
    'GetRealmName',
    'GetRealmName',
    'GetTime',
    'GetUnitName',
    'InterfaceOptionsFrame_OpenToCategory',
    'IsInGroup',
    'IsInRaid',
    'IsShiftKeyDown',
    'PlaySound',
    'PromoteToLeader',
    'SendChatMessage',
    'UnitClass',
    'UnitDebuff',
    'UnitExists',
    'UnitFullName',
    'UnitGUID',
    'UnitIsConnected',
    'UnitIsGroupAssistant',
    'UnitIsGroupLeader',
    'UnitIsPlayer',
    'UnitNameUnmodified',

    'DEBUFF_MAX_DISPLAY',
    'LE_PARTY_CATEGORY_HOME',
    'LE_PARTY_CATEGORY_INSTANCE',
    'RAID_CLASS_COLORS',
    'SOUNDKIT',
    'UNKNOWNOBJECT',

    'math',
    'pairs',
    'print',
    'select',
    'string',
    'table',
    'tostring',
    'type',
}
