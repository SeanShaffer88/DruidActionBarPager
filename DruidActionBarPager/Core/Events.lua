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
    if not ns.Settings.Get() then self:UnregisterAllEvents(); return end
    self:UnregisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
    self:RegisterEvent("SPELLS_CHANGED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("SPELL_DATA_LOAD_RESULT")
    self:RegisterEvent("UPDATE_BINDINGS")
    self:RegisterEvent("CVAR_UPDATE")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    self:RegisterEvent("UPDATE_STEALTH")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
    for _, event in ipairs({ "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "ACTIONBAR_SLOT_CHANGED",
        "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_SPECIALIZATION_CHANGED" }) do
        pcall(self.RegisterEvent, self, event)
    end
    if ns.Profiles then ns.Profiles.OnContext() end
    lastFormSignature = ns.Forms.Signature()
    ns.Rebuild.Now(true)
    builtOnLogin = true
    ns.KeyBindings.UpdateClickMode()
    ns.KeyBindings.Refresh()
end

local function OnRegenEnabled()
    if ns.Profiles then ns.Profiles.OnContext() end
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
    if ns.Profiles then ns.Profiles.OnContext() end
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

local function OnProfileContext(_, unit)
    if unit == nil or type(unit) ~= "string" or unit == "player" then
        if ns.Profiles then ns.Profiles.OnContext() end
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
    UPDATE_SHAPESHIFT_FORM = function() end,
    UPDATE_STEALTH = function() end,
    PLAYER_REGEN_DISABLED = function() end,
    ACTIONBAR_PAGE_CHANGED = function() end,
    ACTIONBAR_SLOT_CHANGED = function() end,
    ACTIVE_TALENT_GROUP_CHANGED = function() if ns.Profiles then ns.Profiles.OnContext() end end,
    PLAYER_SPECIALIZATION_CHANGED = OnProfileContext,
    PLAYER_DEAD = function() end,
    PLAYER_ALIVE = OnProfileContext,
    PLAYER_UNGHOST = OnProfileContext,
}

local function OnEvent(self, event, arg1, arg2)
    local handler = handlers[event]
    if handler then handler(self, arg1, arg2) else OnFormListEvent() end
    if ns.Workflow and ns.Workflow.OnEvent then ns.Workflow.OnEvent(event, arg1, arg2) end
    if ns.MappingPanel then ns.MappingPanel.Refresh() end
end

function E.Install()
    local frame = ns.Frames.events
    frame:SetScript("OnEvent", OnEvent)
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PLAYER_LOGIN")
end
