# DruidActionBarPager

![DruidActionBarPager logo](logo.png)

**Docs:** [Features](FEATURES.md) · [Description](DESCRIPTION.md) · [Changelog](CHANGELOG.md)

**Author:** Malikor  
**Version:** 1.3.0<br>

Version 1.3.0 includes /dabp config, a compact native mapping panel with shared-page warnings, extra-bar selection and current paging ownership. Its buttons support Tab / Shift+Tab, Enter / Space and Escape. Find bars scans only when requested.

/dabp prowl <0-10> optionally assigns Cat + Prowl a different page. Zero inherits Cat. Other forms keep their existing zero = no-switch behavior. Vehicle and game override bars retain priority. Configuration made in combat applies when combat ends.

Compatibility evidence is versioned in the repository's docs/compatibility.md. Installed adapter versions remain unknown unless their metadata supplies them. New settings use schema 5, and a future schema is refused without rewriting its save.
**Game:** World of Warcraft — Forever 1.60.1 (interface 16001)  
**License:** GNU GPL v3

DruidActionBarPager automatically switches your main action bar whenever your druid changes form. You can also select up to three extra bars to mirror that same form page. Travel and Aquatic Form are utility forms, so they keep your normal bar, as does caster form.

It works in combat, has no dependencies, and works with Blizzard's bars or your action bar addon (see below).

## Default pages

| Form | Page |
|---|---|
| Caster (no form) | your normal page (usually 1) |
| Travel | your normal page (no switch) |
| Aquatic | your normal page (no switch) |
| Bear / Dire Bear | 2 |
| Cat | 3 |
| Moonkin | 4 |

Every page can be changed in game.

## Setting up your bars

1. Out of combat, press **Shift + 2** (or use the arrows beside the main bar) to go to page 2.
2. Drag your bear abilities onto that page.
3. Repeat for page 3 (cat) and page 4 (moonkin).
4. Press **Shift + 1** to go back to page 1.

From then on, shifting into a form flips the bar for you.

> **Note:** Pages 3 and 4 are the same pages Blizzard's Right Bar and Right Bar 2 display (while Bottom Right and Bottom Left use pages 5 and 6). If you have those bars turned on and don't want them sharing slots with a form, move forms to pages you don't use with the commands below (pages 7–10 are also valid).

## Action bar addons

DruidActionBarPager finds whichever main bar is actually on your screen and switches that one. Supported automatically:

| Bar | How DruidActionBarPager finds it |
|---|---|
| Blizzard default bar | ActionButton1–12 |
| EllesmereUI | EABButton1–12 |
| Bartender4 | BT4Button1–12 (bar 1) |
| ElvUI | ElvUI_Bar1Button1–12 (bar 1) |
| Dominos | DominosActionButton1–12 (bar 1) |
| Neuron | NeuronActionBar1_ActionButton1–12 (bar 1) |
| Any other bar addon (including LibActionButton-based bars such as AzeriteUI and ConsolePort, and bars with unnamed buttons) | Scans the screen for the visible buttons showing slots 1–12 and groups them by bar |

Bartender4, ElvUI and Neuron have their own stance/form paging. You don't need to turn it off: when they switch bar 1 for a form, DruidActionBarPager immediately puts your DruidActionBarPager page back. If you'd rather use their built-in paging, type `/dabp off`.

The main bar always pages automatically, and yields automatically whenever a vehicle, override, possess, temporary shapeshift, or skyriding bar is active. To page extra bars too (including Blizzard's optional bars on pages 3–6 and 13–15, or third-party extra bars up to slot 180), use `/dabp bars`, then select up to three with `/dabp bar <number> on`. Selected bars mirror the same form page; remove one with `/dabp bar <number> off`, remove a missing saved bar with `/dabp bar slot <1-3> off`, or clear all extra bars with `/dabp bar clear`. Selection saves between sessions; adding or removing a bar while shifted takes effect cleanly without leaving old bars stuck on a form page.

Set hotkeys in **Esc → Key Bindings → Druid Action Bar Pager**. The three individual bindings follow the order you selected bars; the all-bars binding toggles every selected extra. These hotkeys temporarily pause paging for extras only; the main bar keeps paging. Type `/dabp debug` to see attached bars.

## Commands

`/dabp` or `/druidactionbarpager`

| Command | What it does |
|---|---|
| `/dabp` | Show which page each form uses |
| `/dabp bear 2` | Set a form's page (forms: `bear`, `cat`, `travel`, `aquatic`, `moonkin`, `tree`) |
| `/dabp cat 0` | Don't switch pages for that form |
| `/dabp travel 4` | Opt a utility form into switching, if you want it |
| `/dabp on` / `/dabp off` | Enable or disable paging |
| `/dabp reset` | Review default pages before applying |
| `/dabp bars` | List additional action bars (with bar names and page/slot ranges) |
| `/dabp bar <n> on/off` | Select or remove a listed extra bar (up to three) |
| `/dabp bar slot <n> off` | Remove saved extra bar slot 1–3 (even if that bar's addon was removed) |
| `/dabp bar clear` | Remove all selected extra bars |
| `/dabp debug` | Show which bars DruidActionBarPager drives and what it's doing |
| `/dabp help` | List commands |

Changes made during combat are processed after combat ends. If a form page is active, the secure driver applies the change on its next update.

## Installation

1. Unzip the archive.
2. Copy the `DruidActionBarPager` folder into your `World of Warcraft\_<client>_\Interface\AddOns\` folder.
3. Restart the game (required on first install so `Bindings.xml` registers in Key Bindings; `/reload` is enough when updating).

## How it works

Blizzard doesn't let addons change the action bar from ordinary code during combat, which is exactly when druids shift the most. DruidActionBarPager hands the job to the game itself: it registers a secure state driver built from `[form:N]` macro conditions, and a small secure snippet repoints the 12 main bar buttons and any selected extra bars whenever your form changes.

Each button is switched the way its bar expects: Blizzard-style buttons get a page override, buttons that hold a fixed slot (EllesmereUI, Dominos and most others) are pointed at the slot on the new page, and LibActionButton buttons (Bartender4, ElvUI) get a private state for the form. For bars with their own paging, DruidActionBarPager hooks the bar so its page is reapplied whenever the bar changes itself.

Only finding the bar and rebuilding the driver (on login, or when you learn a new form) has to happen out of combat.

Forms are recognised by spell ID, then by spell name, then by icon, so it keeps working even if the beta renumbers spells.

## Troubleshooting

- **Nothing happens when I shift:** type `/dabp` and check that your forms are listed without "(not learned)". If a form shows as not learned even though you have it, please report it along with the form's name.
- **Icons look out of date after shifting:** clicking or using the keybind still casts the correct spell; report it so the visual refresh can be adjusted for this client.
- **After a `/reload` while shifted, the bar didn't flip:** the page is applied on the next form event after loading, which is usually right away. If it still shows the default page, shift out and back in, then type `/dabp debug`.
- **Prowl bar:** there is no separate prowl setting. Prowl is cast in Cat Form, so put Prowl on your cat page (the page set with `/dabp cat <page>`, default 3).
- **The wrong bar switches, or nothing visible changes:** type `/dabp debug`. The "main bar" line names the bar DruidActionBarPager is driving. If it isn't the one on your screen, report it with that output.
- **Extra bar missing:** type `/dabp bars` to rescan visible and hidden action bars, then select it. Use `/dabp debug` to confirm selected bars.
- **Changed bar addon or layout:** `/reload` so DruidActionBarPager finds the new main bar and extra bars.

## License

DruidActionBarPager is free software released under the GNU General Public License v3. See `LICENSE` for the full text.

## Reviewed Mapping Workflows

Open `/dabp config` and choose Preview, Profiles, Share, Undo, Reset or Support.
The workflow opens above Mapping. Tab and Shift+Tab move between buttons;
Enter or Space activates the focused button, and Escape closes the view.
Paste and report fields keep native text selection: use Ctrl+A and Ctrl+C.
Tab leaves the text field and focuses Review import. Cancel, X and Escape
leave the mapping unchanged.

- `/dabp preview cat 8` shows the twelve stored slots for page 8 before assignment.
  Page 0 means No switch; Prowl 0 inherits Cat. Unknown slots are distinct from empty slots.
- `/dabp undo` reviews the last mapping edit. `/dabp reset` reviews the default
  form pages. Apply confirms the change; extra bars, enabled state and window placement stay unchanged.
- `/dabp profiles` opens Tank, Cat, Balance and Healing setups for the current
  character. Each starts with the original mapping. Choose a profile and review
  it before applying. Bind current spec-group explicitly enables automatic
  switching for that readable group; missing client APIs leave manual profiles available.
- `/dabp share` copies only seven form page numbers. Paste a mapping there or use
  `/dabp import DABP1;bear=2;cat=3;travel=0;aquatic=0;moonkin=4;tree=4;prowl=0`
  to review it. Player identity, extra bar IDs, actions and profile bindings are excluded.
- `/dabp support` opens a bounded local technical report for manual copying.

Reviewed applies wait for you to leave combat and return to life. Existing
explicit page commands such as `/dabp cat 3` still update the desired mapping
immediately and defer protected paging until combat ends.
