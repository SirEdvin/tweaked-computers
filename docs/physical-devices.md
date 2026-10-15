# Physical devices and initial progression (TC04)

Target: exactly Factorio 2.0.77, base alone or optional Space Age. This is a
integrated alpha candidate; graphical/client verification is deferred. No VM,
interpreter, OS or gameplay filesystem is introduced.

## Placement and wiring

The visible device is now the native red/green Network endpoint, not an invisible
NETWORK tile layered over a separate body. Computer, KV and monitor occupy 1×1;
logic occupies 3×1 and configurator 2×1. A hidden, nonselectable electric carrier
supplies each shell at the unchanged wattage. It has no collision, item, mining
result, blueprint entry, independent deconstruction or native GUI.

For logic, Input / Network / Output run left to right when north-facing. Only
Input and Output need small device-specific auxiliary sockets. Configurator has
Network / Factory targets; only Factory targets is auxiliary. Every role accepts
both cable colors. East rotates clockwise, south reverses, west counterclockwise.
The body owns ordinary selection, rotation, mining and deconstruction; auxiliary
sockets expose only their named role, never a generic NETWORK identity.

All roles remain electrically independent, with no internal wires. Network
shells, Input and Factory targets have zero combinator sections and are disabled
and inoperable. Output contributes its single controlled bank to both colors.
Opening a selected computer uses the existing linked normal-open custom input or
Ctrl+Shift+E, with the existing reach/force/surface/session guards; it does not
open the native constant-combinator dialog. Client selection/focus remains a
small user-owned review, not a headless claim.

Placement allocates all parts before publishing a logical identity. A failed
allocation destroys only its staged objects and refunds the consumed material
item. Rotation retains the same native endpoints and real wires. Mining produces
one item with the established computer/KV/monitor snapshot policy, and removes
all owned parts. See [device-lifecycle.md](device-lifecycle.md) for data and
blueprint rules. The old interim non-minable computer/KV guard is superseded by
that data-bearing lifecycle; unsupported/corrupt formats still remain guarded.

## Shared socket contract for artwork (RD2)

`scripts/device-definitions.lua` is the sole host metadata source:
`offset(kind,index,direction)` gives auxiliary role centers; `contact(kind,role,
color,direction)` gives wire studs relative to the body; `points(kind,role,pad)`
produces the installed cardinal prototype connection/shadow points. Coordinates
are tile units; north contact x is the role center ±0.07 (red/green). Contact y is
−0.1 except monitors, whose −0.48 lies in the unchanged two-pixel bezel, outside
cell content. `transform` rotates these offsets. `pad_box` is ±0.22 tile.

RD2 exports those coordinates in the pinned engine and consumes them in
`assets/industrial.py`; `assets/socket-layout.json` records the definition hash.
The original five-design family is installed in all four directions, icons,
shadows and status frames, with unchanged footprints and monitor cell geometry.
See [art authoring/provenance](../assets/README.md) and
[RD2 verification](rd2-verification.md). Device-specific native names/descriptions
are present; native graphical hover, wire/art alignment and ordinary-scale
usability still require the short user checklist. Contact sheets are generated
asset inspection, not native-client screenshots.

## Reviewable initial balance

All recipes make one item in 2 seconds; no expansion materials are required.
These figures are initial tuning, not a measured gameplay optimum.

| Device | Iron plates | Copper plates | Electronic circuits | Advanced circuits | Demand | Buffer |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Computer | 10 | 5 | 10 | 2 | 60 kW | 2 kJ |
| KV database | 8 | 0 | 5 | 2 | 30 kW | 1 kJ |
| Monitor tile | 4 | 2 | 5 | 0 | 15 kW | 500 J |
| Logic handler | 6 | 0 | 8 | 0 | 15 kW | 500 J |
| Configurator | 8 | 0 | 8 | 2 | 30 kW | 1 kJ |

`tc-circuit-computers` requires `circuit-network` and the pinned engine's
`advanced-circuit` technology. It costs 100 automation + logistic science pairs,
30 seconds each, and unlocks all five recipes. A configuration change reapplies
unlocks for already-researched forces. Ordinary reload performs no such mutation.
Recipes explicitly disable automatic recycling and remain base-material recipes
with Space Age enabled. Future balance changes need review before release.

The energy source consumes at secondary-input priority, produces nothing,
exports no energy and can refill at twice demand. A complete device has active
power only when its real buffer has at least one tick's demand. The two-tick
buffer is short brownout tolerance, not stored long-term service availability.
Electrical/integrity loss is checked in a prepaid critical lifecycle pass before
restoration notifications can defer. Computer callbacks pause, transient history
is discarded by the runtime, state/timers survive and restoration keeps the same
run, requests input resync and sends retained restoration subscriptions. Native
logic output is disabled/cleared on a peripheral outage. Passive connectors stay
present. Downstream KV/configurator methods must reject unavailable services;
monitor rendering must blank presentation without discarding its model.

Normal reconciliation/restoration uses a persistent fair cursor and the existing
maintenance budget. A computer cannot dispatch using an old positive power
observation. Actual model/graph/rendering capacities remain development limits;
no release latency/maximum-world guarantee is asserted by these logical charges.

## Host integration: scripts.lifecycle

Import at control parsing time. This module registers two lifecycle phase hooks;
do not replace the existing scheduler's on_tick handler. Production control.lua
registers player/robot/script build/revive, mined/death/script removal and native
player rotation events. These functions are host-only, not guest capabilities:

- `build(body) -> record? , diagnostic? , retained_recovery?`: complete staged
  construction through the actual registry. Duplicate build returns the same
  record. Caller owns rollback of an unregistered body on ordinary failure.
- `on_built(event)`: production handler; performs build, refund and body rollback.
- `remove(id,reason,destroy_body) -> boolean`: successful registry teardown then
  exact owned-child destruction. A stale ID never targets a replacement.
- `on_removed(event)` / `on_rotated(event)`: narrow production event handlers.
- `rotate(record,previous_direction) -> boolean , error?`: move the same owned
  endpoints; restore prior direction/positions on refusal. Failed restoration
  retains an inert recovery record rather than destroying player data.
- `connector(record_or_id,role,colour) -> LuaWireConnector?`: current native
  connector, or nil if ownership/geometry/force/surface is inconsistent. Colour
  is exactly red/green. It creates no connector, returns no synthetic graph and
  deliberately does NOT require power: discovery topology remains passive.
- `clear_output(record)`: disable and remove this physical logic endpoint's
  sections/bank on a peripheral outage. Downstream logic owns generation-specific
  writer retirement via `registry.register_cleanup`; use the same endpoint and
  coordinate its `output_bank`/`output_owner` metadata with this function.
- `power_losses`, `reconcile`, `sample_power`, `unlocks`: admitted scheduler or
  synchronized initialization/configuration helpers, never on_load.

Physical records retain `physical_version=1`; new shells have `layout_version=2`.
The body is bound as `body`, while children contain `power` plus Input/Output or
Factory targets as applicable. Do not index `children.network` for new devices:
use `endpoint(rec,role)` or `connector`. `power_entity(rec)` resolves the current
carrier; `has_power(rec)` validates its exact ownership/scope/location and buffer.
All service consumers use those seams, including monitor-member power checks.
The graph admits a body only when its exact connector is the layout-2 Network
endpoint. It never grants discovery merely because an entity is a body or shares
a native circuit-network ID.

`upgrade(rec)` and `upgrade_existing()` perform synchronized staged conversion
from the retained old named EEI prototypes. They snapshot every native role/color
wire (including unsupported and ghost connections), allocate distinct shell/power/
pads, copy current power/output sections and validate all connections before
`registry.replace_physical` publishes ownership. Only then are old components
retired. Logical record/state/database/model/run/generation/queue/timer aliases
remain intact; no guest activation occurs. Monitor anchor body references are
updated, stale editor sessions invalidated, and drafts retained. Refused conversion
keeps the old data and physical wires with a `migration_error` diagnostic. Repair
the cause and retry only in a synchronized host context or another configuration
change; there is no destructive automatic reset or on_load conversion.

Legacy prototype `placeable_by` still accepts the logical item so old blueprint
EEI ghosts can revive. New blueprints wire the shell directly and add only the
required auxiliary ghosts. Both new and old rotated/mirrored helper wires transfer
onto the already-owned endpoint; no generic helper is adopted into the new layout.
Private power never appears in blueprints. Area-cloned power duplicates and
unmatched socket clones are removed, without replacing the new owner's parts.

## Focused verification boundaries

See [rd1-verification.md](rd1-verification.md) for exact reproducible commands and
scope. `tests.redesign_engine` and `tests.redesign_data` exercise the installed
layout/points, twenty cardinal native shells, private drain, passive role signals,
mark/cancel state and allocation/wire rollback. `tests.network_engine` retains
its real graph, authority and compiled facade contracts. `tests.lifecycle_engine`
exercises snapshots, rotation, native clones/blueprints, destruction, force/surface
changes, actual construction-robot mining and cold reload using new shells.

`tools/rd1_upgrade.py` constructs an old save from pinned alpha source in an
isolated scratch checkout, injects only the opt-in fixture, then cold-loads the
unchanged candidate ZIP in a new process with a test-mod configuration change.
It preserves a copy of the old save and exercises running source/state/KV/deadlines/
monitor/output/wires/drafts plus old blueprints/tagged items, including both
preflight and staged-allocation conversion refusal. Fixtures have explicit
synthetic host-only fault injection, not a player-created corrupt-save claim.

Historical `tests/device_engine` describes the earlier TC04/interim checkpoint;
it is not the RD1 acceptance command. No graphical client, multiplayer-join,
performance or final artwork acceptance is claimed by these headless fixtures.
