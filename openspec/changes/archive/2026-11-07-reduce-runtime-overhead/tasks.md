# Tasks

All tasks below are implementation work. Planning completion does not mark them complete. See `design.md` for boundaries, fixture selection, and evidence requirements.

## 1. Preserve the baseline and acceptance inputs

- [x] 1.1 Validate the proposed API before implementation. Run `python tools/player_docs.py --check --change reduce-runtime-overhead` with the pinned LuaLS binary. Verify all four replacement paths and unchanged public identities.
- [x] 1.2 Build an unchanged baseline archive with `tools/build.py` in a fresh external directory. Copy the frozen chest runner and harness. Correct the copied runner's hard-coded `source_head` provenance without changing guest source or workload. Verify archive, guest, harness, engine, and source hashes.
- [x] 1.3 Run the matched baseline windows described in the design. Preserve every output/deadline assertion, individual run, sample count, distribution, and host-contention record in an external report.

## 2. Direct bounded output and linear retention

- [x] 2.1 Extend `tests/computer_contract.lua` and `tests/shell_contract.lua` for direct print/log routes. Cover exact argument/result counts, nil/false formatting, empty output, shell prefixes, invalid strings, captured callables, and fatal control. Verify failing cases reproduce missing behavior before the implementation, then pass afterward.
- [x] 2.2 Bind a private execution-owned sink in `scripts/runtime/computer.lua`, `sandbox.lua`, and `shell.lua`. Remove the program print service round trip and redundant string snapshots. Prepay formatting, retention, and zero-result publication. Verify zero per-entry physical rediscovery on a stable admitted path, unchanged bytes, and refusal before effects.
- [x] 2.3 Replace repeated front eviction with one prefix compaction. Update squared log-count reservations in shell command overhead too. Verify exact-fit and one-credit-short refusal, multiple-entry eviction, independent byte/entry pressure, unchanged truncation state on refusal, and linear movement counts.
- [x] 2.4 Promote the reviewed logging notes in `api/computer.d.lua` and `api/globals.d.lua`. Update the relevant runtime documentation and regenerate both references. Verify `tools/player_docs.py --check` and the packaged computer/shell fixtures with unchanged production limits.

## 3. Specialized deterministic accounting

- [x] 3.1 Specialize hot work/allocation reservations in `scripts/runtime/admission.lua` and `sandbox.lua`. Retain checked ingress, one authoritative ledger, current ceilings, maintenance headroom, and stale-context rejection. Verify malformed amounts, mixed resource shortages, settings changes, and independent computers in runtime contract tests.
- [x] 3.2 Combine only bounded reservations that precede their complete effect unit. Reconcile compiler-cache replay with the new charge sequence. Extend `tests/compiler_cache_contract.lua` to verify exact warm/cold outcomes and paid prefixes at zero, exact-fit, and one-credit-short boundaries.
- [x] 3.3 Promote `api/common.d.lua` accounting notes and document the revised units in `docs/runtime-foundation.md`. Regenerate both references. Verify the typed check and native budget/cold fixtures, including preservation of already spent credits and earlier completed effects.

## 4. Shared host implementations and local authority proofs

- [x] 4.1 Move stateless host implementations out of per-invocation sandbox construction without sharing mutable guard state. Preserve fresh guest closures and namespace bindings. Verify private-helper rebinding, callable alias identity, failed-then-healthy execution, cross-computer isolation, and program/Console separation in `tests/runtime_contract.lua` and `tests/shell_contract.lua`.
- [x] 4.2 Record the exact authority invariants and invalidating operations for each provider enabled for proof reuse. Extend the existing mechanism in `scripts/runtime/principal.lua` and `scripts/services/peripheral.lua`. Keep unclassified providers conservative. Verify invalidation before successful and throwing operations in `tests/device_contract.lua` and `tests/monitor_optimization_contract.lua`.
- [x] 4.3 Verify physical proof scope with captured methods, wrong color, replacement generation, force/surface changes, owner retirement, native availability, and the next invocation. Include real packaged revocation cases and separate-process reload; retain fail-closed outcomes and output cleanup.
- [x] 4.4 Promote `api/peripheral.d.lua` authority notes and update `docs/computer-runtime.md` for fresh state with shared host code. Regenerate both references. Verify the typed check and structural counters showing reduced host construction or repeated proof work without reduced safety coverage.

## 5. Bounded compiler checkpoint reduction

- [x] 5.1 Add focused compiler/runtime cases for prepaid straight-line regions, branches, short-circuit paths, every loop form, recursion, dynamic-size operations, protected calls, and stop. Record the region-entry and cost argument in `docs/runtime-foundation.md`. Verify each case protects effect ordering and original-source diagnostics.
- [x] 5.2 Reduce checkpoints only for the proved eligible regions in `scripts/runtime/compiler.lua` and `sandbox.lua`. Retain dynamic validation, allocation, depth, tuple, loop, call, and fatal barriers. Verify generated control flow cannot enter after admission or reuse credit across a backedge. Keep unproved regions on the existing checked path.
- [x] 5.3 Run runtime, compiler-cache, shell, and native budget fixtures against the region changes. Verify equal new-version warm/cold refusal, exact result arity, finite loop termination, and no post-fatal effects. Update implementation documentation and preserve any failed safety or timing gate without weakening its assertions.

## 6. Integrated acceptance and measured overhead

- [x] 6.1 Build the final candidate and run relevant packaged runtime, computer, compiler-cache, shell, device, monitor-optimization, and budget fixtures in base and Space Age. Use each fixture's supported cold/production-context flags. Verify exact completion markers, zero exits, normal cleanup, and tested archive hashes.
- [x] 6.2 Run separate-process runtime and shell reload cases with retained logs, pending work, shared credits, and non-idempotent effect witnesses. Verify no startup replay, repeated effects, restored permission, or credit renewal. Keep connected multiplayer acceptance separate from headless results.
- [x] 6.3 Exercise the actual Console with the existing native-client fixture. Inspect Follow-off/on output, selection/copy, eviction, attribution, and cold reopen. Preserve screenshots and logs outside git. Verify normal client exit and distinguish visible acceptance from headless contracts.
- [x] 6.4 Run the final matched chest benchmark for three 3,600-tick and three 18,000-tick repetitions, plus minimally instrumented timing. Verify unchanged source, settings, quantities, output entries, and deadlines. Compare reporting and all-tick distributions; preserve diagnostic profiles separately. Require repeatable improvement before claiming a speedup.
- [x] 6.5 Run `python -m unittest discover -s tools -p 'test_*.py'`, `python tools/planning_examples.py --check`, the canonical documentation checks, and `git diff --check`. Verify all four typed drafts are reconciled, generated references are current, production budgets are unchanged, and no game binaries or evidence outputs entered git. Deliver the final safety/performance report with failures and unverified environments stated explicitly.
