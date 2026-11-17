-- Static data shared by the other modules. Nothing here has behaviour.
local ADDON_NAME, ns = ...

local C = {}
ns.Constants = C

C.ADDON_NAME = ADDON_NAME
C.PREFIX = "|cffff7d0aDruidActionBarPager|r: "
C.DB_VERSION = 3

-- Each action page holds 12 buttons, and pages run 1 to 10 (0 = no switch).
C.BUTTONS_PER_PAGE = 12
C.MAX_PAGE = 10

-- Seconds before a queued rebuild runs, and the later re-check after a
-- loading screen (some bar addons finish building their bars a moment later).
C.REBUILD_DEBOUNCE = 0.2
C.LATE_REBUILD_DELAY = 2

-- Defaults: page 0 means "don't switch for this form".
C.DEFAULT_PAGES = {
    bear    = 2,
    cat     = 3,
    travel  = 0, -- utility form: keep the normal bar
    aquatic = 0, -- utility form: keep the normal bar
    moonkin = 4,
    tree    = 4,
}

C.FORM_ORDER = { "bear", "cat", "travel", "aquatic", "moonkin", "tree" }

C.FORM_LABELS = {
    bear    = "Bear / Dire Bear Form",
    cat     = "Cat Form",
    travel  = "Travel Form",
    aquatic = "Aquatic Form",
    moonkin = "Moonkin Form",
    tree    = "Tree of Life",
}

-- Known spell IDs (classic-era values; name/icon matching below covers
-- anything the Forever beta numbers differently).
C.FORM_SPELLS = {
    [5487]  = "bear",    [9634]  = "bear",
    [768]   = "cat",
    [783]   = "travel",
    [1066]  = "aquatic",
    [24858] = "moonkin",
    [33891] = "tree",
}

C.NAME_MATCH = {
    { "bear",         "bear" },
    { "cat",          "cat" },
    { "travel",       "travel" },
    { "aquatic",      "aquatic" },
    { "moonkin",      "moonkin" },
    { "tree of life", "tree" },
}

C.ICON_MATCH = {
    { "bearform",      "bear" },
    { "catform",       "cat" },
    { "travelform",    "travel" },
    { "aquaticform",   "aquatic" },
    { "forceofnature", "moonkin" },
    { "treeoflife",    "tree" },
}

-- Bar addons whose main bar can be recognised by a button-name prefix, checked
-- in order. Anything else is found by scanning the screen (see Core/BarScan).
C.KNOWN_BARS = {
    { name = "EllesmereUI", prefix = "EABButton" },
    { name = "Bartender4",  prefix = "BT4Button" },
    { name = "ElvUI",       prefix = "ElvUI_Bar1Button" },
    { name = "Dominos",     prefix = "DominosActionButton" },
    { name = "Neuron",      prefix = "NeuronActionBar1_ActionButton" },
    { name = "Blizzard",    prefix = "ActionButton" },
}
