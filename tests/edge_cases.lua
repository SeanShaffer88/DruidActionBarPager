-- Comprehensive offline regression and edge-case checks for DruidActionBarPager.
-- Each subcase runs in a fresh harness instance via CASE supplied by tests/run.py.
local H = dofile(TESTDIR .. "/harness.lua")
local results = {}
local function check(name, cond, detail)
    results[#results + 1] = (cond and "PASS " or "FAIL ") .. name
        .. (detail ~= nil and (" [" .. tostring(detail) .. "]") or "")
end

local BEAR_CAT = {
    { spellID = 5487, icon = 132276 },
    { spellID = 768,  icon = 132115 },
}
local BEAR_CAT_NAMES = { [5487] = "Bear Form", [768] = "Cat Form" }

local function makeFixedBar(name, prefix, firstSlot, insertBeforeName, visible)
    local start = #H.allFrames + 1
    local bar = H.newFrame(name, true)
    bar.visible = visible ~= false
    local list = {}
    for i = 1, 12 do
        local b = H.newFrame((prefix or (name .. "Button")) .. i, true)
        b.parent = bar
        b.visible = visible ~= false
        b.attrs.action = firstSlot + i - 1
        _G[b.name] = b
        list[i] = b
    end
    if insertBeforeName then
        local created = {}
        for i = start, #H.allFrames do created[#created + 1] = H.allFrames[i] end
        for i = #H.allFrames, start, -1 do table.remove(H.allFrames, i) end
        for idx, f in ipairs(H.allFrames) do
            if f.name == insertBeforeName then
                for j = #created, 1, -1 do table.insert(H.allFrames, idx, created[j]) end
                break
            end
        end
    end
    return bar, list
end

if CASE == "restricted" then
    -- E1: Restricted closure enforcement & snippet validation.
    local f1, e1 = H.buildRestrictedClosure("local function x() end", {})
    check("E1 harness rejects function keyword in snippets",
        f1 == nil and e1 == "The function keyword is not permitted", e1)
    local f2, e2 = H.buildRestrictedClosure("local t = {}", {})
    check("E1 harness rejects table literals in snippets",
        f2 == nil and e2 == "Direct table creation is not permitted", e2)

    local ns = H.load(ADDON_FILES, nil)
    local snippets = {
        { "FORMPAGE",    ns.Snippets.FORMPAGE,    "self,stateid,newstate" },
        { "APPLY_BAR",   ns.Snippets.APPLY_BAR,   "self,..." },
        { "APPLY",       ns.Snippets.APPLY,       "self,..." },
        { "WRAP_PRE",    ns.Snippets.WRAP_PRE,    "self,name,value" },
        { "WRAP_POST",   ns.Snippets.WRAP_POST,   "self,message,name,value" },
        { "RESTORE_BAR", ns.Snippets.RESTORE_BAR, "self" },
        { "TOGGLE_1",    ns.KeyBindings.Buttons[1].attrs["_onclick"], "self,button,down" },
        { "TOGGLE_2",    ns.KeyBindings.Buttons[2].attrs["_onclick"], "self,button,down" },
        { "TOGGLE_3",    ns.KeyBindings.Buttons[3].attrs["_onclick"], "self,button,down" },
        { "TOGGLE_ALL",  ns.KeyBindings.AllButton.attrs["_onclick"],  "self,button,down" },
    }
    local allValid, bad = true, nil
    for _, item in ipairs(snippets) do
        local fn, err = H.buildRestrictedClosure(item[2], {}, item[3], "=" .. item[1])
        if not fn then allValid = false; bad = item[1] .. ": " .. tostring(err); break end
    end
    check("E1 all 10 restricted snippets satisfy BuildRestrictedClosure", allValid, bad)

elseif CASE == "multibars" then
    -- E2: Blizzard MultiBarBottomLeft (page 6) + MultiBar5 (page 13, slots 145-156)
    -- and a third-party bar on page 14 (slots 157-168).
    local _, mbLeft = H.makeBlizzardBar("MultiBarBottomLeft", "MultiBarBottomLeftButton", 6, true, true)
    local _, mb5 = H.makeBlizzardBar("MultiBar5", "MultiBar5Button", 13, true, true)
    local _, highBar = makeFixedBar("DominosActionBar14", "DominosHighButton", 157)

    H.setForms(BEAR_CAT, BEAR_CAT_NAMES)
    H.load(ADDON_FILES, nil)
    SlashCmdList.DRUIDACTIONBARPAGER("bar 1 on") -- DominosHighButton@157
    SlashCmdList.DRUIDACTIONBARPAGER("bar 2 on") -- MultiBar5Button@145
    SlashCmdList.DRUIDACTIONBARPAGER("bar 3 on") -- MultiBarBottomLeftButton@61

    H.setForm(1); H.gameEvaluate() -- Bear page 2 (slots 13..24)
    check("E2 Blizzard MultiBarBottomLeft mirrors page 2 via actionpage",
        mbLeft[1].attrs.actionpage == 2
            and H.calculateBlizzardAction(mbLeft[1]) == 13
            and H.calculateBlizzardAction(mbLeft[12]) == 24,
        H.calculateBlizzardAction(mbLeft[1]))
    check("E2 Blizzard MultiBar5 (page 13 / slots 145-156) discovered and mirrors page 2",
        mb5[1].attrs.actionpage == 2
            and H.calculateBlizzardAction(mb5[1]) == 13
            and H.calculateBlizzardAction(mb5[12]) == 24,
        H.calculateBlizzardAction(mb5[1]))
    check("E2 third-party high-slot bar (slots 157-168) discovered and mirrors page 2",
        highBar[1].attrs.action == 13 and highBar[12].attrs.action == 24,
        highBar[1].attrs.action)

    H.setForm(0); H.gameEvaluate() -- Caster restores 61..72, 145..156, 157..168
    check("E2 caster restores MultiBarBottomLeft (61), MultiBar5 (145), and high bar (157)",
        mbLeft[1].attrs.actionpage == nil and H.calculateBlizzardAction(mbLeft[1]) == 61
            and mb5[1].attrs.actionpage == nil and H.calculateBlizzardAction(mb5[1]) == 145
            and highBar[1].attrs.action == 157)

elseif CASE == "reorder" then
    -- E3: Candidate reordering, stale candidate-applied, pause preservation, and >10 cap.
    local _, barB = makeFixedBar("BarB", nil, 25)
    local _, barZ = makeFixedBar("ZetaBar", nil, 109)
    H.setForms(BEAR_CAT, BEAR_CAT_NAMES)
    H.load(ADDON_FILES, nil)
    H.runTimers()

    SlashCmdList.DRUIDACTIONBARPAGER("bar 1 on") -- BarB (slot 1)
    SlashCmdList.DRUIDACTIONBARPAGER("bar 2 on") -- ZetaBar (slot 2)
    H.setForm(1); H.gameEvaluate() -- Bear page 2 -> slots 13..24
    H.clickSecure(_G.DruidActionBarPagerToggleExtra1) -- pause BarB (-> 25); ZetaBar stays active (13)
    check("E3 initial pause restores BarB while ZetaBar stays paged",
        barB[1].attrs.action == 25 and barZ[1].attrs.action == 13)

    -- Insert unselected BarA (with parent actionpage=9) before BarB.
    local barAFrame, barA = makeFixedBar("BarA", nil, 37, "BarB")
    barAFrame.attrs.actionpage = 9
    H.fire("PLAYER_ENTERING_WORLD"); H.runTimers(); H.gameEvaluate()
    check("E3 paused BarB keeps pause state after index shift",
        barB[1].attrs.action == 25, barB[1].attrs.action)
    check("E3 unselected BarA is not overwritten by stale candidate-applied",
        barA[1].attrs.action == 37, barA[1].attrs.action)

    -- Add 10 alphabetically earlier unselected bars; selected ZetaBar stays inside cap.
    for k = 1, 10 do
        makeFixedBar("Mid" .. string.char(64 + k) .. "Bar", nil, 49, "ZetaBar")
    end
    H.fire("PLAYER_ENTERING_WORLD"); H.runTimers(); H.gameEvaluate()
    check("E3 selected ZetaBar survives >10 candidate cap and keeps mirroring",
        barZ[1].attrs.action == 13 and H.header().attrs["selectedCandidate2"] ~= nil,
        tostring(barZ[1].attrs.action))

    -- Clear all extra bars while still in Bear: ZetaBar immediately restores to 109.
    SlashCmdList.DRUIDACTIONBARPAGER("bar clear")
    H.gameEvaluate()
    check("E3 clearing extras restores ZetaBar to original slot 109 while main stays on page 2",
        barZ[1].attrs.action == 109 and barA[1].attrs.action == 37
            and H.buttons[1].attrs.actionpage == 2,
        tostring(barZ[1].attrs.action))

    -- Reselecting a previously paused bar starts enabled again.
    SlashCmdList.DRUIDACTIONBARPAGER("bar 2 on") -- BarB
    H.gameEvaluate()
    check("E3 reselected BarB starts enabled (not stuck paused)",
        barB[1].attrs.action == 13, barB[1].attrs.action)

    -- Shared-parent extra bar restores its own base slot instead of main bar's actionpage=1.
    local sharedExtra = {}
    for i = 1, 12 do
        local b = H.newFrame("ASharedButton" .. i, true)
        b.parent = H.mainBar -- shares mainBar whose actionpage == 1!
        b.attrs.action = 84 + i -- slots 85..96
        _G[b.name] = b
        sharedExtra[i] = b
    end
    SlashCmdList.DRUIDACTIONBARPAGER("bar clear")
    wipe(H.log)
    SlashCmdList.DRUIDACTIONBARPAGER("bars")
    local idx = table.concat(H.log, "\n"):match("(%d+)%. ASharedButton")
    SlashCmdList.DRUIDACTIONBARPAGER("bar " .. idx .. " on")
    H.gameEvaluate()
    H.setForm(0); H.gameEvaluate()
    check("E3 extra bar sharing main bar parent restores own base slot 85 (not main actionpage 1)",
        sharedExtra[1].attrs.action == 85, sharedExtra[1].attrs.action)

elseif CASE == "override_and_wrap" then
    -- E4 & E5: Override/vehicle/possess guards and precise WRAP_PRE/WRAP_POST hooks.
    for i = 1, 12 do H.buttons[i].visible = false end
    local dbar, dbtns = makeFixedBar("DominosActionBar1", "DominosActionButton", 1)
    local ebar, ebtns = makeFixedBar("NeuronActionBar2", "NeuronActionBar2_ActionButton", 25)
    H.setForms(BEAR_CAT, BEAR_CAT_NAMES)
    H.load(ADDON_FILES, nil)
    SlashCmdList.DRUIDACTIONBARPAGER("bar 1 on")

    -- Shift to Bear (page 2 -> slots 13..24) in combat.
    H.setCombat(true, true)
    H.setForm(1); H.gameEvaluate()
    check("E4 Bear applies page 2 on main and extra bar in combat",
        dbtns[1].attrs.action == 13 and ebtns[1].attrs.action == 13)

    -- Dominos tries to flip main bar via state-page -> WRAP_POST restores page 2 on main only.
    ebtns[1].attrs.action = 99 -- sentinel: extra bar must not be touched when main bar fires
    dbtns[1].attrs.action = 97 -- Dominos bear page 9
    H.setBarAttrSecure(dbar, "state-page", "bear")
    check("E5 state-page on main bar reapplies main bar without touching extra bar",
        dbtns[1].attrs.action == 13 and ebtns[1].attrs.action == 99,
        tostring(dbtns[1].attrs.action) .. "/" .. tostring(ebtns[1].attrs.action))

    -- Neuron changes state-stance on extra bar -> WRAP_POST reapplies extra bar only.
    dbtns[1].attrs.action = 88
    ebtns[1].attrs.action = 25
    H.setBarAttrSecure(ebar, "state-stance", 1)
    check("E5 state-stance on extra bar reapplies extra bar without touching main bar",
        ebtns[1].attrs.action == 13 and dbtns[1].attrs.action == 88,
        tostring(ebtns[1].attrs.action) .. "/" .. tostring(dbtns[1].attrs.action))
    dbtns[1].attrs.action = 13

    -- Direct actionpage mutation is also caught by WRAP_PRE.
    dbtns[1].attrs.action = 1
    H.setBarAttrSecure(dbar, "actionpage", 9)
    check("E5 direct actionpage change reapplies form page",
        dbtns[1].attrs.action == 13, dbtns[1].attrs.action)
    dbar.attrs.actionpage = nil

    -- Unrelated state-* attrs (smart-target, visibility, overridebar) do NOT trigger reapply.
    dbtns[1].attrs.action = 55
    H.setBarAttrSecure(dbar, "state-target-help", "help")
    H.setBarAttrSecure(dbar, "state-visibility", "show")
    H.setBarAttrSecure(dbar, "state-overridebar", true)
    check("E5 unrelated state-target/visibility/overridebar attrs do not reapply",
        dbtns[1].attrs.action == 55, dbtns[1].attrs.action)
    dbtns[1].attrs.action = 13

    -- Enter vehicle while Bear form aura remains active: driver resolves to 0 and releases bars.
    for _, flag in ipairs({ "overridebar", "vehicleui", "possessbar", "shapeshift" }) do
        H.setSpecialState(flag, true)
        H.gameEvaluate()
        local released = H.header().attrs["fp-page"] == nil
            and dbtns[1].attrs.action == 1 and ebtns[1].attrs.action == 25
        -- Bar sets vehicle slot 133 via state-page while flag active: must NOT be overwritten.
        dbtns[1].attrs.action = 133
        H.setBarAttrSecure(dbar, "state-page", "possess")
        local keptVehicle = dbtns[1].attrs.action == 133
        -- Exit special state while still in Bear: page 2 resumes automatically.
        H.setSpecialState(flag, false)
        H.gameEvaluate()
        local resumed = H.header().attrs["fp-page"] == 2
            and dbtns[1].attrs.action == 13 and ebtns[1].attrs.action == 13
        check("E4 " .. flag .. " yields control and resumes Bear on exit",
            released and keptVehicle and resumed)
    end

    -- bonusbar:5 (skyriding) yields, whereas bonusbar:3 (Bear) does NOT yield.
    H.setSpecialState("bonusbar", 3); H.gameEvaluate()
    local bearKept = H.header().attrs["fp-page"] == 2
    H.setSpecialState("bonusbar", 5); H.gameEvaluate()
    local dragonYielded = H.header().attrs["fp-page"] == nil and dbtns[1].attrs.action == 1
    H.setSpecialState("bonusbar", 0); H.gameEvaluate()
    check("E4 bonusbar:5 yields while druid bonusbar:3 stays paged", bearKept and dragonYielded)
    H.setCombat(false)

elseif CASE == "showgrid_and_reload" then
    -- E6 & E7: Hidden empty buttons (showgrid=0) + UpdateShown, and /reload while shifted
    -- on an unknown third-party bar.
    for i = 1, 12 do H.buttons[i].visible = false end
    local dbar = H.newFrame("DominosActionBar1", true)
    local dbtns = {}
    H.setHasAction(8, true)   -- only slot 8 populated on caster bar (slots 1-7, 9-12 hidden!)
    H.setHasAction(13, true)  -- Bear page 2 has spell in slot 13 (button 1)
    H.setHasAction(24, true)  -- Bear page 2 has spell in slot 24 (button 12)
    for i = 1, 12 do
        local b = H.newFrame("DominosActionButton" .. i, true)
        _G[b.name] = b
        b.parent = dbar
        b.attrs.action = i
        b.attrs["action-base"] = i
        b.attrs.showgrid = 0
        b.visible = (i == 8)
        b.attrs.UpdateShown = [[
            if self:GetAttribute("showgrid") > 0 or HasAction(self:GetAttribute("action")) then
                self:Show()
            else
                self:Hide()
            end
        ]]
        dbtns[i] = b
    end
    H.setForms(BEAR_CAT, BEAR_CAT_NAMES)
    H.load(ADDON_FILES, nil)
    H.setForm(1); H.gameEvaluate()
    check("E6 Dominos detected and all 12 buttons paged even when slot 1 & 10 others are hidden",
        dbtns[1].attrs.action == 13 and dbtns[8].attrs.action == 20 and dbtns[12].attrs.action == 24)
    check("E6 UpdateShown reveals populated Bear slots 1 & 12 and hides empty Bear slot 8",
        dbtns[1].visible == true and dbtns[12].visible == true and dbtns[8].visible == false)
    H.setForm(0); H.gameEvaluate()
    check("E6 caster restore re-shows slot 8 and re-hides empty slot 1",
        dbtns[1].attrs.action == 1 and dbtns[1].visible == false
            and dbtns[8].attrs.action == 8 and dbtns[8].visible == true)

elseif CASE == "reload_shifted_unknown" then
    -- E7: /reload while in Cat form on an unlisted addon bar whose buttons show Cat bonus page 7 (73..84).
    for i = 1, 12 do H.buttons[i].visible = false end
    local _, cbtns = makeFixedBar("CustomUIActionBar1", "CustomUIButton", 73)
    H.setForms(BEAR_CAT, BEAR_CAT_NAMES)
    H.setForm(2) -- Cat Form
    H.setSpecialState("bonusbar", 1) -- Cat bonusbar 1 -> page 7 (slots 73..84)
    H.load(ADDON_FILES, nil)
    H.gameEvaluate() -- Cat default page 3 -> slots 25..36
    check("E7 unlisted main bar auto-detected during /reload while shifted on bonus page",
        cbtns[1].attrs.action == 25 and cbtns[12].attrs.action == 36,
        cbtns[1].attrs.action)
    H.setForm(0); H.setSpecialState("bonusbar", 0); H.gameEvaluate()
    check("E7 caster form after shifted /reload restores slots 1-12 (not bonus slots 73-84)",
        cbtns[1].attrs.action == 1 and cbtns[12].attrs.action == 12,
        cbtns[1].attrs.action)

elseif CASE == "orphans_and_filtering" then
    -- E8 & E9: Orphaned saved bars cleanup, system-bar filtering, and visible-before-hidden sort.
    for i = 1, 12 do H.buttons[i].visible = false end
    -- Hidden Blizzard + false-positive system bars (Shaman totem, vehicle override, pet, stance, flyout).
    H.makeBlizzardBar("MultiBarBottomLeft", "MultiBarBottomLeftButton", 6, false, true)
    H.makeBlizzardBar("MultiBarRight", "MultiBarRightButton", 3, false, true)
    for _, sys in ipairs({
        { "OverrideActionBarButton", 6 },
        { "MultiCastActionButton", 12 },
        { "PossessButton", 6 },
        { "PetActionButton", 10 },
        { "StanceButton", 10 },
        { "SpellFlyoutButton", 8 },
    }) do
        for i = 1, sys[2] do
            local b = H.newFrame(sys[1] .. i, true)
            b.action = i; b.visible = true; _G[b.name] = b
        end
    end
    -- Visible Neuron main bar + 7 visible Neuron extra bars.
    for barIdx = 1, 8 do
        makeFixedBar("NeuronActionBar" .. barIdx,
            "NeuronActionBar" .. barIdx .. "_ActionButton", (barIdx - 1) * 12 + 1)
    end

    H.setForms(BEAR_CAT, BEAR_CAT_NAMES)
    H.load(ADDON_FILES, {
        enabled = true, version = 3,
        pages = { bear = 2, cat = 3, travel = 0, aquatic = 0, moonkin = 4, tree = 4 },
        additionalBars = { "RemovedAddon@13", "RemovedAddon@25", "NeuronActionBar2_ActionButton@13#2" },
    })

    wipe(H.log)
    SlashCmdList.DRUIDACTIONBARPAGER("bars")
    local out = table.concat(H.log, "\n")
    check("E9 system bars (Override/MultiCast/Possess/Pet/Stance/Flyout) excluded from /dabp bars",
        not out:find("OverrideActionBarButton", 1, true)
            and not out:find("MultiCastActionButton", 1, true)
            and not out:find("PossessButton", 1, true)
            and not out:find("PetActionButton", 1, true)
            and not out:find("StanceButton", 1, true)
            and not out:find("SpellFlyoutButton", 1, true))
    check("E9 all 7 visible Neuron extra bars sort ahead of hidden Blizzard bars",
        out:find("1. NeuronActionBar2_ActionButton", 1, true) ~= nil
            and out:find("7. NeuronActionBar8_ActionButton", 1, true) ~= nil
            and out:find("8. ActionButton", 1, true) ~= nil)
    check("E8 /dabp bars lists orphaned saved slots and marks migrated slot #3",
        out:find("saved slot 1: RemovedAddon@13 [not found]", 1, true) ~= nil
            and out:find("[selected #3]", 1, true) ~= nil)

    -- Free slot 1 with `/dabp bar slot 1 off`, then select bar 2.
    SlashCmdList.DRUIDACTIONBARPAGER("bar slot 1 off")
    SlashCmdList.DRUIDACTIONBARPAGER("bar 2 on")
    check("E8 /dabp bar slot 1 off frees orphaned slot and allows new selection",
        #DruidActionBarPagerDB.additionalBars == 3
            and DruidActionBarPagerDB.additionalBars[3] == "NeuronActionBar3_ActionButton@25")

    -- `/dabp bar clear` wipes all remaining entries including orphans.
    SlashCmdList.DRUIDACTIONBARPAGER("bar clear")
    check("E8 /dabp bar clear empties additionalBars", #DruidActionBarPagerDB.additionalBars == 0)

elseif CASE == "late_bar_and_perf" then
    -- E10 & E16: Late-loading third-party bar replacement and zero unnecessary EnumerateFrames scans.
    H.setForms(BEAR_CAT, BEAR_CAT_NAMES)
    H.resetEnumerateCount()
    H.load(ADDON_FILES, nil)
    check("E16 login with known main bar and 0 selected extras runs 0 EnumerateFrames scans",
        H.enumerateCount() == 0, H.enumerateCount())

    -- At t=1.0s (before the 2.0s late timer), EllesmereUI builds EABButton1..12
    -- and hides Blizzard ActionButton1..12 while in Bear form.
    H.setForm(1); H.gameEvaluate()
    check("E10 Blizzard initially paged to Bear page 2", H.buttons[1].attrs.actionpage == 2)
    for i = 1, 12 do H.buttons[i].visible = false end
    local _, ebtns = makeFixedBar("EABBar1", "EABButton", 1)

    H.runTimers() -- fires 2.0s LATE_REBUILD_DELAY -> schedules 0.2s rebuild
    H.runTimers() -- fires 0.2s rebuild
    H.gameEvaluate()
    check("E10 late EllesmereUI bar detected and paged on 2s recheck",
        ebtns[1].attrs.action == 13 and ebtns[12].attrs.action == 24, ebtns[1].attrs.action)
    check("E10 replaced Blizzard buttons have stale actionpage cleared",
        H.buttons[1].attrs.actionpage == nil, tostring(H.buttons[1].attrs.actionpage))

elseif CASE == "keybindings_and_guards" then
    -- E11 & E12: Mouse-disabled toggle buttons, 3-key bindings, ActionButtonUseKeyDown,
    -- dirty-only combat binding flush, pre-ADDON_LOADED safety, and non-Druid isolation.
    H.setBindingKey("DABP_TOGGLE_EXTRA1", "F9", "ALT-F9", "PAD1")
    H.setCVar("ActionButtonUseKeyDown", false)
    local ns = H.loadRaw(ADDON_FILES, nil)

    -- Pre-ADDON_LOADED slash command does not crash.
    local okPre, errPre = pcall(SlashCmdList.DRUIDACTIONBARPAGER, "")
    check("E12 slash command before ADDON_LOADED does not throw", okPre, errPre)

    -- All 4 toggle buttons have mouse disabled and are not anchored at screen CENTER.
    local mouseOff, offCenter = true, true
    for _, btn in ipairs({
        ns.KeyBindings.Buttons[1], ns.KeyBindings.Buttons[2],
        ns.KeyBindings.Buttons[3], ns.KeyBindings.AllButton,
    }) do
        if btn.mouseEnabled then mouseOff = false end
        if btn.point and btn.point[1] == "CENTER" then offCenter = false end
    end
    check("E11 secure toggle buttons disable mouse and avoid CENTER anchor", mouseOff and offCenter)

    H.fire("ADDON_LOADED", "DruidActionBarPager")
    H.fire("PLAYER_LOGIN")
    H.fire("PLAYER_ENTERING_WORLD")
    check("E11 all 3 keys from GetBindingKey are bound", #H.bindingOverrides == 3, #H.bindingOverrides)
    check("E11 ActionButtonUseKeyDown=0 registers LeftButtonUp",
        ns.KeyBindings.Buttons[1].clicks[1] == "LeftButtonUp", ns.KeyBindings.Buttons[1].clicks[1])

    -- Leaving combat without binding changes does not re-run ClearOverrideBindings.
    local refreshesBefore = H.bindingRefreshCount()
    H.fire("PLAYER_REGEN_ENABLED")
    check("E11 PLAYER_REGEN_ENABLED skips binding refresh when clean",
        H.bindingRefreshCount() == refreshesBefore)

    -- Toggle CVar & bindings during combat: zero protected calls in combat, applied on regen.
    H.setCombat(true, true)
    H.setCVar("ActionButtonUseKeyDown", true)
    H.setBindingKey("DABP_TOGGLE_ALL_EXTRAS", "CTRL-F12")
    H.fire("CVAR_UPDATE", "ActionButtonUseKeyDown", "1")
    H.fire("UPDATE_BINDINGS")
    check("E11 CVar and binding updates defer safely during combat",
        ns.KeyBindings.Buttons[1].clicks[1] == "LeftButtonUp" and #H.bindingOverrides == 3)
    H.setCombat(false)
    H.fire("PLAYER_REGEN_ENABLED")
    check("E11 deferred CVar and binding updates flush on PLAYER_REGEN_ENABLED",
        ns.KeyBindings.Buttons[1].clicks[1] == "LeftButtonDown" and #H.bindingOverrides == 4)

elseif CASE == "non_druid" then
    -- E12b: Non-Druid stays completely idle even if player runs /dabp commands.
    UnitClass = function() return "Warrior", "WARRIOR" end
    H.setForms({ { spellID = 2457, icon = 132349 } }, { [2457] = "Battle Stance" })
    H.load(ADDON_FILES, nil)
    SlashCmdList.DRUIDACTIONBARPAGER("on")
    SlashCmdList.DRUIDACTIONBARPAGER("bear 6")
    SlashCmdList.DRUIDACTIONBARPAGER("reset")
    SlashCmdList.DRUIDACTIONBARPAGER("bar 1 on")
    SlashCmdList.DRUIDACTIONBARPAGER("help")
    check("E12 non-Druid never registers state driver, wraps bars, or mutates pages",
        H.header().attrs["_driver-formpage"] == nil
            and #H.wrapCalls == 0
            and #H.bindingOverrides == 0
            and DruidActionBarPagerDB.pages.bear == 2)

elseif CASE == "forms_sv_combat" then
    -- E13, E14, E15 & E16: Form detection (non-English + numeric fileID + word boundary +
    -- async SPELL_DATA_LOAD_RESULT), SV corruption/migrations, strict combat lockdown,
    -- and 0-button fallback accuracy.
    for i = 1, 12 do
        _G["ActionButton" .. i] = nil
        H.buttons[i].visible = false
        H.buttons[i].name = nil
        H.buttons[i].action = nil
    end

    -- Forms:
    --   1: renumbered Bear with German name + numeric fileID 132276 -> bear (page 2)
    --   2: unrelated "Scatter Stance" (contains "cat") -> nil (must NOT match cat!)
    --   3: unrelated "Wildcat Reflexes" -> nil (must NOT match cat!)
    --   4: renumbered Moonkin with unloaded spell name + unknown icon -> nil until SPELL_DATA_LOAD_RESULT
    H.setForms({
        { spellID = 99001, icon = 132276 },
        { spellID = 99002, icon = 134400 },
        { spellID = 99003, icon = 134400 },
        { spellID = 99004, icon = 999999 },
    }, {
        [99001] = "Bärengestalt",
        [99002] = "Scatter Stance",
        [99003] = "Wildcat Reflexes",
    })
    -- Load with heavily corrupted v1-like settings (including string v1 pages,
    -- NaN/Inf, and an unknown top-level key).
    H.load(ADDON_FILES, {
        enabled = "corrupt",
        version = 1,
        staleTopLevel = "drop-me",
        pages = {
            bear = 0 / 0, cat = 1 / 0, travel = "4", aquatic = 5,
            moonkin = "6", tree = "8", unknown = 3,
        },
        additionalBars = { "", 42, "A@13", "A@13", "B@25", "C@37", "D@49" },
    })
    local db = DruidActionBarPagerDB
    check("E14 corrupted v1 SavedVariables repaired and migrated cleanly",
        db.version == 4 and db.enabled == true and db.staleTopLevel == nil
            and db.pages.bear == 2 and db.pages.cat == 3
            and db.pages.travel == 0 and db.pages.aquatic == 0
            and db.pages.moonkin == 4 and db.pages.tree == 8
            and db.pages.unknown == nil and #db.additionalBars == 3)

    local cond = H.header().attrs["_driver-formpage"]
    check("E13 German Bear matched by icon fileID 132276; Scatter/Wildcat rejected",
        cond:find("%[form:1%]2") ~= nil
            and not cond:find("%[form:2%]")
            and not cond:find("%[form:3%]")
            and not cond:find("%[form:4%]"),
        cond)

    wipe(H.log)
    SlashCmdList.DRUIDACTIONBARPAGER("debug")
    local dbg = table.concat(H.log, "\n")
    local hasZeroFallback = dbg:find("main bar: Blizzard (fallback), 0/12 buttons ()", 1, true) ~= nil
    check("E16 missing ActionButtons report 0/12 fallback buttons (not 12/12)",
        hasZeroFallback, not hasZeroFallback and dbg:gsub("\n", " | ") or nil)

    -- Clear initial timers, then deliver async spell data for form 4 ("Moonkin Form").
    H.runTimers(); H.runTimers()
    H.setSpellName(99004, "Moonkin Form")
    H.fire("SPELL_DATA_LOAD_RESULT", 99004, true)
    H.runTimers()
    check("E13 SPELL_DATA_LOAD_RESULT classifies form 4 as moonkin -> page 4",
        H.header().attrs["_driver-formpage"]:find("%[form:4%]4") ~= nil,
        H.header().attrs["_driver-formpage"])
    H.fire("UPDATE_SHAPESHIFT_FORMS")
    check("E13 next shift after SPELL_DATA_LOAD_RESULT skips redundant rebuild",
        H.pendingTimers() == 0, H.pendingTimers())

    -- Strict combat lockdown: slash command + new form + zone event cause 0 protected calls.
    local _, ebtns = makeFixedBar("EABBar1", "EABButton", 1)
    H.setCombat(true, true)
    SlashCmdList.DRUIDACTIONBARPAGER("bar clear")
    SlashCmdList.DRUIDACTIONBARPAGER("bear 9")
    H.fire("PLAYER_ENTERING_WORLD")
    H.runTimers()
    H.setCombat(false)
    H.fire("PLAYER_REGEN_ENABLED")
    H.setForm(1); H.gameEvaluate()
    check("E15 combat-deferred commands and bar attach apply cleanly on PLAYER_REGEN_ENABLED",
        ebtns[1].attrs.action == 97 and #db.additionalBars == 0, ebtns[1].attrs.action)

elseif CASE == "combat_login_and_misc" then
    -- E15b & E17: Reconnecting mid-combat, empty-string button name in /dabp debug,
    -- manual page 2 preservation in Travel Form, and same-prefix BT4 label clarity.
    H.setForms({
        { spellID = 5487, icon = 132276 },
        { spellID = 783,  icon = 132144 },
    }, { [5487] = "Bear Form", [783] = "Travel Form" })
    H.setBindingKey("DABP_TOGGLE_EXTRA1", "F9")
    H.setCVar("ActionButtonUseKeyDown", true)

    -- Load header/buttons pre-combat (as WoW loads addon files before login), then
    -- enter combat for PLAYER_LOGIN + PLAYER_ENTERING_WORLD.
    local ns = H.loadRaw(ADDON_FILES, nil)
    H.setCombat(true, true)
    H.fire("ADDON_LOADED", "DruidActionBarPager")
    H.fire("PLAYER_LOGIN")
    H.fire("PLAYER_ENTERING_WORLD")
    H.runTimers()
    check("E15b mid-combat login defers driver and bindings without protected calls",
        H.header().attrs["_driver-formpage"] == nil and #H.bindingOverrides == 0)
    H.setCombat(false)
    H.fire("PLAYER_REGEN_ENABLED")
    H.setForm(1); H.gameEvaluate()
    check("E15b PLAYER_REGEN_ENABLED finishes login attach, bindings, and click mode",
        H.buttons[1].attrs.actionpage == 2
            and #H.bindingOverrides == 1
            and ns.KeyBindings.Buttons[1].clicks[1] == "LeftButtonDown")

    -- Empty-string button name prints fallback "button 1" in /dabp debug.
    H.setForm(0); H.gameEvaluate()
    for i = 1, 12 do H.buttons[i].visible = false end
    local ubar = H.newFrame("UnnamedHost", true)
    local ubtns = {}
    for i = 1, 12 do
        local b = H.newFrame("", true)
        b.parent = ubar
        b.attrs.action = i
        ubtns[i] = b
    end
    H.setForm(2) -- Travel Form (no bonus bar)
    H.fire("PLAYER_ENTERING_WORLD"); H.runTimers()
    wipe(H.log)
    SlashCmdList.DRUIDACTIONBARPAGER("debug")
    local dbg = table.concat(H.log, "\n")
    check("E17 empty-string button name falls back to 'button 1' in /dabp debug",
        dbg:find("button 1 shows slot", 1, true) ~= nil)

    -- Manual page 2 (slots 13..24) on known bar during Travel Form is preserved, not clobbered to 1..12.
    local _, ebtns = makeFixedBar("EABBar1", "EABButton", 13)
    H.fire("PLAYER_ENTERING_WORLD"); H.runTimers()
    check("E17 manual page 2 slots preserved during non-bonus Travel Form reload",
        H.header().attrs.base1 == 13 and ebtns[1].attrs.action == 13, H.header().attrs.base1)

    -- Same-prefix BT4 extra bars show distinct bar names and page/slot ranges.
    for barIdx = 2, 3 do
        local btBar = H.newFrame("BT4Bar" .. barIdx, true)
        for i = 1, 12 do
            local slot = (barIdx - 1) * 12 + i
            local b = H.newFrame("BT4Button" .. slot, true)
            b.parent = btBar; b.state_types = {}
            b._state_type = "action"; b._state_action = slot
            b.attrs.UpdateState = "--"; _G[b.name] = b
        end
    end
    wipe(H.log)
    SlashCmdList.DRUIDACTIONBARPAGER("bars")
    local barsOut = table.concat(H.log, "\n")
    check("E9 same-prefix BT4 bars show distinct BT4Bar2/BT4Bar3 and page/slot labels",
        barsOut:find("BT4Button [BT4Bar2, page 2 / slots 13-24]", 1, true) ~= nil
            and barsOut:find("BT4Button [BT4Bar3, page 3 / slots 25-36]", 1, true) ~= nil)
elseif CASE == "paused_extra_baseline" then
    local _, extra = makeFixedBar("AuditExtra", nil, 13)
    local _, other = makeFixedBar("ZOtherExtra", nil, 37)
    H.setForms(BEAR_CAT, BEAR_CAT_NAMES)
    H.setForm(1)
    local ns = H.load(ADDON_FILES, nil)
    H.runTimers(); H.gameEvaluate()
    SlashCmdList.DRUIDACTIONBARPAGER("bear 6")
    SlashCmdList.DRUIDACTIONBARPAGER("bar 1 on")
    SlashCmdList.DRUIDACTIONBARPAGER("bar 2 on")
    H.gameEvaluate()
    H.clickSecure(_G.DruidActionBarPagerToggleExtra1)
    for i = 1, 12 do extra[i].attrs.action = 48 + i end
    SlashCmdList.DRUIDACTIONBARPAGER("bear 7")
    H.gameEvaluate()
    check("paused extra adopts current normal page while other extra stays applied",
        extra[1].attrs.action == 49 and other[1].attrs.action == 73)
    local selectedId = DruidActionBarPagerDB.additionalBars[1]
    H.fire("PLAYER_ENTERING_WORLD"); H.runTimers(); H.gameEvaluate()
    check("second rebuild retains paused extra identity and selection",
        DruidActionBarPagerDB.additionalBars[1] == selectedId
            and ns.Attach.Info().missingSelected == false and extra[1].attrs.action == 49)
    makeFixedBar("AAFirstExtra", nil, 109, "AuditExtra")
    H.fire("PLAYER_ENTERING_WORLD"); H.runTimers(); H.gameEvaluate()
    check("candidate reorder retains refreshed baseline and paused state",
        DruidActionBarPagerDB.additionalBars[1] == selectedId and extra[1].attrs.action == 49
            and other[1].attrs.action == 73)
    H.clickSecure(_G.DruidActionBarPagerToggleExtra1)
    check("resuming extra uses the current form page", extra[1].attrs.action == 73)
    H.setForm(0); H.gameEvaluate()
    check("caster restores the normal page chosen while extra was paused",
        extra[1].attrs.action == 49 and extra[12].attrs.action == 60, extra[1].attrs.action)
    H.fire("PLAYER_ENTERING_WORLD"); H.runTimers(); H.gameEvaluate()
    check("caster rebuild retains selected bar identity after its normal page changed",
        DruidActionBarPagerDB.additionalBars[1] == selectedId
            and ns.Attach.Info().missingSelected == false)
    H.setForm(1); H.gameEvaluate()
    check("extra still pages after caster rebuild", extra[1].attrs.action == 73)
    H.clickSecure(_G.DruidActionBarPagerToggleExtra1)
    check("extra still restores its refreshed baseline", extra[1].attrs.action == 49)

    -- A standalone LAB bar may keep its genuine restore state only on buttons.
    for _, button in ipairs(extra) do
        button.attrs.UpdateState = [[
            local state = ...
            self:SetAttribute("state", state)
            self:SetAttribute("action", self:GetAttribute("labaction-" .. state))
        ]]
        button.state_types = {}
        button.UpdateAction = function(self) self._state_action = self.attrs.action end
        button.ButtonContentsChanged = button.UpdateAction
    end
    local function setNormalLabState(state, offset)
        for i, button in ipairs(extra) do
            button.attrs.state = state
            button.attrs["labaction-" .. state] = offset + i
            button.attrs.action = offset + i
            button._state_type = "action"
            button._state_action = offset + i
        end
    end
    setNormalLabState("normal", 48)
    H.fire("PLAYER_ENTERING_WORLD"); H.runTimers(); H.gameEvaluate()
    H.clickSecure(_G.DruidActionBarPagerToggleExtra1)
    H.clickSecure(_G.DruidActionBarPagerToggleExtra1)
    setNormalLabState("updated", 84)
    SlashCmdList.DRUIDACTIONBARPAGER("bear 9")
    H.gameEvaluate()
    H.fire("PLAYER_ENTERING_WORLD"); H.runTimers(); H.gameEvaluate()
    H.clickSecure(_G.DruidActionBarPagerToggleExtra1)
    check("standalone LAB extra resumes after paused state change", extra[1].attrs.action == 97)
    H.setForm(0); H.gameEvaluate()
    check("standalone LAB extra restores refreshed nonzero state and slots",
        extra[1].attrs.state == "updated" and extra[1].attrs.action == 85)
elseif CASE == "reload_prowl" then
    H.setForms(BEAR_CAT, BEAR_CAT_NAMES)
    H.setForm(2); H.setSpecialState("stealth", true)
    local ns = H.load(ADDON_FILES, { version = 4, enabled = true, prowlPage = 8, pages = { cat = 3 } })
    H.runTimers(); H.gameEvaluate()
    check("reload already prowling applies optional page securely", H.buttons[1].attrs.actionpage == 8)
    H.setSpecialState("stealth", false); H.gameEvaluate()
    check("reload Prowl exit restores preserved Cat mapping", H.buttons[1].attrs.actionpage == 3)
    check("malformed page writer refuses NaN", not ns.Settings.SetPage("prowl", 0/0))
elseif CASE == "future_schema" then
    local future = { version = 999, enabled = false, pages = { cat = 10 },
        additionalBars = { "future-id" }, futureValue = { keep = true } }
    local originalPages, originalExtras, originalFuture = future.pages, future.additionalBars, future.futureValue
    local ns = H.load(ADDON_FILES, future)
    check("future settings are refused without assigning a live DB", ns.Settings.Get() == nil)
    check("future settings retain original identity and every field", DruidActionBarPagerDB == future
        and future.version == 999 and future.enabled == false and future.pages == originalPages
        and future.additionalBars == originalExtras and future.futureValue == originalFuture
        and future.prowlPage == nil and future.mappingWindow == nil)
    check("future settings cannot install a paging driver", H.header().attrs["_driver-formpage"] == nil)
else
    error("unknown edge case: " .. tostring(CASE))
end

for _, r in ipairs(results) do print(CASE .. ": " .. r) end
return table.concat(results, "\n")
