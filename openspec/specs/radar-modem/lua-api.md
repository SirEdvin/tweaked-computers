# Radar modem Lua API v1

Normative companion to [spec.md](spec.md). The [shared types, errors and dot-call convention](../../api/common.md) and [named-handler runtime](../computer-runtime/lua-api.md) continue to apply. Acceptance receipts distinguish actual packaged execution, native appearance and connected-client delivery from illustrative examples.

## Discovery and tiers

Use `peripheral.find("modem", "red")`, `peripheral.wrap(name, wire)` or checked `peripheral.call` with the existing mandatory wire argument. `wire` is a local physical discovery color, not a radio frequency. Both radar tiers have public type `modem`; `peripheral.describe` additionally returns `modem_tier = "surface" | "interplanetary"` and the actual footprint. Other metadata retains existing meanings, with radar availability also requiring the native entity to be active.

Only vanilla prototype `radar` and, when Space Age is active, `tc-interplanetary-radar` participate. No automatic support is promised for third-party radar prototypes. No method enumerates remote computers, wraps remote peripherals or returns Factorio objects.

Enrollment originates only at a placed computer, through a complete same-color, same-force, same-surface physical path. Direct cables and supported transitive network connectors qualify, including previously unenrolled native radar/speaker relays. Factory-only sockets, unsupported vanilla relays, ghosts, merged-monitor adjacency and hidden radio links do not. Placement, cloning, revival or wiring to a standalone peripheral does not enroll a radar. Stopped, faulted and unpowered computers remain physical roots; execution and powered methods retain their separate checks. Incomplete or refused adoption retains `E_NETWORK_PENDING`, `E_LIMIT` and `E_CAPACITY`, never a successful partial inventory.

## Methods

| Exact signature | Returns | Behavior |
| --- | --- | --- |
| `open(channel)` | zero values | Add a channel to this physical radar's shared set; reopening is a no-op. |
| `isOpen(channel)` | boolean | Read that shared set. |
| `close(channel)` | zero values | Remove the channel if present; closing an absent channel is a no-op. |
| `closeAll()` | zero values | Clear all channels on this radar, including those opened by another authorized computer. |
| `transmit(channel, replyChannel, payload)` | zero values | Broadcast a defensively copied payload; neither channel needs to be open locally. There is no delivery count or acknowledgement. |
| `isWireless()` | boolean | Always true for either tier. |
| `getLimits()` | copied limits record | Read the effective finite transport envelope and common data limits; available even while the radar is unpowered. |

All methods enforce exact arity and reject colon calls. `transmit` requires three arguments; explicit nil is legal in the third argument, but omitting it is an arity error. `open`, `close` and `transmit` do not return success booleans or subscription identifiers.

A channel is a finite integer in the inclusive range 0–65535. Wrong Lua types/arity produce `E_ARGUMENT`; numeric values outside the channel domain, including fractional and non-finite numbers, produce `E_RANGE`. More than 128 distinct open channels produces `E_CAPACITY` without changing the set. Reopening at capacity succeeds.

Other methods follow the ordinary reachable-peripheral policy: live identity and selected-wire proof on every call; `E_UNREACHABLE` for an invalid binding, `E_NETWORK_PENDING` for incomplete proof, and `E_UNPOWERED` for an inactive or electrically unavailable target. As with existing peripherals, only `getLimits` and generic discovery metadata remain accessible while unpowered; even `isOpen` and `isWireless` require an available target.

No `getNamesRemote`, `callRemote`, `getNameLocal`, remote peripheral enumeration, CraftOS `os.pullEvent`, rednet, implicit routing/repeaters or OS/network sockets are introduced.

## Shared channel ownership

The open-channel set belongs to the physical radar identity, not to a wrapper, wire color, computer run or Console session. All authorized local callers share it in synchronized call order. One caller's `closeAll()` affects the others; stopping or faulting a computer does not implicitly close this shared device state. A player requiring independent subscriptions uses separate radars.

Console commands can call all modem methods through authentic checked bindings. They cannot register a background receive handler: receipt still requires a running saved program and `computer.on`. Opening a channel alone does not create an event subscription or activate a program.

Both tiers accept and retain the same channel domain and capacity. Channels are not security credentials. Exact force membership and a valid local physical path establish authority; allied forces are not included.

## Payload

The third argument accepts the shared `Data` contract, plus explicit nil at the top level. Nil is not added to persistent Data or nested collections. False, zero and empty strings remain distinct payloads. A nil message is represented by an absent `message` field in the event.

Validate the entire value and declared bytes/nodes/depth/entry limits before any packet effect. Do not serialize functions, peripheral facades, host LuaObjects, cycles, mixed-key maps, sparse arrays, metatables or non-finite values; do not silently strip unsupported content to imitate permissive serialization. Use the shared `E_ARGUMENT`/`E_LIMIT` data-validation errors.

Each recipient handler receives an independent plain snapshot. Validation/copy work and event metadata count toward admission, including the copies required by multiple handler registrations. A maximum accepted payload must fit a complete event in an empty recipient queue; payload bytes alone are not the event size.

## Event registration and schema

Register through saved function declarations using `computer.on("modem_message", "received")`; unregister with the returned subscription ID through `computer.off`. All existing subscription limits and named-handler rules remain in force. Multiple registrations intentionally produce one callback per registration.

`ModemMessage` extends `BaseEvent`:

```text
ModemMessage = {
  name = "modem_message",
  tick = Tick, sequence = integer,
  computer_id = ComputerId, run_id = string,
  peripheral = PeripheralName,       -- receiving radar, never sender authority
  wire = "red" | "green",            -- first entry in wires
  wires = Wire[],                    -- valid receive-time local paths, red first
  channel = integer,
  replyChannel = integer,            -- exact CC-style spelling
  message = Data | nil,
  distance = finite number | nil,    -- radar-to-radar tiles on the same surface
  sent_tick = Tick                   -- simulation tick at accepted transmission
}
```

`tick` follows the existing runtime's callback-dispatch semantics, while `sent_tick` preserves the transmission time. Same-surface distance is Euclidean distance between radar entity centers sampled at transmission; it has no range-gating effect. Cross-surface distance is omitted, not zero or a fabricated planetary distance.

One transmission produces one receive event per `(receiving computer run, receiving radar identity, handler registration)`. Reaching one radar on both colors produces one event with both colors, canonical red first. Reaching two receiving radars produces separate events. The transmitting physical radar is excluded from reception, including through other computers wired to it; another radar wired to the sender's computer remains eligible.

`replyChannel` is a hint chosen by the sender, not an automatic response or return route. A receiver can explicitly transmit on it. Opening the original sender's reply channel and registering its handler are separate operations.

## Routing and event admission

At the accepted transmission, select powered/active receiving radars whose channel is open, with the same force as the sender. On the same surface either tier can receive from either tier at any distance. Across surfaces, both endpoints must be advanced and Space Age must be enabled. All surfaces, including planets and travelling space platforms, follow this rule; there is no interplanetary distance calculation or delayed orbital delivery.

Only running, powered computers with a matching handler and a freshly proved local path to the receiver are destinations. A receiver with no eligible computer produces no event. No recipients is a successful no-op, not a discovery failure. Native hidden radar links are never local path evidence.

Routing starts from those eligible receiving computers, not from the remembered-radar pool. `routing_candidates` counts unique available, open-channel receivers reached through their current inventories; disconnected retained records are neither enumerated nor charged against that ceiling. Both relevant color proofs must complete before publication. Numeric ceilings, selected-wire authority, deterministic ordering and failure atomicity are unchanged.

Prepare and charge the complete relevant candidate/delivery plan before publishing its first event. An incomplete relevant graph, fan-out limit, copy failure or throughput refusal has no packet effects; no successful recipient prefix is returned. Unrelated forces and, for ordinary transmitters, other surfaces are not relevant routing candidates. Resource-exhaustion faults still follow the runtime's non-catchable budget rules.

After successful preparation, publish in sorted computer ID, receiving radar ID and subscription sequence order. Local red/green paths are deduplicated before this sort. The existing FIFO scheduler controls callback dispatch, so callbacks never run reentrantly; no minimum one-tick delay is promised. Every accepted transmission is independent even if its payload equals a previous message.

Recipient queue overflow follows the existing runtime policy: visibly fault that recipient and retire its run, skip its remaining prepared deliveries, and continue other recipients deterministically. This is not a retryable sender error after partial publication. Preparation must ensure payloads and host-work reservations cannot fail partway through publication. These are datagrams without acknowledgements/retries, not an all-recipients delivery guarantee.

A packet already queued is an accepted data snapshot: closing a channel, detaching or removing the receiving radar later does not recall it. Subsequent calls still need live authority. Stop, fault, computer removal, force/surface retirement and computer power-loss handling retain their existing cancellation/transient-event rules. No traffic missed during unavailability is replayed.

## Persistence and identity

Ordinary cold saves retain the radar identity and channel set, the computer's registrations and queue, and transport rate-limit accounting. Load reconstructs no guest work and never re-transmits. Modem open state is not included in mined items, blueprints, clones or pasted settings. New placement receives an empty set and a new identity only when enrolled through a computer-rooted path. Radar force/surface reassignment clears channels and invalidates previous bindings before participation in the new scope; public reads refuse a scope mismatch pending synchronized reconciliation rather than mutating authority.

Losing the last computer path retains the same entity's opaque identity and channels as dormant saved data, outside generic tick iteration, availability checks, adoption roots and radio-candidate scans. No dormant-pool polling is permitted. Same-entity, same-scope reconnection restores access without missed-traffic replay; old wrappers remain subject to fresh selected-color authority. Targeted destruction retires the exact entity identity without transferring it to a replacement. Accepted queued events remain independent snapshots.

Upgrading a supported legacy save excludes its registered radar records from recurring work before the first ordinary tick, without player rewiring or an amortized cleanup sweep. Cold reload preserves that separation without authoritative writes in `on_load`. Identity capacity still includes dormant records; retained memory and save serialization are not free, and native Factorio radar simulation is unaffected. Rollback requires the backed-up pre-upgrade save and matching prior mod archive, not an in-place downgrade of the partitioned registry.

## Queryable limits

The limits record includes:

- `channel_min = 0`, `channel_max = 65535`, `open_channels = 128`.
- `message_bytes`, `message_nodes`, `message_depth`: effective positive payload ceilings, no greater than the common data/event envelope permits.
- `routing_candidates`, `deliveries_per_transmit`: finite positive recipient-planning limits; deliveries count handler events, not just radars.
- `transmits_per_computer_tick`, `transmits_per_tick`: finite positive per-computer and aggregate accepted-transmission ceilings, shared by both wire colors, saved programs and Console access.

Zero is allowed only for the documented channel minimum. Unlimited communication range is a semantic rule, not infinity in a numeric limit field. Tier comes from `peripheral.describe`, not another wire namespace or implicit surface search.

Numerical resource ceilings other than channel-domain/open-channel compatibility are frozen after real-engine envelope measurement. Documentation and `getLimits` must agree before release; no existing global budget may be raised merely to pass the new workload.

## Required cases

Exact signatures and return arity; boundary channels; capacity/idempotency; shared computers/colors/Console calls; same-radar self-echo exclusion; two receiving radars; same-surface distances; closed channels; wrong/allied force; mixed tiers both directions; different ordinary surfaces; advanced planet/platform/in-flight routes; nil/false/invalid/oversized data; receiver-copy isolation; both-wire deduplication; multi-handler order; detach before versus after admission; incomplete proof with no prefix; fan-out/rate refusal; receiver overflow; power cycle and no replay; same-tick cold credits; save with queued events; removal/replacement/clone/force change; native hidden-wire exclusion.
