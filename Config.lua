local AddonName, Namespace = ...

local pairs = pairs
local concat = table.concat
local format = string.format

Namespace.Config = {}

local Memory = {
    ConfigurationSetup = nil,
    DefaultConfiguration = {
        profile = {
            QueueTools = {
                showGroupQueueFrame = false,
                Automation = {
                    acceptRoleSelection = false,
                    disableEntryButtonOnCancel = true,
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
                WantBattlegroundLead = {
                    wantLead = false,
                    automaticallyAccept = {},
                    automaticallyReject = {},
                    enableManualRequest = false,
                    manualRequestMessage = '{rt4} {leader} {rt4} can you give me lead please?',
                    sendWhisper = true,
                    sendSay = true,
                    sendRaid = true,
                },
                InstructionFrame = {
                    show = true,
                    move = true,
                    size = { width = 200, height = 100 },
                    position = { anchor = 'CENTER', x = 0, y = 0 },
                    zones = {
                        [0]    = true,
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
                        shadowColor = { 0, 0, 0, 1 },
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

function Namespace.Config.GetConfigurationSetup()
    if Memory.ConfigurationSetup then return Memory.ConfigurationSetup end

    local function textToKeyedTable(input)
        local table = {}
        for name in input:gmatch("[^\n]+") do
            table[name:gsub('%s+', '')] = true
        end

        return table
    end

    local function keyedTableToText(table)
        local text = {}
        local i = 0
        for name in pairs(table) do
            i = i + 1
            text[i] = name
        end

        return concat(text, "\n")
    end

    local L = Namespace.Libs.AceLocale:GetLocale(AddonName)
    local fontFlagList = { [''] = 'None', ['OUTLINE'] = 'Outline', ['OUTLINE, MONOCHROME'] = 'Outline Monochrome' }
    local LibSharedMediaFonts = Namespace.Libs.LibSharedMedia:HashTable('font')
    local LibSharedMediaBackgrounds = Namespace.Libs.LibSharedMedia:HashTable('background')
    local LibSharedMediaBorders = Namespace.Libs.LibSharedMedia:HashTable('border')

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
                        name =  format(L['Version'] .. ': %s (%s)', Namespace.Meta.version, Namespace.Meta.date),
                        type = 'description',
                        width = 'full',
                        fontSize = 'medium',
                    },
                }
            },
            QueueTools = {
                name = L['Queue Tools'],
                type = 'group',
                order = 2,
                args = {
                    Automation = {
                        name = L['Automation'],
                        type = 'group',
                        order = 2,
                        args = {
                            acceptRoleSelection = {
                                name = L['Automatically Accept Role Selection'],
                                desc = L['Accepts the pre-selected role when your group applies for a battleground'],
                                type = 'toggle',
                                width = 'full',
                                set = function (_, value) Namespace.QueueTools:SetAutomationSetting('acceptRoleSelection', value) end,
                                get = function () return Namespace.QueueTools:GetAutomationSetting('acceptRoleSelection') end,
                                order = 1,
                            },
                            disableEntryButtonOnCancel = {
                                name = L['Disable Entry Button on Cancel'],
                                desc = L['Disables the entry button when the group leader cancels entry, hold shift to re-enable the button'],
                                type = 'toggle',
                                width = 'full',
                                set = function (_, value) Namespace.QueueTools:SetAutomationSetting('disableEntryButtonOnCancel', value) end,
                                get = function () return Namespace.QueueTools:GetAutomationSetting('disableEntryButtonOnCancel') end,
                                order = 2,
                            },
                        },
                    },
                    InspectQueue = {
                        name = L['Queue Inspection'],
                        type = 'group',
                        order = 2,
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
                                name = L['These features are only enabled when you are the group or raid leader'],
                                type = 'description',
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
                                order = 16,
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
                                order = 18,
                            },
                            borderTexture = {
                                name = L['Border Texture'],
                                desc = L['Changes the border texture of the frame'],
                                type = 'select',
                                dialogControl = 'LSM30_Border',
                                values = LibSharedMediaBorders,
                                set = function (_, value) Namespace.BattlegroundTools:SetFrameSetting('borderTexture', value) end,
                                get = function () return Namespace.BattlegroundTools:GetFrameSetting('borderTexture') end,
                                order = 15,
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
                                order = 17,
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
                                values = Namespace.BattlegroundTools.Zones,
                                set = function (_, zoneId, value) Namespace.BattlegroundTools:SetZoneId(zoneId, value) end,
                                get = function (_, zoneId) return Namespace.BattlegroundTools:GetZoneId(zoneId) end,
                                order = 25,
                            },
                        },
                    },
                    WantBattlegroundLead = {
                        name = L['Battleground Leader'],
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
                                name = L['Send Raid (/r)'],
                                type = 'toggle',
                                width = 'full',
                                set = function (_, input) return Namespace.BattlegroundTools:SetWantLeadSetting('sendRaid', input) end,
                                get = function () return Namespace.BattlegroundTools:GetWantLeadSetting('sendRaid') end,
                                order = 5,
                            },
                            automationBehavior = {
                                name = L['Decision Automation'],
                                type = 'header',
                                order = 6,
                            },
                            acceptRejectDescription = {
                                name = L['Each player name goes on a new line. The format is "Playername" for players from your realm, and "Playername-Realname" for other realms.'],
                                type = 'description',
                                width = 'full',
                                order = 7,
                            },
                            automaticallyAccept = {
                                name = L['Automatically Accept Request'],
                                desc = L['Players to automatically accept when they request lead'],
                                type = 'input',
                                width = 'full',
                                multiline = 10,
                                set = function (_, input) return Namespace.BattlegroundTools:SetWantLeadSetting('automaticallyAccept', textToKeyedTable(input)) end,
                                get = function () return keyedTableToText(Namespace.BattlegroundTools:GetWantLeadSetting('automaticallyAccept')) end,
                                order = 8,
                            },
                            automaticallyReject = {
                                name = L['Automatically Reject Request'],
                                desc = L['Players to automatically reject when they request lead'],
                                type = 'input',
                                width = 'full',
                                multiline = 10,
                                set = function (_, input) return Namespace.BattlegroundTools:SetWantLeadSetting('automaticallyReject', textToKeyedTable(input)) end,
                                get = function () return keyedTableToText(Namespace.BattlegroundTools:GetWantLeadSetting('automaticallyReject')) end,
                                order = 9,
                            },
                        },
                    },
                },
            },
        },
    }

    return Memory.ConfigurationSetup
end
