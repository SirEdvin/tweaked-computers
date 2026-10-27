## MODIFIED Requirements

### Requirement: Bounded and honest refresh
Inspectors SHALL poll automatically with coalesced scheduling, preserve selections and unchanged mounted content, and stop detail polling when closed. They SHALL show meaningful pending/unavailable states, not incomplete results as complete. Logic observations SHALL use direct native reads without inventory ceilings or revalidation; presentation scheduling SHALL not limit accessible signals. Other families retain their existing allowances. Refresh buttons and numeric tick trackers SHALL remain absent.

#### Scenario: Repeated refresh under contention
- **WHEN** multiple players inspect peripherals while programs and monitors are active
- **THEN** UI work is coalesced without an unbounded request backlog or renewed same-tick credits
- **AND** scheduling presentation does not turn a large Logic Handler inventory into a size refusal or a cache for program reads.

#### Scenario: Snapshot cannot be refreshed
- **WHEN** a non-logic query exceeds its existing allowance or a logic target becomes unavailable
- **THEN** the UI identifies pending/error status and does not publish a partial result as complete
- **AND** previous displayed details are marked stale, while unresolved monitor identities cannot be copied as current.

#### Scenario: Initial query cannot be admitted
- **WHEN** an inspector opens before its refresh is scheduled
- **THEN** identity, controls and meaningful pending detail structure appear without claiming an empty successful result.

#### Scenario: Large native circuit with optional fields
- **WHEN** a Logic Handler has more than 1,024 signals, including records with omitted default identity fields
- **THEN** every entry is accessible with its correct effective identity, wire and count, without sorting or expanding source records
- **AND** fresh refreshes observe native values independently of subscriptions while retaining the user's scroll, focus and copy selection where content is unchanged.
