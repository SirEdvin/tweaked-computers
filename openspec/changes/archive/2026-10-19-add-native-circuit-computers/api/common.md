# Shared Lua API contract, version 1

This document is normative for the companion `specs/*/lua-api.md` contracts. It specifies a new Factorio API inspired by Computer Core and selected CC:Tweaked behavior, not either project's complete runtime. Code examples are contract examples, not evidence that an implementation exists.

## Calling convention and version

- Programs use implicit API version 1. Public namespaces are `computer`, `peripheral` and `colors` (`colours` is the same read-only color namespace).
- Namespaces and wrapped peripheral methods use dot calls: `db.get("key")`, not `db:get("key")`. A colon call adds an unexpected argument and is rejected.
- API methods are synchronous, non-yielding and non-reentrant. Method calls address current authoritative state. Every accepted mutation is ordered by the synchronized dispatcher; a callback is not a transaction.
- Extra arguments and unknown option fields are errors unless a signature explicitly has varargs. Optional means omission or nil where specified, never implicit truthiness or string/number coercion.
- Missing values are nil, not false, zero, empty strings or magic fake handles. Numeric/count APIs explicitly document their own zero/sentinel results.
- API ordinary failures throw a fresh plain `ApiError` table. `pcall` returns `false, error` for these. Fatal execution-budget and stop control signals bypass guest protection. The runtime does not expose the private representation of those signals.

## Shared types

```text
-- Documentation types, not executable declarations.
Wire = "red" | "green"                  -- mandatory discovery/target channel
InputSelection = "red" | "green" -- explicit, no default or combined selector
ComputerId, PeripheralName, DeviceId, SubscriptionId, TimerId = string
Tick = integer                           -- nonnegative, <= 9007199254740991
Int32 = integer                          -- -2147483648 .. 2147483647

SignalId = {
  type = "item" | "fluid" | "virtual" | "recipe", -- explicit on guest input/output
  name = string,                         -- exact registered prototype name
  quality = string                       -- optional input, defaults to "normal"
}
Signal = { signal = SignalId, count = Int32 }

ApiError = {
  code = string, message = string,
  field = string | nil, peripheral = string | nil, device = string | nil
}

BaseEvent = {
  name = string, tick = Tick, sequence = integer,
  computer_id = ComputerId, run_id = string
}
```

`Data` means a finite boolean/number/string, dense 1-based array of Data, or string-keyed map of Data. Arrays and maps cannot mix key kinds; cycles, metatables, functions, threads and LuaObjects are prohibited. No explicit nil element exists inside Data. Limits bound total bytes, nodes, nesting, key lengths and entries, not just one dimension. Persistent state stores nonnil Data; use the separate deletion method to remove a key. An empty table is an empty map unless a specific schema calls for an array.

Identifiers are opaque case-sensitive strings. They are stable across an ordinary save/load but are not reused for a newly placed/cloned entity. Numeric native IDs never become floating-point identity keys in guest code. Prototype names are exact identifiers, not localized labels. `normal` is the only assumed quality; other names must exist in the active prototype registry. Ordinary signal collections reject wildcard pseudo-signals; configurator condition/combinator schemas explicitly permit supported wildcards in their legal positions.

Collections returned by the API are defensive plain snapshots. Sorting is by complete `(type, name, quality)` for signals, opaque name for peripherals/devices, bytewise field name for hash snapshot construction, and native index for section arrays. No ordering relies on table addresses, CPU time, native hash order or player-local state.

## Errors

| Code | Meaning | Mutation policy |
| --- | --- | --- |
| `E_ARGUMENT` | Wrong type/arity, unknown option or malformed structure | None |
| `E_RANGE` | Numeric/domain/prototype/enum value invalid | None |
| `E_NOT_FOUND` | An addressed identity or section no longer exists | None |
| `E_UNREACHABLE` | No valid path on the selected channel or wrong force/surface | None |
| `E_NETWORK_PENDING` | A bounded topology result cannot yet be established | None; retry on a later event/tick |
| `E_UNPOWERED` | Target peripheral service is unavailable without electricity | None |
| `E_UNSUPPORTED` | Device/mode does not support the requested setting | None |
| `E_READ_ONLY` | Setting/section is not mutable in its current native mode | None |
| `E_SHARED_SCOPE` | Shared-group mutation would exceed target authority | None |
| `E_WRONGTYPE` | Redis command addresses the wrong existing key type; message contains WRONGTYPE | None |
| `E_CAPACITY` | Content/storage/signal/display capacity would be exceeded | None |
| `E_LIMIT` | Request exceeds a published per-operation size/complexity limit | None |
| `E_BUSY` | A bounded host operation cannot be admitted now | None; do not busy-wait |
| `E_ENGINE` | Unexpected native adapter failure | Roll back the current operation; if rollback fails, fault the adapter and report the retained recovery record explicitly |
| `E_PROGRAM` | Uncaught ordinary user-program error | Earlier successful calls remain committed; run faults |
| `E_BUDGET` | Fatal callback/reconstruction/allocation exhaustion, or candidate compilation refusal | Active-run exhaustion faults that run through host cleanup; candidate validation rejects only the candidate and preserves the previous active run |

Errors never convert a failed lookup into an empty successful result. Expected absences explicitly permitted by a method (for example GET of a missing key) are not errors. Clients may inspect `error.code` only after checking that the returned error is a table; ordinary Lua assertions can also produce strings. A guest must not rely on error wording. Capacity refusal does not delete already accepted data. Copy-on-read admission is included in operation bounds.

## Scheduling and lifecycle

1. At synchronized tick processing, reconcile bounded lifecycle/power changes and revoke stale authority. Fail-safe output cleanup has a reserved non-guest maintenance path.
2. Observe each powered logic handler's native input state once for that tick. Derive subscription events without recursive callback delivery.
3. Advance timers and topology/display notifications under separate maintenance budgets.
4. Dispatch ready computers in deterministic round-robin order using a persisted cursor; each computer consumes its FIFO event order. IDs and queue sequence break ties. A running callback finishes or faults; it never suspends mid-Lua-stack.
5. Complete bounded display presentation and housekeeping. Native circuit propagation determines when other factory entities observe output; no zero-latency feedback guarantee is made.

Within the published supported envelope, no changed logic sample is silently lost. Queue-capacity overflow faults the affected run visibly and clears its still-owned outputs. Unpowered computers do not admit transient touch/signal event history; on restoration they discard obsolete transient samples, retain durable application state/registrations, and request current-input resynchronization. Already completed effects never replay. Recurring overdue timers produce one event with a missed count instead of a burst; one-shots fire once. Ordinary cold load does not cause power-restoration or startup events merely because host functions were reconstructed.

Discovery remains physical while a relay device is unpowered; actual service calls on an unpowered endpoint fail. Display render state and database contents survive outages. KV expiry follows simulation time even while its entity is unpowered or in a data-bearing item.

## Queryable limits

`computer.getLimits()` returns a defensive table of effective integer ceilings. The release manifest records the same values. At least these keys are present:

```text
source_bytes, generated_source_bytes, source_nodes, source_nesting,
callback_work, callback_depth, callback_allocations, compile_work, host_work_per_tick,
active_computers, active_logic_handlers, aggregate_subscriptions, aggregate_owned_outputs,
state_bytes, state_entries, data_nodes, data_depth, string_bytes,
event_queue_entries, event_queue_bytes, timers, subscriptions,
network_nodes, network_edges, topology_latency_ticks,
peripheral_call_bytes, peripheral_call_entries,
console_entries, console_bytes, fail_safe_latency_ticks
```

Device-specific `getLimits()` adds monitor dimensions/cells/render latency, KV capacities, logic slots/subscriptions, or configurator traversal/configuration/section limits. Values are finite positive integers; allowed zeros are explicitly documented for optional capacities, not silently interpreted as unlimited. Prototype/signal availability is separate from size limits.

These are release-gated values, not falsely precise promises in this planning package. Implementation must derive and freeze a feasible envelope using the packaged engine and actual client workloads before accepting a release. Limits cannot be silently lowered below existing accepted content on load; retain such data readably and refuse growth until an explicit migration/policy is approved. Overflow metadata/item serialization must fit in addition to accepted payloads.

## Compatibility boundaries

- Computer Core: callback inspiration only; no legacy `os`, `disk`, `lan`, `wlan`, `speaker` or gauntlet compatibility layer.
- CC:Tweaked: monitor method names/aliases and terminal semantics are borrowed as a public behavior target; discovery uses explicit wire colors and named callback events rather than sided modems or `os.pullEvent`. No CraftOS, `term.redirect`, `parallel`, turtle or HTTP API.
- Redis: only the listed string/hash/key-expiry operations; local physical storage, no server/protocol or network client. Expiry uses simulation time, not Unix time. Hash readback is a Lua map. No field expiry, transactions, pub/sub or automatic coercion.
- Factorio: typed data facades only, not access to `game`, `script`, `remote`, `storage`, `settings`, `rendering`, `defines`, arbitrary LuaObjects or mod-host `require`.
