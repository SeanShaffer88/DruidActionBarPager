# Compatibility matrix, revision 1

Target is WoW Forever, Interface 16001. This matrix describes adapter contracts. An installed addon's version is displayed only when its own metadata supplies it. A named adapter identifies button conventions, not a field-tested version range.

| Adapter | Ownership mechanism | Offline evidence | Observed client evidence |
|---|---|---|---|
| Blizzard | actionpage override on ID-bearing buttons | tests/families.lua blizzard; edge_cases.lua multibars, override_and_wrap | No exact-build observation supplied for these new capabilities |
| Bartender4 | private LibActionButton state, restoring native state | families.lua bartender4; standalone LAB regression | Unknown version/build |
| EllesmereUI | named EAB buttons and fixed action slots | families.lua ellesmere; late-bar handoff | Unknown version/build |
| Dominos | action-base and fixed slots; UpdateShown | families.lua dominos; showgrid_and_reload | Unknown version/build |
| ElvUI | named detection and shared LibActionButton contract | named detection in BarScan.lua; LAB fixtures above, without an ElvUI-specific family fixture | Unknown version/build |
| Neuron | named buttons and fixed action slots | families.lua neuron | Unknown version/build |
| Generic discovery, including Azerite/unnamed fixtures | owning frame, detected button modes and stable identity | families.lua azerite, unnamed; paused_extra_baseline | Unknown version/build |

The mapping panel and /dabp debug show who currently owns paging. Disabled, missing, pending-combat, game-override and paused-extra states remain distinct. Configured mirroring does not claim a page has already been applied. Sharing an action page is allowed and produces an informational warning.

## Prowl contract and source boundary

prowlPage = 0 inherits Cat. A positive page adds a [form:N,stealth] clause for the actual classified Cat index. Override, vehicle, possess, temporary shapeshift and bonus-bar guards precede it. The driver changes pages securely in combat without inspecting aura names.

The matching client UI snapshot is [Gethe/wow-ui-source bebcb6b](https://github.com/Gethe/wow-ui-source/tree/bebcb6bf309cf41b41bd74f8ca651e6a105b2676). Its [SecureStateDriver.lua](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/SecureStateDriver.lua) delegates macro conditions to native SecureCmdOptionParse and refreshes on UPDATE_STEALTH. The native parser implementation is outside the Lua snapshot. The addon probes the available parser's stealth expression before emitting the optional clause. Offline fixtures validate the Cat-plus-stealth conjunction, guard precedence and transitions. The user authorized progression assuming in-game checks pass; this record does not invent an executed client test or exact adapter version.

## Native panel

/dabp config opens the 600 × 640 native panel, clamped and scaled to the UI canvas. Tab and Shift+Tab move a highlight through its buttons, Enter or Space activates that control, and Escape closes it. Dragging saves its validated anchor and offsets. Reopening does not scan the frame tree. Find bars performs an explicit discovery pass; Next cycles candidates while retaining stable saved identities and avoiding duplicate extra selections. The panel has no idle update handler.

Keyboard capture is released during combat and remains disabled when the panel is opened in combat. Mouse configuration continues using deferred changes. Keyboard navigation resumes after combat only if the panel is still open. Propagation changes are made only out of combat.
