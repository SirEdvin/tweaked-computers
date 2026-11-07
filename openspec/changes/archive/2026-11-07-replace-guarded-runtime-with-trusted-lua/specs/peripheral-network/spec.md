# Peripheral network delta

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

## ADDED Requirements

### Requirement: Checked calls from trusted Lua
Wrapped calls, captured methods, and peripheral.call SHALL enforce the same identity, generation, scope, path, and method contracts. Native execution SHALL grant no host-object access or persistent authority. Host-work and method-specific capacities SHALL remain effective without guest-allocation or temporary-tuple metering.

#### Scenario: All call routes enforce revocation
- **WHEN** a selected path or bound identity becomes invalid before a wrapped, captured, or named call
- **THEN** every route refuses before the unauthorized operation
- **AND** no route relies on an execution guard to supply the missing check.

#### Scenario: Invalidation before a changing operation
- **WHEN** a provider can invalidate an authority assumption, including an operation that subsequently throws
- **THEN** reusable proofs are invalidated before provider entry
- **AND** the next operation in the same invocation must establish valid authority again.

#### Scenario: Output and argument boundaries remain distinct
- **WHEN** trusted Lua submits a caller-created request or receives a host result
- **THEN** the operation enforces its declared arity, domain, copying, result, and capacity contract
- **AND** detached native circuit inventories keep their existing complete-result exception without granting that exception to arbitrary guest tables.

#### Scenario: Result safety after a device effect
- **WHEN** a device method performs an irreversible effect
- **THEN** no retired guest-result allocation reservation remains necessary to receive its declared return tuple
- **AND** retained host admission and method-specific atomicity still prevent an unauthorized or partially admitted effect.

### Requirement: Discovery returns native-width result tuples
peripheral.find SHALL retain sorted multiple-return semantics without the retired tuple_entries ceiling. Zero matches SHALL return zero values. Existing network capacities, host-work admission, native stack limits, and method availability SHALL remain effective. No truncation or replacement result-array API SHALL be introduced.

#### Scenario: More than the former tuple limit
- **WHEN** a supported network contains more than 128 matching peripherals and the complete discovery fits retained host limits
- **THEN** find returns every matching facade as multiple values, in the existing order
- **AND** wrapped identities, wires, and optional-method sets match getNames/wrap.

#### Scenario: Incomplete discovery is not a partial success
- **WHEN** discovery cannot establish the complete inventory within retained topology or host limits
- **THEN** it returns the documented pending or failure outcome, not a successful prefix.
