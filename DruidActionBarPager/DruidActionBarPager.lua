--[[
    DruidActionBarPager - automatic action bar paging for druid forms
    Copyright (C) 2026 Malikor

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

    HOW IT WORKS
    Shapeshifting happens in combat, and Blizzard blocks addons from
    changing the action bar from normal Lua while in combat. So DruidActionBarPager
    uses a secure state driver: the game itself evaluates "[form:N]" macro
    conditions and runs a small secure snippet that repoints the 12 buttons
    of whichever main bar is on screen -- Blizzard's, or a bar addon's
    (EllesmereUI, Bartender4, ElvUI, Dominos, or any other it can find).
    Only finding the bar and (re)building the driver needs to happen out of
    combat, which is done on login and whenever you learn a new form.
]]

local _, ns = ...

-- Entry point, loaded last. Every module above it is already loaded, so this
-- only connects them to the game: slash commands and game events.
ns.Commands.Register()
ns.Events.Install()
