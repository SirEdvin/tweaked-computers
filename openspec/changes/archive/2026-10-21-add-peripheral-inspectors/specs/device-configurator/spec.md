# Spec Delta

## ADDED Requirements

### Requirement: Prototype-grouped target inventory
The configurator inspector SHALL list target-side factory devices grouped by exact entity prototype, with a localized name, prototype identity and count for each group. Broad entity type alone SHALL NOT merge different prototypes. Enumeration SHALL retain existing same-force, same-surface, real-wire traversal rules and include connected targets without writable circuit settings.

#### Scenario: Several inserter prototypes
- **WHEN** target wires reach several devices of one inserter prototype and devices of another inserter prototype
- **THEN** each prototype appears as a separate counted group rather than one generic inserter total.

#### Scenario: Unsupported connected targets and ordinary relays
- **WHEN** a target network reaches ordinary relay poles or devices without writable control behavior
- **THEN** those reachable devices remain counted under their actual prototypes instead of disappearing from the inventory.

### Requirement: Explicit wire membership and unique totals
The inventory SHALL show each prototype group's red-connected count, green-connected count and unique total across both target networks. An entity reachable on both colors SHALL count once in the unique total and once in each applicable color count. The configurator itself and owned helper entities SHALL NOT appear as extra devices; network-role-only peripherals SHALL NOT enter the target inventory.

#### Scenario: Device reached on both colors
- **WHEN** one machine is reachable through red and green target paths, including multiple paths on either color
- **THEN** its group shows one unique device, one red-connected device and one green-connected device
- **AND** the labels explain that red and green counts overlap rather than promising their sum equals the unique total.

#### Scenario: Separate discovery and target networks
- **WHEN** peripherals are attached only to the configurator's computer-network role and factory machines to its target role
- **THEN** the inventory counts only the target-side reachable entities without adding discovery devices or crossing isolated combinator roles.

### Requirement: Complete bounded inventory refresh
The inspector SHALL identify the target inventory's snapshot tick and provide explicit refresh. Counts SHALL be published only from complete admitted target-network observations; incomplete or over-limit traversal SHALL report pending/error rather than a plausible partial total. Display rows SHALL be deterministically ordered and bounded, with all successful groups reachable by scrolling or pagination.

#### Scenario: Wire removed before refresh
- **WHEN** a target loses its last qualifying connection and the player refreshes
- **THEN** the new complete snapshot removes it from the applicable group and color counts without changing any machine settings.

#### Scenario: One wire cannot be enumerated
- **WHEN** either color's traversal cannot complete within supported graph/work limits
- **THEN** the UI does not claim a complete combined inventory or unique total
- **AND** any retained prior snapshot is explicitly stale rather than mixed with new partial counts.
