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
H.setBindingKey("DABP_TOGGLE_EXTRA1", "F9")
H.setBindingKey("DABP_TOGGLE_EXTRA2", "F10")
H.setBindingKey("DABP_TOGGLE_EXTRA3", "F11")
H.setBindingKey("DABP_TOGGLE_ALL_EXTRAS", "SHIFT-F12")

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
check("S3 found bar skips the late rescan", H.pendingTimers() == 0, H.pendingTimers())
H.fire("UPDATE_SHAPESHIFT_FORMS")
check("S3 first unchanged shift after login skips rebuild", H.pendingTimers() == 0, H.pendingTimers())
H.fire("UPDATE_SHAPESHIFT_FORMS")
check("S3 later unchanged shifts skip rebuild", H.pendingTimers() == 0, H.pendingTimers())

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
check("S6 debug confirms bar detection", dbg:find("main bar detected: yes", 1, true) ~= nil)

-- Scenario 7: select three extra bars, bind per-bar and global secure toggles.
local function addExtraBar(name, firstSlot)
    local bar = H.newFrame(name, true)
    for i = 1, 12 do
        local button = H.newFrame(name .. "Button" .. i, true)
        button.parent = bar
        button.id = i
        button.attrs.action = firstSlot + i - 1
    end
end
addExtraBar("TestBar2", 13)
addExtraBar("TestBar3", 25)
addExtraBar("TestBar4", 37)
H.setForm(1)
H.gameEvaluate()

local overrides = {}
for _, binding in ipairs(H.bindingOverrides) do overrides[binding.key] = binding.buttonName end
check("S7 individual hotkeys bind secure toggle buttons",
    overrides.F9 == "DruidActionBarPagerToggleExtra1"
        and overrides.F10 == "DruidActionBarPagerToggleExtra2"
        and overrides.F11 == "DruidActionBarPagerToggleExtra3")
check("S7 all-bars hotkey binds secure toggle button",
    overrides["SHIFT-F12"] == "DruidActionBarPagerToggleAllExtras")

H.log[#H.log] = nil
SlashCmdList.DRUIDACTIONBARPAGER("bars")
local listed = table.concat(H.log, "\n")
check("S7 bar list finds all three extra bars",
    listed:find("TestBar2Button", 1, true) ~= nil
        and listed:find("TestBar3Button", 1, true) ~= nil
        and listed:find("TestBar4Button", 1, true) ~= nil)
SlashCmdList.DRUIDACTIONBARPAGER("bar 1 on")
SlashCmdList.DRUIDACTIONBARPAGER("bar 2 on")
SlashCmdList.DRUIDACTIONBARPAGER("bar 3 on")
H.gameEvaluate()
local extra1 = header.refs["candidate1-button1"]
local extra2 = header.refs["candidate2-button1"]
local extra3 = header.refs["candidate3-button1"]
check("S7 selected extra bars mirror page 6",
    extra1 and extra1.attrs.action == 61
        and extra2 and extra2.attrs.action == 61
        and extra3 and extra3.attrs.action == 61,
    tostring(extra1 and extra1.attrs.action) .. "," .. tostring(extra2 and extra2.attrs.action) .. "," .. tostring(extra3 and extra3.attrs.action))
check("S7 main bar keeps paging with extras selected", H.buttons[1].attrs.actionpage == 6)

H.clickSecure(_G.DruidActionBarPagerToggleExtra1)
check("S7 individual toggle restores only extra bar 1",
    extra1.attrs.action == 13 and extra2.attrs.action == 61 and extra3.attrs.action == 61)
H.clickSecure(_G.DruidActionBarPagerToggleExtra1)
check("S7 individual toggle resumes extra bar 1", extra1.attrs.action == 61)
H.clickSecure(_G.DruidActionBarPagerToggleExtra2)
check("S7 individual toggle controls selected extra bar 2",
    extra1.attrs.action == 61 and extra2.attrs.action == 25 and extra3.attrs.action == 61)
H.clickSecure(_G.DruidActionBarPagerToggleExtra2)
H.clickSecure(_G.DruidActionBarPagerToggleExtra3)
check("S7 individual toggle controls selected extra bar 3",
    extra1.attrs.action == 61 and extra2.attrs.action == 61 and extra3.attrs.action == 37)
H.clickSecure(_G.DruidActionBarPagerToggleExtra3)
H.clickSecure(_G.DruidActionBarPagerToggleAllExtras)
check("S7 all toggle restores extras but not main bar",
    extra1.attrs.action == 13 and extra2.attrs.action == 25 and extra3.attrs.action == 37
        and H.buttons[1].attrs.actionpage == 6)
H.clickSecure(_G.DruidActionBarPagerToggleAllExtras)
check("S7 all toggle resumes selected extras",
    extra1.attrs.action == 61 and extra2.attrs.action == 61 and extra3.attrs.action == 61)

SlashCmdList.DRUIDACTIONBARPAGER("bar 1 off")
H.gameEvaluate()
check("S7 removing a selected bar restores its original slot",
    extra1.attrs.action == 13 and extra2.attrs.action == 61 and extra3.attrs.action == 61)
check("S7 deselection keeps remaining stable IDs", #DruidActionBarPagerDB.additionalBars == 2)

for _, r in ipairs(results) do print(r) end
return table.concat(results, "\n")
