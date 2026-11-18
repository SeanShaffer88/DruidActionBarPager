-- Small helpers with no state.
local _, ns = ...

local U = {}
ns.Util = U

-- Prints a line to the chat frame, with the addon prefix.
function U.Print(msg)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(ns.Constants.PREFIX .. msg)
    end
end

-- True when the logged-in character is a druid.
function U.IsDruid()
    if not UnitClass then return false end
    local _, class = UnitClass("player")
    return class == "DRUID"
end

-- True for a whole page number from 0 (no switch) to MAX_PAGE. Anything else,
-- including nil, is not a valid page.
function U.IsValidPage(page)
    return page ~= nil and page >= 0 and page <= ns.Constants.MAX_PAGE
        and page == math.floor(page)
end
