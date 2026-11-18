-- Connects the detected main bar and discovered extras to the secure header.
local _, ns = ...
local C = ns.Constants
local BUTTONS = C.BUTTONS_PER_PAGE
local header = ns.Frames.header

local At = {}
ns.Attach = At

local info = {
    name = "not scanned",
    count = 0,
    found = false,
    modes = "none",
    wrapped = false,
    extras = {},
    signature = "",
    missingSelected = false,
}
local wrappedBars = {}

local WRAP_PRE = [[
    if name and name:sub(1, 6) == "state-" then
        local apply = control and control:GetAttribute("fp-page")
            and self == control:GetFrameRef("bar")
        if not apply and control and control:GetAttribute("fp-page") then
            for i = 1, 10 do
                if self == control:GetFrameRef("candidate" .. i .. "-bar")
                    and control:GetAttribute("candidate-selected" .. i)
                    and control:GetAttribute("candidate-enabled" .. i) then
                    apply = true
                    break
                end
            end
        end
        if apply then return nil, "dabp" end
    end
]]

local WRAP_POST = [[
    if not control or not control:GetAttribute("fp-page") then return end
    local apply = self == control:GetFrameRef("bar")
    if not apply then
        for i = 1, 10 do
            local ref = "candidate" .. i .. "-bar"
            if self == control:GetFrameRef(ref)
                and control:GetAttribute("candidate-selected" .. i)
                and control:GetAttribute("candidate-enabled" .. i) then
                apply = true
                break
            end
        end
    end
    if apply then control:RunAttribute("fp-apply") end
]]

local function SetRef(label, frame)
    if frame then
        header:SetFrameRef(label, frame)
    else
        header:SetAttribute("frameref-" .. label, nil)
    end
end

local function SetBarState(prefix, bar)
    local state
    if bar then
        local ok, value = pcall(bar.GetAttribute, bar, "state")
        if ok then state = value end
    end
    header:SetAttribute(prefix .. "labbase", state)
end

local function ParentOf(button)
    local ok, parent = pcall(button.GetParent, button)
    if ok then return parent end
end

local function WrapBar(bar)
    if not bar or wrappedBars[bar] then return wrappedBars[bar] or false end
    local okp, protected = pcall(bar.IsProtected, bar)
    if not (okp and protected) then return false end
    local ok = pcall(SecureHandlerWrapScript, bar, "OnAttributeChanged", header, WRAP_PRE, WRAP_POST)
    wrappedBars[bar] = ok and true or false
    return wrappedBars[bar]
end

local function AttachButton(i, button, active, prefix)
    prefix = prefix or ""
    if not button then
        header:SetAttribute(prefix .. "mode" .. i, nil)
        header:SetAttribute(prefix .. "idx" .. i, nil)
        header:SetAttribute(prefix .. "base" .. i, nil)
        return nil, nil
    end

    local mode = ns.BarScan.ModeOf(button)
    local slot = ns.BarScan.BaseSlot(button, active) or ns.BarScan.SlotOf(button) or i
    local index = ((slot - 1) % BUTTONS) + 1
    header:SetAttribute(prefix .. "mode" .. i, mode)
    header:SetAttribute(prefix .. "idx" .. i, index)
    header:SetAttribute(prefix .. "base" .. i, slot)
    return mode, slot
end

local function ModeSummary(counts)
    local summary = {}
    for mode, n in pairs(counts) do summary[#summary + 1] = mode .. " x" .. n end
    table.sort(summary)
    return table.concat(summary, ", ")
end

local function ResolveCandidateId(candidates, id)
    if type(id) ~= "string" then return nil end
    for index, candidate in ipairs(candidates) do
        if candidate.id == id then return index, candidate.id end
    end

    -- Releases before stable IDs stored label@firstSlot#discoveryOrder.
    -- Migrate only when the label/slot pair identifies exactly one candidate.
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

function At.Attach(force)
    local name, list, count, found = ns.BarScan.Find(force)
    local active = header:GetAttribute("fp-active")
    local candidates = ns.BarScan.FindExtras(false)
    local db = ns.Settings.Get()
    local selectedById, candidateById = {}, {}
    for index, candidate in ipairs(candidates) do candidateById[candidate.id] = index end
    local normalizedBars, seenBars = {}, {}
    for slot = 1, C.MAX_ADDITIONAL_BARS do
        local id = db.additionalBars[slot]
        if id then
            local _, canonicalId = ResolveCandidateId(candidates, id)
            local normalizedId = canonicalId or id
            if not seenBars[normalizedId] then
                normalizedBars[#normalizedBars + 1] = normalizedId
                seenBars[normalizedId] = true
                selectedById[normalizedId] = #normalizedBars
            end
        end
    end
    db.additionalBars = normalizedBars

    local bases, mainCounts = {}, {}
    local bar
    for i = 1, BUTTONS do
        local button = list and list[i]
        SetRef("button" .. i, button)
        if button then
            local mode, slot = AttachButton(i, button, active, "")
            bases[button] = slot
            mainCounts[mode] = (mainCounts[mode] or 0) + 1
            bar = bar or ParentOf(button)
        else
            AttachButton(i, nil, active, "")
        end
    end
    SetRef("bar", bar)
    SetBarState("", bar)
    local mainWrapped = WrapBar(bar)

    for index, candidate in ipairs(candidates) do
        local prefix = "candidate" .. index .. "-"
        local oldId = header:GetAttribute(prefix .. "id")
        if oldId ~= candidate.id then header:SetAttribute("candidate-enabled" .. index, true) end
        header:SetAttribute(prefix .. "id", candidate.id)
        header:SetAttribute("candidate-selected" .. index, selectedById[candidate.id] ~= nil)
        if header:GetAttribute("candidate-enabled" .. index) == nil then
            header:SetAttribute("candidate-enabled" .. index, true)
        end

        local candidateBar, candidateCounts = nil, {}
        for i = 1, BUTTONS do
            local button = candidate.buttons[i]
            SetRef(prefix .. "button" .. i, button)
            if button then
                local mode, slot = AttachButton(i, button, active, prefix)
                bases[button] = candidate.slots[i] or slot
                candidateCounts[mode] = (candidateCounts[mode] or 0) + 1
                candidateBar = candidateBar or ParentOf(button)
            else
                AttachButton(i, nil, active, prefix)
            end
        end
        SetRef(prefix .. "bar", candidateBar)
        SetBarState(prefix, candidateBar)
        if selectedById[candidate.id] then WrapBar(candidateBar) end
    end

    for index = #candidates + 1, C.MAX_DISCOVERED_BARS do
        local prefix = "candidate" .. index .. "-"
        header:SetAttribute(prefix .. "id", nil)
        header:SetAttribute("candidate-selected" .. index, false)
        header:SetAttribute("candidate-enabled" .. index, nil)
        SetRef(prefix .. "bar", nil)
        SetBarState(prefix, nil)
        for i = 1, BUTTONS do
            SetRef(prefix .. "button" .. i, nil)
            AttachButton(i, nil, active, prefix)
        end
    end

    local extras, missingSelected, selectedIds = {}, false, {}
    for slot = 1, C.MAX_ADDITIONAL_BARS do
        local id = db.additionalBars[slot]
        local index = id and candidateById[id]
        header:SetAttribute("selectedCandidate" .. slot, index)
        if id then
            selectedIds[#selectedIds + 1] = id
            if index then
                local candidate = candidates[index]
                extras[#extras + 1] = {
                    name = candidate.label,
                    count = candidate.count,
                    visible = candidate.visibleCount > 0,
                    candidate = index,
                    slot = slot,
                }
            else
                missingSelected = true
            end
        end
    end

    local candidateIds = {}
    for _, candidate in ipairs(candidates) do candidateIds[#candidateIds + 1] = candidate.id end
    local signature = table.concat(candidateIds, ";") .. "||" .. table.concat(selectedIds, ";")

    ns.BarScan.SetBaseSlots(bases)
    info = {
        name = name or "unknown",
        count = count or 0,
        found = not not found,
        modes = ModeSummary(mainCounts),
        wrapped = mainWrapped,
        extras = extras,
        signature = signature,
        missingSelected = missingSelected,
    }
    return info.count
end

function At.Info()
    return info
end
