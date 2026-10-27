# Spec Delta

## ADDED Requirements

### Requirement: Consolidated live monitor observation
Recurring monitor physical observation SHALL be consolidated into one minimal pass per actual simulation tick. Unchanged observations SHALL NOT trigger duplicate full physical validation, grouping reconstruction or presentation work. Existing power, component ownership and physical-change behavior SHALL remain intact; this optimization SHALL NOT introduce a slower idle polling interval or suppress maintenance merely because programs are stopped.

#### Scenario: Settled monitor array
- **WHEN** a powered array remains unchanged and has no pending physical repair
- **THEN** the normal tick observes the live state needed to detect power and physical invalidation once through the consolidated path
- **AND** generic lifecycle, grouping and presentation phases do not independently repeat full all-member validation of that unchanged array; actual service, interaction, selected-path and publication proofs remain separately permitted and accountable.

#### Scenario: Outage and recovery without peripheral calls
- **WHEN** a tile in a settled logical display loses power and later regains it without any drawing calls
- **THEN** the existing power-loss safety ordering and admitted hide/restore behavior apply without an added polling delay
- **AND** all-member power requirements, retained buffers and passive wire continuity remain unchanged.

#### Scenario: Silent physical change
- **WHEN** another script moves, rotates, changes the force or surface of a monitor, or invalidates its body or owned helper without a usable notification
- **THEN** live observation detects the changed physical state through the normal lifecycle path and schedules the required invalidation or reconciliation
- **AND** stale geometry, ownership or power cannot remain trusted simply because the presentation work list is empty.

#### Scenario: Unchanged neighboring device families
- **WHEN** monitor observation is removed from duplicate generic maintenance paths
- **THEN** computers, logic, databases, configurators, speakers and radar tracking retain their existing power, cleanup, discovery and safety behavior
- **AND** monitor tile identities and real circuit endpoints remain registered for passive discovery rather than being treated as dormant radars.

### Requirement: Fresh operation-boundary monitor authority
Monitor operations SHALL retain their operation-specific identity, ownership, scope, geometry, power and circuit checks, including existing query-only power exceptions. A prior observation or matching simulation tick SHALL NOT authorize a later operation after native state changes. Positive proof reuse SHALL be limited to a non-mutating operation scope; deferred work SHALL retain identities and revalidate them rather than retain reusable authority.

#### Scenario: Native changes within the same event
- **WHEN** an earlier check succeeds and native code then moves or rotates a tile, changes its force, removes an owned helper or removes power before a later check in the same event
- **THEN** the later guarded active operation or publication refuses the now-invalid state even though the simulation tick is unchanged
- **AND** restoring the state permits a fresh proof without requiring a tick advance.

#### Scenario: Retired identity still has queued work
- **WHEN** a monitor or selecting computer is removed, replaced or regrouped while presentation work is pending
- **THEN** that work cannot publish through the retired identity or affect an unrelated replacement
- **AND** owned cleanup completes under existing budgets while accepted surviving models remain recoverable.

#### Scenario: Idle Console selection loses its path
- **WHEN** a live Console-owned monitor selection has no ready frame and its selected wire path is definitively revoked while the saved program is stopped
- **THEN** the existing bounded authority maintenance detects and releases the selection with its existing diagnostic semantics, without waiting for a new drawing call
- **AND** a temporarily incomplete proof blocks rather than falsely detaches, and no alternative wire color is silently substituted.

### Requirement: Reliable monitor invalidation delivery
Accepted physical, settings, power and ownership transitions SHALL notify the affected monitor work before stale state can be published. Repeated notifications SHALL remain bounded by retained devices and work rather than event history. Budget refusal, further invalidation and save/reload SHALL NOT lose the need for reconciliation, visibility changes or cleanup.

#### Scenario: Supported lifecycle entry points
- **WHEN** placement, revival, clone, rotation, actual removal, settings paste, force merge or surface removal affects a monitor
- **THEN** the existing lifecycle handlers deliver the corresponding monitor invalidation without requiring a guest call or a periodic full signature sweep
- **AND** clone/item isolation, settings inheritance, helper ownership and removal guarantees remain unchanged.

#### Scenario: Deferred work followed by another change
- **WHEN** a monitor transition has scheduled reconciliation or cleanup but admission defers it and another relevant transition occurs
- **THEN** the newer invalidation remains represented until valid current state commits or owned cleanup completes
- **AND** repeated scheduling neither renews credits nor retains one work record per repeated event.

#### Scenario: Initialization and unsupported retained state
- **WHEN** upgrade introduces monitor observation metadata or retained metadata is unsupported
- **THEN** permitted synchronized initialization preserves existing state and valid unfinished work, while unsupported representations remain recoverable and cannot authorize unsafe operation
- **AND** ordinary load performs no world mutation, queue reconstruction, guest execution or native object creation.
