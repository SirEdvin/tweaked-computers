## ADDED Requirements

### Requirement: Constant idle scheduling
On a tick where no timer is due, no computer is ready and no subsystem has due or pending work, the scheduler SHALL do only constant bookkeeping. It SHALL NOT call any subsystem hook and SHALL NOT allocate Lua memory on that tick. A subsystem hook SHALL run on a tick only when its synchronized readiness reports due or pending work.

#### Scenario: Idle ticks between reports
- **WHEN** one running computer waits for a recurring timer and no other device, subscription, output, monitor, open UI, database expiry or lifecycle work is pending
- **THEN** every tick before the timer is due calls no subsystem hook
- **AND** the Lua memory count is unchanged across each of those scheduler ticks.

#### Scenario: Pending work wakes only its hook
- **WHEN** a lifecycle event, signal subscription, owned output, monitor change, open viewer, database expiry, clone, undo or radar adoption creates work
- **THEN** the owning hook runs on the tick its work is due, in the fixed registration order
- **AND** hooks with no work stay skipped on that tick.

#### Scenario: Readiness survives save, reload and late joining
- **WHEN** a save holds pending or due subsystem work and is cold-loaded or joined by another peer
- **THEN** every peer derives the same readiness from synchronized storage and runs the same hooks on the same ticks
- **AND** no work is lost, run twice or delayed past its due tick.

#### Scenario: Unreadable subsystem state
- **WHEN** a readiness check finds retained state it cannot interpret
- **THEN** the scheduler runs that hook, so the hook's existing validation and diagnostic path applies
- **AND** the readiness check does not repair or discard the state.

### Requirement: Run-scoped host scaffolding reuse
Saved-program callbacks within one computer run MAY reuse host-side scaffolding built for an earlier callback of that run. Reuse SHALL be invisible to the guest and to synchronized state. Each callback SHALL load the program fresh, start with fresh guest globals, locals and upvalues, and rebind current authority, admission and per-callback proofs.

#### Scenario: Guest state stays fresh
- **WHEN** a callback assigns a global, writes a top-level local or mutates a table reachable only from guest code
- **THEN** the next callback of the same run does not observe that value
- **AND** only computer state, queued events and other documented persistence carry data between callbacks.

#### Scenario: Warm and cold scaffolding are equivalent
- **WHEN** the same callback runs with reused scaffolding on one peer and newly built scaffolding on another peer or after reload
- **THEN** both runs charge the same host work, refuse at the same point and produce the same effects and output
- **AND** neither peer desynchronizes.

#### Scenario: Authority is checked per callback
- **WHEN** a device is removed, rewired or loses its owner between two callbacks of the same run
- **THEN** the later callback applies current authority and topology, not a proof or inventory cached by an earlier callback.

#### Scenario: Scaffolding ends with its run
- **WHEN** the run stops, faults, is replaced, its computer is removed or relevant settings change
- **THEN** later callbacks never reuse scaffolding from the ended run or the previous settings.

#### Scenario: Console commands
- **WHEN** a player runs a Console command
- **THEN** the Console keeps its existing per-command reconstruction and is not affected by saved-program scaffolding reuse.
