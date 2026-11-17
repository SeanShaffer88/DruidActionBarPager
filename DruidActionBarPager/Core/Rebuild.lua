-- Decides when the secure state driver has to be rebuilt, and rebuilds it.
-- A rebuild attaches the bar and registers a new [form:N] condition. It only
-- runs out of combat; a request made in combat waits for PLAYER_REGEN_ENABLED.
local _, ns = ...
local C = ns.Constants

local R = {}
ns.Rebuild = R

local header = ns.Frames.header

local pending = false      -- a rebuild was requested during combat
local queued = false       -- a debounced rebuild is scheduled
local forceNext = false    -- the next rebuild must look at the bar afresh
local lastKey              -- condition, count and bar name last applied

-- Registers the driver with the given condition. "init" arms the skip so the
-- evaluation RegisterStateDriver does right now, from addon code, never runs
-- the handler and touches the bar.
local function RegisterDriver(condition)
    UnregisterStateDriver(header, "formpage")
    header:SetAttribute("state-formpage", "init")
    RegisterStateDriver(header, "formpage", condition)
end

-- The registration evaluation was skipped, so the page it wanted may not be
-- applied yet (e.g. after /reload while shifted). If what the driver wants
-- differs from what is applied, re-arm it so the next game-driven evaluation
-- applies it. This is checked on every rebuild, not only while a page is
-- active, because no page is active right after login.
local function ArmRefreshIfMismatch()
    local wanted = tonumber(header:GetAttribute("state-formpage"))
    if wanted and wanted <= 0 then wanted = nil end
    if wanted ~= header:GetAttribute("fp-page") then
        -- The next game-driven evaluation applies or restores the page, even
        -- if the current form never changes or paging is disabled.
        header:SetAttribute("state-formpage", "refresh")
    end
end

local function Rebuild()
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    local force = forceNext
    forceNext = false

    local count = ns.Attach.Attach(force)
    local condition = ns.Conditions.Build(ns.Settings.Get())
    local key = condition .. "#" .. count .. "#" .. ns.Attach.Info().name
    if key == lastKey then
        return
    end
    lastKey = key

    RegisterDriver(condition)
    ArmRefreshIfMismatch()
end

-- Rebuilds now (used after a settings change, login, or when combat ends).
-- force makes the next attach look at the bar afresh.
function R.Now(force)
    if force then forceNext = true end
    Rebuild()
end

-- Rebuilds a moment later. Bursts of spell and form events collapse into one.
function R.Request(force)
    if force then forceNext = true end
    if queued then return end
    if C_Timer and C_Timer.After then
        queued = true
        C_Timer.After(C.REBUILD_DEBOUNCE, function()
            queued = false
            Rebuild()
        end)
    else
        Rebuild()
    end
end

-- Runs a rebuild that was deferred by combat, if there is one.
function R.FlushPending()
    if pending then Rebuild() end
end

-- True while a rebuild is waiting for combat to end.
function R.IsPending()
    return pending
end

-- The key of the condition last applied ("condition#count#bar"), or nil.
function R.LastKey()
    return lastKey
end
