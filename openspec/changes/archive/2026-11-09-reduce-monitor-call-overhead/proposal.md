## Why

After `reduce-monitor-redraw-overhead`, a 6×6 monitor that redraws the maintained `smooth-sine-chart` every two ticks still costs about 4.6 ms on each redraw tick. Most of this is host work around about 32 guarded monitor calls (`setCursorPos` + `blit`) for each frame, not drawing:
- The guarded service call packs arguments and results into tables, and copies each scalar argument through tables it then discards.
- `peripheral.wrap` builds a guarded function for every method of the peripheral, on each callback.
- Each work charge goes through several function calls.
- Each availability check makes two full placement proofs for each monitor tile.
- `blit` checks its colour strings one character at a time, and the presenter copies the front grid one cell at a time for each frame.

Evidence: `/home/siredvin/artifacts/tweaked-computers/monitor-sine-profile-2026-11-09/` and the profiles in this change's verification bundle.

## What Changes

- Guarded service calls pass results through without packing them into a table. Calls with only `nil`, boolean, number and string arguments do not pack or copy them. They make the same work charges and checks as before. Any other argument uses the current path.
- `peripheral.wrap` and `peripheral.find` facades build each method's guarded function on first use. Console shell facades keep the current eager construction.
- The work-charge function inlines its integer and ceiling checks.
- `lifecycle.available` proves the placement and ownership of each role one time, then reads both colour connectors.
- `blit` checks its colour strings with one native pattern scan, and the grid write uses a lookup table and local values.
- The presenter copies the front grid with one presized table, and marks only changed cells instead of every reused cell.

Not changed: public Lua API, results, errors, refusal points, work charges, limits, save format.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. No spec-level behavior changes; `skip_specs` is set.

## Impact

- Code: `scripts/runtime/environment.lua`, `scripts/runtime/admission.lua`, `scripts/services/peripheral.lua`, `scripts/lifecycle.lua`, `scripts/monitor-model.lua`, `scripts/rendering.lua`, `scripts/monitor-presentation.lua`.
- Tests: `tests/monitor_presentation_engine.lua` reads the new reused-cell marking.
- Storage: a staged frame can carry `reused_all`. Frames staged by an older version keep their complete `reused` table and are cleaned up as before.

## API Impact

Status: none
Reason: No guest-visible function, field, argument, result, error or limit changes. Work charges and their order are the same. Only host work changes.
Compatibility: Existing programs and saves keep working without migration.
Reviewed-source: ddd53f03a05d727bd9cbd84906313d73bf97161cd56b36ff7d8c14ffa78d1229
