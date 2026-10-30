# Peripheral discovery and calls

The computer sees physically reachable peripherals through uninterrupted red or
green wires directly between the devices’ **Network** connections on its force/surface. Computers
relay discovery but are not programmable peripherals. Supported native radar and vanilla programmable-speaker sockets
also relay local same-color wires. Vanilla poles/machines,
ghosts and INPUT/OUTPUT/TARGETS ports do not relay it. There is no cross-color path,
wireless discovery or coordinate addressing. [Radar modems](modem.md) exchange
bounded data without granting remote peripheral authority; native radar hidden
links are excluded from discovery and saved path witnesses.
The [speaker reference](speaker.md) covers native power, six synchronous methods,
bounded connected-frontier adoption and local audio. Native speaker GUI, circuit
settings and Configurator access remain available after registration.
Unknown external wires are left intact; normal continuity on one connector remains.

## Complete methods

Every discovery call requires an explicit wire, `"red"` or `"green"`; no default
or `"both"`. Names/types are strings, and calls use dots with strict arity.

| Signature | Exact returns |
| --- | --- |
| `peripheral.getNames(wire)` | Complete sorted unique string array, possibly empty |
| `peripheral.isPresent(name, wire)` | Boolean physical presence, independent of power |
| `peripheral.getType(name, wire)` | Type string or one nil if absent |
| `peripheral.getMethods(name, wire)` | Sorted public method/alias array or one nil |
| `peripheral.describe(name, wire)` | PeripheralInfo snapshot or one nil |
| `peripheral.wrap(name, wire)` | Ephemeral protected dot-call facade or one nil |
| `peripheral.call(name, wire, method, ...)` | Exact addressed method returns |
| `peripheral.find(type_name, wire)` | Zero or more facades in name order; **multiple returns**, not an array |
| `peripheral.getName(facade)` | Bound string name of genuine facade |
| `peripheral.getWire(facade)` | Bound `"red"` or `"green"` |
| `peripheral.setMonitorSyncGroup(members)` | No values; atomically replace this run's monitor presentation selection; `{}` clears |
| `peripheral.getMonitorSyncGroup()` | Exactly one defensive status table; does not drive rendering |

Types: `monitor`, `kv_database`, `logic_handler`, `configurator`,
[`recipe_searcher`](recipe-searcher.md), [`factoriopedia_interface`](factoriopedia-interface.md),
[`production_statistics`](production-statistics.md), [`dashboard`](dashboard.md),
[`modem`](modem.md), [`speaker`](speaker.md). Unknown string
types yield zero find matches. `local m = peripheral.find("monitor", "red")`
selects the first; `{peripheral.find("monitor", "red")}` collects all. More than
128 results fails before creating a partial tuple: enumerate names and wrap.

`PeripheralInfo` contains `name`, `type`, optional `label`, `powered:boolean`,
`position={x:number,y:number}`, `surface={index:integer,name:string}`,
`quality:string`, cardinal `direction`, `footprint={width:integer,height:integer}`,
and `wire`. Actual world coordinates are descriptive, not authority. A monitor's
position/footprint describe its logical rectangle's world extents, not terminal
character dimensions. No native entities/connectors/method objects are exposed.

All nine custom families need no electricity. `PeripheralInfo.powered` describes
their live physical availability, not an electrical buffer. For native radar and
speaker it retains native electrical/operational availability. Their reachable
metadata/`getLimits()` remain available while unpowered; other native methods
retain `E_UNPOWERED`. No description authorizes a later call.

## Wrappers and stale identities

A facade binds an opaque identity/generation, current run and selected color.
Every captured method rechecks current authority before work. It cannot be saved
as Data. Store name/color then wrap again in the next callback. Replacing a body
creates a new name even at identical coordinates/label. `getName` and `getWire`
can inspect the genuine callback-local binding after detach but grant no access.

A merged monitor is one logical peripheral through any reachable member, not a
hidden wire bridge between unwired members/colors. A KV reached on both colors
has one database; sharing content does not relay discovery.

## Synchronized monitor presentation

Pass a dense array of exact `{name=..., wire="red"/"green"}` records, not facades.
Up to eight supplied references are checked before deduplication; red wins when
both valid paths address the same logical screen. Canonical members sort by name.
The group supports four logical screens and 10,584 summed actual cells, with mixed
shapes/scales/orientations. Four 6×6 scale-1 screens fit; four at scale 0.5 do not.
Registration requires physically available monitors and current same-force/surface authority.
Wrong shape/key/arity is E_ARGUMENT; excessive refs E_LIMIT; nonmonitors
E_WRONGTYPE; missing paths or physical unavailability E_UNREACHABLE; capacity E_CAPACITY;
another run's selection E_BUSY. Every refusal preserves the prior selection.

Selection controls presentation, not write ownership: other authorized writers
still mutate shared models immediately. Every member needs a successful mutator
after registration/last seal, including an unchanged setter; getters do not count.
Then the post-dispatch boundary captures all current models and later publishes
them together. There is no timeout or flush API. A static member deliberately
holds the round. Re-registering identical canonical members is idempotent.

Status contains `members`, `status` (`none`, `waiting`, `preparing`, `blocked`),
`presented_sequence`, optional `presented_tick` and optional `{code,message}`
`diagnostic`. It reports presenter progress, not a fresh network proof. Blockage
takes priority over preparation, then waiting; only complete publication advances
the acknowledgement. Computer outage suspends ownership; Stop/fault/Apply/removal
or definitive selected-path revocation releases the entire selection without
clearing models/fronts. The host never silently switches its retained wire.
Geometry changes reset participation; over-capacity growth blocks the whole group
until it fits or is reconfigured, without rejecting an otherwise valid scale.

Try the [shared sine trace](../examples.md#monitor-plot-program). See the
[monitor reference](monitor.md) for snapshot, producer-clock and upgrade caveats.

## Events

`computer.on("peripheral_attach", "attached")` and
`computer.on("peripheral_detach", "detached")` register transitions, **not** an
initial snapshot. Query getNames for initial inventory. Both events add
`peripheral:string`, `peripheral_type:string`, `wire:Wire` to BaseEvent. Detach
adds `reason`: `wire_removed`, `removed`, `regrouped`, `force_changed`,
`surface_changed`, `limit` or `unavailable`.

Revocation/owned-output cleanup occurs before guest notification and does not need
a handler. Simultaneous detachments precede attachments, sorted by name; colors
remain independent. Power loss alone is not physical detach. Topology notifications
are bounded maintenance, not the source of call authority. A captured stale method
fails `E_UNREACHABLE`; fresh absent lookups return false/nil only after a **complete**
search. Pending/incomplete search fails `E_NETWORK_PENDING`/`E_LIMIT`, never a
successful empty prefix. Retry on a later tick, not in a busy loop.

A search reaches at most 256 physical nodes including source, examines at most
512 directed adjacency entries (ignored external edges count too), and cannot
return a partial inventory. Notification maintenance attempts three channel
inventories per tick fairly; the queried 60-tick topology ceiling is provisional,
not a guarantee under arbitrary world load. Shared calls use synchronized order,
not exclusive locks or callback-wide transactions.

## Use and troubleshooting

Run [peripheral-program](../examples.md#peripheral-program) with at least one
physically valid NETWORK-connected device; it inspects both colors and logs metadata. Use
the automatically updating Peripherals tab to compare the same paths. Check exact role/color/force/surface
before interpreting missing as empty. A monitor regroup can invalidate an old
name; re-enumerate, do not retarget by coordinates. For service-specific errors
see [shared errors](common.md#errors) and the selected device reference.
