# Radar modem Lua API v1

Normative companion to [spec.md](spec.md). The [shared types, errors and dot-call convention](../../api/common.md) and [named-handler runtime](../computer-runtime/lua-api.md) continue to apply. Acceptance receipts distinguish actual packaged execution, native appearance and connected-client delivery from illustrative examples.

## Discovery and tiers

Use `peripheral.find("modem", "red")`, `peripheral.wrap(name, wire)` or checked `peripheral.call` with the existing mandatory wire argument. `wire` is a local physical discovery color, not a radio frequency. Both radar tiers have public type `modem`; `peripheral.describe` additionally returns `modem_tier = "surface" | "interplanetary"` and the actual footprint. Other metadata retains existing meanings, with radar availability also requiring the native entity to be active.

Only vanilla prototype `radar` and, when Space Age is active, `tc-interplanetary-radar` participate. No automatic support is promised for third-party radar prototypes. No method enumerates remote computers, wraps remote peripherals or returns Factorio objects.

## Methods

| Exact signature | Returns | Behavior |
| --- | --- | --- |
| `open(channel)` | zero values | Add a channel to this physical radar's shared set; reopening is a no-op. |
| `isOpen(channel)` | boolean | Read that shared set. |
| `close(channel)` | zero values | Remove the channel if present; closing an absent channel is a no-op. |
| `closeAll()` | zero values | Clear all channels on this radar, including those opened by another authorized computer. |
| `transmit(channel, replyChannel, payload)` | zero values | Broadcast a defensively copied payload; neither channel needs to be open locally. There is no delivery count or acknowledgement. |
| `isWireless()` | boolean | Always true for either tier. |
| `getLimits()` | copied policy record | Read effective resource descriptors and the safe-integer channel domain; available even while the radar is unpowered. |

All methods enforce exact arity and reject colon calls. `transmit` requires three arguments; explicit nil is legal in the third argument, but omitting it is an arity error. `open`, `close` and `transmit` do not return success booleans or subscription identifiers.

A channel is a finite integer in the inclusive range 0–9007199254740991. Wrong Lua types/arity produce `E_ARGUMENT`; numeric values outside the channel domain, including fractional and non-finite numbers, produce `E_RANGE`. There is no independent open-channel count ceiling. New channels require retained host-memory admission; a recoverable `E_CAPACITY` preserves the previous shared set. Reopening and reducing the set remain available without new retained growth.

Other methods follow the ordinary reachable-peripheral policy: live identity and selected-wire proof on every call; `E_UNREACHABLE` for an invalid binding, `E_NETWORK_PENDING` for incomplete proof, and `E_UNPOWERED` for an inactive or electrically unavailable target. As with existing peripherals, only `getLimits` and generic discovery metadata remain accessible while unpowered; even `isOpen` and `isWireless` require an available target.

No `getNamesRemote`, `callRemote`, `getNameLocal`, remote peripheral enumeration, CraftOS `os.pullEvent`, rednet, implicit routing/repeaters or OS/network sockets are introduced.

## Shared channel ownership

The open-channel set belongs to the physical radar identity, not to a wrapper, wire color, computer run or Console session. All authorized local callers share it in synchronized call order. One caller's `closeAll()` affects the others; stopping or faulting a computer does not implicitly close this shared device state. A player requiring independent subscriptions uses separate radars.

Console commands can call all modem methods through authentic checked bindings. They cannot register a background receive handler: receipt still requires a running saved program and `computer.on`. Opening a channel alone does not create an event subscription or activate a program.

Both tiers accept and retain the same channel domain and capacity. Channels are not security credentials. Exact force membership and a valid local physical path establish authority; allied forces are not included.

## Payload

The third argument accepts the shared `Data` contract, plus explicit nil at the top level. Nil is not added to persistent Data or nested collections. False, zero and empty strings remain distinct payloads. A nil message is represented by an absent `message` field in the event.

Validate the entire value and admit copying, retained plan storage and host-stack use before any packet effect. Do not serialize functions, peripheral facades, host LuaObjects, cycles, mixed-key maps, sparse arrays, metatables or non-finite values; do not silently strip unsupported content to imitate permissive serialization. Shared Data validation and recoverable resource diagnostics apply; removed payload-shape counts are not a separate modem allowance.

Each recipient handler receives an independent plain snapshot. Validation/copy work and event metadata count toward admission, including the copies required by multiple handler registrations. A maximum accepted payload must fit a complete event in an empty recipient queue; payload bytes alone are not the event size.

## Event registration and schema

Register through either supported source form using `computer.on("modem_message", "received")`; unregister with the returned subscription ID through `computer.off`. All existing subscription limits and named-handler rules remain in force. Multiple registrations intentionally produce one callback per registration.

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

Prepare and charge the complete relevant candidate/delivery plan before publishing its first event. Preparation may pause across ticks; a copy, authority or retained-capacity refusal before acceptance has no packet effects. Unrelated forces and, for ordinary transmitters, other surfaces are not relevant routing candidates. After acceptance, the saved cursor resumes the unfinished suffix without replaying processed destinations. Work deferral is private, not a guest retry request; there is no independent candidate, delivery or per-tick transmission count ceiling.

After successful preparation, publish in sorted computer ID, receiving radar ID and subscription sequence order. Local red/green paths are deduplicated before this sort. The existing FIFO scheduler controls callback dispatch, so callbacks never run reentrantly; no minimum one-tick delay is promised. Every accepted transmission is independent even if its payload equals a previous message.

Recipient queue overflow drops the newest delivery and increments that physical computer's persistent loss diagnostics, preserving its run and accepted queue. Current run, handler, radar, power, channel and local authority are rechecked before each publication. An unavailable prepared destination with a surviving computer record increments its loss diagnostics once with reason `modem_destination_unavailable`. Other destinations continue; the sender receives no acknowledgement, count or retryable partial-send error. Complete retirement/sender-cancellation loss attribution remains an implementation gate, not a verified guarantee of this checkpoint.

A packet already queued is an accepted data snapshot: closing a channel, detaching or removing the receiving radar later does not recall it. Subsequent calls still need live authority. Stop, fault, computer removal, force/surface retirement and computer power-loss handling retain their existing cancellation/transient-event rules. No traffic missed during unavailability is replayed.

## Persistence and identity

Ordinary cold saves retain the radar identity and channel set, the computer's registrations and queue, and prepared broadcast progress with spent resource credits. Load executes no guest work and never re-transmits a completed prefix. Modem open state is not included in mined items, blueprints, clones or pasted settings. New placement starts with an empty set and a new identity. Radar force/surface reassignment clears channels and invalidates previous bindings; later ordinary same-scope reconnection does not itself reset channels.

## Queryable limits

The defensive record has `policy_version=2`, `channel_min=0`,
`channel_max=9007199254740991`, `resources` and an empty `tuning` map.
Each resource descriptor contains `limit`, `unit`, `scope`, `setting` and `behavior`,
matching the corresponding descriptor from `computer.getLimits()`:

- `callback_work`, `callback_allocations`, `host_work_per_tick`, `maintenance_work_per_tick`.
- `runtime_memory_bytes`, `host_memory_bytes`, `pending_work_bytes`, `host_stack_depth`.
- `event_queue_entries`, `event_queue_bytes`.

There are no flat common-limit fields or `open_channels`, `message_bytes`,
`message_nodes`, `message_depth`, `routing_candidates`, `deliveries_per_transmit`,
`transmits_per_computer_tick` or `transmits_per_tick` capacities. Mutating this
record, including its nested maps, changes no setting. Unlimited communication
range is a semantic rule, not infinity in a numeric field. Tier comes from
`peripheral.describe`. Resource settings are not a promise that every workload
fits a slice; no production budget may be raised merely to pass a gate.

## Required cases

Exact signatures and return arity; safe-integer channels; resource capacity/idempotency; shared computers/colors/Console calls; same-radar self-echo exclusion; two receiving radars; same-surface distances; closed channels; wrong/allied force; mixed tiers both directions; different ordinary surfaces; advanced planet/platform/in-flight routes; nil/false/invalid/oversized data; receiver-copy isolation; both-wire deduplication; multi-handler order; detach before versus after admission; incomplete proof with no prefix; former fan-out/rate boundary crossings; observable receiver overflow/unavailability; power cycle and no replay; same-tick cold credits; reload within a prepared delivery prefix; removal/replacement/clone/force change; native hidden-wire exclusion. See the implementation evidence for passing subsets and outstanding gates.
