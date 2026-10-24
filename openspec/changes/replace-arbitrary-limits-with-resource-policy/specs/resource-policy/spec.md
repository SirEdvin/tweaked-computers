## Purpose

Protect simulation responsiveness and retained data through explicit configurable resource accounting, without unrelated limits on native inventories or device counts.

## ADDED Requirements

### Requirement: Only justified resource ceilings
The mod SHALL retain only ceilings protecting work, live/retained memory or storage, queued work, stack depth and disposable-data retention, plus the approved six-tile monitor-axis and KV-specific exceptions. Native value domains and authority checks SHALL remain enforced. A removed ceiling MUST NOT reappear as another fixed record, string, tuple or transport-size limit.

#### Scenario: Complete limit disposition
- **WHEN** the change is accepted
- **THEN** every numeric guard and structural capacity in the source-audit inventory has a recorded removal, resource-accounting replacement, native-domain justification or explicit monitor/KV exception
- **AND** settings, generated schemas, generic copies, UI, fixtures and advertised limits agree with that disposition.

#### Scenario: Native inventory exceeds old thresholds
- **WHEN** a valid inventory crosses an old signal, recipe, graph, catalogue or transport threshold while fitting configured resource allowances
- **THEN** it is available completely without an arbitrary cardinality refusal or hidden truncation.

### Requirement: Configurable effective resource policy
Every retained mod-imposed resource ceiling and KV-specific limit SHALL have a localized mod setting with documented scope, units, default and overload behavior. Runtime-global settings SHALL govern live resource policy. Effective values SHALL be queryable. The configurable monitor-axis policy SHALL default to six and never exceed six; native domains and encoding semantics are not tunable quotas.

#### Scenario: Change a live setting
- **WHEN** an authorized settings change increases or decreases a runtime allowance
- **THEN** all affected services use the synchronized effective value without restarting programs or renewing spent same-tick credits
- **AND** any dependency-derived restriction is visible rather than a hidden clamp.

#### Scenario: No silent unlimited sentinel
- **WHEN** a setting is invalid or outside the engine-supported representation
- **THEN** the UI rejects it or reports its effective supported value; zero MUST NOT accidentally disable a safety protection
- **AND** no protected operation relies on an unconfigurable duplicate ceiling.

### Requirement: Work pressure preserves progress
Execution and resumable host-work exhaustion SHALL defer progress fairly without restarting completed work, faulting the computer or clearing outputs. Compilation SHALL instead use a bounded non-resumable pass with recoverable refusal. Requests MAY wait before compilation begins. Accepted work SHALL NOT be silently dropped. Impossible indivisible runtime work SHALL refuse recoverably rather than wait forever.

#### Scenario: Large finite job under a small budget
- **WHEN** a resumable handler or host service needs several ticks of admitted work
- **THEN** it retains paid progress, eventually completes under stable resources and does not starve unrelated computers, UI, cleanup or rendering.

#### Scenario: Unending guest loop
- **WHEN** a handler never finishes
- **THEN** it receives only its fair bounded slices, remains visibly waiting/running, and can be stopped without executing further guest instructions.

#### Scenario: Compilation does not fit
- **WHEN** a source cannot compile within the configured work or memory allowance
- **THEN** the request receives a recoverable diagnostic with setting guidance, preserving source and the previous active run
- **AND** it retains no partial compiler execution and does not silently retry an impossible pass forever.

### Requirement: Hard-resource refusal is recoverable
Memory, storage and necessary depth ceilings SHALL refuse unsafe growth before mutation with a catchable typed error. Existing data SHALL remain accessible for reading, deletion, export or capacity reduction. An uncaught resource refusal SHALL end the current invocation with a visible diagnostic, not retire its run, delete registrations or clear owned output merely because of capacity.

#### Scenario: Full state or KV database
- **WHEN** a write exceeds its effective retained-data allowance
- **THEN** it fails atomically and reports resource, usage, requested growth, effective limit and setting name
- **AND** a subsequent deletion or smaller write can succeed without restarting the computer.

#### Scenario: Protected recursion refusal
- **WHEN** a host call or error-handler re-entry would exceed a justified configured safety depth
- **THEN** it refuses before entering that frame and unwinds to the nearest applicable protected call
- **AND** error handling remains metered, so repeated catches do not bypass work fairness.

### Requirement: Lower limits preserve accepted data
Decreasing a setting SHALL NOT invalidate or delete previously accepted non-disposable data, queued work or suspended execution. Over-limit owners SHALL reject additional growth while allowing non-growing recovery operations. Disposable logs/caches MAY be evicted under their documented retention policy with visible log truncation. Geometry decreases SHALL not silently repartition and clear existing displays.

#### Scenario: Save after reducing capacity
- **WHEN** a player lowers memory, state, KV or queue capacity below current usage and saves
- **THEN** cold reload retains contents, deadlines, admitted order and continuation progress; reads and reductions remain possible
- **AND** new growth is refused until it fits or the player raises the setting.

### Requirement: Observable event loss without program collapse
An event that exceeds the receiving computer's queue allowance SHALL be dropped newest, without evicting accepted events or faulting the run. Each dropped delivery SHALL update persistent per-computer diagnostics and a rate-limited warning. Loss diagnostics SHALL not depend on enqueueing another event into the overflowing queue.

#### Scenario: Sustained overflow
- **WHEN** producers outpace a receiver across several ticks
- **THEN** accepted events keep their order, new excess deliveries are counted once each, and other computers remain serviceable
- **AND** UI and API expose cumulative drops, last drop tick, event kind and resource reason even after log eviction or cold reload.

### Requirement: Bound actual retained resource lifetimes
Accounting SHALL cover guest-owned reachable data, suspended frames, temporary host snapshots, committed storage and pending operations for their actual lifetimes. Per-tick allocation credits alone SHALL NOT serve as retained-memory protection. Aliases, ownership transfers, reclamation and metadata SHALL have deterministic documented accounting.

#### Scenario: Growth across ticks
- **WHEN** a program allocates a small amount each tick and retains it indefinitely
- **THEN** aggregate retained accounting eventually refuses further growth without losing accepted data, even if no individual allocation slice exceeds its per-tick budget.

#### Scenario: Release resources under pressure
- **WHEN** state is deleted, a continuation ends or a pending job is canceled
- **THEN** its exclusive retained resources become reusable without resetting unrelated spent work or double-freeing shared data.

### Requirement: No duplicate container capacities
Event queues and Console history SHALL each use accounted-byte capacity including nonzero entry metadata, without an independent entry-count ceiling. Resource subaccounts SHALL NOT create additional quotas without a distinct protected resource or lifetime. Native/API invariants and the explicit KV/monitor exceptions remain binding.

#### Scenario: Many small entries
- **WHEN** queue events or Console entries exceed their former count ceiling while fitting accounted-byte capacity
- **THEN** count alone does not reject or evict them, and empty entries still consume metadata capacity
- **AND** byte exhaustion uses the existing drop-newest or visible oldest-log-eviction behavior respectively.

### Requirement: Checks protect explicit boundaries and invariants
Validation SHALL protect guest/host boundaries, restored state, native/API invariants, live authority and data integrity. Suspension alone SHALL NOT require full revalidation of unchanged private state. Saved validation flags SHALL NOT authorize execution. Iterative traversal SHALL NOT impose a depth ceiling without a remaining host-stack or native/API constraint.

#### Scenario: Resume private admitted state
- **WHEN** trusted execution suspends with unchanged admitted private data
- **THEN** it can reuse that state without duplicate full shape validation or copying, while mutations and effects retain necessary admission and authority checks
- **AND** cold load or late joining still validates restored state without cache-dependent accounting or behavior.

#### Scenario: Deep iterative data
- **WHEN** valid data exceeds the former depth ceiling and every downstream consumer handles it iteratively within resources and native constraints
- **THEN** it succeeds without a depth refusal; any remaining recursive host path retains its justified protection.
