# Production Statistics Lua API v1

Normative companion to [the capability delta](spec.md). This is a planned contract, not an implemented API or an execution receipt. It follows the repository's shared `openspec/api/common.md` rules. When synchronized, this file belongs beside the canonical `production-statistics/spec.md` and must be included in the package and documentation inventories.

## Discovery and exact method set

Peripheral type: `production_statistics`.

Use the existing `peripheral.find("production_statistics", "red")`, `wrap(name, wire)` or `call(name, wire, method, ...)` entry points with an explicit `"red"` or `"green"` wire. Methods use dots, not colons. The exact method set is:

| Signature | Exact returns |
| --- | --- |
| `stats.getTotals(kind)` | One `TotalsSnapshot` containing all recorded entries |
| `stats.getRates(kind, window)` | One `RatesSnapshot` containing all recorded entries |
| `stats.getHistory(kind, name, window [, quality])` | One `HistorySnapshot` for the selected entry |
| `stats.getLimits()` | One defensive map of the effective common limits |

Arity is exactly 1, 2, 3-or-4, and 0 respectively. An explicit nil fourth history argument is equivalent to omission. There are no overloads, option tables, cursors, all-history queries, sorting options, subscriptions or configuration methods. Calls are synchronous and non-yielding. Ordinary attachment/detachment notifications apply; no statistics event is introduced.

## Scope and inputs

- `kind`: exactly `"item"`, `"fluid"` or `"pollution"`; other strings raise `E_RANGE`.
- `window`: one exact symbolic native precision name from the table below. There is no default window and no numeric-enum input.
- `name`: a nonempty exact internal identity, never a localized label, recipe name, pattern or signal object. Item/fluid names must identify an installed prototype in that namespace. Pollution accepts an installed entity name or an exact key present in either current native pollution count map, including engine-defined sources/sinks not represented by an ordinary entity prototype.
- `quality`: item history only; omission or nil means `"normal"`. A supplied nonempty string must identify an installed quality. Non-nil quality for fluid or pollution is `E_ARGUMENT`. Bulk item calls always expose all recorded qualities separately.
- Input names use the existing common string/service envelope; they are not shortened, case-folded or coerced.

All statistics belong to the peripheral's current surface. Item/fluid data uses its force; pollution uses the surface-wide native statistics and is intentionally not force-filtered. No caller can select another force or surface. Native pollution statistics are emissions/absorption by source/sink, not current chunk concentration, total airborne pollution or a pollution map.

Valid registered item/fluid identities and registered pollution entity identities without recorded activity produce the engine's zero history. An arbitrary unknown name is `E_RANGE`, not an invented all-zero record. An engine-defined non-prototype pollution key is valid only while present in the native inventory. If the pinned engine cannot query such a recorded key consistently, treat that as a failed acceptance gate; do not silently omit it or invent samples.

## Native time windows

| Public `window` | Native precision | Window duration |
| --- | --- | --- |
| `five_seconds` | `defines.flow_precision_index.five_seconds` | 5 seconds |
| `one_minute` | `defines.flow_precision_index.one_minute` | 1 minute |
| `ten_minutes` | `defines.flow_precision_index.ten_minutes` | 10 minutes |
| `one_hour` | `defines.flow_precision_index.one_hour` | 1 hour |
| `ten_hours` | `defines.flow_precision_index.ten_hours` | 10 hours |
| `fifty_hours` | `defines.flow_precision_index.fifty_hours` | 50 hours |
| `two_hundred_fifty_hours` | `defines.flow_precision_index.two_hundred_fifty_hours` | 250 hours |
| `one_thousand_hours` | `defines.flow_precision_index.one_thousand_hours` | 1,000 hours |

Use the native enum symbols, not guessed integer values. Cumulative totals have no `window` argument. Each historical window has exactly 300 samples; this is native chart geometry, not a new configurable resource cap. The window duration divided by that count describes nominal sample spacing, but the API does not fabricate absolute sample timestamps from the call tick.

## Direction and units

| `kind` | `input` | `output` | Totals | Rates and history |
| --- | --- | --- | --- | --- |
| `item` | Produced items | Consumed items | Native item counts | Items per game minute |
| `fluid` | Produced fluid | Consumed fluid | Native fluid units | Fluid units per game minute |
| `pollution` | Emissions | Absorption | Native pollutant units | Pollutant units per game minute |

Fields retain the native input/output meanings. Neither side is netted against the other. Do not round fluid/pollution fractions, convert rate units, merge qualities, compute expected recipe production or report physical-machine throughput instead of recorded native statistics. Counters retain native numeric precision; no stronger arbitrary-precision integer guarantee is made.

## Snapshot shapes

Every statistical method returns exactly one fresh plain table with required `tick`, `input` and `output` fields and no native objects. `tick` is the synchronized game tick at which the query reads the data, not the end timestamp of the newest chart bucket. `kind` and `window` are not repeated in the result because the caller supplied them.

### TotalsSnapshot

For items:

```text
{
  tick = number,
  input = { [quality_name] = { [item_name] = native_count } },
  output = { [quality_name] = { [item_name] = native_count } }
}
```

For fluids and pollution:

```text
{
  tick = number,
  input = { [native_name] = native_count },
  output = { [native_name] = native_count }
}
```

`getTotals` copies the native input/output quality-count maps for items and the ordinary input/output count maps for fluids/pollution. Each side has exactly the keys present in its native map, including zero-valued recorded entries and any native empty quality maps. Missing opposite-side keys are not filled with zero; a caller may interpret absence as no recorded count. Empty statistics return empty maps rather than nil. No stable traversal or alphabetical order is promised.

Totals are cumulative native counters since the engine's applicable reset; they are not guaranteed lifetime totals and are not reconstructed by summing samples. If native counts are cleared or change through another mod, the next query reflects that state.

### RatesSnapshot

Identical map shape to `TotalsSnapshot`, but each numeric leaf is the native average per-minute rate for the requested window. The respective direction's native count map defines its inventory, so an entry with old cumulative activity remains present even when its selected-window rate is zero. Quality nesting and absence semantics remain unchanged.

A rate is read through native `get_flow_count` with the selected `category` (`"input"`/`"output"`), `precision_index`, no `sample_index`, and `count=false`. It is not obtained by subtracting two totals or averaging a private history array. The two directions are not forced to have matching key sets.

### HistorySnapshot

```text
{
  tick = number,
  input = { rate_1, ..., rate_300 },
  output = { rate_1, ..., rate_300 }
}
```

Both arrays are dense, exactly 300 elements long, with index 1 newest and index 300 oldest. Each value is the direct native `get_flow_count` result for that identity, direction, precision and `sample_index`, with `count=false`. Preserve native zero/short-history behavior; do not interpolate, reverse, trim unused-looking buckets or combine different qualities. The arrays are available even if the peripheral was placed after the recorded activity.

The item ID passed to the engine is a plain `{name=..., quality=...}` identity. Fluid/pollution queries use their native name. No native prototype, surface, force or flow-statistics handle crosses into guest code.

## Freshness, safety and limits

- Resolve live scope and statistics on each call. Do not cache counts or native handles across callbacks, persist a collector, or re-create authoritative data during load.
- Preserve the engine's update timing. Current-tick input/output samples may not yet be merged into totals/history; do not manually add them. Comparisons to the native UI account for display rounding, sample boundaries and verified pinned-engine GUI smoothing only in verification/presentation comparison. Every raw API sample remains exact; retain the burst comparison.
- A returned table is detached. Mutating it never alters native statistics, another caller's result or a subsequent read. Saving it through ordinary state/KV APIs is subject to those independent capacity limits.
- All entries are returned on success, including modded names and qualities. There is no top-N cutoff, arbitrary statistics entry ceiling, pagination or statistics-specific setting.
- Existing Data node/depth/string/table/result-byte and shared callback work/allocation protections remain. Large native inventories can therefore refuse as a whole; “all entries” is not a promise of unbounded success. No existing limit is raised and no native-circuit transport exception is generalized for this feature.
- Account for actual native calls, map iteration, validation and output construction. Repeated calls do not renew credits. A refused call returns no partial snapshot and creates no retained job, but consumed accounting remains consumed.
- `getLimits()` exposes the effective common limits without inventing a new limit policy. The fixed history length and supported precision names are documented here rather than represented as tunable budgets.

## Authority, errors and lifecycle

Same-force, same-surface, explicit-color Network reachability and the exact bound identity/generation are rechecked through the existing peripheral facade. Passive discovery and `getLimits()` remain available without device power. All three statistical methods require power. Captured methods do not retarget a replacement; Console-restored bindings retain the existing live checks.

| Condition | Result |
| --- | --- |
| Wrong arity, colon receiver, wrong argument type, empty identity or non-nil quality for non-item history | `E_ARGUMENT` |
| Unknown kind/window, unknown prototype/statistics identity, unknown item quality | `E_RANGE` |
| Existing argument/result envelope is exceeded | Existing `E_LIMIT`; no partial snapshot |
| Native data contains an unsupported/nonfinite value | `E_UNSUPPORTED`; no silently omitted entry |
| Native statistics access unexpectedly fails | `E_ENGINE`; do not manufacture zero values |
| Device is reachable but unpowered | `E_UNPOWERED` for statistical methods |
| Bound identity, path, force or surface is no longer authorized | Existing `E_UNREACHABLE` behavior |
| Network proof is pending or cannot fit existing allowances | Existing `E_NETWORK_PENDING` / `E_LIMIT` behavior |
| Shared work or callback allocation is exhausted | Existing fatal `E_BUDGET` control, not a catchable statistics-specific retry |

Ordinary errors use the shared plain `ApiError` shape and can be caught with `pcall`; message text is not stable API. Existing authority/power checks precede provider input validation, and resource exhaustion can occur before later semantic validation. Do not weaken those contracts to guarantee a different error ordering.

The device owns no statistics data, query sessions, subscriptions or output. Mining and replacement never reset native statistics; blueprint/cloning cannot duplicate a private production history. Save/load retains ordinary identity and wire state without storing native flow objects. Neither the feature nor its inspector exposes reset/write methods.

## Example: query the three categories and operations

Illustrative guest source, not yet executed. The implementation must maintain and execute the equivalent example from the packaged mod. Setup: place and power a computer and Production Statistics device on the same surface/force and connect their visible Network sockets with a red wire. Generate some item/fluid/pollution activity first to see nonempty maps. No collector startup is required.

```lua
function start()
  local stats = peripheral.find("production_statistics", "red")
  assert(stats, "Connect a Production Statistics device with red wire")
  local items = stats.getTotals("item")
  local normal = items.input.normal or {}
  computer.log("Iron produced: " .. tostring(normal["iron-plate"] or 0))

  local fluids = stats.getRates("fluid", "one_minute")
  computer.log("Water consumed/min: " .. tostring(fluids.output.water or 0))

  local pollution = stats.getTotals("pollution")
  for name, amount in pairs(pollution.input) do
    computer.log(name .. " emitted " .. tostring(amount))
  end

  local history = stats.getHistory("item", "iron-plate", "one_minute", "normal")
  computer.log("Newest iron production/min: " .. tostring(history.input[1]))
end
```

An empty map is valid, unlike an unavailable/unpowered query. Large factories can exceed existing whole-result or Console/log budgets; examples must explain `E_LIMIT` and the existing fatal work budget without swallowing failures or retrying in an unbounded loop. The separate maintained monitor example must plot both native history arrays using the existing monitor API, with axes/unit/direction labels and no independent history recorder.

## Pinned primary references and evidence status

Planning inspected the official Factorio 2.1.23 runtime API JSON and current service/lifecycle code. It did not execute a new feature or native-statistics fixture.

- https://lua-api.factorio.com/2.1.23/runtime-api.json
- https://lua-api.factorio.com/2.1.23/classes/LuaFlowStatistics.html
- https://lua-api.factorio.com/2.1.23/classes/LuaForce.html
- https://lua-api.factorio.com/2.1.23/classes/LuaSurface.html

Native sample parity, special pollution keys, cold loads, performance and actual client/multiplayer acceptance remain implementation gates, not facts established by this document.
