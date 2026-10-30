# Shared Lua rules, types, errors and limits

API version 1. Use dots: `db.get("key")`, never `db:get("key")`. Arguments are
strictly typed; extra arguments and unknown option keys are errors unless the
signature explicitly allows varargs. Optional arguments mean omission/nil only
where documented. False, zero, empty string and absent nil are different values.
Methods are synchronous and do not yield. A successful call is committed before
the next call; a callback is **not** a transaction.

## Types

| Type | Meaning |
| --- | --- |
| Wire | Exactly `"red"` or `"green"`; mandatory for discovery/target paths |
| InputSelection | Explicit `"red"` or `"green"`; logic INPUT only, no default or combined selector |
| ID / name | Opaque case-sensitive string; never a coordinate, native object or label |
| Tick | Nonnegative exact integer, at most 9007199254740991 |
| Int32 | Exact integer -2147483648 through 2147483647 |
| SignalId | Logic: `{type=native_type?, name=prototype, quality=quality_name?}`; Configurator follows its independent field schema |
| Signal | `{signal=SignalId, count=Int32}` |
| Data | Finite boolean/number/string, dense 1-based Data array, or string-keyed Data map |

Logic signal names must exist on caller input. Missing type means `item`; missing
quality means `normal`. Native readback does not fill optional fields.
Ordinary signals reject wildcards. Only configurator schemas permit them in
specified roles. Complete signal identity is type/name/quality, not name alone.
Logic signals have no sorting guarantee; compare effective identities, not array
positions. Peripheral/device arrays sort by opaque name/ID, sections by native
index. Hash snapshots are maps, not ordered sequences.

Data excludes nil values, mixed/sparse arrays, cycles, functions, metatables,
threads and Factorio objects. An empty table is an empty map unless a schema
requires an array. Values are validated and defensively copied. Mutating a returned
snapshot never edits stored state. Persist peripheral names/colors, not wrappers.
IDs survive ordinary load but are not reused for replacement/cloned entities.

Logic's fresh native results and trusted notification signal graphs bypass generic
Data transport ceilings, without granting caller data that trust. Native arrays
support indexing, iteration and non-growing edits beyond ordinary table width.
Guest execution, arbitrary growth, string operations and explicit state/KV/Console
persistence retain their normal limits. Circuit notifications consume queue
entries and envelope bytes, not native signal payload bytes; queue bytes therefore
do not measure total circuit snapshot memory. Other event producers are unchanged.

The [modem](modem.md) accepts explicit top-level nil only as the required third
argument of `transmit`. Its event then omits `message`. This does not add nil to
persistent Data, arrays, maps, state or ordinary peripheral argument contracts.

`BaseEvent` fields are `name:string`, `tick:Tick` (dispatch time),
`sequence:integer` (global FIFO sequence), `computer_id:string`, `run_id:string`.
Events and payloads are copied. Observation/deadline times are separate fields.

## Errors

Ordinary API failures throw plain `{code, message, field?, peripheral?, device?}`.
`pcall(fn, ...)` returns `false, error` for these; check `type(error)=="table"`
before reading its code because ordinary Lua errors/assertions can be strings.
Do not parse message wording. Fatal quota/stop controls bypass `pcall`.

| Code | Meaning and recovery |
| --- | --- |
| E_ARGUMENT | Wrong arity/type, unknown key or malformed structure; fix the call |
| E_RANGE | Invalid numeric/domain/prototype/enum value |
| E_NOT_FOUND | Addressed identity/section is no longer available |
| E_UNREACHABLE | Bound path/color/force/surface is no longer valid |
| E_NETWORK_PENDING | Complete bounded topology proof is pending; retry later, never spin |
| E_UNPOWERED | Reachable target's active service needs electricity |
| E_UNSUPPORTED | Requested setting/mode is unavailable; inspect capabilities |
| E_READ_ONLY | Observation or current native section/mode is not writable |
| E_SHARED_SCOPE | Shared-group filter mutation exceeds target-local authority |
| E_WRONGTYPE | KV key has wrong live type; message contains WRONGTYPE |
| E_CAPACITY | Final content/storage/signal capacity would overflow |
| E_LIMIT | Request exceeds a per-operation complexity/size bound |
| E_BUSY | Bounded work/revision action cannot proceed now; review or retry later |
| E_ENGINE | Unexpected native adapter failure; current operation restores prior settings or retains explicit recovery fault |
| E_PROGRAM | Uncaught ordinary program error faults the run |
| E_BUDGET | Fatal active-callback/reconstruction/depth/allocation exhaustion, or candidate compilation refusal |

Argument/domain/capacity refusal does not mutate the rejected operation. Earlier
successful calls remain. Native rollback is target-local, not global: engine group
creation/third-party notifications are not undone. A failed restoration retains
recovery data and refuses later writes. Fix with backup and diagnosis, not deletion.
Candidate validation refusal preserves the old active run; active-run failure
faults it and clears its still-owned logic output.

## Scheduling and power

Each actual tick processes lifecycle/power and authority revocation, signal samples,
notifications/timers, fair callbacks, then display presentation/housekeeping. At
most one program callback or Console command per computer per tick runs, with FIFO
queues and a persisted rotation of ready computers. Empty queues leave that rotation;
an event or Console submission wakes its destination directly. The starting member
rotates even under shared-credit refusal, and a peer awakened during callback dispatch
joins a subsequent round. Future timers sleep in an indexed deadline queue rather
than causing per-tick computer searches. Due timers keep creation order, cancellation,
alignment and coalescing. A callback finishes or faults; it never suspends its Lua stack.
Circuit propagation remains native, not immediate recursive notification.

Monitor models change synchronously, but immutable presentation snapshots seal
after callback dispatch. Hidden preparation retains the old complete visible
image until whole-frame publication is admitted. The shared maintenance budget
is still 200000 units/tick: rendering has a 60000-unit baseline reservation and
can request up to 160000, with a baseline service opportunity between boosts.
Reservations and spent credits persist across same-tick entry/load. Topology
initialization is prepaid and resumable; these work units do not promise 60 UPS.
Selected [monitor groups](peripheral.md#synchronized-monitor-presentation) wait
for every member to participate; buffering cannot infer an application's
multi-callback frame boundary.

Queue overflow visibly faults the run and clears still-owned output. Outages
retain durable state/registrations/timers but discard transient touch/signal history;
restoration resyncs current inputs, not unseen history. Cold load does not replay
`start` or fabricate `power_restored`. Source replacement/Stop/removal/load cannot
renew spent same-tick credits. Timers use ticks; KV EXPIRE uses simulation seconds
at 60 ticks per second. Pausing stops ticks; wall-clock downtime is irrelevant.

Unpowered relays still participate in physical discovery. Descriptions and a
reachable peripheral's `getLimits()` work without power; other methods refuse.
KV data/deadlines and display models survive outages. See [lifecycle](../lifecycle.md).

## Effective safety ceilings

The [generated limit table](limits.md) lists every common integer ceiling from
the implementation. `computer.getLimits()` returns the same effective common
keys defensively; peripheral `getLimits()` adds its own capacities. Read current
limits rather than assuming unlimited values. State byte accounting includes
keys/container metadata; it is not compressed save size or raw string length.
Per-callback allocations/work can refuse a combination of requests even when
individual sizes fit. Do not retry a maximum request in a same-callback loop.

These are provisional alpha safety ceilings, **not** measured real-time CPU,
client latency or simultaneous maximum-world guarantees. Oversized accepted data
is not silently truncated on load; unsupported representations remain recoverable.
No OS/filesystem, unrestricted Factorio API, HTTP, direct messaging, Redis server,
CraftOS or `term.redirect` compatibility layer is provided.
