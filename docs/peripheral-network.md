# Peripheral networks and authority

Target: Factorio 2.0.77, API version 1. This feature checkpoint implements the
complete discovery/facade surface. The device-specific monitor, KV, logic and
configurator workers install their own methods; this checkpoint alone provides
`getLimits` and does not claim those other capabilities are finished.

## Wiring and first use

Wire the computer's NETWORK endpoint to the database's NETWORK endpoint, then
the database's NETWORK endpoint to the monitor's NETWORK endpoint, all red.
Both devices are discoverable over red. Computers can relay discovery, but are
not programmable peripherals. The same setup can independently use green.

A red-to-green chain is not a path. Vanilla poles/machines, ghosts, another
force/surface, and INPUT, OUTPUT or TARGETS endpoints do not relay discovery.
Unknown external wires remain intact. Discovery ports do not generate signals,
read factory signals, or transport a computer messaging protocol. Normal native
continuity between wires on one connector remains intact.

Call `computer.getLimits()` to inspect graph limits. There are 256 physical nodes
(including the source) and 512 examined directed adjacency entries per complete
search. Each undirected wire may be examined at both ends; ignored external
edges consume the bound too, preventing a huge external wire list from bypassing
admission. No query returns an apparently complete prefix when a bound is hit.

## Exact Lua surface

All calls use dots; arity and wire types are checked, with no implicit wire or
`both` discovery mode. Arrays are copied, sorted by opaque name and unique.

| Call | Returns |
| --- | --- |
| `peripheral.getNames(wire)` | Complete `string[]`, possibly empty |
| `peripheral.isPresent(name, wire)` | Boolean current physical presence |
| `peripheral.getType(name, wire)` | Type string, or one nil if absent |
| `peripheral.getMethods(name, wire)` | Sorted method/alias array, or one nil |
| `peripheral.describe(name, wire)` | Copied metadata, or one nil |
| `peripheral.wrap(name, wire)` | Protected ephemeral dot-call facade, or one nil |
| `peripheral.call(name, wire, method, ...)` | Exact method returns |
| `peripheral.find(type_name, wire)` | Zero or more facades, sorted by name |
| `peripheral.getName(facade)` | Already-bound opaque name |
| `peripheral.getWire(facade)` | Already-bound `red` or `green` |

Types are `kv_database`, `monitor`, `logic_handler`, `configurator`. An unknown
string type has zero matches, not a fabricated facade. `find` is multiple returns,
not an array; `{peripheral.find("monitor", "red")}` collects them. More than 128
matches produces `E_LIMIT` before creating a partial tuple; enumerate names and
wrap individual devices instead.

Metadata is `{name, type, label?, powered, position={x,y}, surface={index,name},
quality, direction, footprint={width,height}, wire}`. Position is the actual
native body position, not the originally requested coordinates. Direction is
`north`, `east`, `south` or `west`; footprint is axis-aligned world geometry.
Monitor bindings replace the position/footprint with logical group geometry.
Neither descriptions nor methods contain native entities/connectors.

Use `device.getLimits()` with no arguments even while its reachable endpoint is
unpowered. Other device methods require power. Metadata also remains available
while unpowered, and unpowered devices still relay physical discovery.

A wrapper binds an opaque identity, generation, discovery channel and current
computer run, never a mutable coordinate/label. Captured methods recheck live
physical edges on every invocation. `getName`/`getWire` accept genuine facades
from this callback only and remain useful after target detach; they do not look
up or grant stale target authority. Facades and their methods are not durable
Data and cannot be written into computer state. Save the name and colour, then
wrap again in the next callback. Replacement placement gets a different name.

Shared devices use synchronized dispatch order, not an exclusive claim. There
is no callback-wide transaction: successful prior effects survive a later error.

## Errors and notifications

`E_ARGUMENT`: malformed/extra arguments, wrong wire, fake facade, unknown method.
`E_LIMIT`: graph/result bound exceeded. `E_NETWORK_PENDING`: proof/reconciliation
is incomplete. A captured detached method throws `E_UNREACHABLE`, while fresh
presence/type/describe/wrap queries return false/nil only after a complete search.
Active methods on unpowered devices throw `E_UNPOWERED`. Ordinary errors are
catchable; fatal callback-budget exhaustion still faults the run. Do not busy-wait.

Register `computer.on("peripheral_attach", "attached")` and/or
`computer.on("peripheral_detach", "detached")`. Registration is not an inventory
snapshot; call `getNames` for the initial state. Events extend the computer event
envelope with `peripheral`, `peripheral_type`, `wire`, and a detach `reason`:
`wire_removed`, `removed`, `regrouped`, `force_changed`, `surface_changed`, `limit`
or `unavailable`. Simultaneous detachments precede attachments, each in sorted
name order. A power outage alone is not a physical detach.

The host retains plain per-run/channel inventories and bounded pending event
jobs; deferral preserves the exact next transition. Three channel inventories
are attempted per tick with a persisted rotating cursor. The 60-tick topology
ceiling is development tuning, not a measured maximum-world release guarantee;
maintenance pressure is explicitly `E_NETWORK_PENDING`, never silent success.
Queries and calls do not use this notification cache as authority. Every call
performs a new complete bounded physical search. Logic output uses a cheaper
revalidated physical witness, then a bounded alternate search; failure or proof
credit deferral clears it fail-closed on the next safety pass. Stop/fault/power
cleanup also independently clears only the exact current writer generation.

Logical monitor grouping can map multiple reachable tiles to one identity, but
never adds graph edges between them. Different cables touching different members
can share display contents without gaining access to each other's peripherals.

## End-to-end native program

[Source text](../examples/peripheral-program.lua) contains a complete document
inside its `[[...]]` string. Copy that document into the single-document editor,
Save, Validate, then Run/Apply. It registers transition handlers, inspects both
colours independently, logs copied type/name metadata, calls each facade's
`getLimits`, and retains names as Data rather than wrappers. It is executed by
the packaged native fixture; real client editor entry remains user-deferred.

The in-game help keys are `tc-help.peripheral-network`, `peripheral-calls`,
`peripheral-errors`, and `peripheral-events`, for the editor/help UI to display.

## Host integration contract

Import `scripts.services.peripheral` during control parsing, as control.lua does.
Do not add another on_tick handler. The service installs one provider and two
hooks on the existing scheduler; only plain observations/jobs enter storage.

`register_type(kind, binding)` is a closed four-family binding, not a plugin bus.
Kinds are `kv`, `monitor`, `logic`, `configurator`. `binding.methods` includes a
`getLimits` function and every public method/alias, max 128. Each fixed method is
called as `fn(computer, target, wire, tick, spend, ...)`; validate exact arity and
reserve native work before effects, return only plain Data/ordinary tuples.
The boundary already snapshots caller data, checks current run, identity,
channel, force/surface/path and target power, and snapshots method results.

Optional monitor-only `binding.resolve(member)` returns the current logical
anchor record, or nil for an unavailable member; `binding.describe(target, wire,
base_info)` supplies the group's public geometry. Logical records have an opaque
`id`, `generation`, `kind`, `body`, force/surface, direction and power fields.
Group resolution does not alter physical traversal; absorbed names stop resolving.

`inventory(computer, wire, spend)` returns `(plain_inventory, physical_parents)`.
Each inventory entry has `name, type, generation, member`. Those host-only return
values must be scalar-adjusted when passing to functions expecting one argument.
`authority(computer, name, wire, spend)` returns `(target, plain_physical_id_path)`
or one nil, after a complete live search. `scripts.network` exposes `wire`,
`same_scope`, `real_edges`, `discovery_vertex`, `discover`, `witness` and
`validate_witness`. Reuse the scope/real-edge primitives for configurator target
traversal, but do not reuse the discovery-role allowlist: target relay policy is
separate and must not jump between an entity's isolated connectors.

Logic writes use `output_owner={computer_id, run_id, wire, path?}` and a whole
`output_bank`. The optional path is a physical ID sequence from computer to logic
handler. The network safety hook revalidates it every tick, recovers an alternate
bounded path, or calls `lifecycle.clear_output`. It also clears malformed ownership
fail-closed. The registered source-independent cleanup hook clears exact
computer/run owners on retirement, preserving a newer writer's bank. Logic's own
subscription/sample cleanup must coordinate rather than replace these hooks.

`register_revocation(name, fn)` permits at most four fixed trusted cleanup hooks,
called `(computer, peripheral_name, wire, reason)` before notification publication.
Hooks must do bounded teardown (max current run's 64 subscriptions), not guest
execution or unbounded scans. Every hook runs even if another fails; an unexpected
hook error faults/stops the run. Detach retirement/queue overflow never undoes
revocation or successful prior effects. No guest registration API is exposed.

## Evidence boundaries

`tests.network_engine` uses real owned bodies/connectors and the shipped compiler,
facades and scheduler. Its tiny KV binding is a test boundary, not a database
implementation. The monitor grouping resolver is synthetic; the no-hidden-bridge
wires and stale-facade checks are real, not monitor rectangle/rendering acceptance.
The cold fixture executes the production shared scheduler once per actual tick.
No graphical/client/multiplayer-join checks or screenshots are claimed.
