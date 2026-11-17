-- The only module that reads or writes DruidActionBarPagerDB (the saved
-- variables). It loads, repairs and migrates the table once the addon's
-- variables are available, and hands the table to the other modules.
local _, ns = ...
local C, U = ns.Constants, ns.Util

local S = {}
ns.Settings = S

-- Bound by Load(). Every other module reads the same table through Get().
local db

-- Version 1 switched Travel/Aquatic to pages 4/5. They are utility forms and
-- keep the normal bar, so only the old defaults are cleared.
local function MigrateFromV1(pages)
    if pages.travel == 4 then pages.travel = 0 end
    if pages.aquatic == 5 then pages.aquatic = 0 end
end

-- Moonkin/Tree moved from page 6 to page 4; only the old default is cleared.
local function MigrateFromV2(pages)
    if pages.moonkin == 6 then pages.moonkin = 4 end
    if pages.tree == 6 then pages.tree = 4 end
end

-- Invalid pages fall back to their defaults, and unknown keys are removed.
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

-- Called with each ADDON_LOADED name. Returns true once this addon's saved
-- variables have been loaded.
function S.Load(name)
    if name ~= C.ADDON_NAME then return false end

    -- Guard against a missing, corrupted or hand-edited WTF table.
    if type(DruidActionBarPagerDB) ~= "table" then DruidActionBarPagerDB = {} end
    db = DruidActionBarPagerDB
    if type(db.enabled) ~= "boolean" then db.enabled = true end
    if type(db.pages) ~= "table" then db.pages = {} end
    if type(db.version) ~= "number" then db.version = nil end

    local version = db.version or 1
    if version < 2 then MigrateFromV1(db.pages) end
    if version < 3 then MigrateFromV2(db.pages) end
    db.version = C.DB_VERSION

    RepairPages(db.pages)
    return true
end

-- The saved settings table, or nil before Load() has run.
function S.Get()
    return db
end
