# Computer Lua API v1

Normative companion to [spec.md](spec.md); shared types, errors and scheduling: [common.md](../../api/common.md). Native-language restrictions: [native-language.md](../../api/native-language.md).

## Source document

A computer contains one source document, not files. It contains exported function declarations with optional private local-function helpers:

```lua
function start(event)
  local boots = computer.getState("boots") or 0
  computer.setState("boots", boots + 1)
  computer.every(60, "sample")
end

function sample(event)
  computer.log("Sampling at tick " .. tostring(event.tick))
end
```

Exports populate the named-handler inventory. `start` is optional; it receives `{name="start", ...BaseEvent}` once on explicit Run/Apply. No function/table initialization at module scope may touch the factory, inspect the clock, register events or mutate state. Local helper functions are permitted inside handlers within the documented bounded subset. Every dispatch constructs a fresh ephemeral function environment: locals/globals/closures are not a hidden second persistence mechanism. Handler names are case-sensitive strings and must exist when registered.

Save commits source only; Run/Apply validates and activates a saved revision. Replacing a run cancels its timers/subscriptions/pending events and clears its still-owned logic outputs, then creates a new run generation and queues `start`. Explicit state survives unless the user chooses Reset State. A compile/validation failure before activation does not retire the old run. An error in the newly started handler faults that new run; it does not secretly restart the old revision.

## Identity, time, state and diagnostics

| Signature | Returns | Contract |
| --- | --- | --- |
| `computer.getID()` | `ComputerId` | Stable current entity identity; no native object |
| `computer.getLabel()` | `string` or nil | User label, not an address |
| `computer.setLabel(label)` | no values | Bounded string; nil clears; duplicate labels allowed |
| `computer.getTick()` | `Tick` | Current synchronized simulation tick |
| `computer.getLimits()` | `Limits` | Effective versioned capacities from the shared contract |
| `computer.getState(key)` | `Data` or nil | String key; defensive copy of a present value |
| `computer.setState(key, value)` | no values | Nonnil Data, validated/copied before atomic replacement |
| `computer.deleteState(key)` | boolean | True only if a present key was removed |
| `computer.log(text)` | no values | String appended to bounded per-computer diagnostic output |
| `computer.stop()` | does not return | End current run through host-controlled cleanup; cannot be defeated by `pcall` |

State keys are bounded nonempty strings; Data values can contain empty strings and false. No host filesystem, wall clock, direct signal I/O or direct computer-message methods exist.

## General event registration

```text
computer.on(event_name, handler_name) -> SubscriptionId
computer.off(subscription_id) -> boolean
```

Supported general events: `peripheral_attach`, `peripheral_detach`, `monitor_resize`, `monitor_touch`, `power_restored`. Payloads are documented by their owning capability; all include BaseEvent. Calling `on` twice creates two independent registrations intentionally. `off` is idempotent and returns false for an already removed ID; an ID belonging to another computer/run is invalid. Registrations are durable names/data, never saved functions. Registrations established by `start` survive ordinary save/load; reconstruction must not register them again.

Logic input subscriptions are created by the logic-handler API, not by `computer.on("signal_changed", ...)`. Timers likewise address a named handler directly. `start`, `signal_changed` and `timer` are not registerable general-event names. There is no guest `on_tick`; recurring timers express periodic work under limits. There is no guest stop/fault cleanup callback on which safety depends.

`power_restored` carries `outage_start_tick` and `restored_tick`. It is delivered once to retained registrations after actual power restoration, not cold load. No callback executes at power loss. General subscriptions are not automatically restricted to the peripheral that happened to exist at registration: they receive matching currently authorized devices and channel-qualified attach/detach transitions.

## Timers

```text
computer.after(delay_ticks, handler_name, payload?) -> TimerId
computer.every(interval_ticks, handler_name, payload?) -> TimerId
computer.cancelTimer(timer_id) -> boolean
```

Durations are positive integer simulation ticks, not seconds. Addition to the current tick must remain in the safe integer range. Payload is optional nonnil Data copied when registered. Deadlines are absolute; timers do not depend on game speed or real elapsed time. One-shot ID consumption occurs exactly once when its event is admitted. Cancel removes a not-yet-dispatched timer event as well as its pending deadline; false means no such pending timer/event exists in this run.

```text
-- Documentation payload shape.
TimerEvent = {
  name = "timer", -- plus BaseEvent
  timer_id = TimerId,
  scheduled_tick = Tick,
  interval_ticks = integer | nil,
  missed = integer, -- zero for a timely callback; skipped recurring intervals
  payload = Data | nil
}
```

Recurring events use the first due deadline as `scheduled_tick`, report intervals skipped beyond that delivery in `missed`, and advance to the first aligned deadline strictly after current admission time. Equal deadlines are ordered by timer creation sequence. Handler dispatch can be later than admission; `event.tick` is the dispatch tick, while `scheduled_tick` remains unchanged. Pending work stays ordered through a save. Stop, fault or source activation cancels all timers in that run.

## Recoverable and fatal errors

Approved globals include protected `pcall` for ordinary API errors. A protected call never returns a host object or the private quota/stop sentinel.

```lua
function start(event)
  local db = peripheral.find("kv_database", "red")
  if not db then
    computer.log("Connect a database with a complete red path")
    return
  end
  local ok, value = pcall(db.get, "counter")
  if ok then
    computer.log(value or "No counter yet")
  elseif type(value) == "table" then
    computer.log(value.code .. ": " .. value.message)
  else
    computer.log(tostring(value))
  end
end
```

An uncaught error faults this run, retaining source/state/logs and prior successful calls. Execution-budget failure and `computer.stop()` always leave guest execution; user protection cannot resume effects afterward. The next explicit Run starts a new run generation. Recovery is never an automatic VM fallback, reset or source rerun.

## Required contract checks

- Ordinary false/empty values versus missing state; copy isolation and invalid nested data refusal.
- Save/load after a completed state write, pending one-shot and recurring timers; no duplicated `start` or registration.
- Same-tick budget preservation, malicious loops/recursion, `pcall` quota swallowing, oversized helpers and a responsive neighboring computer.
- Power-pause/resume timing, timer cancel after queue admission, stop cleanup and active/saved source separation.
