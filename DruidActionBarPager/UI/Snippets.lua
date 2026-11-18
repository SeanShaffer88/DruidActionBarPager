-- Restricted snippets executed by SecureStateDriver, SecureHandlerWrapScript,
-- and SecureHandlerClickTemplate. WoW's BuildRestrictedClosure forbids the
-- keyword `f-u-n-c-t-i-o-n` and brace characters anywhere in snippet bodies
-- (including comments), so shared logic lives in the `fp-apply-bar` attribute
-- and is invoked through `self:RunAttribute`.
local _, ns = ...
local C = ns.Constants

local Sn = {}
ns.Snippets = Sn

local BUTTONS = C.BUTTONS_PER_PAGE
local MAX_CANDIDATES = C.MAX_DISCOVERED_BARS

Sn.FORMPAGE = [[
    if newstate == "init" then
        self:SetAttribute("skipnext", true)
        return
    end
    if newstate == "refresh" then return end
    if self:GetAttribute("skipnext") then
        self:SetAttribute("skipnext", nil)
        return
    end
    local page = tonumber(newstate)
    if not page or page <= 0 then page = nil end
    self:SetAttribute("fp-page", page)
    self:RunAttribute("fp-apply")
]]

Sn.APPLY_BAR = ([[
    local buttonPrefix, attrPrefix, barRef, targetPage = ...
    local bar = self:GetFrameRef(barRef)
    local mainBar = self:GetFrameRef("bar")
    for i = 1, %d do
        local b = self:GetFrameRef(buttonPrefix .. i)
        if b then
            local mode = self:GetAttribute(attrPrefix .. "mode" .. i)
            local idx = self:GetAttribute(attrPrefix .. "idx" .. i) or i
            if mode == "page" then
                if b:GetAttribute("actionpage") ~= targetPage then
                    b:SetAttribute("actionpage", targetPage)
                end
            elseif mode == "lab" then
                if targetPage then
                    local slot = (targetPage - 1) * %d + idx
                    b:SetAttribute("labtype-fp", "action")
                    b:SetAttribute("labaction-fp", slot)
                    b:RunAttribute("UpdateState", "fp")
                    b:CallMethod("ButtonContentsChanged", "fp", "action", slot)
                else
                    local state = bar and bar:GetAttribute("state")
                    if state == nil or state == "fp" then
                        state = self:GetAttribute(attrPrefix .. "labstate" .. i)
                    end
                    if state == nil or state == "fp" then
                        state = self:GetAttribute(attrPrefix .. "labbase")
                    end
                    if state == nil or state == "fp" then state = 0 end
                    b:RunAttribute("UpdateState", state)
                    b:CallMethod("UpdateAction")
                end
            else
                local slot
                if targetPage then
                    slot = (targetPage - 1) * %d + idx
                else
                    local actionBase = tonumber(b:GetAttribute("action-base"))
                    local ownBar = bar and (attrPrefix == "" or bar ~= mainBar)
                    local offset = ownBar and tonumber(bar:GetAttribute("actionOffset"))
                    local barpage = ownBar and tonumber(bar:GetAttribute("actionpage"))
                    if actionBase and actionBase > 0 then
                        slot = actionBase
                    elseif offset then
                        slot = offset + idx
                    elseif barpage then
                        slot = (barpage - 1) * %d + idx
                    else
                        slot = self:GetAttribute(attrPrefix .. "base" .. i) or idx
                    end
                end
                if b:GetAttribute("action") ~= slot then
                    b:SetAttribute("action", slot)
                    if type(b:GetAttribute("UpdateShown")) == "string" then
                        b:RunAttribute("UpdateShown")
                    end
                end
            end
        end
    end
]]):format(BUTTONS, BUTTONS, BUTTONS, BUTTONS)

Sn.APPLY = ([[
    local page = self:GetAttribute("fp-page")
    if not page and not self:GetAttribute("fp-active") then return end

    self:RunAttribute("fp-apply-bar", "button", "", "bar", page)
    for candidate = 1, %d do
        local prefix = "candidate" .. candidate .. "-"
        local enabled = page
            and self:GetAttribute("candidate-selected" .. candidate)
            and self:GetAttribute("candidate-enabled" .. candidate)
        if enabled then
            self:RunAttribute("fp-apply-bar", prefix .. "button", prefix, prefix .. "bar", page)
            self:SetAttribute("candidate-applied" .. candidate, true)
        elseif self:GetAttribute("candidate-applied" .. candidate) then
            self:RunAttribute("fp-apply-bar", prefix .. "button", prefix, prefix .. "bar", nil)
            self:SetAttribute("candidate-applied" .. candidate, nil)
        end
    end

    if page then
        self:SetAttribute("fp-active", true)
    else
        self:SetAttribute("fp-active", nil)
    end
]]):format(MAX_CANDIDATES)

Sn.WRAP_PRE = ([[
    if not control or not control:GetAttribute("fp-page") or not name then return end
    local paging = name == "state-page"
        or name == "state-paged"
        or name == "state-stance"
        or name == "state-current"
        or name == "state-custom"
        or name == "state-action"
        or name == "state-bar"
        or name == "state-form"
        or name == "actionpage"
        or name == "actionOffset"
    if not paging then return end
    if self == control:GetFrameRef("bar") then
        return nil, "dabp"
    end
    for i = 1, %d do
        if self == control:GetFrameRef("candidate" .. i .. "-bar")
            and control:GetAttribute("candidate-selected" .. i)
            and control:GetAttribute("candidate-enabled" .. i) then
            return nil, "dabp"
        end
    end
]]):format(MAX_CANDIDATES)

Sn.WRAP_POST = ([[
    local page = control and control:GetAttribute("fp-page")
    if not page or not message then return end
    if self == control:GetFrameRef("bar") then
        control:RunAttribute("fp-apply-bar", "button", "", "bar", page)
    end
    for i = 1, %d do
        if self == control:GetFrameRef("candidate" .. i .. "-bar")
            and control:GetAttribute("candidate-selected" .. i)
            and control:GetAttribute("candidate-enabled" .. i) then
            local prefix = "candidate" .. i .. "-"
            control:RunAttribute("fp-apply-bar", prefix .. "button", prefix, prefix .. "bar", page)
            control:SetAttribute("candidate-applied" .. i, true)
        end
    end
]]):format(MAX_CANDIDATES)

Sn.RESTORE_BAR = [[
    self:RunAttribute("fp-apply-bar", "restore-button", "restore-", "restore-bar", nil)
]]

ns.Frames.header:SetAttribute("_onstate-formpage", Sn.FORMPAGE)
ns.Frames.header:SetAttribute("fp-apply-bar", Sn.APPLY_BAR)
ns.Frames.header:SetAttribute("fp-apply", Sn.APPLY)
