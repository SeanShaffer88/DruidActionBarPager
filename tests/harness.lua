-- Offline WoW Forever (16001) API simulation for DruidActionBarPager logic tests.
-- Enforces Blizzard RestrictedExecution.lua closure rules and restricted globals,
-- runs SecureHandlerWrapScript pre/post hooks and SecureHandlerExecute, models
-- Forever's MainActionBar + per-button container hierarchy, and tracks combat
-- lockdown violations on protected APIs.
local H = {}
local log = {}
H.log = log
local function say(...) log[#log + 1] = table.concat({ ... }, " ") end

wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m)
    say("CHAT:", (m:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
end }

local timers = {}
H.timers = timers
C_Timer = {
    After = function(delay, fn)
        timers[#timers + 1] = { delay = tonumber(delay) or 0, fn = fn }
    end,
}
function H.runTimers(maxDelay)
    local ran = 0
    local remaining = {}
    local snapshot = timers
    timers = remaining
    H.timers = timers
    local toRun = {}
    for _, item in ipairs(snapshot) do
        if maxDelay == nil or item.delay <= maxDelay then
            toRun[#toRun + 1] = item.fn
        else
            remaining[#remaining + 1] = item
        end
    end
    for _, fn in ipairs(toRun) do
        ran = ran + 1
        fn()
    end
    return ran
end
function H.pendingTimers() return #timers end

local currentForm = 0
local specialState = {
    overridebar = false,
    vehicleui = false,
    possessbar = false,
    shapeshift = false,
    bonusbar = 0,
}
local forms = {}
local spellNames = {}
local requestedSpells = {}
H.requestedSpells = requestedSpells
local wrapCalls = {}
H.wrapCalls = wrapCalls
local wrapHandlers = {}
local allFrames = {}
H.allFrames = allFrames
local enumerateCount = 0
function H.enumerateCount() return enumerateCount end
function H.resetEnumerateCount() enumerateCount = 0 end

local inCombat = false
local inRestrictedDepth = 0
local strictCombat = false
local cvars = { actionbuttonusekeydown = false }

local function checkProtectedCall(apiName)
    if strictCombat and inCombat and inRestrictedDepth == 0 then
        error("ADDON_ACTION_BLOCKED: " .. apiName .. " called during combat lockdown", 2)
    end
end

function H.setCombat(state, strict)
    inCombat = not not state
    if strict ~= nil then strictCombat = not not strict end
end
function H.setCVar(name, value)
    cvars[tostring(name):lower()] = not not value
end
function H.setSpecialState(key, value)
    specialState[key] = value
end

-- Standard Lua 5.1 loader for normal addon files.
local function compile(code, chunkname, env)
    local fn, err = loadstring(code, chunkname)
    assert(fn, err)
    if env then setfenv(fn, env) end
    return fn
end

-- Subset of Blizzard_RestrictedAddOnEnvironment's RESTRICTED_FUNCTIONS_SCOPE.
local RESTRICTED_BASE = {
    math = math,
    string = string,
    select = select,
    tonumber = tonumber,
    tostring = tostring,
    type = type,
    rawtype = type,
    format = string.format,
    gmatch = string.gmatch,
    gsub = string.gsub,
    strbyte = string.byte,
    strchar = string.char,
    strfind = string.find,
    strlen = string.len,
    strlower = string.lower,
    strmatch = string.match,
    strrep = string.rep,
    strrev = string.reverse,
    strsub = string.sub,
    strupper = string.upper,
    abs = math.abs,
    ceil = math.ceil,
    floor = math.floor,
    max = math.max,
    min = math.min,
    GetShapeshiftForm = function() return currentForm end,
    HasAction = function(slot) return H.hasAction(slot) end,
}

local actionSlots = {}
H.actionSlots = actionSlots
function H.setHasAction(slot, present)
    actionSlots[slot] = present and true or nil
end
function H.hasAction(slot)
    return slot and actionSlots[slot] == true or false
end

-- Mirrors Blizzard BuildRestrictedClosure (RestrictedExecution.lua:49-96).
function H.buildRestrictedClosure(body, env, signature, chunkname)
    body = tostring(body or "")
    signature = tostring(signature or "self,...")
    if body:match("function") then
        return nil, "The function keyword is not permitted"
    end
    if body:match("[{}]") then
        return nil, "Direct table creation is not permitted"
    end
    if signature:match("function") then
        return nil, "The function keyword is not permitted"
    end
    if not signature:match("^[a-zA-Z_0-9, ]*[.]*$") then
        return nil, "Signature contains invalid characters (" .. signature .. ")"
    end
    local def, err = loadstring("return function (" .. signature .. ") " .. body .. "\nend",
        chunkname or "=restricted")
    if not def then return nil, err end
    setfenv(def, {})
    local fn = def()
    if type(fn) ~= "function" then return nil, "Invalid body" end
    setfenv(fn, env)
    return fn
end

local function makeRestrictedEnv(controlHandle)
    local working = {}
    return setmetatable({}, {
        __index = function(_, k)
            local v = RESTRICTED_BASE[k]
            if v ~= nil then return v end
            v = working[k]
            if v ~= nil then return v end
            if k == "control" then return controlHandle end
            return nil
        end,
        __newindex = function(_, k, v) working[k] = v end,
        __metatable = false,
    })
end

local function runRestricted(frame, signature, controlHandle, code, ...)
    local env = makeRestrictedEnv(controlHandle)
    local fn, err = H.buildRestrictedClosure(code, env, signature, "=snippet")
    if not fn then error(err, 2) end
    inRestrictedDepth = inRestrictedDepth + 1
    local results = { pcall(fn, frame, ...) }
    inRestrictedDepth = inRestrictedDepth - 1
    if not results[1] then error(results[2], 2) end
    return unpack(results, 2)
end

local activeWrapGuard = {}

local methods = {
    GetAttribute = function(self, k)
        if type(k) == "string" and k:sub(1, 9) == "frameref-" then
            return self.refs[k:sub(10)]
        end
        return self.attrs[k]
    end,
    SetAttribute = function(self, k, v)
        if self.prot then checkProtectedCall("SetAttribute(" .. tostring(k) .. ")") end
        if type(k) == "string" and k:sub(1, 9) == "frameref-" then
            self.refs[k:sub(10)] = v
            self.attrs[k] = v
            return
        end
        self.attrs[k] = v
        if type(k) == "string" and k:sub(1, 1) ~= "_" then
            local wraps = wrapHandlers[self]
            if wraps then
                for _, w in ipairs(wraps) do
                    if not activeWrapGuard[w] then
                        activeWrapGuard[w] = true
                        local allow, msg
                        if w.preBody then
                            allow, msg = runRestricted(self, "self,name,value", w.header, w.preBody, k, v)
                        end
                        if allow ~= false and type(k) == "string" and k:sub(1, 6) == "state-" then
                            local code = self.attrs["_onstate-" .. k:sub(7)]
                            if code then
                                runRestricted(self, "self,stateid,newstate", self, code, k:sub(7), v)
                            end
                        end
                        if msg ~= nil and w.postBody then
                            runRestricted(self, "self,message,name,value", w.header, w.postBody, msg, k, v)
                        end
                        activeWrapGuard[w] = nil
                        return
                    end
                end
            end
            if k:sub(1, 6) == "state-" then
                local code = self.attrs["_onstate-" .. k:sub(7)]
                if code then
                    runRestricted(self, "self,stateid,newstate", self, code, k:sub(7), v)
                end
            end
        end
    end,
    RunAttribute = function(self, name, ...)
        assert(type(name) == "string", "Invalid snippet attribute")
        local code = self.attrs[name]
        assert(type(code) == "string", "Invalid snippet body: " .. tostring(name))
        return runRestricted(self, "self,...", self, code, ...)
    end,
    SetFrameRef = function(self, label, fr)
        checkProtectedCall("SetFrameRef")
        assert(fr ~= nil, "Invalid referenced frame")
        self.refs[label] = fr
        self.attrs["frameref-" .. label] = fr
    end,
    GetFrameRef = function(self, label) return self.refs[label] end,
    RegisterEvent = function(self, ev) self.events[ev] = true end,
    UnregisterEvent = function(self, ev) self.events[ev] = nil end,
    UnregisterAllEvents = function(self) wipe(self.events) end,
    SetScript = function(self, script, fn)
        if script == "OnEvent" then self.onevent = fn end
    end,
    IsVisible = function(self) return self.visible ~= false end,
    IsShown = function(self) return self.visible ~= false end,
    IsProtected = function(self) return self.prot, self.prot end,
    GetID = function(self) return self.id or 0 end,
    GetName = function(self) return self.name end,
    GetParent = function(self) return self.parent end,
    CallMethod = function(self, methodName, ...)
        local fn = self[methodName]
        if type(fn) == "function" then
            inRestrictedDepth = inRestrictedDepth - 1
            pcall(fn, self, ...)
            inRestrictedDepth = inRestrictedDepth + 1
        end
    end,
    SetSize = function(self, w, h) self.size = { w, h } end,
    SetAlpha = function(self, a) self.alpha = a end,
    SetPoint = function(self, point, rel, relPoint, x, y)
        self.point = { point, rel, relPoint, x, y }
    end,
    EnableMouse = function(self, enabled) self.mouseEnabled = not not enabled end,
    RegisterForClicks = function(self, ...)
        checkProtectedCall("RegisterForClicks")
        self.clicks = { ... }
    end,
    Show = function(self) self.visible = true end,
    Hide = function(self) self.visible = false end,
}

local function newFrame(name, protected, frameType)
    local f = {
        attrs = {},
        refs = {},
        events = {},
        name = name,
        prot = protected or false,
        mouseEnabled = frameType == "Button",
        clicks = frameType == "Button" and { "LeftButtonUp" } or nil,
    }
    for k, v in pairs(methods) do f[k] = v end
    allFrames[#allFrames + 1] = f
    return f
end

-- Mirrors SecureTemplates.lua SecureActionButtonMixin:CalculateAction.
function H.calculateBlizzardAction(button)
    local page = button.attrs.actionpage
    if page == nil and button.attrs["useparent-actionpage"] then
        local owner = button.bar or button.parent
        page = owner and owner.attrs.actionpage
    end
    page = tonumber(page) or 1
    local id = button:GetID()
    if id > 0 then
        return id + (page - 1) * 12
    end
    return tonumber(button.attrs.action) or 1
end

function H.makeBlizzardBar(barName, buttonPrefix, defaultPage, visible, barProtected)
    local bar = newFrame(barName, barProtected ~= false)
    bar.visible = visible ~= false
    bar.attrs.actionpage = defaultPage
    local list = {}
    for i = 1, 12 do
        local container = newFrame(barName .. "ButtonContainer" .. i, false)
        container.parent = bar
        container.visible = visible ~= false
        local b = newFrame(buttonPrefix .. i, true, "CheckButton")
        b.id = i
        b.parent = container
        b.bar = bar
        b.visible = visible ~= false
        b.attrs["useparent-actionpage"] = true
        b.action = i + (defaultPage - 1) * 12
        _G[b.name] = b
        list[i] = b
    end
    return bar, list
end

UIParent = newFrame("UIParent", false)
CreateFrame = function(frameType, name, parent, template)
    local f = newFrame(name, template and template:find("Secure") ~= nil, frameType)
    f.parent = parent
    if name then _G[name] = f end
    return f
end

-- WoW Forever Blizzard main bar: MainActionBar + per-button containers.
local mainBar, buttons = H.makeBlizzardBar("MainActionBar", "ActionButton", 1, true, true)
H.buttons = buttons
H.mainBar = mainBar

GetNumShapeshiftForms = function() return #forms end
GetShapeshiftFormInfo = function(i)
    local f = forms[i]
    if not f then return nil end
    if f.legacy then
        return f.icon, f.name, (i == currentForm), true
    end
    return f.icon, (i == currentForm), true, f.spellID
end
GetShapeshiftForm = function() return currentForm end
C_Spell = {
    GetSpellName = function(id) return spellNames[id] end,
    RequestLoadSpellData = function(id) requestedSpells[#requestedSpells + 1] = id end,
}
C_ActionBar = {
    HasBonusActionBar = function() return (specialState.bonusbar or 0) > 0 end,
    GetBonusBarIndex = function()
        local b = specialState.bonusbar or 0
        if b > 0 then return b + 6 end
        return 0
    end,
}
GetCVarBool = function(name) return cvars[tostring(name):lower()] == true end
UnitClass = function() return "Druid", "DRUID" end
InCombatLockdown = function() return inCombat end
SlashCmdList = {}

SecureHandlerWrapScript = function(frame, script, hdr, preBody, postBody)
    checkProtectedCall("SecureHandlerWrapScript")
    assert(frame and frame:IsProtected(), "Cannot wrap script on unprotected frame")
    -- Validate both bodies through BuildRestrictedClosure at registration time.
    if preBody then
        local fn, err = H.buildRestrictedClosure(preBody, {}, "self,name,value", "=wrap_pre")
        assert(fn, err)
    end
    if postBody then
        local fn, err = H.buildRestrictedClosure(postBody, {}, "self,message,name,value", "=wrap_post")
        assert(fn, err)
    end
    wrapCalls[#wrapCalls + 1] = frame.name or "<unnamed bar>"
    if script == "OnAttributeChanged" then
        wrapHandlers[frame] = wrapHandlers[frame] or {}
        wrapHandlers[frame][#wrapHandlers[frame] + 1] = {
            header = hdr, preBody = preBody, postBody = postBody,
        }
    end
end

SecureHandlerExecute = function(frame, body)
    checkProtectedCall("SecureHandlerExecute")
    assert(frame and frame:IsProtected(), "Header frame must be explicitly protected")
    assert(type(body) == "string", "Invalid body")
    return runRestricted(frame, "self", frame, body)
end

local bindings, bindingOverrides = {}, {}
local bindingRefreshCount = 0
H.bindingOverrides = bindingOverrides
function H.bindingRefreshCount() return bindingRefreshCount end
function H.setBindingKey(action, ...)
    bindings[action] = { ... }
end
GetBindingKey = function(action)
    local keys = bindings[action]
    if not keys then return end
    return unpack(keys)
end
ClearOverrideBindings = function(owner)
    checkProtectedCall("ClearOverrideBindings")
    bindingRefreshCount = bindingRefreshCount + 1
    for i = #bindingOverrides, 1, -1 do
        if bindingOverrides[i].owner == owner then table.remove(bindingOverrides, i) end
    end
end
SetOverrideBindingClick = function(owner, priority, key, buttonName, mouseButton)
    checkProtectedCall("SetOverrideBindingClick")
    bindingOverrides[#bindingOverrides + 1] = {
        owner = owner, priority = priority, key = key,
        buttonName = buttonName, mouseButton = mouseButton,
    }
end

-- Evaluates WoW macro conditionals used by DruidActionBarPager.
local function bracketMatches(bracket)
    for token in bracket:gmatch("[^,]+") do
        local t = token:gsub("^%s+", ""):gsub("%s+$", "")
        local ok = false
        if t == "overridebar" then ok = specialState.overridebar
        elseif t == "vehicleui" then ok = specialState.vehicleui
        elseif t == "possessbar" then ok = specialState.possessbar
        elseif t == "shapeshift" then ok = specialState.shapeshift
        elseif t:match("^bonusbar:%d+$") then
            ok = tonumber(t:match("^bonusbar:(%d+)$")) == specialState.bonusbar
        elseif t:match("^form:%d+$") then
            ok = tonumber(t:match("^form:(%d+)$")) == currentForm
        end
        if not ok then return false end
    end
    return true
end

local function evalCond(cond)
    for clause in (tostring(cond or "") .. ";"):gmatch("([^;]*);") do
        local c = clause:gsub("^%s+", ""):gsub("%s+$", "")
        if c ~= "" then
            local brackets, result = c:match("^(%[.+%])%s*(.-)$")
            if brackets then
                for group in brackets:gmatch("%[([^%]]*)%]") do
                    if bracketMatches(group) then return result end
                end
            else
                return c
            end
        end
    end
    return nil
end
SecureCmdOptionParse = evalCond

local function coerceStateValue(raw)
    if raw == "nil" then return nil end
    return tonumber(raw) or raw
end

local header
function H.RegisterStateDriver(frame, label, cond)
    checkProtectedCall("RegisterStateDriver")
    frame.attrs["_driver-" .. label] = cond
    local prev = frame.attrs["state-" .. label]
    local state = coerceStateValue(evalCond(cond))
    if state ~= prev then
        frame:SetAttribute("state-" .. label, state)
    end
end
RegisterStateDriver = H.RegisterStateDriver
UnregisterStateDriver = function(f, label)
    checkProtectedCall("UnregisterStateDriver")
    f.attrs["_driver-" .. label] = nil
end

-- Simulates a game-driven state-driver tick (in-engine secure evaluation).
function H.gameEvaluate()
    local cond = header and header.attrs["_driver-formpage"]
    if not cond then return end
    local prev = header.attrs["state-formpage"]
    local state = coerceStateValue(evalCond(cond))
    if state ~= prev then
        inRestrictedDepth = inRestrictedDepth + 1
        header:SetAttribute("state-formpage", state)
        inRestrictedDepth = inRestrictedDepth - 1
    end
end

-- Simulates a secure click on a SecureHandlerClickTemplate button.
function H.clickSecure(frame, isDown)
    local code = frame and frame.attrs["_onclick"]
    if not code then return end
    local down = isDown and true or false
    return runRestricted(frame, "self,button,down", frame, code, "LeftButton", down)
end

-- Simulates a bar frame changing a secure attribute in combat (e.g. its own driver).
function H.setBarAttrSecure(frame, k, v)
    inRestrictedDepth = inRestrictedDepth + 1
    frame:SetAttribute(k, v)
    inRestrictedDepth = inRestrictedDepth - 1
end

function H.setForm(i) currentForm = i end
function H.setForms(list, names)
    forms = list
    spellNames = names or {}
end
function H.setSpellName(id, name) spellNames[id] = name end

-- Loads addon files without firing events (for pre-ADDON_LOADED tests).
function H.loadRaw(files, db)
    DruidActionBarPagerDB = db
    local ns = {}
    for _, name in ipairs(files) do
        local path = ADDON_DIR .. "/" .. name
        local fh = assert(io.open(path, "rb"))
        local src = fh:read("*a")
        fh:close()
        compile(src, "@" .. name)("DruidActionBarPager", ns)
    end
    header = _G.DruidActionBarPagerHeader
    local evFrame
    for _, f in ipairs(allFrames) do
        if f.onevent and f ~= header then evFrame = f end
    end
    H.evFrame = evFrame
    H.ns = ns
    return ns
end

-- Loads addon files and runs the normal login event sequence.
function H.load(files, db)
    local ns = H.loadRaw(files, db)
    H.fire("ADDON_LOADED", "DruidActionBarPager")
    H.fire("PLAYER_LOGIN")
    H.fire("PLAYER_ENTERING_WORLD")
    return ns
end

function H.fire(event, arg1, arg2)
    if H.evFrame and H.evFrame.events[event] then
        H.evFrame.onevent(H.evFrame, event, arg1, arg2)
    end
end

H.header = function() return header end
H.newFrame = newFrame

-- Frame enumeration for the bar scan (walks every frame created so far).
EnumerateFrames = function(prev)
    if prev == nil then enumerateCount = enumerateCount + 1 end
    local start = 1
    if prev then
        for i, f in ipairs(allFrames) do
            if f == prev then start = i + 1; break end
        end
    end
    return allFrames[start]
end
return H
