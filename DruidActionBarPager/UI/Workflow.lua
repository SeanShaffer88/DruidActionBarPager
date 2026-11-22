-- One unprotected child; settings tokens, not widgets, authorize every apply.
local _, ns = ...
local W = {}
ns.Workflow = W
local frame, epoch, focus, dead = nil, 0, 0, false
local keys = {"bear", "cat", "travel", "aquatic", "moonkin", "tree", "prowl"}
local reasons = {
    combat = "Leave combat before applying this review.", dead = "Return to life before applying this review.",
    generation = "Settings changed. Open a fresh review.", conflict = "Settings changed. Open a fresh review.",
    invalid = "The mapping is invalid.", future = "These settings require a newer addon.",
    unavailable = "This operation is unavailable.", empty = "There is no mapping change to review.",
    overflow = "Saved profiles exceed the supported limit.", limit = "The supported limit was reached.",
}
local function Blocked()
    return InCombatLockdown() or dead or (ns.Settings.IsDead and ns.Settings.IsDead())
end
function W.Blocked() return Blocked() end
function W.IsOpen() return frame and frame:IsShown() or false end
function W.Frame() return frame end
local function Text(parent, x, y, width, height)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetPoint("TOPLEFT", x, y); holder:SetSize(width, height)
    local font = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    font:SetAllPoints(holder); font:SetJustifyH("LEFT"); font:SetWordWrap(true)
    holder.SetText = function(self, text) self.text = text; font:SetText(text) end
    return holder
end
local function Focus(index)
    if frame.buttons[focus] then frame.buttons[focus]:UnlockHighlight() end
    focus = index
    if frame.buttons[focus] then frame.buttons[focus]:LockHighlight() end
end
local function Capture()
    if not frame then return end
    local active = frame:IsShown() and not Blocked() and not frame.editing
    frame:EnableKeyboard(not not active)
    if Blocked() then frame.edit:ClearFocus() end
    if not Blocked() then frame:SetPropagateKeyboardInput(true) end
    if not active then Focus(0) end
end
local function Live(token)
    return frame and frame:IsShown() and epoch == token and ns.MappingPanel.Frame():IsShown()
end
local function Error(reason)
    frame.message:SetText(reasons[reason] or "This operation is unavailable. Open a fresh review.")
end
function W.Close()
    if not frame then return end
    epoch = epoch + 1
    frame:Hide()
end
local function Create()
    frame = CreateFrame("Frame", "DruidActionBarPagerWorkflow", ns.MappingPanel.Frame(), "BasicFrameTemplateWithInset")
    frame:SetSize(560, 510); frame:SetPoint("CENTER", ns.MappingPanel.Frame(), "CENTER", 0, 0)
    frame:SetClampedToScreen(true); frame:EnableMouse(true)
    frame.buttons, frame.icons = {}, {}
    frame.title = Text(frame, 18, -32, 520, 24)
    frame.message = Text(frame, 18, -62, 520, 56)
    frame.details = Text(frame, 18, -285, 520, 160)
    frame.editArea = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.editArea:SetPoint("TOPLEFT", 24, -125); frame.editArea:SetSize(490, 220)
    frame.edit = CreateFrame("EditBox", nil, frame.editArea, "InputBoxTemplate")
    frame.edit:SetSize(490, 220)
    frame.editArea:SetScrollChild(frame.edit)
    frame.edit:SetMultiLine(true); frame.edit:SetAutoFocus(false)
    frame.edit:SetFontObject("GameFontHighlightSmall"); frame.edit:SetMaxLetters(4096)
    frame.edit:SetScript("OnEscapePressed", W.Close)
    frame.edit:SetScript("OnEditFocusGained", function(self)
        if not frame:IsShown() or not self:IsShown() then self:ClearFocus(); return end
        frame.editing = true
        if Blocked() then self:ClearFocus() end
        Capture()
    end)
    frame.edit:SetScript("OnTabPressed", function()
        frame.edit:ClearFocus(); frame.editing = false; Capture(); Focus(1)
    end)
    for index = 1, 12 do
        local icon = CreateFrame("Frame", nil, frame)
        icon:SetSize(78, 70); icon:SetPoint("TOPLEFT", 18 + ((index-1)%6)*88, -130-math.floor((index-1)/6)*76)
        icon.texture = icon:CreateTexture(nil, "ARTWORK"); icon.texture:SetAllPoints(icon)
        icon.label = Text(icon, 0, 0, 78, 70); frame.icons[index] = icon
    end
    frame:SetScript("OnHide", function()
        epoch = epoch + 1; frame.token = nil; frame.edit:ClearFocus()
        frame:EnableKeyboard(false); Focus(0)
        if GameTooltip then GameTooltip:Hide() end
        ns.MappingPanel.Refresh()
    end)
    frame:SetScript("OnKeyDown", function(self, key)
        if Blocked() or self.editing then Capture(); return end
        if key == "ESCAPE" then W.Close()
        elseif key == "TAB" then
            local step = IsShiftKeyDown and IsShiftKeyDown() and -1 or 1
            Focus(focus == 0 and (step > 0 and 1 or #self.buttons) or ((focus-1+step)%#self.buttons+1))
        elseif key == "ENTER" or key == "SPACE" then
            local button = self.buttons[focus]
            if button and button:IsShown() then button:GetScript("OnClick")(button) end
        else self:SetPropagateKeyboardInput(true); return end
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(false) end
    end)
    frame:Hide()
end
local function Button(label, x, y, width, callback)
    local button = frame.pool[#frame.buttons+1]
    if not button then
        button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        frame.pool[#frame.buttons+1] = button
    end
    local token = epoch
    button:SetSize(width, 24); button:SetPoint("TOPLEFT", x, y); button:SetText(label)
    button:SetScript("OnClick", function()
        if not Live(token) then return end
        if callback ~= W.Close and Blocked() then Error(InCombatLockdown() and "combat" or "dead"); return end
        callback()
    end)
    button:Show(); frame.buttons[#frame.buttons+1] = button
    return button
end
local function Begin(view)
    ns.MappingPanel.Show()
    if not frame then Create(); frame.pool = {} end
    epoch = epoch + 1; Focus(0)
    for _, button in ipairs(frame.pool) do button:Hide() end
    for _, icon in ipairs(frame.icons) do icon:Hide() end
    frame.buttons = {}; frame.view = view; frame.token = nil; frame.editing = false
    frame.edit:ClearFocus(); frame.edit:Hide(); frame.editArea:Hide(); frame.details:SetText(""); frame.message:SetText("")
    frame:SetFrameLevel(ns.MappingPanel.Frame():GetFrameLevel()+10)
    frame:SetScale(math.max(.3, math.min(1, UIParent:GetWidth()/600, UIParent:GetHeight()/550)))
    frame:Show(); ns.MappingPanel.Refresh(); Capture()
    frame.title:SetText(view)
end
local function Lines(model)
    local out = {}
    for _, change in ipairs(model.changes or {}) do
        out[#out+1] = (ns.Constants.FORM_LABELS[change.form] or change.form) .. ": " .. tostring(change.before) .. " → " .. tostring(change.after)
    end
    if #out == 0 then out[1] = "No form pages change." end
    return table.concat(out, "\n")
end
local function Review(model, apply)
    if not model then Error(apply); return end
    frame.token = model
    frame.details:SetText(Lines(model))
    local token = model
    Button("Apply reviewed mapping", 18, -452, 200, function()
        local ok, reason = apply(token)
        if ok then ns.Rebuild.Now(true); W.Close() else Error(reason) end
    end)
end
local function Cancel() Button("Cancel", 430, -452, 100, W.Close) end
local function PaintPreview()
    local model = ns.Actions.Preview(frame.form, frame.page)
    model = model or {mode="unavailable", available=false, slots={}}
    frame.preview = model
    frame.message:SetText((ns.Constants.FORM_LABELS[frame.form] or frame.form) .. " · Page " .. frame.page
        .. " · " .. (model.mode or "unknown") .. (model.available == false and " · unavailable" or ""))
    for index, icon in ipairs(frame.icons) do
        local slot = model.slots and model.slots[index]
        if slot then
            icon:Show(); icon.texture:SetTexture(slot.texture)
            icon.label:SetText(index .. " · Slot " .. tostring(slot.slot or "?") .. "\n" .. tostring(slot.label or slot.state or "Unknown"))
        else icon:Hide() end
    end
end
function W.Preview(form, page)
    form = form or "cat"
    local supplied = page ~= nil
    page = tonumber(page)
    if supplied and page == nil then return false end
    local map = ns.Settings.Mapping()
    if not map or map[form] == nil or (page and (page%1 ~= 0 or page < 0 or page > 10)) then return false end
    page = page or map[form]
    Begin("Preview page before assigning"); frame.form, frame.page = form, page
    PaintPreview()
    Button("Next form", 18, -100, 120, function()
        local nextIndex = 1
        for index,key in ipairs(keys) do if key == frame.form then nextIndex = index%#keys+1 end end
        W.Preview(keys[nextIndex], frame.page)
    end)
    Button("-", 150, -100, 40, function() W.Preview(frame.form, math.max(0,frame.page-1)) end)
    Button("+", 200, -100, 40, function() W.Preview(frame.form, math.min(10,frame.page+1)) end)
    map[form] = page
    local model, reason = ns.Settings.StageMapping(map, "preview")
    Review(model, model and ns.Settings.ApplyMapping or reason); Cancel(); Capture()
    return true
end
function W.Reset()
    Begin("Reset current profile to defaults?")
    frame.message:SetText("Only the seven form pages change. Extra bars, enabled state and positions stay unchanged.")
    local model, reason = ns.Settings.ResetPreview()
    Review(model, model and ns.Settings.ApplyMapping or reason); Cancel(); Capture()
end
function W.Undo()
    Begin("Undo the last mapping edit?")
    local model, reason = ns.Settings.UndoPreview()
    Review(model, model and ns.Settings.ApplyMapping or reason); Cancel(); Capture()
end
function W.Profiles(selected)
    Begin("Character profiles")
    local status = ns.Profiles.Status()
    frame.message:SetText("Active profile: " .. tostring(status.active or "unavailable") .. "\n"
        .. (status.specAvailable and "Readable spec-group binding available." or "Automatic switching unavailable; use manual profiles."))
    if not status.characterAvailable then
        frame.message:SetText("Character identity is unavailable. Persistent profiles and spec-group bindings are unavailable.")
    end
    for index, profile in ipairs(ns.Profiles.List()) do
        Button(profile.label, 18+(index-1)*132, -130, 125, function() W.Profiles(profile.id) end)
    end
    if selected then
        frame.message:SetText("Active profile: " .. tostring(status.active or "unavailable") .. " · Reviewing: " .. selected
            .. "\nApply activates this profile even when its form pages match the current mapping.")
        local model, reason = ns.Profiles.Preview(selected)
        Review(model, model and ns.Profiles.Apply or reason)
    end
    Button("Bind current spec-group", 18, -210, 245, function()
        local ok, reason = ns.Profiles.BindCurrent(); if ok then W.Profiles() else Error(reason) end
    end)
    Button("Unbind current spec-group", 280, -210, 250, function()
        local ok, reason = ns.Profiles.UnbindCurrent(); if ok then W.Profiles() else Error(reason) end
    end)
    Cancel(); Capture()
end
function W.Share(text)
    Begin("Share or import form pages")
    frame.message:SetText("Form pages only. Bar IDs, player identity, profiles and action contents are excluded. Paste a mapping, then Review import. Tab focuses the review button.")
    frame.edit:SetMaxLetters(4096); frame.edit:SetText(text or ns.Sharing.Export() or "")
    frame.editArea:Show(); frame.edit:Show(); frame.editing = true; if not Blocked() then frame.edit:SetFocus(); frame.edit:HighlightText() end
    Button("Review import", 18, -400, 180, function() W.ImportReview(frame.edit:GetText()) end)
    Cancel(); Capture()
end
function W.ImportReview(text)
    local model, reason = ns.Sharing.Stage(text)
    Begin("Review imported form pages")
    frame.message:SetText("Only form pages in the active profile change; extra bar IDs, identity and action contents are excluded.")
    Review(model, model and ns.Settings.ApplyMapping or reason)
    Button("Back", 300, -452, 100, function() W.Share(text) end); Cancel(); Capture()
end
function W.Support()
    Begin("Copy support report")
    frame.message:SetText("Select the text and press Ctrl+A / Ctrl+C. This local report is never uploaded automatically.")
    frame.edit:SetText(ns.Support.Build()); frame.editArea:Show(); frame.edit:Show(); frame.editing = true
    if not Blocked() then frame.edit:SetFocus(); frame.edit:HighlightText() end; Cancel(); Capture()
end
function W.Refresh()
    if not W.IsOpen() then return end
    Capture()
    if frame.view == "Preview page before assigning" then PaintPreview() end
end
function W.OnEvent(event)
    if event == "PLAYER_DEAD" then dead = true
    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then dead = false end
    W.Refresh()
end
