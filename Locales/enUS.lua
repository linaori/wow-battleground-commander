local AddonName, Namespace = ...
local L = Namespace.Libs.AceLocale:NewLocale(AddonName, 'enUS', true, not Namespace.Debug.enabled)

L['Group Info'] = true
L['Ready Check'] = true
L['Group Information'] = true
L['yes'] = true
L['no'] = true
L['Merc'] = true
L['Deserter'] = true
L['Ready'] = true
L['Not Ready'] = true
L['Addon Information'] = true
L['Version'] = true
L['Addon version: %s'] = true
L['Battleground Tools'] = true
L['Instructions Frame'] = true
L['Enable'] = true
L['Enables or disables the instructions frame that captures raid warnings'] = true
L['Font'] = true
L['Font used for the text inside the frame'] = true
L['Highlight Color'] = true
L['Color of the most recent text message'] = true
L['Text Color'] = true
L['Color of the remaining text messages'] = true
L['Time Color'] = true
L['Color of the time text'] = true
L['Font Flags'] = true
L['Adjust the font flags'] = true
L['Allow Repositioning'] = true
L['Enable to reposition or resize the frame'] = true
L['Font Size'] = true
L['Adjust the font size for the messages and time'] = true
L['Enabled in Zones'] = true
L['Select Zones'] = true
L['Select the zones where the frame should appear when enabled'] = true
L['Frame Text Configuration'] = true
L['Maximum instructions'] = true
L['The maximum amount of instructions to show'] = true
L['Frame Layout'] = true
L['Background Texture'] = true
L['Changes the background texture of the frame'] = true
L['Border Texture'] = true
L['Changes the border texture of the frame'] = true
L['Border Size'] = true
L['Changes the border size'] = true
L['Background Inset'] = true
L['Reduces the size of the background texture'] = true
L['Background Color'] = true
L['Border Color'] = true
L['Battleground Commander loaded'] = true
L['You can access the configuration via /bgc or through the interface options'] = true
L['Latest message on top '] = true
L['Enable to show the latest message on top, otherwise the latest message will be on the bottom'] = true
L['Queue paused for %s'] = true
L['Queue resumed for %s'] = true
L['Request lead inside battleground'] = true
L['Requests lead upon entering or enabling this option'] = true
L['Lead Requested'] = true
L['%s is requesting lead'] = true
L['%d people requested lead'] = true
L['Battleground Leader'] = true
L['Automatically giving lead to %s'] = true
L['Enable Custom Message'] = true
L['Enable sending a custom message if the leader not using Battleground Commander'] = true
L['Custom Message'] = true
L['{leader} will be replaced by the leader name in this message and is optional'] = true
L['Send Whisper (/w)'] = true
L['Send Say (/s)'] = true
L['Send Raid (/r, /i)'] = true
L['Queue Settings'] = true
L['Automatically accept role when queuing'] = true
L['Accepts the pre-selected role when your group applies for a battleground'] = true
L['Clear frame when exiting the battleground'] = true
L['Removes the instructions from the last battleground'] = true
L['Entered %s'] = true
L['Ready Check on Queue Cancel'] = true
L['Do a ready check to see who entered while the group leader cancelled entering'] = true
L['Open Battleground Commander Settings'] = true
L['Accepted automated ready check with message: "%s"'] = true
L['Sending automated ready check with message: "%s"'] = true
L['Cancel'] = true
L['Enter'] = true
L['Entry Management'] = true
L['These features are only enabled when you are the group or raid leader'] = true
L['Send "Enter" message in chat'] = true
L['Send "Cancel" message in chat'] = true
L['Automatically send a message to the raid or party chat when you cancel the entry'] = true
L['Automatically send a message to the raid or party chat when you confirm the entry'] = true
L['Queue Pause Detection'] = true
L['Auto Queue'] = true
L['Declined'] = true
L['Entered'] = true
L['Status'] = true
L['Cancel (%s)'] = true
L['Waiting (%s)'] = true
L['Disable entry button on cancel'] = true
L['Disables the entry button when the group leader cancels entry, hold shift to re-enable the button'] = true
L['Disable entry button by default'] = true
L['The entry button requires shift to be held first, or the group leader to enter.'] = true
L['Show or hide the Battleground Commander group information window'] = true
L['Queue Pop'] = true
L['Accepted'] = true
L['Role Check'] = true
L['OK'] = true
L['Offline'] = true
L['Open World'] = true
L['Alterac Valley'] = true
L['Alterac Valley (Korrak\'s Revenge)'] = true
L['Ashran'] = true
L['Battle for Wintergrasp'] = true
L['Isle of Conquest'] = true
L['Arathi Basin'] = true
L['Arathi Basin (Classic)'] = true
L['Arathi Basin (Winter)'] = true
L['Arathi Basin Comp Stomp'] = true
L['Deepwind Gorge'] = true
L['Eye of the Storm'] = true
L['Eye of the Storm (Rated)'] = true
L['Isle of Conquest'] = true
L['Seething Shore'] = true
L['Silvershard Mines'] = true
L['Strand of the Ancients'] = true
L['Temple of Kotmogu'] = true
L['The Battle for Gilneas'] = true
L['Twin Peaks'] = true
L['Warsong Gulch'] = true
L['Southshore vs. Tarren Mill'] = true
L['Queue Tools'] = true
L['Queue Inspection'] = true
L['Notify When Paused'] = true
L['Send a chat message whenever the queue is paused'] = true
L['Notify When Resumed'] = true
L['Send a chat message whenever the queue is resumed after being paused'] = true
L['Ready Check on Pause'] = true
L['Do a ready check whenever a queue pause is detected'] = true
L['Only as Leader or Assist'] = true
L['Enable the queue pause detection features only when you are party leader or assist'] = true
L['Setup Automation'] = true
L['My raid mark'] = true
L['Automatically assign the configured raid mark when you become leader.'] = true
L['Do not mark me'] = true
L['Leader promotion sound'] = true
L['Play a sound when you are promoted or demoted from being raid leader.'] = true
L['Leader Setup'] = true
L['Requesting Lead'] = true
L['%s will now automatically be promoted to assistant in battlegrounds'] = true
L['Demote players without configured assistant'] = true
L['When someone gets assistant, or was assistant when you get lead, it will automatically demote these players to member if not explicitly configured'] = true
L['When someone in this list is in your battleground while you are leader, they will get promoted to assistant'] = true
L['Available icons'] = true
L['Available icons to automatically mark people with'] = true
L['Include assist list in marking'] = true
L['Also mark players with raid icons when listed in the list of automatic assists'] = true
L['%s will now automatically be marked in battlegrounds'] = true
L['Marked %s with %s'] = true
L['Do not mark'] = true
L['Any available icon'] = true
L['Preferred icon'] = true
L['Try to mark with this icon. If this icon is not available, a random icon will be used'] = true
L['Mark this player'] = true
L['When this user requests lead'] = true
L['No automation'] = true
L['Give lead, unless I want it'] = true
L['Always give lead'] = true
L['Reject lead'] = true
L['Promote to assistant'] = true
L['Automatically promote this player to assistant'] = true
L['Determines which action to perform when this player requests battleground lead'] = true
L['Are you sure you want to delete the config for %s?'] = true
L['Delete'] = true
L['Player Management'] = true
L['Add player from group'] = true
L['Add recently played with'] = true
L['Add player by name'] = true
L['Hold shift to omit the confirm message'] = true
L['BGC: Configure'] = true
L['Player nickname'] = true
L['Show this nickname in the group info. Leave empty to show name-realm instead.'] = true
L['Name format'] = true
L['This changes what the name is shown like in the list'] = true
L['Hide realm when same as yours'] = true
L['Always show the realm'] = true
L['Never show the realm'] = true
L['No Addon'] = true
L['BGC: %d/%d'] = true
L['Want Lead'] = true
L['Leaders'] = true
L['Battleground Options'] = true
L['HH:MM:SS AM (12-hour)'] = true
L['HH:MM:SS (24-hour)'] = true
L['Show server time on Entry Button'] = true
L['When the Entry Window appears, show the server time on the entry button.'] = true
L['Never'] = true
L['Solo, Group Lead'] = true
L['Group Lead'] = true
L['Entry Button time format'] = true
L['Customize the time format on the Entry Button.'] = true
L['Entry Window'] = true
L['Got feedback, suggestions or questions, or you just want to chat? Join us on Discord!'] = true
L['Modifier button to re-enable the entry button'] = true
L['This button will make sure that you can enable the entry button on a queue pop whenever you want'] = true
L['Manually add Player-RealmName'] = true
L['Imported player config, new: %d updated: %s'] = true
L['Players'] = true
L['Export'] = true
L['Import'] = true
L['Copy'] = true
L['Paste'] = true
L['This text can be copied and pasted into the text field under "Import"'] = true
L['Here you can paste the text from "import". Press "Accept" to import the settings'] = true
