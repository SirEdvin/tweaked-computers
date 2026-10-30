# Physical devices and initial progression (TC04)

Target: exactly Factorio 2.1.23, base alone or optional Space Age. This is an
integrated alpha candidate; native-client acceptance is separate from headless contracts. No VM,
interpreter, OS or gameplay filesystem is introduced.

## Placement and wiring

The visible device is now the native red/green Network endpoint, not an invisible
NETWORK tile layered over a separate body. Computer, KV, monitor and Recipe Searcher occupy 1×1;
logic occupies 3×1 and configurator 2×1. All nine custom families, including
Factoriopedia, Production Statistics and Dashboard, need no electricity or power
helper. Native radar and programmable-speaker retain their vanilla electricity.

For logic, Input / Network / Output run left to right when north-facing. Only
Input and Output need small device-specific auxiliary sockets. Configurator has
Network / Factory targets; only Factory targets is auxiliary. Every role accepts
both cable colors. East rotates clockwise, south reverses, west counterclockwise.
The body owns ordinary selection, rotation, mining and deconstruction; auxiliary
sockets expose only their named role, never a generic NETWORK identity.

All roles remain circuit-independent, with no internal wires. Network
shells, Input and Factory targets have zero combinator sections and are disabled
and inoperable. Output contributes its single controlled bank to both colors.
Opening a computer requires Ctrl + left-click with an empty cursor; ordinary
open and the old Ctrl+Shift+E route are disabled. Existing reach/force/surface/session
guards remain. Ctrl-click empty ground does nothing; a monitor cell still receives a
touch. Recover retained drafts through another computer's Maintenance, or the
capacity viewer when opening a ninth computer. No implementation-only native constant-combinator dialog is exposed.
Client selection/focus remains a
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

| Original device | Iron plates | Copper plates | Electronic circuits | Advanced circuits |
| --- | ---: | ---: | ---: | ---: |
| Computer | 10 | 5 | 10 | 2 |
| KV database | 8 | 0 | 5 | 2 |
| Monitor tile | 4 | 2 | 5 | 0 |
| Logic handler | 6 | 0 | 8 | 0 |
| Configurator | 8 | 0 | 8 | 2 |

`tc-circuit-computers` requires `circuit-network` and the pinned engine's
`advanced-circuit` technology. It costs 100 automation + logistic science pairs,
30 seconds each, and unlocks the original five recipes. A configuration change reapplies
unlocks for already-researched forces. Ordinary reload performs no such mutation.
Recipes explicitly disable automatic recycling and remain base-material recipes
with Space Age enabled. Future balance changes need review before release.

The Recipe Searcher is independently owned by `tc-recipe-searcher`
technology. Its exact prerequisites are `tc-circuit-computers` and
`utility-science-pack`; research is 200 red/green/utility sets at 60 seconds each.
One item takes 2 seconds, 10 steel plates, 5 advanced circuits and 2 processing
units. It needs no electricity, has one Network endpoint and no product inventory/fluid box.
Both prototype effects and additive configuration reconciliation consult the same
per-device `technology` metadata; Circuit Computers alone cannot grant it on upgrade.
See the [player API](player/api/recipe-searcher.md) and
[separate candidate evidence](recipe-searcher-validation.md).

Custom electrical cycling never pauses callbacks, discards queued work, clears
owned outputs or blanks a monitor. The legacy `power_restored` registration name
is accepted but produces no new events. Already accepted events remain historical
queue entries. On upgrade, only exactly owned old electrical helpers are retired;
their inert compatibility prototypes remain loadable for old saves/blueprints.

Live identity, exact role ownership, geometry, direction, force, surface and
selected wire authority still gate operations. Stop/fault/removal and invalid
authority retain their fail-safe cleanup; physical unavailability can hide a
monitor without erasing its model. Native radar/speaker electricity is checked
at use time, including real modem receiver eligibility, not by idle power polling.
`PeripheralInfo.powered` remains a boolean: physical availability for custom
devices and live native electrical/operational availability for native carriers.

Physical reconciliation uses existing maintenance admission. A computer cannot
dispatch on stale physical authority. Actual model/graph/rendering capacities remain development limits;
no release latency/maximum-world guarantee is asserted by these logical charges.

## Host integration: scripts.lifecycle

Import at control parsing time. This module registers lifecycle work;
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
  sections/bank when its non-power authority is lost. Downstream logic owns generation-specific
  writer retirement via `registry.register_cleanup`; use the same endpoint and
  coordinate native output configuration and `output_owner`/recovery metadata
  with this function; no reusable output mirror is retained.
- `reconcile`, `observe_monitor`, `unlocks`: admitted scheduler or
  synchronized initialization/configuration helpers, never on_load.

Physical records retain `physical_version=1`; new shells have `layout_version=2`.
The body is bound as `body`, while children contain only Input/Output or Factory
targets as applicable. `availability_version=1` identifies the power-free layout;
unknown representations remain inert for recovery. Do not index `children.network`
for new devices: use `endpoint(rec,role)` or `connector`. `available(rec)` validates
live ownership/scope/geometry; the old host `has_power` name aliases that check.
All active consumers revalidate these proofs, including monitor members.
The graph admits a body only when its exact connector is the layout-2 Network
endpoint. It never grants discovery merely because an entity is a body or shares
a native circuit-network ID.

`upgrade(rec)` and `upgrade_existing()` perform synchronized staged conversion
from the retained old named EEI prototypes. They snapshot every native role/color
wire (including unsupported and ghost connections), allocate distinct shells and
required role pads, copy current output sections and validate all connections before
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
No power helper is created by blueprints. Only clones of exactly owned obsolete
electrical helpers are removed; unrelated inert entities survive. Unmatched role
socket clones are handled without replacing the new owner's parts.

## Focused verification boundaries

See [rd1-verification.md](rd1-verification.md) for exact reproducible commands and
scope. `tests.redesign_engine` and `tests.redesign_data` exercise the installed
layout/points, all nine families in four cardinal directions without electricity, passive role signals,
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
