-- Small helpers with no state.
local _, ns = ...

local U = {}
ns.Util = U

-- Prints a line to the chat frame, with the addon prefix.
function U.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(ns.Constants.PREFIX .. msg)
end

-- True for a whole page number from 0 (no switch) to MAX_PAGE. Anything else,
-- including nil, is not a valid page.
function U.IsValidPage(page)
    return page ~= nil and page >= 0 and page <= ns.Constants.MAX_PAGE
        and page == math.floor(page)
end
