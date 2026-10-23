# Durable compiler jobs: quarantined integration boundary

**Not production complete. Do not connect OpenSpec 4.4 callers to this prototype.**
The public `compiler.advance` and `compiler.reconstruct` now fail closed with a
recoverable `E_UNSUPPORTED`, before reading a cursor, invoking an adapter,
charging work, loading text, or modifying source/state. This also refuses fresh
jobs: accepting only apparently fresh or well-shaped records would not establish
trust across subsequent ticks or cold loads.

Existing production `compile`/`prepare` callers are unchanged. They reconstruct
from source, not saved generated text. They are **not** a fallback selected by a
failed resumable job. No interpreter, restart/replay, fatal-budget substitution,
or larger resource allowance was added.

## Current caller contract

- `compiler.new_job(source, mode)` still creates the prototype's plain initial
  record (`mode` nil or `shell`); it is not executable authority. Its caller must
  own source/initial storage before creation. Do not enqueue new production jobs
  while the interfaces below are quarantined.
- `compiler.advance(job, context, admit)` returns
  `nil, {code='E_UNSUPPORTED', recoverable=true, message=...}` for every input.
  There is no `wait` status, adapter call, cursor traversal or partial progress.
- `compiler.reconstruct(plan, admit_native)` returns the same refusal, **not a
  factory**. A caller must inspect the diagnostic before calling a result.
- On refusal, retain the candidate source and previous active program; publish a
  candidate diagnostic only. Do not retry forever, silently discard accepted
  state, activate a partial artifact, or invoke synchronous compilation instead.
- `compiler-machine` and `compiler-artifact` are unvalidated prototype internals,
  **not alternate supported production entry points**. The public facade no
  longer imports the native artifact loader. Calling the raw modules bypasses
  the quarantine and is unsafe with saved/caller-owned state.

## Trust audit: why a schema check is insufficient

The prototype stores ordinary tables containing compiler lexical cells, captured
references, module values, function symbols, program counters, parser ASTs,
output strings, and prepayment/cost flags. The generated-build identity names
trusted static compiler blocks; it does not authenticate mutable saved operands.

Concrete bypasses in the pre-quarantine implementation:

1. `compiler-machine.advance` returns `job.result` before checking any frame.
   A forged current-build job with `native_checked=true` bypasses syntax checking
   too, and publishes arbitrary handlers, artifacts and source.
2. `compiler-artifact.factory` accepts caller-owned `artifact.blocks`, cleanup
   text and `native_cost` directly. Syntax checking is not trust validation:
   `function(_,r) r.untrusted_effect() end` is valid Lua. A saved expression need
   not even be a function literal; the reconstruction factory evaluates it.
3. Removing `result`/`native_checked` is insufficient. Saved emitter locals,
   captures, return tuples or an intermediate output accumulator can be forged
   to produce the same arbitrary text from a valid static program counter.
4. Malformed stack/tuple/iterator/cleanup cursors can cause host errors before
   the per-block protected call. Saved `paid`, `debt`, `wait_tick` and native-cost
   fields can also bypass work or suppress progress. A function/metatable scan
   alone does not validate any of these semantic relationships.

A native Factorio regression reproduced acceptance of the forged completed job
before the quarantine. The new hostile fixtures check **refusal**, not pretend
full validation. A process-local trusted-object cache disappears on cold load;
a hash supplied in the same mutable save is not independent authority. Replaying
compilation to compare all saved state would invalidate the promised exact paid
progress contract. A safe durable design must establish complete control/data
invariants and regenerate native text only from a validated, restricted
representation, rather than treat arbitrary saved Lua strings as authority.
That redesign/proof is not implemented here.

## Allocation audit: no production adapter yet

The old `admit(job, peak_bytes)` callback is only a hint seam. Its constants and
work-unit estimates are **not** actual retained graph or temporary accounting:

| Boundary | Missing coverage |
| --- | --- |
| Generated compiler blocks | Direct table construction, lexical-cell allocation and table/slot writes; a fixed 128-byte hint cannot describe every mutation. |
| `frame`, `r.closure`, `join`, `r.append` | Capture-cell aliases, parameter/vararg and return tuple storage, appended entries, and transient vectors; some copies loop without per-entry admission. |
| Native primitives | Input/output and temporary coexistence, tuple packing, formatting expansion and match captures; work costs are not byte bounds. Some special/protected calls bypass the growth hint entirely. |
| Syntax verification | `load('return '..text, ...)` creates joined text and native compiler workspace without a memory reservation. |
| Reconstruction/cache | Factory/closure/cleanup tables and native function storage; source character counts do not measure native compiled-object storage. Eviction alone is not a temporary-peak proof. |
| Completion/cancellation | The zero-byte callback neither transfers graph ownership nor releases aliased retained objects/reservations. |

Before reopening the facade, the compiler and parent need an actual allocation
interface, not a renamed estimate callback:

- Resolve a private owner through synchronized host context; do not save mutable
  shared ledgers inside compiler frames. Reserve initial source/cursor ownership
  before publishing a job.
- Instrument every allocation and graph mutation in the transform/primitives.
  Prepay replacement/growth before publication, reconcile actual retained
  graph/aliases, account temporary overlap through release, and prevent a failed
  primitive from leaving unaccounted retained prefixes.
- Make validation/reconciliation itself resumable and charged. Saved validation
  readiness is not proof; validate it before trusting it.
- Admit native loading and live reconstruction workspace, including cache hits,
  **before guest effects**. Keep cold/warm work decisions identical. An atom that
  cannot fit a fresh configured slice must produce an actionable resource refusal,
  not endless waits. Native allocation bounds require evidence, not text-length
  substitution.
- On cancellation/revision replacement, release the private owner and all
  reservations. Before activation, recheck source/revision/principal and transfer
  ownership atomically; only then retire the previous run.

No implemented production adapter satisfies these requirements. Do not install
a no-op adapter or advertise a completed ledger integration. The old dedicated
fixtures' `test_workspace` functions only measured transform behavior.

## Authorized guard changes

The compiler identifier-byte guard is removed from the synchronous validator and
its regenerated durable transform. Reserved names and native grammar remain.
`parse_admission.push` now uses the existing configurable `host_stack_depth` and
returns `E_CAPACITY`; the arbitrary `source_nesting` setting is no longer consulted
there. Synchronous emitter recursion retains its host-depth protection. Static
transformed compiler frames do not consume the recursive host stack, so no guest
nesting/count cap was added to them. Other lanes own noncompiler name/data gates.

## Regeneration and evidence

`tools/compiler_build.py` uses development-only `lupa.lua52`; no Python dependency
is shipped by Factorio. Regenerate after compiler validator/transform/source
changes. Checked-in `compiler-generated/*.lua`, `identity.lua` and `manifest.json`
record transformed-source/output hashes. `vendor/phobos/manifest.json` preserves
the pinned upstream revision and tokenizer cursor patch. No vendor source changed
in this audit.

- `tests.compiler_policy_guards`: long public/local/shell identifiers, reserved
  names, obsolete nesting independence, real host-depth refusal and recovery.
- `tests.compiler_cursor_trust`: forged completed results/costs, malformed
  frames/scalars, stale builds, cycles, metatable traps and fresh cursors all
  refuse without reaching admission or execution.
- `tests.compiler_cursor_trust_cold`: a real cold saved cyclic cursor with a
  forged completed fragment remains unchanged and has no execution authority.
- `tests.compiler_cache_contract` and `tests.resource_policy_activation` continue
  to cover the existing source-based callers; these are not durable integration
  acceptance.
- The unchanged `tests.compiler_jobs*` success fixtures are deliberately **blocked
  by the quarantine**, not rewritten to use raw internals or a test bypass. Their
  previous transform/cold passes remain historical evidence only.

Evidence root for this audit:
`/home/siredvin/artifacts/tweaked-computers/compiler-trust-2026-10-23-BFcnmL/`.
`guards/` contains pre-quarantine base/Space Age guard, large/copy/cache-transform,
and parser-cold passes on engine 2.0.77; `unsafe-repro/` preserves the native hostile
failure. Final quarantine receipts must be evaluated separately. The preliminary
`--production-context` cold attempt was unsupported by the harness; the successful
parser-cold run used the isolated fixture context, not production ownership.

OpenSpec completion, production lifecycle wiring, actual graph/temporary
accounting, full semantic saved-cursor validation and connected late joining
remain unverified/unimplemented. This quarantine is a safety fix, not delivery of
the original durable-compiler feature.
