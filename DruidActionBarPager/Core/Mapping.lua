-- Read-only panel/debug snapshots. Discovery runs only on explicit request.
local _, ns = ...
local C = ns.Constants
local M = {}
ns.Mapping = M
local candidates = {}

function M.Discover()
    local db = ns.Settings.Get()
    if not db then return {} end
    candidates = ns.BarScan.FindExtras(false, db.additionalBars, true)
    return candidates
end

function M.Candidates()
    return candidates
end

local function Parse(condition)
    if not SecureCmdOptionParse then return nil end
    local ok, result = pcall(SecureCmdOptionParse, condition)
    if ok then return tonumber(result) end
end

function M.Snapshot()
    local db = ns.Settings.Get()
    if not db then return { state = "Settings unavailable", rows = {}, extras = {}, warnings = {} } end
    local info, header = ns.Attach.Info(), ns.Frames.header
    local learned, rows, extras, warnings, pages = {}, {}, {}, {}, {}
    local form = GetShapeshiftForm and GetShapeshiftForm() or 0
    for index = 1, ns.Forms.Count() do learned[ns.Forms.Classify(index) or "?"] = true end
    for _, key in ipairs(C.FORM_ORDER) do
        rows[#rows + 1] = { key = key, name = C.FORM_LABELS[key], page = db.pages[key], learned = learned[key] or false }
    end
    rows[#rows + 1] = { key = "prowl", name = "Cat + Prowl", page = db.prowlPage, learned = learned.cat or false }
    if db.prowlPage > 0 and not ns.Conditions.ProwlSupported() then
        warnings[#warnings + 1] = "Prowl conditional unavailable; Cat mapping remains active."
    end
    for _, row in ipairs(rows) do
        if row.page > 0 then
            if pages[row.page] then
                warnings[#warnings + 1] = row.name .. " shares page " .. row.page .. " (slots "
                    .. ((row.page - 1) * C.BUTTONS_PER_PAGE + 1) .. "-" .. (row.page * C.BUTTONS_PER_PAGE)
                    .. ") with " .. pages[row.page] .. "."
            else pages[row.page] = row.name end
        end
    end
    for _, extra in ipairs(info.extras) do
        local enabled = header:GetAttribute("candidate-enabled" .. extra.candidate)
        local applied = header:GetAttribute("candidate-applied" .. extra.candidate)
        extras[extra.slot] = {
            id = extra.id, name = extra.display or extra.name,
            status = not enabled and "Paused; normal page"
                or (applied and ("Mirroring page " .. tostring(header:GetAttribute("fp-page")))
                    or "Mirror configured; normal bar"),
        }
    end
    for _, missing in ipairs(info.missingExtras or {}) do
        extras[missing.slot] = { id = missing.id, name = missing.id, status = "Missing bar" }
    end
    -- Blizzard's optional bars expose the same stored action slots as form pages.
    local optional = {
        { "MultiBarBottomLeftButton1", 6 }, { "MultiBarBottomRightButton1", 5 },
        { "MultiBarRightButton1", 3 }, { "MultiBarLeftButton1", 4 },
    }
    for _, entry in ipairs(optional) do
        local button = _G[entry[1]]
        local ok, visible = false, false
        if button and button.IsVisible then ok, visible = pcall(button.IsVisible, button) end
        if ok and visible and pages[entry[2]] then
            warnings[#warnings + 1] = pages[entry[2]] .. " uses page " .. entry[2]
                .. " (slots " .. ((entry[2] - 1) * C.BUTTONS_PER_PAGE + 1) .. "-" .. (entry[2] * C.BUTTONS_PER_PAGE)
                .. "), also displayed by " .. entry[1]:gsub("Button1$", "") .. "."
        end
    end
    local desired = Parse(ns.Conditions.Build(db))
    local applied = header:GetAttribute("fp-page")
    local yielded = Parse(C.OVERRIDE_CONDITION .. ";1") == 0
    local state
    if ns.Rebuild.IsPending() then state = "Pending combat changes"
    elseif not db.enabled then state = "Disabled"
    elseif not info.found then state = "Main bar not found"
    elseif yielded then state = "Yielding to game override"
    elseif applied then state = "DABP owns page " .. applied
    else state = "Normal bar owns paging" end
    return {
        state = state, form = form, desired = desired, applied = applied,
        rows = rows, extras = extras, warnings = warnings,
        owner = info.name, compatibility = ns.Compatibility.Describe(info.name),
        enabled = db.enabled,
    }
end
