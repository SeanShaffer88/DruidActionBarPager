--[[
    DruidActionBarPager - automatic action bar paging for druid forms
    Copyright (C) 2026 Malikor

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

    HOW IT WORKS
    Shapeshifting happens in combat, and Blizzard blocks addons from
    changing the action bar from normal Lua while in combat. So DruidActionBarPager
    uses a secure state driver: the game itself evaluates "[form:N]" macro
    conditions and runs a small secure snippet that repoints the 12 buttons
    of whichever main bar is on screen -- Blizzard's, or a bar addon's
    (EllesmereUI, Bartender4, ElvUI, Dominos, or any other it can find).
    Only finding the bar and (re)building the driver needs to happen out of
    combat, which is done on login and whenever you learn a new form.
]]

local ADDON_NAME = ...
local PREFIX = "|cffff7d0aDruidActionBarPager|r: "

-- Localized globals (Lua 5.1: upvalue access beats a _G hash lookup).
local _G = _G
local pairs, ipairs, type, pcall = pairs, ipairs, type, pcall
local tonumber, tostring = tonumber, tostring
local concat, sort, wipe = table.concat, table.sort, wipe
local math_floor = math.floor
local InCombatLockdown = InCombatLockdown
local EnumerateFrames = EnumerateFrames
local C_Spell, C_Timer = C_Spell, C_Timer

-- The global GetSpellInfo was removed in the Mainline API this client is
-- built on; C_Spell.GetSpellName replaces it. Keep the global only as a
-- fallback for clients that still have it.
local GetSpellName
if C_Spell and C_Spell.GetSpellName then
    GetSpellName = C_Spell.GetSpellName
elseif GetSpellInfo then
    GetSpellName = function(id) return (GetSpellInfo(id)) end
else
    GetSpellName = function() return nil end
end

-- Defaults: page 0 means "don't switch for this form".
local DEFAULT_PAGES = {
    bear    = 2,
    cat     = 3,
    travel  = 0, -- utility form: keep the normal bar
    aquatic = 0, -- utility form: keep the normal bar
    moonkin = 4,
    tree    = 4,
}

local FORM_ORDER = { "bear", "cat", "travel", "aquatic", "moonkin", "tree" }

local FORM_LABELS = {
    bear    = "Bear / Dire Bear Form",
    cat     = "Cat Form",
    travel  = "Travel Form",
    aquatic = "Aquatic Form",
    moonkin = "Moonkin Form",
    tree    = "Tree of Life",
}

-- Known spell IDs (classic-era values; name/icon matching below covers
-- anything the Forever beta numbers differently).
local FORM_SPELLS = {
    [5487]  = "bear",    [9634]  = "bear",
    [768]   = "cat",
    [783]   = "travel",
    [1066]  = "aquatic",
    [24858] = "moonkin",
    [33891] = "tree",
}

local NAME_MATCH = {
    { "bear",         "bear" },
    { "cat",          "cat" },
    { "travel",       "travel" },
    { "aquatic",      "aquatic" },
    { "moonkin",      "moonkin" },
    { "tree of life", "tree" },
}

local ICON_MATCH = {
    { "bearform",       "bear" },
    { "catform",        "cat" },
    { "travelform",     "travel" },
    { "aquaticform",    "aquatic" },
    { "forceofnature",  "moonkin" },
    { "treeoflife",     "tree" },
}

local DB_VERSION = 3

local db
local pendingRebuild = false
local lastCondition

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
end

---------------------------------------------------------------------------
-- Form detection
---------------------------------------------------------------------------

-- GetShapeshiftFormInfo has returned different shapes across client versions:
--   modern:  icon, active, castable, spellID
--   1.12:    icon, name, active, castable
local pendingSpellData = {} -- spellID -> true while a load is in flight

local function GetFormDetails(index)
    local a, b, _, d = GetShapeshiftFormInfo(index)
    local icon, name, spellID = a, nil, nil
    if type(b) == "string" then
        name = b
    else
        spellID = d
        if spellID then
            name = GetSpellName(spellID)
            -- Spell data can arrive after login; ask for it and rebuild on
            -- SPELL_DATA_LOAD_RESULT. Only needed when the ID isn't known.
            if not name and C_Spell and C_Spell.RequestLoadSpellData
                and not pendingSpellData[spellID] then
                pendingSpellData[spellID] = true
                C_Spell.RequestLoadSpellData(spellID)
            end
        end
    end
    return spellID, name, icon
end

local function ClassifyForm(index)
    local spellID, name, icon = GetFormDetails(index)

    if spellID and FORM_SPELLS[spellID] then
        return FORM_SPELLS[spellID]
    end

    if name then
        local lname = name:lower()
        for _, pair in ipairs(NAME_MATCH) do
            if lname:find(pair[1], 1, true) then
                return pair[2]
            end
        end
    end

    if type(icon) == "string" then
        local licon = icon:lower():gsub("[^%a]", "")
        for _, pair in ipairs(ICON_MATCH) do
            if licon:find(pair[1], 1, true) then
                return pair[2]
            end
        end
    end

    return nil
end

-- A cheap summary of the form list (count, spell IDs, names, keys). It only
-- changes when forms are learned or the spell data they depend on loads, so
-- comparing it tells a real form-list change from an ordinary shift.
local lastFormSignature

local function FormSignature()
    local parts = {}
    local count = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
    for i = 1, count do
        local spellID, name = GetFormDetails(i)
        parts[#parts + 1] = tostring(spellID) .. ":" .. tostring(name) .. ":" .. tostring(ClassifyForm(i))
    end
    return count .. "|" .. concat(parts, ",")
end

---------------------------------------------------------------------------
-- Secure paging header
--
-- Shapeshifting happens in combat, where addons can't touch the action bar
-- from ordinary Lua. So the work is done by secure snippets that the game
-- runs itself: a state driver evaluates "[form:N]page" conditions and calls
-- _onstate-formpage, which stores the wanted page and runs "fp-apply".
--
-- TAINT: let the game's driver update and bar page changes apply the page.
-- Skip evaluation during driver registration from addon Lua, which can taint
-- Blizzard code and interfere with protected actions such as Log Out / Exit Game.
---------------------------------------------------------------------------

local header = CreateFrame("Frame", "DruidActionBarPagerHeader", UIParent, "SecureHandlerStateTemplate")

header:SetAttribute("_onstate-formpage", [[
    if newstate == "init" then
        self:SetAttribute("skipnext", true)
        return
    end
    if newstate == "refresh" then
        return
    end
    if self:GetAttribute("skipnext") then
        self:SetAttribute("skipnext", nil)
        return
    end
    local page = tonumber(newstate)
    if not page or page <= 0 then
        page = nil -- caster/utility form: give the bar back
    end
    self:SetAttribute("fp-page", page)
    self:RunAttribute("fp-apply")
]])

-- Points the main bar's 12 buttons at the wanted page, or restores them.
-- Each button has a mode, worked out from how that button finds its slot:
--   page   - Blizzard-style buttons with an ID: override "actionpage"
--   action - buttons holding a fixed slot (EllesmereUI, Dominos, most
--            others): set "action" to the slot on the wanted page
--   lab    - LibActionButton buttons (Bartender4, ElvUI): give the button a
--            private "fp" state holding the slot and switch it to that state
header:SetAttribute("fp-apply", [[
    local page = self:GetAttribute("fp-page")
    if not page and not self:GetAttribute("fp-active") then
        return -- nothing applied, nothing to restore
    end
    local bar = self:GetFrameRef("bar")
    for i = 1, 12 do
        local b = self:GetFrameRef("button" .. i)
        if b then
            local mode = self:GetAttribute("mode" .. i)
            local idx = self:GetAttribute("idx" .. i) or i
            if mode == "page" then
                if b:GetAttribute("actionpage") ~= page then
                    b:SetAttribute("actionpage", page)
                end
            elseif mode == "lab" then
                if page then
                    local slot = (page - 1) * 12 + idx
                    b:SetAttribute("labtype-fp", "action")
                    b:SetAttribute("labaction-fp", slot)
                    b:RunAttribute("UpdateState", "fp")
                    b:CallMethod("ButtonContentsChanged", "fp", "action", slot)
                else
                    local st = (bar and bar:GetAttribute("state")) or self:GetAttribute("labbase") or 0
                    b:RunAttribute("UpdateState", st)
                    b:CallMethod("UpdateAction")
                end
            else
                local slot
                if page then
                    slot = (page - 1) * 12 + idx
                else
                    local offset = bar and tonumber(bar:GetAttribute("actionOffset"))
                    local barpage = bar and tonumber(bar:GetAttribute("actionpage"))
                    if offset then
                        slot = offset + idx
                    elseif barpage then
                        slot = (barpage - 1) * 12 + idx
                    else
                        slot = self:GetAttribute("base" .. i) or idx
                    end
                end
                if b:GetAttribute("action") ~= slot then
                    b:SetAttribute("action", slot)
                end
            end
        end
    end
    if page then
        self:SetAttribute("fp-active", true)
    else
        self:SetAttribute("fp-active", nil)
    end
]])

---------------------------------------------------------------------------
-- Finding the main bar
---------------------------------------------------------------------------

-- Bar addons hide Blizzard's bar and draw their own buttons, so DruidActionBarPager
-- pages whichever main bar is actually on screen. Known addons are checked
-- by name first; anything else is found by scanning for visible buttons
-- showing slots 1-12.
local KNOWN_BARS = {
    { name = "EllesmereUI", prefix = "EABButton" },
    { name = "Bartender4",  prefix = "BT4Button" },
    { name = "ElvUI",       prefix = "ElvUI_Bar1Button" },
    { name = "Dominos",     prefix = "DominosActionButton" },
    { name = "Neuron",      prefix = "NeuronActionBar1_ActionButton" },
    { name = "Blizzard",    prefix = "ActionButton" },
}

local barInfo = { name = "none", count = 0, wrapped = false, modes = "" }
local wrappedBars = {}
local attachedBase, nextAttachedBase = {}, {}

local function IsShown(f)
    local ok, v = pcall(f.IsVisible, f)
    return ok and v
end

local function SlotOf(b)
    -- LibActionButton (Bartender4, ElvUI, ConsolePort, AzeriteUI...) keeps the
    -- slot it is showing in _state_action; its .action field stays 0.
    if b._state_type == "action" then
        local s = tonumber(b._state_action)
        if s and s > 0 then return s end
    end
    local ok, a = pcall(b.GetAttribute, b, "action")
    a = ok and tonumber(a) or nil
    if not a and type(b.action) == "number" and b.action > 0 then a = b.action end
    return a
end

local function ButtonsFromPrefix(prefix)
    local list, count = {}, 0
    for i = 1, 12 do
        local b = _G[prefix .. i]
        if b then list[i] = b; count = count + 1 end
    end
    return list, count
end

-- Last resort: group visible action buttons by name and pick the group
-- that covers the most of slots 1-12.
-- One shared function for the scan (no closure per frame). Forbidden or
-- odd frames can error, so it runs under pcall.
-- Named buttons are grouped by their name without the trailing number (one
-- group per bar). Unnamed buttons -- common in newer bar addons -- are grouped
-- by their parent frame, which is the bar they belong to.
local function ScanCheck(f, active)
    if not f.IsVisible or not f:IsVisible() then return nil end
    if not f.IsProtected or not f:IsProtected() then return nil end
    -- A previously discovered button can currently point outside slots 1-12.
    local slot = (active and attachedBase[f]) or SlotOf(f)
    local name = f:GetName()
    local group
    if name and name ~= "" then
        group = (name:gsub("%d+$", ""))
    else
        group = f:GetParent()
    end
    return slot, group
end

local function ScanForMainBar()
    if not EnumerateFrames then return nil end
    local groups = {}
    local active = header:GetAttribute("fp-active")
    local f, guard = EnumerateFrames(), 0
    while f and guard < 200000 do
        guard = guard + 1
        local ok, slot, group = pcall(ScanCheck, f, active)
        if ok and slot and group and slot >= 1 and slot <= 12 then
            local g = groups[group]
            if not g then
                g = { buttons = {}, count = 0 }
                g.label = type(group) == "string" and group or "unnamed bar"
                groups[group] = g
            end
            if not g.buttons[slot] then
                g.buttons[slot] = f
                g.count = g.count + 1
            end
        end
        f = EnumerateFrames(f)
    end
    local bestLabel, best
    for _, g in pairs(groups) do
        if not best or g.count > best.count then bestLabel, best = g.label, g end
    end
    if best and best.count >= 6 then
        return bestLabel, best.buttons, best.count
    end
    return nil
end

local function FindMainBarUncached()
    for _, known in ipairs(KNOWN_BARS) do
        local list, count = ButtonsFromPrefix(known.prefix)
        if count > 0 and list[1] and IsShown(list[1]) then
            return known.name, list, count
        end
    end
    local name, list, count = ScanForMainBar()
    if name then
        return name .. " (auto-detected)", list, count
    end
    -- Nothing visible (e.g. during a loading screen): fall back to Blizzard.
    local list, count = ButtonsFromPrefix("ActionButton")
    return "Blizzard", list, count
end

-- Detection can mean scanning every frame in the UI, so the result is
-- cached and reused while its first button is still on screen. Rebuilds
-- that may follow a bar change (loading screen, slash command) force a
-- fresh look.
local cachedName, cachedList, cachedCount

local function FindMainBar(force)
    if not force and cachedList and cachedList[1] and IsShown(cachedList[1]) then
        return cachedName, cachedList, cachedCount
    end
    cachedName, cachedList, cachedCount = FindMainBarUncached()
    return cachedName, cachedList, cachedCount
end

local function ModeOf(b)
    local ok, upd = pcall(b.GetAttribute, b, "UpdateState")
    if ok and type(upd) == "string" and type(b.state_types) == "table" then
        return "lab"
    end
    -- Only Blizzard's own action buttons take an actionpage override. Other
    -- addons' buttons often carry an ID too, where the override does nothing,
    -- so those are treated as fixed-slot buttons instead.
    local okn, name = pcall(b.GetName, b)
    if okn and type(name) == "string" and name:find("^ActionButton%d+$") then
        local okid, id = pcall(b.GetID, b)
        if okid and id and id > 0 then
            return "page"
        end
    end
    return "action"
end

-- A bar addon with its own paging (Blizzard's bonus bars, Bartender4, ElvUI,
-- AzeriteUI, Neuron...) may reset its buttons when its state changes -- and
-- druid forms often trigger exactly that. Wrapping the bar makes
-- DruidActionBarPager re-apply its page right after any "state-" change.
local WRAP_PRE = [[
    if name and name:sub(1, 6) == "state-" then
        return nil, "dabp"
    end
]]
local WRAP_POST = [[
    if self == control:GetFrameRef("bar") and control:GetAttribute("fp-page") then
        control:RunAttribute("fp-apply")
    end
]]

local function WrapBar(bar)
    if not bar or wrappedBars[bar] then return wrappedBars[bar] or false end
    -- Any protected bar can be hooked: if it never changes state, the wrap
    -- does nothing. Bars without a protected state can't be hooked at all.
    local okp, protected = pcall(bar.IsProtected, bar)
    if not (okp and protected) then
        return false
    end
    local ok = pcall(SecureHandlerWrapScript, bar, "OnAttributeChanged", header, WRAP_PRE, WRAP_POST)
    wrappedBars[bar] = ok and true or false
    return wrappedBars[bar]
end

-- SetFrameRef errors on nil, so clearing a reference goes through the
-- attribute the reference is stored in.
local function SetRef(label, frame)
    if frame then
        header:SetFrameRef(label, frame)
    else
        header:SetAttribute("frameref-" .. label, nil)
    end
end

-- Run out of combat only. Reads the bar from Lua and records what the
-- secure snippets need on DruidActionBarPager's own header -- it never writes to the
-- bar addon's buttons from here.
local modes, summary = {}, {} -- reused between rebuilds

local function AttachButtons(force)
    local name, list, count = FindMainBar(force)
    wipe(modes)
    wipe(summary)
    wipe(nextAttachedBase)
    local active = header:GetAttribute("fp-active")
    local bar
    for i = 1, 12 do
        local b = list[i]
        SetRef("button" .. i, b)
        if b then
            local mode = ModeOf(b)
            local slot = (active and attachedBase[b]) or SlotOf(b) or i
            nextAttachedBase[b] = slot
            header:SetAttribute("mode" .. i, mode)
            header:SetAttribute("idx" .. i, (slot - 1) % 12 + 1)
            header:SetAttribute("base" .. i, slot)
            modes[mode] = (modes[mode] or 0) + 1
            -- Every mode needs the parent bar: its own paging (Blizzard's
            -- bonus bar, Bartender4, ...) is what overwrites our page, so
            -- WrapBar has to hook it -- page-mode buttons included.
            if not bar then
                local okp, parent = pcall(b.GetParent, b)
                if okp then bar = parent end
            end
        end
    end
    attachedBase, nextAttachedBase = nextAttachedBase, attachedBase
    SetRef("bar", bar)
    for mode, n in pairs(modes) do summary[#summary + 1] = mode .. " x" .. n end
    sort(summary)
    barInfo.name = name
    barInfo.count = count
    barInfo.modes = concat(summary, ", ")
    barInfo.wrapped = WrapBar(bar)
    return count
end

local function BuildCondition()
    if not db.enabled then
        return "0"
    end
    local parts = {}
    local count = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
    for i = 1, count do
        local key = ClassifyForm(i)
        local page = key and db.pages[key]
        if page and page > 0 then
            parts[#parts + 1] = ("[form:%d]%d"):format(i, page)
        end
    end
    parts[#parts + 1] = "0"
    return concat(parts, ";")
end

local forceNext = false

local function Rebuild()
    if InCombatLockdown() then
        pendingRebuild = true
        return
    end
    pendingRebuild = false
    local force = forceNext
    forceNext = false

    local count = AttachButtons(force)
    local condition = BuildCondition()
    local key = condition .. "#" .. count .. "#" .. barInfo.name
    if key == lastCondition then
        return
    end
    lastCondition = key

    UnregisterStateDriver(header, "formpage")
    -- "init" arms the skip so the evaluation RegisterStateDriver performs
    -- right now (from DruidActionBarPager's own, insecure code) never touches a bar.
    header:SetAttribute("state-formpage", "init")
    RegisterStateDriver(header, "formpage", condition)
    -- The registration evaluation was skipped, so the page it wanted may not
    -- be applied yet (e.g. after /reload while shifted). Compare what the
    -- driver wants with what is applied -- not only when a page is already
    -- active, which is never true right after login -- and re-arm the driver
    -- if they differ, so the next game-driven evaluation applies it.
    local wanted = tonumber(header:GetAttribute("state-formpage"))
    if wanted and wanted <= 0 then wanted = nil end
    if wanted ~= header:GetAttribute("fp-page") then
        -- The next game-driven evaluation will apply or restore the page,
        -- even if the current form never changes or paging is disabled.
        header:SetAttribute("state-formpage", "refresh")
    end
end

-- SPELLS_CHANGED and UPDATE_SHAPESHIFT_FORMS can fire in bursts; collapse
-- each burst into one rebuild a moment later.
local rebuildQueued = false
local function RunQueuedRebuild()
    rebuildQueued = false
    Rebuild()
end

local function RequestRebuild(force)
    if force then forceNext = true end
    if rebuildQueued then return end
    if C_Timer and C_Timer.After then
        rebuildQueued = true
        C_Timer.After(0.2, RunQueuedRebuild)
    else
        Rebuild()
    end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function ShowStatus()
    Print(db.enabled and "|cff40ff40enabled|r" or "|cffff4040disabled|r")
    local known = {}
    local count = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
    for i = 1, count do
        local key = ClassifyForm(i)
        if key then known[key] = i end
    end
    for _, key in ipairs(FORM_ORDER) do
        local page = db.pages[key]
        local pageText = page > 0 and ("page " .. page) or "|cff888888no switch|r"
        local knownText = known[key] and "" or " |cff888888(not learned)|r"
        Print(("  %-8s -> %s%s"):format(key, pageText, knownText))
    end
end

local function ShowDebug()
    Print("debug:")
    Print(("  main bar: %s, %d/12 buttons (%s)"):format(barInfo.name, barInfo.count, barInfo.modes))
    Print("  hooked into the bar's own paging: " .. (barInfo.wrapped and "yes" or "no (not needed or not possible)"))
    local count = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
    Print("  current form: " .. tostring(GetShapeshiftForm and GetShapeshiftForm()) .. " of " .. count)
    for i = 1, count do
        local spellID, name = GetFormDetails(i)
        Print(("    [form:%d] %s (id %s) -> %s"):format(i, tostring(name), tostring(spellID), tostring(ClassifyForm(i))))
    end
    local cond = lastCondition and lastCondition:match("^([^#]*)#")
    Print("  driver: " .. tostring(cond))
    if cond and SecureCmdOptionParse then
        Print("  driver wants page: " .. tostring(SecureCmdOptionParse(cond)))
    end
    Print("  page applied now: " .. tostring(header:GetAttribute("fp-page") or "none (normal bar)"))
    local b = cachedList and cachedList[1]
    if b then
        local okn, name = pcall(b.GetName, b)
        Print(("  %s shows slot %s"):format(okn and name or "button 1", tostring(SlotOf(b))))
    end
    Print("  in combat: " .. tostring(InCombatLockdown()))
end

local function ShowHelp()
    Print("commands (/dabp or /druidactionbarpager):")
    Print("  /dabp                - show current page for each form")
    Print("  /dabp <form> <page>  - set a page, e.g. /dabp bear 2")
    Print("  /dabp <form> 0       - don't switch pages for that form")
    Print("  /dabp on | off       - enable or disable paging")
    Print("  /dabp reset          - restore default pages")
    Print("  /dabp debug          - show which bar is being switched")
    Print("  forms: bear, cat, travel, aquatic, moonkin, tree")
end

local function HandleSlash(input)
    input = (input or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, arg = input:match("^(%S*)%s*(.-)$")

    if cmd == "" or cmd == "list" or cmd == "status" then
        ShowStatus()
        return
    elseif cmd == "debug" then
        ShowDebug()
        return
    elseif cmd == "help" then
        ShowHelp()
        return
    elseif cmd == "on" or cmd == "off" then
        db.enabled = (cmd == "on")
        Print(db.enabled and "paging enabled." or "paging disabled.")
    elseif cmd == "reset" then
        for k, v in pairs(DEFAULT_PAGES) do db.pages[k] = v end
        Print("pages reset to defaults.")
    elseif DEFAULT_PAGES[cmd] then
        local page = tonumber(arg)
        if not page or page < 0 or page > 10 or page ~= math_floor(page) then
            Print("page must be a whole number from 1 to 10 (or 0 for no switch).")
            return
        end
        db.pages[cmd] = page
        if page == 0 then
            Print(FORM_LABELS[cmd] .. " will no longer switch pages.")
        else
            Print(FORM_LABELS[cmd] .. " -> action bar page " .. page .. ".")
        end
    else
        ShowHelp()
        return
    end

    if InCombatLockdown() then
        Print("you're in combat; the change will apply when combat ends.")
    end
    forceNext = true
    Rebuild()
end

SLASH_DRUIDACTIONBARPAGER1 = "/dabp"
SLASH_DRUIDACTIONBARPAGER2 = "/druidactionbarpager"
SlashCmdList["DRUIDACTIONBARPAGER"] = HandleSlash

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local events = CreateFrame("Frame")

events:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        -- Guard against a missing, corrupted or hand-edited WTF table.
        if type(DruidActionBarPagerDB) ~= "table" then DruidActionBarPagerDB = {} end
        db = DruidActionBarPagerDB
        if type(db.enabled) ~= "boolean" then db.enabled = true end
        if type(db.pages) ~= "table" then db.pages = {} end
        if type(db.version) ~= "number" then db.version = nil end
        -- 1.0.0 switched Travel/Aquatic to pages 4/5; they are utility forms
        -- and should keep the normal bar. Only clear the old defaults.
        if (db.version or 1) < 2 then
            if db.pages.travel == 4 then db.pages.travel = 0 end
            if db.pages.aquatic == 5 then db.pages.aquatic = 0 end
        end
        -- Moonkin/Tree moved from page 6 to page 4; only clear the old default.
        if (db.version or 1) < 3 then
            if db.pages.moonkin == 6 then db.pages.moonkin = 4 end
            if db.pages.tree == 6 then db.pages.tree = 4 end
        end
        db.version = DB_VERSION
        for k, v in pairs(DEFAULT_PAGES) do
            local page = tonumber(db.pages[k])
            if not page or page < 0 or page > 10 or page ~= math_floor(page) then
                page = v
            end
            db.pages[k] = page
        end
        for k in pairs(db.pages) do
            if DEFAULT_PAGES[k] == nil then db.pages[k] = nil end -- unknown keys
        end
        self:UnregisterEvent("ADDON_LOADED")
        return
    end

    if event == "PLAYER_LOGIN" then
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
        forceNext = true
        Rebuild()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if pendingRebuild then Rebuild() end
        return
    end

    if event == "SPELL_DATA_LOAD_RESULT" then
        local spellID, success = arg1, arg2
        if pendingSpellData[spellID] then
            pendingSpellData[spellID] = nil
            if success then RequestRebuild() end
        end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        -- Bars may have changed across the loading screen, and some bar
        -- addons finish building theirs a moment later.
        RequestRebuild(true)
        if C_Timer and C_Timer.After then
            C_Timer.After(2, function() RequestRebuild(true) end)
        end
        return
    end

    -- UPDATE_SHAPESHIFT_FORMS, SPELLS_CHANGED.
    -- These also fire every time you shift. A shift doesn't change the form
    -- list, so skip the rebuild (and its debounce delay) unless it did. The
    -- game's own state driver already switches the page on the shift itself.
    local signature = FormSignature()
    if signature == lastFormSignature and not pendingRebuild then
        return
    end
    lastFormSignature = signature
    RequestRebuild()
end)

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
