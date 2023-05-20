## Battleground Commander
Provides quality of life features for Battlegrounds.

Discord: https://discord.gg/7tKEKMCkGq

### Queue Tools
This adds a bunch of tools that will help group leaders get the info they need to queue or cancel whenever needed.

#### Automatic Role Selection
You can enable automatic role selection for battlegrounds to reduce a manual step that delays entry.

#### Queue Entry and Decline Tools
When a queue entry window shows, for non-group leaders the "Enter" button is disabled by default, and additionally
this button will be disabled if the group leader cancels. This behavior can be changed in the settings, and holding the
shift button will re-enable the button. When the group leader enters the battleground and has Battleground Commander, it
will also enable the Entry Button for non-group leaders.

The group leader has the ability to automatically do a ready check when a queue entry is cancelled and if not
all group members declined within a certain time limit.

To help coordinate which group leaders gets an entry, and when this occurred, you can configure to see the server time
inside the queue button. This format can be configured as either 12 or 24 hours, and can be configured to never show,
show solo, and as group leader.

#### Group Information
This window can be accessed through the PvP window by checking the "Group Info" box. This list shows all players in your
group and shows various bits of info used to queue. You can also do a ready check from here, and open the settings.
You'll be able to see the following information in the columns:
 - if that player has "Automatic Role Selection" enabled (BGC required by that player)
 - if that player has the Mercenary Contract buff, and how long remaining (BGC required by that player)
 - status column which shows various bits of info:
   - ready check status
   - role selection status
   - deserter debuff remaining
   - if the queue entry window showed up
   - if that player entered (BGC required by that player)
   - if that player declined entry (BGC required by that player)
 - Player faction

Additionally you can also see who uses which addon by hovering over the window title, or the players themselves, and you
can access the list of people who request lead. In the settings (QueueTools -> Group Information) you can configure
player names in Battleground Commander to be shown in several formats:
 - Never show the realm
 - Always Show the realm
 - Hide the realm when it's the same realm as you are from (default Blizzard behavior)

#### Queue Pause Detection
Free choice of automatically notifying the group when the queue is paused, resumed, and doing a ready check to verify
who is and isn't ready. These options can also be limited to being a group leader or assist. Additionally, if someone
else with this addon does an automated ready check, it will try to automatically accept it.

### Battleground Tools
Extra conveniences for Battlegrounds.

#### Instructions Frame
This frame shows Raid Warnings from your raid leader with a time to indicate how long ago this message was sent. You can
configure this frame to load only in specific zones, and it will filter out duplicate messages.

#### Requesting Lead
Users with this addon can request lead from other users with this addon. The leader will receive the option to give lead
or reject the request, and remember the choice in the future. When the player with lead also wants lead, they will not
get the popup, though they can add an exclusion per player to automatically give lead away.

#### Leader Setup
Allows the leader to automatically place a raid marker on themselves when they get lead, and lets the leader
automatically assign assist to raid members based on their name.

#### Player Management
You can automate certain levels of player management:
 - Give them a nickname that appears in the Battleground Commander UI
 - Whether or not you want to automatically promote the player to assistant
 - Automatically try to mark the player with either a random icon, or a preferred icon
 - What to do when the user asks for lead through Battleground Commander:
   - Not automate it at all
   - Give them lead unless you want lead
   - Always give them lead, even if you want lead, which is useful if you off-lead and still want to automatically give 
     it to a community leader
   - Automatically reject their request

## Official Download Locations
You can find this addon on: [CurseForge.com](https://www.curseforge.com/wow/addons/battleground-commander), 
[Wago.io](https://addons.wago.io/addons/battleground-commander), and [WowUp.io](https://wowup.io/addons/1792745). 
You can find the releases on [GitHub](https://github.com/linaori/wow-battleground-commander/releases).
