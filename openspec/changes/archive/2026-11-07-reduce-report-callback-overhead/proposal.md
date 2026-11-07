## Why

The chest benchmark report tick (one computer prints 20 chest signals) costs about 1 ms of mod time in the scheduler. Profiling shows three avoidable costs in each report. The program text is compiled again with Lua `load` (about 0.16 ms). Each `print` is converted through the full safe `tostring`, also for plain strings. When the Console is full, each append shifts all retained entries in a Lua loop (about 4.7 µs per print).

## What Changes

- A run-scoped scaffold keeps the program chunk that Lua `load` produced for its first callback. Later callbacks of the same run execute that chunk again. Each callback still constructs fresh declarations, helper closures and locals, and is charged the same as before.
- `print` passes string arguments directly. Other values continue to use the existing safe `tostring`.
- A Console append that evicts exactly one old entry removes it with the native `table.remove`. Appends that evict more entries keep the existing linear compaction.

Not changed: guest-visible behavior, public Lua API, charges and refusal points, Console retention rules, save format, Console command reconstruction.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `computer-runtime`: run-scoped scaffolding may reuse the loaded program chunk of its run, instead of loading the program fresh for each callback.

## Impact

- Code: `scripts/runtime/compiler.lua` (chunk reuse in the scaffold), `scripts/runtime/environment.lua` (string fast path in `print`), `scripts/runtime/computer.lua` (single-entry eviction).
- Tests: `tests/runtime_scaffold_engine.lua` counts program loads for warm, cold and new-run callbacks. Existing Console eviction, refusal and warm/cold admission contracts must pass unchanged.
- No new dependency, setting, limit or storage field.

## API Impact

Status: none
Reason: No guest-visible function, field, argument, result, error or limit changes. The reused chunk is host-internal and produces the same guest behavior and charges as a fresh load.
Compatibility: Existing programs and saves keep working without migration.
Reviewed-source: ab504fb6abbdc30a67a896945c41fd13156aac2e36178bf2b86191993f392312
