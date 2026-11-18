-- Turns game events into settings loads and rebuild requests.
local _, ns = ...
local C, U = ns.Constants, ns.Util

local E = {}
ns.Events = E
local lastFormSignature
local builtOnLogin = false

local function OnAddonLoaded(self, name)
    if ns.Settings.Load(name) then self:UnregisterEvent("ADDON_LOADED") end
end

local function OnPlayerLogin(self)
    if not U.IsDruid() then
        self:UnregisterAllEvents()
        return
    end
    self:UnregisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
    self:RegisterEvent("SPELLS_CHANGED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("SPELL_DATA_LOAD_RESULT")
    self:RegisterEvent("UPDATE_BINDINGS")
    self:RegisterEvent("CVAR_UPDATE")
    lastFormSignature = ns.Forms.Signature()
    ns.Rebuild.Now(true)
    builtOnLogin = true
    ns.KeyBindings.UpdateClickMode()
    ns.KeyBindings.Refresh()
end

local function OnRegenEnabled()
    ns.Rebuild.FlushPending()
    ns.KeyBindings.FlushPending()
end

local function OnFormListEvent()
    local signature = ns.Forms.Signature()
    if signature == lastFormSignature and not ns.Rebuild.IsPending() then return end
    lastFormSignature = signature
    ns.Rebuild.Request()
end

local function OnSpellDataLoaded(_, spellID, success)
    if not ns.Forms.TakePendingSpell(spellID) or not success then return end
    OnFormListEvent()
end

local function OnBindingsUpdated()
    ns.KeyBindings.Refresh()
end

local function OnCVarUpdated(_, cvarName)
    ns.KeyBindings.OnCVarUpdate(cvarName)
end

local function NeedsRescan()
    local info = ns.Attach.Info()
    return ns.BarScan.NeedsMainRescan() or info.missingSelected
end

local function OnEnteringWorld()
    -- Skip a back-to-back rebuild on the initial login when OnPlayerLogin just
    -- attached the live bars; still schedule the delayed check for addons that
    -- finish building or replacing bars a moment after entering the world.
    if builtOnLogin then
        builtOnLogin = false
        if NeedsRescan() then ns.Rebuild.Request(true) end
    else
        ns.Rebuild.Request(true)
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(C.LATE_REBUILD_DELAY, function()
            if NeedsRescan() then ns.Rebuild.Request(true) end
        end)
    end
end

local handlers = {
    ADDON_LOADED = OnAddonLoaded,
    PLAYER_LOGIN = OnPlayerLogin,
    PLAYER_REGEN_ENABLED = OnRegenEnabled,
    SPELL_DATA_LOAD_RESULT = OnSpellDataLoaded,
    PLAYER_ENTERING_WORLD = OnEnteringWorld,
    UPDATE_BINDINGS = OnBindingsUpdated,
    CVAR_UPDATE = OnCVarUpdated,
}

local function OnEvent(self, event, arg1, arg2)
    local handler = handlers[event]
    if handler then handler(self, arg1, arg2) else OnFormListEvent() end
end

function E.Install()
    local frame = ns.Frames.events
    frame:SetScript("OnEvent", OnEvent)
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PLAYER_LOGIN")
end
