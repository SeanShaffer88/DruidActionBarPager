-- Secure click targets let per-extra-bar bindings change protected button attrs
-- during combat without calling insecure Lua.
local _, ns = ...
local C = ns.Constants
local K = {}
ns.KeyBindings = K

BINDING_HEADER_DRUIDACTIONBARPAGER = "Druid Action Bar Pager"
for i = 1, C.MAX_ADDITIONAL_BARS do
    _G["BINDING_NAME_DABP_TOGGLE_EXTRA" .. i] = "Toggle selected extra bar " .. i
end
BINDING_NAME_DABP_TOGGLE_ALL_EXTRAS = "Toggle all selected extra bars"

local header = ns.Frames.header
local buttons = {}
local allButtons = {}
local owner = header
local bindingsDirty = false
local clicksDirty = false

local function WantedClickType()
    if GetCVarBool then
        local ok, useDown = pcall(GetCVarBool, "ActionButtonUseKeyDown")
        if ok and useDown then return "LeftButtonDown" end
    end
    return "LeftButtonUp"
end

local function ApplyClickType(button, clickType)
    if button and button.RegisterForClicks then
        button:RegisterForClicks(clickType)
    end
end

local function MakeButton(name, script)
    local button = CreateFrame("Button", name, UIParent, "SecureHandlerClickTemplate")
    button:SetFrameRef("header", header)
    button:SetAttribute("_onclick", script)
    button:SetSize(1, 1)
    button:SetAlpha(0)
    if button.EnableMouse then button:EnableMouse(false) end
    ApplyClickType(button, WantedClickType())
    button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    button:Show()
    allButtons[#allButtons + 1] = button
    return button
end

for i = 1, C.MAX_ADDITIONAL_BARS do
    buttons[i] = MakeButton("DruidActionBarPagerToggleExtra" .. i, ([[
        local control = self:GetFrameRef("header")
        local candidate = control:GetAttribute("selectedCandidate%d")
        if candidate then
            local key = "candidate-enabled" .. candidate
            control:SetAttribute(key, not control:GetAttribute(key))
            control:RunAttribute("fp-apply")
        end
    ]]):format(i))
end

local allButton = MakeButton("DruidActionBarPagerToggleAllExtras", ([[
    local control = self:GetFrameRef("header")
    local allOn = true
    for candidate = 1, %d do
        if control:GetAttribute("candidate-selected" .. candidate)
            and not control:GetAttribute("candidate-enabled" .. candidate) then
            allOn = false
            break
        end
    end
    local enabled = not allOn
    for candidate = 1, %d do
        if control:GetAttribute("candidate-selected" .. candidate) then
            control:SetAttribute("candidate-enabled" .. candidate, enabled)
        end
    end
    control:RunAttribute("fp-apply")
]]):format(C.MAX_DISCOVERED_BARS, C.MAX_DISCOVERED_BARS))

for i = 1, C.MAX_DISCOVERED_BARS do
    if header:GetAttribute("candidate-enabled" .. i) == nil then
        header:SetAttribute("candidate-enabled" .. i, true)
    end
end

local function Bind(action, button)
    if not GetBindingKey then return end
    local keyCount = select("#", GetBindingKey(action))
    for i = 1, keyCount do
        local key = select(i, GetBindingKey(action))
        if key and key ~= "" then
            SetOverrideBindingClick(owner, false, key, button:GetName(), "LeftButton")
        end
    end
end

function K.UpdateClickMode()
    if InCombatLockdown() then
        clicksDirty = true
        return
    end
    clicksDirty = false
    local clickType = WantedClickType()
    for _, button in ipairs(allButtons) do
        ApplyClickType(button, clickType)
    end
end

function K.OnCVarUpdate(cvarName)
    if type(cvarName) == "string" and cvarName:lower() == "actionbuttonusekeydown" then
        K.UpdateClickMode()
    end
end

function K.Refresh()
    if not ClearOverrideBindings or not SetOverrideBindingClick then return end
    if InCombatLockdown() then
        bindingsDirty = true
        return
    end
    bindingsDirty = false
    ClearOverrideBindings(owner)
    for i = 1, C.MAX_ADDITIONAL_BARS do
        Bind("DABP_TOGGLE_EXTRA" .. i, buttons[i])
    end
    Bind("DABP_TOGGLE_ALL_EXTRAS", allButton)
end

function K.FlushPending()
    if clicksDirty then K.UpdateClickMode() end
    if bindingsDirty then K.Refresh() end
end

K.Buttons = buttons
K.AllButton = allButton
