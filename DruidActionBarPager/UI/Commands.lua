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
    Print(db.enabled and "|cff40ff40enabled|r" or "|cffff4040disabled|r")

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
    Print(("  main bar: %s, %d/12 buttons (%s)"):format(info.name, info.count, info.modes))
    Print("  main bar detected: " .. (info.found and "yes" or "no (fallback)"))
    Print("  hooked into the bar's own paging: " .. (info.wrapped and "yes" or "no (not needed or not possible)"))
    ShowFormLines()
    ShowDriverLines(ns.Frames.header)

    local button = ns.BarScan.FirstCachedButton()
    if button then
        local okn, name = pcall(button.GetName, button)
        Print(("  %s shows slot %s"):format(okn and name or "button 1", tostring(ns.BarScan.SlotOf(button))))
    end
    Print("  in combat: " .. tostring(InCombatLockdown()))
end

local function ShowHelp()
    Print("commands (/dabp or /druidactionbarpager):")
    Print("  /dabp                - show current page for each form")
    Print("  /dabp <form> <page>  - set a page, e.g. /dabp bear 2")
    Print("  /dabp <form> 0       - don't switch pages for that form")
    Print("  /dabp on | off       - enable or disable paging")
    Print("  /dabp reset          - restore default pages")
    Print("  /dabp debug          - show which bar is being switched")
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

    local view = VIEWS[cmd]
    if view then
        view()
        return
    end

    if not ApplySetting(ns.Settings.Get(), cmd, arg) then return end

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
