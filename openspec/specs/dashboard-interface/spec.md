# dashboard-interface Specification

## Purpose

Let computers configure a physical peripheral's native machine-style window with mixed controls and optional charts, while retaining shared data and safe player/program authority.

## Requirements

### Requirement: Device-local dashboard window
Ordinary opening of a Dashboard SHALL show its configured native window, exact copyable peripheral identity and availability. The window SHALL belong to the opening player, not replace world monitors or another machine's UI. Empty dashboards SHALL show a meaningful unconfigured state without running a program.

#### Scenario: Open without a writer
- **WHEN** an authorized player opens a powered dashboard with no connected running computer
- **THEN** its last accepted content is available, or it shows the unconfigured state if it has none
- **AND** opening does not configure the device, subscribe a computer or execute guest code.

### Requirement: Six mixed-content tabs
A dashboard SHALL accept up to six named tabs in numbered slots. Each tab SHALL compose labels, buttons and optional charts using rows and columns. Complete tab replacement SHALL validate atomically; invalid nodes, duplicate widget IDs, unsupported fields and excess tabs SHALL leave the previous model unchanged. No general native-GUI or arbitrary-style API SHALL be exposed.

#### Scenario: Mixed tab and slot boundary
- **WHEN** a program configures a valid tab containing a label, button and supported chart in any slot from one through six
- **THEN** all elements appear together in that tab, in declared layout order
- **AND** slot seven is rejected without changing any existing tab.

#### Scenario: Invalid replacement
- **WHEN** a replacement contains duplicate IDs or an unsupported widget
- **THEN** its entire replacement fails, preserving existing content and history.

### Requirement: Stable targeted updates
Programs SHALL update label/button text and button enablement by tab slot and stable widget ID. Updating content SHALL preserve unrelated widgets, each viewer's selected tab, scroll and unchanged text selection. Structural replacement SHALL preserve compatible chart data by ID as specified by the companion API; removing or changing a chart's data definition SHALL explicitly reset that chart only.

#### Scenario: Live values while reading
- **WHEN** a program updates one label and appends a chart sample while two players view different tabs
- **THEN** both receive relevant content updates without being moved to another tab or losing unchanged selection/scroll.

#### Scenario: Reapply configuration
- **WHEN** a program reapplies an identical tab definition after restarting
- **THEN** the retained histories are not erased and no duplicate widgets appear.

### Requirement: Shared wired configuration authority
The `dashboard` peripheral SHALL use existing explicit-wire discovery, identity, power, shared-access and typed-error contracts. All authorized computers SHALL share one committed model in synchronized call order. Neither configuring a button nor subscribing SHALL grant exclusive ownership, a hidden network bridge or remote player access.

#### Scenario: Competing writers
- **WHEN** two authorized computers update the same label in synchronized order
- **THEN** the later successful value wins for all viewers and readers
- **AND** a later refused update does not roll back the preceding successful one.

### Requirement: Authorized button subscriptions
Each accepted button activation SHALL be scheduled for every explicit subscription whose computer still has authority to the dashboard. Events SHALL identify the dashboard, wire, subscription, tab, button and player. Delivery SHALL revalidate the exact tab/button configuration and current authority. GUI handlers SHALL NOT invoke guest callbacks directly or select the last writer as an implicit controller.

#### Scenario: Multiple subscribed computers
- **WHEN** an authorized player activates an enabled button with two authorized subscribed computers and one unsubscribed computer connected
- **THEN** each subscription receives one event through ordinary scheduled dispatch and the unsubscribed computer receives none
- **AND** alternate physical paths do not duplicate delivery for the same subscription.

#### Scenario: Stale or forged activation
- **WHEN** an event refers to another player's window, a removed/replaced button, a disabled button or a device the player cannot reach
- **THEN** it creates no callback, even when its supplied tags resemble a valid session.

#### Scenario: Revocation after click
- **WHEN** a clicked button is structurally replaced, its subscription is cancelled or its computer loses its authorized path before dispatch
- **THEN** that pending delivery cannot activate the stale control.

### Requirement: Existing event lifecycle and pressure semantics
Dashboard subscriptions and pending clicks SHALL follow existing run retirement, power, queue-capacity and cancellation rules. New clicks SHALL NOT accumulate for stopped or unpowered computers. Delivery to one subscriber SHALL NOT depend on another subscriber's handler succeeding. No unbounded private click backlog or automatic retry of a delivered action SHALL be introduced.

#### Scenario: Full recipient queue
- **WHEN** one recipient's queue cannot accept a click but another recipient can
- **THEN** the affected recipient follows existing visible overflow/fail-safe behavior, without converting the click into an unbounded retry job or preventing independent eligible delivery.

#### Scenario: Writer stops
- **WHEN** a configuring program stops
- **THEN** its subscriptions retire but the shared dashboard model and chart histories remain.

### Requirement: Optional chart capability
Labels, buttons and dashboard lifecycle SHALL work without `factorio-charts`. Chart-specific methods SHALL appear only when the compatible dependency is enabled. Without it, new chart definitions SHALL be refused, while retained chart definitions/data SHALL remain recoverable and display a clear unavailable placeholder. Base controls SHALL remain usable.

#### Scenario: Base installation
- **WHEN** the mod is loaded without the chart library
- **THEN** discovery exposes a working dashboard with no chart methods and a label/button-only tab can be configured and used.

#### Scenario: Remove and restore the dependency
- **WHEN** a save with populated charts is loaded without the library and later with it again
- **THEN** chart data survives, base controls continue working, and supported charts can render again without replaying producer callbacks.

### Requirement: Unmodified upstream chart scope
Charts SHALL use only factorio-charts capabilities supported without modifying the library. Line graphs and duration-stacked-bars SHALL retain documented upstream semantics and constraints. Unsupported graph kinds, arbitrary numeric/category bars, custom rendering and fallback charts SHALL remain absent. The interface SHALL NOT claim to embed Factorio's production widget or reproduce it exactly.

#### Scenario: Non-history duration bars
- **WHEN** a program submits a valid latest dataset of nonnegative durations in seconds to a stacked-bar widget
- **THEN** it is shown using the upstream duration axis and ordering without accumulating a time history.

#### Scenario: Unsupported chart request
- **WHEN** a program requests an unsupported chart type or a numeric bar-axis mode
- **THEN** it receives the companion API's documented typed validation error without changing accepted data or silently substituting a different chart.

### Requirement: Peripheral-owned rolling samples
Line charts SHALL retain the configured number of most-recent submitted samples on the dashboard. A successful append SHALL advance one sample and evict only the oldest when full. Sampling SHALL be explicit, independent of viewers and ordered by accepted calls; no automatic resampling, multi-resolution aggregation or fabricated wall-clock spacing SHALL be claimed.

#### Scenario: Wrap and reload
- **WHEN** a chart fills, receives another sample and is saved/reloaded in a separate process
- **THEN** it retains exactly the newest configured sample window in order, without replay, duplication or implicit averaging.

#### Scenario: No viewers or producer outage
- **WHEN** nobody views the tab, or the producer stops between submissions
- **THEN** accepted samples remain available; closing the UI does not stop admission, and producer silence creates no synthetic samples.

### Requirement: Accounted retained capacity
The combined dashboard definition, retained chart data and reserved line-buffer capacity SHALL fit the existing per-device application-state byte allowance, currently 65,536 accounted bytes. Existing Data, operation and work limits SHALL also apply. The requested line capacity SHALL be admitted before acceptance. Queryable renderer constraints SHALL prevent silent upstream truncation without adding arbitrary widget-count policies.

#### Scenario: Complete capacity admission
- **WHEN** a proposed definition or bar dataset cannot fit the shared allowance or a required upstream rendering domain
- **THEN** it is refused before mutation, and existing layout, data and line-buffer reservations remain intact.

#### Scenario: Full reserved line window
- **WHEN** a valid line chart reaches its admitted rolling capacity
- **THEN** another valid fixed-shape sample replaces its oldest sample without unbounded retained growth.

### Requirement: Power and player access
Dashboard calls except limit inspection SHALL require live peripheral power. Opening and every action SHALL revalidate player identity, force, surface, reach and permissions. An unpowered dashboard SHALL retain its model while presenting an explicit unavailable state and refusing button actions. Different viewers SHALL retain independent UI sessions without expanding computer authority.

#### Scenario: Outage and restoration
- **WHEN** an open dashboard loses power and later regains it
- **THEN** actions are disabled during the outage, data is not erased and the valid retained model can be displayed after restoration.

### Requirement: Lifecycle-safe presentation
Save/load SHALL preserve accepted dashboard state without executing guest code or modifying storage on load. Rendering/session state SHALL not become application data. Library changes, window closure, tab replacement, removal and authority loss SHALL retire affected GUI/render resources without clearing unrelated histories or leaving orphaned renderings.

#### Scenario: Save with an open tab
- **WHEN** a save with an open dashboard is cold-loaded
- **THEN** synchronized gameplay revalidates or closes the session before interaction, preserves histories and does not renew same-tick accounting credits.

### Requirement: Bounded usable native layout
The window SHALL use native controls, readable spacing, dragging, close/Escape and bounded scrolling at supported resolutions/scales. Chart presentation SHALL be demand-driven and coalesced under existing maintenance allowances, with no drawing work for closed tabs. Pending/failed chart rendering SHALL be explicit and SHALL NOT block unrelated base controls or fabricate a current result.

#### Scenario: Closed and changing charts
- **WHEN** a producer submits samples with every viewer closed, then a player opens a tab
- **THEN** history remains current without background redraws, and the opened tab schedules its latest chart for presentation.

#### Scenario: Multiple viewers under contention
- **WHEN** players view different dashboard tabs while other computers and monitors are active
- **THEN** refresh work remains bounded and fair, unchanged widgets retain interaction state, and a chart awaiting work is not reported as current.

### Requirement: Packaged dashboard acceptance
Acceptance SHALL verify the exact packaged mod and dependency versions on Factorio 2.1.23 in base and Space Age, including dependency absence, cold save/load, removal/reinstallation, native UI input and connected clients. Source inspection, mocked controls and headless assertions SHALL remain distinct from visual and multiplayer evidence.

#### Scenario: Full mixed-tab workflow
- **WHEN** the implementation is accepted
- **THEN** maintained programs demonstrate mixed tabs, button delivery, rolling wrap and supported duration bars with inspected native captures
- **AND** separate evidence covers two viewers/two subscribers, rejection atomicity, resource cleanup, mined data and configuration-only copies without changing production budgets to pass.
