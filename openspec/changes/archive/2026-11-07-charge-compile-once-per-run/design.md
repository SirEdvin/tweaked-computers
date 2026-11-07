## Context

`compiler.run` validates the exact source on every callback. It replays the cached validation trace into the `compile` ledger, then reserves `#generated + nodes + 1` for reconstruction. The scaffold and the validation cache are process-local. Thus the charge must not depend on them.

## Goals / Non-Goals

**Goals:** charge compilation once per run, with identical charges on all peers.

**Non-Goals:** a mod setting to enable or disable this, a cache that survives a new run, changes to Console commands or to the first-callback refusal.

## Decisions

### 1. Saved marker on the computer record

`compiler.run` reads `owner.compile_paid == owner.run_id`. When the marker matches, it validates the source without a context (no charge) and skips the reconstruction reserve. Otherwise it charges as before and, after the reserve succeeds, sets `owner.compile_paid = owner.run_id`.

The marker is synchronized storage, so a late joiner or a reloaded save makes the same decision. A new run has a new `run_id`, so it pays again. A stale marker of an ended run never matches.

Alternative considered: a process-local cache with a runtime-global setting to disable it. Rejected: a cold peer charges differently, which desyncs in multiplayer.

### 2. Validation stays on every callback

Unmetered validation still checks the saved source before execution. Saved or caller-generated text is never executed.

## Risks / Trade-offs

- [A cold peer does real compilation work that no budget meters] → It occurs once per run and peer. The first callback of the run paid the full charge.
- [A refused first callback] → The marker is set only after the reserve succeeds, so a deferred or failed first callback pays again on the next attempt.

## Migration Plan

No migration. Old saves have no marker, so the first callback after the update pays once. Rollback is a code revert. An old version ignores the field.
