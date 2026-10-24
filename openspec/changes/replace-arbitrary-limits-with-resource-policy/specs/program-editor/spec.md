## MODIFIED Requirements

### Requirement: Source-located diagnostics and bounded output
Validation and runtime failures SHALL identify the active/saved revision, handler and original source location where available. Output SHALL be bounded by configurable accounted bytes including entry metadata, without an independent entry-count ceiling, and show truncation. Errors MUST NOT expose host objects, private internals or generated-code-only locations to the player.

#### Scenario: Error after successful actions
- **WHEN** a program faults after previous successful peripheral operations
- **THEN** the console reports the fault and stopped/faulted state without claiming those earlier operations were rolled back.

## ADDED Requirements

### Requirement: Actionable pressure and loss status
The workspace SHALL distinguish running, budget-waiting, recoverable resource refusal and actual fault. It SHALL show cumulative event drops, last drop tick/kind/reason and actionable setting guidance without requiring logs to survive. Stop SHALL remain usable while execution is suspended, and status refresh SHALL preserve drafts, focus and selection.

#### Scenario: Runaway but suspended handler
- **WHEN** a handler consumes every work slice
- **THEN** the UI identifies waiting/progress rather than a fault and an explicit Stop cancels the continuation without needing that handler to cooperate.

#### Scenario: Logs have rolled over
- **WHEN** old overflow warnings have been evicted
- **THEN** the persistent loss counter and latest loss details remain visible independently of Console retention.

### Requirement: Source and draft capacity follows storage
Source, command text, identifier/search input and recoverable drafts SHALL NOT be refused by independent arbitrary length/count ceilings. Storage pressure SHALL retain existing drafts and visibly reject new growth. Compilation SHALL show queued, completed or recoverably refused status, not promise partial compiler progress. The previous run SHALL remain active until replacement succeeds.

#### Scenario: More than eight dirty drafts
- **WHEN** a player opens another computer after retaining eight drafts and aggregate storage permits it
- **THEN** the additional draft is available without deleting an earlier draft or requiring an arbitrary draft slot.

#### Scenario: Candidate cannot compile within its allowance
- **WHEN** a queued candidate receives a recoverable bounded-compilation refusal
- **THEN** its draft remains editable, the old run remains active, and the UI identifies the relevant resource/setting rather than showing endless progress
- **AND** a later successful request rechecks source revision and current authority before replacement.
