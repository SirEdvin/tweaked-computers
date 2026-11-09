# dashboard-interface delta

## MODIFIED Requirements

### Requirement: Device-local dashboard window
Ordinary opening of a Dashboard SHALL show its configured native window, exact copyable peripheral identity and availability. The window SHALL belong to the opening player, not replace world monitors or another machine's UI. Empty dashboards SHALL show a meaningful unconfigured state without running a program.

#### Scenario: Open without a writer
- **WHEN** an authorized player opens a dashboard with no connected running computer
- **THEN** its last accepted content is available, or it shows the unconfigured state if it has none
- **AND** opening does not configure the device, subscribe a computer or execute guest code.

### Requirement: Shared wired configuration authority
The `dashboard` peripheral SHALL use existing explicit-wire discovery, identity, shared-access and typed-error contracts. All authorized computers SHALL share one committed model in synchronized call order. Neither configuring a button nor subscribing SHALL grant exclusive ownership, a hidden network bridge or remote player access.

#### Scenario: Competing writers
- **WHEN** two authorized computers update the same label in synchronized order
- **THEN** the later successful value wins for all viewers and readers
- **AND** a later refused update does not roll back the preceding successful one.

### Requirement: Existing event lifecycle and pressure semantics
Dashboard subscriptions and pending clicks SHALL follow existing run retirement, queue-capacity and cancellation rules. New clicks SHALL NOT accumulate for stopped or faulted computers. Delivery to one subscriber SHALL NOT depend on another subscriber's handler succeeding. No unbounded private click backlog or automatic retry of a delivered action SHALL be introduced.

#### Scenario: Full recipient queue
- **WHEN** one recipient's queue cannot accept a click but another recipient can
- **THEN** the affected recipient follows existing visible overflow/fail-safe behavior, without converting the click into an unbounded retry job or preventing independent eligible delivery.

#### Scenario: Writer stops
- **WHEN** a configuring program stops
- **THEN** its subscriptions retire but the shared dashboard model and chart histories remain.

### Requirement: Power and player access
Dashboard calls SHALL require no electricity. Opening and every action SHALL revalidate player identity, force, surface, reach and permissions. Electrical changes SHALL not disable controls or hide the retained model; actual identity/authority failures SHALL remain explicit. Different viewers SHALL retain independent UI sessions without expanding computer authority.

#### Scenario: Outage and restoration
- **WHEN** electrical supply around an open dashboard disappears and returns
- **THEN** its model and authorized actions remain available without generating clicks, samples or restoration work.

## ADDED Requirements

### Requirement: Viewer-owned dashboard refresh
Only open authorized dashboard sessions with dirty content or due refresh work SHALL receive UI service. Closing or invalidating a session SHALL remove its refresh membership. No viewer SHALL mean no recurring dashboard rendering, chart materialization or availability polling; accepted models and chart histories remain retained.

#### Scenario: Closed dashboard population
- **WHEN** many dashboards retain content but no player has them open
- **THEN** ordinary ticks perform no per-dashboard UI discovery or chart rendering, and later opening shows current accepted content.

#### Scenario: Visible dirty chart
- **WHEN** an open viewer has a changed visible chart while other charts are closed or hidden
- **THEN** existing coalescing, fairness and chart budgets service eligible visible work without repeatedly rebuilding unchanged charts.

#### Scenario: Independent viewers
- **WHEN** one player closes or loses authority while another remains authorized
- **THEN** only the affected session is retired; the other viewer continues normal refresh and shared model state is preserved.
