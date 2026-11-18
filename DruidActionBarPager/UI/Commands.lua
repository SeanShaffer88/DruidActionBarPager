-- Slash commands: /dabp and /druidactionbarpager.
local _, ns = ...
local C, U = ns.Constants, ns.Util

local Cmd = {}
ns.Commands = Cmd

local Print = U.Print

local function PageText(page)
    if page > 0 then return "page " .. page end
    return "|cff888888no switch|r"
end

local function ShowStatus()
    local db = ns.Settings.Get()
    local info = ns.Attach.Info()
    local missingCount = info.missingExtras and #info.missingExtras or 0
    Print(db.enabled and "|cff40ff40enabled|r" or "|cffff4040disabled|r")
    if missingCount > 0 then
        Print(("  extra bars selected: %d/%d (%d not found; see /dabp bars or /dabp bar clear)"):format(
            #db.additionalBars, C.MAX_ADDITIONAL_BARS, missingCount))
    else
        Print(("  extra bars selected: %d/%d"):format(#db.additionalBars, C.MAX_ADDITIONAL_BARS))
    end

    -- The form index of each form the player has, by page key.
    local learned = {}
    for i = 1, ns.Forms.Count() do
        local key = ns.Forms.Classify(i)
        if key then learned[key] = i end
    end

    for _, key in ipairs(C.FORM_ORDER) do
        local notLearned = learned[key] and "" or " |cff888888(not learned)|r"
        Print(("  %-8s -> %s%s"):format(key, PageText(db.pages[key]), notLearned))
    end
end

local function ShowFormLines()
    local count = ns.Forms.Count()
    Print("  current form: " .. tostring(GetShapeshiftForm and GetShapeshiftForm()) .. " of " .. count)
    for i = 1, count do
        local spellID, name = ns.Forms.Details(i)
        Print(("    [form:%d] %s (id %s) -> %s"):format(i, tostring(name), tostring(spellID),
            tostring(ns.Forms.Classify(i))))
    end
end

local function ShowDriverLines(header)
    local key = ns.Rebuild.LastKey()
    local cond = key and key:match("^([^#]*)#")
    Print("  driver: " .. tostring(cond))
    if cond and SecureCmdOptionParse then
        Print("  driver wants page: " .. tostring(SecureCmdOptionParse(cond)))
    end
    Print("  page applied now: " .. tostring(header:GetAttribute("fp-page") or "none (normal bar)"))
end

local function ShowDebug()
    local info = ns.Attach.Info()
    Print("debug:")
    Print(("  main bar: %s, %d/%d buttons (%s)"):format(
        info.name, info.count, C.BUTTONS_PER_PAGE, info.modes))
    Print("  main bar detected: " .. (info.found and "yes" or "no (fallback)"))
    Print("  hooked into the bar's own paging: " .. (info.wrapped and "yes" or "no (not needed or not possible)"))
    ShowFormLines()
    ShowDriverLines(ns.Frames.header)

    local button = ns.BarScan.FirstCachedButton()
    if button then
        local okn, name = pcall(button.GetName, button)
        local label = (okn and type(name) == "string" and name ~= "") and name or "button 1"
        Print(("  %s shows slot %s"):format(label, tostring(ns.BarScan.SlotOf(button))))
    end
    for _, extra in ipairs(info.extras) do
        local enabled = ns.Frames.header:GetAttribute("candidate-enabled" .. extra.candidate)
        Print(("  extra bar %d: %s (%d/%d buttons, %s), paging %s"):format(
            extra.slot, extra.display or extra.name, extra.count, C.BUTTONS_PER_PAGE,
            extra.visible and "visible" or "hidden", enabled and "on" or "off"))
    end
    for _, missing in ipairs(info.missingExtras or {}) do
        Print(("  extra bar %d: %s (not found; /dabp bar slot %d off or /dabp bar clear)"):format(
            missing.slot, missing.id, missing.slot))
    end
    Print("  in combat: " .. tostring(InCombatLockdown()))
end

local function FindSelectedSlot(additionalBars, candidates, targetIndex)
    for slot, savedId in ipairs(additionalBars) do
        local resolvedIndex = ns.BarScan.ResolveCandidateId(candidates, savedId)
        if resolvedIndex == targetIndex then return slot end
    end
end

local function ShowBars()
    local db = ns.Settings.Get()
    local candidates = ns.BarScan.FindExtras(false, db.additionalBars, true)
    Print("additional bars (showing up to " .. C.MAX_DISCOVERED_BARS
        .. "; select up to " .. C.MAX_ADDITIONAL_BARS .. "):")
    if #candidates == 0 then
        Print("  no action bars found; show the bar or check /dabp debug.")
    else
        for index, candidate in ipairs(candidates) do
            local slot = FindSelectedSlot(db.additionalBars, candidates, index)
            local tag = slot and (" [selected #" .. slot .. "]") or ""
            Print(("  %d. %s (%d/%d buttons, %s)%s"):format(
                index, ns.BarScan.FormatCandidate(candidate), candidate.count,
                C.BUTTONS_PER_PAGE, candidate.visibleCount > 0 and "visible" or "hidden", tag))
        end
    end

    local hasMissing = false
    for slot, savedId in ipairs(db.additionalBars) do
        if not ns.BarScan.ResolveCandidateId(candidates, savedId) then
            hasMissing = true
            Print(("  saved slot %d: %s [not found]"):format(slot, savedId))
        end
    end

    Print("  /dabp bar <number> on|off selects a bar; /dabp bar clear removes all.")
    if hasMissing then
        Print("  /dabp bar slot <1-" .. C.MAX_ADDITIONAL_BARS .. "> off removes a missing saved bar.")
    end
    Print("  Per-bar hotkeys follow selection order; one hotkey toggles all selected bars.")
end

local function ShowHelp()
    Print("commands (/dabp or /druidactionbarpager):")
    Print("  /dabp                 - show current page for each form")
    Print("  /dabp <form> <page>   - set a page, e.g. /dabp bear 2")
    Print("  /dabp <form> 0        - don't switch pages for that form")
    Print("  /dabp on | off        - enable or disable paging")
    Print("  /dabp reset           - restore default pages")
    Print("  /dabp bars            - list additional action bars")
    Print("  /dabp bar <n> on|off  - select or remove a listed extra bar")
    Print("  /dabp bar slot <n> off - remove saved extra bar slot 1-" .. C.MAX_ADDITIONAL_BARS)
    Print("  /dabp bar clear       - remove all selected extra bars")
    Print("  /dabp debug           - show which bars are being switched")
    Print("  key bindings: toggle each selected extra bar or all extras")
    Print("  forms: bear, cat, travel, aquatic, moonkin, tree")
end

-- Sets one form's page. Returns true if the setting changed.
local function SetFormPage(db, form, arg)
    local page = tonumber(arg)
    if not U.IsValidPage(page) then
        Print(("page must be a whole number from 1 to %d (or 0 for no switch)."):format(C.MAX_PAGE))
        return false
    end
    db.pages[form] = page
    if page == 0 then
        Print(C.FORM_LABELS[form] .. " will no longer switch pages.")
    else
        Print(C.FORM_LABELS[form] .. " -> action bar page " .. page .. ".")
    end
    return true
end

-- Selects/removes a discovered bar by list number, removes a saved slot by
-- slot index, or clears all saved extra bars.
local function SetExtraBar(db, arg)
    local trimmed = arg or ""
    if trimmed == "clear" then
        if #db.additionalBars == 0 then
            Print("no extra bars are selected.")
            return false
        end
        wipe(db.additionalBars)
        Print("all extra bars cleared.")
        return true
    end

    local slotText = trimmed:match("^slot%s+(%d+)%s+off$")
    if slotText then
        local slot = tonumber(slotText)
        local removed = slot and db.additionalBars[slot]
        if not removed then
            Print("no saved extra bar in slot " .. tostring(slotText) .. "; see /dabp bars.")
            return false
        end
        table.remove(db.additionalBars, slot)
        Print("removed saved extra bar slot " .. slot .. " (" .. removed .. ").")
        return true
    end

    local indexText, state = trimmed:match("^(%d+)%s+(%a+)$")
    local index = tonumber(indexText)
    if not index or (state ~= "on" and state ~= "off") then
        Print("use /dabp bar <number> on|off, /dabp bar slot <1-"
            .. C.MAX_ADDITIONAL_BARS .. "> off, or /dabp bar clear.")
        return false
    end

    local candidates = ns.BarScan.FindExtras(false, db.additionalBars, true)
    local candidate = candidates[index]
    if not candidate then
        Print("no bar at that number; use /dabp bars to refresh the list.")
        return false
    end
    local selectedAt = FindSelectedSlot(db.additionalBars, candidates, index)
    if state == "on" then
        if selectedAt then
            Print(candidate.label .. " is already selected (slot " .. selectedAt .. ").")
            return false
        end
        if #db.additionalBars >= C.MAX_ADDITIONAL_BARS then
            Print("select up to " .. C.MAX_ADDITIONAL_BARS
                .. " extra bars (use /dabp bar slot <n> off or /dabp bar clear to free a slot).")
            return false
        end
        table.insert(db.additionalBars, candidate.id)
        Print(ns.BarScan.FormatCandidate(candidate)
            .. " selected as extra bar " .. #db.additionalBars .. ".")
    else
        if not selectedAt then
            Print(candidate.label .. " is not selected.")
            return false
        end
        table.remove(db.additionalBars, selectedAt)
        Print(ns.BarScan.FormatCandidate(candidate) .. " removed from extra bars.")
    end
    return true
end

-- Applies a settings command. Returns true if the settings changed and the
-- bar needs rebuilding.
local function ApplySetting(db, cmd, arg)
    if cmd == "on" or cmd == "off" then
        db.enabled = (cmd == "on")
        Print(db.enabled and "paging enabled." or "paging disabled.")
        return true
    end
    if cmd == "reset" then
        for form, page in pairs(C.DEFAULT_PAGES) do db.pages[form] = page end
        Print("pages reset to defaults.")
        return true
    end
    if cmd == "bar" then return SetExtraBar(db, arg) end
    if C.DEFAULT_PAGES[cmd] then
        return SetFormPage(db, cmd, arg)
    end
    ShowHelp()
    return false
end

-- Commands that only show information.
local VIEWS = {
    [""]     = ShowStatus,
    list     = ShowStatus,
    status   = ShowStatus,
    debug    = ShowDebug,
    bars     = ShowBars,
    help     = ShowHelp,
}

-- Splits the input into a lowercase command and its argument.
local function ParseInput(input)
    local text = (input or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, arg = text:match("^(%S*)%s*(.-)$")
    return cmd, arg
end

local function HandleSlash(input)
    local cmd, arg = ParseInput(input)
    if cmd == "help" then
        ShowHelp()
        return
    end
    if not U.IsDruid() then
        Print("inactive on non-druid characters.")
        return
    end
    local db = ns.Settings.Get()
    if not db then
        Print("settings are not loaded yet.")
        return
    end

    local view = VIEWS[cmd]
    if view then
        view()
        return
    end

    if not ApplySetting(db, cmd, arg) then return end

    if InCombatLockdown() then
        Print("you're in combat; the change will apply when combat ends.")
    end
    ns.Rebuild.Now(true)
end

-- Registers the slash commands. Called once when the addon starts.
function Cmd.Register()
    SLASH_DRUIDACTIONBARPAGER1 = "/dabp"
    SLASH_DRUIDACTIONBARPAGER2 = "/druidactionbarpager"
    SlashCmdList["DRUIDACTIONBARPAGER"] = HandleSlash
end
