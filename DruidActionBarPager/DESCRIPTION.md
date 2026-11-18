# DruidActionBarPager

**Automatic action bar paging for druid forms in WoW Forever — by Malikor.**

---

Shift into Bear and your bear abilities are already on your bar. Shift into
Cat, and your cat abilities are there instead. DruidActionBarPager switches
your main action bar to a different page for every druid form, automatically
— even in combat. Select up to three extra bars to mirror that page too.

## Why you'll like it

- **Your form abilities, the moment you shift.** Bear / Dire Bear goes to
  page 2, Cat to page 3, Moonkin (and Tree of Life) to page 4 by default.
  Caster form returns to your normal page. Travel and Aquatic are utility
  forms, so they keep your normal bar unless you opt them in.
- **Works in combat.** A secure state driver built from `[form:N]` macro
  conditions lets the game itself do the switching, so paging works exactly
  when druids shift the most — mid-fight.
- **Works with your bars.** Blizzard's default and optional bars, EllesmereUI,
  Bartender4, ElvUI, Dominos and Neuron are detected automatically, and any
  other bar addon (including LibActionButton-based bars and bars with unnamed
  buttons) is found by scanning for the visible main bar. Bar addons with their
  own form paging don't fight it: DruidActionBarPager reapplies its page
  immediately, while yielding cleanly to vehicle and override bars. Extra bars
  can be selected with `/dabp bars` (and cleared with `/dabp bar clear`);
  individual and all-extra hotkeys are available in Key Bindings.
- **Set it up your way.** Every form's page can be changed in game with
  `/dabp <form> <page>`, disabled per form with page `0`, or reset to the
  defaults with `/dabp reset`. Settings save between sessions.
- **No dependencies, nothing to configure to start.** Install it, put your
  bear abilities on page 2, cat on page 3 and moonkin on page 4, and shift.

## How to use it

1. Extract the `DruidActionBarPager` folder into
   `World of Warcraft\_classic_beta_\Interface\AddOns\` and restart the game
   (or `/reload` when updating).
2. Out of combat, press **Shift + 2** and drag your bear abilities onto
   page 2. Repeat for page 3 (cat) and page 4 (moonkin), then **Shift + 1**
   back to your normal bar.
3. Type `/dabp` to see which page each form uses. Use `/dabp bars` to select
   extra bars, and `/dabp debug` to see which bars the addon is driving.

Good to know: pages 3 and 4 match Blizzard's Right Bar and Right Bar 2 (and
pages 5 and 6 match Bottom Right and Bottom Left), so if you keep those bars
visible and separate, move forms to pages you don't use (pages 7–10 are valid
too). After a `/reload` while shifted, your form page reapplies on the next
form update automatically.

DruidActionBarPager is by Malikor, free software released under the GNU
General Public License v3, for WoW Forever 1.60.1 (Interface 16001).
