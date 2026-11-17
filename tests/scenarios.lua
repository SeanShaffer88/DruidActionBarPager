local H = dofile(TESTDIR .. "/harness.lua")
local results = {}
local function check(name, cond, detail)
    results[#results + 1] = (cond and "PASS " or "FAIL ") .. name .. (detail and (" [" .. tostring(detail) .. "]") or "")
end

local FORMS = {
    { spellID = 5487, icon = "Ability_Racial_BearForm" },   -- bear
    { spellID = 768,  icon = "Ability_Druid_CatForm" },     -- cat
    { spellID = 24858, icon = "Spell_Nature_ForceOfNature" }, -- moonkin
}
local NAMES = { [5487] = "Dire Bear Form", [768] = "Cat Form", [24858] = "Moonkin Form" }

-- Scenario 1: /reload while in bear form, saved bear=6, cat=7.
H.setForms(FORMS, NAMES)
H.setForm(1)
H.load(ADDON_FILES, { enabled = true, version = 3, pages = { bear = 6, cat = 7, travel = 0, aquatic = 0, moonkin = 4, tree = 4 } })
local header = H.header()
check("S1 bar hook: MainMenuBar wrapped (Blizzard page-mode buttons)", #H.wrapCalls > 0 and H.wrapCalls[1] == "MainMenuBar", table.concat(H.wrapCalls, ","))
check("S1 registration leaves state armed for next evaluation", header.attrs["state-formpage"] == "refresh", header.attrs["state-formpage"])
H.gameEvaluate() -- next game-driven evaluation (e.g. UPDATE_SHAPESHIFT_FORMS while still in bear)
check("S1 page 6 applied after next shapeshift evaluation", header.attrs["fp-page"] == 6, tostring(header.attrs["fp-page"]))
check("S1 Blizzard buttons overridden to page 6", H.buttons[1].attrs.actionpage == 6 and H.buttons[12].attrs.actionpage == 6,
    tostring(H.buttons[1].attrs.actionpage))

-- Scenario 2: shift to cat, back to bear.
H.setForm(2); H.gameEvaluate()
check("S2 cat -> page 7", header.attrs["fp-page"] == 7 and H.buttons[1].attrs.actionpage == 7, tostring(header.attrs["fp-page"]))
H.setForm(1); H.gameEvaluate()
check("S2 bear again -> page 6", header.attrs["fp-page"] == 6 and H.buttons[1].attrs.actionpage == 6, tostring(header.attrs["fp-page"]))

-- Scenario 3: a plain shift fires UPDATE_SHAPESHIFT_FORMS but the form list is unchanged.
H.runTimers()
H.fire("UPDATE_SHAPESHIFT_FORMS")
H.runTimers()
local before = H.pendingTimers()
H.fire("UPDATE_SHAPESHIFT_FORMS")
check("S3 unchanged form list on shift: no rebuild scheduled", H.pendingTimers() == 0, H.pendingTimers())

-- Scenario 4: learning a new form does trigger a rebuild.
local extended = { FORMS[1], FORMS[2], FORMS[3], { spellID = 1066, icon = "Ability_Druid_AquaticForm" } }
H.setForms(extended, NAMES)
H.fire("UPDATE_SHAPESHIFT_FORMS")
check("S4 new form learned: rebuild scheduled", H.pendingTimers() == 1, H.pendingTimers())
H.runTimers()

-- Scenario 5: caster form restores the normal bar.
H.setForm(0); H.gameEvaluate()
check("S5 caster form gives the bar back", header.attrs["fp-page"] == nil and H.buttons[1].attrs.actionpage == nil, tostring(header.attrs["fp-page"]))

-- Scenario 6: /dabp debug reports the hook.
H.log[#H.log] = nil
SlashCmdList.DRUIDACTIONBARPAGER("debug")
local dbg = table.concat(H.log, "\n")
check("S6 debug reports bar hooked", dbg:find("hooked into the bar's own paging: yes", 1, true) ~= nil)

for _, r in ipairs(results) do print(r) end
return table.concat(results, "\n")
