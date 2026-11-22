# Changelog

All notable changes to DruidActionBarPager are documented here.

## [Unreleased]

### Added
- Open `/dabp config` to see which page each form uses, choose extra bars, and review shared-page warnings. Move through its buttons with the keyboard and keep its position between sessions.
- Preview the twelve buttons on a page before assigning it to a form. Empty slots and slots the addon cannot read are shown separately.
- Review Undo or Reset before changing pages. Undo keeps up to ten mapping edits until you reload or change character or profile.
- Keep four separate Tank, Cat, Balance and Healing setups for each character. Choose them yourself, or explicitly link a setup to the current talent setup when your client supports automatic changes.
- Share only form page numbers, without extra bar IDs or player details. Review pasted pages before applying them.
- Copy a local troubleshooting report without character names or player IDs.
- Give Cat + Prowl its own page with `/dabp prowl <0-10>`. Zero keeps Cat's page, and the game's special bars keep priority.
- See which bar addons have been checked and when the installed version is unknown.

### Changed
- Existing page choices are kept when settings are upgraded. Saves from a newer addon are left untouched.
- Windows and Linux produce identical ZIPs. Published downloads are checked against the verified package.

## [1.2.1] - 2026-11-21

### Fixed
- Restore the normal page selected while an extra bar was paused, including standalone LibActionButton states. Saved extra-bar selections and pause state stay stable through repeated rebuilds and candidate reordering.

## [1.2.0] - 2026-11-18

### Added
- `/dabp bar clear` and `/dabp bar slot <1-3> off` commands to remove saved extra bars even when the addon that owned them is hidden or uninstalled, plus missing-bar indicators in `/dabp`, `/dabp bars`, and `/dabp debug`.
- Parent bar names and page/slot ranges in `/dabp bars` and `/dabp debug`, so same-prefix bars (such as Bartender4 and Dominos) are easy to tell apart.
- Locale-independent numeric icon `fileDataID` fallback for druid form detection, and `ActionButtonUseKeyDown` support for extra-bar toggle keybindings (including 3+ bound keys per action).

### Fixed
- Replace the inner helper in the `fp-apply` restricted snippet with a separate `fp-apply-bar` attribute invoked via `RunAttribute`, fixing WoW's `"The function keyword is not permitted"` restricted-closure error that blocked paging on shapeshift and hotkey press.
- Page selected Blizzard optional action bars (`MultiBar*`) via `actionpage` overrides instead of ignored `action` attributes, expand discovery to slots 1–180 (covering `MultiBar5`–`MultiBar7` and high-page third-party bars), and resolve `button.bar` ahead of Forever's unprotected per-button container frames.
- Preserve per-bar hotkey pause state and `candidate-applied` tracking across candidate reordering, keep selected bars inside the 10-bar discovery cap, and restore deselected, cleared, dropped, or replaced bars out of combat via `SecureHandlerExecute`.
- Yield action bars automatically during `[overridebar]`, `[vehicleui]`, `[possessbar]`, `[shapeshift]`, and `[bonusbar:5]` states, restrict `OnAttributeChanged` bar hooks to actual paging attributes (reapplying only the affected bar), and remove stale duplicate wrap snippets.
- Attach all 12 buttons of a visible known bar even when empty slots are hidden (`showgrid` off), and run `UpdateShown` on fixed-slot buttons that define it.
- Preserve caster base slots after `/reload` while shifted (reading `action-base` on Dominos, normalizing bonus-page main-bar slots, and detecting unlisted main bars already showing an active bonus page), and preserve non-`0` default button states on standalone `LibActionButton` bars.
- Filter Blizzard system bars (`OverrideActionBarButton`, `MultiCastActionButton`, `PossessButton`, `PetActionButton`, `StanceButton`, `ExtraActionButton`, `SpellFlyoutButton`) out of `/dabp bars`, and sort visible bars ahead of hidden bars.
- Re-detect late-loading third-party main bars that hide or supersede the initial main bar during the 2-second post-login check, skip full-UI frame scans on rebuild when no extra bars are selected, and avoid redundant startup/post-combat work.
- Disable mouse input on the invisible secure toggle buttons and move them off screen center, keep `/dabp` commands idle on non-druid characters and safe before `ADDON_LOADED`, use whole-word form-name matching, and clean up minor `SavedVariables` and debug-output edge cases.
- Stop repeating `header="DRUIDACTIONBARPAGER"` in `Bindings.xml` and group the four extra-bar hotkeys with `category="BINDING_HEADER_DRUIDACTIONBARPAGER"`, eliminating the duplicate binding-header `LUA_WARNING` on load and placing them under **Druid Action Bar Pager** in Key Bindings.

## [1.1.2-patched.4] - 2026-11-17

### Fixed
- Keep saved extra-bar selections stable when discovery order changes, and migrate older IDs when they identify one bar unambiguously.

## [1.1.2-patched.3] - 2026-11-17

### Added
- Select up to three extra action bars to mirror form paging, with per-bar and all-extra hotkeys.
- Release workflow builds an install-ready ZIP and SHA-256 checksum automatically.

### Fixed
- Avoid a needless rebuild on the first shapeshift after login, and skip the delayed full-screen rescan when a bar was already found.

## [1.1.2-patched.2] - 2026-11-17

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
