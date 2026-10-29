# Scheduling and peripheral availability API contract

Normative companion to this change's [runtime](specs/computer-runtime/spec.md), [logic](specs/logic-handler/spec.md), [network](specs/peripheral-network/spec.md) and [lifecycle](specs/device-lifecycle/spec.md) deltas. This document changes availability and scheduling semantics, not method inventories, argument validation or return arity. Canonical capability companions remain the baseline until implementation/synchronization; the differences below explicitly supersede their electrical requirements.

## Stable public surface

| Existing operation | Exact return | Scheduling meaning |
| --- | --- | --- |
| `computer.on(event_name, handler_name)` | one SubscriptionId | Register interest; only relevant events enqueue callbacks. |
| `computer.off(subscription_id)` | one boolean | Cancel the matching registration under existing scope/queue rules; remove its observation interest. |
| `computer.after(delay_ticks, handler_name, payload?)` | one TimerId | Register an absolute simulation deadline, not a per-computer tick loop. |
| `computer.every(interval_ticks, handler_name, payload?)` | one TimerId | Recurring aligned deadline with existing missed-interval coalescing. |
| `computer.cancelTimer(timer_id)` | one boolean | Cancel pending deadline and undispatched timer event; false when neither exists for that run. |
| `io.subscribe(options, handler_name)` | one SubscriptionId | Add one run/binding-specific signal subscription and its selected input to watched membership. |
| `io.unsubscribe(subscription_id)` | one boolean | Remove that subscription and matching undispatched samples; remove the watch when its final subscriber leaves. |
| `peripheral.describe(name, wire)` | one PeripheralInfo or nil | Fresh authorized metadata; preserve the `powered` boolean field as described below. |
| `peripheral.call(name, wire, method, ...)` | the method's unchanged result tuple | Revalidate exact live authority, plus native power only for radar/speaker active methods. |

These signatures and existing error cases come from the canonical [computer](../../specs/computer-runtime/lua-api.md), [logic](../../specs/logic-handler/lua-api.md) and [network](../../specs/peripheral-network/lua-api.md) contracts. No guest `tick`, task, scheduler, sleep, continuation or flush API is added. Console restrictions on timers/subscriptions remain intact. Callback locals still do not survive invocation; native bounded handlers and explicit application state are unchanged.

## Availability by peripheral family

| Device / peripheral type | New electricity rule | Preserved service surface |
| --- | --- | --- |
| Computer (not a discoverable peripheral) | No consumption or electrical prerequisite for Run, callbacks or Console | Existing computer API and editor/Console controls |
| `kv_database` | All methods and local browsing work without electricity | Complete KV method inventory, exact expiry and atomic mutation |
| `monitor` | All methods, touch and retained visible images work without electricity | Terminal methods, automatic buffering, selected groups, resize/touch payloads |
| `logic_handler` | All methods, subscription observations and valid owned output work without electricity | Reads, output replacement, explicit input/color subscriptions |
| `configurator` | All existing methods and local target browsing work without electricity | Exact target identity, native capability/patch/section authority; no target-machine power changes |
| `recipe_searcher` | `findRecipes` and `getLimits` work without electricity | Same signatures, complete-or-error records, limits and research |
| `factoriopedia_interface` | `getItem`, `getFluid`, `listItems`, `listFluids`, `getLimits` work without electricity | Same namespaces, metadata and complete-or-error results |
| `production_statistics` | `getTotals`, `getRates`, `getHistory`, `getLimits` work without electricity | Same scope, units, native samples and result shapes |
| `dashboard` | All present base/optional-chart methods and authorized button actions work without electricity | Same exact conditional method inventory, subscriptions and event validity |
| `modem` (ordinary and advanced radar) | Native electricity unchanged; active methods and receiving-radar eligibility check it at use time | Existing `open`, `isOpen`, `close`, `closeAll`, `transmit`, `isWireless`, `getLimits` |
| `speaker` (native programmable speaker) | Native electricity unchanged; methods other than `getLimits` check it at use time | Existing `playNote`, `playSound`, `getInstruments`, `getNotes`, `getSounds`, `getLimits` |

For valid custom endpoints, `PeripheralInfo.powered` is `true`: the endpoint needs no electrical supply. It is not a substitute for physical validity, operational status or selected-wire authority. For native modem/speaker endpoints the same field remains the fresh native availability observation at the requested description. Metadata is a snapshot, never a reusable authorization token. Passive relay and permitted metadata/`getLimits` access remain power-independent for native endpoints.

No native radar/speaker power watcher is registered by placement, discovery, open channels, message subscriptions or retained metadata. A real transmission evaluates receiving radar power as part of its existing bounded eligibility proof. An unpowered receiver gets no new packet; restoring supply never replays missed traffic. Already accepted packet snapshots retain existing cancellation semantics. Speaker requests already submitted to the engine are not canceled or replayed by this change.

## Signal observation and event compatibility

- `options.input` remains mandatory `"red"` or `"green"`; the wrapper's discovery wire is a separate authority choice. `signals` and `initial` keep their existing validation/defaults.
- No signal subscription means no subscription-driven tick visit for that computer. A computer can remain asleep while its subscribed physical input is observed each tick.
- Multiple subscribers to one physical input/color share the native observation, not filters, baseline ownership, event identities or callback authorization. Direct reads and registration baselines still query native state; retained observation data is not a service read cache.
- `getLimits().sample_interval_ticks` stays `1`. `notification_latency_ticks`, queue policy, callback work bounds and the existing topology/fail-safe envelope stay unchanged.
- `SignalChanged` retains `subscription_id`, `peripheral`, `wire`, `input`, `sample_tick`, `initial`, `resync`, `previous`, `current`, `changes`, `previous_connected`, `connected` and BaseEvent. Sample time and dispatch time remain distinct. Values visible only between observable native circuit steps are not promised.
- A native unchanged hint can avoid retrieving/projecting an unchanged inventory; it does not replace selected-path/connectivity validation, actual comparison after a positive hint, or required initial/resync work. An observation failure retains explicit fault/fail-safe behavior; it is not permission to silently reduce frequency.
- Electrical changes do not create `resync=true`. Preserve the field for current-state resynchronization required by a supported legacy paused-state migration or physical observation recovery, not ordinary power monitoring. A normal cold load preserves baselines and pending events; it does not manufacture a resync or replay startup.
- Stop/fault/replacement/definitive detachment removes the appropriate registrations and work memberships under existing cancellation semantics. Reaching the same device on another color never silently moves a subscription.

## Computer and Console lifecycle

Electrical supply changes do not pause custom computers, cancel queued commands/events, clear valid outputs, rebaseline inputs or trigger startup. Explicit stop/fault and non-power authority loss keep their existing cleanup rules and last-writer protection. Source, explicit state, committed Console values, device content and ledgers remain preserved under existing lifecycle contracts.

`computer.on("power_restored", handler_name)` remains accepted for backward source/save compatibility, and `off` remains usable. It is an inert legacy event name: no new restoration events or recurring watcher are generated. Already admitted historical `power_restored` events remain ordinary accepted queue items; migration never synthesizes an extra one.

A legacy running-but-electrically-paused save resumes the same generation after synchronized migration, without `start` replay. Timers preserve aligned deadlines and coalesce overdue intervals. Previously discarded transients are not resurrected; surviving subscriptions needing a current baseline get their documented one-time resync.

## Dispatch and errors

One executable program or Console item per computer per actual simulation tick remains the maximum. FIFO order within each accepted queue, fair program/Console arbitration, shared work/allocation/maintenance accounting, fatal execution controls and overflow policy remain unchanged. Cross-computer service follows a stable synchronized ready rotation; callbacks never execute inside event producers. Work created during the dispatch round joins a subsequent round, not a recursive invocation.

| Condition | Required result |
| --- | --- |
| Custom device lacks electrical coverage | Not an error; no `E_UNPOWERED` |
| Native radar/speaker lacks active electrical availability | Existing `E_UNPOWERED` before an active effect |
| Captured binding removed/replaced, wrong scope or selected path lost | Existing unreachable/authority diagnostic; no retargeting |
| Incomplete topology proof | Existing pending/limit diagnostic, not an invented empty complete result |
| Signal sampling cannot be admitted | Existing explicit affected-run sampling failure and output cleanup, not silent missed observation |
| Queue or guest execution allowance exhausted | Existing overflow/fatal controls; no new drop, pause or unlimited queue policy |
| Speaker playback allowance exhausted after valid authority | Existing boolean `false`, not a new deferred sound job |

## Contract verification

Exercise the exact unchanged methods through saved handlers and Console where supported, not internal host calls alone. Cover every custom family without electrical infrastructure, unchanged native outages and restoration, metadata-to-call races, queued timer cancellation, same-input fan-out with different filters/colors, native one-tick pulses, no-subscriber populations, local read-only inspection, cold upgrade/reload and late joining. Verify source/state/wires/model/queue/credit preservation and no callbacks, output writes, audio or radio replay during load. Update every affected canonical companion/help/example when implementing; do not leave the prior electrical contract as the only shipped guidance.
