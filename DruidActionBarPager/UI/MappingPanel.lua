-- Native, unprotected configuration UI. Secure paging remains in Rebuild/Snippets.
local _, ns = ...
local P = {}
ns.MappingPanel = P
local panel, rows, extras
local queued = false
local controls = {}
local focus = 0

local function Text(parent, size, x, y, width)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetPoint("TOPLEFT", x, y)
    holder:SetSize(width, 22)
    holder:EnableMouse(true)
    local text = holder:CreateFontString(nil, "OVERLAY", size == 16 and "GameFontNormalLarge" or "GameFontHighlightSmall")
    text:SetAllPoints(holder)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    holder.SetText = function(_, value) text:SetText(value) end
    holder.SetTextColor = function(_, ...) text:SetTextColor(...) end
    return holder
end

local function Button(parent, text, x, y, width, action)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", action)
    controls[#controls + 1] = button
    return button
end

local function Focus(index)
    if controls[focus] then controls[focus]:UnlockHighlight() end
    focus = index
    if controls[focus] then controls[focus]:LockHighlight() end
end

local function KeyDown(self, key)
    -- This panel is unprotected, so disabling its keyboard is legal in combat.
    -- Propagation itself has a nocombat restriction and must not be called here.
    if InCombatLockdown() then
        Focus(0)
        self:EnableKeyboard(false)
        return
    end
    if key == "TAB" then
        local step = IsShiftKeyDown and IsShiftKeyDown() and -1 or 1
        local nextFocus = focus == 0 and (step > 0 and 1 or #controls)
            or ((focus - 1 + step) % #controls + 1)
        Focus(nextFocus)
    elseif key == "ENTER" or key == "SPACE" then
        local button = controls[focus]
        if button then button:GetScript("OnClick")(button) end
    elseif key == "ESCAPE" then
        self:Hide()
    else
        self:SetPropagateKeyboardInput(true)
        return
    end
    self:SetPropagateKeyboardInput(false)
end

local function Tooltip(frame, message)
    frame:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(message, 1, 0.82, 0)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

local function Fit()
    if not panel or not UIParent.GetWidth or not UIParent.GetHeight then return end
    local scale = math.min(1, UIParent:GetWidth() / 640, UIParent:GetHeight() / 620)
    panel:SetScale(math.max(0.3, scale))
end

local function ChangePage(key, delta)
    local db = ns.Settings.Get()
    if not db then return end
    local current = key == "prowl" and db.prowlPage or db.pages[key]
    local page = math.max(0, math.min(ns.Constants.MAX_PAGE, current + delta))
    ns.Commands.Execute(key .. " " .. page)
end

function P.SelectNext(slot)
    local db = ns.Settings.Get()
    if not db then return end
    local list = ns.Mapping.Candidates()
    local current, start = db.additionalBars[slot], 0
    for index, candidate in ipairs(list) do if candidate.id == current then start = index end end
    for index = start + 1, #list do
        local candidate, used = list[index], false
        for other, id in ipairs(db.additionalBars) do
            if other ~= slot and id == candidate.id then used = true end
        end
        if not used then return ns.Commands.SelectExtra(slot, candidate.id) end
    end
    return ns.Commands.SelectExtra(slot, nil)
end

function P.Refresh()
    if not panel or not panel:IsShown() then return end
    if InCombatLockdown() then
        Focus(0)
        panel:EnableKeyboard(false)
    else
        panel:SetPropagateKeyboardInput(true)
        panel:EnableKeyboard(true)
    end
    local snapshot = ns.Mapping.Snapshot()
    Fit()
    panel.status:SetText(snapshot.state .. " · form " .. tostring(snapshot.form or 0))
    panel.owner:SetText("Main bar: " .. tostring(snapshot.owner or "unavailable")
        .. " · wants " .. tostring(snapshot.desired or "normal") .. " / applied " .. tostring(snapshot.applied or "normal"))
    for index, row in ipairs(snapshot.rows) do
        rows[index].label:SetText(row.name .. (row.learned and "" or " (not learned)"))
        rows[index].value:SetText(row.page > 0 and ("Page " .. row.page)
            or (row.key == "prowl" and "Inherit Cat" or "No switch"))
    end
    for slot = 1, ns.Constants.MAX_ADDITIONAL_BARS do
        local extra = snapshot.extras[slot]
        extras[slot]:SetText(extra and (slot .. ". " .. extra.name .. " · " .. extra.status) or (slot .. ". No extra selected"))
        Tooltip(extras[slot], extra and (extra.name .. "\n" .. extra.status .. "\nSaved bar ID: " .. extra.id) or "Use Find bars, then Next to select an extra.")
    end
    panel.enabled:SetText(snapshot.enabled and "Disable paging" or "Enable paging")
    local compatible = snapshot.compatibility
    panel.evidence:SetText(compatible and (compatible.adapter .. " · " .. compatible.evidence .. " · version " .. compatible.version) or "")
    Tooltip(panel.evidence, compatible and (compatible.method .. "\n" .. compatible.client .. "\nMatrix " .. compatible.matrix .. " · " .. compatible.fixture) or "")
    panel.warning:SetText(#snapshot.warnings > 0 and (#snapshot.warnings .. " shared-page warning(s); hover for details.") or "No configured shared-page overlap detected.")
    Tooltip(panel.warning, #snapshot.warnings > 0 and (table.concat(snapshot.warnings, "\n") .. "\nSharing slots can be intentional.") or "Extras mirror the main page; they do not create separate action slots.")
end

local function QueueRefresh(_, name)
    if not panel or not panel:IsShown() or queued then return end
    if type(name) ~= "string" then return end
    if name ~= "fp-page" and name ~= "state-formpage"
        and not name:match("^candidate%-enabled") and not name:match("^candidate%-applied") then return end
    if C_Timer and C_Timer.After then
        queued = true
        C_Timer.After(0, function() queued = false; P.Refresh() end)
    end
end

local function Create()
    panel = CreateFrame("Frame", "DruidActionBarPagerMapping", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(600, 580)
    local window = ns.Settings.Get().mappingWindow
    panel:SetPoint(window.point, UIParent, window.relativePoint, window.x, window.y)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        ns.Settings.SaveWindow(point, relativePoint, x, y)
    end)
    panel:SetScript("OnShow", P.Refresh)
    panel:SetScript("OnHide", function(self)
        Focus(0)
        self:EnableKeyboard(false)
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
    end)
    panel:SetScript("OnKeyDown", KeyDown)
    panel:SetScript("OnSizeChanged", Fit)
    if panel.TitleText then panel.TitleText:SetText("DruidActionBarPager · Mapping") end
    if UISpecialFrames then table.insert(UISpecialFrames, "DruidActionBarPagerMapping") end
    panel.status = Text(panel, 16, 18, -42, 560)
    panel.owner = Text(panel, 12, 18, -68, 560)
    Text(panel, 12, 18, -98, 250):SetText("Form")
    Text(panel, 12, 340, -98, 200):SetText("Main page · extras mirror this")
    rows = {}
    local keys = { "bear", "cat", "travel", "aquatic", "moonkin", "tree", "prowl" }
    for index, key in ipairs(keys) do
        local y = -120 - (index - 1) * 30
        rows[index] = {
            label = Text(panel, 12, 18, y - 5, 300),
            value = Text(panel, 12, 378, y - 5, 120),
        }
        Button(panel, "-", 340, y, 28, function() ChangePage(key, -1) end)
        Button(panel, "+", 510, y, 28, function() ChangePage(key, 1) end)
    end
    Text(panel, 12, 18, -340, 400):SetText("Selected extras · Next cycles discovered bars")
    Button(panel, "Find bars", 480, -332, 96, function()
        ns.Mapping.Discover()
        P.Refresh()
    end)
    extras = {}
    for slot = 1, ns.Constants.MAX_ADDITIONAL_BARS do
        local y = -365 - (slot - 1) * 30
        extras[slot] = Text(panel, 12, 18, y - 5, 438)
        Button(panel, "Next", 480, y, 96, function() P.SelectNext(slot) end)
    end
    panel.warning = Text(panel, 12, 18, -463, 560)
    panel.warning:SetTextColor(1, 0.82, 0)
    panel.evidence = Text(panel, 12, 18, -488, 560)
    panel.enabled = Button(panel, "Disable paging", 18, -530, 140, function()
        local db = ns.Settings.Get()
        if db then ns.Commands.Execute(db.enabled and "off" or "on") end
    end)
    Button(panel, "Close", 476, -530, 100, function() panel:Hide() end)
    if ns.Frames.header.HookScript then ns.Frames.header:HookScript("OnAttributeChanged", QueueRefresh) end
    Fit()
    panel:Hide()
    return panel
end

function P.Toggle()
    if not ns.Settings.Get() then return end
    if not panel then Create() end
    if panel:IsShown() then panel:Hide() else panel:Show() end
end

function P.Frame() return panel end
function P.Controls() return controls end
