-- Locates the main action bar and additional player action bars.
local _, ns = ...
local C = ns.Constants

local B = {}
ns.BarScan = B

local BUTTONS = C.BUTTONS_PER_PAGE
local MAX_SLOT = C.MAX_SCAN_SLOT
local baseSlots = {}
local discoverySlots = {}
local cachedName, cachedList, cachedCount, cachedFound, cachedAssumedBase

local function ReadField(frame, key)
    return frame[key]
end

local function ReadLabSlot(frame)
    if frame._state_type == "action" then return tonumber(frame._state_action) end
end

local function ReadActionField(frame)
    local action = frame.action
    if type(action) == "number" and action > 0 then return action end
end

local function IsShown(frame)
    local ok, visible = pcall(frame.IsVisible, frame)
    return ok and visible
end

local function AnyShown(list)
    if not list then return false end
    for i = 1, BUTTONS do
        if list[i] and IsShown(list[i]) then return true end
    end
    return false
end

local function ActionBaseSlot(frame)
    local ok, raw = pcall(frame.GetAttribute, frame, "action-base")
    local slot = ok and tonumber(raw)
    if slot and slot > 0 then return slot end
end

-- Returns the frame's owning bar: prefers `frame.bar` (used by WoW Forever's
-- Blizzard action buttons, whose direct GetParent() is a per-button container)
-- when it is a real frame, then falls back to GetParent().
function B.OwnerOf(frame)
    if not frame then return nil end
    local okb, bar = pcall(ReadField, frame, "bar")
    if okb and bar and bar ~= frame then
        local okf = pcall(ReadField, bar, "IsProtected")
        if okf and type(bar.IsProtected) == "function" then
            local okp = pcall(bar.IsProtected, bar)
            if okp then return bar end
        end
    end
    local okp, parent = pcall(frame.GetParent, frame)
    if okp then return parent end
end

local function SlotOf(frame, preferBase)
    if not frame then return nil end
    if preferBase then
        local base = ActionBaseSlot(frame)
        if base then return base end
    end
    local okl, labSlot = pcall(ReadLabSlot, frame)
    if okl and labSlot and labSlot > 0 then return labSlot end
    local oka, rawAction = pcall(frame.GetAttribute, frame, "action")
    local slot = oka and tonumber(rawAction)
    if not slot then
        local oks, rawState = pcall(frame.GetAttribute, frame, "state-action")
        slot = oks and tonumber(rawState)
    end
    if slot and slot > 0 then return slot end
    local okf, fieldSlot = pcall(ReadActionField, frame)
    if okf and fieldSlot then return fieldSlot end
end

local function GroupFor(frame)
    local okn, name = pcall(frame.GetName, frame)
    if okn and type(name) == "string" and name ~= "" then
        local prefix = name:gsub("%d+$", "")
        if C.IGNORED_BUTTON_PREFIXES[prefix] then return nil end
        return prefix
    end
    return B.OwnerOf(frame)
end

local function GroupLabel(group)
    if type(group) == "string" then return group end
    if group then
        local ok, name = pcall(group.GetName, group)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    return "unnamed bar"
end

local function FrameName(frame)
    if not frame then return nil end
    local ok, name = pcall(frame.GetName, frame)
    if ok and type(name) == "string" and name ~= "" and name ~= "UIParent" then
        return name
    end
end

local function ActiveBonusPage()
    if C_ActionBar and C_ActionBar.HasBonusActionBar and C_ActionBar.GetBonusBarIndex then
        local okh, has = pcall(C_ActionBar.HasBonusActionBar)
        if okh and has then
            local oki, idx = pcall(C_ActionBar.GetBonusBarIndex)
            local page = oki and tonumber(idx)
            if page and page > 1 then return page end
        end
    end
end

-- A generic action button must be protected, belong to a player bar, and report
-- a real action slot. Main-bar scans require visibility; extra-bar discovery
-- also includes hidden bars so a selected bar hidden mid-shift can still restore.
local function ScanCheck(frame, active, includeHidden)
    local visible = IsShown(frame)
    if not includeHidden and not visible then return nil end
    local ok, protected = pcall(frame.IsProtected, frame)
    if not (ok and protected) then return nil end

    local group = GroupFor(frame)
    if not group then return nil end

    local slot = includeHidden and discoverySlots[frame] or (active and baseSlots[frame])
    if not slot then slot = SlotOf(frame, true) end
    if not slot then return nil end

    return slot, group, visible
end

-- Known bars attach all 12 protected buttons as soon as at least one button on
-- the bar is visible, so empty hidden slots (showgrid off) still page on shift.
local function FindKnownBar()
    for _, known in ipairs(C.KNOWN_BARS) do
        local list, count, anyVisible = {}, 0, false
        for i = 1, BUTTONS do
            local button = _G[known.prefix .. i]
            if button then
                local ok, protected = pcall(button.IsProtected, button)
                if ok and protected then
                    list[i] = button
                    count = count + 1
                    if not anyVisible and IsShown(button) then anyVisible = true end
                end
            end
        end
        if count > 0 and anyVisible then
            return known.name, list, count, true, false
        end
    end
end

local function RecordGroupButton(groups, key, owner, slot, frame)
    local group = groups[key]
    if not group then
        group = { list = {}, count = 0, label = GroupLabel(owner) }
        groups[key] = group
    end
    local index = ((slot - 1) % BUTTONS) + 1
    if not group.list[index] then
        group.list[index] = frame
        group.count = group.count + 1
    end
end

local function BestGroup(groups)
    local best
    for _, group in pairs(groups) do
        if not best or group.count > best.count
            or (group.count == best.count and group.label < best.label) then
            best = group
        end
    end
    if best and best.count >= math.floor(BUTTONS / 2) then return best end
end

local function ScanForMainBar(active)
    if not EnumerateFrames then return nil end
    local shifted = not active and GetShapeshiftForm and (tonumber(GetShapeshiftForm()) or 0) > 0
    local bonusPage = shifted and ActiveBonusPage()
    local groups, bonusGroups = {}, {}
    local frame = EnumerateFrames()
    local guard = 0
    while frame and guard < 200000 do
        guard = guard + 1
        local ok, slot, owner = pcall(ScanCheck, frame, active, false)
        if ok and slot and owner then
            if slot >= 1 and slot <= BUTTONS then
                RecordGroupButton(groups, owner, owner, slot, frame)
            elseif shifted and slot <= MAX_SLOT then
                local page = math.floor((slot - 1) / BUTTONS) + 1
                if (bonusPage and page == bonusPage)
                    or (not bonusPage and page >= 7 and page <= 10) then
                    local key = tostring(owner) .. "#" .. page
                    RecordGroupButton(bonusGroups, key, owner, slot, frame)
                end
            end
        end
        frame = EnumerateFrames(frame)
    end

    local best = BestGroup(groups)
    if best then
        return best.label .. " (auto-detected)", best.list, best.count, true, false
    end
    local bonusBest = shifted and BestGroup(bonusGroups)
    if bonusBest then
        return bonusBest.label .. " (auto-detected)", bonusBest.list, bonusBest.count, true, true
    end
    return nil
end

local function FindUncached(active)
    local name, list, count, found, assumedBase = FindKnownBar()
    if name then return name, list, count, found, assumedBase end

    name, list, count, found, assumedBase = ScanForMainBar(active)
    if name then return name, list, count, found, assumedBase end

    local fallback, fallbackCount = {}, 0
    for i = 1, BUTTONS do
        local button = _G["ActionButton" .. i]
        if button then
            fallback[i] = button
            fallbackCount = fallbackCount + 1
        end
    end
    return "Blizzard (fallback)", fallback, fallbackCount, false, false
end

function B.Find(force)
    local active = ns.Frames.header:GetAttribute("fp-active")
    if not force and cachedFound and AnyShown(cachedList) then
        return cachedName, cachedList, cachedCount, cachedFound, cachedAssumedBase
    end
    cachedName, cachedList, cachedCount, cachedFound, cachedAssumedBase = FindUncached(active)
    return cachedName, cachedList, cachedCount, cachedFound, cachedAssumedBase
end

-- True when the cached main bar was never found, went completely hidden, or was
-- superseded by a higher-priority known bar that finished loading after login.
function B.NeedsMainRescan()
    if not cachedFound or not AnyShown(cachedList) then return true end
    local knownName = FindKnownBar()
    if knownName and knownName ~= cachedName then return true end
    return false
end

-- Resolves a saved extra-bar ID (including pre-1.1.2-patched.4 `label@slot#n`
-- IDs when unambiguous) to `(candidateIndex, canonicalId)`.
function B.ResolveCandidateId(candidates, id)
    if type(id) ~= "string" then return nil end
    for index, candidate in ipairs(candidates) do
        if candidate.id == id then return index, candidate.id end
    end

    local legacyBase = id:match("^(.*@%d+)#%d+$")
    if not legacyBase then return nil end
    local match, matches
    for index, candidate in ipairs(candidates) do
        if candidate.idBase == legacyBase then
            match = index
            matches = (matches or 0) + 1
        end
    end
    if matches == 1 then return match, candidates[match].id end
end

-- Human-readable summary of a candidate bar that distinguishes same-prefix
-- bars (e.g. BT4Button / DominosActionButton) by parent frame and page/slots.
function B.FormatCandidate(candidate)
    local page = math.floor((candidate.firstSlot - 1) / BUTTONS) + 1
    local lastSlot = candidate.firstSlot + BUTTONS - 1
    local detail
    if candidate.barName and candidate.barName ~= candidate.label then
        detail = ("%s, page %d / slots %d-%d"):format(
            candidate.barName, page, candidate.firstSlot, lastSlot)
    else
        detail = ("page %d / slots %d-%d"):format(page, candidate.firstSlot, lastSlot)
    end
    return ("%s [%s]"):format(candidate.label, detail)
end

-- Return up to MAX_DISCOVERED_BARS extra 12-button groups, excluding the main
-- bar. Visible bars sort ahead of hidden bars, and saved selections are kept
-- inside the cap even when more than MAX_DISCOVERED_BARS groups exist.
function B.FindExtras(force, selectedIds, preserveMainCache)
    local active = ns.Frames.header:GetAttribute("fp-active")
    local mainList
    if preserveMainCache then
        mainList = cachedList
        if not mainList then
            local _, list = FindUncached(active)
            mainList = list
        end
    else
        local _, list = B.Find(force)
        mainList = list
    end

    local mainButtons = {}
    for _, button in pairs(mainList or {}) do
        if button then mainButtons[button] = true end
    end
    if not EnumerateFrames then return {} end

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
                    barName = nil,
                    firstSlot = firstSlot,
                    buttons = {},
                    slots = {},
                    count = 0,
                    visibleCount = 0,
                }
                byBlock[block] = group
                groups[#groups + 1] = group
            end
            if not group.barName then
                group.barName = FrameName(B.OwnerOf(frame))
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
        local aVis, bVis = a.visibleCount > 0, b.visibleCount > 0
        if aVis ~= bVis then return aVis end
        if a.label ~= b.label then return a.label < b.label end
        if a.firstSlot ~= b.firstSlot then return a.firstSlot < b.firstSlot end
        return a.id < b.id
    end)

    if #candidates > C.MAX_DISCOVERED_BARS then
        local keep = {}
        if type(selectedIds) == "table" then
            for _, savedId in ipairs(selectedIds) do
                local idx = B.ResolveCandidateId(candidates, savedId)
                if idx then keep[candidates[idx]] = true end
            end
        end
        local dropIndex = #candidates
        while #candidates > C.MAX_DISCOVERED_BARS and dropIndex >= 1 do
            if not keep[candidates[dropIndex]] then
                table.remove(candidates, dropIndex)
            end
            dropIndex = dropIndex - 1
        end
        while #candidates > C.MAX_DISCOVERED_BARS do
            table.remove(candidates)
        end
    end
    return candidates
end

function B.FirstCachedButton()
    if not cachedList then return nil end
    for i = 1, BUTTONS do
        if cachedList[i] then return cachedList[i] end
    end
end

function B.SetBaseSlots(slots)
    baseSlots = slots or {}
    -- Keep an attached bar's discovery ID stable when its normal page changes.
    -- Restore baselines can change while an extra is paused; grouping cannot.
    local previous = discoverySlots
    discoverySlots = {}
    for button, slot in pairs(baseSlots) do
        discoverySlots[button] = previous[button] or slot
    end
end

function B.BaseSlot(button, active)
    return active and baseSlots[button] or nil
end

function B.HasActionBase(button)
    return ActionBaseSlot(button) ~= nil
end

-- True when `slot` falls on the active bonus-bar page (or a standard druid
-- bonus page 7-10), distinguishing form-shifted slots from manual pages 2-6.
function B.IsBonusSlot(slot)
    if type(slot) ~= "number" or slot <= BUTTONS then return false end
    local page = math.floor((slot - 1) / BUTTONS) + 1
    local bonusPage = ActiveBonusPage()
    if bonusPage then return page == bonusPage end
    return page >= 7 and page <= 10
end

function B.BaseSlotOf(button)
    return SlotOf(button, true)
end

function B.SlotOf(button)
    return SlotOf(button, false)
end

-- Classifies how a button switches pages:
--   "lab"    - LibActionButton-1.0 button (private `fp` state)
--   "page"   - Blizzard ActionButton / MultiBar*Button (GetID() > 0 + actionpage)
--   "action" - fixed-slot button (`action` attribute)
function B.ModeOf(button)
    if not button then return nil end
    local ok, upd = pcall(button.GetAttribute, button, "UpdateState")
    if ok and type(upd) == "string" and type(button.state_types) == "table" then
        return "lab"
    end
    local okn, name = pcall(button.GetName, button)
    if okn and type(name) == "string" then
        local okid, id = pcall(button.GetID, button)
        if okid and type(id) == "number" and id > 0 then
            if name:find("^ActionButton%d+$") then
                return "page"
            end
            if name:find("^MultiBar%w+Button%d+$") then
                local oku, useParent = pcall(button.GetAttribute, button, "useparent-actionpage")
                if oku and useParent then return "page" end
                local oka, rawAction = pcall(button.GetAttribute, button, "action")
                if not (oka and tonumber(rawAction)) then return "page" end
            end
        end
    end
    return "action"
end
