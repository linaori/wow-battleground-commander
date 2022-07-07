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
    '_G', 
    'LibStub',
    'Namespace', 

    'BattlegroundCommanderDatabase',

    'DoReadyCheck',
    'UnitIsGroupLeader',
    'UnitIsGroupAssistant',
    'GetInstanceInfo',
    'CreateFrame',
    'PlaySound',
    'GetPlayerAuraBySpellID',
    'CombatLogGetCurrentEventInfo',
    'UnitClass',
    'UnitFullName',
    'GetUnitName',
    'GetRealmName',
    'GetNumGroupMembers',
    'GetBattlefieldStatus',
    'GetMaxBattlefieldID',
    'UnitDebuff',
    'UnitIsPlayer',
    'UnitExists',
    'UnitGUID',
    'IsInGroup',
    'IsInRaid',
    'GetTime',
    'GetInstanceInfo',
    'GetRealmName',
    'C_ChatInfo',
    'SendChatMessage',
    'InterfaceOptionsFrame_OpenToCategory',
    'PromoteToLeader',

    'SOUNDKIT',
    'RAID_CLASS_COLORS',
    'DEBUFF_MAX_DISPLAY',
    'UNKNOWNOBJECT',
    'LE_PARTY_CATEGORY_HOME',
    'LE_PARTY_CATEGORY_INSTANCE',

    'math',
    'tostring',
    'string',
    'pairs',
    'type',
    'print',
    'table',
    'select',
}
