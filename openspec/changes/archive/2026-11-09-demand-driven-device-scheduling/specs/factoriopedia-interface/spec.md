# factoriopedia-interface delta

## MODIFIED Requirements

### Requirement: Distinct physical catalogue peripheral
The mod SHALL provide a 1×1 Factoriopedia Interface requiring and consuming no electricity, identified as peripheral type `factoriopedia_interface`. Its selectable body SHALL provide one Network endpoint accepting red and green wires. It SHALL have no item inventory, fluid input, crafting function, factory-signal API or dedicated catalogue GUI.

#### Scenario: Place and wire the interface
- **WHEN** a player places the interface in any cardinal direction and connects its body to a computer Network
- **THEN** discovery exposes the distinct peripheral on the connected color, with wire contacts matching the visible body and no power helper.

### Requirement: Existing resource bounds without a new catalogue quota
Catalogue operations SHALL consume the existing work, allocation and Data allowances without renewing credits or adding a feature-specific name-count cap. A list or record that cannot fit SHALL refuse explicitly without a prefix, cursor or silent truncation. `getLimits()` SHALL report current common limits and remain available regardless of electrical coverage. Successful lists SHALL not imply arbitrary modpack-size support.

#### Scenario: Catalogue exceeds shared result capacity
- **WHEN** the complete name array exceeds an existing Data allowance and sufficient work remains to detect that refusal
- **THEN** the list call raises `E_LIMIT`, publishes no partial array and leaves subsequent individually affordable exact-name queries possible with fresh work credits.

#### Scenario: Work is exhausted
- **WHEN** repeated calls exhaust existing work or allocation credits
- **THEN** the current fatal budget behavior remains in effect without renewed credits, retry loops or reclassification as an empty catalogue.

#### Scenario: Unrelated catalogue growth
- **WHEN** unrelated installed prototypes increase but an exact-name lookup's record is unchanged
- **THEN** that lookup does not enumerate unrelated prototypes or charge their count as its metadata work.

### Requirement: Existing network and power authority
Calls SHALL use existing same-force, same-surface, explicit-color Network authority and exact bound device identity. All methods SHALL require no electricity; missing electrical supply MUST NOT cause `E_UNPOWERED`. Detach, replacement or scope changes SHALL revoke stale calls. Passive Network relay SHALL preserve existing color separation.

#### Scenario: Power disappears and returns
- **WHEN** electrical supply around the interface disappears and returns, or never existed
- **THEN** catalogue calls, discovery, passive relay and authorized limits remain available under normal authority checks without rebuilding the device.

#### Scenario: Captured method after replacement
- **WHEN** a program calls a retained method after its interface is removed and replaced at the same position
- **THEN** the old binding raises `E_UNREACHABLE` instead of retargeting the replacement.

### Requirement: Distinct artwork and identity-only inspection
The interface SHALL have a distinct Service Rack body/icon with readable cardinal views, status and Network contacts, while preserving pre-existing device artwork and geometry. Normal opening SHALL show its authorized identity/status inspector, not a vanilla carrier dialog or catalogue browser. Native Factoriopedia opening and existing item/fluid information SHALL remain unchanged.

#### Scenario: Inspect and identify the new block
- **WHEN** an authorized player opens an interface with or without electrical coverage without a connected computer
- **THEN** its exact peripheral name is copyable and status is meaningful, without performing a catalogue scan or starting a program.

#### Scenario: View beside existing devices
- **WHEN** the interface is rendered beside Recipe Searcher and the other Service Rack devices in each cardinal direction
- **THEN** its silhouette and icon are distinguishable and both wire colors attach to their depicted contacts, with unrelated device pixels unchanged.

### Requirement: Shipped API contract and runnable example
The shipped feature SHALL include localized names, discoverable method help, the companion Lua API contract and a runnable guest example covering name lists, item/fluid lookup and absent rocket capacity. Documentation SHALL explain exact namespaces, baseline quality, units, complete-or-error lists and the difference between reference metadata and live factory feasibility.

#### Scenario: Use the documented API
- **WHEN** the documented example runs through the actual guest API against a wired interface without requiring electrical supply in the tested archive
- **THEN** it uses the declared methods and fields successfully, and discovery/help/package inventories include the new peripheral without removing existing methods.
