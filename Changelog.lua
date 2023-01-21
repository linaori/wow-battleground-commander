local _, Namespace = ...

Namespace.Changelog = {
    {
        version = '10.0.2-17',
        improvements = {
            'Mercenary color in Group Information will now show a red color for players who do not have the same mercenary status as the leader',
        },
    },
    {
        version = '10.0.2-16',
        improvements = {
            'Added mercenary buff support for alliance',
        },
    },
    {
        version = '10.0.2-15',
        improvements = {
            'Added basic mercenary detection for players without Battleground Commander. It will not show the remaining time as it is only known whether or not mercenary mode is active',
        },
        bugs = {
            'Features relying on "active battleground" detection should no longer trigger after the match finished while not exiting yet (during score screen)',
            'Fixed a bug where the "status" column was not set to "OK" for group members after entering a battleground',
        },
    },
    {
        version = '10.0.2-14',
        features = {
            'Added a preferred icon for player configuration. When configured and you get lead, the player will be marked with the selected icon, or get another available icon if available. Players with a preferred icon will take precedence over players with "any available icon"',
        },
        improvements = {
            'Removed "add player by name" for now, as it was limited to the combination of the other two ways of adding users'
        },
    },
    {
        version = '10.0.2-13',
        bugs = {
            'Fixed an issue where the new "BGC: Configure" option would show up in places it does not belong',
        },
    },
    {
        version = '10.0.2-12',
        features = {
            'Added shortcuts in the config to configure players options: "Add player from group", "Add recently played with", "Add player by name"',
        },
        improvements = {
            'Reworked the config for player management. Each player now has a dedicated config section under "Battleground Tools -> Player Management"',
            'Replaced /bgca and /bgcm by a right click context menu item: "BGC: Configure"'
        },
        bugs = {
            'Fixed a bug where the instruction frame did not properly update after reloading in a battleground',
        },
    },
    {
        version = '10.0.2-11',
        bugs = {
            'Fixed an issue where the instruction window sometimes would not go away',
        },
    },
    {
        version = '10.0.2-10',
        improvements = {
            'Players who are marked should no longer be randomly swapping marks',
            'Ensured internal logic works the same everywhere when it comes to detecting battleground status',
            'When "Requesting Lead -> Send Raid is enabled, it will now also use the instance chat',
            'Removed "Open World" as option from the instructions window',
            'Changing "Leader Setup" settings now also re-marks accordingly',
        },
        bugs = {
            'Fixed an error when opening the group info while not in a group',
        },
    },
    {
        version = '10.0.2-9',
        features = {
            'Added an option to automatically mark raid members. Target a player and run /bgcm in chat to add them to the list. You can also manually add players in the "Battleground Tools -> Leader Setup -> Decision Automation" section',
        },
    },
    {
        version = '10.0.2-8',
        improvements = {
            'Updated TOC for 10.0.2, pre-patch phase 2',
        },
    },
    {
        version = '10.0.0-7',
        bugs = {
            'Fixed the issue of demoting assists automatically back to member if not listed when manually promoted',
        },
    },
    {
        version = '10.0.0-6',
        improvements = {
            'Added a toggle to control automatic promotion and demotion behavior',
        },
    },
    --{
    --    version = '10.0.0-5',
    --    features = {
    --        'Added an option to mark yourself with an icon when you become lead',
    --        'Added an option to play a sound when you are promoted to, or demoted from lead',
    --        'Added a ready check sound and taskbar flash when the popup to give lead is shown',
    --        'Added a changelog inside the addon',
    --        'Added an option to automatically promote members to assistant. Target a player and run /bgca in chat to add them to the list. You can also manually add players in the "Battleground Tools -> Leader Setup -> Decision Automation" section',
    --    },
    --    improvements = {
    --        'Internal rework to detect when someone in the raid becomes member, assistant, or lead, to improve accuracy for automation tools',
    --        'Some minor performance improvements when the addon tries to find the current raid leader, or a specific unit (like player, raid5, party2 etc)',
    --        'Reworked the options ui to utilize the space more efficiently',
    --        'Names in the accept/reject lead input, and the automatic assistant input, are now sorted'
    --    },
    --    bugs = {
    --        'Fixed an issue where requesting lead would miss when lead was given without the raid roster changing',
    --    },
    --},
    --{
    --    version = '10.0.0-4',
    --    improvements = {
    --        'Updated Russian translations (by k33th)',
    --        'Nicer messages when text is being printed to the chat',
    --    },
    --},
    --{
    --    version = '10.0.0-3',
    --    features = {
    --        'Added Russian translations (by k33th)',
    --    },
    --    improvements = {
    --        'Tweaked how often the leader would ask for lead in certain scenarios'
    --    },
    --    bugs = {
    --        'Fixed an issue where the "give lead" window did not automatically close after giving lead',
    --    },
    --},
    --{
    --    version = '10.0.0-2',
    --    improvements = {
    --        'Removed some code that was bridging API changes between 9.2.7 and 10.0.0'
    --    },
    --    bugs = {
    --        'Fixed an issue where the the "enter" button would not always properly update on cancel or enter messages',
    --    },
    --},
    --{
    --    version = '10.0.0-1',
    --    improvements = {
    --        'Changed versioning to <wow version>-<incremental bgc number> to better show which WoW client it works with',
    --    },
    --    bugs = {
    --        'Fixed an incompatibility with the latest 10.0.0 version',
    --    },
    --},
}