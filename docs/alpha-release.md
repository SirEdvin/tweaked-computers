# Tweaked Computers 0.1.0 — ALPHA

First public user-test alpha for **Factorio 2.0.77**, with base alone or optional
Space Age. Back up your save before installing or upgrading. This is not stable
or client-verified; keep a separate test save.

## What is included

- Native guarded Lua named callbacks, persistent copied state, events and timers.
- One-document in-game source editor with validation, Save, Run, Apply, Stop,
  Reset State, conflict handling and draft recovery.
- Same-colour circuit-wire discovery with live path/force/surface checks.
- Merging in-world monitors, terminal/palette/colour aliases, touch and resize events.
- Independent shared string/hash KV databases with expiry and data-bearing mining.
- Quality-aware logic inputs, subscriptions and generation-owned output cleanup.
- Typed configurator discovery, conditions, combinator parameters/sections and
  applicable base/Space Age settings with explicit recovery on engine failures.
- Owned composite devices, recipes/power, rotation, mining, blueprint, clone,
  force/surface and cold-load lifecycle policies.

There is no interpreter, OS, shell, filesystem, guest dynamic loading, arbitrary
Factorio-object access or direct computer messaging. This is not full CraftOS,
Computer Core or Redis compatibility.

## Install and learn

1. Install **Tweaked Computers (ALPHA)** from the
   [Mod Portal](https://mods.factorio.com/mod/tweaked-computers) for Factorio 2.0.77.
2. Open the [getting-started guide](https://siredvin.github.io/tweaked-computers/getting-started/).
3. Follow the first controller tutorial, then the combined factory example.
   Save alone does not activate a program; Run/Apply selects the saved revision.
4. Use the [complete public Lua reference](https://siredvin.github.io/tweaked-computers/api/common/)
   for signatures, errors, limits, wiring and lifecycle rules.

[Public source](https://github.com/SirEdvin/tweaked-computers/tree/alpha-0.1.0)
and [developer OpenWiki](https://github.com/SirEdvin/tweaked-computers/tree/alpha-0.1.0/openwiki)
are separate from the player guide. The consolidated feature PR remains open for
review; publication is not a merge or an OpenSpec archive.

## Evidence and limitations

The integrated implementation has real packaged Factorio 2.0.77 base/Space Age,
factory-effect, sandbox and separate-process save/reload evidence. GUI fixture
input is table-backed, not native-client input evidence. No graphical/client or
multiplayer-join verification has been performed by agents. Native typing/paste,
focus/buttons, wire selection, artwork/port alignment, zoom/readability, real touch,
audible playback and multiplayer remain user checks. Resource ceilings are
provisional safety limits, not real-time or simultaneous maximum-world guarantees.
Newer engine versions and third-party prototype combinations are unverified.

Report feedback in the [issue tracker](https://github.com/SirEdvin/tweaked-computers/issues)
with engine/mod versions, wiring, source and diagnostics; remove private literals
and save data before sharing. Stop using the affected test save if recovery looks
unsafe, and retain your backup.

Project source and selected Greg Flavored artwork retain MIT notices. The glyph
atlas is independently authored; no original CC:Tweaked font bytes are included.
Pinned Phobos parser sources retain their own MIT license, notices and hashes.
