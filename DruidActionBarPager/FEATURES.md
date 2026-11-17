# DruidActionBarPager — Features

The full feature list for DruidActionBarPager 1.1.2-patched.1 for WoW Forever
(Interface 16001, game version 1.60.1). For the short version see `README.md`;
for store-listing copy see `DESCRIPTION.md`.

DruidActionBarPager is by Malikor, released under the GNU GPL v3.

## Automatic form paging

- Automatically switches the main action bar to a different page for each
  druid combat form, the moment you shift.
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
- Stays idle on non-druid characters.

## Works in combat

- Paging works in combat, when druids shift the most.
- Uses a secure state driver built from `[form:N]` macro conditions: the
  game itself evaluates the conditions and a small secure snippet repoints
  the 12 main bar buttons whenever your form changes.
- Changes made during combat are processed after combat ends; if a form
  page is active, the secure driver applies the change on its next update.
- 1.1.2-patched.1: an active form page is restored or replaced through the
  secure state driver when settings change, form pages are reapplied only
  when the attached third-party bar changes its own page, and original
  button slots are preserved during rebuilds while a form page is active.

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
- Only the bar that shows page 1 (your main bar) is switched.
- Each button is switched the way its bar expects: page overrides for
  Blizzard-style buttons, slot repointing for fixed-slot buttons
  (EllesmereUI, Dominos and most others), and a private form state for
  LibActionButton buttons (Bartender4, ElvUI).
- The detected main bar is cached, so the full-screen scan for unknown bar
  addons only runs after a loading screen or a `/dabp` change.

## Form detection

- Forms are recognised by spell ID first, then by spell name
  (`C_Spell.GetSpellName`), then by icon — so detection keeps working even
  if spell numbers change.
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
| `/dabp debug` | Show which bar the addon drives and what it is doing |
| `/dabp help` | List commands |
