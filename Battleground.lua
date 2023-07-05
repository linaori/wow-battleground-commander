local ModuleName, Public, Private, AddonName, Namespace = 'Battleground', {}, {}, ...

local Addon = Namespace.Addon
local Module = Addon:NewModule(ModuleName, 'AceEvent-3.0', 'AceTimer-3.0', 'AceComm-3.0')
local L = Namespace.Libs.AceLocale:GetLocale(AddonName)

local GetBattlefieldStatus = GetBattlefieldStatus
local GetInstanceInfo = GetInstanceInfo
local GetMaxBattlefieldID = GetMaxBattlefieldID
local GetActiveMatchState = C_PvP.GetActiveMatchState
local pairs = pairs

Namespace.Battleground = Public

local QueueStatus = {
    Queued = 'queued',
    Confirm = 'confirm',
    Active = 'active',
    None = 'none',
    Error = 'error',
}

local ActiveMatchState = {
    Nothing = 0,
    Active = 1,
    Score = 2,
}

local Zones = {
    [30]   = L['Alterac Valley'],
    [2197] = L['Alterac Valley (Korrak\'s Revenge)'],
    [1191] = L['Ashran'],
    [2118] = L['Battle for Wintergrasp'],
    [628]  = L['Isle of Conquest'],
    [2107] = L['Arathi Basin'],
    [529]  = L['Arathi Basin (Classic)'],
    [1681] = L['Arathi Basin (Winter)'],
    [2177] = L['Arathi Basin Comp Stomp'],
    [1105] = L['Deepwind Gorge'],
    [566]  = L['Eye of the Storm'],
    [968]  = L['Eye of the Storm (Rated)'],
    [1803] = L['Seething Shore'],
    [727]  = L['Silvershard Mines'],
    [607]  = L['Strand of the Ancients'],
    [998]  = L['Temple of Kotmogu'],
    [761]  = L['The Battle for Gilneas'],
    [726]  = L['Twin Peaks'],
    [489]  = L['Warsong Gulch'],
    [1280] = L['Southshore vs. Tarren Mill'],
}

Namespace.Battleground.QueueStatus = QueueStatus
Namespace.Battleground.Zones = Zones
local Memory = {
    currentZoneId = nil,
    queueState = {
        --[0] = {
        --    status = QueueStatus,
        --    queueSuspended = boolean
        --    queueId = number
        --},
    },
    queueStateChangeListeners = {},
}

--- per name callback with the argument being {previousState, newState, mapName}
--- @param callback
function Public.RegisterQueueStateListener(listenerName, callback)
    Memory.queueStateChangeListeners[listenerName] = callback
end

function Public.InActiveBattleground()
    return GetActiveMatchState() == ActiveMatchState.Active
end

function Private.InitCurrentZoneId()
    local _, instanceType, _, _, _, _, _, currentZoneId = GetInstanceInfo()
    if instanceType == 'none' then currentZoneId = 0 end

    Memory.currentZoneId = currentZoneId
end

function Public.GetCurrentZoneId()
    if Memory.currentZoneId == nil then Private.InitCurrentZoneId() end

    return Memory.currentZoneId
end

-- Getting ready to enter, or already in a bg, so other queues will pause
function Public.AllowQueuePause()
    for _, queueState in pairs(Memory.queueState) do
        if queueState.status == QueueStatus.Active or queueState.status == QueueStatus.Confirm then
            return true
        end
    end

    return false
end

function Module:UPDATE_BATTLEFIELD_STATUS(_, queueId)
    local previousState = Memory.queueState[queueId] or { status = QueueStatus.None, suspendedQueue = false, queueId = queueId }
    local status, mapName, _, _, suspendedQueue = GetBattlefieldStatus(queueId)
    local newState = { status = status, suspendedQueue = suspendedQueue, queueId = queueId }

    if newState.status == previousState.status and newState.suspendedQueue == previousState.suspendedQueue then return end

    for _, listener in pairs(Memory.queueStateChangeListeners) do
        listener(previousState, newState, mapName)
    end

    Memory.queueState[queueId] = newState
end

function Module:OnEnable()
    self:RegisterEvent('UPDATE_BATTLEFIELD_STATUS')
    self:RegisterEvent('PLAYER_ENTERING_WORLD')
end

function Module:PLAYER_ENTERING_WORLD(_, isLogin, isReload)
    Private.InitCurrentZoneId()

    if not isLogin and not isReload then return end

    -- when logging in or reloading mid-queue, the first queue status mutation
    -- is inaccurate if not set before it happens
    for queueId = 1, GetMaxBattlefieldID() do
        local status, _, _, _, suspendedQueue = GetBattlefieldStatus(queueId)
        Memory.queueState[queueId] = { status = status, suspendedQueue = suspendedQueue }
    end
end
