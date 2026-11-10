## Context

See proposal.md for the measurements. Current behavior:

- `compiler.run` calls `compiler.compile(plan.source, ...)` on every callback (`scripts/runtime/compiler.lua:295`). A paid run passes no admission context, so the call makes no charge. The call still does a lookup in a shared cache, and a miss tokenizes, parses, validates and syntax-loads the source.
- The shared cache is one FIFO of 8 entries for program and Console sources (`compiler.lua:258`). A hit does not move an entry. Nine distinct sources that take turns miss on every callback.
- A run scaffold already exists (`compiler.lua:273-282`). Its key is the computer record, run ID, generation and exact source string. It holds the host environment and the loaded program chunk. `registry` cleanup drops it.
- Each guest service that is not classified as stable calls `guard.invalidate_authority()` before its body (`scripts/runtime/environment.lua:246`). This drops the owner proof, the inventory proofs and the monitor availability proofs (`scripts/services/peripheral.lua:100`). `runtime.services` registers all `computer` methods without a classification (`scripts/runtime/computer.lua:347`).
- The peripheral provider already classifies its metadata methods with `guard.stable_service` (`peripheral.lua:287`).

## Goals / Non-Goals

**Goals:**
- No source validation on later callbacks of a run that has reusable scaffolding.
- No proof invalidation by the 14 listed `computer` methods.
- Identical results, errors, charges and refusals on warm and cold peers.

**Non-Goals:**
- A faster parser or validator. One validation stays at about 11.5 ms for a 1.6 KB source.
- Any cross-callback authority or topology cache. Each invocation still starts without proofs.
- Console command reconstruction. Each command still compiles its own text.
- Timer delivery, event copies, physical observation and other callback overhead.

## Decisions

### 1. Keep the validated handler set in the run scaffold

When a callback of a paid run finds a scaffold entry that matches (record, run ID, generation, exact source) and that entry has a loaded chunk, `compiler.run` uses the handler set that the entry holds. It does not call `compiler.compile`. The entry receives the handler set at the same point where it receives the loaded chunk, after a successful validation in this process.

The existing checks stay: retained handler names must equal the validated set, and the requested handler must be declared. An unpaid callback, a callback without an owner and a callback without a matching entry validate as they do now.

Why this is safe: the chunk in the entry came from a source that this process validated, and the entry key includes that exact source. The skipped call makes no charge for a paid run, so admission does not change. A peer without the entry validates one time and gets the same handler set, because validation is deterministic for a given source and runtime version.

Alternative: only change the shared cache (more entries or least-recently-used order). Rejected as the only fix: Console commands and activations still evict program entries, and each callback still pays a lookup and a plan copy. Alternative: store validated data in the save. Rejected: saved or caller-supplied executable data is never trusted.

### 2. Shared source cache capacity equals the active-computer limit

The FIFO capacity becomes `limits.active_computers` (64). After a load, the first callback of each running program then finds the entries that the other first callbacks made. The order stays first-in, first-out. Charges still replay from the retained trace, so warm and cold admission stay equal.

This is a process-local capacity, not a player-visible limit. It adds no setting and no `getLimits` field.

Alternative: keep 8 entries. The user selected 64. Alternative: remove the shared cache. Rejected: activation validates, the first callback validates again, and Console commands use the cache too.

### 3. Classify the 14 computer methods as stable

`runtime.services` calls `guard.stable_service` for a closed list of methods after it builds them. This is the mechanism that the peripheral provider uses for its metadata methods. A stable service does not call `guard.invalidate_authority()`. Each method still runs `current()`, which checks the guard and the owner proof identity on every call.

The list is explicit. A method that a provider adds to the `computer` namespace later stays unclassified. `computer.stop` is not a guarded service and ends the invocation. In a Console command, the host replaces `on`, `off`, `after`, `every` and `cancelTimer` with refusal functions. Those refusal functions stay unclassified, which has no effect on results.

Review of the proof assumptions (computer identity, body, generation, force, surface, execution owner, connectors, wire path, target scope, monitor member availability):

| Methods | State that they change | Effect on proof assumptions |
| --- | --- | --- |
| `getID`, `getLabel`, `getTick`, `getLimits`, `getState` | None | None |
| `setLabel` | Record label | None |
| `setState`, `deleteState` | Record state and its size counters | None |
| `log` | Console entries or the callback output buffer | None |
| `on`, `off` | Record subscriptions, saved topology-interest and monitor-recipient indexes, identity sequence | None. No entity, wire, owner or run changes. |
| `after`, `every`, `cancelTimer` | Record timers, deadline index, queued timer events, identity sequence | None |

None of these methods enqueue an event, so none can cause a queue-overflow fault that retires the run.

Work charges do not depend on proof reuse. The owner and connector checks make no charge. A reused inventory proof replays the charges of its walk. Monitor availability charges on every call. The contract test compares ledger totals to prove this.

Alternative: classify the whole `computer` namespace in `environment.lua`. Rejected: a future provider method would become stable without a review. Alternative: tell players to call `computer` methods before `wrap`. Rejected: the cost stays hidden for other programs.

### API impact

None. The `lua-api` artifact is deliberately skipped. No public declaration, argument, result, error or limit changes.

## Risks / Trade-offs

- [A later change makes a listed method change physical state] → The list is closed and the contract test names each method. The reviewed-boundary table in `docs/computer-runtime.md` records the review.
- [A scaffold entry gives a handler set for another source] → The entry key includes the exact source string, as for the loaded chunk. `tests/runtime_scaffold_engine.lua` covers a new run, a changed source and a cold peer.
- [The larger shared cache uses more Lua memory] → Each entry keeps the source string, a plan copy and a charge trace of at most 32768 numbers. Sixty-four full traces are about 32 MB in the worst case, compared with about 4 MB for 8 entries. Sources near the 16 KB limit make shorter traces than that bound. The memory is process-local and is not saved.
- [Warm and cold peers differ] → No charge depends on either reuse. Contract tests compare ledger totals, refusal points and effects for warm and cold runs.
- [The measured gain is smaller than the ablation] → Report matched baseline, candidate, baseline runs. Claim no gain beyond them.

## Migration Plan

No storage change. Old saves load unchanged. Rollback is a code revert.
