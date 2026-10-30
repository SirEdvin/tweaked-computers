# Dashboard API

Type: `dashboard`. Connect its electricity-free Network socket to a computer on explicit
`"red"` or `"green"`. Use dot calls on `peripheral.find("dashboard", "red")` or
`peripheral.wrap(name, wire)`; calls revalidate exact identity, scope and path.
See [building and opening a Dashboard](../dashboard.md) and the complete
[shared rules](common.md). Multiple writers share one device model; no writer
owns the window or becomes an implicit button recipient.

## Base methods

| Method | Exact return values |
| --- | --- |
| `setTab(slot, definition)` | No values |
| `getTab(slot)` | One defensive definition, or one nil |
| `removeTab(slot)` | One boolean: did a tab exist? |
| `setText(slot, id, text)` | No values |
| `setEnabled(slot, id, enabled)` | No values |
| `subscribe(handler_name)` | One run-bound subscription ID |
| `unsubscribe(subscription_id)` | One boolean; cancels pending matching clicks too |
| `getLimits()` | One defensive effective-limit map |

Slots are integers **1–6**. Zero configured tabs and empty containers are valid.
Visible tabs follow occupied slot order; removing a selected tab selects the
lowest remaining slot for that viewer. Programs do not choose a viewer's tab.
`getTab` returns current configuration/control text, not chart history or native
handles. All methods revalidate their current non-power identity/scope/path requirements.

### Complete definitions

`definition = {title=string, content=Node}`. Titles are nonempty plain text.
Every node has a nonempty `id` unique within that tab and a `type`:

| Type | Fields beyond `id` and `type` |
| --- | --- |
| `row`, `column` | Dense `children=Node[]`, including an empty array |
| `label` | `text=string`, including empty text |
| `button` | Nonempty `text=string`, optional boolean `enabled` (default true) |
| `line` | Dense unique nonempty `series=string[]`, integer `capacity`, optional `format` |
| `stacked_bars` | Dense unique nonempty `phases=string[]` |

Chart node kinds require the optional library for a new definition. Unknown
fields, duplicate IDs and unsupported widgets refuse the **entire** replacement.
Text is literal, not rich text, executable markup or native style names. IDs and
series/phase names use the existing `identifier_bytes` allowance.

`setTab` replaces only one slot. An identical normalized definition does not
rebuild it. Compatible chart IDs retain their own data: lines require the same
ordered series and capacity; bars require the same ordered phases. Changing a
title, layout position, control text or line format does not erase compatible
history. Removing a chart or changing its data definition resets only that chart.
A structural replacement invalidates old button targets and pending clicks for
that tab. `setText` and `setEnabled` update a leaf without changing layout identity,
selected tabs, scroll or unchanged text selection. Wrong widget kind is
`E_ARGUMENT`; an absent tab/widget is `E_NOT_FOUND`.

## Scheduled buttons

Only an ordinary left-click on an enabled, currently visible owned native button
is an activation. Normal opening, tab selection and closing never emit a click.
Each successful `subscribe(handler_name)` registers this saved program run on
this exact Dashboard and wire. Two registrations intentionally receive two events;
redundant physical paths do not multiply a registration. An unsubscribed computer
receives none, including one that configured the controls. **Console cannot
subscribe or unsubscribe.** `computer.on` does not expose an unrestricted shortcut.

The scheduled `dashboard_click` event contains normal BaseEvent fields and:

| Field | Meaning |
| --- | --- |
| `peripheral` | Exact Dashboard identity |
| `wire` | This registration's `red` or `green` channel |
| `subscription_id` | Recipient's run-bound registration |
| `tab` | Numbered slot |
| `button` | Exact widget ID |
| `player_index` | Activating player |
| `tick` | Activation tick, not necessarily callback dispatch tick |

No callback runs inside the GUI handler. Delivery revalidates the exact physical
Dashboard, layout/button, enabled state, player/session authority and recipient
path/physical availability. Stale/foreign/hidden or revoked actions do not execute. A full recipient
queue follows existing overflow/fault cleanup without preventing another eligible
recipient's delivery. There is no private retry backlog or replay of delivered
factory actions. Stop, program replacement and cancellation retire registrations
without clearing Dashboard data; unsubscribe requires the exact run/device/wire.

The **Dashboard button** in-game Reference tutorial and maintained
`dashboard-program.lua` show the complete program. [Runnable programs](../examples.md)
also includes the optional-chart program. Multiple subscribers must coordinate
intentional factory side effects themselves.

## Optional line and duration methods

With unmodified **factorio-charts 1.2.0**, method enumeration and new wrappers add
exactly these methods. Without it they are absent, not callable stubs. Retained
chart definitions/data remain readable/removable, with unavailable placeholders;
new chart definitions raise `E_UNSUPPORTED`. Existing labels/buttons remain usable.
Trusted item/blueprint restoration preserves valid definitions while the library
is absent. Reinstalling it does not rerun producer startup.

### `appendSample(slot, id, values)`

Returns no values. The addressed node must be `line`; `values` is a plain map
containing **exactly** its series names, each with a finite number. One call appends
one whole vector. At capacity it evicts only the oldest vector. The horizontal
axis is accepted **sample order**, not timestamps or guaranteed wall-clock spacing.
No samples are fabricated while the producer stops or the window is closed.

`capacity` is at least **2**, because the upstream renderer divides by
`length - 1`. Its complete fixed-shape rolling reservation is admitted when the
line is configured, not only as it fills. `format` is `"number"` (default),
`"percent"` or `"time"`: number uses upstream's supported host `tostring` formatter;
percent inputs are already percent units; time values are **seconds**. No guest
formatter functions are accepted. Palette/order follow the unchanged renderer,
including sum-based ordering; colors are not promised to remain independently
fixed across reordered series. Empty/single-sample history shows collecting status.
Nonfinite derived sums/ranges refuse atomically without eviction.

### `setBars(slot, id, bars)`

Returns no values. The addressed node must be `stacked_bars`. `bars` is a dense
ordered array of maps with exactly the configured phase names and finite,
nonnegative durations in **seconds**. Phases are bottom-to-top stack order;
bar order is input order. Zero is valid, an empty array clears the dataset.
Every call replaces the latest dataset, not a history. Derived padded totals must
remain finite. The host's fixed 900×700 design viewport and upstream spacing
must leave positive bar widths; `getLimits()` exposes the actual support bound.

This is the unmodified library's time-axis bar renderer, **not** arbitrary
numeric/category bars, a custom renderer or Factorio's production graph widget.
Surrounding labels can explain the units and input order. Hatching, custom icons,
chart tooltips/clicks and independent color controls are not exposed.

### `clearChart(slot, id)`

Returns no values. Clears samples/index/totals or the latest bar dataset, retaining
the definition and a line's reserved capacity. It does not clear another widget.
`appendSample` on bars and `setBars` on a line raise `E_ARGUMENT`.

## Capacity, errors and lifetime

`getLimits()` includes common limits plus `dashboard_tabs=6` and
`dashboard_state_bytes=state_bytes` (default **65,536 accounted bytes**). With the
library it additionally includes `chart_line_series` from upstream's palette/domain
and `chart_bar_entries` from positive-width geometry. Excess series are refused,
not silently truncated by upstream. All six tabs, line reservations, metadata
and latest bar datasets share **one physical-device allowance**, across wires,
writers and viewers. Existing Data, operation and work envelopes also apply;
accounted bytes are not calibrated native Lua heap bytes. No new widget-count,
retention-time or series-count setting is added.

Validation/admission and result preparation precede publication. A capacity refusal
leaves prior layout/history/reservations intact. Lowered limits preserve accepted
state, reads/removal and non-growing updates, rather than truncating data.
Wrong arity/types/unknown fields are `E_ARGUMENT`; invalid slots, numeric/renderer
domains and formats are `E_RANGE`; shared retained exhaustion is `E_CAPACITY`;
ordinary Data/call bounds remain `E_LIMIT`. Unsupported/corrupt saved schemas
raise `E_UNSUPPORTED` without replacing recoverable data. Existing identity,
wire, scope, physical validity and fatal `E_BUDGET` contracts are unchanged.

Charts render only for selected open tabs, coalesced under existing maintenance
allowances. Pending/error states identify non-current presentation while retaining
accepted history and usable base controls. A chart that cannot fit a fresh work
allowance reports a refusal rather than retrying forever. Viewer/render resources
are host-owned, never returned as guest Data or transported in an item.

Cold saves retain accepted model/ring order and legitimate pending work, without
startup replay or load-stage mutation. Mining carries layout/history/latest bars
in one versioned tagged item; replacement gets a new physical identity and no
subscriptions/viewers/render objects. Blueprints/clones/settings copies carry
**definitions only**. Existing destinations retain only their own compatible
history, never the source's samples. Optional-library removal preserves data;
downgrading the main mod to a version without these prototypes is not a safe
rollback. Back up the save and newer archive.
