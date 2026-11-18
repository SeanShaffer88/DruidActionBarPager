-- Runs one action-bar "family" fixture. FAMILY is set by the runner.
local H = dofile(TESTDIR .. "/harness.lua")
local results = {}
local function check(name, cond, detail)
    results[#results + 1] = (cond and "PASS " or "FAIL ") .. name .. (detail ~= nil and (" [" .. tostring(detail) .. "]") or "")
end

local FORMS = {
    { spellID = 5487, icon = 132276 },
    { spellID = 768,  icon = 132115 },
}
local NAMES = { [5487] = "Dire Bear Form", [768] = "Cat Form" }

-- Blizzard's own bar must not win in the addon families (it is hidden there).
local blizzard = {}
for i = 1, 12 do blizzard[i] = _G["ActionButton" .. i] end
local function hideBlizzard()
    for i = 1, 12 do blizzard[i].visible = false end
end

-- Mirrors LibActionButton-1.0's real UpdateState + ButtonContentsChanged + UpdateAction.
local LAB_UPDATE_STATE = [[
    local state = ...
    self:SetAttribute("state", state)
    local kind = self:GetAttribute(format("labtype-%s", tostring(state))) or "empty"
    local action = self:GetAttribute(format("labaction-%s", tostring(state)))
    self:SetAttribute("type", kind)
    if kind == "action" then
        self:SetAttribute("action", action)
    else
        self:SetAttribute("action", nil)
    end
]]

local function labButton(name, parent, slot, id, initialState)
    local st = initialState ~= nil and initialState or "0"
    local b = H.newFrame(name, true)
    if name then _G[name] = b end
    b.parent = parent
    b.id = id
    b.attrs.state = st
    b.attrs["labtype-" .. tostring(st)] = "action"
    b.attrs["labaction-" .. tostring(st)] = slot
    b.attrs.type = "action"
    b.attrs.action = slot
    b.attrs.UpdateState = LAB_UPDATE_STATE
    b.state_types = { [tostring(st)] = "action" }
    b.state_actions = { [tostring(st)] = slot }
    b._state_type = "action"
    b._state_action = slot
    b.action = 0
    b.UpdateAction = function(self)
        local cur = tostring(self.attrs.state)
        self._state_type = self.attrs["labtype-" .. cur] or "empty"
        self._state_action = self.attrs["labaction-" .. cur]
        self.action = self._state_type == "action" and (self._state_action or 0) or 0
    end
    b.ButtonContentsChanged = function(self, state, kind, value)
        local key = tostring(state)
        self.state_types[key] = kind or "empty"
        self.state_actions[key] = value
        self:UpdateAction()
    end
    return b
end

-- Fixed-slot button: slot in the "action" attribute (plus optional action-base).
local function fixedButton(name, parent, slot, id, withActionBase)
    local b = H.newFrame(name, true)
    if name then _G[name] = b end
    b.parent = parent
    b.id = id
    b.attrs.action = slot
    if withActionBase then b.attrs["action-base"] = slot end
    return b
end

local buttons, bar, expectMode, expectName
local EXPECT_FP = "action"

if FAMILY == "blizzard" then
    buttons = blizzard
    bar = H.mainBar
    expectMode, expectName = "page x12", "Blizzard"
elseif FAMILY == "bartender4" then
    hideBlizzard()
    bar = H.newFrame("BT4Bar1", true)
    bar.attrs.state = "0"
    buttons = {}
    for i = 1, 12 do buttons[i] = labButton("BT4Button" .. i, bar, i, i, "0") end
    expectMode, expectName, EXPECT_FP = "lab x12", "Bartender4", "lab"
elseif FAMILY == "azerite" then
    hideBlizzard()
    -- Standalone LAB bar with non-zero button state ("default") and no bar `state` attr.
    bar = H.newFrame("AzeriteActionBar1", true)
    buttons = {}
    for i = 1, 12 do buttons[i] = labButton("AzeriteActionBar1Button" .. i, bar, i, i, "default") end
    expectMode, expectName, EXPECT_FP = "lab x12", "AzeriteActionBar1Button (auto-detected)", "lab"
elseif FAMILY == "unnamed" then
    hideBlizzard()
    bar = H.newFrame(nil, true)
    buttons = {}
    for i = 1, 12 do buttons[i] = fixedButton(nil, bar, i, i, false) end
    expectMode, expectName = "action x12", "unnamed bar (auto-detected)"
elseif FAMILY == "dominos" then
    hideBlizzard()
    bar = H.newFrame("DominosActionBar1", true)
    buttons = {}
    -- Start already paged to Dominos default Bear page 9 (97..108) while action-base holds 1..12.
    for i = 1, 12 do
        local b = fixedButton("DominosActionButton" .. i, bar, 96 + i, nil, false)
        b.attrs["action-base"] = i
        buttons[i] = b
    end
    expectMode, expectName = "action x12", "Dominos"
elseif FAMILY == "ellesmere" then
    hideBlizzard()
    bar = H.newFrame("EABBar1", true)
    buttons = {}
    for i = 1, 12 do buttons[i] = fixedButton("EABButton" .. i, bar, i, nil, false) end
    expectMode, expectName = "action x12", "EllesmereUI"
elseif FAMILY == "neuron" then
    hideBlizzard()
    bar = H.newFrame("NeuronActionBar1", true)
    buttons = {}
    for i = 1, 12 do buttons[i] = fixedButton("NeuronActionBar1_ActionButton" .. i, bar, i, i, false) end
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
local gotName, gotModes = dbg:match("main bar: ([^,]+), %d+/12 buttons %(([^)]*)%)")
check("detected bar name = " .. expectName, gotName == expectName, gotName)
check("button modes = " .. expectMode, gotModes == expectMode, gotModes)

local okSlots = true
local badDetail
for i = 1, 12 do
    local b = buttons[i]
    local want = (6 - 1) * 12 + i
    if EXPECT_FP == "lab" then
        if b.attrs.state ~= "fp" or b.attrs.type ~= "action" or b._state_action ~= want then
            okSlots = false
            badDetail = badDetail or ("lab btn " .. i .. " = " .. tostring(b._state_action))
        end
    elseif FAMILY == "blizzard" then
        if b.attrs.actionpage ~= 6 or H.calculateBlizzardAction(b) ~= want then
            okSlots = false
            badDetail = badDetail or ("actionpage btn " .. i .. " = " .. tostring(b.attrs.actionpage))
        end
    else
        if b.attrs.action ~= want then
            okSlots = false
            badDetail = badDetail or ("action btn " .. i .. " = " .. tostring(b.attrs.action))
        end
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
    local want = (3 - 1) * 12 + i
    if EXPECT_FP == "lab" then
        if b.attrs.state ~= "fp" or b._state_action ~= want then p3 = false end
    elseif FAMILY == "blizzard" then
        if b.attrs.actionpage ~= 3 or H.calculateBlizzardAction(b) ~= want then p3 = false end
    else
        if b.attrs.action ~= want then p3 = false end
    end
end
check("page 3 shown on every button after re-scan", p3)
wipe(H.log)
SlashCmdList.DRUIDACTIONBARPAGER("debug")
local dbg2 = table.concat(H.log, "\n")
local n2, m2 = dbg2:match("main bar: ([^,]+), %d+/12 buttons %(([^)]*)%)")
check("same bar found after re-scan", n2 == expectName and m2 == expectMode, tostring(n2) .. " / " .. tostring(m2))
H.setForm(0)
H.gameEvaluate()
SlashCmdList.DRUIDACTIONBARPAGER("bear 6")
H.gameEvaluate()

-- Back to caster: verify every button genuinely restores original slot 1..12.
H.setForm(0)
H.gameEvaluate()
local restored = true
local restoreDetail
for i = 1, 12 do
    local b = buttons[i]
    if EXPECT_FP == "lab" then
        if b.attrs.type ~= "action" or b.attrs.action ~= i or b._state_action ~= i then
            restored = false
            restoreDetail = restoreDetail or ("lab btn " .. i .. " state=" .. tostring(b.attrs.state)
                .. " type=" .. tostring(b.attrs.type) .. " act=" .. tostring(b._state_action))
        end
    elseif FAMILY == "blizzard" then
        if b.attrs.actionpage ~= nil or H.calculateBlizzardAction(b) ~= i then
            restored = false
            restoreDetail = restoreDetail or ("blizz btn " .. i .. " page=" .. tostring(b.attrs.actionpage))
        end
    else
        if b.attrs.action ~= i then
            restored = false
            restoreDetail = restoreDetail or ("action btn " .. i .. " = " .. tostring(b.attrs.action))
        end
    end
end
check("caster form restores slots 1-12 on every button", restored and header.attrs["fp-page"] == nil, restoreDetail)

for _, r in ipairs(results) do print(FAMILY .. ": " .. r) end
return table.concat(results, "\n")
