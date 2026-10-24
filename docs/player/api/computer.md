# Computer callbacks and state

Use either [plain function declarations or the legacy native descriptor](language.md).
All API calls use `computer.method(...)` with exact arity except the documented
optional arguments. If exported, `start` is queued once per explicit successful
Run/Apply, not after ordinary load. Without it, activation runs no arbitrary export.
Every dispatched callback gets fresh locals/functions/environment and a copied
event. Use state for continuity; closures and captured locals are not saved.

In declaration-form programs, `sample(...)` calls another export synchronously
with exactly your arguments and ordinary Lua results. It shares the current run,
authority and budgets; it does not queue a callback or invent an event argument.
Calling `start(...)` this way is not Run/Apply: only its written body runs.
Exports are immutable within the program (normal local shadowing is allowed).
Private `local function` helpers are not registerable handlers. These bindings
belong to this program, never to the [live Console](../console.md).

## Complete method reference

| Signature | Return values | Contract |
| --- | --- | --- |
| `computer.getID()` | string | Current opaque entity ID |
| `computer.getLabel()` | string or one nil | Descriptive label, not unique/addressable |
| `computer.setLabel(label?)` | none | String of at most 64 bytes; omitted/nil clears; empty/duplicate labels allowed |
| `computer.getTick()` | Tick | Current synchronized simulation tick |
| `computer.getLimits()` | copied map | All [common limits](limits.md) |
| `computer.getResourceStatus()` | copied map | Policy version, execution state, measured resource usage, retained event-loss counters and last recorded resource refusal |
| `computer.getState(key)` | copied Data or one nil | Key: nonempty string of at most 64 bytes |
| `computer.setState(key, value)` | none | Atomically validate/copy nonnil Data; false and empty strings are values |
| `computer.deleteState(key)` | boolean | True only if present and removed |
| `computer.log(text)` | none | String, bounded rolling diagnostic output |
| `computer.stop()` | does not return | Stop this run through unavoidable host cleanup, even inside pcall |
| `computer.on(event_name, handler_name)` | subscription string | Create an independent general-event registration |
| `computer.off(subscription_id)` | boolean | Remove own run's registration; false if already removed |
| `computer.after(delay_ticks, handler_name, payload?)` | timer string | One-shot positive integer tick delay |
| `computer.every(interval_ticks, handler_name, payload?)` | timer string | Recurring positive integer tick interval |
| `computer.cancelTimer(timer_id)` | boolean | Cancel deadline and admitted undispatched event; false if neither remains |

State: at most 256 root entries and, by default, 65,536 accounted bytes;
there is no separate total-node ceiling.
Data depth 16, per-table entries 1,024, strings 16,384 bytes. Keys/container
metadata count too. Rejected updates preserve the old value. Snapshots do not
mutate originals; nil is not a state value, use deleteState. Payloads use copied
nonnil Data when supplied; metadata must also fit the event envelope.

Logs keep the newest 64 entries / 16,384 bytes, evicting oldest. An entry must be
a string within supported bounds. There is no program access to editor drafts,
other computers' state/lifecycle, wall clock or arbitrary Factorio objects.

Use `print("Initial sample count:", total)` for ordinary multi-argument output.
It writes one tab-separated entry through the same bounded log, preserving false
and nil positions, returning no values. `print()` writes an empty entry. The
Console displays tabs as spaces without changing stored bytes. No chat output is
produced. `computer.log(text)` remains the exact one-string API. Complete formatting
and retention admission precede append/eviction; earlier output survives later errors.
See [base helpers and protected errors](language.md#printing-raw-helpers-and-error-transformation).

## Resource status

`computer.getResourceStatus()` takes no arguments and returns one defensive
snapshot for this computer in programs and Console. It has `policy_version=2`,
`state`, `resources`, `dropped_events` and an optional `last_refusal`.
State distinguishes `running`, `waiting`, `idle`, `resource_refused`, `stopped`
and `faulted`; waiting does not mean that a callback has finished.

Each reported resource contains `used`, `limit`, `unit`, `scope`, `setting` and
`over_limit`. Missing measurements are unavailable, not zero usage. Counters are
deterministic accounting units, not a measurement of the Lua heap or client FPS.
The workspace can show this host snapshot without waiting for the guest to call
the method.

`dropped_events.total` survives Stop/Run, Console reset and cold reload. It
saturates rather than wrapping, with `saturated=true`, and may include
`last_tick`, `last_kind` and `last_reason`. These counters remain available after
their rate-limited warning has been evicted from the log. Reading the snapshot
does not clear counters or change accepted events.

Warnings are cumulative log messages, never extra events in the full queue.
`tc-event-drop-warning-interval` sets the minimum simulation ticks between
warnings for each physical computer. Several losses share one pending warning;
cold reload preserves its throttle. Host work pressure delays the warning without
delaying the counter. If the configured Console byte allowance cannot hold the
message, it remains pending until it fits; the workspace/API still report loss.
Warning publication pays for log retention before evicting older messages.

## General events

Register declared handler names, never functions. Each `on` call is independent:
two registrations intentionally yield two deliveries. IDs belong to this
computer/run; another run's subscription/timer ID is invalid, not an alias.
Declarations alone do not subscribe to an event, even if named `monitor_touch`.
Timers and subscriptions accept exported names as strings, not function values,
private helper names or nested local names.

| Registerable event | Additional fields beyond BaseEvent |
| --- | --- |
| peripheral_attach | peripheral, peripheral_type, wire; [discovery timing](peripheral.md#events) |
| peripheral_detach | peripheral, peripheral_type, wire, reason |
| monitor_resize | peripheral, wire, wires, old_width, old_height, width, height, reason |
| monitor_touch | peripheral, wire, wires, x, y, player_index, sample_tick |
| power_restored | outage_start_tick, restored_tick |
| modem_message | peripheral, wire, wires, channel, replyChannel, message?, distance?, sent_tick; [modem semantics](modem.md#messages-and-named-handlers) |

`power_restored` occurs once after a real outage for retained subscriptions, not
cold load. No power-loss/stop/fault guest callback is required for safety. `start`,
`timer` and `signal_changed` are **not** accepted by computer.on. Logic uses
[its own subscribe](logic.md#subscriptions); timers address a named handler directly.
There is no guest on_tick.

## TimerEvent

A timer handler receives `name="timer"` plus [BaseEvent](common.md#types),
`timer_id:string`, `scheduled_tick:Tick`, `interval_ticks:integer?`,
`missed:integer`, `payload:Data?`. One-shots omit interval_ticks; omitted payload
is nil. Durations are ticks, not seconds, and `current_tick + duration` must fit
9007199254740991. Equal deadlines use creation order.

One-shots are consumed once on queue admission. Recurring overdue intervals
coalesce into one event: scheduled_tick retains the first due deadline, missed
counts skipped intervals, and the next deadline remains aligned. Already queued
recurring notifications also coalesce rather than burst after an outage. Event
`tick` is dispatch time, not its deadline. Cancel removes admitted work too.

## Run lifecycle and errors

Save commits source, not execution. Successful Apply cancels old work/output,
creates a new generation and queues `start` only if exported; explicit state remains. Failed
candidate validation preserves the old active run. Stop/fault cancels current work
but preserves recoverable source/state/logs. Reset State is a separate stopped,
confirmed editor action. [Editor workflow](../editor.md) and [lifecycle](../lifecycle.md)
cover conflicts and material-item recovery.

Ordinary errors are catchable; uncaught errors fault this run. Fatal quota/stop
signals cannot be swallowed or forged. Earlier successful effects remain, except
mandatory cleanup of this run's still-owned logic output. Outages pause callbacks,
discard transient event history, retain timers/registrations/state and request
input resync. Load does not replay startup, timers already consumed, or effects.
The exact active source stays separate from newer saved-but-unapplied source;
later callbacks reconstruct the active revision, not the latest editor save.
Legacy descriptor saves remain supported without rewriting or restarting them.
API 1, compiler representation 2 and storage 1 are unchanged. Downgrades after
saving declaration-form source are not supported by descriptor-only compilers:
keep a backup or convert and explicitly apply a legacy descriptor before downgrading.

For a complete timer/state program see [language example](language.md); for robust
error inspection see [database example](kv.md). Do not busy-loop on network/busy
failures or assume a new source revision refreshes same-tick budgets.
