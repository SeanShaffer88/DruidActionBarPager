# DruidActionBarPager — Features

The full feature list for DruidActionBarPager 1.2.1 for WoW Forever
(Interface 16001, game version 1.60.1). For the short version see `README.md`;
for store-listing copy see `DESCRIPTION.md`.

DruidActionBarPager is by Malikor, released under the GNU GPL v3.

## Automatic form paging

- Automatically switches the main action bar to a different page for each
  druid combat form, the moment you shift. Up to three selected extra bars
  can mirror the same page.
- Default pages:

  | Form | Page |
  |---|---|
  | Caster (no form) | your normal page (usually 1) |
  | Travel | your normal page (no switch) |
  | Aquatic | your normal page (no switch) |
  | Bear / Dire Bear | 2 |
  | Cat | 3 |
  | Moonkin / Tree of Life | 4 |

- Every form's page can be changed in game, set to any valid page
  (including pages 7–10), or set to `0` to disable switching for that form.
- Utility forms (Travel, Aquatic) keep your normal bar by default and can be
  opted into switching with a command.
- Settings are saved between sessions (`DruidActionBarPagerDB`), and
  corrupted or hand-edited settings are repaired on load: invalid pages fall
  back to their defaults and unknown entries are removed.
- Stays idle on non-druid characters (including slash commands other than `/dabp help`).
- Automatically yields control when a vehicle, override, possess, temporary
  shapeshift, or skyriding bar is active, then resumes form paging once it ends.

## Works in combat

- Paging works in combat, when druids shift the most.
- Uses a secure state driver built from `[form:N]` macro conditions: the
  game itself evaluates the conditions and a small secure snippet repoints
  the 12 main bar buttons and selected extra bars whenever your form changes.
- Changes made during combat are processed after combat ends; if a form
  page is active, the secure driver applies the change on its next update.
- 1.1.2-patched.1: an active form page is restored or replaced through the
  secure state driver when settings change, form pages are reapplied only
  when the attached third-party bar changes its own page, and original
  button slots are preserved during rebuilds while a form page is active.
- 1.1.2-patched.2: the main bar is found for more bar addons (Neuron by name,
  and LibActionButton-based bars and bars with unnamed buttons by screen scan),
  paging is re-applied after any bar state change, the page holds on Blizzard's
  own bar, shapeshifting no longer triggers a rebuild, and the code is split
  into modules.

## Action bar addon support

Finds whichever main bar is actually on your screen and switches that one:

| Bar | How it is found |
|---|---|
| Blizzard default bar | ActionButton1–12 |
| EllesmereUI | EABButton1–12 |
| Bartender4 | BT4Button1–12 (bar 1) |
| ElvUI | ElvUI_Bar1Button1–12 (bar 1) |
| Dominos | DominosActionButton1–12 (bar 1) |
| Neuron | NeuronActionBar1_ActionButton1–12 (bar 1) |
| Any other bar addon (including LibActionButton-based bars such as AzeriteUI and ConsolePort, and bars with unnamed buttons) | Scans the screen for the visible buttons showing slots 1–12 and groups them by bar |

- No dependencies.
- Bartender4, ElvUI and Neuron have their own stance/form paging; it does
  not need to be turned off — when they switch bar 1 for a form,
  DruidActionBarPager immediately puts its own page back.
- The main bar always switches; up to three extra bars (across pages 1–15 /
  slots 1–180, including Blizzard optional bars `MultiBar*`) can be selected
  to mirror its active form page. `/dabp bars` lists visible and hidden player
  bars with parent bar names and page/slot ranges; `/dabp bar <number> on|off`
  selects them, `/dabp bar slot <n> off` removes an unavailable saved slot, and
  `/dabp bar clear` removes all saved extras.
- Each button is switched the way its bar expects: page overrides for
  Blizzard action and multi-bar buttons, slot repointing for fixed-slot buttons
  (EllesmereUI, Dominos and most others, including empty hidden buttons), and a
  private form state for LibActionButton buttons (Bartender4, ElvUI, and
  standalone LibActionButton bars).
- The detected main bar is cached, and the full-screen extra-bar scan is skipped
  entirely during rebuilds when no extra bars are selected. Per-bar and
  all-extra hotkeys are available under Key Bindings → Druid Action Bar Pager
  and respect `ActionButtonUseKeyDown`.

## Form detection

- Forms are recognised by spell ID first, then by whole-word spell name
  (`C_Spell.GetSpellName`), then by numeric icon `fileDataID` or texture path
  — so detection keeps working across locales even if spell numbers change.
- Spell data that is not loaded yet is requested, and forms are rechecked
  once it arrives.
- Bursts of spell and form events trigger one rebuild instead of many.

## Commands

`/dabp` or `/druidactionbarpager`

| Command | What it does |
|---|---|
| `/dabp` | Show which page each form uses |
| `/dabp bear 2` | Set a form's page (forms: `bear`, `cat`, `travel`, `aquatic`, `moonkin`, `tree`) |
| `/dabp cat 0` | Don't switch pages for that form |
| `/dabp travel 4` | Opt a utility form into switching |
| `/dabp on` / `/dabp off` | Enable or disable paging |
| `/dabp reset` | Restore the default pages |
| `/dabp bars` | List additional action bars |
| `/dabp bar <n> on/off` | Select or remove a listed extra bar |
| `/dabp bar slot <n> off` | Remove saved extra bar slot 1–3 |
| `/dabp bar clear` | Remove all selected extra bars |
| `/dabp debug` | Show which bars the addon drives and what it is doing |
| `/dabp help` | List commands |
