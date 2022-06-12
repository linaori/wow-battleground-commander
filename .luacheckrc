std='lua51'
exclude_files = {
    '**/Libs/**/*.lua',
    '.luacheckrc',
}

ignore = {
    '212/self',
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
    'GetRealmName',
    'GetNumGroupMembers',
    'UnitDebuff',
    'UnitIsPlayer',
    'UnitExists',
    'UnitGUID',
    'IsInGroup',
    'IsInRaid',
    'GetTime',

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
    'concat',
    'select',
}
