local ModuleName, Public, _, Namespace = 'Battleground', {}, ...

local Addon = Namespace.Addon
local Module = Addon:NewModule(ModuleName, 'AceEvent-3.0', 'AceTimer-3.0', 'AceComm-3.0')

local GetBattlefieldStatus = GetBattlefieldStatus
local GetInstanceInfo = GetInstanceInfo
local GetMaxBattlefieldID = GetMaxBattlefieldID
local pairs = pairs

Namespace.Battleground = Public

local QueueStatus = {
    Queued = 'queued',
    Confirm = 'confirm',
    Active = 'active',
    None = 'none',
    Error = 'error',
}

Namespace.Battleground.QueueStatus = QueueStatus

local Memory = {
    currentZoneId = nil,
    queueState = {
        --[0] = {
        --    status = QueueStatus,
        --    queueSuspended = boolean
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
    for _, queueState in pairs(Memory.queueState) do
        if queueState.status == QueueStatus.Active then
            return true
        end
    end

    return false
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
    local previousState = Memory.queueState[queueId] or { status = QueueStatus.None, suspendedQueue = false }
    local status, mapName, _, _, suspendedQueue = GetBattlefieldStatus(queueId)
    local newState = { status = status, suspendedQueue = suspendedQueue }

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
    local _, instanceType, _, _, _, _, _, currentZoneId = GetInstanceInfo()
    if instanceType == 'none' then currentZoneId = 0 end

    Memory.currentZoneId = currentZoneId

    if not isLogin and not isReload then return end

    -- when logging in or reloading mid-queue, the first queue status mutation
    -- is inaccurate if not set before it happens
    for queueId = 1, GetMaxBattlefieldID() do
        local status, _, _, _, suspendedQueue = GetBattlefieldStatus(queueId)
        Memory.queueState[queueId] = { status = status, suspendedQueue = suspendedQueue }
    end
end