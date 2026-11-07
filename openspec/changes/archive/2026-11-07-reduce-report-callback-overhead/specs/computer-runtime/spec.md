## MODIFIED Requirements

### Requirement: Run-scoped host scaffolding reuse
Saved-program callbacks within one computer run MAY reuse host-side scaffolding built for an earlier callback of that run, including the program chunk that the scaffold loaded for that run's source. Reuse SHALL be invisible to the guest and to synchronized state. Each callback SHALL execute the program's declarations again, start with fresh guest globals, locals and upvalues, and rebind current authority, admission and per-callback proofs.

#### Scenario: Guest state stays fresh
- **WHEN** a callback assigns a global, writes a top-level local or mutates a table reachable only from guest code
- **THEN** the next callback of the same run does not observe that value
- **AND** only computer state, queued events and other documented persistence carry data between callbacks.

#### Scenario: Warm and cold scaffolding are equivalent
- **WHEN** the same callback runs with reused scaffolding on one peer and newly built scaffolding on another peer or after reload
- **THEN** both runs charge the same host work, refuse at the same point and produce the same effects and output
- **AND** neither peer desynchronizes.

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
