# Proposal

## Why

Ordinary native inventories fail behind overlapping mod-invented ceilings: a 150-signal network currently fails a 64-signal guard, and deleting that guard exposes Data, event and work refusals. Resource protection must constrain resource consumption rather than impose unrelated device/count ceilings or stop healthy computers on ordinary overload.

## What Changes

- Retain only justified protection for execution/compilation/host work, live and retained memory/storage, pending work, host-stack depth and disposable-data retention. Expose every retained resource ceiling in mod settings, with effective values, units and overload behavior available to players and programs.
- **BREAKING:** work exhaustion suspends the current computation and resumes it fairly on later ticks. Preserve exact continuation progress across cold save/load and multiplayer joining without replaying completed side effects. Replace the existing non-suspending native-handler restriction; preserve both supported source forms and the guest trust boundary.
- Compilation is the explicit exception: use a bounded, non-resumable pass, with recoverable work/memory refusal and source/previous-run preservation. Do not persist a compiler execution machine. This supersedes the earlier promise of resumable tokenizer/parser/emitter progress, not durable running-handler progress.
- **BREAKING:** storage/memory/depth limits remain hard admission boundaries with recoverable errors, not whole-computer resource faults. Accepted data is not discarded. Non-event pending work is deferred or refused visibly before acceptance, never silently dropped.
- **BREAKING:** event overflow drops the newest incoming event, retains the existing queue and run, and exposes persistent per-computer drop diagnostics through UI/API plus a rate-limited warning.
- Remove arbitrary signal/filter/output, recipe, configurator, discovery, device-registration, active-computer, modem fan-out, speaker-catalogue, source/table-shape and monitor synchronization capacities. Remove hidden transport ceilings that merely recreate them. Actual native domains and aggregate resource admission remain binding.
- Remove duplicate event-queue and Console-history entry ceilings; their byte accounting includes entry metadata. Retain a check only for a named trust boundary, native/API invariant, data-loss risk or distinct protected resource. Bounded execution blocks replace prescribed per-primitive checkpoints; unchanged safety and acceptance behavior remain required.
- Explicit exceptions approved by the user: retain the monitor geometry ceiling of six tiles per axis and KV-specific limits. KV limits become configurable and recoverable. The geometry setting defaults to six and may reduce the effective limit, but never exceeds the approved 6×6 ceiling.
- Retain access validation, serialization integrity, exact identity, role/color separation, native numeric domains, output fail-safes on genuine stop/power/authority loss, and device/API semantics unrelated to capacity. No filesystem, guest coroutine API or general-purpose OS is introduced.
- Update every affected API companion, examples, generated configuration schemas, diagnostics and boundary tests. Planning only: no implementation, task unblocking, merge or release is authorized by this proposal.

## Capabilities

### New Capabilities

- `resource-policy`: allowed resource ceilings, settings, recoverable overload, accounting, observability and exhaustive disposition of old limits.

### Modified Capabilities

- `computer-runtime`: resumable durable execution, hard-resource recovery, drop-newest event admission and runtime introspection.
- `program-source`: bounded non-resumable compilation into durable handlers while preserving source grammar and ordinary call semantics.
- `console-shell`: resumable commands, preserved staged state, shared fair resource admission and isolated recovery.
- `logic-handler`: full native signal inventories, filters and output capacity governed by native/resource constraints rather than signal slots.
- `peripheral-network`: incremental complete discovery, no node/edge/result ceiling and no fixed synchronization-group cardinality.
- `device-configurator`: native-capacity configuration and complete inventory under resumable work admission.
- `recipe-searcher`: complete matching recipes without the 50-result ceiling.
- `radar-modem`: resource-governed routing, channel storage and fan-out with observable receiver event drops.
- `speaker-peripheral`: full catalogues and deferred work rather than arbitrary catalogue/playback-count ceilings.
- `monitor-display`: retained 6×6 geometry, resource-governed buffering and synchronization, and explicit presentation boundaries for suspended work.
- `kv-database`: configurable retained KV-specific limits with atomic recoverable refusal and safe live decreases.
- `device-lifecycle`: no arbitrary registry/placement ceilings, save-safe continuation migration and non-lossy item transport.
- `program-editor`: waiting/recoverable-pressure/event-loss visibility, protected drafts and settings guidance.
- `peripheral-inspection`: complete engine-owned inventories through bounded, resumable read-only work.

## Impact

Source baseline inspected: `69e27d9e0fc417438d5a428ddeeca5b67ffe9703` (0.1.13). Primary change areas are `scripts/runtime/{compiler,sandbox,admission,computer,shell,data,budget-settings}.lua`, `scripts/scheduler.lua`, services, `scripts/network.lua`, configuration validators/generator, registry/lifecycle/blueprints, monitor model/presenter, UI, `settings.lua` and locale/help. Reuse the existing Phobos front end and service implementations; no new external dependency is proposed.

Existing specs explicitly require non-suspending execution, fatal budget exhaustion, queue-overflow faults and fixed per-device capacities. These are intentional contract changes, not a configuration-only patch. Continuation ABI/storage migration, deterministic commit boundaries and performance are release-critical. The existing signal-limit Kanban investigation overlaps this scope; implementation must reconcile landed work rather than duplicate it, without automatically changing that campaign's state.

Clarification record: recoverable hard-resource refusal, durable handler pause/resume and drop-newest diagnostics remain approved, with only 6×6 monitor geometry and KV-specific device-capacity exceptions. The simplification review explicitly approved bounded non-resumable compilation, duplicate-capacity removal and less prescriptive checkpoint/validation rules. Defaults remain engineering tuning, not measurements; unchanged user workloads and safety gates still apply. These revised artifacts do not claim the existing implementation already conforms.
