-- Decides when the secure state driver has to be rebuilt, and rebuilds it.
local _, ns = ...
local C = ns.Constants
local R = {}
ns.Rebuild = R

local header = ns.Frames.header
local pending = false
local queued = false
local forceNext = false
local lastKey

local function RegisterDriver(condition)
    UnregisterStateDriver(header, "formpage")
    header:SetAttribute("state-formpage", "init")
    RegisterStateDriver(header, "formpage", condition)
end

local function ArmRefreshIfMismatch(force)
    local wanted = tonumber(header:GetAttribute("state-formpage"))
    if wanted and wanted <= 0 then wanted = nil end
    local applied = tonumber(header:GetAttribute("fp-page"))
    if force or wanted ~= applied then
        header:SetAttribute("state-formpage", "refresh")
    end
end

local function Rebuild()
    queued = false
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    local force = forceNext
    forceNext = false

    local count = ns.Attach.Attach(force)
    local info = ns.Attach.Info()
    local condition = ns.Conditions.Build(ns.Settings.Get())
    local key = condition .. "#" .. count .. "#" .. info.name .. "#" .. (info.signature or "")
    local changed = key ~= lastKey
    if not changed then
        if force then ArmRefreshIfMismatch(true) end
        return
    end
    lastKey = key
    RegisterDriver(condition)
    ArmRefreshIfMismatch(force or changed)
end

function R.Now(force)
    if force then forceNext = true end
    Rebuild()
end

function R.Request(force)
    if force then forceNext = true end
    if queued then return end
    if InCombatLockdown() then
        pending = true
        return
    end
    if C_Timer and C_Timer.After then
        queued = true
        C_Timer.After(C.REBUILD_DEBOUNCE, Rebuild)
    else
        Rebuild()
    end
end

function R.FlushPending()
    if pending or forceNext then Rebuild() end
end

function R.IsPending()
    return pending
end

function R.LastKey()
    return lastKey
end
