-- Secure click targets let per-extra-bar bindings change protected button attrs.
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
local owner = header

local function MakeButton(name, script)
    local button = CreateFrame("Button", name, UIParent, "SecureHandlerClickTemplate")
    button:SetFrameRef("header", header)
    button:SetAttribute("_onclick", script)
    button:SetSize(1, 1)
    button:SetAlpha(0)
    button:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    button:Show()
    return button
end

for i = 1, C.MAX_ADDITIONAL_BARS do
    local index = i
    buttons[i] = MakeButton("DruidActionBarPagerToggleExtra" .. i, [[
        local control = self:GetFrameRef("header")
        local candidate = control:GetAttribute("selectedCandidate" .. ]] .. index .. [[)
        if candidate then
            local key = "candidate-enabled" .. candidate
            control:SetAttribute(key, not control:GetAttribute(key))
            control:RunAttribute("fp-apply")
        end
    ]])
end

local allButton = MakeButton("DruidActionBarPagerToggleAllExtras", [[
    local control = self:GetFrameRef("header")
    local allOn = true
    for candidate = 1, 10 do
        if control:GetAttribute("candidate-selected" .. candidate)
            and not control:GetAttribute("candidate-enabled" .. candidate) then
            allOn = false
            break
        end
    end
    local enabled = not allOn
    for candidate = 1, 10 do
        if control:GetAttribute("candidate-selected" .. candidate) then
            control:SetAttribute("candidate-enabled" .. candidate, enabled)
        end
    end
    control:RunAttribute("fp-apply")
]])
for i = 1, C.MAX_DISCOVERED_BARS do
    if header:GetAttribute("candidate-enabled" .. i) == nil then
        header:SetAttribute("candidate-enabled" .. i, true)
    end
end

local function Bind(action, button)
    if not GetBindingKey then return end
    local first, second = GetBindingKey(action)
    if first and first ~= "" then
        SetOverrideBindingClick(owner, false, first, button:GetName(), "LeftButton")
    end
    if second and second ~= "" then
        SetOverrideBindingClick(owner, false, second, button:GetName(), "LeftButton")
    end
end

function K.Refresh()
    if not ClearOverrideBindings or not SetOverrideBindingClick then return end
    if InCombatLockdown() then return end
    ClearOverrideBindings(owner)
    for i = 1, C.MAX_ADDITIONAL_BARS do
        Bind("DABP_TOGGLE_EXTRA" .. i, buttons[i])
    end
    Bind("DABP_TOGGLE_ALL_EXTRAS", allButton)
end

K.Buttons = buttons
K.AllButton = allButton
