-- The two frames the addon owns. Creating them does nothing else; the snippets
-- are attached in UI/Snippets.lua and the events in Core/Events.lua.
local _, ns = ...

local Fr = {}
ns.Frames = Fr

-- Secure state header: the game's state driver runs its snippets here, and it
-- holds the references to the bar and its buttons. The name makes it a global,
-- which the secure environment needs.
Fr.header = CreateFrame("Frame", "DruidActionBarPagerHeader", UIParent, "SecureHandlerStateTemplate")

-- Plain frame that receives game events.
Fr.events = CreateFrame("Frame")
