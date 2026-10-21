# Computer Lua API v1

Normative companion to [spec.md](spec.md); shared types, errors and scheduling: [common.md](../../api/common.md). Native-language restrictions: [native-language.md](../../api/native-language.md).

## Source document

A computer contains one source document, not files. It accepts declaration-form programs or the legacy literal returned descriptor below. The [program-source companion](../program-source/lua-api.md) defines the declaration-only top level, private helpers, export scope and ordinary guarded direct calls; API 1 is implicit for that form.

This section describes saved-program mode. The independent [Console](../console-shell/lua-api.md) accepts bounded statements and expressions without a descriptor, but cannot borrow handlers, register background work or change this source shape. Its retained scratch graph and symbolic bindings do not make callback locals, closures or ordinary Data durable.

```lua
return {
  api_version = 1,
  handlers = {
    start = function(event)
      local boots = computer.getState("boots") or 0
      computer.setState("boots", boots + 1)
      computer.every(60, "sample")
    end,
    sample = function(event)
      computer.log("Sampling at tick " .. tostring(event.tick))
    end
  }
}
```

In the legacy form, `handlers` maps unique names to function declarations; declaration-form exports populate the same named inventory. `start` is optional; it receives `{name="start", ...BaseEvent}` once on explicit Run/Apply. No module-level initialization may touch the factory, inspect the clock, register events or mutate state. Local helpers follow the selected form's lexical rules. Every dispatch constructs fresh ephemeral functions and locals: closures are not hidden persistence. Handler names are case-sensitive strings and must exist when registered; direct calls do not create another run or synthesize an event.

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

Supported general events: `peripheral_attach`, `peripheral_detach`, `monitor_resize`, `monitor_touch`, `power_restored`, `modem_message`. Payloads are documented by their owning capability; all include BaseEvent. Calling `on` twice creates two independent registrations intentionally. `off` is idempotent and returns false for an already removed ID; an ID belonging to another computer/run is invalid. Registrations are durable names/data, never saved functions. Registrations established by `start` survive ordinary save/load; reconstruction must not register them again.

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
return {
  api_version = 1,
  handlers = {
    start = function(event)
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
  }
}
```

An uncaught error faults this run, retaining source/state/logs and prior successful calls. Execution-budget failure and `computer.stop()` always leave guest execution; user protection cannot resume effects afterward. The next explicit Run starts a new run generation. Recovery is never an automatic VM fallback, reset or source rerun.

## Expanded Lua base globals

The complete [base-global contract](base-globals-api.md) is normative alongside the inventory below, including argument/result adjustment, ordinary and fatal errors, retained-name recovery and compatibility exclusions. It extends rather than replaces the computer methods, events and scheduling above.

The same guarded globals are available in declaration/descriptor callbacks and Console. `_VERSION` is the fixed string `Lua 5.2`, a language-family label rather than unrestricted standard-library compatibility. No new namespace members, host facilities, Data domains or persistence schema are introduced; API 1/compiler 2/storage 1 remain unchanged.

| Signature | Result and contract |
| --- | --- |
| `print(...)` | No values; one Console entry, safe tostring arguments joined by tabs, no added newline. Zero arguments append an empty entry. |
| `rawget(t, key)` | One identical stored value, including nil; explicit nil/NaN lookup returns nil. Guest-owned plain table only. |
| `rawset(t, key, value)` | Identical t; nil deletes. Existing indexed-write ownership/key/value/growth/work/allocation admission precedes mutation. |
| `rawlen(value)` | Byte-string length or guest-owned table's native border, not map cardinality. |
| `rawequal(a, b)` | One native raw-equality boolean for approved guest values; identity is not copied. Bounded string validation/comparison is paid first. |
| `unpack(t, i?, j?)` | Identical bounded table.unpack function; defaults 1/#t, i=1..1025, j=0..1024, at most 128 results with nil holes. |
| `xpcall(fn, handler, ...)` | true,exact results on success; false,first handler result on ordinary failure (one nil for no result). |

Raw helpers require every positional argument, including explicit nil where supported. Additional arguments follow native handling and still pay call tuple bounds. `rawset` refuses nil/NaN keys, preserves false/aliases/reference keys/transient self-reference, and permits replacement/deletion at full capacity when otherwise admitted. Any refused write leaves all aliases unchanged. `rawget`/`rawset`/`rawlen` refuse protected namespaces, facades and foreign tables. `rawequal` may compare authentic facades/functions without exposing their contents. Ordinary Data still refuses cycles/functions/reference keys; Console retains only its existing supported graph and symbolic peripheral identities.

Print uses stable descriptions (table, guest function, API handle or approved callable label), never host addresses or recursive inspection. Both unpack aliases have description `table function`. Saved output goes through guarded computer.log; Console retains `Shell #<command> output: ` attribution and expression-result formatting, with no entry for zero-result expressions. Complete formatting/allocation and retention work precede append/eviction; tuple/string/console/retention limits remain unchanged. Refusal produces no partial entry. Earlier successful output survives later faults. Displayed tabs become single spaces, without changing raw bytes, selection or Follow-off behavior. No chat/stdout/logfile/monitor destination is added; computer.log keeps its one-string/no-results signature.

Both xpcall operands must be approved functions. Forward exactly the supplied trailing arguments, retaining nil holes and aliases. Status counts toward tuple width. On ordinary failure pass exactly one safe error to the handler: guest references retain identity; host-origin records become defensive snapshots. Native message-handler re-entry is bounded by existing work/depth limits; exact error-in-handler wording is not promised. Fatal work/allocation/depth/tuple exhaustion and saved-program stop bypass nested pcall/xpcall and never reach guest message code as private control values. A fatal function suppresses the handler; a fatal handler suppresses later handlers/effects. Console still cannot stop the program. Earlier state/printing/peripheral effects are not rolled back.

New names are reserved top-level public/private declarations and immutable Console globals. Ordinary lexical locals/parameters and legacy descriptor handler keys retain their rules. Old active-name collisions fault on synchronized reconstruction, retaining exact source/state; loading does not execute or rewrite source. Rename and explicitly Save/Run. Old Console root collisions report named E_UNSUPPORTED before effects and retain their graph until explicit confirmed Reset Shell; nested fields are ordinary data.

Acceptance program (Validate/Save must emit nothing; activation emits the two raw entries once; ordinary reload must not replay them):

```lua
function start(event)
  local values = table.pack(false, nil, 3)
  assert(unpack == table.unpack)
  print(_VERSION, unpack(values, 1, values.n))
  local t = {}
  assert(rawequal(rawset(t, "ready", false), t))
  assert(rawget(t, "ready") == false)
  assert(rawlen("hello") == 5)
  local ok, message = xpcall(function()
    error("sample failure")
  end, function(problem)
    return "handled: " .. tostring(problem)
  end)
  assert(ok == false)
  print(message)
end
```

Expected raw entries: `Lua 5.2\tfalse\tnil\t3` and `handled: sample failure`.

## Required contract checks

- Ordinary false/empty values versus missing state; copy isolation and invalid nested data refusal.
- Save/load after a completed state write, pending one-shot and recurring timers; no duplicated `start` or registration.
- Same-tick budget preservation, malicious loops/recursion, `pcall` quota swallowing, oversized helpers and a responsive neighboring computer.
- Power-pause/resume timing, timer cancel after queue admission, stop cleanup and active/saved source separation.
