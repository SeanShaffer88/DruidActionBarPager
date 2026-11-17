# DruidActionBarPager

![DruidActionBarPager logo](logo.png)

**Docs:** [Features](FEATURES.md) · [Description](DESCRIPTION.md) · [Changelog](CHANGELOG.md)

**Author:** Malikor  
**Version:** 1.1.2-patched.1 (local patch)  
**Game:** World of Warcraft — Forever 1.60.1 (interface 16001)  
**License:** GNU GPL v3

DruidActionBarPager automatically switches your main action bar to a different page whenever your druid changes form, so your Bear, Cat and Moonkin abilities show up on your bar the moment you shift. Travel and Aquatic Form are utility forms, so they keep your normal bar, as does caster form.

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

> **Note:** Pages 3 and 4 are the same pages the optional extra bars (Right Bar, Right Bar 2, Bottom Right and Bottom Left) display. If you have those bars turned on, they will show your form abilities too. Either turn those bars off, or move forms to pages you don't use with the commands below (pages 7–10 are also valid).

## Action bar addons

DruidActionBarPager finds whichever main bar is actually on your screen and switches that one. Supported automatically:

| Bar | How DruidActionBarPager finds it |
|---|---|
| Blizzard default bar | ActionButton1–12 |
| EllesmereUI | EABButton1–12 |
| Bartender4 | BT4Button1–12 (bar 1) |
| ElvUI | ElvUI_Bar1Button1–12 (bar 1) |
| Dominos | DominosActionButton1–12 (bar 1) |
| Other bar addons | Scans the screen for the visible buttons showing slots 1–12 |

Bartender4, ElvUI and Dominos have their own stance/form paging. You don't need to turn it off: when they switch bar 1 for a form, DruidActionBarPager immediately puts your DruidActionBarPager page back. If you'd rather use their built-in paging, type `/dabp off`.

DruidActionBarPager only switches the bar that shows page 1 (your main bar). Type `/dabp debug` to see which bar it's driving.

## Commands

`/dabp` or `/druidactionbarpager`

| Command | What it does |
|---|---|
| `/dabp` | Show which page each form uses |
| `/dabp bear 2` | Set a form's page (forms: `bear`, `cat`, `travel`, `aquatic`, `moonkin`, `tree`) |
| `/dabp cat 0` | Don't switch pages for that form |
| `/dabp travel 4` | Opt a utility form into switching, if you want it |
| `/dabp on` / `/dabp off` | Enable or disable paging |
| `/dabp reset` | Restore the default pages |
| `/dabp debug` | Show which bar DruidActionBarPager drives and what it's doing |
| `/dabp help` | List commands |

Changes made during combat are processed after combat ends. If a form page is active, the secure driver applies the change on its next update.

## Installation

1. Unzip the archive.
2. Copy the `DruidActionBarPager` folder into your `World of Warcraft\_<client>_\Interface\AddOns\` folder.
3. Restart the game or type `/reload`.

## How it works

Blizzard doesn't let addons change the action bar from ordinary code during combat, which is exactly when druids shift the most. DruidActionBarPager hands the job to the game itself: it registers a secure state driver built from `[form:N]` macro conditions, and a small secure snippet repoints the 12 main bar buttons whenever your form changes.

Each button is switched the way its bar expects: Blizzard-style buttons get a page override, buttons that hold a fixed slot (EllesmereUI, Dominos and most others) are pointed at the slot on the new page, and LibActionButton buttons (Bartender4, ElvUI) get a private state for the form. For bars with their own paging, DruidActionBarPager hooks the bar so its page is reapplied whenever the bar changes itself.

Only finding the bar and rebuilding the driver (on login, or when you learn a new form) has to happen out of combat.

Forms are recognised by spell ID, then by spell name, then by icon, so it keeps working even if the beta renumbers spells.

## Troubleshooting

- **Nothing happens when I shift:** type `/dabp` and check that your forms are listed without "(not learned)". If a form shows as not learned even though you have it, please report it along with the form's name.
- **Icons look out of date after shifting:** clicking or using the keybind still casts the correct spell; report it so the visual refresh can be adjusted for this client.
- **After a `/reload` while shifted, the bar didn't flip:** the page is applied on the next form event after loading, which is usually right away. If it still shows the default page, shift out and back in, then type `/dabp debug`.
- **Prowl bar:** there is no separate prowl setting. Prowl is cast in Cat Form, so put Prowl on your cat page (the page set with `/dabp cat <page>`, default 3).
- **The wrong bar switches, or nothing visible changes:** type `/dabp debug`. The "main bar" line names the bar DruidActionBarPager is driving. If it isn't the one on your screen, report it with that output.
- **Changed bar addon or layout:** `/reload` so DruidActionBarPager finds the new main bar.

## License

DruidActionBarPager is free software released under the GNU General Public License v3. See `LICENSE` for the full text.
