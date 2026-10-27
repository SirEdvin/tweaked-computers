## MODIFIED Requirements

### Requirement: Bounded native work
Source validation, reconstruction, callbacks and host services SHALL retain execution limits. Loops, recursion, opaque library work and guest-created allocation SHALL remain bounded; execution exhaustion SHALL fault the run and invoke fail-safe cleanup. Trusted native circuit inventories SHALL not be refused by generic Data or inventory-proportional admission ceilings. Circuit calls remain metered operations, not permission for unbounded guest execution.

#### Scenario: Infinite loop cannot monopolize the simulation
- **WHEN** a callback loops indefinitely or repeatedly catches ordinary errors
- **THEN** enforced execution admission aborts it within the declared work ceiling
- **AND** its quota failure cannot be swallowed to obtain additional work or peripheral effects
- **AND** unrelated admitted computers remain serviceable.

#### Scenario: Large helper inputs remain charged
- **WHEN** a program attempts maximum-sized concatenation, formatting, table construction, state copying or caller-authored peripheral output
- **THEN** guest work and applicable storage/native domains remain enforced before mutation
- **AND** circuit data is not rejected solely for exceeding a generic table, node, name or transport ceiling.

#### Scenario: Native inventory versus guest workload
- **WHEN** one admitted circuit read returns a large native inventory
- **THEN** the bridge exposes the complete result without imposing a proportional result-copy quota
- **AND** subsequent guest loops, repeated calls, arbitrary allocations and explicit state writes still obey their existing resource protections.

### Requirement: Guest trust boundary
Guest code SHALL receive only approved APIs and isolated plain values. It MUST NOT obtain Factorio LuaObjects, host state, filesystem/network access, mutable standard libraries or private budget/authority mechanisms. Every API operation SHALL recheck authority. Fresh detached native circuit records can be transferred without generic defensive recopying; shared baselines and queued events SHALL remain isolated from guest mutation.

#### Scenario: A captured peripheral method outlives its connection
- **WHEN** guest code retains a wrapped method and the valid same-color path is removed
- **THEN** calling that method fails without reading or mutating the disconnected device.

#### Scenario: Native signal tables are usable and isolated
- **WHEN** a guest indexes or iterates a native signal collection beyond former table limits and mutates an existing signal entry
- **THEN** ordinary guest table access works without altering native circuits, output configuration, another consumer or retained event baselines.

#### Scenario: Trust cannot be forged or reused for arbitrary data
- **WHEN** guest data imitates a signal event, adds functions/cycles/host-like fields to a returned table, or passes a result to ordinary state/KV storage
- **THEN** no user-controlled marker grants trusted native treatment and normal argument/storage validation still applies
- **AND** a caller-supplied output replacement is validated even if originally derived from a native read.

#### Scenario: Reuse a native-sized array as caller input
- **WHEN** a guest replaces existing entries of a native-sized array with their signal identities and submits it as a subscription filter
- **THEN** non-growing replacement is not rejected by the old table-entry ceiling, and the complete caller-supplied filter is validated at registration
- **AND** this does not exempt arbitrary new guest allocation or storage from its existing protections.

### Requirement: Simulation timers and bounded queues
Timers SHALL use simulation ticks, persist deadlines and address named handlers. One-shot timers SHALL fire at most once; recurring timers SHALL not replay unbounded missed intervals. Event backlog SHALL remain bounded with visible fault-on-overflow behavior. Native circuit snapshot size SHALL not consume generic guest-payload byte/node capacity; circuit notifications SHALL still consume queue entries and bounded envelope accounting.

#### Scenario: Paused game and closed save
- **WHEN** simulation ticks do not advance
- **THEN** timer deadlines do not advance through wall-clock time.

#### Scenario: Overdue timer after a power interruption
- **WHEN** a powered-down computer regains power after recurring deadlines passed
- **THEN** at most one overdue event per timer is admitted with its missed-interval count
- **AND** the next deadline remains aligned to the original interval.

#### Scenario: Large observation fits an otherwise available queue
- **WHEN** a trusted circuit notification has more native signal data than generic Data/peripheral payload ceilings allow, but a queue entry and its envelope fit
- **THEN** its complete observation is retained and delivered without a size-induced fault or truncated arrays.

#### Scenario: Slow consumer still reaches backlog protection
- **WHEN** pending notifications exhaust the existing queue entry or envelope allowance
- **THEN** the existing visible overflow fault and output cleanup occur
- **AND** no unlimited backlog, drop-newest policy or suspension mechanism is introduced.

#### Scenario: Cold delivery preserves the accepted observation
- **WHEN** a save contains accepted subscriptions and large undispatched circuit events
- **THEN** cold load retains their observation data, ordering and run identity without startup or output replay
- **AND** subsequent dispatch does not reintroduce a generic payload ceiling or use retained observations to answer fresh reads.
