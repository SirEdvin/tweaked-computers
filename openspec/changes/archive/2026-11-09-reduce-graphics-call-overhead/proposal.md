## Why

After `monitor-graphics-mode`, one graphics `set` call that changes only the text of a text object costs about 59 µs of host time and allocates about 6.1 KB. Factorio's native work is about 2 µs of this. The remaining cost is host work around the call:
- The guarded service call copies the property table. The graphics call then copies it again, and `validate` builds a third table.
- `validate` copies every property that the call does not change, for example `target` and `color`.
- The guarded service packs the arguments and the results into new tables for each call that has a table argument.
- Each `set` builds the complete native projection and writes every native property, also when only the text changes.
- Each facade call resolves the peripheral identity again, also when the inventory proof of the same callback is still valid.

Evidence: `/home/siredvin/artifacts/tweaked-computers/monitor-stock-benchmark-2026-11-09/call-cost/` and this change's verification bundle.

## What Changes

- The guarded service can borrow table arguments for a host function that only reads them. Borrowed arguments get the same checks and work charges, in the same order, as a snapshot. They are not copied. Borrowed calls use the pooled service frame and do not pack arguments or results.
- Monitor graphics methods borrow their property tables. The graphics payload check measures the table with `data.measure` instead of copying it. The charges and the per-call byte and entry allowances are the same.
- `set` keeps the stored values of properties that the call does not change. It does not copy them. Stored properties are never changed in place.
- A `set` that changes only `text` and/or `color` of a left-aligned text object writes only those native properties. All other changes rebuild the complete native projection as before.
- A facade call resolves the peripheral identity one time for each inventory proof. The cache is removed when the proof is removed (`invalidate()` and every bind).

Not changed: public Lua API, results, errors, refusal points, work charges, limits, save format.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. No spec-level behavior changes; `skip_specs` is set.

## Impact

- Code: `scripts/runtime/environment.lua`, `scripts/services/peripheral.lua`, `scripts/services/monitor.lua`, `scripts/monitor-graphics.lua`.
- Tests: `tests/runtime_environment_contract.lua` (borrowed input), `tests/monitor_graphics_contract.lua` (text and colour fast path).
- Storage: none. Stored graphics properties can share unchanged value tables with the previous stored properties. No code changes stored properties in place.

## API Impact

Status: none
Reason: No guest-visible function, field, argument, result, error or limit changes. Work charges and their order are the same. Only host work changes.
Compatibility: Existing programs and saves keep working without migration.
Reviewed-source: 0e870bb5a65ca54b40c099ddb16308a80f06167eeb5a28c2d96006cc4eaeb1f4
