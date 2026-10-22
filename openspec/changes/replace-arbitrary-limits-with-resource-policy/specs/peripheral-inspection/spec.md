## MODIFIED Requirements

### Requirement: Bounded and honest refresh
Inspectors SHALL show meaningful pending content before query admission and bound work, snapshots and GUI elements under configurable shared resource policy, without independent native-inventory count ceilings. All open inspectors, including KV and Configurator, SHALL poll automatically through throttled, coalesced scheduler admission. Refresh controls and numeric update/sample tick trackers SHALL NOT be displayed, including logic subpanels. Incomplete results SHALL be marked pending/stale/error, never a successful empty inventory or complete partial count. Closed/hidden inspectors SHALL perform no detail polling. Automatic updates SHALL retain key/field/page selection and mounted unchanged rows/text rather than recreating them on each observation.

#### Scenario: Repeated refresh under contention
- **WHEN** multiple players repeatedly request inspection while programs and monitors are active
- **THEN** excess work is deferred within effective configured resource allowances, no unbounded request backlog accumulates and already-spent same-tick credits remain spent across save/load.

#### Scenario: Snapshot cannot be refreshed
- **WHEN** the required query cannot complete within its current work slice or configured memory allowance
- **THEN** the UI retains paid resumable progress and identifies pending or recoverable resource refusal and does not publish a partial result as current.
- **AND** any previous complete detached details remain visible as explicitly stale, while unresolved monitor identities cannot be copied as current.

#### Scenario: Initial query cannot be admitted
- **WHEN** any supported peripheral inspector opens before data-query work is available
- **THEN** its identity, controls and meaningful pending detail structure are visible without claiming an empty successful result.

## ADDED Requirements

### Requirement: Complete read-only inventory access
Every successful inspector inventory SHALL include all applicable native records or make every record reachable through explicit paging/scrolling. Query work and GUI construction SHALL be scheduled fairly. A closed inspector SHALL release its pending work without changing device data, subscriptions or output ownership.

#### Scenario: Large logic input
- **WHEN** an authorized player opens a powered Logic Handler carrying 150 distinct signals
- **THEN** all identities and exact counts become reachable without E_LIMIT from signal/table-count ceilings, with independent red/green freshness and no truncated successful sample.

#### Scenario: Inventory changes during refresh
- **WHEN** a query spans ticks while native values or target identity change
- **THEN** publication identifies a coherent complete observation or remains explicitly pending/stale; it never combines incompatible partial totals or retargets a replacement device.
