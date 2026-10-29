# Dashboard Lua API v1

Normative companion to [dashboard-interface](spec.md). Existing shared rules remain in `openspec/api/common.md`: dot calls, explicit red/green wire, plain defensive Data, synchronous non-reentrant services, typed ordinary errors and unchanged fatal execution budgets.

## Discovery and exact methods

Peripheral type: `dashboard`. Use the existing `peripheral.find("dashboard", "red")`, `wrap(name, wire)` and `call(name, wire, method, ...)`. A wrapper retains exact identity/generation and channel; every call revalidates current authority. Saved-handler and Console calls share state and accounting, but only saved-handler programs can subscribe.

| Always-present method | Arguments | Exact returns |
| --- | --- | --- |
| `setTab(slot, definition)` | Numbered slot and complete TabDefinition | Zero |
| `getTab(slot)` | Numbered slot | One defensive TabDefinition, or one nil for an unused slot |
| `removeTab(slot)` | Numbered slot | One boolean, whether a tab existed |
| `setText(slot, id, text)` | Existing label/button ID and replacement text | Zero |
| `setEnabled(slot, id, enabled)` | Existing button ID and boolean | Zero |
| `subscribe(handler_name)` | Declared saved-program handler name | One run-bound SubscriptionId |
| `unsubscribe(subscription_id)` | ID from this run and exact dashboard/wire binding | One boolean, whether a registration existed; also cancels matching pending deliveries |
| `getLimits()` | None | One defensive effective-limit map |

When compatible factorio-charts is active, add exactly:

| Chart method | Arguments | Exact returns |
| --- | --- | --- |
| `appendSample(slot, id, values)` | Existing line-chart ID and complete series-value map | Zero |
| `setBars(slot, id, bars)` | Existing stacked-bar ID and ordered latest dataset | Zero |
| `clearChart(slot, id)` | Existing chart ID | Zero |

No separate GUI namespace, native handles, executable callback values, direct library access, global dashboard finder, timers, history-query API or arbitrary drawing/style interface is added. `getTab` returns configuration/current control text, not chart data or private render state. `getLimits` is allowed while the device is reachable but unpowered; other methods require power. Exact arities above apply; there are no implicit extra arguments or colon-call receivers.

Absent chart methods are absent from `peripheral.getMethods` and new wrapped facades, not stubs. Existing unknown-method behavior applies to `peripheral.call`. A retained Console chart-method binding fails safely after library removal. `setTab` refuses a definition containing chart widgets while the library is absent; existing retained charts can still be inspected with `getTab`, removed, or accompanied by updates to their existing base controls. Trusted save/item/blueprint restoration preserves valid chart definitions even without the library.

## Tabs and layout

`slot` is an integer from 1 through 6. Visible tabs are ordered by occupied slot; empty slots do not produce empty buttons. Zero configured tabs is valid. Removing the currently selected tab selects the lowest remaining slot for that viewer, or the unconfigured screen when none remain. Other viewers' valid selections do not change. Players, not program calls, choose the active tab.

`TabDefinition = {title=string, content=Node}`. `title` is nonempty. Strings are plain display text, not LocalisedString objects, markup programs or interpreted Factorio rich text. They retain existing string/Data allowances. Unknown fields are rejected; omitted optional values receive the defaults below, with explicit nil treated as omission. IDs and series/phase names are nonempty exact strings within the existing `identifier_bytes` allowance.

Every Node has a required `id` and `type`. IDs are unique across the entire tab, including containers; different tabs can reuse an ID. Dense child order is display order.

| `type` | Additional fields | Meaning |
| --- | --- | --- |
| `row` | `children=Node[]` | Native horizontal layout; empty children allowed |
| `column` | `children=Node[]` | Native vertical layout; empty children allowed |
| `label` | `text=string` | Wrapping native label; empty text allowed |
| `button` | `text=string`, `enabled=boolean?` | Native button; nonempty caption, enabled defaults true |
| `line` | `series=string[]`, `capacity=integer`, `format=string?` | Rolling graph; details below |
| `stacked_bars` | `phases=string[]` | Latest duration dataset; details below |

Containers use the host's normal spacing and bounded scroll area. Charts use one host-controlled design viewport, fitted into the window without guest pixel coordinates or GUI style names. Labels around a chart can provide its title, units, explanation and category descriptions. No canvas, arbitrary images, custom fonts, rich-text input, text-entry controls, chart-click events or user-defined formatting callbacks are included.

`setTab` validates the complete candidate and its capacity before publishing it. It replaces that slot, not all slots. Existing chart state survives if the same widget ID and data definition survive: for lines, identical ordered series and capacity; for bars, identical ordered phases. Text, layout position, tab title or line-format changes do not clear compatible data. Removing a chart, changing its kind/series/phases/capacity, or explicitly clearing it discards only that chart's old data. Thus applying the same startup definition is safe, while changing a data definition is an explicit reset. No implicit partial merge of an invalid definition occurs.

Structural replacements invalidate old GUI button targets and queued events for that tab. Reapplying an identical normalized definition does not cause a needless replacement. Content-only text/enablement calls do not change layout identity; enabled state is rechecked for action delivery. A missing tab/widget is `E_NOT_FOUND`; addressing the wrong widget kind is `E_ARGUMENT`. `removeTab` on an unused valid slot returns false.

## Rolling line charts

- `series` is a nonempty dense array of unique exact names. Its size cannot exceed the renderer's `colors.get_max_series()` result: the inspected renderer otherwise draws only a prefix. This is an upstream support boundary, not a new tunable cardinality policy.
- `capacity` is a required integer of at least two (the upstream graph divides by `length - 1`). Admission must reserve the complete fixed-shape rolling capacity within the dashboard allowance and existing Data bounds, rather than accept an oversized empty buffer which will fail merely by filling.
- `format` is `"number"` (default), `"percent"` or `"time"`. Percent and time use the library's built-ins, with time values in seconds and percentages already expressed in percent units. Number uses the library's existing formatter-function option bound to trusted host `tostring`; no guest formatter, formatting DSL, monkeypatch or custom renderer is introduced.
- `values` is a plain map containing exactly the configured series names, each with a finite number. Extra/missing series, invalid numbers or nonfinite derived sums/ranges are rejected atomically. A rejected append cannot evict the old sample or change running totals.
- Each accepted call appends one whole vector in synchronized order, advancing one position. At capacity it evicts exactly the oldest vector. All series advance together, including zero values. No samples are invented for closed windows, stopped programs, power gaps or missed timer events.
- The horizontal position represents sample order. Callers choose sampling cadence using existing timers; there is no timestamp input, irregular-time interpolation, real-time X-axis guarantee or multiresolution selector. Samples from multiple writers follow accepted-call order.
- `clearChart` resets samples/index/totals, preserving definition and reserved capacity. `setBars` on a line widget is invalid.
- Line colors/order follow the unchanged library, including changes caused by its sum ordering. Any native legend must use that same returned ordering/colors, not promise independently stable colors. Empty or single-sample history may show no line; present honest empty/collecting status rather than manufacturing points.

## Snapshot duration bars

`phases` is a nonempty dense array of unique names, in bottom-to-top stack order. `bars` is a dense ordered array of plain maps, one per bar, each containing exactly these names with finite nonnegative durations in seconds. Entries and their padded total must remain finite. An empty array clears the dataset; zeros are valid. A new successful `setBars` replaces the complete previous dataset rather than recording a history.

Pass this data to the library's existing `deliveries`, `phase_order` and `phase_colors` options. Use its supplied palette in phase order and its unmodified time axis. Do not interpret counts as seconds, add numeric/category axis formatting, draw custom bar labels or reorder bars. Ordinary surrounding labels can describe input order. Bar icons, hatching, overlays and tooltips are not required by this version.

The fixed host design viewport and upstream spacing must produce positive bar widths; expose the supported maximum bar count in `getLimits` and reject a larger dataset. The shared byte/Data/work ceilings can refuse a smaller dataset too. This geometry check is derived from the unmodified renderer, not a guessed performance cap. `appendSample` on this widget is invalid; `clearChart` removes its dataset only.

## Shared retained accounting and errors

`getLimits` includes existing common limits plus:

- `dashboard_tabs=6`.
- `dashboard_state_bytes`, equal to the existing effective `state_bytes` allowance (currently 65,536 accounted bytes).
- With the library only: `chart_line_series`, derived from the upstream renderer; and `chart_bar_entries`, derived from its positive-width domain at the fixed host design viewport.

This allowance is per physical dashboard, shared across all six slots, both wires and all writers; it is not renewed per call or viewer. Account the complete layout/control text, snapshot bar data, line-buffer reservation including running totals, and device-owned model metadata using the existing Data accounting convention. Do not describe accounted bytes as calibrated native Lua heap bytes. Existing structural and transport constraints remain effective; this feature does not widen them or add a per-widget/series count setting. Finite arithmetic and native renderer-domain checks remain required.

Validate and admit candidate state and return values before mutation. Temporary copies and fan-out still consume their existing operation/work/queue allowances. Rendering and GUI storage have a separate host lifetime and must be bounded by admitted model size, actual open sessions and existing maintenance admission; they are not smuggled into guest Data or an unbounded private queue. Limits lowered below accepted state retain it and permit reads/removal/non-growing changes, not silent truncation.

| Condition | Error/behavior |
| --- | --- |
| Wrong arity, unknown fields, invalid Data shape, wrong widget kind, duplicate IDs or series names | `E_ARGUMENT`, unchanged model |
| Invalid slot, capacity, format, nonfinite numeric input/derived arithmetic or renderer numeric domain | `E_RANGE`, unchanged model |
| Missing addressed tab/widget | `E_NOT_FOUND` (except `getTab` nil and `removeTab` false) |
| Chart-containing definition without the library | `E_UNSUPPORTED`, previous tab intact |
| Unsupported/corrupt saved schema | `E_UNSUPPORTED`, retain recoverable data and refuse unsafe activation |
| Shared retained capacity exceeded | `E_CAPACITY`, old state/reservations intact |
| Existing Data/call size envelope exceeded | Existing `E_LIMIT`, no partial update |
| Subscription in Console or for an undeclared handler | Existing handler/Console refusal |
| Lost identity/path/scope, pending proof or no power | Existing peripheral authority/power errors |
| Guest work/allocation exhausted | Existing fatal `E_BUDGET`; no credit reset or weaker safety mode |
| Native rendering failure/maintenance contention | Visible chart error/pending state; accepted application model retained |

Error wording is not API. Existing authority/budget precedence is preserved; the API does not promise semantic-error precedence after admission has failed.

## Buttons and subscriptions

`subscribe(handler_name)` explicitly registers this computer run for every button in this dashboard on this wire. Each call makes a distinct registration, including intentionally registering on both wire colors. A click is delivered once per valid subscription, not once per physical route. Merely configuring or viewing a dashboard does not subscribe. All valid subscribers receive events; the last writer has no special role.

A scheduled `dashboard_click` event carries the existing BaseEvent fields plus:

| Field | Meaning |
| --- | --- |
| `peripheral` | Exact dashboard peripheral name |
| `wire` | This subscription's `red` or `green` channel |
| `subscription_id` | Recipient's run-bound registration |
| `tab` | Numbered tab slot |
| `button` | Stable widget ID |
| `player_index` | Activating player |

Only a normal left-button activation of an enabled native button is supported initially. Event `tick` is the activation tick; normal scheduled dispatch may occur later. A private layout-generation token accompanies the delivery for revalidation but is not guest authority. Validate the actual owned element/parent chain, current player session, exact physical identity, selected visible tab, permission, reach, enabled state and power before accepting an activation. Revalidate layout identity, subscription/run, computer path and applicable player/device authority before delivering queued work; an unavailable or unprovable target never executes a stale action.

No callback runs inside the GUI handler. Use the existing scheduled subscriptions/events and pressure policy, including existing recipient overflow fault/cleanup behavior; one recipient's refusal/fault cannot cancel other eligible registrations. Stopped/unpowered computers do not accumulate new transient clicks. Stop, activation replacement, cancellation and definitive detachment retire affected registrations/deliveries without erasing dashboard content. One subscription on two alternative physical paths still gets one event; two explicit subscriptions can intentionally get two.

## Lifecycle and optional dependency

- Ordinary save/reload preserves model, ring order/reservation and legitimate pending delivery state without startup replay. Revalidate native GUI/render sessions during gameplay, not `on_load`.
- Closing windows or stopping/disconnecting a producer does not clear data. Unpowered dashboards show identity/status and refuse active controls/services; power restoration does not invent samples or clicks.
- Mining retains definitions/history/latest bars in a versioned data-bearing item; replacement receives a new identity without subscriptions, viewers or render resources. Snapshot metadata must fit in addition to the maximum accepted content. Malformed/unsupported snapshots remain recoverable rather than silently replaced with an empty panel.
- Blueprints/clones/settings copy transfer definitions only. New devices start with empty charts. Existing targets preserve only their own compatible chart data through the ordinary `setTab` rule, never the source's samples.
- Dependency removal preserves model/data and releases native presentation through host-owned cleanup that does not require the absent library. Existing chart areas show an unavailable message. Reinstallation rebuilds compatible presentation during gameplay; never rerun the producer to reconstruct history.

## Minimal base program

The maintained executable example is `examples/dashboard-program.lua`; its native-input evidence is recorded separately from this contract.

```lua
return {
    api_version = 1,
    handlers = {
        start = function(event)
            local panel = peripheral.find("dashboard", "red")
            assert(panel, "Connect a powered Dashboard on red")
            panel.setTab(1, {
                title = "Overview",
                content = {type = "column", id = "root", children = {
                    {type = "label", id = "status", text = "Ready"},
                    {type = "button", id = "ack", text = "Acknowledge"}
                }}
            })
            panel.subscribe("clicked")
        end,
        clicked = function(event)
            local panel = peripheral.wrap(event.peripheral, event.wire)
            if event.tab == 1 and event.button == "ack" then
                panel.setText(1, "status", "Acknowledged")
            end
        end
    }
}
```

The maintained `examples/dashboard-charts.lua` inspects the method inventory, demonstrates mixed tabs, wraps its configured history before viewing and submits a latest duration dataset. Lines use sample-order X positions; duration bars use seconds, not arbitrary category/count axes. Native and connected-peer acceptance is recorded separately.
