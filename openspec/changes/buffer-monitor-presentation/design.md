# Design

## Context

See [proposal.md](proposal.md) for motivation and the two capability deltas plus [Lua contract](specs/monitor-display/lua-api.md) for observable behavior. This document proposes implementation; no renderer experiment or new runtime behavior has been executed as part of planning.

### Observed local behavior

- The current pre-change implementation in `scripts/monitor-model.lua:3-5` limits logical groups to 4×4 tiles, 4,704 cells per screen, 80,000 aggregate cells and 1,024 rendering checks/tick. The unchanged geometry formula at lines 26-27 gives a proposed 6×6 display 63×42 cells at scale 1 and 126×84 at scale 0.5. Four scale-1 6×6 screens and one scale-0.5 6×6 screen each total 10,584 cells; that is the revised per-publication envelope, not a claim about the old implementation.
- Existing mutators update plain terminal cells and revision synchronously. Writes replace cell records, palette setters replace palette triples, scroll constructs a replacement array and clear replaces the grid (`scripts/monitor-model.lua:74-140`). This is a useful starting point for immutable roots, but every mutation route must be audited before sharing arrays.
- `scripts/rendering.lua:40-58,109-119` reads live `g.model`, destroys visible old cell objects and creates visible replacements while sweeping. Its revision checks avoid falsely acknowledging a mixed sweep, but do not preserve a complete visible front frame while rendering catches up. Cursor updates read the same live model separately.
- The renderer reserves 60,000 maintenance units (`scripts/rendering.lua:11`); scheduler maintenance is shared and durable within the actual tick (`scripts/scheduler.lua:17-35`). Dispatch precedes the render phase at lines 152-160. Per-call model commits already survive later callback failure; do not replace that contract with a transaction.
- `scripts/services/monitor.lua` owns group reconciliation, scale changes, resize/touch notifications and authentic peripheral registration. `scripts/services/peripheral.lua` owns current network proof, facade/run guards and revocation hooks. Logical IDs are not physical registry tile IDs: reuse its checked logical resolver.
- Grouping signatures currently contain tile identities/scope/positions but no policy version (`scripts/services/monitor.lua:45-49,117-127`). Raising the dimension constants alone does not invalidate an unchanged saved wall. The six-tile policy needs paid explicit reconciliation and matching migration tests, not just a new maximum constant.
- Existing `tests/monitor_engine.lua:161-186,235-257,267-321` exercises native sprite objects, palette/outage restoration, maximum grids, mixed sweeps and separate-process retained progress. `tests/monitor_feedback_engine.lua` covers native feedback and interaction. Extend these paths rather than replacing them with a second fake renderer.
- The external user example at `/home/siredvin/releases/tweaked-computers/examples/plot-all-monitors.lua` deliberately writes four rows every five ticks and finishes one screen before selecting another. That producer behavior is separate from the renderer's sweep; renderer buffering alone cannot remove its application-level intermediate images.

### Pinned CC:Tweaked investigation

Reference source: tag `v1.20.1-1.120.2`, commit `c3cfb206de28769c81ee45a44ad9fcf741cc7091` in `cc-tweaked/CC-Tweaked`. These are inspected source observations, not a claim of current-release compatibility.

| Primary source at that commit | Finding used here |
| --- | --- |
| `projects/core/src/main/java/dan200/computercraft/core/apis/TermMethods.java:39-45,254-265` and `core/terminal/Terminal.java:168-187` | Lua writes/blits mutate terminal text/color buffers and mark changes; they are not framebuffer presentation commands. |
| `projects/common/src/main/java/dan200/computercraft/shared/peripheral/monitor/MonitorPeripheral.java:46-110` | Monitor reuses terminal methods and adds text-scale access. There is no monitor flush, swapBuffers or begin/end-frame API. |
| Same directory, `ServerMonitor.java:64-83` and `MonitorBlockEntity.java:137-138` | Dirty notifications are coalesced and handed to monitor update scheduling. |
| Same directory, `MonitorWatcher.java:25-30,47-81` | The watcher deduplicates queued monitors, snapshots terminal state and sends whole monitor states subject to bandwidth. Queueing is per monitor, not a multi-monitor presentation transaction. |
| `projects/common/src/main/java/dan200/computercraft/shared/computer/terminal/TerminalState.java:18-45` and `shared/peripheral/monitor/ClientMonitor.java:57-68` | Snapshot data and client application are distinct from producer writes. |
| `projects/common/src/client/java/dan200/computercraft/client/render/monitor/MonitorBlockEntityRenderer.java:133-188` | Client rendering rebuilds GPU buffer contents when the received terminal changes. Factorio does not expose that backend to this mod. |
| `projects/core/src/main/resources/data/computercraft/lua/rom/apis/window.lua:172-186,472-507` | Hidden windows keep Lua-side line buffers; reveal/redraw forwards rows, palette and cursor to the parent terminal. This is optional composition, not native monitor frame control or a cross-monitor barrier. |

Source browser base: `https://github.com/cc-tweaked/CC-Tweaked/tree/c3cfb206de28769c81ee45a44ad9fcf741cc7091`. Factorio reference: `https://lua-api.factorio.com/2.0.77/runtime-api.json`; the locally inspected schema declares `LuaRendering.draw_sprite.visible` and writable `LuaRenderObject.visible` as booleans. This establishes supported hidden creation/toggling, not the CPU cost or observed client-frame guarantee of a large swap.

Borrow the separation of model, coalesced snapshots and presentation. Do not copy/vendor upstream Java, Lua, fonts or shaders; the inspected files have mixed MPL-2.0/CCPL notices. Keep the independently implemented terminal/glyph policy and no-new-dependency scope.

## Goals / Non-Goals

Current acceptance override during apply: the user explicitly deferred graphical and multiplayer-client validation and authorized finishing implementation and uploading the next alpha for their review. References below to the original native-client rollout gate document the original plan, not a remaining prerequisite for this authorized alpha. Keep client/peer tasks unchecked and `client_verified=false`; do not weaken automated resource, coherence, lifecycle or compatibility checks.

**Goals:**

- Make automatic buffering the normal path behind unchanged terminal drawing methods, and retain shared synchronous model semantics.
- Support all 36 complete rectangular tile sizes with each local axis in 1..6, all supported scales/orientations and heterogeneous cohorts through one geometry-driven buffer path.
- Give renderer work an immutable input and a complete visible front frame, with bounded newest-pending updates behind admitted work.
- Offer a selected-group barrier without conflating it with a producer's animation clock or inferring finish boundaries from timer intervals.
- Keep preparation, admission, native visibility changes, snapshot retention and retirement observable and charged to existing budgets.
- Prove the native backend before expanding implementation; compare producer, preparation and actual publication timing separately.

**Non-Goals:**

- CraftOS, the CC `window` module, Lua redirection, manual frame/flush APIs, graphics textures/shaders or a new scripting backend.
- Physical dimensions above 6×6, one irregular/L-shaped framebuffer, unrestricted synchronization groups, higher callback/shared host ceilings or a 60-FPS promise.
- Guaranteed wall-clock/client latency under arbitrary worlds, or automatic recognition of a completed multi-callback plot.
- Rewriting GUI controls, artwork, the general scheduler, existing unrelated OpenSpec changes, packaging policy or releases.

## Decisions

### 1. Automatic terminal snapshots, not explicit frame transactions

Seal eligible terminal state after callbacks in the existing synchronized render phase. Preserve model mutation order even if a later call fails. Group cancellation on run fault does not erase earlier successful shared model writes; they can subsequently present through the ordinary path.

Use immutable cell/palette records and bounded copy-on-write array roots. A sealed snapshot stores the model revision, cells root, palette/settings, cursor state and a captured geometry/identity stamp. The next mutation of a shared cells root must reserve its bounded copy cost before changing the authoritative root or any logical state. Clear/scroll can install their already-required new arrays. Palette triples must remain immutable. Do not deep-copy the full grid on every character write or at every render check.

Raise the physical cap to six tiles on each local axis and derive per-display cells from the actual geometry formula, with 10,584 as the maximum at scale 0.5. Do not introduce shape presets or allocate a maximum-square backing store for every display. Use each snapshot's width for row strides and clipping, its own scale/palette/cursor metadata, and the captured affine transform for every cardinal orientation. A 3×6 and a 6×3 display have different character grids despite equal tile area; neither dimension nor cost can be inferred from area alone. Mixed cohorts capture independent member geometries and add actual cell counts for admission.

The larger cap requires reviewing partition candidate-walk charges, retained model creation, power-member validation, COW/clear/scroll/scale costs, save representation and aggregate admission as well as rendering. Preserve the existing world tile/model-cell ceilings; topology and model jobs must defer with paid progress rather than assuming four large rectangle constructions always fit one maintenance quantum.

Snapshot creation/root pinning, first-write copies, new cell/metadata records and release bookkeeping all need explicit cost/retention accounting. Validate operation arguments and the complete required admission before publishing any model/COW/dirty changes. A rejected call must preserve cells, cursor, palette, revision and presentation bookkeeping, not just visible bytes.

Record successful mutator participation separately from visual differences: an unchanged setter can advance a selected group's round, while getters cannot. Detect unchanged visual state to avoid needless sprite recreation. Working model state and displayed snapshot acknowledgement are separate concepts.

Alternative rejected: adding mandatory `beginFrame`/`endFrame` to existing monitor methods. CC's monitor API does not use those, the user selected automatic behavior, and existing programs should not need a flush just to gain render coherence. An invisible-window library would be a different composition feature and does not solve native publication by itself.

### 2. Bounded pipeline with no restart starvation

Pipeline:

```text
successful model mutations
    -> singleton dirty snapshots OR selected-group participation barrier
    -> newest pending immutable snapshot/vector
    -> admitted immutable preparation job(s)
    -> completely hidden replacement objects
    -> whole-publication preflight + credit reservation
    -> same-tick visibility/pointer publication
    -> bounded retirement of obsolete exclusive objects
```

Each screen belongs either to its owner's explicit cohort or to its ordinary singleton lane, never both. For a selected cohort, all members must participate since registration/last seal. Capture their current roots together only at a post-dispatch boundary; reset participation then, not at display acknowledgement. Keep at most one newest pending vector for a cohort behind admitted preparation. New pending vectors can supersede each other; an admitted vector finishes instead of being restarted on every revision change.

Admitted staging cell slots across all jobs total at most 10,584, enough for the largest single supported display or four 6×6 scale-1 displays. Each job consumes only its actual grid slots. Allow several smaller or mixed-shape jobs in that same aggregate allowance; do not impose one job or one publication per tick. Pending snapshot vectors across all screens are bounded by the existing aggregate model-cell capacity. Keep a deterministic rotating eligible-cohort order and paid durable preparation/cleanup cursors. Preparation and retirement share the 1,024-cell-check ceiling, with positive fair service for both when both have work. Whole commits have separately bounded native-operation costs, charged to the same maintenance ledger. A full staging/retirement queue causes backpressure, not extra hidden generations or guest-data truncation.

Full-cell palette/geometry changes are bounded invalidations; sparse ordinary changes should retain/reuse unchanged immutable cell render records where this reduces work. A candidate must not mutate any object still used by the front frame. If unchanged records are shared, publication and retirement must transfer their ownership without hiding/destroying them. Keep a flat bounded candidate representation, not an unbounded chain of overlay generations.

Alternative rejected: rendering from a live model plus restarting a sweep on every revision. That either shows mixed rows or starves publication under a fast producer. Retaining every historical frame is also rejected: newest-pending coalescing is explicit, like a display rather than a lossless event log.

### 3. Hidden native objects plus a prepaid same-tick swap

Create every replacement background/glyph/cursor with `visible=false`; do not depend on setting it hidden after a visible default construction. Retain the current complete front frame while new objects are built over ticks. Draw cells using captured geometry/palette, not `g.model` read again during preparation. Cursor and blink objects belong to the same frame; unchanged displayed cursor blinking can continue normally while preparation is hidden.

There is no Factorio rendering-group toggle or GPU upload API to assume. A commit must toggle individual old/new exclusive objects. Preflight identities, geometry, power, current selected-path witnesses, every affected object and the full work/native-operation count; reserve the whole remainder before the first visibility mutation. After admission, run the finite no-yield visibility loop and pointer/acknowledgement updates without further budget checks that could throw halfway. Do not allocate draw objects, call guest code, discover topology, or perform fallible incremental copying inside that loop. Retire old objects afterwards rather than destroying them on the commit path.

Proposed single-publication maximum is 10,584 actual cells and at most 42,352 old/new visibility operations, conservatively four cell-object toggles per cell plus old/new panel/cursor allowance for four members. The existing 60,000-unit render reservation is a baseline, not proof that a larger commit fits. The first implementation gate must derive a finite whole preflight/commit ceiling and, if needed, rebalance the one render reservation within the unchanged 200,000-unit shared maintenance ceiling. It must prove non-render lifecycle/network/notification progress as well as commit admission; do not simply reserve the entire ledger or rescale cost coefficients to make the result pass. Include worst-path authority validation and actual native CPU/client evidence. A single scale-0.5 6×6 monitor and four scale-1 6×6 monitors remain required supported cases, not optional fallbacks to smaller dimensions.

If a ready commit cannot fit the remaining ledger, leave every old object visible and every replacement hidden, retain its exact job and rotate fairly. Same-tick repeated dispatch/load must not renew credits. Use the one measured render reservation within the unchanged shared maintenance ceiling; do not manufacture a second renderer budget or split a single published frame to fit.

Alternative rejected: an O(1) cells-table swap followed by incremental visible rendering. That is atomic model publication, not atomic world presentation. Increasing the sweep size or raising quotas similarly fails the hard-bound requirement. A native client gate must show that one synchronous event's complete visibility change produces the intended visual result; headless booleans alone are insufficient evidence of that result.

### 4. Small explicit selection API, shared writing unchanged

Add the two methods in the Lua contract to the existing `peripheral` service factory. Delegate monitor-specific admission/readback through a fixed host registration/binding following the existing provider/revocation patterns; avoid introducing a circular require from the peripheral service back into the monitor service. Keep orchestration in the existing monitor/render modules unless an extracted plain-data helper is actually necessary. Do not add a general-purpose transaction framework or guest plugin registry.

Keep one selection per `(computer_id, run_id)` and one explicit group per logical monitor. Validate all supplied red/green paths before deduplication, retain canonical red preference, sort by logical ID and store plain identity/generation/path records. Same canonical membership is idempotent; changed membership replaces atomically after all checks, cancelling the old unpublished cohort as a whole. Reject overlapping explicit groups with E_BUSY, but never reject another authorized computer's ordinary writes merely because a group exists. Any authorized successful mutation can satisfy a member's participation.

Use existing live discovery and checked logical inventory resolution for registration; use bounded current witness validation immediately before publication. A host-only monitor validation/sealing binding can be invoked from the existing render hook so capture/preflight share the correct end-of-dispatch boundary without depending on a new alphabetic phase-hook order. These host bindings remain ephemeral code, not stored callbacks.

Persist only bounded plain configuration/progress and Factorio-supported render handles. `getMonitorSyncGroup()` returns copied status, not a facade, cells array, capability to unselected peers or native object. Status distinguishes waiting for producers from queued preparation and temporary blockage; sequence/tick acknowledge the actual visibility swap, not a model write or completed cell scan. No additional event type is needed.

Alternative rejected: automatically treating every physically reachable monitor as one group. That would synchronize unrelated programs, cross the supported cohort capacity and change default behavior unpredictably on discovery. Selection is explicit; buffering itself is automatic.

### 4a. Demand-driven headroom and resumable topology initialization

The user approved this revision after the native probe demonstrated a 147,384-unit publication/path cost and insufficient remaining headroom for the old atomic topology initializer. Preserve that failed measurement as baseline evidence rather than changing its accounting to pass.

Keep the existing 60,000-unit baseline render reservation. A trusted presenter can request a finite next-tick demand, capped at 160,000 within the unchanged 200,000-unit maintenance ledger. Freeze the effective reservation at the first maintenance admission of each actual tick; later demand changes affect only a later tick. Persist the request, frozen reservation and last boosted tick so same-tick entry or cold load cannot create new headroom or credits. Permit a boosted reservation at most once every two actual ticks, ensuring at least one baseline-reservation opportunity between boosts, even if a stale ready request remains pending. The renderer still must reserve its entire actual publication before its first visibility mutation; a boost is headroom, not permission to exceed the ledger or acknowledge an uncommitted frame.

Split topology initialization into durable bounded indexing, ordering and rectangle-construction stages before the existing staged model construction/publication. Retain only plain records, arrays, maps and cursors. Each mutation is prepaid; credit refusal preserves the next unprocessed step. Avoid a large all-at-once sort charge by using bounded resumable ordering on the at-most-256 tile inventory. Include policy identity/dimensions in grouping signatures, accept compatible already-staged legacy jobs or invalidate them deterministically, and leave committed models/identities untouched until complete publication. Ordinary load performs no initialization or credit reset.

Verify worst-path publication against the actual scheduler, alongside real topology work, notifications/cleanup and a running neighbor. Retain baseline-service opportunities under continuous demand, prove eventual topology publication, and exercise a cold save mid-initialization with spent credits. This scheduler/topology foundation does not itself enable production buffering or enlarge merged displays before the client gate. Graphical acceptance remains required and is not waived by this revision.

### 5. Capacity, invalidation and retention stay fail closed

Proposed cohort/input/staging limits are in the Lua contract. Derive finite effective retained-cell and native-object caps before implementation rollout, including authoritative models, displayed snapshots, pending vectors, admitted staging, invalid fronts and retired objects. Current 80,000 model cells are not a complete memory bound once buffering is introduced. Retired slots total at most 10,584 and actual retirement uses each frame's own geometry; when that queue is full, invalid old fronts remain explicitly accounted as owned fronts until admitted retirement, rather than escaping the count or triggering an unbounded teardown batch. Topology changes must respect these limits while reconciling many screens.

Power loss hides the affected display and blocks replacement group publication while retaining model/front data. Owner-computer outage suspends its selection without retiring its run. Source stop/fault/replacement/removal or definitive selected-path/identity revocation releases the entire selection with a bounded diagnostic; its old visible images/models remain. Released accepted models can later present independently. That is cancellation of an unpublished group epoch, not successful partial publication. Temporary proof exhaustion blocks instead of being misclassified as permanent detach.

A scale/topology/rotation change invalidates affected frame stamps and resets participation. Keep valid model resize/notification semantics; if a retained group now exceeds combined cells, block it with E_CAPACITY rather than rejecting a valid scale, splitting silently or publishing part. Old-geometry output may hide while invalidated. Ignore world touches when visible and authoritative grid geometry differ, preserving the existing transform/reach/power/force/Ctrl-click rules whenever they agree. Do not publish stale geometry after a later rebuild or retarget absorbed IDs.

Cleanup must never depend on a guest handler and must be resumable/admitted. Preserve selection/wiring/deconstruction layers from the redesign; hidden staging uses the same audited layers and cannot cover world feedback. Removal, surface/force changes and invalid native handles must not leak either generation.

### 6. Persistence is a versioned presentation upgrade, not an on-load rebuild

Add a versioned presentation subrecord rather than silently changing the meaning of existing sweep fields. Keep the authoritative terminal model representation compatible where possible. Existing pre-buffer saves retain models except where a grouping-policy resize requires the normal documented clear; retain/account their old rendering handles until paid migration/retirement, never perform that work on load. A legacy partial sweep is not a coherent frame to acknowledge: hide/retire it under admission and present a newly prepared complete model snapshot. Do not clear an unchanged-geometry durable terminal or rerun start merely to reconstruct presentation.

Version or otherwise include the six-tile grouping policy in reconciliation identity. On upgrade, invalidate obsolete partition decisions and incompatible staged grouping jobs through admitted synchronized work even if the tile signature is otherwise unchanged. Repartition existing 3×6/6×6 walls using the established deterministic anchor rule, inheriting settings and emitting normal detach/resize effects; changed character dimensions clear the resulting buffer. Unaffected displays must not receive synthetic resize or clearing. Repeated ordinary loads must not keep regrouping an already-upgraded wall. Preserve a backup and explicitly document the content/identity consequences of these geometry-changing merges.

Persist immutable snapshot roots/metadata, group ownership/participation, preparation and retirement cursors, last acknowledgements and spent maintenance state. Ephemeral drawing/validation functions are reconstructed at control parse. Ordinary on_load may register/rebind code only, not mutate storage or perform native rendering/source execution. Unknown retained versions stay recoverable/inert rather than being coerced into empty screens.

Alternative rejected: discarding all render state on load and redrawing immediately. It loses exact progress, can reveal staging, renews work and creates a native-work spike.

### 7. Performance and the plot remain distinct acceptance gates

First prove one scale-0.5 6×6 screen and four scale-1 6×6 screens with real render objects and unchanged callback/shared host ceilings, including the measured render-reservation balance. Check all 36 W/H combinations at all ten supported scales and four orientations (1,440 fast geometry/model cases). Use native representatives 1×1, 1×6, 6×1, 3×6, 6×3 and 6×6 plus a mixed-size cohort to verify real grouping, row strides, sparse/full repaint, clipping, cursor/palette, resize and retention; do not replace that with only square samples. Measure accepted producer work/allocation, snapshot/COW work, preparation checks, native creates/visibility writes/destruction, maximum retained slots, ready-to-visible ticks and complete scheduler cost. Under stable geometry/power/authority with all participants ready, test the existing 256-tick quiescent target at full admitted world size. Preserve failed gates; no unannounced larger aggregate ceilings or reduced size/four-screen target.

For the player plot, measure the existing exact 4×4 example as a retained historical baseline. Add an improved shared-phase/delta-drawing example that derives each monitor's plot dimensions from getSize, updates selected 1×1/3×6/6×6 or other admitted mixed-size screens within measured producer limits and handles both colors, logical deduplication, additions, disconnections and resize. Choose the actual row/delta strategy from those measurements rather than assuming that an all-screen full redraw fits one callback. An example's app-level complete frame is only claimed if it really finishes its intended changes before the relevant round seals; if guest production cannot do that under unchanged limits, report the blocker rather than introduce an unapproved manual-frame API or claim buffering solved it.

Headless tests can prove snapshot identity, same simulation publication tick, real hidden/visible native objects, quotas and cold progress. A graphical client must separately inspect dense repaint, palette/cursor animation, the synchronized plot, selection/wiring/deconstruction readability and touch behavior. A multiplayer peer pair is required before claiming peer-visible synchronization/determinism. Lack of those clients is an explicit pending acceptance item, not a reason to mark a visual release gate complete.

## Risks / Trade-offs

- [Large native visibility loops can be costly despite bounded work units] → Run the small native backend gate before broad integration; preserve the four scale-1 6×6 and single scale-0.5 6×6 targets, prove render/non-render reservation balance and stop for a design decision if they fail.
- [More snapshot/object residency] → Count all roots/generations, use immutable records/COW, share unchanged front records safely, and apply staging/retirement backpressure under explicit caps.
- [A stale/static group participant can hold the entire animation] → Require explicit membership, expose waiting status, document no-op participation and never silently time out/split.
- [Producer batches are mistaken for rendering tearing] → Separate application-frame and snapshot semantics in API/docs and compare the old and improved exact-source plot in real production ticks.
- [Newer writes or invalidations cause starvation] → Finish admitted coherent snapshots; bound/coalesce newest pending vectors and service preparation/retirement/eligible groups fairly.
- [Existing legacy render handles or geometry changes reveal bad images] → Versioned paid migration, whole-epoch cancellation and explicit old-geometry hiding/touch suppression.
- [A larger cap leaves saved walls stuck in old partitions or unexpectedly clears merged content] → Include grouping-policy identity in paid upgrade reconciliation, test unchanged saved 3×6/6×6 walls, and document normal absorbed-name and dimension-change clearing semantics.
- [Incomplete canonical OpenSpec baseline] → Preserve the existing capability paths, make only additive deltas here and reconcile the earlier unfinished changes before eventual archive/sync. Do not rewrite or declare their pending client reviews complete.

## Migration Plan

1. Implementation begins only after a new apply request, on its own branch. Start with native visibility/cost/cold-progress tests and record failed gates before continuing.
2. Introduce versioned presentation data and grouping-policy identity, raise the merged-display dimensions/cell bound, and perform paid conversion from old sweeps/partitions. Preserve unaffected models/credits; verify documented resize clearing and absorbed-name detachment for enlarged walls. Test ordinary cold load separately from configuration-change migration in base and Space Age.
3. Integrate automatic singleton buffering, then checked selected groups, cancellation/retirement and immutable shared-writer behavior. Roll out defaults only once the unchanged-method and legacy-save fixtures pass.
4. Update exact API/help/limit documentation and the verified plot example, then run the packaged regression and client acceptance matrix.
5. Keep a backup of pre-upgrade saves. An older mod must not be assumed to understand the new presentation subrecord; rollback uses the saved backup and matching old mod archive, not destructive in-place downgrade. Publication/version bump requires separate user authorization.

## Open Questions

No unresolved product/API choice is required before implementation. Numeric cost coefficients, the finite commit-work/render reservation within the existing shared ceiling, derived total-object/retained-cell caps and measured rendering latency must be established by the first gate without weakening six-tile geometry support, the specified group capacity, aggregate budgets or publication guarantees. If that gate disproves feasibility, stop and reopen the design with the user instead of silently changing the contract.
