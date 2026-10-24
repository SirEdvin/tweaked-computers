# Resource-policy API amendment

This is a proposed contract, not an implemented API. It supplements all capability deltas. Existing method names, dot-call conventions, authority checks, argument/result shapes and native domains remain unless explicitly amended here or in a device companion.

## Sequential calls, resumable execution

A caller continues after a service returns, as before, but the host may suspend its continuation across simulation ticks while preparing a result or waiting for work. No guest future, polling token or coroutine API is added. A service that has committed a side effect records completion before its caller can suspend; it must not replay that effect on reload. Invalid authority/native input still produces ordinary typed errors. `computer.getTick()` returns the actual current simulation tick at each invocation, not a captured tick from the first slice; the event's original dispatch/sample timestamps remain stable.

`pcall` and `xpcall` catch resource-capacity and depth errors. They do not catch scheduler suspension or Stop. If a resource error is not caught, only that invocation/command ends; accepted state, subscriptions, timers and output ownership survive. Ordinary uncaught program bugs retain documented fault/fail-safe behavior. Hard native exceptions are not disguised as scheduling pressure.

Compilation and reconstruction are bounded non-resumable passes, not guest invocations. A request may wait before starting, then completes or refuses recoverably without saving partial compiler execution. Refusal preserves source, the previous active run, committed shell values and any suspended handler frames. If reduced limits prevent reconstruction, status reports the applicable resource/setting without replaying or faulting the retained run; recovery requires a suitable allowance or an explicit user action, not an endless automatic retry. Running handlers still resume exactly across ticks, cold reload and joining peers.

## New runtime status

`computer.getResourceStatus()` returns exactly one defensive plain table in programs and Console. It reports the caller's computer; it is not a world-enumeration API. The UI reads the same host status independently of the busy guest lane.

```text
ResourceStatus = {
  policy_version = 2,
  state = "running" | "waiting" | "idle" | "resource_refused" | "stopped" | "faulted",
  wait = {resource: string, setting: string, resumable: boolean, since_tick: Tick}?,
  resources = { [resource_name]: {
    used: number, limit: number, unit: string,
    scope: string, setting: string, over_limit: boolean
  } },
  dropped_events = {
    total: nonnegative safe integer, saturated: boolean,
    last_tick: Tick?, last_kind: string?, last_reason: string?
  },
  last_refusal = ResourceError?
}
ResourceError = {
  code: "E_CAPACITY" | "E_LIMIT" | "E_BUDGET",
  message: string, resource: string, setting: string,
  used: number, requested: number, limit: number,
  recoverable: true, line: integer?, column: integer?
}
```

`E_CAPACITY` denotes aggregate retained storage/memory or pending-work capacity. `E_LIMIT` denotes a retained explicit KV/geometry or necessary depth bound. `E_BUDGET` denotes recoverable compilation-work refusal or a truly indivisible runtime operation that cannot fit one full configured slice; ordinary runtime slice exhaustion is internal suspension, never a guest error. Existing validation/native/authority codes retain meaning. Diagnostic metadata must not contain native objects, private continuations or untrusted rich text.

Loss counters belong to the physical computer, survive Stop/Run, Console reset and cold reload, and do not transfer through mining/clone/blueprints. At the engine's exact-integer maximum the count saturates with `saturated=true` rather than wrapping. This is a representation constraint, not a tunable event cap. No reset method is added. A warning is emitted at most once per configured interval, with cumulative diagnostics retained independently of logs. Each recipient-handler delivery is counted separately. A pending internal `start` invocation is lifecycle work, not a droppable queue event; activate it directly in its execution lane so overflow cannot create a never-started run.

## Effective limits

Every `getLimits()` returns `policy_version=2` plus a `resources` map whose entries contain `limit`, `unit`, `scope`, `setting`, and `behavior` (`defer`, `reject`, `drop_newest`, `evict`). Retain applicable real-domain/geometry metadata and configurable KV fields. Removed fields such as `signal_slots`, `recipe_search_results`, `network_nodes`, `table_entries`, fixed renderer cells and modem delivery counts are absent, not zero, infinity or fictional large values. Document this as a breaking introspection change; method result arrays themselves keep their old shape.

Event queues and Console history use accounted bytes, including entry metadata, without `event_queue_entries` or `console_entries` capacity fields. Usage may still report an entry count as information, never as a second ceiling. Compilation reports recoverable refusal for an over-budget pass; waiting to start does not promise incremental compiler progress.

A device's map references its applicable owner/shared settings, not invented per-device quotas. Cadences and presentation page sizes are explicitly marked tuning/retention parameters rather than total-inventory ceilings. Query metadata remains available for reachable unpowered peripherals as before. Status and Stop have reserved host service opportunity under pressure, but are still charged fairly and cannot grant guest authority or unlimited execution.

## Non-event backpressure

Console submissions, activation/compilation requests and host service jobs cannot be silently dropped as events. Retain accepted request source/order/status, and necessary progress for resumable services; compilation retains no tokenizer/parser/emitter cursor. Refuse visibly before acceptance if pending storage is full, and report a failed compilation to its requester without replay. Superseded read-only UI refreshes and pending display snapshots may coalesce to the newest complete state; this does not discard committed application data or forget an accepted write. Logs and executable caches are disposable and use configured eviction.

## Compatibility boundaries

Source grammar and API-v1 descriptor input remain accepted. Continuation/storage ABI and policy introspection are explicitly versioned independently. Retained executable state uses symbolic source/function/block references, never serialized Lua closures. A suspended wrapper is a checked symbolic binding and revalidates live authority before each effect. Program state and service Data still reject functions and native objects; continuation persistence is not permission to store arbitrary functions in user state.

The default monitor synchronization selection keeps existing calls. Additional named selections use optional `group_key` arguments as documented in the monitor companion. Existing wire-color, 16-color blit encoding, signal identity and native numeric domains remain API semantics; they are not capacity settings. Channel numbers expand to nonnegative safe integers because this mod's radio namespace has no native 16-bit engine domain.
