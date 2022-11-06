local _, Namespace = ...

Namespace.Changelog = {
    {
        version = '10.0.0-5',
        features = {
            'Added an option to mark yourself with an icon when you become lead',
            'Added an option to play a sound when you are promoted to, or demoted from lead',
            'Added a ready check sound and taskbar flash when the popup to give lead is shown',
            'Added a changelog inside the addon',
            'Added an option to automatically promote members to assistant. Target a player and run /bgca in chat to add them to the list. You can also manually add players in the "Battleground Tools -> Leader Setup -> Automatic Assistant" section',
        },
        improvements = {
            'Internal rework to detect when someone in the raid becomes member, assistant, or lead, to improve accuracy for automation tools',
            'Some minor performance improvements when the addon tries to find the current raid leader, or a specific unit (like player, raid5, party2 etc)',
            'Reworked the options ui to utilize the space more efficiently',
            'Names in the accept/reject lead input, and the automatic assistant input, are now sorted'
        },
        bugs = {
            'Fixed an issue where requesting lead would miss when lead was given without the raid roster changing',
        },
    },
    {
        version = '10.0.0-4',
        improvements = {
            'Updated Russian translations (by k33th)',
            'Nicer messages when text is being printed to the chat',
        },
    },
    {
        version = '10.0.0-3',
        features = {
            'Added Russian translations (by k33th)',
        },
        improvements = {
            'Tweaked how often the leader would ask for lead in certain scenarios'
        },
        bugs = {
            'Fixed an issue where the "give lead" window did not automatically close after giving lead',
        },
    },
    {
        version = '10.0.0-2',
        improvements = {
            'Removed some code that was bridging API changes between 9.2.7 and 10.0.0'
        },
        bugs = {
            'Fixed an issue where the the "enter" button would not always properly update on cancel or enter messages',
        },
    },
    {
        version = '10.0.0-1',
        improvements = {
            'Changed versioning to <wow version>-<incremental bgc number> to better show which WoW client it works with',
        },
        bugs = {
            'Fixed an incompatibility with the latest 10.0.0 version',
        },
    },
}