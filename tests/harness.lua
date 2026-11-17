-- Minimal WoW API simulation to exercise DruidActionBarPager's logic.
local H = {}
local log = {}
H.log = log
local function say(...) log[#log + 1] = table.concat({ ... }, " ") end

wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m)
    say("CHAT:", (m:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
end }

local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
function H.runTimers()
    local t = timers; timers = {}
    for _, fn in ipairs(t) do fn() end
    return #t
end
function H.pendingTimers() return #timers end

local currentForm = 0
local forms = {}
local spellNames = {}
local wrapCalls = {}
H.wrapCalls = wrapCalls
local allFrames = {}
H.allFrames = allFrames

local function runSnippet(frame, code, extra)
    local env = setmetatable({ self = frame, tonumber = tonumber, pairs = pairs, ipairs = ipairs, type = type }, { __index = _G })
    for k, v in pairs(extra or {}) do env[k] = v end
    local fn, err = load(code, "snippet", "t", env)
    assert(fn, err)
    return fn()
end

local methods = {
    GetAttribute = function(self, k) return self.attrs[k] end,
    SetAttribute = function(self, k, v)
        self.attrs[k] = v
        if type(k) == "string" and k:sub(1, 6) == "state-" then
            local code = self.attrs["_onstate-" .. k:sub(7)]
            if code then runSnippet(self, code, { newstate = v, control = self }) end
        end
    end,
    RunAttribute = function(self, name)
        local code = self.attrs[name]
        if code then return runSnippet(self, code, {}) end
    end,
    SetFrameRef = function(self, label, fr) self.refs[label] = fr end,
    GetFrameRef = function(self, label) return self.refs[label] end,
    RegisterEvent = function() end,
    UnregisterEvent = function() end,
    UnregisterAllEvents = function() end,
    SetScript = function(self, _, fn) self.onevent = fn end,
    IsVisible = function(self) return self.visible ~= false end,
    IsShown = function(self) return self.visible ~= false end,
    IsProtected = function(self) return self.prot end,
    GetID = function(self) return self.id or 0 end,
    GetName = function(self) return self.name end,
    GetParent = function(self) return self.parent end,
    CallMethod = function() end,
}

local function newFrame(name, protected)
    local f = { attrs = {}, refs = {}, name = name, prot = protected or false }
    for k, v in pairs(methods) do f[k] = v end
    allFrames[#allFrames + 1] = f
    return f
end

UIParent = newFrame("UIParent", false)
CreateFrame = function(_, name, _, template)
    local f = newFrame(name, template and template:find("Secure") ~= nil)
    if name then _G[name] = f end
    return f
end

-- Blizzard-style main bar: protected MainMenuBar with a paging snippet, 12 buttons.
local mainBar = newFrame("MainMenuBar", true)
mainBar.attrs["_onstate-page"] = "-- Blizzard paging (not run in this harness)"
local buttons = {}
for i = 1, 12 do
    local b = newFrame("ActionButton" .. i, true)
    b.id = i; b.parent = mainBar; b.attrs.action = i
    _G["ActionButton" .. i] = b
    buttons[i] = b
end
H.buttons = buttons
H.mainBar = mainBar

GetNumShapeshiftForms = function() return #forms end
GetShapeshiftFormInfo = function(i)
    local f = forms[i]
    if not f then return nil end
    return f.icon, (i == currentForm), true, f.spellID
end
GetShapeshiftForm = function() return currentForm end
C_Spell = {
    GetSpellName = function(id) return spellNames[id] end,
    RequestLoadSpellData = function() end,
}
UnitClass = function() return "Druid", "DRUID" end
InCombatLockdown = function() return false end
SlashCmdList = {}
EnumerateFrames = nil
SecureCmdOptionParse = nil
UnregisterStateDriver = function(f, label) f.attrs["_driver-" .. label] = nil end
SecureHandlerWrapScript = function(frame) wrapCalls[#wrapCalls + 1] = frame.name or "<unnamed bar>" end

-- Real state-driver semantics: evaluate the condition; run the handler when the state changes.
local function evalCond(cond)
    local state = "0"
    for clause in (cond .. ";"):gmatch("([^;]*);") do
        local n, p = clause:match("^%[form:(%d+)%](%d+)$")
        if n then
            if tonumber(n) == currentForm then state = p; break end
        elseif clause:match("^%d+$") then
            state = clause; break
        end
    end
    return state
end

local header
function H.RegisterStateDriver(frame, label, cond)
    frame.attrs["_driver-" .. label] = cond
    local prev = frame.attrs["state-" .. label]
    local state = evalCond(cond)
    frame.attrs["state-" .. label] = state
    local code = frame.attrs["_onstate-" .. label]
    if state ~= prev and code then runSnippet(frame, code, { newstate = state, control = frame }) end
end
RegisterStateDriver = H.RegisterStateDriver
UnregisterStateDriver = function(f, label) f.attrs["_driver-" .. label] = nil end

-- A game-driven evaluation (what happens on a shapeshift event).
function H.gameEvaluate()
    local cond = header.attrs["_driver-formpage"]
    if not cond then return end
    local prev = header.attrs["state-formpage"]
    local state = evalCond(cond)
    if state ~= prev then
        header.attrs["state-formpage"] = state
        runSnippet(header, header.attrs["_onstate-formpage"], { newstate = state, control = header })
    end
end

function H.setForm(i) currentForm = i end
function H.setForms(list, names)
    forms = list
    spellNames = names or {}
end

-- Load the addon with the given saved settings and fire PLAYER_LOGIN etc. via its OnEvent.
function H.load(src, db)
    DruidActionBarPagerDB = db
    local chunk = assert(load(src, "@DruidActionBarPager.lua", "t"))
    chunk("DruidActionBarPager")
    header = _G.DruidActionBarPagerHeader
    -- Fire the events the addon registered for, in login order.
    local evFrame
    for _, f in ipairs(allFrames) do
        if f.onevent and f ~= header then evFrame = f end
    end
    H.evFrame = evFrame
    H.fire("ADDON_LOADED", "DruidActionBarPager")
    H.fire("PLAYER_LOGIN")
    H.fire("PLAYER_ENTERING_WORLD")
end

function H.fire(event, arg1, arg2)
    H.evFrame.onevent(H.evFrame, event, arg1, arg2)
end

H.header = function() return header end
H.newFrame = newFrame
H.bindMethods = nil

-- Frame enumeration for the bar scan (walks every frame created so far).
EnumerateFrames = function(prev)
    local start = 1
    if prev then
        for i, f in ipairs(allFrames) do
            if f == prev then start = i + 1; break end
        end
    end
    return allFrames[start]
end
return H
