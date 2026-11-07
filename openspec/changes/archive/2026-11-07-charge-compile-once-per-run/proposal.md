## Why

Since `reduce-report-callback-overhead`, a run loads its program chunk once. Each callback still pays the full compilation charge again: the replayed source-validation trace and the `compile` reconstruction reserve. The charge stays identical on warm and cold peers, but a callback pays for compilation that the run already paid for.

A process-local cache cannot skip this charge safely. A late joiner or a reloaded save has a cold cache and would charge differently, which causes a desync.

## What Changes

- The computer record keeps a saved marker, `compile_paid`, equal to the `run_id` of the run that paid compilation.
- The first callback of a run pays the compilation charge and sets the marker. Later callbacks of the same run do not pay it.
- All peers read the same saved marker. Thus warm and cold peers charge the same and refuse at the same point. No setting is necessary.
- Each callback still validates the exact source and executes the program declarations again.

Not changed: Console commands, callbacks without a computer record, source validation, refusal of the first callback, public Lua API, settings.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `computer-runtime`: a run pays compilation work once, and a saved marker records the payment.

## Impact

- Code: `scripts/runtime/compiler.lua`.
- Tests: `tests/runtime_scaffold_engine.lua`.
- Docs: `docs/computer-runtime.md`.
- Storage: one new optional string field on the computer record. Old saves load unchanged. Their first callback after the update pays compilation once.

## API Impact

Status: none
Reason: No guest-visible function, field, argument, result, error or limit changes. `compile_work` keeps its meaning. Later callbacks of a run consume less of it.
Compatibility: Existing programs and saves keep working without migration.
Reviewed-source: 024722237c5fa933d268268d7e62463f0227f08808516c8041348e2a8c525e44
