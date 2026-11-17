-- Locates the main action bar and other visible/hidden action bars.
local _, ns = ...
local C = ns.Constants

local B = {}
ns.BarScan = B

local BUTTONS = C.BUTTONS_PER_PAGE
local MAX_SLOT = BUTTONS * C.MAX_PAGE
local baseSlots = {}
local cachedName, cachedList, cachedCount, cachedFound

local function IsShown(frame)
    local ok, visible = pcall(frame.IsVisible, frame)
    return ok and visible
end

local function SlotOf(frame)
    if frame._state_type == "action" then
        local slot = tonumber(frame._state_action)
        if slot and slot > 0 then return slot end
    end
    local ok, slot = pcall(function()
        local action = tonumber(frame:GetAttribute("action"))
        if not action then action = tonumber(frame:GetAttribute("state-action")) end
        if action then return action end
    end)
    if ok and slot and slot > 0 then return slot end
    if type(frame.action) == "number" and frame.action > 0 then return frame.action end
end

local function GroupFor(frame)
    local name = frame:GetName()
    if name and name ~= "" then return name:gsub("%d+$", "") end
    return frame:GetParent()
end

local function GroupLabel(group)
    if type(group) == "string" then return group end
    if group then
        local ok, name = pcall(group.GetName, group)
        if ok and name and name ~= "" then return name end
    end
    return "unnamed bar"
end

-- A generic action button must be protected and show a real action slot. Main-bar
-- scans require visibility; extra-bar discovery also includes hidden bars so a
-- selected bar can be restored safely when it is hidden during a form change.
local function ScanCheck(frame, active, includeHidden)
    local visible = IsShown(frame)
    if not includeHidden and not visible then return nil end
    local ok, protected = pcall(frame.IsProtected, frame)
    if not (ok and protected) then return nil end

    local slot = active and baseSlots[frame] or nil
    if not slot then slot = SlotOf(frame) end
    if not slot then return nil end

    local group = GroupFor(frame)
    if not group then return nil end
    return slot, group, visible
end

local function FindKnownBar(active)
    for _, known in ipairs(C.KNOWN_BARS) do
        local list, count = {}, 0
        for i = 1, BUTTONS do
            local button = _G[known.prefix .. i]
            if button and IsShown(button) then
                local ok, protected = pcall(button.IsProtected, button)
                if ok and protected then
                    list[i] = button
                    count = count + 1
                end
            end
        end
        if count > 0 and list[1] then return known.name, list, count, true end
    end
end

local function ScanForMainBar(active)
    if not EnumerateFrames then return nil end
    local groups = {}
    local frame = EnumerateFrames()
    local guard = 0
    while frame and guard < 200000 do
        guard = guard + 1
        local ok, slot, owner = pcall(ScanCheck, frame, active, false)
        if ok and slot and slot >= 1 and slot <= BUTTONS and owner then
            local group = groups[owner]
            if not group then
                group = { list = {}, count = 0,
                    label = type(owner) == "string" and owner or "unnamed bar" }
                groups[owner] = group
            end
            local index = ((slot - 1) % BUTTONS) + 1
            if not group.list[index] then
                group.list[index] = frame
                group.count = group.count + 1
            end
        end
        frame = EnumerateFrames(frame)
    end

    local best
    for _, group in pairs(groups) do
        if not best or group.count > best.count then best = group end
    end
    if best and best.count >= 6 then
        return best.label .. " (auto-detected)", best.list, best.count, true
    end
    return nil
end

local function FindUncached(active)
    local name, list, count, found = FindKnownBar(active)
    if name then return name, list, count, found end

    name, list, count, found = ScanForMainBar(active)
    if name then return name, list, count, found end

    local fallback = {}
    for i = 1, BUTTONS do fallback[i] = _G["ActionButton" .. i] end
    return "Blizzard (fallback)", fallback, BUTTONS, false
end

function B.Find(force)
    local active = ns.Frames.header:GetAttribute("fp-active")
    local first = cachedList and cachedList[1]
    if not force and first and IsShown(first) then
        return cachedName, cachedList, cachedCount, cachedFound
    end
    cachedName, cachedList, cachedCount, cachedFound = FindUncached(active)
    return cachedName, cachedList, cachedCount, cachedFound
end

-- Return up to MAX_DISCOVERED_BARS extra 12-button groups, excluding the main
-- bar. Stable names/slot ranges are saved; selection order drives the hotkeys.
function B.FindExtras(force)
    local _, mainList = B.Find(force)
    local mainButtons = {}
    for _, button in pairs(mainList or {}) do
        if button then mainButtons[button] = true end
    end
    if not EnumerateFrames then return {} end

    local active = ns.Frames.header:GetAttribute("fp-active")
    local groupsByOwner, groups = {}, {}
    local idOccurrences = {}
    local frame = EnumerateFrames()
    local guard = 0
    while frame and guard < 200000 do
        guard = guard + 1
        local ok, slot, owner, visible = pcall(ScanCheck, frame, active, true)
        if ok and slot and slot >= 1 and slot <= MAX_SLOT and owner then
            local byBlock = groupsByOwner[owner]
            if not byBlock then byBlock = {}; groupsByOwner[owner] = byBlock end
            local block = math.floor((slot - 1) / BUTTONS)
            local group = byBlock[block]
            if not group then
                local firstSlot = block * BUTTONS + 1
                local label = GroupLabel(owner)
                local idBase = label .. "@" .. firstSlot
                local occurrence = (idOccurrences[idBase] or 0) + 1
                idOccurrences[idBase] = occurrence
                local id = idBase
                if occurrence > 1 then id = idBase .. "~" .. occurrence end
                group = {
                    id = id,
                    idBase = idBase,
                    label = label,
                    firstSlot = firstSlot,
                    buttons = {},
                    slots = {},
                    count = 0,
                    visibleCount = 0,
                }
                byBlock[block] = group
                groups[#groups + 1] = group
            end
            local index = ((slot - 1) % BUTTONS) + 1
            if not group.buttons[index] then
                group.buttons[index] = frame
                group.slots[index] = slot
                group.count = group.count + 1
                if visible then group.visibleCount = group.visibleCount + 1 end
            end
        end
        frame = EnumerateFrames(frame)
    end

    local candidates = {}
    for _, group in ipairs(groups) do
        local isMain = false
        for _, button in pairs(group.buttons) do
            if mainButtons[button] then isMain = true; break end
        end
        if not isMain and group.count >= math.floor(BUTTONS / 2) then
            candidates[#candidates + 1] = group
        end
    end
    table.sort(candidates, function(a, b)
        if a.label ~= b.label then return a.label < b.label end
        if a.firstSlot ~= b.firstSlot then return a.firstSlot < b.firstSlot end
        return a.id < b.id
    end)
    while #candidates > C.MAX_DISCOVERED_BARS do table.remove(candidates) end
    return candidates
end

function B.FirstCachedButton()
    return cachedList and cachedList[1]
end

function B.SetBaseSlots(slots)
    baseSlots = slots or {}
end

function B.BaseSlot(button, active)
    return active and baseSlots[button] or nil
end

function B.SlotOf(button)
    return SlotOf(button)
end

function B.ModeOf(button)
    local ok, upd = pcall(button.GetAttribute, button, "UpdateState")
    if ok and type(upd) == "string" and type(button.state_types) == "table" then
        return "lab"
    end
    local okn, name = pcall(button.GetName, button)
    if okn and type(name) == "string" and name:find("^ActionButton%d+$") then
        local okid, id = pcall(button.GetID, button)
        if okid and id and id > 0 then return "page" end
    end
    return "action"
end
