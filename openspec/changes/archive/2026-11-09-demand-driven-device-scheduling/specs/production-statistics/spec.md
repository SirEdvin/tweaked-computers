# production-statistics delta

## MODIFIED Requirements

### Requirement: Physical statistics peripheral
The mod SHALL provide a 1×1 Production Statistics device of type `production_statistics`, requiring and consuming no electricity and exposing one visible Network endpoint for red and green wires. It SHALL have a distinct industrial instrument identity, matching item icon and cardinal views. It SHALL be read-only and expose no resource inventory, crafting operation, statistic reset or signal read/write service.

#### Scenario: Place and discover the device
- **WHEN** a player or robot places the device in any cardinal orientation and connects it to a computer through an authorized same-color Network path
- **THEN** discovery exposes one `production_statistics` identity with correctly aligned visible contacts and the normal operational-status presentation without electricity warnings.

### Requirement: Live identity and power checks
Each method SHALL retain existing exact-identity, force/surface and explicit-wire authority checks. All methods SHALL require no electricity; missing electrical supply MUST NOT cause `E_UNPOWERED`. Removal, replacement or scope changes SHALL invalidate captured calls rather than retargeting them.

#### Scenario: Power outage and restoration
- **WHEN** a reachable device has no electrical supply, or surrounding supply disappears and returns
- **THEN** its name, limits and authorized statistical queries remain usable without losing or altering native historical data.

#### Scenario: Captured method after replacement
- **WHEN** a program retains a method and the device is removed, replaced or moved outside its authorized scope
- **THEN** the old method fails through the existing reachability contract and cannot read a replacement's statistics.

### Requirement: Documented and exercised player workflow
The feature SHALL ship localized names, identity/status inspection, contextual Reference, a complete Lua API contract and maintained examples covering all categories and operations, including a monitor dashboard. Acceptance SHALL exercise the packaged feature on Factorio 2.1.23 base and Space Age and distinguish headless, native-client and connected-multiplayer evidence.

#### Scenario: Player builds a dashboard
- **WHEN** the maintained example runs on a statistics device and monitor without requiring electrical supply connected through the documented wire color
- **THEN** it obtains totals, rates and native history through their separate methods and presents correctly labelled values without a second history collector.

#### Scenario: Native chart comparison
- **WHEN** native client verification compares item/fluid/pollution statistics with the documented peripheral results at a controlled observation point
- **THEN** directions, quality selection, windows, units and historical order agree, allowing only native display rounding, documented sampling boundaries and verified pinned-engine GUI presentation smoothing; the burst case remains and all 300 raw samples per side match direct native `get_flow_count`, with smoothing confined to verification/presentation comparison
- **AND** missing graphical or connected-client receipts remain explicit unmet acceptance gates.
