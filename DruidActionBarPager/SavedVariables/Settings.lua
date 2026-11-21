-- The only module that reads or writes DruidActionBarPagerDB. It loads,
-- repairs and migrates the table once the addon's variables are available.
local _, ns = ...
local C, U = ns.Constants, ns.Util

local S = {}
ns.Settings = S
local db
local ANCHORS = { CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
    TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }

local KNOWN_KEYS = {
    enabled        = true,
    version        = true,
    pages          = true,
    additionalBars = true,
    prowlPage      = true,
    mappingWindow  = true,
}

local function MigrateFromV1(pages)
    if tonumber(pages.travel) == 4 then pages.travel = 0 end
    if tonumber(pages.aquatic) == 5 then pages.aquatic = 0 end
end

local function MigrateFromV2(pages)
    if tonumber(pages.moonkin) == 6 then pages.moonkin = 4 end
    if tonumber(pages.tree) == 6 then pages.tree = 4 end
end

local function RepairPages(pages)
    for form, default in pairs(C.DEFAULT_PAGES) do
        local page = tonumber(pages[form])
        if not U.IsValidPage(page) then page = default end
        pages[form] = page
    end
    for form in pairs(pages) do
        if C.DEFAULT_PAGES[form] == nil then pages[form] = nil end
    end
end

local function RepairAdditionalBars(bars)
    local repaired, seen = {}, {}
    for _, id in ipairs(bars) do
        if type(id) == "string" and id ~= "" and not seen[id]
            and #repaired < C.MAX_ADDITIONAL_BARS then
            repaired[#repaired + 1] = id
            seen[id] = true
        end
    end
    return repaired
end

function S.Load(name)
    if name ~= C.ADDON_NAME then return false end
    -- Refuse a future save before assigning or repairing any persistent value.
    if type(DruidActionBarPagerDB) == "table"
        and type(DruidActionBarPagerDB.version) == "number"
        and DruidActionBarPagerDB.version > C.DB_VERSION then
        U.Print("Settings belong to a newer version. Install that version to use them.")
        return false
    end
    if type(DruidActionBarPagerDB) ~= "table" then DruidActionBarPagerDB = {} end
    db = DruidActionBarPagerDB
    if type(db.enabled) ~= "boolean" then db.enabled = true end
    if type(db.pages) ~= "table" then db.pages = {} end
    if type(db.version) ~= "number" or db.version ~= db.version then
        db.version = nil
    end

    local version = db.version or 1
    if version < 2 then MigrateFromV1(db.pages) end
    if version < 3 then MigrateFromV2(db.pages) end
    db.version = C.DB_VERSION
    if not U.IsValidPage(db.prowlPage) then db.prowlPage = 0 end
    local window = db.mappingWindow
    local function coordinate(value)
        return type(value) == "number" and value == value and math.abs(value) <= 10000
    end
    if type(window) ~= "table" or not ANCHORS[window.point] or not ANCHORS[window.relativePoint]
        or not coordinate(window.x) or not coordinate(window.y) then
        db.mappingWindow = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
    else
        db.mappingWindow = { point = window.point, relativePoint = window.relativePoint, x = window.x, y = window.y }
    end

    RepairPages(db.pages)
    if type(db.additionalBars) ~= "table" then db.additionalBars = {} end
    db.additionalBars = RepairAdditionalBars(db.additionalBars)

    for key in pairs(db) do
        if not KNOWN_KEYS[key] then db[key] = nil end
    end
    return true
end

function S.Get()
    return db
end

function S.SetPage(form, page)
    if not db or not U.IsValidPage(page) then return false end
    if form == "prowl" then db.prowlPage = page
    elseif C.DEFAULT_PAGES[form] ~= nil then db.pages[form] = page
    else return false end
    return true
end

function S.SetExtra(slot, id)
    if not db or type(slot) ~= "number" or slot ~= math.floor(slot)
        or slot < 1 or slot > C.MAX_ADDITIONAL_BARS then return false end
    if id ~= nil and (type(id) ~= "string" or id == "" or slot > #db.additionalBars + 1) then return false end
    for index, saved in ipairs(db.additionalBars) do
        if saved == id and index ~= slot then return false end
    end
    if id then db.additionalBars[slot] = id
    elseif db.additionalBars[slot] then table.remove(db.additionalBars, slot) end
    return true
end

function S.SaveWindow(point, relativePoint, x, y)
    if not db or not ANCHORS[point] or not ANCHORS[relativePoint]
        or type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y
        or math.abs(x) > 10000 or math.abs(y) > 10000 then return false end
    db.mappingWindow = { point = point, relativePoint = relativePoint, x = x, y = y }
    return true
end
