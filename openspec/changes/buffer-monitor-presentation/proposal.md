# Proposal

## Why

Monitor drawing currently reads a changing terminal model while replacing visible cell sprites over several ticks, so large screens visibly sweep and independent screens have no common publication barrier. Adopt CC:Tweaked-inspired automatic terminal snapshots and dirty-update coalescing, with a Factorio-specific bounded presentation mechanism rather than requiring existing programs to flush their writes.

## What Changes

- Automatically buffer presentation behind the existing monitor drawing methods. Successful calls still update the shared terminal model immediately; rendering prepares a fixed snapshot while retaining the previous complete visible image.
- Coalesce pending updates, finish already admitted frames without repeatedly restarting them, and publish a complete prepared image in one synchronized simulation tick.
- Use demand-driven publication headroom rather than a permanently enlarged render reservation. Freeze reservation decisions per actual tick, allow a baseline maintenance-service tick between boosted reservations, and initialize topology through admitted resumable stages. This approved revision addresses the measured fixed-reservation failure without raising shared ceilings or weakening whole-frame publication.
- Increase the merged-display limit to six tiles on each local axis. Support every complete rectangle from 1×1 through 6×6, including 3×6, 6×3 and narrow strips, at every existing text scale and cardinal orientation. Buffer allocation, indexing, preparation and charging follow actual character dimensions; smaller displays do not pay for a padded 6×6 grid.
- Add optional `peripheral.setMonitorSyncGroup(members)` / `peripheral.getMonitorSyncGroup()` for one explicitly selected group per computer run. Ordinary monitors need no setup. A selected group waits for every member to participate in the next update round, then prepares and publishes its snapshot vector together; no partial group publication or timeout-based splitting.
- Publish and enforce group, snapshot, staging, retirement, native-object and commit-work bounds. Retain four logical screens per synchronized group and raise its proposed combined-cell envelope to 10,584, covering four 6×6 scale-1 screens, one maximum-resolution 6×6 screen or mixed shapes/scales within that total. Size staging and retirement for that envelope; derive native commit credits and any render-reservation rebalance through the feasibility gate within unchanged shared host/maintenance ceilings. These are proposed safety limits, not measured performance claims.
- Preserve terminal signatures, aliases, synchronous model visibility, per-call refusal atomicity, shared-writer ordering, power retention, logical identities, touch mapping and world-feedback layers. Presentation becomes deliberately deferred and frame-coherent; a callback does not become a model transaction.
- Document the distinction between render snapshots and application frames. Buffering cannot infer when a program drawing over several callbacks is finished. No mandatory flush, begin/end-frame API, CraftOS `window` library, or CC GPU/network implementation is introduced. Improve the plot example separately using one shared animation phase and measured producer work; do not promise that buffering alone removes its deliberate four-row pacing.
- Reconcile old saves under the new grouping policy during paid synchronized work, even without a tile change. Larger existing walls can merge under normal anchor/detach/resize rules; document that changed character dimensions clear contents rather than promising image preservation across those merges.

## Capabilities

### New Capabilities

None. Reuse the existing behavioral boundaries rather than introducing a parallel monitor-buffer capability.

### Modified Capabilities

- `monitor-display`: complete rectangular merged displays up to 6×6, geometry-driven automatic coherent snapshots, bounded hidden preparation and same-tick presentation, mixed-size synchronized groups, observable backpressure and durable policy-upgrade/lifecycle behavior.
- `peripheral-network`: checked group selection/readback without changing discovery, write authority or shared access.

The canonical `openspec list --specs --json` inventory is currently empty. These paths already exist in the in-flight `add-native-circuit-computers` and `redesign-device-experience` changes. This change uses ADDED requirements for the new behaviors, explicitly references those baselines, and does not edit or archive their unfinished work. Baseline reconciliation is required before eventual spec synchronization/archive.

## Impact

Current apply authorization: the user explicitly requested completion and publication of the next alpha, deferring all graphical/client validation to their own review. Graphical and peer acceptance remain unverified and are not reported as passed; they no longer block this authorized alpha upload. All automated safety, compatibility, persistence and budget requirements remain binding.

- Main implementation areas: `scripts/monitor-model.lua`, `scripts/rendering.lua`, `scripts/services/monitor.lua`, `scripts/services/peripheral.lua`, `scripts/scheduler.lua`, runtime limit publication and existing cleanup/authority hooks.
- Contract/documentation areas: monitor/peripheral references, common scheduling/limits documentation, built-in help and a tested multi-monitor plot example.
- Verification areas: existing monitor, feedback, runtime and integration fixtures; new focused buffered-presentation/authority fixtures; packaged Factorio 2.0.77 base and Space Age cold tests plus explicitly separate native-client acceptance.
- The merged-display size change is in scope; irregular/oversized walls still partition into valid rectangles. No dependency, asset, scripting-runtime, GUI-control, version bump, publication or release change is authorized by this proposal. Global tile/model-cell and callback/shared host-work ceilings are not implicitly increased.
