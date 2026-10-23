# Durable compiler jobs: integration boundary

This lane supplies a working, native-tested compiler job, not completed OpenSpec 4.4 integration. The production lifecycle still calls the synchronous `compile`/`prepare` interfaces until the parent connects private jobs, ownership and reconstruction admission. Do not mark 4.4 complete from these fixtures.

## Implementation

`tools/compiler_build.py` uses development-only `lupa.lua52` to run the pinned Phobos parser over the **trusted compiler implementation**. `compiler-build.lua` emits static native Lua blocks. Checked-in `compiler-generated/*.lua` contains that transform, with source/output hashes and a cursor build identity. This is neither guest bytecode interpretation nor a guest fallback runtime: guest code still uses continuation ABI 9.

The compiler trampoline stores only plain tables/scalars: lexical cells and captures, parser module globals, tokenizer indices, Phobos AST links, calls/returns, pending charge debt, emitter state, CFG/liveness queues and final block metadata. Each native block prepays work. A paid block prefix survives a later primitive's suspension. The tokenizer's unbounded token-pattern scans were replaced with character loops; the existing lexical rules and diagnostic construction remain. Sort/concat/array helpers have explicit durable loop state. No coroutine or native iterator is stored.

Compilation produces individual native block/cleanup strings plus plain entry/prototype/symbol/literal metadata. Syntax verification visits those fragments across slices. Reconstruction lazily loads one block and its cleanup row **before** executing it. Cache hits pay exactly the same admission sequence as misses. Native calls remain indivisible: an atom that cannot fit a fresh effective slice refuses instead of waiting forever. Very long individual strings/native fragments remain such atoms; this does not impose a source/token/node/handler count limit.

The compiler's source/token/node/handler/generated-text/tuple/constructor gates were removed. Synchronous emitter recursion now checks the real host-depth setting (with the baseline callback-depth fallback); transformed frames do not consume recursive host stack. The parent must replace the remaining `source_nesting` check in the existing, out-of-lane `parse_admission.lua` synchronous helper. **The identifier-byte check is still present**: the attempted removal was denied by a tool approval timeout, and was not retried through another tool. Renewed approval or a separately authorized parent edit is required.

## Parent API

- `compiler.new_job(source, mode)` creates a private cursor. `mode` is nil or `shell`. Reserve its initial/source ownership before creation.
- `compiler.advance(job, context, admit)` returns `plan, diagnostic, status`. Waiting is `nil,nil,'wait'`; the same tick cannot renew credits. A changed generated-build identity returns `E_UNSUPPORTED` and retains source. `admit` is mandatory; omission fails closed.
- `compiler.reconstruct(plan, admit_native)` returns the existing continuation factory shape. **Only pass the private, successfully completed job result**, never a UI/caller-supplied artifact or saved arbitrary generated text. `admit_native(cost, guard)` runs before native loading and guest effects, including on cache hits. It must reserve compile and shared-host credits, privately suspend on transient shortage, and refuse an atom larger than a fresh effective slice. The parent-owned guard needs this private suspension integration; the lane does not modify sandbox/continuation.
- Parent stores candidate cursors outside active state, schedules them across ticks, rechecks source/revision/principal before activation, and only then retires the previous run. Invalid candidates publish candidate diagnostics only. Stop/revision replacement cancels the old job and releases its owner.
- Parent removes source/name gates in save/editor/lifecycle and connects program, Console, validation and cold reconstruction callers. Existing synchronous APIs are not a fallback for an unfinished job.

## Required ownership and trust integration

`admit(job, peak_bytes)` is called before host-frame/native allocations and with zero on completed publication. It is a **pre-admission seam**, not a completed memory ledger. Parent must attach the cursor graph and source to a shared host-memory owner, reserve transient peaks, reconcile retained graph ownership, and release on cancellation/completion. It must not treat cumulative allocation estimates as live retained usage. The current peak hints (per-block, frame and native-call estimates) still need a complete allocation/alias audit; they are not verified upper bounds. Tests deliberately pass an explicitly named test-only workspace adapter, so they do **not** prove memory-capacity compliance.

Persisted private compiler frames also require the shared incremental trust/schema validator before production exposure. The current implementation checks cursor/build identity and program-counter existence, and reuses all guest grammar/trust validation, but this is **not** full hostile/corrupt compiler-frame validation. In particular, a saved emitted fragment must not become an independent executable authority. This needs resolution with the parent's private-record ownership/trust integration before shipping.

## Verification and regeneration

Run `python tools/compiler_build.py` in an environment containing `lupa.lua52`; no Python dependency is loaded or shipped by Factorio. Regenerate after changes to the Phobos sources, compiler validator, continuation lowerer, primitives or transform. `vendor/phobos/manifest.json` preserves upstream provenance and records the lexical cursor patch.

Packaged fixtures:

- `tests.compiler_jobs`: larger-than-former-source/token/node limits, 80 declarations, deep parser state, invalid programs, shell coordinates, copy-at-every-slice progress, exact charge trace equality, required memory-adapter refusal, and lazy reconstruction with normal versus one-byte cache allowance.
- `tests.compiler_jobs_token_cold`: a real cold save during tokenization.
- `tests.compiler_jobs_cold`: a real cold save during Phobos parsing.
- `tests.compiler_jobs_emission_cold`: a real cold save during continuation emission/liveness work.
- Cold fixtures compare final artifacts and total paid work against uninterrupted compilation, then execute the emitted native blocks through the existing ABI and assert one final effect.
- Existing `tests.compiler_cache_contract` and `tests.resource_policy_activation` protect synchronous cache/caller isolation and invalid-candidate preservation. Their passes do not claim the new pending-job lifecycle is integrated.

The native engine is authoritative for saved table traversal. A stock Lua 5.2/Lupa deep-copy run changed hash traversal/comparison work; the equivalent Factorio copy/cold checks are required rather than calling a stock-Lua clone a native-save proof. Full failure logs are retained with the lane's evidence.
