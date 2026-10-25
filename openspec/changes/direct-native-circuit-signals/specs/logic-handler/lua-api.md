# Logic Handler Lua API: direct native circuits

Companion to this change's `spec.md`. Replaces the canonical-signal, inventory-limit and cached-observation portions of the existing Logic Handler API. Method names, dot-call arity, explicit input/discovery colors and source `api_version = 1` remain unchanged. Record shape/order changes are intentional compatibility changes, not a new language ABI.

## Signal values

`Signal = {signal = SignalID, count = Int32}`. `SignalID` follows Factorio 2.0.77's native circuit identity: native defaults apply when type or quality is absent. Readers must not assume those fields exist. The effective identity is `(type or "item", name, quality or "normal")`; interpreting this identity does not modify the record.

Bulk input results preserve native records and their native sequence. No lexical, count-based or cross-call stable ordering is promised. The API does not fill missing fields, revalidate native records, merge signals or recalculate counts. An absent native inventory is exposed as `{}` to preserve the array return type. All signal categories returned by the engine remain available, not only the former item/fluid/virtual/recipe subset.

User-supplied identities accept the same optional defaults. Invalid inputs, wildcard pseudo-signals and malformed writes still fail. Native prototype/quality existence and numeric/index domains govern caller validation; no mod-defined prototype-name length or signal/filter/output count is substituted for them.

## Methods

| Signature | Returns and behavior |
| --- | --- |
| `io.readSignal(input, signal)` | Int32 from a fresh selected native input read; absent identity gives zero. |
| `io.readSignals(input)` | Complete native `Signal[]` from this call; no cache, sorting, normalization or pagination. |
| `io.getInputStatus()` | `{red_connected=boolean, green_connected=boolean}` from current physical INPUT connectors. |
| `io.getOutput()` | Fresh `Signal[]` view of the handler's own native output configuration, not external network totals; no ordering/default-field guarantee. |
| `io.setOutput(signals)` | No values. Validate a dense caller array, then atomically replace the shared native bank and writer. Native capacity only, no mod slot ceiling. |
| `io.clearOutput()` | No values. Empty native bank replacement under the existing ownership contract. |
| `io.subscribe(options, handler_name)` | Run/binding-scoped subscription ID. Validate and apply registration-count admission here only. |
| `io.unsubscribe(subscription_id)` | Boolean; remove the matching registration and its queued callbacks, preserving existing binding checks. |
| `io.getLimits()` | Retained applicable registration/runtime policy and timing fields. Removed `signal_slots`, `filter_signals`, `active_logic_handlers` and `aggregate_owned_outputs` are absent, not zero, infinity or replacement knobs. Shared Data fields do not describe a circuit-inventory capacity. |

Input is exactly `"red"` or `"green"`; no default or `"both"`. The discovery channel remains independent of the input selector. Output is one bank shared across both output connectors. Zero output entries contribute nothing. Duplicate effective identities, including omitted/explicit default aliases, are rejected before mutation. Ordinary rejected writes preserve bank and owner; unexpected engine errors retain the existing rollback/recovery behavior.

## Subscriptions

`options = {input = "red" | "green", signals = {SignalID, ...} | nil, initial = boolean | nil}`.

Omitted filters select all signals; supplied filters remain nonempty and unique, without a filter-cardinality ceiling. Existing per-computer and aggregate subscription counts are admission policy, checked only when registering. There is no separate sampled-device quota. Invalid options/handlers and admission refusal leave accepted registrations unchanged.

Registration reads a fresh baseline. Each powered sampling tick obtains a fresh native observation. Retain only comparison history and accepted delivery data; neither can answer a direct API read. Order-only changes and omitted/explicit default aliases do not create notifications. Existing initial, disappearance, connectivity and power-resync behavior remains.

`signal_changed` keeps its existing envelope and fields: `subscription_id`, `peripheral`, `wire`, `input`, `sample_tick`, `initial`, `resync`, `previous`, `current`, `changes`, `previous_connected`, `connected`. `previous/current` are complete selected native signal arrays. `changes` contains `{signal=SignalID, previous=Int32, current=Int32}` with disappearance represented by current zero. None of these arrays has a sorting guarantee; their signal IDs do not gain synthetic default fields.

Queue admission advances the baseline, not callback execution. Each consumer's delivered tables are isolated from other consumers and retained baselines. Native signal payload size does not trigger generic Data byte/node/entry ceilings. Existing queue entry/envelope backlog limits and fault-on-overflow behavior remain; no drop-newest or continuation policy is introduced. Explicit application-state/KV storage remains subject to that storage API's existing rules.

## Lifetime and compatibility

Power, authority, stop/fault cleanup, last-writer identity, explicit red/green roles and native propagation timing do not change. Save/load retains accepted subscriptions/events and native output ownership without querying during load, replaying startup or republishing output. Earlier expanded records remain readable by effective identity; do not rewrite every saved observation or discard accepted work merely to adopt the new shape.

Replace positional assumptions with identity lookup, using defaults locally:

```lua
local signals = io.readSignals("red")
for _, entry in ipairs(signals) do
  local s = entry.signal
  if (s.type or "item") == "item" and s.name == "iron-plate"
      and (s.quality or "normal") == "normal" then
    computer.log(tostring(entry.count))
  end
end
```

The loop remains ordinary metered guest code. Native access is not an unlimited guest computation or storage promise.
