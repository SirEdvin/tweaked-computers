# Demand-driven monitor Lua API amendment

Normative companion to this change's [monitor-display delta](spec.md). This amendment preserves API version 1 and incorporates the complete existing [terminal method contract](../../../../specs/monitor-display/lua-api.md), [buffering and synchronization contract](../../../../specs/monitor-display/buffering-api.md) and [common authority/errors contract](../../../../api/common.md). It changes host work scheduling, not guest method signatures or model semantics.

## Public surface and exact results

All existing dot-call signatures, argument domains, Color/Colour aliases, glyph rules, clipping and per-call atomicity remain unchanged. No new `flush`, frame-control, queue-management, wait or polling method is introduced. No method acquires a hidden yield.

| Existing API | Exact result | Scheduling contract |
| --- | --- | --- |
| `m.write(text)`, `m.blit(text, foreground, background)` | Zero values | Validate and change the shared model before returning; coalesce presentation demand for the affected display/group. |
| `m.clear()`, `m.clearLine()`, `m.scroll(lines)` | Zero values | Preserve their current cell/cursor semantics and full-invalidation behavior where required; do not retain a command for later execution. |
| `m.setCursorPos(x, y)`, `m.setCursorBlink(enabled)` | Zero values | Preserve synchronous state and successful round participation, including valid no-ops. Native cursor blinking does not require recurring full-frame work. |
| `m.setTextColor(color)`, `m.setBackgroundColor(color)` and Colour aliases | Zero values | Preserve synchronous shared drawing state and participation; unchanged components need not be reconstructed. |
| Both documented overloads of `m.setPaletteColor(...)` and `m.setPaletteColour(...)` | Zero values | Preserve full validation, recoloring of stored color indexes and presentation invalidation; overloads and arity are not changed. |
| `m.setTextScale(scale)` | Zero values | Preserve the half-step domain, current dimensions, dimension-change clearing and resize notification; invalidate obsolete staging as required. |
| Existing monitor getters and `isColor()` / `isColour()` | Existing exact arity from the terminal contract | Read current shared model/state under existing guards, not a queued command result or an older visible image; do not drive rendering. |
| `m.getLimits()` | One defensive table | Preserve all existing keys/capacities and its reachable-but-unpowered availability. No new scheduling knobs or limits. |
| `peripheral.setMonitorSyncGroup(members)` | Zero values | Preserve atomic registration, canonical deduplication, explicit wire binding, idempotence, run/shell ownership and clear-on-empty-array behavior. |
| `peripheral.getMonitorSyncGroup()` | One defensive `MonitorSyncStatus` table | Preserve existing fields, status meanings, sequence/tick acknowledgement and diagnostics. Readback does not drive rendering or retry an authority proof. |

Read-after-write is still synchronous even when the world is displaying the previous complete image. A later rejected call or callback failure does not undo earlier successful calls. Existing validation, work admission, copy-on-write and refusal atomicity remain binding.

## Presentation demand and synchronization

- Snapshot sealing remains after synchronized callback dispatch, never inside a callback. The canonical buffering contract's post-dispatch offer is an eligibility boundary, not a requirement to enumerate every unchanged monitor each tick.
- Repeated writes before that boundary coalesce demand. The existing bounded newest-pending snapshot sits behind an admitted immutable frame; new writes cannot restart that frame indefinitely or create an unbounded per-call queue.
- A selected group still requires a successful mutating operation on every member after registration or the preceding seal. A successful no-op counts; getters and rejected operations do not. A no-op round retains its sequence/publication semantics without requiring redundant native sprite reconstruction.
- A group with incomplete participation does not time out, fabricate missing writes or partially publish. Other independent eligible displays retain deterministic fair service.
- A stopped writer leaves its last complete powered image visible. Running a program elsewhere does not wake settled monitors. Preparation, ready publication, backpressure recovery and retirement already in progress continue without requiring new drawing.
- Native settings paste, topology changes, power transitions and ownership release also cause the necessary work. Drawing calls are not the only invalidation source.

## Power, authority and physical changes

All tiles of a logical display must remain powered for active monitor operations. Outage hides presentation without erasing the model; restoration can show retained valid state without a dummy write or artificial resize. Existing admission and hide/restore timing are preserved; there is no new idle polling interval.

One minimal live observation path retains physical-change detection. It does not grant durable authority: calls, touches and publication retain their operation-specific checks for identity, force/surface/geometry, owned components, power and required paths, including the existing `getLimits()` power exception. Same-tick native changes must not reuse an earlier positive proof. Safe proof reuse within an operation known not to mutate physical state is unchanged.

Saved-program and Console selections retain their distinct principals. An idle Console selection must still be released after definitive path revocation even with the saved program stopped and no frame ready. Temporary incomplete proofs keep existing blocked/pending semantics; no silent wire fallback is added. Status reads report retained status under their existing contract rather than secretly retrying maintenance.

## Events, errors and limits

`monitor_touch`, `monitor_resize`, peripheral attach/detach and all existing payloads, ordering and deduplication rules remain unchanged. Committed geometry is readable when resize is delivered; touches never use obsolete visible geometry as if it were current. Deconstruction marking/cancellation is not actual topology removal and must not clear cells or invent a resize.

No new public error code is introduced. Existing `E_ARGUMENT`, `E_RANGE`, `E_UNPOWERED`, `E_UNREACHABLE`, `E_NETWORK_PENDING`, `E_BUSY`, `E_CAPACITY`, `E_LIMIT`, `E_NOT_FOUND` and unsupported-state handling retain their operation-specific meanings. In particular, ordinary queue backpressure does not turn an already accepted model update into a new guest-call failure or permit partial group publication.

Existing physical/model/selection, pending/staging/retirement, native-object, work and allocation ceilings remain binding. Frozen actual-tick maintenance reservations and spent credits survive repeated entry and cold load. This change does not raise limits to make a benchmark pass or promise zero-cost physical observation.

## Persistence and acceptance

Ordinary cold load preserves fronts, model state, selections, participation, pending snapshots and exact paid work. Upgrade from 0.1.16 initializes missing scheduling metadata through permitted synchronized work without executing guest code, clearing unchanged models or forcing unaffected complete fronts to rebuild. Unsupported retained representations stay recoverable and inactive rather than being silently reset.

Acceptance exercises burst writes, read-after-write, later failure, no-op participation, active and idle producers, settings paste, outages/restoration, same-event native mutations, idle Console revocation, topology/identity changes, all retained work phases and unchanged limits. Structural counters prove idle-work elision; matched 144-tile timing reports include both idle and active workloads without a fixed numerical performance gate. These checks do not by themselves establish graphical-client or connected-multiplayer acceptance.
