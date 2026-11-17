-- Hands the main bar's buttons to the secure header, and hooks the bar so its
-- own paging can't undo the form page. Runs out of combat only. It only
-- records references and attributes on our own header; it never writes to
-- the bar addon's buttons from here.
local _, ns = ...
local C = ns.Constants
local Snippets = ns.Snippets

local At = {}
ns.Attach = At

local BUTTONS = C.BUTTONS_PER_PAGE
local header = ns.Frames.header

-- What the last attach found, for /dabp debug and the rebuild key.
local info = { name = "none", count = 0, wrapped = false, modes = "" }

-- Bars already hooked (true) or that refused the hook (false).
local wrappedBars = {}

-- SetFrameRef errors on nil, so clearing a reference goes through the
-- attribute the reference is stored in.
local function SetRef(label, frame)
    if frame then
        header:SetFrameRef(label, frame)
    else
        header:SetAttribute("frameref-" .. label, nil)
    end
end

-- Hooks a protected bar so the page is re-applied after any state change.
-- Any protected bar can be hooked: if it never changes state, the wrap does
-- nothing. A bar that refused the hook is tried again on the next attach.
-- Returns true if the bar is hooked.
local function WrapBar(bar)
    if not bar or wrappedBars[bar] then return wrappedBars[bar] or false end
    local okp, protected = pcall(bar.IsProtected, bar)
    if not (okp and protected) then
        return false
    end
    local ok = pcall(SecureHandlerWrapScript, bar, "OnAttributeChanged", header,
        Snippets.WRAP_PRE, Snippets.WRAP_POST)
    wrappedBars[bar] = ok and true or false
    return wrappedBars[bar]
end

-- The bar a button belongs to: its parent frame.
local function ParentOf(button)
    local ok, parent = pcall(button.GetParent, button)
    if ok then return parent end
    return nil
end

-- Writes the attributes the snippets read for button i. Returns its mode.
local function AttachButton(i, button, active)
    local mode = ns.BarScan.ModeOf(button)
    local slot = ns.BarScan.BaseSlot(button, active) or ns.BarScan.SlotOf(button) or i
    header:SetAttribute("mode" .. i, mode)
    header:SetAttribute("idx" .. i, (slot - 1) % BUTTONS + 1)
    header:SetAttribute("base" .. i, slot)
    return mode, slot
end

-- "lab x12, page x0" style summary of how many buttons use each mode.
local function ModeSummary(modeCounts)
    local summary = {}
    for mode, n in pairs(modeCounts) do
        summary[#summary + 1] = mode .. " x" .. n
    end
    table.sort(summary)
    return table.concat(summary, ", ")
end

-- Finds the main bar and attaches its buttons. Returns the button count.
function At.Attach(force)
    local name, list, count = ns.BarScan.Find(force)
    local active = header:GetAttribute("fp-active")

    local modeCounts, bases = {}, {}
    local bar
    for i = 1, BUTTONS do
        local button = list[i]
        SetRef("button" .. i, button)
        if button then
            local mode, slot = AttachButton(i, button, active)
            bases[button] = slot
            modeCounts[mode] = (modeCounts[mode] or 0) + 1
            -- Every mode needs the parent bar: its own paging (Blizzard's bonus
            -- bar, Bartender4, ...) is what overwrites our page, so the bar is
            -- hooked, page-mode buttons included.
            bar = bar or ParentOf(button)
        end
    end
    ns.BarScan.SetBaseSlots(bases)
    SetRef("bar", bar)

    info.name = name
    info.count = count
    info.modes = ModeSummary(modeCounts)
    info.wrapped = WrapBar(bar)
    return count
end

-- The information from the last attach (name, count, modes, wrapped).
function At.Info()
    return info
end
