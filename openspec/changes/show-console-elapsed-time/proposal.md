# Proposal

## Why

The computer Console currently prefixes messages with raw map ticks, which are difficult to read as elapsed time. The user accepted elapsed map time instead of local wall-clock time, with the same origin across computer restarts and hours continuing beyond 24.

## What Changes

- Display every retained Console log entry with an elapsed-map-time prefix `[HH:MM:SS]` instead of its raw tick number, using completed simulation seconds.
- Keep hours cumulative, padded to at least two digits, with no daily rollover or reset when opening the Console or restarting the computer.
- Format the entry's recorded tick, not its age or the time the Console is viewed. Existing retained logs use the new display without migration.
- Preserve stored ticks/text, log ordering and retention, shell attribution, diagnostics, selectable output, Follow behavior and unchanged-text refresh suppression.
- Briefly document that the timestamp follows simulation progress, not the PC clock.
- Do not add clocks, settings, dependencies, guest APIs, persistent fields or changes to runtime scheduling.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `program-editor`: Specify elapsed-map-time formatting for the existing shared Console output, including long-running maps and retained entries.

## Impact

- Presentation: `scripts/ui/editor.lua`, where `console(rec)` currently renders `entry.tick` directly for all log sources.
- Regression coverage: focused timestamp and refresh assertions in the existing editor and shell fixtures; retained-log coverage in the existing cold editor fixture.
- Player documentation: `docs/player/console.md`.
- No change to `scripts/runtime/computer.lua` log storage, `scripts/runtime/shell.lua` attribution, save schemas, authority checks, peripheral APIs or resource limits.
