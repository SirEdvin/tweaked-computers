# Logic handler Lua API v1

Normative companion to [spec.md](spec.md). Obtain as `peripheral.find("logic_handler", network_wire)`. The discovery wire and the input-selection argument are separate concepts: a computer can reach the middle port over red while reading the input port's green circuit.

## Methods

| Signature | Returns | Meaning |
| --- | --- | --- |
| `io.readSignal(input, signal)` | Int32 | `input` explicitly selects red or green; absent signal gives 0 |
| `io.readSignals(input)` | `Signal[]` | Complete fresh selected native input, preserving order and optional fields |
| `io.getInputStatus()` | table | `{red_connected=boolean, green_connected=boolean}` for actual input connectors |
| `io.getOutput()` | `Signal[]` | This handler's configured contribution only, not external signals on its output network |
| `io.setOutput(signals)` | no values | Atomically replace the entire shared output bank and transfer its last-writer ownership |
| `io.clearOutput()` | no values | Equivalent to `setOutput({})`; no separate color bank |
| `io.subscribe(options, handler_name)` | SubscriptionId | Create a named input-change subscription for this computer/run/binding |
| `io.unsubscribe(subscription_id)` | boolean | Remove this run's subscription and its queued, undispatched samples; false if already absent |
| `io.getLimits()` | table | `subscriptions`, `sample_interval_ticks` (1), `notification_latency_ticks`, plus retained shared policy; no signal/filter/device/bank count caps |

Effective signal identity is `(type or "item", name, quality or "normal")`.
Caller writes/filters reject wildcard pseudo-signals. Reads trust engine-produced
records, preserving native sequence and omitted fields without validation,
normalization, sorting or a stable-order guarantee. Counts supplied by callers must
be exact signed 32-bit integers; no string/float coercion is accepted.

Supported native types are `item`, `fluid`, `virtual`, `recipe`, `entity`,
`space-location`, `asteroid-chunk` and `quality`. A recipe
name identifies an installed recipe prototype, including mod-added recipes,
independently of its products or research status. Same-named item and recipe
signals do not merge. This applies to reads, output banks and subscription filters.
Every direct read and registration baseline queries the selected native input.
There is no mod-defined name, signal, filter or output-slot ceiling. Native output
index/count domains still apply; fixed service/dispatch work remains metered.
Native graph transfer bypasses generic Data limits, not guest execution or explicit
state/KV/Console persistence. Native cost is not a calibrated universal heap/tick bound.

Input selectors are mandatory red or green. Missing, `both` and invalid values fail before registration; no default, compatibility alias or color combination exists. Each read retains native signed32 semantics on the selected circuit. Negative counts are legal. Output arrays must have unique effective identities, including omitted/explicit default aliases; duplicates fail before mutation. Zero-valued entries are omitted. The native section is the source of truth, not a retained output mirror. An empty bank emits no contribution.

Output is one set mirrored to both output connectors. Other devices can contribute different totals on those networks; getOutput does not report those totals. Externally wiring input and output together can deliberately create feedback, but there is no internal feedthrough between input, middle and output.

## Subscriptions

```text
-- Documentation options.
SignalSubscriptionOptions = {
  input = "red" | "green", -- required, never defaulted or combined
  signals = { SignalId, ... } | nil, -- nil means all; nonnil must be nonempty/unique
  initial = boolean | nil           -- default false
}
```

`handler_name` must name a handler in the active document. The registration persists by name/validated data, never by a saved function. It is scoped to the wrapper's selected discovery channel; losing that binding revokes it. A new path on another color does not silently transfer the subscription.

Registration reads a fresh baseline, never a cached observation. Existing per-computer
and aggregate registration counts are checked only when registering. Filters have
no cardinality cap; non-growing native-array edits can construct a large request.
With initial=false, notify only on effective identity/count or connectivity changes,
not ordering or explicit-default differences. With initial=true, enqueue next sample
with empty previous. A disappearance remains observable as zero in changes.

```text
-- Documentation event; also includes BaseEvent.
SignalChanged = {
  name = "signal_changed",
  subscription_id = SubscriptionId,
  peripheral = PeripheralName,
  wire = Wire,                      -- computer discovery channel
  input = InputSelection,
  sample_tick = Tick,                -- tick at which the engine snapshot was read
  initial = boolean,
  resync = boolean,
  previous = { Signal, ... },
  current = { Signal, ... },
  changes = {
    { signal = SignalId, previous = Int32, current = Int32 }, ...
  },
  previous_connected = { red = boolean | nil, green = boolean | nil },
  connected = { red = boolean | nil, green = boolean | nil }
}
```

Only selected colors are present in connectivity maps. Initial events use false selected connectivity in previous_connected. `resync=true` denotes restoration after a power interruption, not replay. `previous` is the most recent successfully admitted sample, or the registration baseline; queue admission advances it, not callback dispatch. Power interruption discards queued transient samples, so previous may describe a discarded callback's observation. Collections preserve optional fields and have no sorting guarantee; delivered events are isolated from baselines and other subscribers. Empty changes with changed connectivity is valid. Native graph size does not consume generic payload capacity, but queue entries and envelope bytes remain bounded with existing fault-on-overflow behavior.

Factorio reports circuit values from its native circuit-update state, documented as previous-tick signals. `sample_tick` identifies observation time; it does not assert that a newly written output can be read by another device immediately. `event.tick` identifies callback dispatch. No within-tick transient detection or recursively triggered signal callback is promised. When powered and within the supported envelope, sampling is once per actual simulation tick, not once per arbitrary number of scheduler dispatches.

## Output ownership and failure

Persisted legacy subscriptions with `both`, missing or invalid input fault the run
before queued callback dispatch, clear its still-owned output and discard pending
callbacks. Update source to select red or green and restart; never translate wires
or replay effects on load. Valid single-color load retains exact identities.

Every successful setOutput/clearOutput records the writing computer's identity, active run generation and bound network color. The bank is a single ownership unit. A subsequent successful write replaces that ownership; a failed write does not. Stop, fault, computer/handler power loss, removal, force/surface change or loss of the owner's selected path clears its still-owned output through host cleanup.

Computer A stopping must not clear a bank written more recently by B. Clear applies before any later unauthorized guest call and within the published topology/fail-safe envelope for externally observed wiring changes. Retaining the same bank across ordinary load is allowed only with retained valid ownership; host function reconstruction neither republishes the write nor creates a new owner. Clones/new placement have empty output and no owner.

A writer's shared state/KV updates and monitor image are not rolled back when its output is cleared. Configurator-applied factory settings remain in place. This is fail-safe signal output, not a general factory-state transaction.

## Example: threshold control

```lua
function start(event)
  local io = peripheral.find("logic_handler", "red")
  if io then
    io.subscribe({
      input = "red",
      signals = { { type = "item", name = "iron-plate", quality = "normal" } },
      initial = true
    }, "changed")
  end
end

function changed(event)
  local io = peripheral.wrap(event.peripheral, event.wire)
  if not io then return end
  local count = 0
  for _, entry in ipairs(event.current) do
    count = entry.count
  end
  local enable = 0
  if count < 100 then enable = 1 end
  io.setOutput({
    { signal = { type = "virtual", name = "signal-A", quality = "normal" }, count = enable }
  })
end
```

The filter above selects one full identity, so its current snapshot has at most one entry. A second computer can receive these circuit signals through its own logic handler; there is no direct computer-message API.

Required cases: red and green separately with both physical wires connected; missing/both/invalid selector refusal; disconnected versus zero input; native int32 boundaries/wrap; different qualities and same-name different types; duplicate output refusal; native propagation latency; subscription initial/filter/removal/resync; every-tick changed and unchanged samples; full queues; multiple writers; stale binding, legacy fault without queued replay and valid cold ownership; all rotations and externally wired feedback.
