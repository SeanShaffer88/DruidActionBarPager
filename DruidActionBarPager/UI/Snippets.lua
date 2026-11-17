-- Restricted snippets run only from the secure state driver or secure clicks.
local _, ns = ...
local Sn = {}
ns.Snippets = Sn

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

Sn.APPLY = [[
    local page = self:GetAttribute("fp-page")
    if not page and not self:GetAttribute("fp-active") then return end

    local function applyBar(buttonPrefix, attrPrefix, barRef, targetPage)
        local bar = self:GetFrameRef(barRef)
        for i = 1, 12 do
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
                        local slot = (targetPage - 1) * 12 + idx
                        b:SetAttribute("labtype-fp", "action")
                        b:SetAttribute("labaction-fp", slot)
                        b:RunAttribute("UpdateState", "fp")
                        b:CallMethod("ButtonContentsChanged", "fp", "action", slot)
                    else
                        local state = (bar and bar:GetAttribute("state"))
                            or self:GetAttribute(attrPrefix .. "labbase") or 0
                        b:RunAttribute("UpdateState", state)
                        b:CallMethod("UpdateAction")
                    end
                else
                    local slot
                    if targetPage then
                        slot = (targetPage - 1) * 12 + idx
                    else
                        local offset = bar and tonumber(bar:GetAttribute("actionOffset"))
                        local barpage = bar and tonumber(bar:GetAttribute("actionpage"))
                        if offset then
                            slot = offset + idx
                        elseif barpage then
                            slot = (barpage - 1) * 12 + idx
                        else
                            slot = self:GetAttribute(attrPrefix .. "base" .. i) or idx
                        end
                    end
                    if b:GetAttribute("action") ~= slot then b:SetAttribute("action", slot) end
                end
            end
        end
    end

    applyBar("button", "", "bar", page)
    for candidate = 1, 10 do
        local prefix = "candidate" .. candidate .. "-"
        local enabled = page
            and self:GetAttribute("candidate-selected" .. candidate)
            and self:GetAttribute("candidate-enabled" .. candidate)
        if enabled then
            applyBar(prefix .. "button", prefix, prefix .. "bar", page)
            self:SetAttribute("candidate-applied" .. candidate, true)
        elseif self:GetAttribute("candidate-applied" .. candidate) then
            applyBar(prefix .. "button", prefix, prefix .. "bar", nil)
            self:SetAttribute("candidate-applied" .. candidate, nil)
        end
    end

    if page then self:SetAttribute("fp-active", true)
    else self:SetAttribute("fp-active", nil) end
]]

Sn.WRAP_PRE = [[
    if name and name:sub(1, 6) == "state-" then
        local apply = control and control:GetAttribute("fp-page")
            and self == control:GetFrameRef("bar")
        if not apply and control and control:GetAttribute("fp-page") then
            for i = 1, 10 do
                if self == control:GetFrameRef("candidate" .. i .. "-bar")
                    and control:GetAttribute("candidate-selected" .. i)
                    and control:GetAttribute("candidate-enabled" .. i) then
                    apply = true
                    break
                end
            end
        end
        if apply then return nil, "dabp" end
    end
]]

Sn.WRAP_POST = [[
    if self == control:GetFrameRef("bar") and control:GetAttribute("fp-page") then
        control:RunAttribute("fp-apply")
    end
]]

ns.Frames.header:SetAttribute("_onstate-formpage", Sn.FORMPAGE)
ns.Frames.header:SetAttribute("fp-apply", Sn.APPLY)
