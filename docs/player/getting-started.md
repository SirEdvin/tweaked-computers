# Installation, crafting and wiring

## Install safely

In a build containing the [Factoriopedia Interface](api/factoriopedia-interface.md), it shares Recipe Searcher
research: 10 steel plates, 5 advanced circuits, 2 processing units, 2 seconds per
1×1 device. No electricity is needed; connect its Network body to the computer's red or
green Network. Ordinary opening shows identity/status; queries are read-only guest
calls, not a catalogue GUI. No item/fluid input is needed.

1. Back up the save and its mod configuration. Keep that backup outside the active
   save slot; removal/destruction of a device is not a backup strategy.
2. In Factorio's Mods screen, find **Tweaked Computers** (`tweaked-computers`) on
   the Mod Portal, select **0.1.17 ALPHA**, enable it, and restart when prompted.
   This version targets Factorio 2.1.23. Stay on 0.1.14 for Factorio 2.0.77.
3. For manual installation, download `tweaked-computers_0.1.17.zip` from the
   [alpha release](https://github.com/SirEdvin/tweaked-computers/releases/tag/alpha-0.1.17)
   and place it in your Factorio
   user-data `mods` directory without unpacking it. Remove conflicting duplicate
   versions, enable the mod, and restart. The ZIP's internal folder must match its
   numeric version. GitHub's automatic source archives are not installable mod ZIPs.
   Record the exact engine/mod versions when reporting a bug.
4. Load a copy of the save first. Tested engine: **2.1.23**. Base alone works;
   Space Age is optional, not a required dependency. Expansion settings and quality
   names require their corresponding installed prototypes. This guide does not
   claim later Factorio engines or arbitrary mod combinations are verified.

**0.1.17 breaking computer-storage change:** computer items are plain hardware.
Ordinary pickup/replacement loses computer contents, and old programmed item
payloads are ignored without import or recovery. Placed computers, active programs,
private drafts and KV/monitor data are not reset. Back up the complete save and
matching mod archive first; restore both for rollback, not just the old mod.
Use [source-only copies or qualifying stopped undo](lifecycle.md#undo-and-redo)
when preserving a program or a removed computer's saved state.

0.1.17 also adds elapsed Console time, demand-driven monitor maintenance,
native-only Factoriopedia/Production Statistics and [Dashboards](dashboard.md).
Optional `factorio-charts >= 1.2.0` provides upstream line charts and duration bars;
without it, Dashboard labels/buttons work and accepted datasets remain retained.
Controlled 2.1.23 base/Space Age native-client and connected-peer checks supplement
packaged/cold/upgrade checks; they are not exhaustive mod-pack or GPU certification.
Keep the pre-upgrade save and matching mod ZIPs together for rollback. Do not
downgrade a newly saved world; synchronizing an old save can reselect its old mod.

The historical migration evidence summarized here is **headless-only** on 2.1.23. Keep the pre-conversion save, 2.0.77
engine and matching mod ZIP for rollback; do not downgrade a converted save.
The following graphical, audio and connected-client checks were performed on
**2.0.77**, not repeated on 2.1.23:
artwork and live charts have isolated software-rendered base/Space Age checks;
the Console has native workflow checks in both modes and real base two-client
late-join/cold-server checks. Recipe Searcher appearance and Ctrl-click transfer,
held-modifier and monitor-touch checks cover both native clients; connected recipe
query checks cover base. The new campaign adds native inspector/Reference and
independently recorded speaker audio checks, plus actual two-client fresh/cold
radar/speaker/inspector cases in both modes, not exhaustive multiplayer certification.
Read the [alpha warning](index.md#alpha-warning). Keep backups before upgrades;
unknown saved formats are retained for recovery, not automatically reset.
Version 0.1.5 adds automatic buffered monitors, all complete rectangles up to
6×6 and optional synchronized groups. Existing walls may merge without tile
changes: absorbed names detach and changed character dimensions clear contents.
Keep the pre-upgrade save and old mod ZIP for rollback; do not downgrade a new
presentation record in place. Broader client validation remains part of alpha review.
Version 0.1.6 adds [live Map budgets](api/limits.md#live-mod-settings), fivefold
defaults and [dirty-cell chart animation](monitor-animation.md). Higher budgets
can reduce UPS; the measured two-tick publication cadence is not a universal
30-FPS guarantee. Replace the old chart with the complete new example to use
its shared-phase, all-screen updates.
Version 0.1.7 adds the selected Foundry family, connected-subpixel curves and
monitor component reuse without increasing those budgets. It does not promise
60 UPS or smooth GPU-backed animation in arbitrary factories.
Version 0.1.8 adds the [live Console](console.md): one-line Lua with real factory
effects and shared save-backed scratch values. There is no command history and
user functions cannot be retained. Run/Apply, Stop or confirmed Reset Shell clear
scratch values; closing/reopening and save/load retain them. Keep a pre-upgrade
save and matching ZIP rather than downgrading a save containing shell state.

Version 0.1.9 adds Recipe Searcher, recipe circuit signals, monitor stacks of 50,
readable Console tabs and preserved native Ctrl-click behavior. Logic input and
discovery/binding require explicit `"red"` or `"green"`; update old `"both"`
subscriptions before running them. Invalid retained subscriptions fault before
callbacks and release their owned output without replay or silent translation.
The output is still one shared bank mirrored onto both colors. Shared work/Data
budgets are unchanged and can still refuse queries or independent subscriptions.

Version 0.1.10 adds [plain exported function programs](api/language.md) and keeps
the separate Console. Validate and Save do not
execute a new program; Run/Apply explicitly activates it. The new
[world-maintenance Map setting](api/limits.md#maintenance-and-shared-headroom)
defaults to 200000, inside the unchanged shared host budget. Raising it is not
a speed control or a guarantee that a busy factory will keep 60 UPS. Per-computer
fault diagnostics no longer overwrite each other's run/revision identity.
Keep the pre-upgrade save and matching 0.1.9 ZIP; do not downgrade a save after
adopting declaration-form source. This release does not add a new connected
multiplayer or hardware-performance certification.

Version 0.1.11 adds [read-only peripheral inspectors](inspectors.md),
[radar modems](api/modem.md), [vanilla speaker audio](api/speaker.md) and
[guarded Lua helpers](api/language.md#printing-raw-helpers-and-error-transformation).
Both native carriers retain their original GUI, circuits and mining result;
hidden radar radio links never grant discovery authority, and hearing sound never
grants speaker control. The optional interplanetary radar has separate Space Age research.

New built-ins reserve only top-level function declaration names, not ordinary
locals/parameters or nested scratch fields. An older colliding
active declaration faults at synchronized reconstruction while preserving exact
source/state; rename the declaration and explicitly Save/Run. An older colliding
Console root returns named `E_UNSUPPORTED` before effects and keeps its graph.
Confirmed **Reset Shell discards all scratch values**, not just the colliding name;
it does not erase saved source, application state or old logs. Inspect/copy needed
data from a pre-upgrade backup first. Do not use Maintenance Reset State as a
substitute. Keep the pre-upgrade save and matching 0.1.10 ZIP for rollback rather
than downgrading the upgraded save in place.

Version 0.1.12 shows inspector structure immediately, even when a data query is
waiting. Logic input colors and own output update independently; a failed refresh
keeps any previous complete view explicitly stale. Configurator unique counts
still require both target traversals and are never partial totals. Long UI
instructions now live in tooltips and Reference. Old open windows may close once
after upgrade; reopen them. Computer drafts, source, state and peripheral data
are retained. Keep a pre-upgrade save and matching 0.1.11 ZIP for rollback.

Version 0.1.13 removes catalogue-wide admission estimates from logic input reads
and Recipe Searcher product/category queries. Adding unrelated recipes, items or
qualities no longer makes a small input query unaffordable. Actual result limits,
validation, live ownership checks and shared work/Data budgets remain unchanged.
Back up the save and keep the matching 0.1.12 ZIP before upgrading.

Version 0.1.14 reads complete native circuit inventories in native order, without
mod-defined signal/filter/output-slot ceilings. Missing signal type means item;
missing quality means normal. Update programs that assume sorted arrays or explicit
default fields. Native output slot bounds, validation, authority, ownership and
ordinary guest/persistence budgets still apply. Existing subscriptions, queued
events and native output owners survive without restarting programs. Empty-ground
Ctrl-click is inert; recover retained drafts through a computer's Maintenance tab.
Keep the pre-upgrade save and matching 0.1.13 ZIP; do not downgrade the upgraded save.

## Research and craft

In 0.1.10's [Service Rack family](artwork.md), look for a green folded desk
for the computer, offset cartridges for the database, bracketed flat glass for
the monitor, a long ceramic-terminal rail for logic, an open caliper with a dial
for configuration, and a low scanner sled for Recipe Searcher. Item icons match
these bodies. Native circuit computers research shows the desk; Recipe Searcher
research shows the scanner. This is an artwork-only change: footprints, wire
targets, costs and unlocks below are unchanged. Historical 0.1.9 archives keep
their original artwork and remain immutable.

Research **Native circuit computers** (`tc-circuit-computers`) after
`circuit-network` and `advanced-circuit`. It costs 100 automation + logistic
science-pack pairs at 30 seconds each and unlocks the original five recipes. Existing
researched forces receive missing unlocks on a mod configuration change.
All recipes make one item in 2 seconds and use base materials even with Space Age.
These are initial balance values.

Version 0.1.9 includes separately researched **Recipe Searcher**
(`tc-recipe-searcher`). Its exact direct
prerequisites are `tc-circuit-computers` and `utility-science-pack`. It costs 200
units of one automation, one logistic and one utility pack each, at 60 seconds per
unit (no chemical or production packs in this technology). One device crafts in
2 seconds from 10 steel plates, 5 advanced circuits and 2 processing units. Its
1×1 body needs no electricity. Circuit Computers alone never unlocks
it, including when installing into an already-researched factory.

Fresh monitor items stack to 50. Native tags, labels and quality must match to
stack data-bearing items; unlike settings do not silently merge. Computer and KV
items remain stacks of one. Mining retains monitor settings/palette, not a
portable copy of the previous logical screen buffer.

| Device / recipe ID | Iron plate | Copper plate | Electronic circuit | Advanced circuit |
| --- | ---: | ---: | ---: | ---: |
| Computer `tc-computer` | 10 | 5 | 10 | 2 |
| KV database `tc-kv` | 8 | 0 | 5 | 2 |
| Monitor tile `tc-monitor` | 4 | 2 | 5 | 0 |
| Logic handler `tc-logic` | 6 | 0 | 8 | 0 |
| Configurator `tc-configurator` | 8 | 0 | 8 | 2 |

All nine custom families need no electricity or power helper. Electrical cycling
does not pause their programs, cancel accepted work, clear outputs or blank
monitors. KV expiry still follows simulation ticks. Native radar, programmable-
speaker and vanilla factory targets retain their own electricity requirements;
native radar/speaker active methods can still report `E_UNPOWERED`.

## Recognize the devices

The world sprites and inventory icons use the same industrial forms:

| Device | Look for |
| --- | --- |
| Computer | Green folded-steel desk with inset controls and a low display |
| KV database | Offset cartridge stack with exposed service handles |
| Monitor | Flat bracketed dark glass with unchanged bezel contacts |
| Logic handler | Long ceramic-terminal rail with Input / Network / Output sockets |
| Configurator | Open caliper and dial with a separate Factory targets socket |
| Recipe Searcher | Low scanner sled with a copper optical bridge |

The small Network diamond and Factory targets crosshair supplement the device
shape and socket position. Their colors do not restrict which wire color you use.
A stopped computer has a grey dash; running uses an alternating amber
beacon. Green means an available custom peripheral, amber slash means physically unavailable and a tiny
red cross means fault (monitors use compact bezel dots). These status cues are
not deconstruction markers and do not replace the native removal X. The body
keeps its identity in every state. Native appearance remains part of alpha review.

## Direct device wiring and role sockets

Connect red or green wire directly to the visible computer, database or monitor.
Its hover name identifies that device, not a separate NETWORK tile. The monitor's
wire contacts are on its bezel. Select the main body to rotate, mine or mark the
whole device; there is no separately placeable Network block.

Logic has separate named Input and Output sockets around its central Network
connection. Configurator has a separate Factory targets socket beside Network.
Those auxiliary sockets cannot be mined or operated independently. North-facing
roles run left to right; east rotates clockwise, south reverses and west rotates
counterclockwise. Rotation keeps existing native role wires.

With an empty cursor and no open GUI, hover the main body and use your game's
Rotate / Reverse rotate controls (normally R / Shift+R). These follow the game's
bindings; they do not open a workspace. Square bodies turn a quarter-turn;
rectangular combinator bodies use the engine's half-turn behavior. Choose a
perpendicular orientation while placing the item. A held wire, item, ghost or
an auxiliary socket is not an empty-cursor body rotation. The engine may briefly
show “Not operable” after the forwarded rotation: the body has still turned,
but its native combinator configuration remains deliberately unavailable.

| Device footprint, north-facing | Connection layout |
| --- | --- |
| Computer, KV, monitor, Recipe Searcher: 1×1 | Network directly on device |
| Logic: 3×1 | Input / Network on device / Output |
| Configurator: 2×1 | Network on device / Factory targets |

Each role has separate red and green connectors. There are **no internal wires**
between roles. Cable color and role-marker color are unrelated.

- NETWORK: computer discovery through mod-owned NETWORK ports and the exact
  supported native radar/speaker sockets. Computers relay it but are not callable
  peripherals. Vanilla poles and other machines do not relay discovery; hidden
  radar radio links never grant it. Ports do not emit a computer-message signal protocol.
- INPUT: read native factory circuit signals through a logic handler.
- OUTPUT: the logic handler's one programmed bank contributes equally to red and
  green. External contributions on each color can still differ.
- TARGETS: the configurator reaches factory circuit-control settings. Vanilla
  same-color wire relays work here, but isolated native combinator connectors do
  not bridge each other.

Use one uninterrupted color for each path. A red wire into a relay and green wire
out is not discovery. The same device can separately appear on both colors;
shared database/display contents do not bridge wires. Force and surface must match.
For a merged monitor, connect a NETWORK wire to any member, but shared display
geometry does not make unwired members relay each other's networks.

Next: [your first controller](first-controller.md). If a device is missing, use
[Peripherals and troubleshooting](troubleshooting.md).
