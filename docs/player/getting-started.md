# Installation, crafting and wiring

## Install safely

1. Back up the save and its mod configuration. Keep that backup outside the active
   save slot; removal/destruction of a device is not a backup strategy.
2. In Factorio's Mods screen, find **Tweaked Computers** (`tweaked-computers`) on
   the Mod Portal, install the intended ALPHA version, enable it, and restart when
   prompted. The listing is published as the final alpha-delivery step; before it
   exists, use only an explicitly supplied candidate ZIP, not GitHub's source ZIP.
3. For manual installation, place `tweaked-computers_VERSION.zip` in your Factorio
   user-data `mods` directory without unpacking it. Remove conflicting duplicate
   versions, enable the mod, and restart. The ZIP's internal folder must match its
   numeric version. Record the exact engine/mod versions when reporting a bug.
4. Load a copy of the save first. Tested engine: **2.0.77**. Base alone works;
   Space Age is optional, not a required dependency. Expansion settings and quality
   names require their corresponding installed prototypes. This guide does not
   claim later Factorio engines or arbitrary mod combinations are verified.

The alpha has not been graphically/client or multiplayer-join verified by agents.
Read the [alpha warning](index.md#alpha-warning). Keep backups before upgrades;
unknown saved formats are retained for recovery, not automatically reset.

## Research and craft

Research **Native circuit computers** (`tc-circuit-computers`) after
`circuit-network` and `advanced-circuit`. It costs 100 automation + logistic
science-pack pairs at 30 seconds each and unlocks all five recipes. Existing
researched forces receive missing unlocks on a mod configuration change.
All recipes make one item in 2 seconds and use base materials even with Space Age.
These are initial balance values.

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

## Body versus role ports

Select the body to rotate/mine the whole device. The small selectable role ports
have priority over the body and cannot be mined or operated independently.
North-facing layouts run left to right; east rotates clockwise, south reverses,
west rotates counterclockwise. Rotation keeps existing native role wires.

| Body footprint, north-facing | Role order | Role marker |
| --- | --- | --- |
| Computer, KV, monitor: 1×1 | NETWORK | Cyan diamond |
| Logic: 3×1 | INPUT / NETWORK / OUTPUT | Amber I / cyan diamond / lime square |
| Configurator: 2×1 | NETWORK / TARGETS | Cyan diamond / violet T |

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
