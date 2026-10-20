# Installation, crafting and wiring

## Install safely

1. Back up the save and its mod configuration. Keep that backup outside the active
   save slot; removal/destruction of a device is not a backup strategy.
2. In Factorio's Mods screen, find **Tweaked Computers** (`tweaked-computers`) on
   the Mod Portal, select **0.1.10 ALPHA**, enable it, and restart when prompted.
   This version includes function programs, the live maintenance setting and
   Service Rack artwork/research icons, retaining the direct wiring and editor.
3. For manual installation, download `tweaked-computers_0.1.10.zip` from the
   [alpha release](https://github.com/SirEdvin/tweaked-computers/releases/tag/alpha-0.1.10)
   and place it in your Factorio
   user-data `mods` directory without unpacking it. Remove conflicting duplicate
   versions, enable the mod, and restart. The ZIP's internal folder must match its
   numeric version. GitHub's automatic source archives are not installable mod ZIPs.
   Record the exact engine/mod versions when reporting a bug.
4. Load a copy of the save first. Tested engine: **2.0.77**. Base alone works;
   Space Age is optional, not a required dependency. Expansion settings and quality
   names require their corresponding installed prototypes. This guide does not
   claim later Factorio engines or arbitrary mod combinations are verified.

Artwork and live charts have isolated software-rendered base/Space Age checks;
the Console has native workflow checks in both modes and real base two-client
late-join/cold-server checks. Recipe Searcher appearance and Ctrl-click transfer,
held-modifier and monitor-touch checks cover both native clients; connected recipe
query checks cover base. Space Age connected joining, exhaustive native wire
selection and audible playback remain unverified.
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

Version 0.1.10 adds [plain exported function programs](api/language.md), while
keeping legacy descriptors and the separate Console. Validate and Save do not
execute a new program; Run/Apply explicitly activates it. The new
[world-maintenance Map setting](api/limits.md#maintenance-and-shared-headroom)
defaults to 200000, inside the unchanged shared host budget. Raising it is not
a speed control or a guarantee that a busy factory will keep 60 UPS. Per-computer
fault diagnostics no longer overwrite each other's run/revision identity.
Keep the pre-upgrade save and matching 0.1.9 ZIP; do not downgrade a save after
adopting declaration-form source. This release does not add a new connected
multiplayer or hardware-performance certification.

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
1×1 body consumes 30 kW with a 1 kJ buffer. Circuit Computers alone never unlocks
it, including when installing into an already-researched factory.

Fresh monitor items stack to 50. Native tags, labels and quality must match to
stack data-bearing items; unlike settings do not silently merge. Computer and KV
items remain stacks of one. Mining retains monitor settings/palette, not a
portable copy of the previous logical screen buffer.

| Device / recipe ID | Iron plate | Copper plate | Electronic circuit | Advanced circuit | Demand | Buffer |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Computer `tc-computer` | 10 | 5 | 10 | 2 | 60 kW | 2 kJ |
| KV database `tc-kv` | 8 | 0 | 5 | 2 | 30 kW | 1 kJ |
| Monitor tile `tc-monitor` | 4 | 2 | 5 | 0 | 15 kW | 500 J |
| Logic handler `tc-logic` | 6 | 0 | 8 | 0 | 15 kW | 500 J |
| Configurator `tc-configurator` | 8 | 0 | 8 | 2 | 30 kW | 1 kJ |

Supply electricity to every body; each needs at least one tick's demand in its
buffer to operate. Buffers provide only short brownout tolerance. Passive wire
paths remain during outages, but active peripheral calls fail `E_UNPOWERED`.
Computer callbacks pause; logic output clears; monitor presentation hides but its
image survives. KV expiry still follows simulation ticks.

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
A powered stopped computer has a grey dash; running uses an alternating amber
beacon. Green means a powered peripheral, amber slash means unpowered and a tiny
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

- NETWORK: computer discovery through mod-owned NETWORK ports only. Computers
  relay it but are not callable peripherals. Vanilla poles/machines do not relay
  discovery. Ports do not emit a computer-message signal protocol.
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
[Refresh Peripherals and troubleshooting](troubleshooting.md).
