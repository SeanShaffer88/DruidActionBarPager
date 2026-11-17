# Changelog

All notable changes to DruidActionBarPager are documented here.

## [Unreleased]

### Added
- Works with more action bar addons: Neuron is recognised by name, and any bar built on LibActionButton (AzeriteUI, ConsolePort and others) is found by the screen scan, which now reads LibActionButton's current slot.
- Bars whose buttons have no names are found too: the scan groups unnamed buttons by their parent bar.
- Bar paging is re-applied after any state change of the bar, not only page changes, so bars that switch state a different way keep the form page.

### Changed
- Only Blizzard's own action buttons (ActionButton1–12) are switched with a page override. Other addons' buttons that carry an ID are switched by slot, since the page override does nothing on them.

### Fixed
- The form page now holds on the bar that actually switches. The Blizzard main bar's own paging (bonus bar) was never hooked, so it could overwrite the page the addon had applied (e.g. page 6 applied, page 2 shown). Blizzard's bar is now hooked the same way as the bar addons.
- After `/reload` while shifted, the page the form wants is armed right after login, so the next form event applies it. Previously it could stay on the default page until you shifted out and back in.
- Shapeshifting no longer triggers a bar rebuild and its 0.2 s debounce. A rebuild only runs when the form list changes (forms learned, spell data loaded), so shifts switch the bar without the extra delay.

## [1.1.2-patched.1] - 2026-11-14

- Restore or replace an active form page through the secure state driver when settings change.
- Reapply form pages only when the currently attached third-party bar changes its own page.
- Preserve original button slots during rebuilds while a form page is active.

## [1.1.2] - 2026-10-15

### Fixed
- Form names are read with `C_Spell.GetSpellName`; the old global `GetSpellInfo` no longer exists in this client, so name-based form detection was silently off. Spell data that isn't loaded yet is requested and the forms are rechecked once it arrives.
- Corrupted or hand-edited saved settings are repaired on load: invalid pages fall back to their defaults and unknown entries are removed.

### Changed
- Bursts of spell and form events now trigger one rebuild instead of many.
- The detected main bar is cached, so the full-screen frame scan used for unknown bar addons only runs after a loading screen or a `/dabp` change, not on every event.
- `PLAYER_LOGIN` is unregistered after startup.

## [1.1.1] - 2026-10-14

### Changed
- Verified compatible with Forever beta build 1.60.1.70374. No functional changes.

## [1.1.0] - 2026-10-13

### Added
- Works with action bar addons: EllesmereUI, Bartender4, ElvUI and Dominos are detected automatically, and any other bar addon is found by scanning the screen for the visible main bar (the buttons showing slots 1–12).
- Bars with their own form paging (Bartender4, ElvUI, Dominos) no longer override DruidActionBarPager: when they switch bar 1 for a form, DruidActionBarPager's page is reapplied immediately.
- `/dabp debug` shows which bar DruidActionBarPager is driving, whether it's hooked into that bar's paging, and the page currently applied.
- New icon and logo: two action bars trading places, in druid colors.

### Changed
- Renamed from FormPager to DruidActionBarPager. Slash commands are now `/dabp` and `/druidactionbarpager` (previously `/fpage` and `/formpager`). Settings are saved under the new name, so pages you changed in FormPager need setting again.
- Moonkin Form (and Tree of Life) now switches to page 4 instead of page 6. A saved Moonkin page still on the old default of 6 moves to 4 automatically; a page you set yourself is kept.

### Fixed
- The bar now switches in the Forever client, which builds its action buttons after addons load.
- Log Out and Exit Game in the Escape menu no longer fail with a "tried to call the protected function" error. The addon now changes the bar only on a real form change.

## [1.0.1] - 2026-10-13

### Changed
- Travel Form and Aquatic Form no longer switch the action bar by default; they are utility forms and now keep your normal bar. Opt back in with `/fpage travel <page>` or `/fpage aquatic <page>`.
- Existing settings still on the old 1.0.0 defaults (Travel 4, Aquatic 5) are cleared automatically; custom pages you chose are kept.

## [1.0.0] - 2026-10-13

### Added
- Automatic main action bar paging for druid forms: Bear/Dire Bear (page 2), Cat (3), Travel (4), Aquatic (5), Moonkin (6), Tree of Life (6).
- Returns to normal paging in caster form.
- Works in combat via a secure state driver.
- Form detection by spell ID, spell name, or icon for compatibility with the Forever beta.
- Slash commands `/fpage` and `/formpager` to view and change pages, disable switching per form, toggle the addon, and reset defaults.
- Settings saved between sessions.
- Stays idle on non-druid characters.
