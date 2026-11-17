-- Runs one action-bar "family" fixture. FAMILY is set by the runner.
local H = dofile(TESTDIR .. "/harness.lua")
local results = {}
local function check(name, cond, detail)
    results[#results + 1] = (cond and "PASS " or "FAIL ") .. name .. (detail ~= nil and (" [" .. tostring(detail) .. "]") or "")
end

local FORMS = {
    { spellID = 5487, icon = "Ability_Racial_BearForm" },
    { spellID = 768, icon = "Ability_Druid_CatForm" },
}
local NAMES = { [5487] = "Dire Bear Form", [768] = "Cat Form" }

-- Blizzard's own bar must not win in the addon families (it is hidden there).
local blizzard = {}
for i = 1, 12 do blizzard[i] = _G["ActionButton" .. i] end
local function hideBlizzard()
    for i = 1, 12 do blizzard[i].visible = false end
end

-- LibActionButton-style button: slot in _state_action, .action = 0, UpdateState set.
local function labButton(name, parent, slot, id)
    local b = H.newFrame(name, true)
    if name then _G[name] = b end
    b.parent = parent
    b.id = id
    b.attrs.UpdateState = "-- LAB UpdateState (not run here)"
    b.state_types = {}
    b._state_type = "action"
    b._state_action = slot
    b.action = 0
    return b
end

-- Fixed-slot button: slot in the "action" attribute.
local function fixedButton(name, parent, slot, id)
    local b = H.newFrame(name, true)
    if name then _G[name] = b end
    b.parent = parent
    b.id = id
    b.attrs.action = slot
    return b
end

local buttons, bar, expectMode, expectName, expectLabel
local EXPECT_FP = "action" -- where the page's slot is checked: "action" or "lab"

if FAMILY == "blizzard" then
    buttons = blizzard
    bar = H.mainBar
    expectMode, expectName = "page x12", "Blizzard"
elseif FAMILY == "bartender4" then
    hideBlizzard()
    bar = H.newFrame("BT4Bar1", true)
    buttons = {}
    for i = 1, 12 do buttons[i] = labButton("BT4Button" .. i, bar, i, i) end
    expectMode, expectName, EXPECT_FP = "lab x12", "Bartender4", "lab"
elseif FAMILY == "azerite" then
    hideBlizzard()
    bar = H.newFrame("AzeriteActionBar1", true)
    buttons = {}
    for i = 1, 12 do buttons[i] = labButton("AzeriteActionBar1Button" .. i, bar, i, i) end
    expectMode, expectName, EXPECT_FP = "lab x12", "AzeriteActionBar1Button (auto-detected)", "lab"
elseif FAMILY == "unnamed" then
    hideBlizzard()
    bar = H.newFrame(nil, true) -- unnamed bar frame, unnamed buttons
    buttons = {}
    for i = 1, 12 do buttons[i] = fixedButton(nil, bar, i, i) end
    expectMode, expectName = "action x12", "unnamed bar (auto-detected)"
elseif FAMILY == "dominos" then
    hideBlizzard()
    bar = H.newFrame("DominosActionBar1", true)
    buttons = {}
    for i = 1, 12 do buttons[i] = fixedButton("DominosActionButton" .. i, bar, i, nil) end
    expectMode, expectName = "action x12", "Dominos"
elseif FAMILY == "ellesmere" then
    hideBlizzard()
    bar = H.newFrame("EABBar1", true)
    buttons = {}
    for i = 1, 12 do buttons[i] = fixedButton("EABButton" .. i, bar, i, nil) end
    expectMode, expectName = "action x12", "EllesmereUI"
elseif FAMILY == "neuron" then
    hideBlizzard()
    bar = H.newFrame("NeuronActionBar1", true)
    buttons = {}
    for i = 1, 12 do buttons[i] = fixedButton("NeuronActionBar1_ActionButton" .. i, bar, i, i) end
    expectMode, expectName = "action x12", "Neuron"
else
    error("unknown family " .. tostring(FAMILY))
end

H.setForms(FORMS, NAMES)
H.setForm(1)
H.load(ADDON_FILES, { enabled = true, version = 3,
    pages = { bear = 6, cat = 7, travel = 0, aquatic = 0, moonkin = 4, tree = 4 } })
H.gameEvaluate()

local header = H.header()
check("applied page 6", header.attrs["fp-page"] == 6, tostring(header.attrs["fp-page"]))

SlashCmdList.DRUIDACTIONBARPAGER("debug")
local dbg = table.concat(H.log, "\n")
local gotLine = dbg:match("main bar: ([^\n]-), 12/12 buttons %(([^)]*)%)")
local gotName, gotModes = dbg:match("main bar: ([^,]+), %d+/12 buttons %(([^)]*)%)")
check("detected bar name = " .. expectName, gotName == expectName, gotName)
check("button modes = " .. expectMode, gotModes == expectMode, gotModes)

local okSlots = true
local badDetail
for i = 1, 12 do
    local b = buttons[i]
    local want = (6 - 1) * 12 + i
    local got
    if EXPECT_FP == "lab" then
        got = b.attrs["labaction-fp"]
        if got ~= want then okSlots = false; badDetail = badDetail or ("lab btn " .. i .. " = " .. tostring(got)) end
    elseif FAMILY == "blizzard" then
        got = b.attrs.actionpage
        if got ~= 6 then okSlots = false; badDetail = badDetail or ("actionpage btn " .. i .. " = " .. tostring(got)) end
    else
        got = b.attrs.action
        if got ~= want then okSlots = false; badDetail = badDetail or ("action btn " .. i .. " = " .. tostring(got)) end
    end
end
check("every button shows page 6 (" .. EXPECT_FP .. ")", okSlots, badDetail)

check("bar hooked for paging", #H.wrapCalls > 0, table.concat(H.wrapCalls, ","))

-- Change the bear page while bear is active: forced re-scan with a page applied.
SlashCmdList.DRUIDACTIONBARPAGER("bear 3")
H.gameEvaluate()
check("bear 3 applied while active", header.attrs["fp-page"] == 3, tostring(header.attrs["fp-page"]))
local p3 = true
for i = 1, 12 do
    local b = buttons[i]
    if EXPECT_FP == "lab" then
        if b.attrs["labaction-fp"] ~= (3 - 1) * 12 + i then p3 = false end
    elseif FAMILY == "blizzard" then
        if b.attrs.actionpage ~= 3 then p3 = false end
    else
        if b.attrs.action ~= (3 - 1) * 12 + i then p3 = false end
    end
end
check("page 3 shown on every button after re-scan", p3)
H.log[#H.log] = nil
SlashCmdList.DRUIDACTIONBARPAGER("debug")
local dbg2 = table.concat(H.log, "\n")
local n2, m2 = dbg2:match("main bar: ([^,]+), %d+/12 buttons %(([^)]*)%)")
check("same bar found after re-scan", n2 == expectName and m2 == expectMode, tostring(n2) .. " / " .. tostring(m2))
H.setForm(0)
H.gameEvaluate()
SlashCmdList.DRUIDACTIONBARPAGER("bear 6")
H.gameEvaluate()

-- Back to caster: buttons restored.
H.setForm(0)
H.gameEvaluate()
local restored = true
for i = 1, 12 do
    local b = buttons[i]
    if EXPECT_FP == "lab" then
        if b.attrs["labaction-fp"] ~= nil and header.attrs["fp-page"] ~= nil then restored = false end
    elseif FAMILY == "blizzard" then
        if b.attrs.actionpage ~= nil then restored = false end
    else
        if b.attrs.action ~= i then restored = false end
    end
end
check("caster form restores the normal bar", restored and header.attrs["fp-page"] == nil)

for _, r in ipairs(results) do print(FAMILY .. ": " .. r) end
return table.concat(results, "\n")
