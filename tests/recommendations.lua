local H = dofile(TESTDIR .. "/harness.lua")
local results = {}
local function check(name, ok)
    results[#results + 1] = (ok and "PASS " or "FAIL ") .. name
end
H.setForms({ { spellID = 5487, icon = 132276 }, { spellID = 768, icon = 132115 } },
    { [5487] = "Bear Form", [768] = "Cat Form" })
local extraBar, extra = H.newFrame("RecommendationBar", true), {}
for index = 1, 12 do
    local button = H.newFrame("RecommendationButton" .. index, true)
    button.parent, button.attrs.action = extraBar, 12 + index
    extra[index], _G[button.name] = button, button
end
local ns = H.load(ADDON_FILES, { version = 3, pages = { bear = 2, cat = 3 }, additionalBars = {} })
H.runTimers(); H.gameEvaluate()
check("v3 migration preserves Cat and defaults Prowl to inherit", ns.Settings.Get().version == 4
    and ns.Settings.Get().pages.cat == 3 and ns.Settings.Get().prowlPage == 0)
H.setForm(2); H.setSpecialState("stealth", true); H.gameEvaluate()
check("default Prowl inherits Cat", H.buttons[1].attrs.actionpage == 3)
ns.Commands.Execute("prowl 8")
H.gameEvaluate()
check("explicit Prowl page applies with classified Cat index", H.buttons[1].attrs.actionpage == 8
    and ns.Conditions.Build(ns.Settings.Get()):find("[form:2,stealth]8", 1, true) ~= nil)
H.setCombat(true, true)
H.setSpecialState("stealth", false); H.gameEvaluate()
check("leaving Prowl restores Cat in combat", H.buttons[1].attrs.actionpage == 3)
H.setSpecialState("stealth", true); H.gameEvaluate()
check("entering Prowl switches securely in combat", H.buttons[1].attrs.actionpage == 8)
ns.Commands.Execute("prowl 9")
check("combat edit queues without insecure paging", ns.Rebuild.IsPending() and H.buttons[1].attrs.actionpage == 8)
H.setCombat(false); H.fire("PLAYER_REGEN_ENABLED"); H.gameEvaluate()
check("queued Prowl configuration applies after combat", H.buttons[1].attrs.actionpage == 9)
H.setSpecialState("vehicleui", true); H.gameEvaluate()
check("game override precedes Prowl", H.buttons[1].attrs.actionpage == nil
    and ns.Mapping.Snapshot().state == "Yielding to game override")
H.setSpecialState("vehicleui", false); H.setForm(1); H.gameEvaluate()
check("stealth outside Cat keeps Bear mapping", H.buttons[1].attrs.actionpage == 2)
ns.Commands.Execute("prowl -1"); ns.Commands.Execute("prowl 1.5"); ns.Commands.Execute("prowl 11")
check("invalid Prowl pages leave validated configuration intact", ns.Settings.Get().prowlPage == 9)
local parse = SecureCmdOptionParse
SecureCmdOptionParse = nil
check("unavailable native conditional API falls back to ordinary forms",
    not ns.Conditions.Build(ns.Settings.Get()):find(",stealth", 1, true)
        and #ns.Mapping.Snapshot().warnings > 0)
SecureCmdOptionParse = parse
local enumeration = H.enumerateCount()
ns.Commands.Execute("config")
local panel = ns.MappingPanel.Frame()
check("mapping panel opens unprotected without scanning", panel:IsShown() and not panel.prot
    and H.enumerateCount() == enumeration)
check("panel is compact clamped and has no idle ticker", panel.size[1] == 600 and panel.size[2] == 580
    and panel.clamped and panel:GetScript("OnUpdate") == nil)
panel:GetScript("OnKeyDown")(panel, "TAB")
check("Tab focuses a visible native control", ns.MappingPanel.Controls()[1].highlighted)
local before = ns.Settings.Get().pages.bear
panel:GetScript("OnKeyDown")(panel, "ENTER")
check("Enter activates focused mapping control through canonical settings",
    ns.Settings.Get().pages.bear == math.max(0, before - 1))
IsShiftKeyDown = function() return true end
panel:GetScript("OnKeyDown")(panel, "TAB")
check("Shift Tab wraps bounded focus", ns.MappingPanel.Controls()[#ns.MappingPanel.Controls()].highlighted)
IsShiftKeyDown = nil
panel:GetScript("OnKeyDown")(panel, "ESCAPE")
check("Escape closes panel and disables key capture", not panel:IsShown() and not panel.keyboard)
ns.Commands.Execute("config")
panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 33, -44)
panel:GetScript("OnDragStop")(panel)
check("panel placement persists through validated settings",
    ns.Settings.Get().mappingWindow.point == "TOPLEFT" and ns.Settings.Get().mappingWindow.x == 33)
UIParent:SetSize(800, 400)
ns.MappingPanel.Refresh()
check("small UI canvas fits compact panel", panel.scale < 1 and panel.scale * 580 <= 400)
ns.Commands.Execute("cat 4"); ns.Commands.Execute("moonkin 4")
check("shared form page has an informational warning", #ns.Mapping.Snapshot().warnings > 0)
check("compatibility describes named mock evidence without an invented version",
    ns.Compatibility.Describe("Bartender4").evidence == "Offline mock contract"
        and ns.Compatibility.Describe("Bartender4").version == "unknown")
check("generic detection is explicit", ns.Compatibility.Describe("Other (auto-detected)").adapter == "Generic discovery")
ns.Mapping.Discover()
check("panel can select a discovered extra through canonical settings", ns.MappingPanel.SelectNext(1)
    and #ns.Settings.Get().additionalBars == 1)
H.setForm(2); H.setSpecialState("stealth", true); H.gameEvaluate()
H.runTimers(0)
check("Prowl also pages selected extras", extra[1].attrs.action == 97)
check("extra status describes applied mirroring", ns.Mapping.Snapshot().extras[1].status == "Mirroring page 9")
H.clickSecure(_G.DruidActionBarPagerToggleExtra1); H.runTimers(0)
check("secure toggle updates paused ownership without a panel ticker",
    ns.Mapping.Snapshot().extras[1].status == "Paused; normal page" and extra[1].attrs.action == 13)
check("selection validation refuses a missing bar identity", not ns.Commands.SelectExtra(1, "missing-bar"))
ns.Commands.Execute("bar clear"); H.gameEvaluate()
check("cleared extras disappear from mapping snapshot", ns.Mapping.Snapshot().extras[1] == nil)
ns.Commands.Execute("off"); H.gameEvaluate()
check("disabled ownership is explicit", ns.Mapping.Snapshot().state == "Disabled")
ns.Commands.Execute("reset")
check("reset also restores inherited Prowl behavior", ns.Settings.Get().prowlPage == 0)
panel:GetScript("OnKeyDown")(panel, "TAB")
H.setCombat(true, true); H.fire("PLAYER_REGEN_DISABLED")
check("combat entry releases an already-open panel keyboard", not panel.keyboard)
local captureError = not pcall(panel.SetPropagateKeyboardInput, panel, true)
check("harness enforces native propagation nocombat contract", captureError)
local safe = true
for _, key in ipairs({ "TAB", "ENTER", "SPACE", "ESCAPE", "W" }) do
    safe = pcall(panel:GetScript("OnKeyDown"), panel, key) and safe
end
check("stale queued navigation cannot invoke restricted API or capture gameplay input",
    safe and not panel.keyboard)
panel:Hide()
ns.Commands.Execute("config")
check("opening in combat keeps keyboard capture disabled", panel:IsShown() and not panel.keyboard)
local cat = ns.Settings.Get().pages.cat
ns.MappingPanel.Controls()[4]:GetScript("OnClick")(ns.MappingPanel.Controls()[4])
check("mouse configuration still defers safely during combat",
    ns.Rebuild.IsPending() and ns.Settings.Get().pages.cat == cat + 1)
H.setCombat(false); H.fire("PLAYER_REGEN_ENABLED"); H.gameEvaluate()
check("open panel keyboard recovers after combat", panel.keyboard and panel.propagate)
H.setCombat(true, true); H.fire("PLAYER_REGEN_DISABLED"); panel:Hide()
H.setCombat(false); H.fire("PLAYER_REGEN_ENABLED")
check("closed panel does not recapture keys after combat", not panel.keyboard)
ns.Commands.Execute("cat " .. cat)
return table.concat(results, "\n")
