-- Finds the main bar on screen and describes its buttons. Reads frames only;
-- it never changes them.
local _, ns = ...
local C = ns.Constants

local B = {}
ns.BarScan = B

local BUTTONS = C.BUTTONS_PER_PAGE

-- The slot each button showed before a form page was applied, for buttons
-- that are on the page now. Replaced on every attach.
local baseSlots = {}

-- Result of the last find, reused while its first button is still shown.
local cachedName, cachedList, cachedCount, cachedFound

local function IsShown(frame)
    local ok, visible = pcall(frame.IsVisible, frame)
    return ok and visible
end

-- The action slot a button shows. LibActionButton (Bartender4, ElvUI,
-- ConsolePort, AzeriteUI...) keeps the slot in _state_action; its .action
-- field stays 0.
local function SlotOf(button)
    if button._state_type == "action" then
        local s = tonumber(button._state_action)
        if s and s > 0 then return s end
    end
    local ok, a = pcall(button.GetAttribute, button, "action")
    a = ok and tonumber(a) or nil
    if not a and type(button.action) == "number" and button.action > 0 then
        a = button.action
    end
    return a
end

-- The buttons named prefix1..prefix12 that exist, as a list by slot, and how many.
local function ButtonsFromPrefix(prefix)
    local list, count = {}, 0
    for i = 1, BUTTONS do
        local b = _G[prefix .. i]
        if b then
            list[i] = b
            count = count + 1
        end
    end
    return list, count
end

-- Slot and group for one frame during the scan, or nil if it isn't a visible,
-- protected button. Named buttons group by name without the trailing number
-- (one group per bar); unnamed buttons, common in newer bar addons, group by
-- their parent frame, which is the bar they belong to.
local function ScanCheck(frame, active)
    if not frame.IsVisible or not frame:IsVisible() then return nil end
    if not frame.IsProtected or not frame:IsProtected() then return nil end
    -- A button that was moved to a form page can show a slot outside 1-12.
    local slot = (active and baseSlots[frame]) or SlotOf(frame)
    local name = frame:GetName()
    local group
    if name and name ~= "" then
        group = (name:gsub("%d+$", ""))
    else
        group = frame:GetParent()
    end
    return slot, group
end

-- One group's buttons, keyed by slot, and a label for it.
local function NewGroup(group)
    return {
        buttons = {},
        count = 0,
        label = type(group) == "string" and group or "unnamed bar",
    }
end

-- Walks every frame and returns the group that covers the most of slots 1-12
-- (at least six of them), as label, buttons by slot, count. Otherwise nil.
local function ScanForMainBar()
    if not EnumerateFrames then return nil end

    local active = ns.Frames.header:GetAttribute("fp-active")
    local groups = {}
    local frame, guard = EnumerateFrames(), 0
    while frame and guard < 200000 do
        guard = guard + 1
        local ok, slot, group = pcall(ScanCheck, frame, active)
        if ok and slot and group and slot >= 1 and slot <= BUTTONS then
            local g = groups[group]
            if not g then
                g = NewGroup(group)
                groups[group] = g
            end
            if not g.buttons[slot] then
                g.buttons[slot] = frame
                g.count = g.count + 1
            end
        end
        frame = EnumerateFrames(frame)
    end

    local best
    for _, g in pairs(groups) do
        if not best or g.count > best.count then best = g end
    end
    if best and best.count >= 6 then
        return best.label, best.buttons, best.count
    end
    return nil
end

-- A known bar addon's bar, if one is on screen: its name, buttons and count.
local function FindKnownBar()
    for _, known in ipairs(C.KNOWN_BARS) do
        local list, count = ButtonsFromPrefix(known.prefix)
        if count > 0 and list[1] and IsShown(list[1]) then
            return known.name, list, count, true
        end
    end
    return nil
end

local function FindUncached()
    local name, list, count, found = FindKnownBar()
    if name then return name, list, count, found end

    name, list, count = ScanForMainBar()
    if name then
        return name .. " (auto-detected)", list, count, true
    end

    -- Nothing visible (e.g. during a loading screen): fall back to Blizzard.
    list, count = ButtonsFromPrefix("ActionButton")
    return "Blizzard", list, count, false
end

-- Returns the main bar's name, its buttons by slot, and the button count.
-- Detection can scan every frame in the UI, so the result is reused while its
-- first button is still shown. A forced find ignores the cache; it runs after
-- a loading screen or a settings change, when the bar may have changed.
function B.Find(force)
    if not force and cachedList and cachedList[1] and IsShown(cachedList[1]) then
        return cachedName, cachedList, cachedCount, cachedFound
    end
    cachedName, cachedList, cachedCount, cachedFound = FindUncached()
    return cachedName, cachedList, cachedCount, cachedFound
end

-- The first button of the last find, or nil.
function B.FirstCachedButton()
    return cachedList and cachedList[1]
end

-- Records the slots to restore for the buttons attached in the last attach.
function B.SetBaseSlots(slots)
    baseSlots = slots
end

-- The slot a button showed before the page was applied, when a page is active.
function B.BaseSlot(button, active)
    return active and baseSlots[button] or nil
end

-- The slot a button currently shows, or nil.
B.SlotOf = SlotOf

-- How the secure snippets must treat a button:
--   lab    - LibActionButton: a private state holds the slot
--   page   - Blizzard's own action button: an actionpage override
--   action - any other button: its "action" attribute is set to the slot
function B.ModeOf(button)
    local ok, upd = pcall(button.GetAttribute, button, "UpdateState")
    if ok and type(upd) == "string" and type(button.state_types) == "table" then
        return "lab"
    end
    -- Only Blizzard's own action buttons take an actionpage override. Other
    -- addons' buttons often carry an ID too, where the override does nothing,
    -- so those are treated as fixed-slot buttons instead.
    local okn, name = pcall(button.GetName, button)
    if okn and type(name) == "string" and name:find("^ActionButton%d+$") then
        local okid, id = pcall(button.GetID, button)
        if okid and id and id > 0 then
            return "page"
        end
    end
    return "action"
end
