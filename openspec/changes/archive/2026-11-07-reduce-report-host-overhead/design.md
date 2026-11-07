## Context

See proposal.md for the profile. The measured per-report costs are:
- `peripheral.find`: 259 µs. The network walk is 196 µs of this.
- 20 × `print`: 279 µs. The Console append is 53 µs of this.
- `readSignals`: about 115 µs.
- Timer enqueue: 93 µs.

Current `print` in a saved program (`scripts/runtime/environment.lua`) does these steps:
1. Enters one guarded host scope.
2. Charges `n+1`, converts the arguments, then charges `bytes+1`.
3. Calls the bound output sink in `scripts/runtime/computer.lua`. The sink checks the owner, charges `log_work` (`4`, plus `3 × entries` when the Console is full), and calls `M.log`, which evicts immediately.

`computer.log` is a guest service with its own guarded scope and charges.

Discovery (`network.walk`) does a breadth-first walk of the mod's own devices on every callback. It reads `connector.owner`, `entity.force`, `entity.surface` and the registry several times for each vertex and each edge target. Factorio 2.1.23 has no wire connect/disconnect event, so a wire edit can occur silently between callbacks. `LuaControl.force_index` and `surface_index` exist in 2.1.23.

## Goals / Non-Goals

**Goals:** less host time on report callbacks, with the same guest-visible results, order, refusal codes and synchronized state.

**Non-Goals:**
- Console command output or charges.
- Caching `readSignals` results.
- The timer enqueue path. It is measured, but its cause is not yet split out.
- Any saved cache.
- Any cross-callback topology cache (see decision 3).
- New settings or limits.

## Decisions

### 1. Per-callback output buffer for saved programs

The program output sink appends `{text, tick}` to a process-local buffer owned by the callback. Both `print` and `computer.log` use the same sink, so their relative order stays the same. `compiler.run` flushes the buffer in every exit path before it returns: success, guest error, stop and host refusal. Thus `runtime.fault`/`retire` entries still follow the program's output. Each direct `M.log` call first flushes any pending buffer for that record. A missed flush can then not reorder entries.

The flush appends all entries, then evicts the oldest entries until the existing entry and byte limits hold. Sequential appends always keep the longest suffix that fits the limits, so the final entries, byte count and truncation flag are identical. While the callback buffers, the buffer drops its own oldest entries when they could not survive. This keeps retained memory within one Console of data.

Alternative: flush only on success. Rejected, because output from earlier successful prints must survive a later fault.

### 2. Two charges per program print

`print` keeps its `n+1` charge before any native conversion. The existing contract refuses number formatting before host admission. A single charge would need the byte count first, so it would convert before admission. The user chose to keep the pre-conversion charge. After conversion, the sink makes one charge: `(bytes+1) + 4`. The first entry that overflows the buffered Console in a callback also pays a one-time eviction charge of `3 × retained entries`. The output sink no longer charges. The owner check stays on every print. `computer.log` keeps its service charge, plus the same entry and eviction rule.

A refused charge publishes nothing. The callback fails with the existing error at the same print.

Alternative: one charge after conversion. Rejected, because it lets native conversion run before admission. Alternative: keep three charges. Rejected, because the merged sink charge removes one charge and the second guarded call for each print.

### 3. Verified topology reuse in discovery: measured and dropped

The plan was a process-local graph per computer and wire. Each callback would verify every vertex and edge of the graph, in order, against the live wires before reusing it. A registry/settings change would invalidate it early, and the walk's charge trace would be replayed. Factorio 2.1.23 has no wire connect/disconnect event, so the verification is required on every use.

A prototype of that exact verification was measured on 2.1.23 with a computer wired to one logic handler, 2,000 hot iterations each:
- `network.discover`: 35.7 µs.
- Verification of the cached two-vertex graph: 24.2 µs.

The verification still needs `lifecycle.connector` (about 4.2 µs) and `real_connections` (about 4.4 µs) for each vertex, and these dominate the walk. Reuse therefore saves about 11 µs hot, roughly 5% of a report tick. That does not justify a second graph structure, invalidation and charge replay. The rest of the in-game discovery cost (about 180 µs) appears to be cold-cache/GC overhead, which a cache does not remove. The user approved dropping reuse.

### 4. Cheaper fresh walk

`discovery_vertex` and `same_scope` read `connector.owner` once for each vertex and compare `force_index` and `surface_index` instead of creating `LuaForce`/`LuaSurface` wrappers. The walk keeps the record from the edge validation that accepted a vertex, so a vertex is not validated a second time when it is dequeued. It also skips validation of targets it has already seen. Native state cannot change inside the walk, so the results do not change. The visit order, charges and errors do not change.

### API impact

None. The `lua-api` artifact is deliberately skipped. No public declaration, argument, result, error or limit changes.

## Risks / Trade-offs

- [Buffered output stays invisible if a host error escapes `compiler.run`] → The flush is in the shared exit path, and `M.log` flushes pending output first. Contract tests cover a guest error and a stop after print.
- [The charge prefix of a refused print changes] → This is accepted (decision 2). Contract tests assert that a refused print publishes nothing and that the callback fails at the same print.

## Migration Plan

No storage change. Buffers are process-local, so old saves load unchanged. Rollback is a code revert.
