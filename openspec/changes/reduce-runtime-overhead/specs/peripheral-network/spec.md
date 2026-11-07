# Spec Delta

## MODIFIED Requirements

### Requirement: Bounded topology reconciliation and fail-closed calls
Topology changes SHALL be reconciled deterministically within published capacity/latency limits. A peripheral operation MUST fail closed if current reachability cannot be established within its work allowance. A stale cache alone MUST NOT authorize a mutation. A complete physical proof can be reused only within one non-yielding invocation while all its authority assumptions remain valid.

#### Scenario: Wiring changes without a dedicated engine event
- **WHEN** a player or another mod removes a path without a dedicated wire-change notification
- **THEN** subsequent calls cannot use stale cached authority and periodic reconciliation updates discovery/events within the declared supported envelope.

#### Scenario: Unsupported network size
- **WHEN** traversal exceeds a declared node, edge or work limit
- **THEN** the computer receives an explicit pending/limit diagnostic rather than an apparently complete partial device list.

#### Scenario: Reuse does not widen authority
- **WHEN** an invocation reuses a complete proof after operations that cannot change its assumptions
- **THEN** each call remains bound to the same computer, program run or shell session, exact target generation, force, surface, and selected wire
- **AND** a different target, generation, owner, or color requires its own valid proof.

#### Scenario: Invalidate before a potentially changing operation
- **WHEN** an operation can change an endpoint, path, identity, owner, scope, or another assumption of a retained proof
- **THEN** the host invalidates that proof before the operation can change those facts
- **AND** a later call obtains a complete current proof even if the earlier operation threw an ordinary error.

#### Scenario: Unclassified operation keeps full validation
- **WHEN** the host cannot establish that an intervening operation preserves a proof's assumptions
- **THEN** it does not reuse that proof for subsequent calls
- **AND** incomplete revalidation returns the existing pending/limit/error outcome without reading or mutating an unauthorized target.

#### Scenario: Proof ends with the invocation
- **WHEN** a callback or Console command returns, faults, stops, or is retired
- **THEN** its temporary authority proofs cannot authorize any later invocation
- **AND** cold load, captured methods, retained shell bindings, and background observations require current execution-time authority.

#### Scenario: Physical proof is not native availability
- **WHEN** a call reuses a valid same-color physical proof for a native radar or speaker
- **THEN** its operation still enforces current native availability and method-specific requirements
- **AND** no retained metadata snapshot supplies permission for an unavailable native operation.
