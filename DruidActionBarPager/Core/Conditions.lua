-- Builds the state-driver condition that tells the game which page each form
-- wants, yielding to override/vehicle/possess/temp-shapeshift bars first.
-- Pure: the result depends only on the settings table and the player's forms.
local _, ns = ...
local C = ns.Constants

local Cd = {}
ns.Conditions = Cd

-- Override guard first, then one "[form:N]page" clause per configured form,
-- then "0" (normal bar). Returns "0" when disabled or no forms map to a page.
function Cd.Build(settings)
    if not settings or not settings.enabled then
        return "0"
    end

    local formParts = {}
    for i = 1, ns.Forms.Count() do
        local key = ns.Forms.Classify(i)
        local page = key and settings.pages[key]
        if page and page > 0 then
            formParts[#formParts + 1] = ("[form:%d]%d"):format(i, page)
        end
    end
    if #formParts == 0 then
        return "0"
    end

    local parts = { C.OVERRIDE_CONDITION }
    for i = 1, #formParts do parts[#parts + 1] = formParts[i] end
    parts[#parts + 1] = "0"
    return table.concat(parts, ";")
end
