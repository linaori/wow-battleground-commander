local _, Namespace = ...

Namespace.Changelog = {
    {
        version = '11.0.0-49',
        improvements = {
            'The War Within update for 11.0.0',
        },
    },
    {
        version = '10.2.7-48',
        bugs = {
            'Fixed a possible Lua error when giving lead',
        },
        improvements = {
            'Updated TOC for 10.2.7',
        },
    },
    {
        version = '10.2.6-47',
        improvements = {
            'Updated TOC for 10.2.6',
        },
        bugs = {
            'Fixed a possible Lua error trying to figure out the deserter debuff',
        },
    },
    {
        version = '10.2.5-46',
        improvements = {
            'Remove spaces from the input when manually adding a character, this makes it harder to make accidental mistakes when the realm has a space, or when the input contains a space around the dash sign',
        },
    },
    {
        version = '10.2.5-45',
        features = {
            'Added the ability export and import player specific configurations',
        },
        improvements = {
            'Player management has moved away from Battleground Tools as tab, and is now accessible on the same option level in the left menu'
        },
        bugs = {
            'Changing profiles will now correctly reload the player list in Player Management'
        },
    },
    {
        version = '10.2.5-44',
        features = {
            'Added the ability to manually add players to player management',
        },
    },
    {
        version = '10.2.5-43',
        improvements = {
            'Updated TOC for 10.2.5',
        },
    },
    {
        version = '10.2.0-42',
        improvements = {
            'Updated TOC for 10.2.0',
        },
    },
    {
        version = '10.1.7-41',
        improvements = {
            'Updated TOC for 10.1.7',
        },
    },
    {
        version = '10.1.5-40',
        bugs = {
            'Fixed giving/requesting lead, assist, and marks not working inside battlegrounds since 10.1.5',
        },
    },
    {
        version = '10.1.5-39',
        features = {
            'You can now configure which modifier button (Shift, Ctrl, or Alt) re-enables the entry button',
        },
        improvements = {
            'Updated TOC for 10.1.5',
            'Group information window is now refreshed when players without Battleground Commander enter',
        },
    },
    {
        version = '10.1.0-38',
        improvements = {
            'When a party member without addon enters an instance, it will now show "entered" as status message instead of "waiting"',
            'If that user is the party leader, the "enter" button for the group will return to normal',
            'When the queue timer expires it will now reset the states from "waiting" to "ok"',
        },
    },
    {
        version = '10.1.0-37',
        bugs = {
            'Attempt to increase stability of giving lead to someone else through either the dialog or automatically',
        },
        improvements = {
            'Requesting lead now uses the generic data sync instead of its own message',
            'Manually sending a request lead message is now only active when the leader is not using Battleground Commander',
            '"Unknown" player name should be seen less often in the player list when realm names are visible',
        },
    },
    {
        version = '10.1.0-36',
        features = {
            'Added a time display on the entry button in "Battleground Commander -> Queue Tools -> Queue Settings". You can configure 12h vs 24h format, and when you want to show it: Never, Solo, or Group Lead. This will help coordination by determining when a group leader gets an entry window',
            'Added Battleground Commander to the addon compartment (next to the minimap) to quickly access the settings',
            'Created a Discord server and added the invite link',
        },
        improvements = {
            'Added new icon for the addon list',
        },
    },
    {
        version = '10.1.0-35',
        improvements = {
            'Updated TOC for 10.1',
        },
    },
    --{
    --    version = '10.0.7-34',
    --    bugs = {
    --        'When you request lead it no longer shows you as an additional +1 in the "Leaders" button',
    --    },
    --},
    --{
    --    version = '10.0.7-33',
    --    features = {
    --        'Added a new option to give someone lead even if you are currently requesting lead. You can configure this option in the Player Management under "when this user requests lead"',
    --    },
    --    improvements = {
    --        'Added a counter to the "leaders" button in the group info window, to show how many people are requesting lead',
    --        'Automatically close the Give Lead window in certain scenarios',
    --    },
    --},
    --{
    --    version = '10.0.7-32',
    --    bugs = {
    --        'Hopefully fixed a bug where sometimes mercenary mode was not refreshed properly',
    --    },
    --    improvements = {
    --        'Combined the "request lead" and "auto accept role" checkboxes in a new "Battleground Options" dropdown',
    --    },
    --},
    --{
    --    version = '10.0.7-31',
    --    improvements = {
    --        'Tooltip hover in group information now shows if the player wants lead',
    --        'Addon version information is now integrated into the frame title',
    --        'The settings button moved up, next to the close button',
    --        'The window where you can give lead to others will no longer close by itself as you can now manually open it',
    --        'The window to give lead is now closed when you press ESC',
    --        'Reworked the internal behavior of tracking who wants lead, please report any bugs you encounter',
    --    },
    --    features = {
    --        'Added a button to the Group Information window to open the window that shows who wants lead',
    --    },
    --},
    --{
    --    version = '10.0.7-30',
    --    improvements = {
    --        'Improved handling of giving lead automation',
    --        'Give Lead window now respects the name display configuration and colors by class',
    --    },
    --    bugs = {
    --        'No longer show the Give Lead window when the people in the list are not in the match at that moment',
    --    },
    --},
    --{
    --    version = '10.0.7-29',
    --    improvements = {
    --        'Updated TOC for 10.0.7',
    --    },
    --},
    --{
    --    version = '10.0.5-28',
    --    improvements = {
    --        'Added text to show total BGC addon users in group information',
    --    },
    --},
    --{
    --    version = '10.0.5-27',
    --    improvements = {
    --        'Changed text color to be less "bad" when you have a different mercenary status than your leader if the leader does not have the addon',
    --    },
    --},
    --{
    --    version = '10.0.5-26',
    --    bugs = {
    --        'Fixed trying to give lead to someone when they ask, while not having lead yourself',
    --    },
    --},
    --{
    --    version = '10.0.5-25',
    --    bugs = {
    --        'Fixed some functions not working properly for people from the same realm as you',
    --        'Reduced the chance of "Unknown" being shown as player name in the group information window',
    --    },
    --    improvements = {
    --        'Improved the group information tooltip, which will now also try to show if the addon is out of date or not by coloring the version',
    --    },
    --},
    --{
    --    version = '10.0.5-24',
    --    features = {
    --        'Added the ability to give a custom nick name to players',
    --        'Added a setting to configure how names are shown in the group info: Hide realm when same as yours, Always show the realm, and Never show the realm',
    --        'The "settings" button in the group information window now opens just the Battleground Commander config instead of all settings',
    --    },
    --},
    --{
    --    version = '10.0.5-23',
    --    bugs = {
    --        'Fixed the "accepted automated ready check with message" print showing the incorrect data',
    --    },
    --},
    --{
    --    version = '10.0.5-22',
    --    bugs = {
    --        'Fixed a lua error triggering randomly when class color was not known yet',
    --    },
    --},
    --{
    --    version = '10.0.5-21',
    --    bugs = {
    --        'Fixed an issue with the addon not sending and receiving data cross-realm due to "sender" losing its realm information. For now all names in group information will include the realm.',
    --    },
    --},
    --{
    --    version = '10.0.5-20',
    --    improvements = {
    --        'Added some German translations (OmarJAH)',
    --        'Tweaked some button and table widths to accommodate other languages',
    --    },
    --},
    --{
    --    version = '10.0.5-19',
    --    bugs = {
    --        'Fixed an issue with the faction color sometimes not being set properly',
    --        'Fixed an issue with the group information frame scrollbar ending up outside the window',
    --    },
    --},
    --{
    --    version = '10.0.5-18',
    --    improvements = {
    --        'Updated TOC for 10.0.5',
    --    },
    --},
    --{
    --    version = '10.0.2-17',
    --    improvements = {
    --        'Mercenary color in Group Information will now show a red color for players who do not have the same mercenary status as the leader',
    --        'The faction of a player is now show in the Group Information table',
    --    },
    --},
    --{
    --    version = '10.0.2-16',
    --    improvements = {
    --        'Added mercenary buff support for alliance',
    --    },
    --},
    --{
    --    version = '10.0.2-15',
    --    improvements = {
    --        'Added basic mercenary detection for players without Battleground Commander. It will not show the remaining time as it is only known whether or not mercenary mode is active',
    --    },
    --    bugs = {
    --        'Features relying on "active battleground" detection should no longer trigger after the match finished while not exiting yet (during score screen)',
    --        'Fixed a bug where the "status" column was not set to "OK" for group members after entering a battleground',
    --    },
    --},
    --{
    --    version = '10.0.2-14',
    --    features = {
    --        'Added a preferred icon for player configuration. When configured and you get lead, the player will be marked with the selected icon, or get another available icon if available. Players with a preferred icon will take precedence over players with "any available icon"',
    --    },
    --    improvements = {
    --        'Removed "add player by name" for now, as it was limited to the combination of the other two ways of adding users'
    --    },
    --},
    --{
    --    version = '10.0.2-13',
    --    bugs = {
    --        'Fixed an issue where the new "BGC: Configure" option would show up in places it does not belong',
    --    },
    --},
    --{
    --    version = '10.0.2-12',
    --    features = {
    --        'Added shortcuts in the config to configure players options: "Add player from group", "Add recently played with", "Add player by name"',
    --    },
    --    improvements = {
    --        'Reworked the config for player management. Each player now has a dedicated config section under "Battleground Tools -> Player Management"',
    --        'Replaced /bgca and /bgcm by a right click context menu item: "BGC: Configure"'
    --    },
    --    bugs = {
    --        'Fixed a bug where the instruction frame did not properly update after reloading in a battleground',
    --    },
    --},
    --{
    --    version = '10.0.2-11',
    --    bugs = {
    --        'Fixed an issue where the instruction window sometimes would not go away',
    --    },
    --},
    --{
    --    version = '10.0.2-10',
    --    improvements = {
    --        'Players who are marked should no longer be randomly swapping marks',
    --        'Ensured internal logic works the same everywhere when it comes to detecting battleground status',
    --        'When "Requesting Lead -> Send Raid is enabled, it will now also use the instance chat',
    --        'Removed "Open World" as option from the instructions window',
    --        'Changing "Leader Setup" settings now also re-marks accordingly',
    --    },
    --    bugs = {
    --        'Fixed an error when opening the group info while not in a group',
    --    },
    --},
    --{
    --    version = '10.0.2-9',
    --    features = {
    --        'Added an option to automatically mark raid members. Target a player and run /bgcm in chat to add them to the list. You can also manually add players in the "Battleground Tools -> Leader Setup -> Decision Automation" section',
    --    },
    --},
    --{
    --    version = '10.0.2-8',
    --    improvements = {
    --        'Updated TOC for 10.0.2, pre-patch phase 2',
    --    },
    --},
    --{
    --    version = '10.0.0-7',
    --    bugs = {
    --        'Fixed the issue of demoting assists automatically back to member if not listed when manually promoted',
    --    },
    --},
    --{
    --    version = '10.0.0-6',
    --    improvements = {
    --        'Added a toggle to control automatic promotion and demotion behavior',
    --    },
    --},
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
