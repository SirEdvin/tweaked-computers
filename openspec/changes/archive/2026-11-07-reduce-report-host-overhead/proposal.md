## Why

A chest report callback (one `peripheral.find`, one `readSignals`, 20 `print` calls) costs about 0.97 ms of host time. The guest code itself costs about 60 µs. A profile of the PR #65 build attributes most of the remainder to host overhead: about 280 µs for the 20 guarded `print` calls, and about 200 µs to walk the wire network inside `peripheral.find`. Evidence: `/home/siredvin/artifacts/tweaked-computers/report-tick-profile-2026-11-07-pr65/`.

## What Changes

- In saved-program callbacks, `print` and `computer.log` put their entries in a buffer for that callback. The host writes the buffer to the Console once, when the callback ends. This also occurs when the callback fails or stops, before any fault entry. Entry text, tick, order, retention and eviction stay the same.
- In saved-program callbacks, one `print` makes two work charges instead of three. The argument charge stays before any native conversion. One charge then admits the bytes and the entry. The host charges Console eviction cost one time per callback, on the first entry that makes the buffered Console overflow. A refused `print` adds no entry.
- The network walk validates each device once and uses `force_index` and `surface_index`, so it creates fewer native wrapper objects. Results, order, charges and refusals do not change.
- A verified cross-callback graph cache was prototyped and measured, then dropped: exact verification still needs the most expensive native reads (see design.md).

Not changed: Console commands (their output and charges stay immediate), public Lua API, settings, save format, reachability rules, refusal codes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `computer-runtime`: program output is buffered for each callback and admitted with two charges per print instead of three.

## Impact

- Code: `scripts/runtime/environment.lua` (print), `scripts/runtime/computer.lua` (output sink, Console flush), `scripts/runtime/compiler.lua` (flush at callback end), `scripts/network.lua` (cheaper walk).
- Tests: Console order and retention contracts, print refusal and charge contracts.
- Docs: `docs/computer-runtime.md`; player Console notes when they describe charges.
- Storage: none. Every cache is process-local and is never saved.

## API Impact

Status: none
Reason: No guest-visible function, field, argument, result, error or limit changes. Output stays in the same order with the same text. Only internal timing and work charges change.
Compatibility: Existing programs and saves keep working without migration.
Reviewed-source: f7e796734ffb3d4bb2f7fa34bcf71a53542e496f0635600ec38ca32d5759f430
