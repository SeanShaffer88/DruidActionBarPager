-- Builds the state-driver condition that tells the game which page each form
-- wants, e.g. "[form:1]2;[form:3]3;0". Pure: the result depends only on the
-- settings table and the forms the player has.
local _, ns = ...

local Cd = {}
ns.Conditions = Cd

-- One "[form:N]page" clause per form with a page, then "0" (normal bar).
function Cd.Build(settings)
    if not settings.enabled then
        return "0"
    end

    local parts = {}
    for i = 1, ns.Forms.Count() do
        local key = ns.Forms.Classify(i)
        local page = key and settings.pages[key]
        if page and page > 0 then
            parts[#parts + 1] = ("[form:%d]%d"):format(i, page)
        end
    end
    parts[#parts + 1] = "0"
    return table.concat(parts, ";")
end
