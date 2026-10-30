# Proposal

## Why

Plain named declarations expose named callbacks while allowing the same function to be called normally from another function in the program.

## What Changes

- Accept a saved document containing plain top-level `function name(...) ... end` declarations; derive the existing API-v1 handler inventory internally. Keep `start` optional and invoke it once on successful activation as today.
- Make declared program functions available to one another, including forward references and bounded recursion. A direct call is synchronous, returns ordinary bounded Lua values, and uses the caller's existing guard, budget, authority and run; it does not enqueue an event or synthesize an event argument.
- Support top-level `local function` helpers as private, non-registerable helpers with normal lexical scope. Only non-local named declarations are exported as handlers; names still do not imply event subscriptions.
- Reject module-level effects/variable initialization; retain sandbox and explicit-state rules.
- Update the inserted starter and primary language documentation to show the simpler format and a function used both immediately and later as a timer callback. Retain independent behavioral coverage and examples.
- Keep the live Console separate: the user explicitly confirmed that manual calls are within the same program, not a Console-to-program invocation feature.

## Capabilities

### New Capabilities

- `program-source`: Function-declaration saved programs, automatic handler export, intra-program function calls, and source validation/reconstruction.

### Modified Capabilities

None. At planning time, the in-flight `add-native-circuit-computers` change owned the broader `computer-runtime` capability; this narrower capability extended its source-authoring boundary rather than copying lifecycle, scheduling and peripheral requirements.

## Impact

- Primary implementation: `scripts/runtime/compiler.lua`, with narrowly scoped reuse/adaptation of closure admission in `scripts/runtime/sandbox.lua` if necessary. Preserve the existing active source/handler inventory consumed by `scripts/runtime/computer.lua` and the scheduler.
- User entry points: `scripts/ui/help.lua`, the existing editor-model compiler calls, `docs/player/api/language.md`, `docs/player/api/computer.md`, `docs/player/examples.md`, and source-language statements in runtime/Console documentation.
- Verification: extend the packaged runtime, compiler-cache, computer cold-reload and editor contracts; retain the shell regressions. Use existing package/smoke tooling and unchanged production limits.
- No new runtime dependencies, interpreter, guest loader, filesystem, Console bridge or persistent functions. Keep API version 1, compiler representation version 2 and storage version 1 for the supported retained source/inventory contract; verify reconstruction explicitly.
- Feasibility is supported by source inspection and a planning-only Factorio 2.0.77 probe in base and Space Age. Both passed 31 contract groups using unchanged production payloads plus an isolated fixture. The probe exercises current guarded native lexical-function building blocks, not an implemented new frontend, editor path, cold reload or multiplayer feature. Evidence: `/home/siredvin/artifacts/tweaked-computers/function-program-proposal-2026-10-19/`.
