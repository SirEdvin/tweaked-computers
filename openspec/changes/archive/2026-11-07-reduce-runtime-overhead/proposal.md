# Proposal

## Why

The chest-report benchmark identifies repeated sandbox construction, guarded logging, and admission calls as substantial costs beside a small native circuit read. Remove redundant host work while preserving bounded execution, valid authority, isolated state, and deterministic effects.

## What Changes

- Give `print` and `computer.log` one private, bounded output path. Remove the generic service round trip and repeated Data snapshots of validated strings.
- Replace repeated front-removal log eviction with one prefix compaction. Preserve entry order, byte limits, entry limits, and the saved array representation.
- Specialize frequent work and allocation reservations. Validate invariant execution context once, without caching mutable allowance or spent-credit values.
- Share stateless host helper implementations. Keep guest environments, functions, mutable bindings, ownership tables, errors, and counters isolated for each invocation.
- Permit reuse of a valid authority proof within one non-yielding callback or Console command. Invalidate it before any operation that can change its assumptions. Never carry it into later execution.
- Coarsen compiler-inserted work checks only for bounded, prepaid regions. Retain checks at loops, calls, effects, variable-cost work, and fatal-control boundaries.
- **BREAKING**: Internal charges and `E_BUDGET` locations can change. Earlier versions' charged amounts and failure prefixes are not compatibility promises. Hard ceilings, warm/cold determinism, spent credits, and completed-effect order remain protected.
- Require matched benchmark evidence and independent safety tests. Lower charges alone do not establish lower CPU cost.

## Capabilities

### New Capabilities

None. These changes belong to the existing execution, source, Console, and authority contracts.

### Modified Capabilities

- `computer-runtime`: admitted local logging, revised accounting, shared host code with fresh invocation state, and authority guarantees instead of mandatory repeated physical checks.
- `program-source`: bounded compiler checkpoints and original-source diagnostics under revised charges.
- `console-shell`: the same accounting and output protections for commands, with independent attribution and shared credits.
- `peripheral-network`: callback-local proof reuse with explicit invalidation, unchanged live access requirements, and no cross-callback permission.

## Impact

Primary implementation areas are `scripts/runtime/{admission,compiler,sandbox,computer,principal,shell}.lua` and `scripts/services/peripheral.lua`. Service call sites require an authority-invalidation review before any proof reuse.

Existing runtime, computer, compiler-cache, Console, topology, and native budget tests provide the regression base. Packaged cold checks and the unchanged four-chest reporting workload provide integration and performance evidence.

No new dependency, VM, persistent guest environment, scheduling policy, capacity setting, or increased production budget is proposed. Saved log arrays, application Data, timers, queues, and shell graphs keep their existing formats. The unfinished acceptance work in `demand-driven-device-scheduling` remains separate.

The prior evidence is under `/home/siredvin/artifacts/tweaked-computers/chest-poll-2026-11-06/` and `/home/siredvin/artifacts/tweaked-computers/chest-report-profile-2026-11-06-205244/`. These are baseline and diagnostic evidence, not proof that this proposal is implemented or faster.

## API Impact

Status: changed
Reason: Document revised budget-failure compatibility, admitted local output, and the permitted lifetime of authority proofs.
Compatibility: Public names, argument domains, return arity, ordinary errors, and retained-data formats remain unchanged. Internal charges and quota-failure positions can differ from earlier versions. No public identity is added or removed. Existing source requires no rewrite, but programs near a budget boundary can complete a different prefix before refusal.

| Canonical path | Disposition | Removed identities |
| --- | --- | --- |
| api/common.d.lua | modified | - |
| api/computer.d.lua | modified | - |
| api/globals.d.lua | modified | - |
| api/peripheral.d.lua | modified | - |

The change-scoped declarations are complete replacement drafts, not canonical edits. Implementation must promote the accepted drafts and regenerate both API references.
