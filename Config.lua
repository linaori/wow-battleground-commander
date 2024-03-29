local AddonName, Namespace = ...

local GetCurrentRegion = GetCurrentRegion
local IsShiftKeyDown = IsShiftKeyDown
local pairs = pairs
local concat = table.concat
local format = string.format

local EntryButtonShowPopTime = Namespace.Utils.EntryButtonShowPopTime
local EntryButtonTimeFormat = Namespace.Utils.EntryButtonTimeFormat
local RaidIconIndex = Namespace.Utils.RaidIconIndex
local RaidIconChatTexture = Namespace.Utils.RaidIconChatTexture
local ModifierButton = Namespace.Utils.ModifierButton

Namespace.Config = {}

local Memory = {
    ConfigurationSetup = nil,
    DefaultConfiguration = {
        profile = {
            QueueTools = {
                showGroupQueueFrame = false,
                GroupInfo = {
                    nameFormat = 1,
                },
                Automation = {
                    acceptRoleSelection = true,
                    disableEntryButtonOnQueuePop = true,
                    disableEntryButtonOnCancel = true,
                    enableEntryButtonModifier = ModifierButton.Shift,
                    showTimeOnEntryButton = EntryButtonShowPopTime.Always,
                    entryButtonTimeFormat = GetCurrentRegion() == 1 and EntryButtonTimeFormat.Half or EntryButtonTimeFormat.Full,
                },
                InspectQueue = {
                    onlyAsLeader = true,
                    sendPausedMessage = true,
                    sendResumedMessage = true,
                    doReadyCheckOnQueuePause = true,
                    doReadyCheckOnQueueCancelAfterConfirm = true,
                    sendMessageOnQueueCancelAfterConfirm = true,
                    sendMessageOnBattlegroundEntry = true,
                },
            },
            BattlegroundTools = {
                firstTime = true,
                playerManagementIndex = 0,
                PlayerManagement = {
                    -- ['player-realm'] = {
                    --     playerName = 'name-realm',
                    --     playerNickname = 'Custom nickname',
                    --     groupLabel = 'class color name',
                    --     giveLeadBehavior = GiveLeadBehavior,
                    --     markBehavior = MarkBehavior,
                    --     promoteToAssistant = boolean,
                    --     preferredIcon = iconIndex,
                    --     sortOrderIndex = number,
                    -- }
                },
                WantBattlegroundLead = {
                    wantLead = false,
                    enableManualRequest = false,
                    manualRequestMessage = '{rt4} {leader} {rt4} can you give me lead please?',
                    sendWhisper = true,
                    sendSay = true,
                    sendRaid = true,
                },
                LeaderTools = {
                    leaderIcon = 0,
                    leaderSound = 1,
                    availableIcons = {
                        [RaidIconIndex.YellowStar] = false,
                        [RaidIconIndex.OrangeCircle] = false,
                        [RaidIconIndex.PurpleDiamond] = false,
                        [RaidIconIndex.GreenTriangle] = false,
                        [RaidIconIndex.SilverMoon] = false,
                        [RaidIconIndex.BlueSquare] = false,
                        [RaidIconIndex.RedCross] = false,
                        [RaidIconIndex.WhiteSkull] = false,
                    },
                    demoteUnlisted = false,
                },
                InstructionFrame = {
                    show = true,
                    move = true,
                    size = { width = 200, height = 100 },
                    position = { anchor = 'CENTER', x = 0, y = 0 },
                    zones = {
                        [30]   = true,
                        [2197] = true,
                        [1191] = true,
                        [2118] = true,
                        [2107] = true,
                        [529]  = true,
                        [1681] = true,
                        [2177] = true,
                        [1105] = true,
                        [566]  = true,
                        [968]  = true,
                        [628]  = true,
                        [1803] = true,
                        [727]  = true,
                        [607]  = true,
                        [998]  = true,
                        [761]  = true,
                        [726]  = true,
                        [489]  = true,
                        [1280] = true,
                    },
                    settings = {
                        maxInstructions = 5,
                        backgroundTexture = 'Blizzard Dialog Background Dark',
                        backgroundColor = { r = 1, g = 1, b = 1, a = 0.8 },
                        borderTexture = 'Blizzard Dialog',
                        borderColor = { r = 1, g = 1, b = 1, a = 0.5 },
                        borderSize = 12,
                        backgroundInset = 3,
                        clearFrameOnExitBattleground = true,
                    },
                    font = {
                        family = Namespace.Libs.LibSharedMedia:GetDefault('font'),
                        size = 12,
                        flags = '',
                        colorTime = { r = 0.5, g = 0.5, b = 0.5 },
                        colorHighlight = { r = 1, g = 0.28, b = 0 },
                        color = { r = 0.7, g = 0.5, b = 0 },
                        shadowColor = { r = 0, g = 0, b = 0, a = 1 },
                        shadowOffset = { x = 1, y = -1 },
                        topToBottom = true,
                    },
                },
            }
        },
    },
}

function Namespace.Config.GetDefaultConfiguration()
    return Memory.DefaultConfiguration
end

function Namespace.Config.AddPlayerConfig(playerName)
    if not playerName or not playerName:find('-') then
        return
    end

    playerName = playerName:gsub(' ', '')
    local config = Namespace.BattlegroundTools:GetPlayerConfig(playerName)
    if config then
        return Namespace.Addon:OpenPlayerConfig(playerName)
    end

    local playerData = Namespace.PlayerData.GetPlayerDataByName(playerName)
    config = Namespace.BattlegroundTools:CreatePlayerConfig(playerName)
    config.groupLabel = playerData and playerData.classColor:WrapTextInColorCode(playerName) or playerName

    Memory.ConfigurationSetup.args.PlayerManagement.args.Players.args[playerName] = Namespace.Config.CreatePlayerConfigNode(config)

    Namespace.Libs.AceConfigRegistry:NotifyChange(AddonName)

    Namespace.Addon:OpenPlayerConfig(playerName)
end

function Namespace.Config.GetConfigurationSetup()
    if Memory.ConfigurationSetup then return Memory.ConfigurationSetup end

    local L = Namespace.Libs.AceLocale:GetLocale(AddonName)
    local fontFlagList = { [''] = 'None', ['OUTLINE'] = 'Outline', ['OUTLINE, MONOCHROME'] = 'Outline Monochrome' }
    local LibSharedMediaFonts = Namespace.Libs.LibSharedMedia:HashTable('font')
    local LibSharedMediaBackgrounds = Namespace.Libs.LibSharedMedia:HashTable('background')
    local LibSharedMediaBorders = Namespace.Libs.LibSharedMedia:HashTable('border')

    local NameFormat = Namespace.QueueTools.NameFormat

    local function addPlayerConfig(_, playerName)
        Namespace.Config.AddPlayerConfig(playerName)
    end

    Memory.ConfigurationSetup = {
        name = Namespace.Meta.name,
        type = 'group',
        args = {
            Information = {
                name = L['Addon Information'],
                type = 'group',
                order = 1,
                args = {
                    version = {
                        name = format(L['Version'] .. ': %s\n ', Namespace.Meta.version),
                        type = 'description',
                        width = 'full',
                        fontSize = 'medium',
                        order = 1,
                    },
                    discord = {
                        name = ' |TInterface\\AddOns\\BattlegroundCommander\\Media\\Textures\\discord.tga:26:26|t Discord',
                        desc = L['Got feedback, suggestions or questions, or you just want to chat? Join us on Discord!'],
                        type = 'input',
                        width = 1.5,
                        order = 2,
                        get = function () return Namespace.Meta.discord end
                    },
                }
            },
            QueueTools = {
                name = L['Queue Tools'],
                type = 'group',
                childGroups = 'tab',
                order = 2,
                args = {
                    GroupInfo = {
                        name = L['Group Information'],
                        type = 'group',
                        order = 1,
                        args = {
                            nameFormat = {
                                name = L['Name format'],
                                desc = L['This changes what the name is shown like in the list'],
                                width = 2,
                                type = 'select',
                                values = {
                                    [NameFormat.RealmWhenPlayer] = L['Hide realm when same as yours'],
                                    [NameFormat.RealmAlways] = L['Always show the realm'],
                                    [NameFormat.RealmNever] = L['Never show the realm'],
                                },
                                set = function (_, value) Namespace.QueueTools:SetGroupInfoSetting('nameFormat', value) end,
                                get = function () return Namespace.QueueTools:GetGroupInfoSetting('nameFormat') end,
                                order = 1,
                            },
                        },
                    },
                    Automation = {
                        name = L['Queue Settings'],
                        type = 'group',
                        order = 2,
                        args = {
                            acceptRoleSelection = {
                                name = L['Automatically accept role when queuing'],
                                desc = L['Accepts the pre-selected role when your group applies for a battleground'],
                                type = 'toggle',
                                width = 'full',
                                set = function (_, value) Namespace.QueueTools:SetAutomationSetting('acceptRoleSelection', value) end,
                                get = function () return Namespace.QueueTools:GetAutomationSetting('acceptRoleSelection') end,
                                order = 1,
                            },
                            entryManagementHeader = {
                                name = L['Entry Window'],
                                type = 'header',
                                order = 2,
                            },
                            disableEntryButtonOnQueuePop = {
                                name = L['Disable entry button by default'],
                                desc = L['The entry button requires shift to be held first, or the group leader to enter.'],
                                type = 'toggle',
                                width = 'full',
                                set = function (_, value) Namespace.QueueTools:SetAutomationSetting('disableEntryButtonOnQueuePop', value) end,
                                get = function () return Namespace.QueueTools:GetAutomationSetting('disableEntryButtonOnQueuePop') end,
                                order = 3,
                            },
                            disableEntryButtonOnCancel = {
                                name = L['Disable entry button on cancel'],
                                desc = L['Disables the entry button when the group leader cancels entry, hold shift to re-enable the button'],
                                type = 'toggle',
                                width = 'full',
                                set = function (_, value) Namespace.QueueTools:SetAutomationSetting('disableEntryButtonOnCancel', value) end,
                                get = function () return Namespace.QueueTools:GetAutomationSetting('disableEntryButtonOnCancel') end,
                                order = 4,
                            },
                            enableEntryButtonModifier = {
                                name = L['Modifier button to re-enable the entry button'],
                                desc = L['This button will make sure that you can enable the entry button on a queue pop whenever you want'],
                                type = 'select',
                                style = 'radio',
                                width = 2,
                                values = {
                                    [ModifierButton.Control] = ModifierButton.Control,
                                    [ModifierButton.Alt] = ModifierButton.Alt,
                                    [ModifierButton.Shift] = ModifierButton.Shift,
                                },
                                set = function (_, value) Namespace.QueueTools:SetAutomationSetting('enableEntryButtonModifier', value) end,
                                get = function () return Namespace.QueueTools:GetAutomationSetting('enableEntryButtonModifier') end,
                                order = 5,
                            },
                            showTimeOnEntryButton = {
                                name = L['Show server time on Entry Button'],
                                desc = L['When the Entry Window appears, show the server time on the entry button.'],
                                type = 'select',
                                style = 'radio',
                                width = 2,
                                values = {
                                    [EntryButtonShowPopTime.Never] = L['Never'],
                                    [EntryButtonShowPopTime.OnlyGroupLead] = L['Group Lead'],
                                    [EntryButtonShowPopTime.Always] = L['Solo, Group Lead'],
                                },
                                set = function (_, value) Namespace.QueueTools:SetAutomationSetting('showTimeOnEntryButton', value) end,
                                get = function () return Namespace.QueueTools:GetAutomationSetting('showTimeOnEntryButton') end,
                                order = 6,
                            },
                            entryButtonTimeFormat = {
                                name = L['Entry Button time format'],
                                desc = L['Customize the time format on the Entry Button.'],
                                type = 'select',
                                style = 'radio',
                                width = 2,
                                values = {
                                    [EntryButtonTimeFormat.Full] = L['HH:MM:SS (24-hour)'],
                                    [EntryButtonTimeFormat.Half] = L['HH:MM:SS AM (12-hour)'],
                                },
                                set = function (_, value) Namespace.QueueTools:SetAutomationSetting('entryButtonTimeFormat', value) end,
                                get = function () return Namespace.QueueTools:GetAutomationSetting('entryButtonTimeFormat') end,
                                order = 7,
                            },
                        },
                    },
                    InspectQueue = {
                        name = L['Queue Inspection'],
                        type = 'group',
                        order = 3,
                        args = {
                            queuePauseDetection = {
                                name = L['Queue Pause Detection'],
                                type = 'header',
                                order = 1,
                            },
                            onlyAsLeader = {
                                name = L['Only as Leader or Assist'],
                                desc = L['Enable the queue pause detection features only when you are party leader or assist'],
                                type = 'toggle',
                                width = 'double',
                                set = function (_, value) Namespace.QueueTools:SetQueueInspectionSetting('onlyAsLeader', value) end,
                                get = function () return Namespace.QueueTools:GetQueueInspectionSetting('onlyAsLeader') end,
                                order = 2,
                            },
                            sendPausedMessage = {
                                name = L['Notify When Paused'],
                                desc = L['Send a chat message whenever the queue is paused'],
                                type = 'toggle',
                                width = 'double',
                                set = function (_, value) Namespace.QueueTools:SetQueueInspectionSetting('sendPausedMessage', value) end,
                                get = function () return Namespace.QueueTools:GetQueueInspectionSetting('sendPausedMessage') end,
                                order = 3,
                            },
                            sendResumedMessage = {
                                name = L['Notify When Resumed'],
                                desc = L['Send a chat message whenever the queue is resumed after being paused'],
                                type = 'toggle',
                                width = 'double',
                                set = function (_, value) Namespace.QueueTools:SetQueueInspectionSetting('sendResumedMessage', value) end,
                                get = function () return Namespace.QueueTools:GetQueueInspectionSetting('sendResumedMessage') end,
                                order = 4,
                            },
                            entryManagementHeader = {
                                name = L['Entry Management'],
                                type = 'header',
                                order = 5,
                            },
                            entryManagementDescription = {
                                name = L['These features are only enabled when you are the group or raid leader'] .. '\n ',
                                type = 'description',
                                fontSize = 'medium',
                                width = 'full',
                                order = 6,
                            },
                            doReadyCheckOnQueuePause = {
                                name = L['Ready Check on Pause'],
                                desc = L['Do a ready check whenever a queue pause is detected'],
                                type = 'toggle',
                                width = 'double',
                                set = function (_, value) Namespace.QueueTools:SetQueueInspectionSetting('doReadyCheckOnQueuePause', value) end,
                                get = function () return Namespace.QueueTools:GetQueueInspectionSetting('doReadyCheckOnQueuePause') end,
                                order = 7,
                            },
                            doReadyCheckOnQueueCancelAfterConfirm = {
                                name = L['Ready Check on Queue Cancel'],
                                desc = L['Do a ready check to see who entered while the group leader cancelled entering'],
                                type = 'toggle',
                                width = 'double',
                                set = function (_, value) Namespace.QueueTools:SetQueueInspectionSetting('doReadyCheckOnQueueCancelAfterConfirm', value) end,
                                get = function () return Namespace.QueueTools:GetQueueInspectionSetting('doReadyCheckOnQueueCancelAfterConfirm') end,
                                order = 8,
                            },
                            sendMessageOnQueueCancelAfterConfirm = {
                                name = L['Send "Cancel" message in chat'],
                                desc = L['Automatically send a message to the raid or party chat when you cancel the entry'],
                                type = 'toggle',
                                width = 'double',
                                set = function (_, value) Namespace.QueueTools:SetQueueInspectionSetting('sendMessageOnQueueCancelAfterConfirm', value) end,
                                get = function () return Namespace.QueueTools:GetQueueInspectionSetting('sendMessageOnQueueCancelAfterConfirm') end,
                                order = 9,
                            },
                            sendMessageOnBattlegroundEntry = {
                                name = L['Send "Enter" message in chat'],
                                desc = L['Automatically send a message to the raid or party chat when you confirm the entry'],
                                type = 'toggle',
                                width = 'double',
                                set = function (_, value) Namespace.QueueTools:SetQueueInspectionSetting('sendMessageOnBattlegroundEntry', value) end,
                                get = function () return Namespace.QueueTools:GetQueueInspectionSetting('sendMessageOnBattlegroundEntry') end,
                                order = 10,
                            },
                        }
                    },
                },
            },
            BattlegroundTools = {
                name = L['Battleground Tools'],
                type = 'group',
                childGroups = 'tab',
                order = 3,
                args = {
                    InstructionsFrame = {
                        name = L['Instructions Frame'],
                        type = 'group',
                        order = 1,
                        args = {
                            enable = {
                                name = L['Enable'],
                                desc = L['Enables or disables the instructions frame that captures raid warnings'],
                                type = 'toggle',
                                set = function (_, value) Namespace.BattlegroundTools:SetInstructionFrameState(value) end,
                                get = function () return Namespace.BattlegroundTools:GetInstructionFrameState() end,
                                order = 1,
                            },
                            reposition = {
                                name = L['Allow Repositioning'],
                                desc = L['Enable to reposition or resize the frame'],
                                type = 'toggle',
                                set = function (_, value) Namespace.BattlegroundTools:SetInstructionFrameMoveState(value) end,
                                get = function () return Namespace.BattlegroundTools:GetInstructionFrameMoveState() end,
                                order = 2,
                            },
                            fontDescription = {
                                name = L['Frame Text Configuration'],
                                type = 'header',
                                order = 4,
                            },
                            font = {
                                name = L['Font'],
                                desc = L['Font used for the text inside the frame'],
                                type = 'select',
                                dialogControl = 'LSM30_Font',
                                values = LibSharedMediaFonts,
                                set = function (_, value) Namespace.BattlegroundTools:SetFontSetting('family', value) end,
                                get = function () return Namespace.BattlegroundTools:GetFontSetting('family') end,
                                order = 5,
                            },
                            fontFlags = {
                                name = L['Font Flags'],
                                desc = L['Adjust the font flags'],
                                type = 'select',
                                values = fontFlagList,
                                set = function (_, value) Namespace.BattlegroundTools:SetFontSetting('flags', value) end,
                                get = function () return Namespace.BattlegroundTools:GetFontSetting('flags') end,
                                order = 6,
                            },
                            fontSize = {
                                name = L['Font Size'],
                                desc = L['Adjust the font size for the messages and time'],
                                type = 'range',
                                min = 4,
                                max = 50,
                                softMin = 8,
                                softMax = 20,
                                step = 1,
                                set = function (_, value) Namespace.BattlegroundTools:SetFontSetting('size', value) end,
                                get = function () return Namespace.BattlegroundTools:GetFontSetting('size') end,
                                order = 7,
                            },
                            highlightColor = {
                                name = L['Highlight Color'],
                                desc = L['Color of the most recent text message'],
                                type = 'color',
                                set = function (_, r, g, b)
                                    Namespace.BattlegroundTools:SetFontSetting('colorHighlight', { r = r, g = g, b = b })
                                end,
                                get = function ()
                                    local color = Namespace.BattlegroundTools:GetFontSetting('colorHighlight')
                                    return color.r, color.g, color.b
                                end,
                                order = 9,
                            },
                            color = {
                                name = L['Text Color'],
                                desc = L['Color of the remaining text messages'],
                                type = 'color',
                                set = function (_, r, g, b) Namespace.BattlegroundTools:SetFontSetting('color', { r = r, g = g, b = b }) end,
                                get = function ()
                                    local color = Namespace.BattlegroundTools:GetFontSetting('color')
                                    return color.r, color.g, color.b
                                end,
                                order = 10,
                            },
                            timerColor = {
                                name = L['Time Color'],
                                desc = L['Color of the time text'],
                                type = 'color',
                                set = function (_, r, g, b) Namespace.BattlegroundTools:SetFontSetting('colorTime', { r = r, g = g, b = b }) end,
                                get = function ()
                                    local color = Namespace.BattlegroundTools:GetFontSetting('colorTime')
                                    return color.r, color.g, color.b
                                end,
                                order = 11,
                            },
                            frameDesignDescription = {
                                name = L['Frame Layout'],
                                type = 'header',
                                order = 13,
                            },
                            backgroundTexture = {
                                name = L['Background Texture'],
                                desc = L['Changes the background texture of the frame'],
                                type = 'select',
                                dialogControl = 'LSM30_Background',
                                values = LibSharedMediaBackgrounds,
                                set = function (_, value) Namespace.BattlegroundTools:SetFrameSetting('backgroundTexture', value) end,
                                get = function () return Namespace.BattlegroundTools:GetFrameSetting('backgroundTexture') end,
                                order = 14,
                            },
                            backgroundInset = {
                                name = L['Background Inset'],
                                desc = L['Reduces the size of the background texture'],
                                type = 'range',
                                min = 0,
                                max = 20,
                                step = 1,
                                set = function (_, value) Namespace.BattlegroundTools:SetFrameSetting('backgroundInset', value) end,
                                get = function () return Namespace.BattlegroundTools:GetFrameSetting('backgroundInset') end,
                                order = 15,
                            },
                            backgroundColor = {
                                name = L['Background Color'],
                                type = 'color',
                                hasAlpha = true,
                                set = function (_, r, g, b, a) Namespace.BattlegroundTools:SetFrameSetting('backgroundColor', { r = r, g = g, b = b, a = a }) end,
                                get = function ()
                                    local color = Namespace.BattlegroundTools:GetFrameSetting('backgroundColor')
                                    return color.r, color.g, color.b, color.a
                                end,
                                order = 16,
                            },
                            borderTexture = {
                                name = L['Border Texture'],
                                desc = L['Changes the border texture of the frame'],
                                type = 'select',
                                dialogControl = 'LSM30_Border',
                                values = LibSharedMediaBorders,
                                set = function (_, value) Namespace.BattlegroundTools:SetFrameSetting('borderTexture', value) end,
                                get = function () return Namespace.BattlegroundTools:GetFrameSetting('borderTexture') end,
                                order = 17,
                            },
                            borderSize = {
                                name = L['Border Size'],
                                desc = L['Changes the border size'],
                                type = 'range',
                                min = 0,
                                max = 30,
                                step = 1,
                                set = function (_, value) Namespace.BattlegroundTools:SetFrameSetting('borderSize', value) end,
                                get = function () return Namespace.BattlegroundTools:GetFrameSetting('borderSize') end,
                                order = 18,
                            },
                            borderColor = {
                                name = L['Border Color'],
                                type = 'color',
                                hasAlpha = true,
                                set = function (_, r, g, b, a) Namespace.BattlegroundTools:SetFrameSetting('borderColor', { r = r, g = g, b = b, a = a }) end,
                                get = function ()
                                    local color = Namespace.BattlegroundTools:GetFrameSetting('borderColor')
                                    return color.r, color.g, color.b, color.a
                                end,
                                order = 19,
                            },
                            topToBottom = {
                                name = L['Latest message on top '],
                                desc = L['Enable to show the latest message on top, otherwise the latest message will be on the bottom'],
                                type = 'toggle',
                                set = function (_, value) Namespace.BattlegroundTools:SetFontSetting('topToBottom', value) end,
                                get = function () return Namespace.BattlegroundTools:GetFontSetting('topToBottom') end,
                                order = 20,
                            },
                            maximumInstructions = {
                                name = L['Maximum instructions'],
                                desc = L['The maximum amount of instructions to show'],
                                type = 'range',
                                min = 1,
                                max = 20,
                                step = 1,
                                set = function (_, value) Namespace.BattlegroundTools:SetFrameSetting('maxInstructions', value) end,
                                get = function () return Namespace.BattlegroundTools:GetFrameSetting('maxInstructions') end,
                                order = 21,
                            },
                            zoneDescription = {
                                name = L['Enabled in Zones'],
                                type = 'header',
                                order = 23,
                            },
                            clearFrameOnExitBattleground = {
                                name = L['Clear frame when exiting the battleground'],
                                desc = L['Removes the instructions from the last battleground'],
                                type = 'toggle',
                                width = 'full',
                                set = function (_, value) Namespace.BattlegroundTools:SetFrameSetting('clearFrameOnExitBattleground', value) end,
                                get = function () return Namespace.BattlegroundTools:GetFrameSetting('clearFrameOnExitBattleground') end,
                                order = 24,
                            },
                            zones = {
                                name = L['Select Zones'],
                                desc = L['Select the zones where the frame should appear when enabled'],
                                type = 'multiselect',
                                values = Namespace.Battleground.Zones,
                                set = function (_, zoneId, value) Namespace.BattlegroundTools:SetZoneId(zoneId, value) end,
                                get = function (_, zoneId) return Namespace.BattlegroundTools:GetZoneId(zoneId) end,
                                order = 25,
                            },
                        },
                    },
                    WantBattlegroundLead = {
                        name = L['Requesting Lead'],
                        type = 'group',
                        order = 2,
                        args = {
                            enableManualRequest = {
                                name = L['Enable Custom Message'],
                                desc = L['Enable sending a custom message if the leader not using Battleground Commander'],
                                type = 'toggle',
                                set = function (_, input) return Namespace.BattlegroundTools:SetWantLeadSetting('enableManualRequest', input) end,
                                get = function () return Namespace.BattlegroundTools:GetWantLeadSetting('enableManualRequest') end,
                                order = 1,
                            },
                            manualRequestMessage = {
                                name = L['Custom Message'],
                                desc = L['{leader} will be replaced by the leader name in this message and is optional'],
                                type = 'input',
                                multiline = false,
                                width = 'full',
                                set = function (_, input) return Namespace.BattlegroundTools:SetWantLeadSetting('manualRequestMessage', input) end,
                                get = function () return Namespace.BattlegroundTools:GetWantLeadSetting('manualRequestMessage') end,
                                order = 2,
                            },
                            sendWhisper = {
                                name = L['Send Whisper (/w)'],
                                type = 'toggle',
                                width = 'full',
                                set = function (_, input) return Namespace.BattlegroundTools:SetWantLeadSetting('sendWhisper', input) end,
                                get = function () return Namespace.BattlegroundTools:GetWantLeadSetting('sendWhisper') end,
                                order = 3,
                            },
                            sendSay = {
                                name = L['Send Say (/s)'],
                                type = 'toggle',
                                width = 'full',
                                set = function (_, input) return Namespace.BattlegroundTools:SetWantLeadSetting('sendSay', input) end,
                                get = function () return Namespace.BattlegroundTools:GetWantLeadSetting('sendSay') end,
                                order = 4,
                            },
                            sendRaid = {
                                name = L['Send Raid (/r, /i)'],
                                type = 'toggle',
                                width = 'full',
                                set = function (_, input) return Namespace.BattlegroundTools:SetWantLeadSetting('sendRaid', input) end,
                                get = function () return Namespace.BattlegroundTools:GetWantLeadSetting('sendRaid') end,
                                order = 5,
                            },
                        },
                    },
                    LeaderSetup = {
                        name = L['Leader Setup'],
                        type = 'group',
                        order = 3,
                        args = {
                            leaderSound = {
                                name = L['Leader promotion sound'],
                                desc = L['Play a sound when you are promoted or demoted from being raid leader.'],
                                width = 'full',
                                type = 'toggle',
                                set = function (_, input) Namespace.BattlegroundTools:SetLeaderToolsSetting('leaderSound', input) end,
                                get = function () return Namespace.BattlegroundTools:GetLeaderToolsSetting('leaderSound') end,
                                order = 1,
                            },
                            demoteUnlisted = {
                                name = L['Demote players without configured assistant'],
                                desc = L['When someone gets assistant, or was assistant when you get lead, it will automatically demote these players to member if not explicitly configured'],
                                type = 'toggle',
                                width = 'full',
                                set = function (_, input) return Namespace.BattlegroundTools:SetLeaderToolsSetting('demoteUnlisted', input) end,
                                get = function () return Namespace.BattlegroundTools:GetLeaderToolsSetting('demoteUnlisted') end,
                                order = 2,
                            },
                            leaderIcon = {
                                name = L['My raid mark'],
                                desc = L['Automatically assign the configured raid mark when you become leader.'],
                                type = 'select',
                                values = {
                                    [RaidIconIndex.NoIcon] = L['Do not mark me'],
                                    [RaidIconIndex.YellowStar] = RaidIconChatTexture.YellowStar,
                                    [RaidIconIndex.OrangeCircle] = RaidIconChatTexture.OrangeCircle,
                                    [RaidIconIndex.PurpleDiamond] = RaidIconChatTexture.PurpleDiamond,
                                    [RaidIconIndex.GreenTriangle] = RaidIconChatTexture.GreenTriangle,
                                    [RaidIconIndex.SilverMoon] = RaidIconChatTexture.SilverMoon,
                                    [RaidIconIndex.BlueSquare] = RaidIconChatTexture.BlueSquare,
                                    [RaidIconIndex.RedCross] = RaidIconChatTexture.RedCross,
                                    [RaidIconIndex.WhiteSkull] = RaidIconChatTexture.WhiteSkull,
                                },
                                set = function (_, input)
                                    Namespace.BattlegroundTools:SetLeaderToolsSetting('leaderIcon', input)
                                end,
                                get = function () return Namespace.BattlegroundTools:GetLeaderToolsSetting('leaderIcon') end,
                                order = 3,
                            },
                            availableIcons = {
                                name = L['Available icons'],
                                desc = L['Available icons to automatically mark people with'],
                                type = 'multiselect',
                                values = {
                                    [RaidIconIndex.YellowStar] = RaidIconChatTexture.YellowStar,
                                    [RaidIconIndex.OrangeCircle] = RaidIconChatTexture.OrangeCircle,
                                    [RaidIconIndex.PurpleDiamond] = RaidIconChatTexture.PurpleDiamond,
                                    [RaidIconIndex.GreenTriangle] = RaidIconChatTexture.GreenTriangle,
                                    [RaidIconIndex.SilverMoon] = RaidIconChatTexture.SilverMoon,
                                    [RaidIconIndex.BlueSquare] = RaidIconChatTexture.BlueSquare,
                                    [RaidIconIndex.RedCross] = RaidIconChatTexture.RedCross,
                                    [RaidIconIndex.WhiteSkull] = RaidIconChatTexture.WhiteSkull,
                                },
                                set = function (_, markerIndex, value) Namespace.BattlegroundTools:SetMarkerIndexSetting(markerIndex, value) end,
                                get = function (_, markerIndex) return Namespace.BattlegroundTools:GetMarkerIndexSetting(markerIndex) end,
                                order = 4,
                            },
                        },
                    },
                },
            },
            PlayerManagement = {
                name = L['Player Management'],
                type = 'group',
                order = 4,
                childGroups = 'tab',
                args = {
                    Players = {
                        name = L['Players'],
                        type = 'group',
                        order = 1,
                        childGroups = 'tree',
                        args = {
                            addPlayerFromGroup = {
                                name = L['Add player from group'],
                                type = 'select',
                                width = 1.2,
                                values = function ()
                                    local names = {}
                                    local found = 0
                                    Namespace.PlayerData.ForEachUnitData(function (playerData)
                                        if playerData.units.player then return end

                                        local name = playerData.name
                                        local color = playerData.classColor

                                        if Namespace.BattlegroundTools:GetPlayerConfig(name) then return end

                                        names[name] = color and color:WrapTextInColorCode(name) or name
                                        found = found + 1
                                    end)

                                    Memory.ConfigurationSetup.args.PlayerManagement.args.Players.args.addPlayerFromGroup.disabled = found == 0

                                    return names
                                end,
                                get = function () return nil end,
                                set = addPlayerConfig,
                                order = 1,
                            },
                            addPlayerFromRecentGroup = {
                                name = L['Add recently played with'],
                                type = 'select',
                                width = 1.2,
                                values = function ()
                                    local names = {}
                                    local found = 0
                                    Namespace.PlayerData.ForEachPlayerData(function (playerData)
                                        if playerData.units.primary then return end

                                        local name = playerData.name
                                        local color = playerData.classColor

                                        if Namespace.BattlegroundTools:GetPlayerConfig(name) then return end

                                        names[name] = color and color:WrapTextInColorCode(name) or name
                                        found = found + 1
                                    end)

                                    Memory.ConfigurationSetup.args.PlayerManagement.args.Players.args.addPlayerFromRecentGroup.disabled = found == 0

                                    return names
                                end,
                                get = function () return nil end,
                                set = addPlayerConfig,
                                order = 2,
                            },
                            addPlayerRaw = {
                                name = L['Manually add Player-RealmName'],
                                type = 'input',
                                multiline = false,
                                width = 1.2,
                                get = function () return nil end,
                                set = addPlayerConfig,
                                order = 3,
                            },
                        }
                    },
                    ExportPlayers = {
                        name = L['Export'],
                        type = 'group',
                        order = 2,
                        args = {
                            ExportField = {
                                name = L['Copy'],
                                desc = L['This text can be copied and pasted into the text field under "Import"'],
                                type = 'input',
                                order = 1,
                                multiline = 30,
                                width = 3.5,
                                get = function ()
                                    local AceSerializer = Namespace.Libs.AceSerializer
                                    local data = {}
                                    for playerName, playerConfig in pairs(Namespace.BattlegroundTools:GetAllPlayerConfig()) do
                                        data[playerName] = {
                                            gl = playerConfig.groupLabel:gsub('|c', '[c'):gsub('|r', '[r'),
                                            glb = playerConfig.giveLeadBehavior,
                                            mb = playerConfig.markBehavior,
                                            pta = playerConfig.promoteToAssistant,
                                            pi = playerConfig.preferredIcon,
                                        }
                                    end

                                    local serialized = AceSerializer:Serialize(data)
                                    if not serialized then return 'serialize failed, please report this bug' end

                                    return serialized
                                end,
                                set = function () return end,
                            },
                        },
                    },
                    ImportPlayers = {
                        name = L['Import'],
                        type = 'group',
                        order = 3,
                        args = {
                            ImportField = {
                                name = L['Paste'],
                                desc = L['Here you can paste the text from "import". Press "Accept" to import the settings'],
                                type = 'input',
                                order = 1,
                                multiline = 30,
                                width = 3.5,
                                get = function () end,
                                set = function (_, input)
                                    local AceSerializer = Namespace.Libs.AceSerializer
                                    local success, data = AceSerializer:Deserialize(input)
                                    if not success then return end

                                    local type = type
                                    local Addon = Namespace.Addon
                                    local BattlegroundTools = Namespace.BattlegroundTools
                                    local GetPlayerDataByName = Namespace.PlayerData.GetPlayerDataByName
                                    local created = 0
                                    local updated = 0
                                    for playerName, incoming in pairs(data) do
                                        local config = BattlegroundTools:GetPlayerConfig(playerName)
                                        if not config then
                                            config = BattlegroundTools:CreatePlayerConfig(playerName)
                                            created = created + 1
                                        else
                                            updated = updated + 1
                                        end

                                        local playerData = GetPlayerDataByName(playerName)
                                        config.groupLabel = playerData and playerData.classColor:WrapTextInColorCode(playerName) or config.groupLabel

                                        if not config.groupLabel:match('|c(.+)|r') then
                                            config.groupLabel = type(incoming.gl) == 'string' and incoming.gl:gsub('%[c', '|c'):gsub('%[r', '|r') or playerName
                                        end

                                        if type(incoming.glb) == 'number' then
                                            config.giveLeadBehavior = incoming.glb
                                        end

                                        if type(incoming.mb) == 'number' then
                                            config.markBehavior = incoming.mb
                                        end

                                        if type(incoming.pta) == 'boolean' then
                                            config.promoteToAssistant = incoming.pta
                                        end

                                        if type(incoming.pi) == 'number' then
                                            config.preferredIcon = incoming.pi
                                        end
                                    end

                                    Addon:Print(format(L['Imported player config, new: %d updated: %s'], created, updated))
                                    Addon:InitializePlayerConfig()
                                end,
                            },
                        },
                    },
                },
            },
        },
    }

    local function header(text, order) return {
        name = text,
        type = 'header',
        width = 'full',
        order = order,
    } end

    local function sectionTitle(text, order) return {
        name = text,
        type = 'description',
        fontSize = 'large',
        width = 'full',
        order = order,
    } end

    local function description(list, order) return {
        name = ' - ' .. concat(list, '\n - ') .. '\n ',
        type = 'description',
        fontSize = 'medium',
        width = 'full',
        order = order,
    } end

    local changelogSection = Memory.ConfigurationSetup.args.Information.args
    local order = 1
    for _, changelog in pairs(Namespace.Changelog) do
        order = order + 1
        changelogSection['changelog' .. order] = header('Version: ' .. changelog.version, order)

        if changelog.features then
            order = order + 1
            changelogSection['changelog' .. order] = sectionTitle('Features', order)

            order = order + 1
            changelogSection['changelog' .. order] = description(changelog.features, order)
        end

        if changelog.improvements then
            order = order + 1
            changelogSection['changelog' .. order] = sectionTitle('Improvements', order)

            order = order + 1
            changelogSection['changelog' .. order] = description(changelog.improvements, order)
        end

        if changelog.bugs then
            order = order + 1
            changelogSection['changelog' .. order] = sectionTitle('Bugs', order)

            order = order + 1
            changelogSection['changelog' .. order] = description(changelog.bugs, order)
        end
    end

    return Memory.ConfigurationSetup
end

function Namespace.Config.CreatePlayerConfigNode(config)
    local L = Namespace.Libs.AceLocale:GetLocale(AddonName)
    local GiveLeadBehavior = Namespace.BattlegroundTools.GiveLeadBehavior
    local MarkBehavior = Namespace.BattlegroundTools.MarkBehavior

    return {
        name = config.groupLabel,
        type = 'group',
        order = config.sortOrderIndex + 10,
        args = {
            spacer = {
                name = config.groupLabel,
                type = 'description',
                fontSize = 'large',
                width = 1.5,
                order = 0.1,
            },
            delete = {
                name = L['Delete'],
                desc = L['Hold shift to omit the confirm message'],
                type = 'execute',
                confirm = function ()
                    if IsShiftKeyDown() then return false end
                    return format(L['Are you sure you want to delete the config for %s?'], config.groupLabel)
                end,
                width = 1,
                func = function ()
                    Memory.ConfigurationSetup.args.PlayerManagement.args.Players.args[config.playerName] = nil
                    Namespace.BattlegroundTools:DeletePlayerConfig(config.playerName)
                end,
                order = 1,
            },
            splitter = {
                name = '',
                type = 'header',
                order = 2,
            },
            playerNickname = {
                name = L['Player nickname'],
                desc = L['Show this nickname in the group info. Leave empty to show name-realm instead.'],
                type = 'input',
                multiline = false,
                width = 'full',
                set = function (_, value) Namespace.BattlegroundTools:SetPlayerConfigValue(config.playerName, 'playerNickname', value) end,
                get = function () return Namespace.BattlegroundTools:GetPlayerConfigValue(config.playerName, 'playerNickname') end,
                order = 3,
            },
            promoteToAssistant = {
                name = L['Promote to assistant'],
                desc = L['Automatically promote this player to assistant'],
                type = 'toggle',
                set = function (_, value) Namespace.BattlegroundTools:SetPlayerConfigValue(config.playerName, 'promoteToAssistant', value) end,
                get = function () return Namespace.BattlegroundTools:GetPlayerConfigValue(config.playerName, 'promoteToAssistant') end,
                order = 4,
            },
            giveLeadBehavior = {
                name = L['When this user requests lead'],
                desc = L['Determines which action to perform when this player requests battleground lead'],
                type = 'select',
                style = 'radio',
                values = {
                    [GiveLeadBehavior.NoAutomation] = L['No automation'],
                    [GiveLeadBehavior.GiveLead] = L['Give lead, unless I want it'],
                    [GiveLeadBehavior.OverrideLead] = L['Always give lead'],
                    [GiveLeadBehavior.RejectLead] = L['Reject lead'],
                },
                set = function (_, value) Namespace.BattlegroundTools:SetPlayerConfigValue(config.playerName, 'giveLeadBehavior', value) end,
                get = function () return Namespace.BattlegroundTools:GetPlayerConfigValue(config.playerName, 'giveLeadBehavior') end,
                order = 5,
            },
            markBehavior = {
                name = L['Mark this player'],
                type = 'select',
                style = 'radio',
                values = {
                    [MarkBehavior.NoMark] = L['Do not mark'],
                    [MarkBehavior.AnyAvailable] = L['Any available icon'],
                    [MarkBehavior.PreferredMark] = L['Preferred icon'],
                },
                set = function (_, value)
                    Memory.ConfigurationSetup.args.PlayerManagement.args.Players.args[config.playerName].args.preferredIcon.disabled = value ~= MarkBehavior.PreferredMark
                    Namespace.BattlegroundTools:SetPlayerConfigValue(config.playerName, 'markBehavior', value)
                end,
                get = function () return Namespace.BattlegroundTools:GetPlayerConfigValue(config.playerName, 'markBehavior') end,
                order = 6,
            },
            preferredIcon = {
                name = L['Preferred icon'],
                desc = L['Try to mark with this icon. If this icon is not available, a random icon will be used'],
                type = 'select',
                disabled = config.markBehavior ~= MarkBehavior.PreferredMark,
                values = {
                    [RaidIconIndex.YellowStar] = RaidIconChatTexture.YellowStar,
                    [RaidIconIndex.OrangeCircle] = RaidIconChatTexture.OrangeCircle,
                    [RaidIconIndex.PurpleDiamond] = RaidIconChatTexture.PurpleDiamond,
                    [RaidIconIndex.GreenTriangle] = RaidIconChatTexture.GreenTriangle,
                    [RaidIconIndex.SilverMoon] = RaidIconChatTexture.SilverMoon,
                    [RaidIconIndex.BlueSquare] = RaidIconChatTexture.BlueSquare,
                    [RaidIconIndex.RedCross] = RaidIconChatTexture.RedCross,
                    [RaidIconIndex.WhiteSkull] = RaidIconChatTexture.WhiteSkull,
                },
                set = function (_, value) Namespace.BattlegroundTools:SetPlayerConfigValue(config.playerName, 'preferredIcon', value) end,
                get = function () return Namespace.BattlegroundTools:GetPlayerConfigValue(config.playerName, 'preferredIcon') end,
                order = 7,
            },
        }
    }
end
