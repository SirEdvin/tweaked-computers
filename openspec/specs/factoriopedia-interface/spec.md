# factoriopedia-interface Specification

## Purpose

Let computer programs discover installed item and fluid names and read their intrinsic properties through a dedicated powered peripheral, including item stack size, reference rocket capacity and fluid temperature bounds.

## Requirements

### Requirement: Distinct physical catalogue peripheral
The mod SHALL provide a 1×1 Factoriopedia Interface consuming 30 kW, identified as peripheral type `factoriopedia_interface`. Its selectable body SHALL provide one Network endpoint accepting red and green wires. It SHALL have no item inventory, fluid input, crafting function, factory-signal API or dedicated catalogue GUI.

#### Scenario: Place and wire the interface
- **WHEN** a player places and powers the interface in any cardinal direction and connects its body to a computer Network
- **THEN** discovery exposes the distinct peripheral on the connected color, with wire contacts matching the visible body and a nonselectable power helper.

### Requirement: Shared Recipe Searcher progression
One `tc-factoriopedia-interface` SHALL cost 10 steel plates, 5 advanced circuits and 2 processing units with a two-second crafting time. Its disabled-by-default recipe SHALL unlock through the existing `tc-recipe-searcher` technology. Existing research prerequisites, science ingredients, research cost and Recipe Searcher recipe SHALL remain unchanged.

#### Scenario: Fresh force before and after research
- **WHEN** a fresh force has Circuit Computers but not Recipe Searcher researched
- **THEN** the new recipe remains locked.
- **WHEN** it completes Recipe Searcher research
- **THEN** both Recipe Searcher and Factoriopedia Interface recipes are enabled, without separate research or expansion-only materials.

#### Scenario: Existing researched force upgrades
- **WHEN** a pre-feature save with Recipe Searcher researched loads the feature through configuration change
- **THEN** the new recipe becomes enabled without resetting research, disabling unrelated recipes or changing existing devices.

### Requirement: Exact typed metadata lookup
`getItem(name)` and `getFluid(name)` SHALL each accept exactly one nonempty, case-sensitive installed prototype name in their respective namespace and return exactly one detailed record defined in `lua-api.md`. Unknown names SHALL raise `E_RANGE`; invalid arity, empty names or wrong argument types SHALL raise the documented argument error rather than returning an empty record.

#### Scenario: Shared item and fluid name
- **WHEN** an item and a fluid have the same internal name
- **THEN** each lookup returns only its own namespace and does not fall back to the other.

#### Scenario: Invalid lookup
- **WHEN** a caller supplies a missing name, empty string, unsupported argument type or extra argument
- **THEN** the call fails according to the companion API contract, with no successful partial record and no world mutation.

### Requirement: Complete installed catalogue visibility
`listItems()` and `listFluids()` SHALL take no arguments and return one complete dense array of unique exact names sorted in ascending bytewise order. Installed modded, hidden, Factoriopedia-hidden and blueprint-parameter entries SHALL participate. Lookup SHALL preserve the requested identity rather than substituting a Factoriopedia alternative. Visibility SHALL not depend on force research or the computer's surface.

#### Scenario: Browse hidden and modded entries
- **WHEN** a catalogue contains ordinary, hidden, parameter and third-party entries
- **THEN** every name appears once in the appropriate successful list, and detail lookup exposes its actual visibility flags.

#### Scenario: Alternative Factoriopedia entry
- **WHEN** a prototype points to an alternative display prototype
- **THEN** lookup returns the requested prototype's metadata and optional alternative name, not the alternative's properties.

#### Scenario: Reordered catalogue and empty registry
- **WHEN** native enumeration order differs but installed prototypes are unchanged
- **THEN** successful name lists have the same ascending order.
- **WHEN** a supported catalogue is empty
- **THEN** its list returns one empty array.

### Requirement: Explicit item metadata and baseline quality
An item record SHALL expose the companion contract's identity, stack size, stackability, resolved native weight, reference rocket count and fuel/spoilage metadata. Optional prototype references SHALL be names only. Quality-dependent spoil time SHALL describe `normal` quality, not the peripheral's quality or a physical stack. The API SHALL not claim to expose every item-subtype property.

#### Scenario: Ordinary and specialized items
- **WHEN** callers inspect a fuel, spoilable item, placeable item and ordinary nonfuel item
- **THEN** their native values, meaningful zeros and optional references remain distinguishable without fabricated placement, burn or spoil results.

#### Scenario: Quality-sensitive spoilage
- **WHEN** the queried item has quality-sensitive spoilage or the interface itself has a non-normal quality
- **THEN** `spoil_ticks` still equals the item's normal-quality value and the record states whether quality affects spoil time.

### Requirement: Reference rocket capacity counts individual items
For positive item weight, `rocket_capacity` SHALL be the finite whole-item mass capacity `floor(default_rocket_lift_weight / weight)` using installed native values. It SHALL not count stacks, round to stack multiples or represent a particular silo's free space. The record SHALL expose the weight and reference lift weight used. For zero weight, the count SHALL be absent, not zero or infinity.

#### Scenario: Stack size is not rocket capacity
- **WHEN** an item's stack size and reference rocket count differ
- **THEN** both values are returned independently and the count describes individual items of that prototype alone.

#### Scenario: Modded weight and reference capacity
- **WHEN** a mod changes item weight or the default rocket lift weight
- **THEN** the result uses those installed values, including floor rounding for nonintegral quotients and zero when one positive-weight item exceeds the reference lift weight.

#### Scenario: Zero-weight entry
- **WHEN** a catalogue item has zero weight
- **THEN** lookup still returns its metadata and weight but omits `rocket_capacity`, without treating it as a zero-capacity item or exposing a nonfinite number.

#### Scenario: A particular silo differs
- **WHEN** a silo has different lift weight, restricted inventory, existing cargo or unavailable launching
- **THEN** the reference count remains unchanged and documentation does not describe it as that silo's feasible load or remaining capacity.

### Requirement: Intrinsic fluid temperatures and energy properties
Fluid records SHALL expose native `default_temperature`, `max_temperature`, `gas_temperature`, `heat_capacity`, `fuel_value` and `emissions_multiplier`. Temperatures SHALL use degrees Celsius; default temperature SHALL also describe the native minimum. Heat capacity SHALL use joules per fluid unit per degree Celsius and fuel value joules per fluid unit. No production-temperature set SHALL be inferred.

#### Scenario: Read fluid bounds
- **WHEN** a caller inspects a fluid with a nontrivial temperature range
- **THEN** default/minimum and maximum remain distinct from the visual gas threshold, heat capacity and any recipe-specific temperature.

#### Scenario: Modded or nonfuel fluid
- **WHEN** a mod defines negative finite temperature bounds, equal default/maximum values or zero fuel value
- **THEN** lookup preserves the installed native values rather than clamping, substituting water's properties or dropping zero values.

### Requirement: Detached finite data and explicit omissions
Every successful result SHALL be detached plain Data without native objects, functions or metatables. Required fields SHALL preserve false, zero and empty arrays; optional fields SHALL be absent only for the reasons defined in `lua-api.md`. Unrepresentable metadata SHALL fail explicitly rather than silently omit required information or substitute another prototype.

#### Scenario: Caller changes returned data
- **WHEN** a caller edits a returned name list, fuel-category array or detail record
- **THEN** installed prototypes and subsequent callers' results remain unchanged.

#### Scenario: Unsupported native representation
- **WHEN** native metadata violates the documented finite-data representation
- **THEN** lookup raises `E_UNSUPPORTED` without returning a misleading successful record.

### Requirement: Existing resource bounds without a new catalogue quota
Catalogue operations SHALL consume the existing work, allocation and Data allowances without renewing credits or adding a feature-specific name-count cap. A list or record that cannot fit SHALL refuse explicitly without a prefix, cursor or silent truncation. `getLimits()` SHALL report current common limits and remain available without peripheral power. Successful lists SHALL not imply arbitrary modpack-size support.

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
Calls SHALL use existing same-force, same-surface, explicit-color Network authority and exact bound device identity. Reachable unpowered interfaces SHALL remain discoverable and allow `getLimits()`, but the four catalogue methods SHALL raise `E_UNPOWERED`. Detach, replacement or scope changes SHALL revoke stale calls. Passive Network relay SHALL preserve existing color separation.

#### Scenario: Power disappears and returns
- **WHEN** the interface loses electrical power
- **THEN** catalogue calls fail while discovery, passive relay and authorized limits remain available.
- **WHEN** power is restored
- **THEN** newly authorized catalogue calls succeed without rebuilding the device.

#### Scenario: Captured method after replacement
- **WHEN** a program calls a retained method after its interface is removed and replaced at the same position
- **THEN** the old binding raises `E_UNREACHABLE` instead of retargeting the replacement.

### Requirement: Non-mutating queries and lifecycle continuity
Queries SHALL not change prototypes, recipes, research, inventories, fluids, native Factoriopedia UI or other devices. Placement, rotation, mining, destruction, cloning and wired-blueprint revival SHALL follow existing logical-device semantics with one drop and no usable orphan helpers. Ordinary cold load SHALL preserve identity and network paths without running queries, guest startup or load-time mutations.

#### Scenario: Query then save and reload
- **WHEN** a program retains a detail snapshot through supported computer state and the factory is reloaded in a separate process
- **THEN** the stored snapshot and device identity survive, no query or startup is replayed during load, and later queries read the installed catalogue.

#### Scenario: Mine, clone and revive
- **WHEN** the interface is mined, cloned or revived from a wired blueprint
- **THEN** the existing logical-item and helper ownership rules apply, with new entity identities for new devices and no catalogue payload or query session transferred in items.

### Requirement: Distinct artwork and identity-only inspection
The interface SHALL have a distinct Service Rack body/icon with readable cardinal views, status and Network contacts, while preserving pre-existing device artwork and geometry. Normal opening SHALL show its authorized identity/status inspector, not a vanilla carrier dialog or catalogue browser. Native Factoriopedia opening and existing item/fluid information SHALL remain unchanged.

#### Scenario: Inspect and identify the new block
- **WHEN** an authorized player opens a powered or unpowered interface without a connected computer
- **THEN** its exact peripheral name is copyable and status is meaningful, without performing a catalogue scan or starting a program.

#### Scenario: View beside existing devices
- **WHEN** the interface is rendered beside Recipe Searcher and the other Service Rack devices in each cardinal direction
- **THEN** its silhouette and icon are distinguishable and both wire colors attach to their depicted contacts, with unrelated device pixels unchanged.

### Requirement: Supported engine and honest acceptance
The feature SHALL operate on the repository's pinned Factorio 2.1.23 in base-only and optional Space Age configurations without expansion-only crafting prerequisites. Validation SHALL separately identify packaged engine, cold-load/upgrade, actual client appearance/tooltip and connected multiplayer evidence. Documentation or headless success SHALL not be presented as client or multiplayer acceptance.

#### Scenario: Base-only and expansion installations
- **WHEN** the packaged feature is loaded in either supported configuration
- **THEN** the new device can be researched, crafted, wired and queried using installed metadata without an expansion-only recipe dependency.

#### Scenario: Tooltip comparison
- **WHEN** reference rocket counts and temperature fields are accepted for release
- **THEN** evidence includes comparison with the pinned full client's native presentation for representative items/fluids and explicit separate coverage of exceptional metadata.

### Requirement: Shipped API contract and runnable example
The shipped feature SHALL include localized names, discoverable method help, the companion Lua API contract and a runnable guest example covering name lists, item/fluid lookup and absent rocket capacity. Documentation SHALL explain exact namespaces, baseline quality, units, complete-or-error lists and the difference between reference metadata and live factory feasibility.

#### Scenario: Use the documented API
- **WHEN** the documented example runs through the actual guest API against a powered, wired interface in the tested archive
- **THEN** it uses the declared methods and fields successfully, and discovery/help/package inventories include the new peripheral without removing existing methods.
