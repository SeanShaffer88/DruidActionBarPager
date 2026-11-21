-- Static data shared by the other modules. Nothing here has behaviour.
local ADDON_NAME, ns = ...

local C = {}
ns.Constants = C

C.ADDON_NAME = ADDON_NAME
C.PREFIX = "|cffff7d0aDruidActionBarPager|r: "
C.DB_VERSION = 4

-- Each action page holds 12 buttons; configurable form pages run 1 to 10
-- (0 = no switch), while action-bar discovery covers slots 1 to 180 (pages 1-15,
-- including Blizzard MultiBar5-7 and third-party high-page extra bars).
C.BUTTONS_PER_PAGE = 12
C.MAX_PAGE = 10
C.MAX_SCAN_SLOT = 180
C.MAX_ADDITIONAL_BARS = 3
C.MAX_DISCOVERED_BARS = 10

-- Yield action bars whenever a vehicle, override, possess, temporary shapeshift,
-- or skyriding bar is active, even if a druid form aura stays up.
C.OVERRIDE_CONDITION = "[overridebar][vehicleui][possessbar][shapeshift][bonusbar:5]0"

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

-- Whole-word Lua frontier patterns so unrelated stances (e.g. "Scatter" or
-- "Wildcat") do not match a druid form name.
C.NAME_MATCH = {
    { "%f[%a]bear%f[%A]",         "bear" },
    { "%f[%a]cat%f[%A]",          "cat" },
    { "%f[%a]travel%f[%A]",       "travel" },
    { "%f[%a]aquatic%f[%A]",      "aquatic" },
    { "%f[%a]moonkin%f[%A]",      "moonkin" },
    { "%f[%a]tree of life%f[%A]", "tree" },
}

-- Numeric fileDataIDs returned by GetShapeshiftFormInfo in modern/Forever
-- clients; locale-independent fallback when spell IDs change.
C.ICON_FILE_IDS = {
    [132276] = "bear",    -- Ability_Racial_BearForm
    [132115] = "cat",     -- Ability_Druid_CatForm
    [132144] = "travel",  -- Ability_Druid_TravelForm
    [132112] = "aquatic", -- Ability_Druid_AquaticForm
    [136036] = "moonkin", -- Spell_Nature_ForceOfNature
    [132145] = "tree",    -- Ability_Druid_TreeOfLife
}

-- Legacy texture-path substrings for clients/fixtures returning string paths.
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

-- Protected system/special button prefixes that are never player action bars.
C.IGNORED_BUTTON_PREFIXES = {
    OverrideActionBarButton = true,
    MultiCastActionButton   = true,
    MultiCastSlotButton     = true,
    MultiCastSpellButton    = true,
    PossessButton           = true,
    PetActionButton         = true,
    StanceButton            = true,
    ShapeshiftButton        = true,
    ExtraActionButton       = true,
    SpellFlyoutButton       = true,
    SpellFlyoutPopupButton  = true,
}
