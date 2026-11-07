## MODIFIED Requirements

### Requirement: Power-free status and demand-owned art updates
Custom-device world/status/UI presentation SHALL not show missing electricity as a fault or unavailable state. Status art SHALL update only for affected dirty identities whose operational state changed, without scanning all devices each tick. The running-computer blink SHALL be a native engine animation with its existing four frames, 10-tick frame cadence and tick alignment, not a script redraw. Native radar/speaker graphics, warnings and animation SHALL remain unchanged.

#### Scenario: Custom device outside electrical coverage
- **WHEN** each custom family is viewed in the native client without an electrical network
- **THEN** its intended artwork and contacts remain legible, no electrical warning or helper appears, and genuine stopped/fault/physical-invalid states remain distinguishable.

#### Scenario: Unchanged artwork
- **WHEN** devices retain the same operational state across ordinary ticks
- **THEN** the mod performs no per-device status discovery or redundant native sprite update; a later run/fault/lifecycle change updates only affected art.

#### Scenario: Running computer blinks without script work
- **WHEN** a computer stays running across many ticks
- **THEN** its status light shows the same four-frame blink at the same 10-tick cadence as before
- **AND** the mod performs no status-art update or deadline for that computer until its operational state changes.

#### Scenario: Native exception appearance
- **WHEN** a native radar or programmable speaker loses power
- **THEN** native visual feedback remains intact without adding a custom recurring power watcher.
