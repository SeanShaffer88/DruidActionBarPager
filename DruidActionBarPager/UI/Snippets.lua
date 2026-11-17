-- Secure snippets, run by the game inside its restricted environment. They may
-- only use the frames and attributes they are handed (self, control, newstate,
-- name), never addon locals or the ns table, so they are kept as plain strings.
--
--   FORMPAGE  - the state driver's handler on the header: stores the wanted
--               page and runs APPLY.
--   APPLY     - points the main bar's 12 buttons at the wanted page, or restores
--               them. Each button has a mode, worked out from how it finds its
--               slot:
--                 page   - Blizzard-style buttons with an ID: override "actionpage"
--                 action - buttons holding a fixed slot (EllesmereUI, Dominos,
--                          most others): set "action" to the slot on the page
--                 lab    - LibActionButton buttons (Bartender4, ElvUI): give the
--                          button a private "fp" state holding the slot
--   WRAP_PRE / WRAP_POST - run around the bar's own state changes, so the page
--               is re-applied after the bar resets itself.
--
-- TAINT: the game's driver applies the page, not addon Lua. Registration is
-- skipped (see the "init" handling) because evaluating it from addon code can
-- taint Blizzard code and break Log Out / Exit Game.
local _, ns = ...

local Sn = {}
ns.Snippets = Sn

local header = ns.Frames.header

-- Handler for the state driver: runs for each form change.
Sn.FORMPAGE = [[
    if newstate == "init" then
        self:SetAttribute("skipnext", true)
        return
    end
    if newstate == "refresh" then
        return
    end
    if self:GetAttribute("skipnext") then
        self:SetAttribute("skipnext", nil)
        return
    end
    local page = tonumber(newstate)
    if not page or page <= 0 then
        page = nil -- caster/utility form: give the bar back
    end
    self:SetAttribute("fp-page", page)
    self:RunAttribute("fp-apply")
]]

-- Points the main bar's buttons at the wanted page (or restores them).
Sn.APPLY = [[
    local page = self:GetAttribute("fp-page")
    if not page and not self:GetAttribute("fp-active") then
        return -- nothing applied, nothing to restore
    end
    local bar = self:GetFrameRef("bar")
    for i = 1, 12 do
        local b = self:GetFrameRef("button" .. i)
        if b then
            local mode = self:GetAttribute("mode" .. i)
            local idx = self:GetAttribute("idx" .. i) or i
            if mode == "page" then
                if b:GetAttribute("actionpage") ~= page then
                    b:SetAttribute("actionpage", page)
                end
            elseif mode == "lab" then
                if page then
                    local slot = (page - 1) * 12 + idx
                    b:SetAttribute("labtype-fp", "action")
                    b:SetAttribute("labaction-fp", slot)
                    b:RunAttribute("UpdateState", "fp")
                    b:CallMethod("ButtonContentsChanged", "fp", "action", slot)
                else
                    local st = (bar and bar:GetAttribute("state")) or self:GetAttribute("labbase") or 0
                    b:RunAttribute("UpdateState", st)
                    b:CallMethod("UpdateAction")
                end
            else
                local slot
                if page then
                    slot = (page - 1) * 12 + idx
                else
                    local offset = bar and tonumber(bar:GetAttribute("actionOffset"))
                    local barpage = bar and tonumber(bar:GetAttribute("actionpage"))
                    if offset then
                        slot = offset + idx
                    elseif barpage then
                        slot = (barpage - 1) * 12 + idx
                    else
                        slot = self:GetAttribute("base" .. i) or idx
                    end
                end
                if b:GetAttribute("action") ~= slot then
                    b:SetAttribute("action", slot)
                end
            end
        end
    end
    if page then
        self:SetAttribute("fp-active", true)
    else
        self:SetAttribute("fp-active", nil)
    end
]]

-- Run before a wrapped bar's OnAttributeChanged: only "state-" changes matter.
Sn.WRAP_PRE = [[
    if name and name:sub(1, 6) == "state-" then
        return nil, "dabp"
    end
]]

-- Run after it: re-apply the page if this bar is the main bar and a page is applied.
Sn.WRAP_POST = [[
    if self == control:GetFrameRef("bar") and control:GetAttribute("fp-page") then
        control:RunAttribute("fp-apply")
    end
]]

-- Install the state handler and the apply step on the header.
header:SetAttribute("_onstate-formpage", Sn.FORMPAGE)
header:SetAttribute("fp-apply", Sn.APPLY)
