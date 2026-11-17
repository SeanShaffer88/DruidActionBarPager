-- Druid form detection. Reads the game's shapeshift API and keeps no settings.
-- Forms are matched by spell ID first, then by spell name, then by icon, so
-- detection keeps working if the client renumbers spells.
local _, ns = ...
local C = ns.Constants

local F = {}
ns.Forms = F

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

-- Spell IDs whose data has been requested and has not arrived yet.
local pendingSpellData = {}

-- GetShapeshiftFormInfo has returned different shapes across client versions:
--   modern:  icon, active, castable, spellID
--   1.12:    icon, name, active, castable
-- Returns spellID, name, icon for the form at index.
local function FormDetails(index)
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

-- The page key ("bear", "cat", ...) for the form at index, or nil.
local function ClassifyForm(index)
    local spellID, name, icon = FormDetails(index)

    if spellID and C.FORM_SPELLS[spellID] then
        return C.FORM_SPELLS[spellID]
    end

    if name then
        local lname = name:lower()
        for _, pair in ipairs(C.NAME_MATCH) do
            if lname:find(pair[1], 1, true) then
                return pair[2]
            end
        end
    end

    if type(icon) == "string" then
        local licon = icon:lower():gsub("[^%a]", "")
        for _, pair in ipairs(C.ICON_MATCH) do
            if licon:find(pair[1], 1, true) then
                return pair[2]
            end
        end
    end

    return nil
end

-- Number of shapeshift forms the player currently has.
function F.Count()
    return GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
end

-- The page key for the form at index, or nil if it isn't a known druid form.
F.Classify = ClassifyForm

-- Spell ID, name and icon of the form at index.
F.Details = FormDetails

-- A cheap summary of the form list (count, spell IDs, names, keys). It only
-- changes when forms are learned or the spell data they depend on loads, so
-- comparing it tells a real form-list change from an ordinary shift.
function F.Signature()
    local count = F.Count()
    local parts = {}
    for i = 1, count do
        local spellID, name = FormDetails(i)
        parts[#parts + 1] = tostring(spellID) .. ":" .. tostring(name) .. ":" .. tostring(ClassifyForm(i))
    end
    return count .. "|" .. table.concat(parts, ",")
end

-- Clears the pending request for spellID. Returns true if one was pending.
function F.TakePendingSpell(spellID)
    if not pendingSpellData[spellID] then return false end
    pendingSpellData[spellID] = nil
    return true
end
