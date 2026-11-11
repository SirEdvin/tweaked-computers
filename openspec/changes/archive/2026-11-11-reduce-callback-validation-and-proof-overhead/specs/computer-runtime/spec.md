## ADDED Requirements

### Requirement: Run-scoped source validation reuse
A saved-program callback SHALL NOT validate its source again when its run still holds reusable scaffolding for the same exact active source. The reused result SHALL give the same handlers, effects, charges and refusals as a new validation. A callback SHALL execute only program text from a source that the current process validated. The number of distinct running programs and Console activity SHALL NOT cause repeated validation.

#### Scenario: Later callback with reused scaffolding
- **WHEN** a run that paid compilation receives a later callback and its scaffolding for the same exact source is reusable
- **THEN** the host does not validate the source again
- **AND** the callback has the same declared handlers, effects, charges and refusals as a callback that validates the source

#### Scenario: Peer without the process cache
- **WHEN** a peer has no scaffolding for a paid run after a late join or a reload
- **THEN** that peer validates the exact active source one time without a compilation charge
- **AND** its effects, charges and refusals equal those of a peer that reused scaffolding

#### Scenario: Many distinct running programs
- **WHEN** as many computers as the active-computer limit run distinct sources and each receives callbacks
- **THEN** each run validates its source at most one time in a process after its first callback
- **AND** validation of other sources or Console commands between the callbacks causes no new validation for a running program

#### Scenario: New run or changed source
- **WHEN** a computer starts a new run, activates a changed source or has no reusable scaffolding
- **THEN** the host validates that exact source before it executes program text
- **AND** it never executes text that a caller or saved data supplied as already validated

### Requirement: Computer methods preserve callback-local proofs
Calls to the computer methods getID, getLabel, setLabel, getTick, getLimits, getState, setState, deleteState, log, on, off, after, every and cancelTimer SHALL NOT invalidate the callback-local authority proofs of a saved-program callback or a Console command. Each call SHALL still check current execution ownership. The stop method and unclassified operations SHALL keep invalidation before their effects.

#### Scenario: Computer call between peripheral calls
- **WHEN** an invocation wraps a peripheral, calls a listed computer method and then calls a proof-preserving method of that peripheral
- **THEN** the invocation makes one network discovery for that wire
- **AND** results, errors and work charges equal those of the same calls with a new proof

#### Scenario: Console command
- **WHEN** a Console command calls a listed computer method between two peripheral calls
- **THEN** the same proof rule applies as in a saved-program callback

#### Scenario: Operations that can change proof assumptions
- **WHEN** an invocation calls computer.stop, a peripheral method without a stability classification or another unclassified operation
- **THEN** the host invalidates the proofs before the effects of that operation, also when the operation fails
- **AND** a later call gets a complete current proof

#### Scenario: Ownership is checked on each call
- **WHEN** the execution owner is not active or the computer identity, body, generation, force or surface differs from the proof
- **THEN** a listed computer method fails with the existing ownership error
- **AND** a retained proof does not authorize the call

#### Scenario: Proof ends with the invocation
- **WHEN** a callback or Console command returns, faults, stops or is retired
- **THEN** a later invocation starts without proofs, also after it called only listed computer methods

## MODIFIED Requirements

### Requirement: Run-scoped host scaffolding reuse
Saved-program callbacks within one computer run MAY reuse host-side scaffolding built for an earlier callback of that run, including the program chunk that the scaffold loaded for that run's source. Reuse SHALL be invisible to the guest and to synchronized state. Each callback SHALL execute the program's declarations again, start with fresh guest globals, locals and upvalues, and rebind current authority, admission and per-callback proofs. A run SHALL pay compilation work once. A saved marker on the computer record SHALL record that payment, and process-local caches SHALL NOT affect charges.

#### Scenario: Guest state stays fresh
- **WHEN** a callback assigns a global, writes a top-level local or mutates a table reachable only from guest code
- **THEN** the next callback of the same run does not observe that value
- **AND** only computer state, queued events and other documented persistence carry data between callbacks.

#### Scenario: Warm and cold scaffolding are equivalent
- **WHEN** the same callback runs with reused scaffolding on one peer and newly built scaffolding on another peer or after reload
- **THEN** both runs charge the same host work, refuse at the same point and produce the same effects and output
- **AND** neither peer desynchronizes.

#### Scenario: Compilation is paid once per run
- **WHEN** the first callback of a run is admitted
- **THEN** it pays source validation and reconstruction work and records the payment in the saved computer record
- **AND** later callbacks of the same run make no compilation charge, with or without reused scaffolding
- **AND** a new run pays again, and a refused first callback records no payment.

#### Scenario: Loaded program is reused only within its run
- **WHEN** several callbacks of one run execute with reused scaffolding
- **THEN** the program text is loaded once for that run and each later callback executes the same loaded chunk with fresh declarations
- **AND** a new run, changed source, callback without reusable scaffolding or Console command loads its program again.

#### Scenario: Authority is checked per callback
- **WHEN** a device is removed, rewired or loses its owner between two callbacks of the same run
- **THEN** the later callback applies current authority and topology, not a proof or inventory cached by an earlier callback.

#### Scenario: Scaffolding ends with its run
- **WHEN** the run stops, faults, is replaced, its computer is removed or relevant settings change
- **THEN** later callbacks never reuse scaffolding from the ended run or the previous settings.

#### Scenario: Console commands
- **WHEN** a player runs a Console command
- **THEN** the Console keeps its existing per-command reconstruction and is not affected by saved-program scaffolding reuse.
