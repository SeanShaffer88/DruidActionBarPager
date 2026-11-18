-- The only module that reads or writes DruidActionBarPagerDB. It loads,
-- repairs and migrates the table once the addon's variables are available.
local _, ns = ...
local C, U = ns.Constants, ns.Util

local S = {}
ns.Settings = S
local db

local KNOWN_KEYS = {
    enabled        = true,
    version        = true,
    pages          = true,
    additionalBars = true,
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
