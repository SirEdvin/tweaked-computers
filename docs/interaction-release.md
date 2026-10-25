# Tweaked Computers 0.1.4 — ALPHA

Historical release notes: the current interaction no longer opens recovery on
empty ground. Use another computer's Maintenance for retained drafts; opening a
new computer with all eight slots occupied shows the capacity recovery viewer.
See the [current editor guide](player/editor.md#retained-drafts-and-mined-computers).

Wire-safe interaction hotfix for **Factorio 2.0.77**, base alone or optional Space
Age. Back up your save and old mod ZIP before updating. This remains an alpha;
native graphical-client and multiplayer acceptance is not claimed.

## Controls

With an empty cursor and no GUI open:

- **Ctrl + left-click a computer** to open its workspace.
- **Ctrl + left-click empty ground** to open retained recovery drafts.
- **Ctrl + left-click a monitor character cell** to activate it, without opening a
  workspace or recovery window. Position-based monitor hit testing is retained.

Ordinary left-click and the native Open GUI action no longer open mod workspaces.
The linked `open-gui` hook and old Ctrl+Shift+E shortcut are removed. All three
interactions share the new **Interact with computer / monitor / recovery drafts**
action in Controls, initially Ctrl + left-click. Previous custom bindings for the
old separate actions do not carry over; deliberately rebind the new action if
needed. Native buttons inside an already-open workspace still use normal clicks.

Holding red/green wire, an item or a cursor ghost refuses workspace/recovery
opening. Ordinary wire placement is no longer intercepted by the editor. The five
device shells and auxiliary sockets remain selectable and wireable but their
implementation-only native combinator dialogs stay unavailable; other mods' and
vanilla entity dialogs are not changed. Other device families do not gain new UIs.

A shared world-interaction router checks the exact input identity, GUI context,
cursor and custom-input permissions. Computer opening still applies existing
force/surface/reach checks and draft authority. No saved format, public guest Lua
API, program execution policy or device data is changed, and updating does not
automatically reset state, save drafts or restart a program.

## Related regression fix

The authentic monitor provider uses logical display identities rather than
physical tile registry IDs. The Peripherals panel now resolves discovered entries
through the same checked resolver as guest calls, so real monitor rows can be
listed and selected instead of incorrectly reporting a changed identity.

## Verification

The packaged workspace fixture uses actual native circuit shells and tests both
wire colors, connecting/disconnecting real engine connectors around ordinary-open
events, all five device families and owned sockets, vanilla-dialog preservation,
Ctrl-click-only opening, retained recovery, held-wire/ghost refusal, GUI-context
and permission/reach refusal. Prototype tests require the one exact Ctrl-click
binding and absence of every old open/monitor binding. Monitor tests exercise the
shared router and ensure position-based touches do not accidentally open recovery.

The release gate repeats workspace, editor cold-save, monitor cold-save, runtime
and production factory cold-integration suites on the final ZIP in both base and
Space Age. GUI/player objects are explicitly table-backed; native connectors,
world entities, runtime and save/reload processes are real. The regression first
fails against the previous ordinary-open implementation. CI runs these relevant
suites too. Checksums and complete focused logs accompany the release assets.

These tests are not proof of real mouse delivery, native layout/focus or
multiplayer behavior. After updating, use a backed-up test save to connect red and
green wires with ordinary clicks, then clear the cursor and Ctrl-click to open.
Keep the remaining [client playtest](player/editor.md#integrated-redesign-playtest)
limits explicit. Resource ceilings and newer-engine/mod combinations remain
unverified.

## Install

Update to **0.1.4** on the
[Factorio Mod Portal](https://mods.factorio.com/mod/tweaked-computers), or install
`tweaked-computers_0.1.4.zip` from the matching
[GitHub alpha release](https://github.com/SirEdvin/tweaked-computers/releases/tag/alpha-0.1.4).
Restart Factorio and load a backed-up save first. Do not use the automatic GitHub
source archive as a mod ZIP or leave conflicting duplicate versions installed.

See the [player guide](https://siredvin.github.io/tweaked-computers/) and immutable
[0.1.4 source](https://github.com/SirEdvin/tweaked-computers/tree/alpha-0.1.4).
The [0.1.3 GUI-style hotfix](gui-hotfix-release.md) and
[0.1.2 redesign](redesign-release.md) remain historical. Report errors in the
[issue tracker](https://github.com/SirEdvin/tweaked-computers/issues) with exact
engine/mod versions; redact private source literals and save data. Existing
project/parser/artwork licenses remain unchanged.
