# Tweaked Computers 0.1.3 — ALPHA

GUI compatibility hotfix for **Factorio 2.0.77**, base alone or optional Space Age.
Back up your save and previous mod ZIP before updating. This remains a user-test
alpha; graphical-client and multiplayer acceptance is not claimed.

## Fixed

Opening a computer in 0.1.2 could cause a non-recoverable engine error because the
workspace helper assigned `vertical_spacing` to a horizontal flow. Horizontal
rows now receive `horizontal_spacing`; vertical columns retain `vertical_spacing`.
The fix applies to the title bar, action rows, peripheral results, maintenance
confirmations and standalone draft recovery, not just the first failing row.

Public Lua API v1, saved formats, source/draft authority, running programs, device
wiring and factory behavior are unchanged. Save remains separate from Run/Apply.
No automatic draft deletion, state reset or program restart is introduced.

## Regression protection and audit scope

The runtime GUI construction and style accesses in `scripts/ui/editor.lua` were
audited against the pinned 2.0.77 runtime API and shipped core style definitions.
This is the mod's GUI construction module. The stricter table-backed GUI fixture
now rejects unsupported or unaudited style properties, cross-direction spacing,
text-only style settings on other widgets, write-only style getters, invalid
constructor fields/directions, incompatible named styles, duplicate child names
and child names that shadow any pinned LuaGuiElement attribute or method.
Negative tests exercise those guards, including the original failing assignment.
Prototype tests check named style types, parent styles and registered fonts,
including the font set dynamically on the title label.

Packaged workspace tests cover the selected-computer custom input and native-open
event handlers, all five tabs, dynamic peripheral rows, resolution/scale changes,
focus mode, conflicts, retained drafts and standalone recovery. Separate cold
processes check dirty/saved/active sources and retained state across save/reload.
CI now runs the workspace and cold editor suites in both base and Space Age, in
addition to the existing sandbox and production factory integration checks.

The release procedure exercises the final versioned archive, not source symlinks.
Checksums, complete engine logs and per-case summaries are retained outside git
and shipped with the matching release evidence. A mutation restoring the original
helper must fail the stricter workspace test before publication.

These checks prevent the audited mismatch class from silently passing the old
permissive mock. They do not prove that every possible GUI bug is absent. Native
layout, text entry, clipboard, focus, scrolling, world presentation and multiplayer
still need the [client playtest](player/editor.md#integrated-redesign-playtest).
Resource limits remain provisional; arbitrary mod combinations and newer engines
are unverified.

## Install

Update to **0.1.3** using the
[Factorio Mod Portal](https://mods.factorio.com/mod/tweaked-computers), or install
`tweaked-computers_0.1.3.zip` from the
[GitHub alpha release](https://github.com/SirEdvin/tweaked-computers/releases/tag/alpha-0.1.3).
Restart Factorio and load a backed-up copy of your save first. Do not install the
GitHub automatic source archive or multiple copies of this mod.

The [player guide](https://siredvin.github.io/tweaked-computers/) documents the
controls and Lua API. The immutable
[0.1.3 source](https://github.com/SirEdvin/tweaked-computers/tree/alpha-0.1.3) contains
the fix and tests. [0.1.2 redesign notes](redesign-release.md) remain historical.
Report engine/mod versions and the complete error in the
[issue tracker](https://github.com/SirEdvin/tweaked-computers/issues); remove private
source literals and save data. Project/parser/artwork licenses remain unchanged.
