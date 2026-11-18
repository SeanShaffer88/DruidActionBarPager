-- Connects the found main bar and up to three extra bars to the secure header.
-- All work here runs out of combat (guarded by Core/Rebuild.lua).
local _, ns = ...
local C = ns.Constants

local At = {}
ns.Attach = At

local BUTTONS = C.BUTTONS_PER_PAGE
local header = ns.Frames.header

local info = {
    name = "none",
    count = 0,
    found = false,
    modes = "",
    wrapped = false,
    extras = {},
    missingExtras = {},
    signature = "",
    missingSelected = false,
}
local wrappedBars = {}
local baseLabStates = {}
local attachedMain = { bar = nil, labbase = nil, buttons = {} }
local attachedCandidates = {}
local lastCandidateCount = 0

local function SetRef(label, frame)
    if frame then
        header:SetFrameRef(label, frame)
    else
        header:SetAttribute("frameref-" .. label, nil)
    end
end

local function ReadAttr(frame, attr)
    if not frame then return nil end
    local ok, value = pcall(frame.GetAttribute, frame, attr)
    if ok then return value end
end

local function SetBarState(prefix, bar)
    local state = ReadAttr(bar, "state")
    if state == "fp" then state = nil end
    header:SetAttribute(prefix .. "labbase", state)
    return state
end

local function WrapBar(bar)
    if not bar then return false end
    if wrappedBars[bar] ~= nil then return wrappedBars[bar] end
    local okp, protected = pcall(bar.IsProtected, bar)
    if not (okp and protected) then return false end
    local ok = pcall(
        SecureHandlerWrapScript,
        bar,
        "OnAttributeChanged",
        header,
        ns.Snippets.WRAP_PRE,
        ns.Snippets.WRAP_POST
    )
    wrappedBars[bar] = ok and true or false
    return wrappedBars[bar]
end

-- Restores a dropped, deselected, or replaced bar out of combat by running the
-- same restricted `fp-apply-bar` snippet through SecureHandlerExecute, keeping
-- all button mutations inside the secure environment (including LAB UpdateState
-- and Dominos UpdateShown handles).
local function RestoreBarRecord(record, excludeButtons, refMainBar, restoreMainBar)
    if not record or not record.buttons or not SecureHandlerExecute then return end
    if InCombatLockdown and InCombatLockdown() then return end

    local any = false
    for i = 1, BUTTONS do
        local entry = record.buttons[i]
        local button = entry and entry.frame
        if button and not (excludeButtons and excludeButtons[button]) then
            any = true
            SetRef("restore-button" .. i, button)
            header:SetAttribute("restore-mode" .. i, entry.mode)
            header:SetAttribute("restore-idx" .. i, entry.idx)
            header:SetAttribute("restore-base" .. i, entry.base)
            header:SetAttribute("restore-labstate" .. i, entry.labstate)
        else
            SetRef("restore-button" .. i, nil)
            header:SetAttribute("restore-mode" .. i, nil)
            header:SetAttribute("restore-idx" .. i, nil)
            header:SetAttribute("restore-base" .. i, nil)
            header:SetAttribute("restore-labstate" .. i, nil)
        end
    end
    if not any then return end

    SetRef("bar", refMainBar)
    SetRef("restore-bar", record.bar)
    header:SetAttribute("restore-labbase", record.labbase)
    pcall(SecureHandlerExecute, header, ns.Snippets.RESTORE_BAR)

    SetRef("bar", restoreMainBar)
    SetRef("restore-bar", nil)
    header:SetAttribute("restore-labbase", nil)
    for i = 1, BUTTONS do
        SetRef("restore-button" .. i, nil)
        header:SetAttribute("restore-mode" .. i, nil)
        header:SetAttribute("restore-idx" .. i, nil)
        header:SetAttribute("restore-base" .. i, nil)
        header:SetAttribute("restore-labstate" .. i, nil)
    end
end

local function CaptureLabState(button, active, newLabStates)
    local saved = baseLabStates[button]
    local current = ReadAttr(button, "state")
    local state
    if active and saved ~= nil then
        state = saved
    elseif current ~= nil and current ~= "fp" then
        state = current
    else
        state = saved
    end
    if state ~= nil and state ~= "fp" then
        newLabStates[button] = state
        return state
    end
    return nil
end

local function AttachButton(i, button, active, prefix, normalizeShiftedMain, newLabStates, presetSlot)
    prefix = prefix or ""
    if not button then
        header:SetAttribute(prefix .. "mode" .. i, nil)
        header:SetAttribute(prefix .. "idx" .. i, nil)
        header:SetAttribute(prefix .. "base" .. i, nil)
        header:SetAttribute(prefix .. "labstate" .. i, nil)
        return nil, nil, nil, nil
    end

    local mode = ns.BarScan.ModeOf(button)
    local slot = ns.BarScan.BaseSlot(button, active)
        or presetSlot
        or ns.BarScan.BaseSlotOf(button)
        or i
    local index = ((slot - 1) % BUTTONS) + 1
    if normalizeShiftedMain and not ns.BarScan.HasActionBase(button)
        and ns.BarScan.IsBonusSlot(slot) then
        slot = index
    end

    local labstate
    if mode == "lab" then
        labstate = CaptureLabState(button, active, newLabStates)
    end

    header:SetAttribute(prefix .. "mode" .. i, mode)
    header:SetAttribute(prefix .. "idx" .. i, index)
    header:SetAttribute(prefix .. "base" .. i, slot)
    header:SetAttribute(prefix .. "labstate" .. i, labstate)
    return mode, slot, index, labstate
end

local function ModeSummary(counts)
    local summary = {}
    for mode, n in pairs(counts) do summary[#summary + 1] = mode .. " x" .. n end
    table.sort(summary)
    return table.concat(summary, ", ")
end

local function SnapshotCandidates()
    local byId = {}
    for index = 1, lastCandidateCount do
        local prefix = "candidate" .. index .. "-"
        local oldId = header:GetAttribute(prefix .. "id")
        local record = attachedCandidates[index]
        if oldId then
            byId[oldId] = {
                enabled = header:GetAttribute("candidate-enabled" .. index),
                applied = header:GetAttribute("candidate-applied" .. index) and true or false,
                labbase = record and record.labbase or header:GetAttribute(prefix .. "labbase"),
                bar = record and record.bar or nil,
                buttons = record and record.buttons or {},
            }
        end
    end
    return byId
end

function At.Attach(force)
    local name, list, count, found, assumedMainBase = ns.BarScan.Find(force)
    local active = header:GetAttribute("fp-active") and true or false
    local shifted = GetShapeshiftForm and (tonumber(GetShapeshiftForm()) or 0) > 0
    local normalizeShiftedMain = not active and (assumedMainBase or shifted)
    local db = ns.Settings.Get()

    local oldCandidatesById = SnapshotCandidates()
    local oldMain = attachedMain

    -- Skip the full-UI frame scan when the user has not selected any extra bars.
    local candidates = {}
    if db and #db.additionalBars > 0 then
        candidates = ns.BarScan.FindExtras(false, db.additionalBars, true)
    end

    local selectedById, candidateById = {}, {}
    for index, candidate in ipairs(candidates) do
        candidateById[candidate.id] = index
    end
    local normalizedBars, seenBars = {}, {}
    if db then
        for slot = 1, C.MAX_ADDITIONAL_BARS do
            local id = db.additionalBars[slot]
            if id then
                local _, canonicalId = ns.BarScan.ResolveCandidateId(candidates, id)
                local normalizedId = canonicalId or id
                if not seenBars[normalizedId] then
                    normalizedBars[#normalizedBars + 1] = normalizedId
                    seenBars[normalizedId] = true
                    selectedById[normalizedId] = #normalizedBars
                end
            end
        end
        db.additionalBars = normalizedBars
    end

    local bases, newLabStates, mainCounts = {}, {}, {}
    local currentMainButtons, mainRecords = {}, {}
    local bar
    for i = 1, BUTTONS do
        local button = list and list[i]
        SetRef("button" .. i, button)
        if button then
            local mode, slot, idx, labstate = AttachButton(
                i, button, active, "", normalizeShiftedMain, newLabStates, nil
            )
            bases[button] = slot
            currentMainButtons[button] = true
            mainRecords[i] = { frame = button, mode = mode, idx = idx, base = slot, labstate = labstate }
            mainCounts[mode] = (mainCounts[mode] or 0) + 1
            bar = bar or ns.BarScan.OwnerOf(button)
        else
            AttachButton(i, nil, active, "", false, newLabStates, nil)
        end
    end
    SetRef("bar", bar)
    local mainLabBase = SetBarState("", bar)
    local mainWrapped = WrapBar(bar)

    -- If the main bar changed while a form page was active, release any buttons
    -- that are no longer part of the attached main bar.
    local prevMainBar = oldMain and oldMain.bar or bar
    if active and oldMain then
        RestoreBarRecord(oldMain, currentMainButtons, nil, bar)
    end
    attachedMain = { bar = bar, labbase = mainLabBase, buttons = mainRecords }

    local newAttachedCandidates, keptCandidateIds = {}, {}
    for index, candidate in ipairs(candidates) do
        local prefix = "candidate" .. index .. "-"
        local prev = oldCandidatesById[candidate.id]
        local isSelected = selectedById[candidate.id] ~= nil
        local enabled = true
        if isSelected and prev and prev.enabled ~= nil then
            enabled = prev.enabled and true or false
        end
        local applied = (isSelected and prev and prev.applied) and true or nil
        if not isSelected and prev and prev.applied then
            RestoreBarRecord(prev, currentMainButtons, prevMainBar, bar)
        end

        header:SetAttribute(prefix .. "id", candidate.id)
        header:SetAttribute("candidate-selected" .. index, isSelected)
        header:SetAttribute("candidate-enabled" .. index, enabled)
        header:SetAttribute("candidate-applied" .. index, applied)

        local candidateBar, candidateCounts = nil, {}
        local buttonRecords, currentButtons = {}, {}
        for i = 1, BUTTONS do
            local button = candidate.buttons[i]
            SetRef(prefix .. "button" .. i, button)
            if button then
                local preset = not active and candidate.slots[i] or nil
                local mode, slot, idx, labstate = AttachButton(
                    i, button, active, prefix, false, newLabStates, preset
                )
                bases[button] = slot
                currentButtons[button] = true
                buttonRecords[i] = {
                    frame = button, mode = mode, idx = idx, base = slot, labstate = labstate,
                }
                candidateCounts[mode] = (candidateCounts[mode] or 0) + 1
                candidateBar = candidateBar or ns.BarScan.OwnerOf(button)
            else
                AttachButton(i, nil, active, prefix, false, newLabStates, nil)
            end
        end
        SetRef(prefix .. "bar", candidateBar)
        local candidateLabBase = SetBarState(prefix, candidateBar)
        if isSelected then WrapBar(candidateBar) end

        if isSelected and prev and prev.applied then
            RestoreBarRecord(prev, currentButtons, prevMainBar, bar)
        end
        newAttachedCandidates[index] = {
            bar = candidateBar,
            labbase = candidateLabBase,
            buttons = buttonRecords,
        }
        keptCandidateIds[candidate.id] = true
    end

    -- Clear any candidate slots beyond the current list.
    local clearLimit = math.max(lastCandidateCount, #candidates)
    for index = #candidates + 1, clearLimit do
        local prefix = "candidate" .. index .. "-"
        header:SetAttribute(prefix .. "id", nil)
        header:SetAttribute("candidate-selected" .. index, false)
        header:SetAttribute("candidate-enabled" .. index, nil)
        header:SetAttribute("candidate-applied" .. index, nil)
        SetRef(prefix .. "bar", nil)
        SetBarState(prefix, nil)
        for i = 1, BUTTONS do
            SetRef(prefix .. "button" .. i, nil)
            AttachButton(i, nil, active, prefix, false, newLabStates, nil)
        end
    end

    -- Restore any previously applied extra bar that is no longer in candidates
    -- (for example after clearing the last selected bar or hiding/removing it).
    for oldId, prev in pairs(oldCandidatesById) do
        if prev.applied and not keptCandidateIds[oldId] then
            RestoreBarRecord(prev, currentMainButtons, prevMainBar, bar)
        end
    end

    attachedCandidates = newAttachedCandidates
    lastCandidateCount = #candidates
    baseLabStates = newLabStates

    local extras, missingExtras, missingSelected, selectedIds = {}, {}, false, {}
    for slot = 1, C.MAX_ADDITIONAL_BARS do
        local id = normalizedBars[slot]
        local index = id and candidateById[id]
        header:SetAttribute("selectedCandidate" .. slot, index)
        if id then
            selectedIds[#selectedIds + 1] = id
            if index then
                local candidate = candidates[index]
                extras[#extras + 1] = {
                    id = candidate.id,
                    name = candidate.label,
                    display = ns.BarScan.FormatCandidate(candidate),
                    count = candidate.count,
                    visible = candidate.visibleCount > 0,
                    candidate = index,
                    slot = slot,
                }
            else
                missingSelected = true
                missingExtras[#missingExtras + 1] = { slot = slot, id = id }
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
        missingExtras = missingExtras,
        signature = signature,
        missingSelected = missingSelected,
    }
    return info.count
end

function At.Info()
    return info
end
