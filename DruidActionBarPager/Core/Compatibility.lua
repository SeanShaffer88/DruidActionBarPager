-- Evidence describes tested contracts, never an inferred installed version.
local _, ns = ...
local K = { VERSION = 1 }
ns.Compatibility = K
local cache = {}

local adapters = {
    Blizzard = { addon = nil, fixture = "blizzard, multibars", method = "actionpage" },
    Bartender4 = { addon = "Bartender4", fixture = "bartender4", method = "LibActionButton state" },
    ElvUI = { addon = "ElvUI", fixture = "adapter detection; LAB contract", method = "LibActionButton state" },
    Dominos = { addon = "Dominos", fixture = "dominos", method = "action-base / fixed slot" },
    EllesmereUI = { addon = "EllesmereUI", fixture = "ellesmere", method = "fixed slot" },
    Neuron = { addon = "Neuron", fixture = "neuron", method = "fixed slot" },
}

function K.Describe(name)
    name = name or "unknown"
    if cache[name] then return cache[name] end
    local adapter = adapters[name]
    local metadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local version
    if adapter and adapter.addon and metadata then
        local ok, result = pcall(metadata, adapter.addon, "Version")
        if ok and type(result) == "string" then version = result end
    end
    local descriptor = {
        matrix = K.VERSION,
        adapter = adapter and name or "Generic discovery",
        detection = adapter and "Named adapter" or "Generic discovery",
        version = version or "unknown",
        evidence = "Offline mock contract",
        method = adapter and adapter.method or "detected button attributes",
        fixture = adapter and adapter.fixture or "unnamed, azerite",
        client = "Interface 16001; installed build not field-verified",
    }
    cache[name] = descriptor
    return descriptor
end

function K.Invalidate() cache = {} end
