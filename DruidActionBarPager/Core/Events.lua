-- Turns game events into settings loads and rebuild requests.
local _, ns = ...
local C = ns.Constants

local E = {}
ns.Events = E
local lastFormSignature

local function OnAddonLoaded(self, name)
    if ns.Settings.Load(name) then self:UnregisterEvent("ADDON_LOADED") end
end

local function OnPlayerLogin(self)
    local _, class = UnitClass("player")
    if class ~= "DRUID" then
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
    lastFormSignature = ns.Forms.Signature()
    ns.Rebuild.Now(true)
    ns.KeyBindings.Refresh()
end

local function OnRegenEnabled()
    ns.Rebuild.FlushPending()
    ns.KeyBindings.Refresh()
end

local function OnSpellDataLoaded(_, spellID, success)
    if ns.Forms.TakePendingSpell(spellID) and success then ns.Rebuild.Request() end
end

local function OnBindingsUpdated()
    ns.KeyBindings.Refresh()
end

local function OnEnteringWorld()
    ns.Rebuild.Request(true)
    if C_Timer and C_Timer.After then
        C_Timer.After(C.LATE_REBUILD_DELAY, function()
            local info = ns.Attach.Info()
            if not info.found or info.missingSelected then ns.Rebuild.Request(true) end
        end)
    end
end

local function OnFormListEvent()
    local signature = ns.Forms.Signature()
    if signature == lastFormSignature and not ns.Rebuild.IsPending() then return end
    lastFormSignature = signature
    ns.Rebuild.Request()
end

local handlers = {
    ADDON_LOADED = OnAddonLoaded,
    PLAYER_LOGIN = OnPlayerLogin,
    PLAYER_REGEN_ENABLED = OnRegenEnabled,
    SPELL_DATA_LOAD_RESULT = OnSpellDataLoaded,
    PLAYER_ENTERING_WORLD = OnEnteringWorld,
    UPDATE_BINDINGS = OnBindingsUpdated,
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
