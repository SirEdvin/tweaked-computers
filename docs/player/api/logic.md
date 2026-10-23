# Logic handler input, output and subscriptions

A north-facing handler has **INPUT / NETWORK / OUTPUT** left to right. Wire computer
NETWORK to handler NETWORK for discovery, factory readout to INPUT, controlled
machines to OUTPUT. No internal role feedthrough exists. External feedback is
possible only if you wire it deliberately. Obtain
`local io = peripheral.find("logic_handler", "red")`.
Discovery red is independent of the explicit INPUT selection red or green.

## Complete methods

| Signature | Exact returns |
| --- | --- |
| `io.readSignal(input, signal)` | Int32, absent gives 0 |
| `io.readSignals(input)` | Defensive canonical nonzero Signal array |
| `io.getInputStatus()` | `{red_connected=boolean, green_connected=boolean}` from actual INPUT edges |
| `io.getOutput()` | Defensive Signal array of this handler's configured contribution only |
| `io.setOutput(signals)` | None; complete bank replacement and writer transfer |
| `io.clearOutput()` | None; equivalent to setOutput({}) |
| `io.subscribe(options, handler_name)` | Run-scoped subscription string |
| `io.unsubscribe(subscription_id)` | Boolean; remove own binding's registration and queued samples; false when absent |
| `io.getLimits()` | Defensive shared + device ceilings |

Strict dot calls; extra arguments/unknown options fail. `input` is exactly red
or green; missing, `both` and other selectors are refused before registration.
A SignalId is `{type="item"/"fluid"/"virtual"/"recipe", name=prototype,
quality=quality_name?}`; a Signal is `{signal=SignalId,count=Int32}`. Type/name and
quality must exist. Quality defaults normal and is explicit on readback. No
wildcards or count coercion. Complete identities sort by type/name/quality.

Recipe names are exact installed recipe prototype names, including recipes added
by other mods; they need not match the recipe's output item. An item and recipe
with the same name remain distinct. Recipe signals work in single/all-signal
reads, output banks and subscription filters. For example,
`io.readSignal("red", {type="recipe", name="iron-plate"})` reads the recipe signal,
not the iron-plate item signal.

Each read observes only its selected physical circuit; colors are never combined.
Native circuit sums retain signed32 semantics. Negative counts are legal. Duplicate normalized output identities,
including duplicate zeros, are refused before mutation; zero entries are omitted.
Failed validation/admission preserves bank **and** writer.

Output is one bank mirrored to red and green; native external contributors can
make network totals different. getOutput does not read those totals. A successful
write/clear transfers the entire bank's ownership to this computer/run/discovery
color. Another writer's subsequent success replaces that ownership.

## Subscriptions

`options={input=InputSelection, signals={SignalId,...}?, initial=boolean?}`.
Input is required; omitted signals means all, otherwise nonempty unique filters;
initial defaults false. Handler name must be declared. Registrations persist by
name/data, never saved functions, and bind the selected discovery color. Losing
red cannot silently rebind green. IDs from another run/binding are invalid.

One actual-tick sample per powered subscribed handler. Initial=false baselines
current input without an event; true queues next sampling tick with empty
previous and false previous connectivity. Notify only changed selected values or
connectivity. A vanished nonzero signal has `current=0` in changes. An empty
network connecting/disconnecting may produce empty changes with changed
connectivity. Within-tick transients are not observed.

`signal_changed` extends [BaseEvent](common.md#types) with:

| Field | Type / meaning |
| --- | --- |
| subscription_id | string |
| peripheral, wire | string name and selected discovery Wire |
| input | red / green |
| sample_tick | Tick of observation, not callback dispatch |
| initial, resync | booleans |
| previous, current | canonical Signal arrays |
| changes | array of `{signal=SignalId, previous=Int32, current=Int32}` |
| previous_connected, connected | maps with selected red/green boolean keys only |

Queue **admission**, not callback dispatch, advances the baseline. Computer/handler
outages discard obsolete queued samples but retain registration/baseline. Restoration
resyncs current values, not every missed transition; previous can describe an
admitted sample whose callback was discarded. Native circuits report prior circuit
update state; no immediate recursive effect or zero-latency propagation is promised.

## Fail-safe ownership and persistence

Stop, fault, power loss, removal, authority change or loss of the owner's selected
path clears **only** that run's still-owned bank. A stopping old writer cannot
clear a later writer's bank. Source failure cannot suppress cleanup. On restoration
output remains empty until another successful write. Cold load retains a valid
bank/owner/subscriptions without replaying start or republishing writes. Persisted
legacy subscriptions with `both`, missing or invalid input fault the run before
queued callbacks dispatch, clear its owned output and discard pending callbacks;
update the saved source to select red or green explicitly and restart. No wire is
silently substituted. New
placement/clones start zero/unowned.

State/KV/display and applied factory configuration are not rolled back by output
cleanup. Use native conditions that stop on absent output for fail-safe control.
Unexpected native bank failure restores prior contribution or retains explicit
recovery and clears output; never assume a callback-wide factory transaction.

## Bounds and use

Input snapshots and filters have no signal-count ceiling. Each explicit color
returns its complete sorted native inventory, including negative counts, quality
and recipe identities. Output replacement has no mod-defined 64-slot ceiling:
the engine must accept and read back the complete staged bank before publication.
Invalid counts and identities leave the previous bank and writer unchanged.

Private preparation cursors retain paid read/filter/sort/change progress across
slices and cold reload. Work deferral does not retire the run or advance its
last admitted baseline; delayed observations are marked `resync`. Queue overflow
drops the newest notification, counts the loss, and requests resynchronization.
Stop, lost authority and power still clear exact-owned output independently.

Shared work, retained-memory and event-byte admission still apply. Sampling is
attempted every tick, not promised every tick under pressure. Native enumeration
materializes its list before Lua can inspect its size; call charges are not a
native CPU-time or allocation bound. Unsupported native signal categories are
refused, never silently filtered out. See the integration gates in
`docs/inventory-resource-validation.md` before treating the resource-policy branch
as a fully validated release.

Use [logic-controller](../examples.md#logic-controller) and the
[first inserter tutorial](../first-controller.md). If reads stay zero, check chest
read mode and INPUT color, distinguish disconnected getInputStatus from connected
zero, and use exact quality. If output vanishes, inspect owner path/power/fault,
not just native downstream condition. [Shared errors](common.md#errors) apply.
