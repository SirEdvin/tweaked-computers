# Logic handler Lua API v1

Normative companion to [spec.md](spec.md). Obtain as `peripheral.find("logic_handler", network_wire)`. The discovery wire and the input-selection argument are separate concepts: a computer can reach the middle port over red while reading the input port's green circuit.

## Methods

| Signature | Returns | Meaning |
| --- | --- | --- |
| `io.readSignal(input, signal)` | Int32 | `input` is red/green/both; absent signal gives 0 |
| `io.readSignals(input)` | `Signal[]` | Selected native input snapshot, sorted, with zero totals omitted |
| `io.getInputStatus()` | table | `{red_connected=boolean, green_connected=boolean}` for actual input connectors |
| `io.getOutput()` | `Signal[]` | This handler's configured contribution only, not external signals on its output network |
| `io.setOutput(signals)` | no values | Atomically replace the entire shared output bank and transfer its last-writer ownership |
| `io.clearOutput()` | no values | Equivalent to `setOutput({})`; no separate color bank |
| `io.subscribe(options, handler_name)` | SubscriptionId | Create a named input-change subscription for this computer/run/binding |
| `io.unsubscribe(subscription_id)` | boolean | Remove this run's subscription and its queued, undispatched samples; false if already absent |
| `io.getLimits()` | table | `signal_slots`, `subscriptions`, `filter_signals`, `sample_interval_ticks` (1), `notification_latency_ticks`, plus shared caps |

Signal identity is the full type/name/quality tuple. Ordinary reads/writes reject wildcard pseudo-signals. Missing quality is normalized to `normal`; returned identities always include all three fields. Counts must be exact signed 32-bit integers. No string/float coercion is accepted.

Supported ordinary types are `item`, `fluid`, `virtual` and `recipe`. A recipe
name identifies an installed recipe prototype, including mod-added recipes,
independently of its products or research status. Same-named item and recipe
signals do not merge. This applies to reads, output banks and subscription filters.
Native snapshot pre-admission includes the installed recipe prototype registry.
Other signal categories remain unsupported. Existing work/maintenance caps remain binding;
two-color sampling can refuse when the complete envelope does not fit.

`both` sums the red and green input values by full identity and wraps to signed 32-bit using `((sum + 2147483648) % 4294967296) - 2147483648`. This does not physically connect colors or change discovery rules. Negative counts are legal. Output arrays must have unique normalized identities; duplicates are rejected before mutation, rather than silently added. Zero-valued entries are removed in the canonical stored bank. An empty bank emits no contribution.

Output is one set mirrored to both output connectors. Other devices can contribute different totals on those networks; getOutput does not report those totals. Externally wiring input and output together can deliberately create feedback, but there is no internal feedthrough between input, middle and output.

## Subscriptions

```text
-- Documentation options.
SignalSubscriptionOptions = {
  input = "red" | "green" | "both", -- required
  signals = { SignalId, ... } | nil, -- nil means all; nonnil must be nonempty/unique
  initial = boolean | nil           -- default false
}
```

`handler_name` must name a handler in the active document. The registration persists by name/validated data, never by a saved function. It is scoped to the wrapper's selected discovery channel; losing that binding revokes it. A new path on another color does not silently transfer the subscription.

The registration uses the most recent authoritative sample as its baseline. With initial=false, notify only when selected values or selected input-connectivity change. With initial=true, enqueue an initial snapshot on the next sampling tick; `previous` is empty and `initial=true` distinguishes it from a delta. Filters apply to complete identities, not name substrings; a nonzero-to-absent change remains observable as zero in `changes`.

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

Only selected colors are present in connectivity maps. Initial events use false selected connectivity in previous_connected. `resync=true` denotes restoration after a power interruption, not a replay of every unobserved transition. `previous` is the most recent successfully admitted sample, or the registration baseline if none has been admitted; queue admission advances this baseline, not later callback dispatch. A power interruption discards queued transient samples for the affected computer/subscription, so a resync's previous snapshot may describe a sample whose callback was discarded. Current is the newly selected sample, and resync explicitly marks that discontinuity. All collections are copied and canonical. Empty changes with changed connectivity is a valid event.

Factorio reports circuit values from its native circuit-update state, documented as previous-tick signals. `sample_tick` identifies observation time; it does not assert that a newly written output can be read by another device immediately. `event.tick` identifies callback dispatch. No within-tick transient detection or recursively triggered signal callback is promised. When powered and within the supported envelope, sampling is once per actual simulation tick, not once per arbitrary number of scheduler dispatches.

## Output ownership and failure

Every successful setOutput/clearOutput records the writing computer's identity, active run generation and bound network color. The bank is a single ownership unit. A subsequent successful write replaces that ownership; a failed write does not. Stop, fault, computer/handler power loss, removal, force/surface change or loss of the owner's selected path clears its still-owned output through host cleanup.

Computer A stopping must not clear a bank written more recently by B. Clear applies before any later unauthorized guest call and within the published topology/fail-safe envelope for externally observed wiring changes. Retaining the same bank across ordinary load is allowed only with retained valid ownership; host function reconstruction neither republishes the write nor creates a new owner. Clones/new placement have empty output and no owner.

A writer's shared state/KV updates and monitor image are not rolled back when its output is cleared. Configurator-applied factory settings remain in place. This is fail-safe signal output, not a general factory-state transaction.

## Example: threshold control

```lua
return {
  api_version = 1,
  handlers = {
    start = function(event)
      local io = peripheral.find("logic_handler", "red")
      if io then
        io.subscribe({
          input = "red",
          signals = { { type = "item", name = "iron-plate", quality = "normal" } },
          initial = true
        }, "changed")
      end
    end,
    changed = function(event)
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
  }
}
```

The filter above selects one full identity, so its current snapshot has at most one entry. A second computer can receive these circuit signals through its own logic handler; there is no direct computer-message API.

Required cases: each input color/both; disconnected versus zero input; int32 boundaries/wrap; different qualities and same-name different types; duplicate output refusal; native propagation latency; subscription initial/filter/removal/resync; every-tick changed and unchanged samples; full queues; multiple writers; stale binding and cold ownership; all rotations and externally wired feedback.
