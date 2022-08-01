local _, Namespace = ...

Namespace.Communication = {}

local AceSerializer = Namespace.Libs.AceSerializer
local LibCompress = Namespace.Libs.LibCompress
local Encoder = LibCompress:GetAddonEncodeTable()

local GroupType = Namespace.Utils.GroupType
local GetRealUnitName = Namespace.Utils.GetRealUnitName

local Channel = {
    Raid = 'RAID',
    Party = 'PARTY',
    Instance = 'INSTANCE_CHAT',
    Whisper = 'WHISPER',
    Say = 'SAY',
}
Namespace.Communication.Channel = Channel

function Namespace.Communication.PackData(data)
    return Encoder:Encode(LibCompress:CompressHuffman(AceSerializer:Serialize(data)))
end

function Namespace.Communication.UnpackData(raw)
    local decompressed = LibCompress:Decompress(Encoder:Decode(raw))
    if not decompressed then return end

    local success, data = AceSerializer:Deserialize(decompressed)
    if not success then return end

    return data
end

function Namespace.Communication.GetMessageDestination()
    local currentType = Namespace.Utils.GetGroupType()

    if currentType == GroupType.InstanceRaid or currentType == GroupType.InstanceParty then return Channel.Instance, nil end
    if currentType == GroupType.Raid then return Channel.Raid, nil end
    if currentType == GroupType.Party then return Channel.Party, nil end

    return Channel.Whisper, GetRealUnitName('player')
end
