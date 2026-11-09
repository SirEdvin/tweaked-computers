## Context

See proposal.md for the problem. Measurement method: a guest callback that makes 100 identical calls, compared with an empty loop, on one 6×6 wall (headless 2.1.23, `tools/monitor_performance.py --program`). The harness collects Lua garbage before each measured tick, so the values do not include collector work from the harness. Per `set` call before this change: 58.8 µs and 6.1 KB. Removing each part in a scratch build gave: graphics host work about 33 µs, peripheral lookup about 12 µs, argument snapshot about 8.5 µs, availability check about 6 µs, guest `string.format` and table about 3.4 µs. A native micro-benchmark gave 1.7 µs for a nine-property native text update.

## Goals / Non-Goals

**Goals:** less host time and less garbage for each graphics call, with the same results, errors, refusal points and work charges.

**Non-Goals:**
- Removing the guarded service, work charges, payload allowances, ownership proofs or the content-area check.
- Caching across callbacks. Factorio 2.1.23 has no wire connect or disconnect event, so a cross-callback topology cache cannot be proved current.
- Partial native updates for other object kinds or other properties.
- Terminal-mode changes.

## Decisions

### 1. Borrowed service input

`E.borrow_input(fn)` marks a host function that only reads its arguments. For a non-scalar call to that function, the service checks each argument like a snapshot: scalars through `snapshot_scalar`, other values through `copy()` with a measuring flag that has the same checks and charges and builds no output. The call then uses the pooled frame and `results(frame,pcall(fn,...))`, like the scalar fast path. The marks are weak-keyed because facade services are per-callback closures. Borrowing is ignored for services with native input or an input rule.

Alternative: mark graphics methods as native input. Rejected: native input skips the snapshot charges and the nested plain-table checks.

### 2. Measured graphics payload

`payload()` calls `data.measure` with the same ceiling and entry allowance and returns the caller's table. `validate` reads it one time and builds fresh stored tables: `point`, `color` and `points` return new tables, and strings and numbers are immutable. A guest cannot attach a metatable, and both measurements refuse non-plain, cyclic, non-finite and oversized tables before `validate` reads them.

### 3. Reused unchanged properties

`validate(kind,input,base)` stores `base[k]` for properties that the call does not give. No code changes stored property tables in place: `get` returns a clone, and `set` replaces `o.props`.

### 4. Text and colour fast path

After validation and the content-area check, a `set` on a text object whose input keys are only `text` and/or `color` writes only `native.text` (the mapped private-use text) and/or `native.color`. A text change on centre or right aligned text moves the native anchor, so it uses the full rebuild. For left alignment, rotation and vertical alignment do not depend on the text length.

### 5. Identity reuse per inventory proof

`lookup` keeps resolved records in a weak table keyed by the inventory proof's value table. `invalidate()` and every bind replace the proof, so the cache goes with it. `current()`, the name and wire checks, and the proof's charge replay still run on each call, and `invoke` still compares the captured generation. An earlier change dropped a similar per-proof cache because it gave no measurable gain on the sine-chart workload. Here it measured 13.8 → 11.4 µs for `getMode`; for `set` the gain was within noise.

### API impact

None. The `lua-api` artifact is deliberately skipped.

## Risks / Trade-offs

- [A borrowed host function retains or changes a guest table] → Only monitor graphics methods borrow, and their code builds fresh stored tables. The comment on `E.borrow_input` states the rule. `runtime_environment_contract` checks that a borrowed argument arrives uncopied, is charged like a snapshot, and is refused with the same code as a snapshot.
- [The fast path leaves a stale native property] → Only `text` and `color` change, and only when nothing else does. `monitor_graphics_contract` checks the native text, colour and anchor, a refused overlong text, and the centred-text rebuild.
- [A peripheral changes identity during one callback] → The cache uses the same lifetime as the inventory proof, which the runtime already treats as valid for the callback.

## Migration Plan

No storage migration. Rollback is a code revert.
