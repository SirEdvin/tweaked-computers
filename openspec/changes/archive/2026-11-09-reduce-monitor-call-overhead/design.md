## Context

See proposal.md for the problem. A profile of the `reduce-monitor-redraw-overhead` build, one 6×6 wall, gives per guarded monitor call about 100 µs instrumented: about 35 µs in the guarded service wrapper, 15 µs to find and check the peripheral, and 30 µs to write the grid. `peripheral.wrap` cost about 0.3–0.6 ms for each callback. Guest program code is native Lua and is not metered per instruction, so host charges and checks are the only per-call costs that this change can reduce.

## Goals / Non-Goals

**Goals:** less host time for each guarded call and for each monitor redraw, with the same results, errors, refusal points and work charges.

**Non-Goals:**
- Buffering monitor calls in the sandbox and replaying them at the end of a callback. The model already buffers drawing until after the callback. Deferral would move errors and budget refusals away from the call that caused them, and it would not remove the per-cell write cost.
- A batch or whole-frame write API.
- Caching across callbacks or ticks. A per-proof cache of resolved peripheral names was measured and dropped: it gave no measurable gain.
- Changes to the maintained examples.

## Decisions

### 1. Scalar fast path in `E.service`

When every argument is `nil`, boolean, number or string, the body makes the same snapshot charges and checks as `copy()` for one scalar (`spend(1)`, the finite/string checks, `spend(#value)` and the per-call byte ceiling), then calls the provider with the original varargs. A pooled frame per nesting depth replaces the per-call frame table; `transfer_result` still marks the current frame. Results are checked in place; the first result that needs a snapshot falls back to a packed copy from that position. `scoped` returns through a vararg helper instead of `table.pack`/`table.unpack`.

Alternative: skip the guard for monitor methods. Rejected: the guard isolates errors and restores the host string metatable.

### 2. Lazy facade methods

`E.lazy_namespace(make,label)` returns the same protected proxy and charges the same single namespace charge. An entry is built and labelled on first access. A protected proxy is empty either way, so `pairs`, `next` and `rawget` see no difference. Shell facades stay eager because they bind every method for later restoration.

### 3. Cheaper charges and proofs

The work-charge closure inlines `errors.integer` and `host_ceiling` and raises the same messages. `lifecycle.available` uses a shared `checked_port` (placement, ownership, scope) for each role and then reads both connectors, instead of calling `connector()` twice. For a layout-2 network role the port is the body itself, so the body's own checks replace the port's native validity and equality reads.

### 4. Cheaper grid and presenter work

`blit` validates its colours with `string.find(s,'[^0-9a-f]')`. The write loop uses a byte-to-index table and keeps the grid in a local value, refreshing it after the copy-on-write. The copy-on-write and the presenter's front copy use `{table.unpack(cells,1,n)}`. A delta frame sets `reused_all=true` and `render_cell` marks a changed cell `false`; cleanup reads `reused[index]`, falling back to `reused_all`. `render_cell` reads each native validity flag once.

### API impact

None. The `lua-api` artifact is deliberately skipped.

## Risks / Trade-offs

- [A fast-path charge differs from `copy()`] → It follows the same order and messages; a scalar at depth 0 cannot reach the node or depth limits (asserted at load). The full matrix includes the existing charge and refusal contracts.
- [A staged frame from an older version] → It keeps its complete `reused` table, and `reused_all` is absent, so cleanup behaves as before.

## Migration Plan

No storage migration. Rollback is a code revert.
