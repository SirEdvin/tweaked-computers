# Production Statistics Spec Delta

## Purpose

Let computer programs read the native item, fluid and pollution statistics for their local factory through a physical peripheral, including cumulative totals, time-window averages and historical chart samples without maintaining a second production ledger.

## ADDED Requirements

### Requirement: Physical statistics peripheral
The mod SHALL provide a 1×1 Production Statistics device of type `production_statistics`, consuming 30 kW and exposing one visible Network endpoint for red and green wires. It SHALL have a distinct industrial instrument identity, matching item icon and cardinal views. It SHALL be read-only and expose no resource inventory, crafting operation, statistic reset or signal read/write service.

#### Scenario: Place and discover the device
- **WHEN** a player or robot places the device in any cardinal orientation and connects it to a computer through an authorized same-color Network path
- **THEN** discovery exposes one `production_statistics` identity with correctly aligned visible contacts and the normal power/status presentation.

### Requirement: Existing progression and upgrade-safe unlock
The device recipe SHALL produce one item in 2 seconds from 8 iron plates, 5 electronic circuits and 2 advanced circuits, with a stack size of 50. Existing Circuit Computers research SHALL unlock it without a new technology or expansion-only ingredient. Configuration reconciliation SHALL enable it for already-researched forces without granting research or changing other recipe states.

#### Scenario: Fresh and upgraded research
- **WHEN** a fresh force has not researched Circuit Computers
- **THEN** the recipe is locked until that technology is researched.
- **WHEN** an existing force with Circuit Computers researched upgrades to this feature
- **THEN** the new recipe becomes enabled while existing devices, recipes, source and saved data remain intact.

### Requirement: Local category and authority scope
Queries SHALL accept only `item`, `fluid` and `pollution` and always use the peripheral's current surface. Item/fluid statistics SHALL belong to its current force; pollution SHALL be the surface-wide native statistics, not force-filtered or a local pollution concentration. There SHALL be no force/surface selector, electricity, kill-count or construction-statistics query.

#### Scenario: Two forces on two surfaces
- **WHEN** authorized computers query peripherals on two surfaces and two forces have distinct item/fluid activity on one surface
- **THEN** each query sees only its own surface and its own force's item/fluid data
- **AND** pollution queries by those forces on the same surface read that surface's shared native pollution statistics.

#### Scenario: Excluded categories and selectors
- **WHEN** a caller requests electricity or supplies an extra force or surface selector
- **THEN** the call fails with the documented argument/range error and does not read another scope.

### Requirement: Separate statistical operations
The exact public method set SHALL be `getTotals`, `getRates`, `getHistory` and the standard `getLimits`. The statistical methods SHALL be synchronous read-only calls with distinct signatures and result shapes defined in `lua-api.md`. They SHALL NOT require subscriptions, jobs, sessions, background recording or a running computer during the observed historical period.

#### Scenario: Read existing factory history
- **WHEN** a new statistics device is placed in an established factory
- **THEN** its first authorized calls can read the native retained totals, rates and history from before placement rather than starting a new history at installation time.

### Requirement: Complete cumulative totals
`getTotals(kind)` SHALL return every entry in both native cumulative count maps for the selected scope, with the exact native numbers and separate input/output maps. Items SHALL preserve quality-name then item-name nesting; fluids and pollution SHALL retain native name keys. Missing keys SHALL remain absent and an empty side SHALL be an empty map. No total SHALL be inferred from current rates or history.

#### Scenario: Distinct quality and direction inventories
- **WHEN** normal and higher-quality versions of an item exist, one item is only produced and another only consumed
- **THEN** the snapshot preserves each recorded quality and direction independently without aggregation, invented opposite-side keys or discarded entries.

#### Scenario: Native reset or lack of activity
- **WHEN** native statistics have no recorded entries or another authorized system has reset them
- **THEN** subsequent totals reflect the current native maps rather than stale values or a fabricated lifetime total.

### Requirement: Bulk native window averages
`getRates(kind, window)` SHALL return both directions for every key recorded in their respective native count maps, replacing counts with the engine's average rate for the selected window. Rates SHALL use native per-minute units, preserve item qualities and include recorded entries whose selected-window rate is zero. It SHALL support every pinned native flow-precision window named in `lua-api.md`.

#### Scenario: Old activity outside the short window
- **WHEN** a recorded entry has cumulative activity but no activity in the selected short window
- **THEN** it remains in the corresponding rates map with the native zero rate.

#### Scenario: Every supported precision
- **WHEN** a caller selects each supported window for item, fluid and pollution data
- **THEN** returned values equal direct native window-average reads for the same identities and directions, without converting them to per-second values or averaging chart samples independently.

### Requirement: Native per-entry historical samples
`getHistory(kind, name, window, quality?)` SHALL return separate dense input and output arrays with all 300 native samples for exactly one identity and window. Index 1 SHALL be newest and index 300 oldest; values SHALL be native per-minute rates. Only items SHALL accept quality, defaulting to normal. The API SHALL NOT resample, reverse, interpolate, synthesize timestamps or substitute periodically collected data.

#### Scenario: Both historical directions
- **WHEN** a caller requests an item, fluid or pollution entry with recorded activity
- **THEN** both arrays match all direct native sample reads in native order, including zero values and native short-history behavior.

#### Scenario: Item quality is not merged
- **WHEN** two qualities of the same item have different activity
- **THEN** selecting one quality returns only its history, and omitted or nil quality selects normal rather than all qualities.

### Requirement: Fresh defensive native snapshots
Results SHALL be detached finite plain Data with a `tick` identifying when they were read. They SHALL follow the engine's statistics update timing, not add unfinished current-tick samples. The API SHALL preserve fractional values and native identities without rounding, localization or prototype-based omission. Subsequent reads SHALL observe native changes without reboot; changing a result SHALL not change statistics or another result.

#### Scenario: Caller mutation and later production
- **WHEN** a caller changes a returned map or history sample and real production later changes the native statistics
- **THEN** native statistics and other snapshots remain unaffected by the caller's mutation, while the next query reflects the engine's new values.

#### Scenario: Native pollution sources and sinks
- **WHEN** the native pollution maps contain terrain or other engine-defined source/sink keys
- **THEN** totals and rates preserve those exact keys, and history accepts those recorded identities instead of dropping them because an ordinary entity-prototype lookup does not recognize them.

### Requirement: Existing resource safety without silent truncation
Successful results SHALL contain the entire requested snapshot. Existing shared work, allocation and Data limits SHALL remain enforced without renewal, new statistics-specific entry caps, new settings or global limit increases. A snapshot that cannot fit SHALL fail explicitly with no partial result or retained query state. The native 300-sample history length SHALL not be treated as a configurable resource policy.

#### Scenario: Complete bulk result or refusal
- **WHEN** the complete native inventory fits the existing call envelope
- **THEN** every recorded entry is returned with no top-N cutoff.
- **WHEN** the same requested snapshot exceeds an existing protection
- **THEN** the call refuses under the existing error/control contract without a successful prefix, truncated map, continuation token or retry loop.

#### Scenario: Repeated expensive queries
- **WHEN** a program repeats rate/history queries during one callback or shared tick
- **THEN** actual native calls and result-processing work consume the existing budgets and cannot reset them or bypass neighboring computer scheduling.

### Requirement: Live identity and power checks
Each method SHALL retain existing exact-identity, force/surface and explicit-wire authority checks. Reachable unpowered devices SHALL remain discoverable and permit `getLimits`, but reject all three statistical operations with `E_UNPOWERED`. Removal, replacement or scope changes SHALL invalidate captured calls rather than retargeting them.

#### Scenario: Power outage and restoration
- **WHEN** a reachable device loses power
- **THEN** its name and limits remain accessible but statistical queries fail with `E_UNPOWERED`.
- **WHEN** power returns
- **THEN** newly authorized queries work without losing native historical data.

#### Scenario: Captured method after replacement
- **WHEN** a program retains a method and the device is removed, replaced or moved outside its authorized scope
- **THEN** the old method fails through the existing reachability contract and cannot read a replacement's statistics.

### Requirement: Stateless composite lifecycle
The device SHALL follow existing placement, rotation, mining, destruction, cloning and wired-blueprint revival semantics with one logical item and no usable helper orphans. Native statistics SHALL not be stored in its item or device state. Cold load SHALL preserve identity and wires without executing queries on load; fresh calls SHALL resolve current native statistics rather than saved native object references.

#### Scenario: Mine and rebuild without resetting statistics
- **WHEN** a statistics device is mined, cloned or rebuilt from a wired blueprint
- **THEN** the new entity has its own identity and correct owned components, and neither native statistics nor existing computers' state is reset or copied into the item.

#### Scenario: Separate-process reload and connected peers
- **WHEN** a factory with connected statistics devices is cold-loaded or a second client joins
- **THEN** synchronized queries agree on scope, keys, values and sample order without duplicated recording, startup effects or a process-local authoritative cache.

### Requirement: Documented and exercised player workflow
The feature SHALL ship localized names, identity/status inspection, contextual Reference, a complete Lua API contract and maintained examples covering all categories and operations, including a monitor dashboard. Acceptance SHALL exercise the packaged feature on Factorio 2.1.23 base and Space Age and distinguish headless, native-client and connected-multiplayer evidence.

#### Scenario: Player builds a dashboard
- **WHEN** the maintained example runs on a powered statistics device and monitor connected through the documented wire color
- **THEN** it obtains totals, rates and native history through their separate methods and presents correctly labelled values without a second history collector.

#### Scenario: Native chart comparison
- **WHEN** native client verification compares item/fluid/pollution statistics with the documented peripheral results at a controlled observation point
- **THEN** directions, quality selection, windows, units and historical order agree, allowing only native display rounding and documented sampling boundaries
- **AND** missing graphical or connected-client receipts remain explicit unmet acceptance gates.
