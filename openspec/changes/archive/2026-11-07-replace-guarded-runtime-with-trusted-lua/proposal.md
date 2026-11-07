# Proposal

## Why

The current runtime instruments ordinary Lua operations and constructs a large guard for each invocation. Recent profiling identifies these mechanisms as substantial costs beside the actual device work.

## What Changes

- **BREAKING**: Execute validated saved programs and Console commands as trusted native Lua. Remove execution-step, temporary-allocation, call-depth, and tuple metering.
- **BREAKING**: Use native behavior for temporary computations and approved library operations. Remove temporary string/table ceilings, staged assignment, and staged sorting. Native limits still apply.
- Keep the existing source grammar, approved API surface, named events, and explicit persistence. Reconstruct fresh program functions for each callback. Do not cache mutable execution environments.
- Keep checked device access, protected namespaces, safe output formatting, validated persistence, bounded queues/logs, source validation, and host-work admission.
- **BREAKING**: Remove `callback_work`, `callback_allocations`, `callback_depth`, `tuple_entries`, and `generated_source_bytes` from common limits. Remove settings `tc-callback-work` and `tc-callback-allocations`.
- Keep `string_bytes` and `table_entries` as boundary limits, not temporary-value limits. Keep the existing source, shared host, maintenance, device, and retained-data allowances. Add no replacement quota.
- Keep fatal host-work refusal and saved-program stop outside protected error handling. Native Lua failures use native behavior instead of synthetic guest-quota faults.
- Preserve compatible guarded-runtime saves through an explicit synchronized upgrade. Preserve source, state, shell graphs, run identities, queued work, deadlines, and already spent host credits.
- Delete the instrumenting emitter, execution-only guard machinery, obsolete settings, and tests of withdrawn guarantees. Retain and adapt tests for every surviving protection.
- Update typed declarations, generated references, player warnings, and test tooling. State that trusted code can stall the simulation or exhaust memory.
- Compare the replacement with the current optimized archive using unchanged workloads. A performance improvement remains unverified until implementation measurements exist.

The maintainer accepted the runaway-code risk first. A separate clarification selected both execution modes and native temporary-value behavior.

## Capabilities

### New Capabilities

None. This change replaces execution policy within existing capabilities.

### Modified Capabilities

- `computer-runtime`: Trusted execution, checked boundaries, native helpers, retained host admission, compatible upgrades, and explicit risk warnings.
- `program-source`: Validation without operation instrumentation, native calls, source diagnostics, and unchanged declaration/persistence semantics.
- `console-shell`: Trusted command evaluation with existing authorization, transactional scratch publication, and independent resource ownership.
- `peripheral-network`: Direct checked calls without the execution guard, including authentic bindings and multi-return discovery without the retired tuple ceiling.
- `factoriopedia-interface`: Shared host work and Data limits without guest-allocation accounting.
- `production-statistics`: Complete snapshots under retained host/Data limits without guest-allocation accounting.
- `recipe-searcher`: Existing result and persistence limits without retired per-computer execution/allocation budgets.

## Impact

The replacement affects `scripts/runtime/compiler.lua`, `sandbox.lua`, `admission.lua`, `computer.lua`, `shell.lua`, and `shell-values.lua`. The design includes their callers in services, scheduling, UI admission, and registry migration.

Cleanup also affects runtime limits/settings, their locale entries, helper export inspection, limit generation, runtime fixtures, and maintained documentation. The Phobos validator remains; its parser hooks still bound source validation. No interpreter, external library, coroutine engine, compatibility backend, or additional setting is introduced.

This change follows the implemented but unarchived `reduce-runtime-overhead` change. Its direct output and authority optimizations remain useful. Its instrumented regions and guest-accounting specializations become obsolete. Do not rewrite that change's tasks or historical evidence. If both changes are archived, synchronize the earlier deltas first and these replacements last.

This proposal authorizes no implementation, release, commit, push, or archival operation.

## API Impact

Status: changed
Reason: Execution guarantees, temporary-value semantics, helper behavior, and reported limits change. Device signatures and persistent Data formats remain compatible.
Compatibility: Source syntax, named callbacks, exact service return counts, and supported saves remain compatible. Programs must not depend on removed limit fields, synthetic temporary-value errors, or atomic temporary sorting/assignment. Native errors can replace earlier mod-specific helper failures. `E_BUDGET` remains for source/host work, not a watchdog for Lua execution. All remaining service-specific domains and bounds still apply.

| Canonical path | Disposition | Removed identities |
| --- | --- | --- |
| api/common.d.lua | modified | - |
| api/computer.d.lua | modified | - |
| api/globals.d.lua | modified | - |
| api/peripheral.d.lua | modified | - |
| api/generated/limits.d.lua | modified | TC.Limits.callback_work, TC.Limits.callback_allocations, TC.Limits.callback_depth, TC.Limits.tuple_entries, TC.Limits.generated_source_bytes |
| api/factoriopedia-interface.d.lua | modified | - |
| api/production-statistics.d.lua | modified | - |
| api/recipe-searcher.d.lua | modified | - |
| api/dashboard.d.lua | modified | - |
| api/speaker.d.lua | modified | - |
| api/configurator.d.lua | modified | - |
| api/monitor.d.lua | modified | - |
