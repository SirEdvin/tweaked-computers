# Logic handler input, output and subscriptions

A north-facing handler has **INPUT / NETWORK / OUTPUT** left to right. Wire computer
NETWORK to handler NETWORK for discovery, factory readout to INPUT, controlled
machines to OUTPUT. No internal role feedthrough exists. External feedback is
possible only if you wire it deliberately. Obtain
`local io = peripheral.find("logic_handler", "red")`.
Discovery red is independent of INPUT selection red/green/both.

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

Strict dot calls; extra arguments/unknown options fail. `input` is exactly red,
green or both. A SignalId is `{type="item"/"fluid"/"virtual"/"recipe", name=prototype,
quality=quality_name?}`; a Signal is `{signal=SignalId,count=Int32}`. Type/name and
quality must exist. Quality defaults normal and is explicit on readback. No
wildcards or count coercion. Complete identities sort by type/name/quality.

Recipe names are exact installed recipe prototype names, including recipes added
by other mods; they need not match the recipe's output item. An item and recipe
with the same name remain distinct. Recipe signals work in single/all-signal
reads, output banks and subscription filters. For example,
`io.readSignal("red", {type="recipe", name="iron-plate"})` reads the recipe signal,
not the iron-plate item signal.

Both-input sums wrap signed32 per identity using
`((red+green+2147483648)%4294967296)-2147483648`, without physically connecting
colors. Negative counts are legal. Duplicate normalized output identities,
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
| input | red / green / both |
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
bank/owner/subscriptions without replaying start or republishing writes. New
placement/clones start zero/unowned.

State/KV/display and applied factory configuration are not rolled back by output
cleanup. Use native conditions that stop on absent output for fail-safe control.
Unexpected native bank failure restores prior contribution or retains explicit
recovery and clears output; never assume a callback-wide factory transaction.

## Bounds and use

Initial caps: 64 signal slots per input/combined snapshot/output; 64 filter signals;
64 subscriptions per computer shared with general registrations; 128 sampled
handlers; 1,024 aggregate subscriptions; 128 owned banks. Sample interval 1 tick,
fail-safe target 1 tick, notification/topology ceiling 60 ticks is provisional.
The native prototype×quality read envelope is pre-admitted; large modded universes
can refuse instead of doing unbounded work. Queue overflow or sampling/notification
maintenance refusal visibly faults affected runs, not silently loses history.
The supported-type precharge includes the installed recipe registry. Other native
signal categories remain unsupported and are refused, not silently filtered out.
Two-color subscriptions can exceed shared sampling headroom in Space Age even
when a single-color subscription or ordinary `readSignals("both")` callback fits.
Sampling refusal faults the run visibly; it does not silently miss updates.

Use [logic-controller](../examples.md#logic-controller) and the
[first inserter tutorial](../first-controller.md). If reads stay zero, check chest
read mode and INPUT color, distinguish disconnected getInputStatus from connected
zero, and use exact quality. If output vanishes, inspect owner path/power/fault,
not just native downstream condition. [Shared errors](common.md#errors) apply.
