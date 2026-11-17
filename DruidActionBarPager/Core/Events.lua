-- Turns game events into settings loads and rebuild requests. Events arrive on
-- the events frame from UI/Frames.lua; Install() connects them.
local _, ns = ...
local C = ns.Constants

local E = {}
ns.Events = E

-- The form list signature at the last form event. A shift doesn't change it.
local lastFormSignature

local function OnAddonLoaded(self, name)
    if ns.Settings.Load(name) then
        self:UnregisterEvent("ADDON_LOADED")
    end
end

local function OnPlayerLogin(self)
    local _, class = UnitClass("player")
    if class ~= "DRUID" then
        -- Nothing to do for other classes; stay completely idle.
        self:UnregisterAllEvents()
        return
    end
    self:UnregisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
    self:RegisterEvent("SPELLS_CHANGED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("SPELL_DATA_LOAD_RESULT")
    -- A shapeshift event on login must not trigger a needless first rebuild.
    lastFormSignature = ns.Forms.Signature()
    ns.Rebuild.Now(true)
end

local function OnRegenEnabled()
    ns.Rebuild.FlushPending()
end

local function OnSpellDataLoaded(_, spellID, success)
    if ns.Forms.TakePendingSpell(spellID) and success then
        ns.Rebuild.Request()
    end
end

local function OnEnteringWorld()
    -- Bars may have changed across the loading screen, and some bar addons
    -- finish building theirs a moment later.
    ns.Rebuild.Request(true)
    if C_Timer and C_Timer.After then
        C_Timer.After(C.LATE_REBUILD_DELAY, function()
            -- Only retry when the initial scan fell back; a found bar needs no
            -- second full-screen scan and driver reset.
            if not ns.Attach.Info().found then ns.Rebuild.Request(true) end
        end)
    end
end

-- UPDATE_SHAPESHIFT_FORMS and SPELLS_CHANGED also fire on every shift. A shift
-- doesn't change the form list, so skip the rebuild (and its debounce) unless
-- the list did. The game's state driver switches the page on the shift itself.
local function OnFormListEvent()
    local signature = ns.Forms.Signature()
    if signature == lastFormSignature and not ns.Rebuild.IsPending() then
        return
    end
    lastFormSignature = signature
    ns.Rebuild.Request()
end

local handlers = {
    ADDON_LOADED         = OnAddonLoaded,
    PLAYER_LOGIN         = OnPlayerLogin,
    PLAYER_REGEN_ENABLED = OnRegenEnabled,
    SPELL_DATA_LOAD_RESULT = OnSpellDataLoaded,
    PLAYER_ENTERING_WORLD = OnEnteringWorld,
}

local function OnEvent(self, event, arg1, arg2)
    local handler = handlers[event]
    if handler then
        handler(self, arg1, arg2)
    else
        OnFormListEvent()
    end
end

-- Connects the handler to the events frame and listens for the first two
-- events; the rest are registered at login for druids.
function E.Install()
    local frame = ns.Frames.events
    frame:SetScript("OnEvent", OnEvent)
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PLAYER_LOGIN")
end
