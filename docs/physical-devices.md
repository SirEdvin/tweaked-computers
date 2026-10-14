# Physical devices and initial progression (TC04)

Target: exactly Factorio 2.0.77, base alone or optional Space Age. This is a
physical/runtime development checkpoint, not the integrated release. No VM,
interpreter, OS or gameplay filesystem is introduced.

## Placement and wiring

Every logical item places one electrically powered body and owned circuit
endpoints. Computers, KV databases and monitor tiles occupy 1×1. Logic handlers
occupy 3×1 (INPUT, NETWORK, OUTPUT); configurators occupy 2×1 (NETWORK, TARGETS).
The unrotated north-facing layout runs left to right. East rotates it clockwise,
south reverses it and west rotates it counterclockwise. All five bodies support
cardinal orientation. Body collision is inset 0.1 tile from its full selection
footprint. Small port selection boxes have greater priority than the body.

The coloured development icons are expressly temporary; role names/descriptions
on the native selectable endpoints distinguish ports independently of wire
colour. The final cleared Greg Flavored artwork is a separate integration input.
This checkpoint references native base-game icons; it ships no copied icon bytes.
Client alignment, clickability and native interaction remain user-deferred.

Each role has its own native red and green connectors. There are no internal
wires or shared native networks between roles. NETWORK, INPUT and TARGETS ports
have zero combinator sections, are disabled and cannot be opened/edited/pasted
through native player controls. Incoming wires on a single endpoint retain normal
native continuity. OUTPUT is a separate controlled constant combinator, able to
contribute one bank equally to red/green. TC04 checks that native capability;
the full typed logic/output ownership API belongs to the logic milestone.

Owned endpoints cannot be mined/deconstructed/blueprinted/upgraded or rotated
independently, yield no drops and have no collision. The body remains the logical
item. Placement stages all parts before publishing an identity. Failure destroys
only the exact staged objects and returns exactly one consumed player/robot item,
preserving its native metadata. Removal invokes the existing source-independent
cleanup hooks and destroys exact retained child references only after successful
registry removal. Failed teardown retains the whole recovery record. Rotation
moves existing endpoints without replacing identities or their real wires.

IMPORTANT interim data-loss guard: computer/KV bodies are currently non-minable,
with `mining_guard='awaiting-data-bearing-snapshots'`. Plain mining must not discard
committed source/state or future database contents. The later lifecycle/snapshot
milestone MUST replace this guard with bounded transactional data-bearing mining,
not simply remove it. This is not a reduced final lifecycle contract. Explicit
entity destruction still has the destruction policy. Logic/configurator basic
one-drop removal is implemented; complete robots/ghosts/clone/settings-copy and
snapshot lifecycle remains with its assigned downstream cards.

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

Physical records extend the parent registry schema with `physical_version=1`,
`direction`, copied `position`, `power_checked_tick`, optional `power_revision`,
`mining_guard`, and retained `physical_error` diagnostics. `kind` is exactly
computer/kv/monitor/logic/configurator. Children are keyed by input/network/output/
targets as applicable. Native binding/owner identity is still supplied by
`registry.by_entity`, not lookup by coordinates or network ID. Combine this
mapping with `connector.owner`, `wire_connector_id` and colour in the graph worker;
never promote INPUT/OUTPUT/TARGETS into discovery vertices. All LuaObjects remain
host-only. Guest descriptors must be copied, bounded plain values.

Body native EEI configuration GUI is disabled (`gui_mode='none'`) so it cannot
be used to edit production/demand. The editor worker must provide its intended
native custom interaction entry (or a guarded, intercepted native opening path),
not assume that this checkpoint contains an editor. Port native GUI is disabled
with `operable=false` and copy/paste prohibition.

## Focused verification boundaries

`tests/device_contract.lua` checks geometry/tuning definitions, not client views.
`tests/device_engine.lua` runs shipped host handlers/modules with actual native
bodies, connectors, circuit propagation, power, assemblers and registry in the
fixture mod's isolated storage. It is not a claimed player/robot client placement
or click test. The partial allocation failure uses an explicitly host-only surface
proxy; the first staged child, construction robot cargo and refund inventory are
real native objects. Production event registration is shipped, while mocked event
payloads do not prove native player/robot event delivery.

The batch checks all five cardinal footprints, rotated live-wire identity,
independent logic/configurator role networks, no internal signal leaks, mirrored
native output, one logical basic drop, exact replacement/removal, atomic allocation
rollback/refund, retained cleanup refusal, fresh/researched unlocks and actual
unmodified native crafting. A protected infinite-loop source faults beside a
healthy powered computer. A real disconnected electrical buffer measures one-tick
consumption; outage/pause/output-zero/restoration run on actual ticks. Participants
are quiesced before snapshot capture. Cold readback preserves body/port/run/source/
state/power/ledger identities without on_load mutation or startup replay.

The same harness separately reloads the snapshot normally, then changes only the
copied test mod version in a third base process to verify configuration-change
unlocks. `/quit` overwrites its input map: each resumed phase uses a copy so the
original frozen snapshot remains immutable. The production archive never changes.

    python3 tools/build.py --output /absolute/outside/artifacts
    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive /absolute/outside/artifacts/tweaked-computers_0.1.0.zip \
      --output /absolute/outside/new-smoke --fixture tests.device_engine \
      --cold --upgrade-fixture

No graphical client, screenshots, joining-peer matrix, fuzz/performance campaign,
publication or deployment belongs to this checkpoint. Final artwork, complete
peripheral services, snapshot lifecycle and integrated acceptance remain explicit
other milestones, not silently declared complete here.
