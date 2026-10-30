# Production Statistics

Read native **item, fluid and pollution** totals, window-average rates and history
through a physical `production_statistics` peripheral. This is not an independent
collector, machine scanner or replacement for the game's production charts.

## Build and connect

Research **Recipe Searcher** (`tc-recipe-searcher`). Its original research cost,
prerequisites and existing unlocks are unchanged. Circuit Computers alone is not
enough. Craft one device in 2 seconds from **8 iron plates, 5 electronic circuits
and 2 advanced circuits**. Items stack to 50. The 1×1 instrument consumes **30 kW**.
Connect its visible **Network** contacts directly to a computer Network on an
explicit red or green wire. Both colors work independently; the body is a passive
same-color relay, never a factory-signal input/output or a bridge between colors.
Normal opening shows identity and status, with **Select name for copy** and native
Copy. Neither opening nor automatic inspector refresh queries statistics.

## Methods

Use dots, not colons. Every method returns exactly one fresh plain table.

| Signature | Result |
| --- | --- |
| `getTotals(kind)` | All native cumulative counters in `{tick,input,output}` |
| `getRates(kind, window)` | Same complete map shape, native rates per minute |
| `getHistory(kind, name, window [, quality])` | Two dense 300-sample arrays in `{tick,input,output}` |
| `getLimits()` | Defensive effective common limits |

Arity is exactly 1, 2, 3-or-4 and 0. Explicit nil quality is omission, but other
extra nil arguments are still extra arguments. `kind` is exactly `item`, `fluid`
or `pollution`. No force/surface selector, option table, cursor, subscription,
write or reset method exists.

## Scope, directions and shapes

Every call resolves the device's **live own surface**. Item/fluid statistics use
**its force**. Pollution statistics are **surface-wide**, shared between forces,
and include the surface's native pollutant (including spores where applicable).
These are emissions/absorption, not chunk concentration or total airborne pollution.

- `input`: produced items/fluid, emitted pollutant.
- `output`: consumed items/fluid, absorbed pollutant.
- Item maps: `{[quality_name]={[item_name]=number}}`, preserving every recorded
  quality separately. Fluid/pollution maps: `{[native_name]=number}`.
- Each direction retains its own exact key set. Missing opposite keys remain
  absent; native zero entries and empty quality maps are not discarded. An empty
  map is successful empty data, not an error.
- Totals retain native cumulative counters since the applicable native reset.
  Rates/history retain native fractional **per-game-minute** values without
  rounding, netting or additional conversion.
- `tick` is query time, not a synthetic sample timestamp. Current-tick samples
  may not be merged yet. The native UI rounds display values; it is not a second
  source of higher-precision numbers.

`getRates` uses the recorded inventory even if an old entry's short-window rate
is now zero. It does not union the directions or average a private series.

## Windows and historical order

All eight exact symbolic windows are supported:
`five_seconds`, `one_minute`, `ten_minutes`, `one_hour`, `ten_hours`,
`fifty_hours`, `two_hundred_fifty_hours`, `one_thousand_hours`.
There is no default window and no numeric-enum input.

`getHistory` selects one exact internal item/fluid identity, or an installed
entity/recorded native pollution source or sink identity. Non-prototype pollution
keys are valid while present in either current native count map. Unknown names
are errors, not fabricated zero histories. Valid installed but unrecorded
item/fluid/entity identities return native zeros. Item quality defaults to
`normal`; supplied item quality must be installed. Other kinds reject non-nil
quality. Bulk calls always preserve all recorded item qualities.

Both history arrays contain **all 300 native samples**, index **1 newest**, index
**300 oldest**, including zero/short-history samples. The length is native chart
geometry, not a tunable capacity. The peripheral never reverses, interpolates,
resamples or independently records history. A newly placed device can read history
from before placement. The monitor example indexes oldest-left for presentation only.

## Whole result or explicit refusal

Existing [shared rules](common.md) and [effective limits](limits.md) apply.
There is no statistics-specific entry ceiling, new setting or native-circuit
transport exemption. Complete native results that fit return every entry.
A non-fitting result refuses as a whole, never truncates or leaves a retained job.
Repeated queries spend the same shared callback/host credits; retrying does not
renew them. A native call's fixed admission charge is not a hard C++ time or heap bound.

| Condition | Error/control |
| --- | --- |
| Wrong arity/type, empty identity, colon receiver, non-item quality | `E_ARGUMENT` |
| Unknown kind/window/name/item quality | `E_RANGE` |
| Existing result/Data envelope cannot fit | `E_LIMIT`, no partial snapshot |
| Unsupported/nonfinite native value | `E_UNSUPPORTED` |
| Unexpected native access failure | `E_ENGINE`, never invented zero data |
| Physically invalid device | `E_UNREACHABLE`; custom devices need no electricity |
| Removed/replaced/foreign/out-of-scope identity/path | `E_UNREACHABLE` |
| Network proof pending or too expensive | `E_NETWORK_PENDING` / `E_LIMIT` |
| Shared work/allocation exhausted | Fatal `E_BUDGET`, not catchable |

Ordinary errors are plain catchable ApiErrors. Live facade physical authority and
shared resource checks can precede provider argument validation. Captured methods
never retarget replacement devices; restored Console bindings keep live checks.
Changing a returned map/sample cannot mutate native statistics or another result.

## Run the tutorials

The in-game **Reference → Examples → Native production statistics** tutorial
contains literal complete code, setup, steps and failure notes. Copy it manually
into an empty Editor, Validate, Save and Run. The identical packaged
[production-statistics-program](../examples.md#production-statistics-program)
reads all three categories and prints input totals/rates and both iron histories.
Empty inputs are reported explicitly; `E_LIMIT` is reported as refusal. Console
history itself is bounded, so this is not an unlimited factory export.

For a dashboard, connect one electricity-free monitor on the **same red discovery network**
and run [production-statistics-monitor](../examples.md#production-statistics-monitor).
Use at least **14 columns and 7 rows** (join monitor tiles if necessary). After
120 ticks it displays iron production/consumption per minute and both native
one-minute histories, with a shared peak scale and **older → newer** direction.
The two traces are input above output. `No activity` means zero native series;
`Query refused` means a whole-result limit refusal. Physically invalid/missing devices
fault instead of pretending data is empty. No other program should write this screen.

## Save, upgrade and rollback

Ordinary cold loading preserves device identity/wires without querying on load
or replaying program startup. No native statistics object, history, session or
cache is stored by this device. Mine/clone/blueprint follow the normal composite
lifecycle with one logical item; removing a device never resets native statistics.

Back up before upgrading. Forces that already researched Recipe Searcher gain
the new recipe during configuration reconciliation; Circuit-Computers-only
forces stay locked. Existing devices, source/data and wires remain intact.
Rollback means restoring the **pre-upgrade save and matching archive**, not loading
a new save containing the device with an older mod. This guide describes the
feature build, not a release/version announcement.
