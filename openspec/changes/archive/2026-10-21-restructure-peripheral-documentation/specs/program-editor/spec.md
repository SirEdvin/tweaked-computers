# Spec Delta

## ADDED Requirements

### Requirement: Method-isolated peripheral reference
The in-game Reference SHALL document each general peripheral discovery method and each shipped device-specific method in its own paragraph, with at least two empty lines between adjacent method paragraphs. Each entry SHALL identify its signature, results and relevant behavior. Aliases SHALL have separate entries. Shared device guidance SHALL remain distinct from method paragraphs, and existing API caveats and examples SHALL remain available.

#### Scenario: Read the discovery API
- **WHEN** a player opens the general peripheral discovery topic
- **THEN** each discovery method has an individually readable paragraph rather than sharing a method list or paragraph with another method
- **AND** adjacent method paragraphs have at least two empty lines between them.

#### Scenario: Read a device method and its alias
- **WHEN** a player reads any shipped device-family topic, including Monitor methods with Color/Colour aliases
- **THEN** each exported method and alias has its own separated paragraph with its signature, results and relevant caveats, or an explicit alias reference to the corresponding method
- **AND** method overloads remain together within that method's paragraph.

#### Scenario: Preserve shared semantics and help tools
- **WHEN** a player browses or searches the reorganized reference
- **THEN** shared wiring, power, persistence, bounds and event guidance remains available without mixing multiple methods into a method paragraph
- **AND** native text selection/copy, existing examples and non-peripheral topics remain available.

### Requirement: Select-then-open peripheral documentation
In the computer's Peripherals tab, a first click on an unselected peripheral SHALL retain the existing identity/status selection behavior without leaving the tab. Clicking the same selected peripheral again on the same discovery wire SHALL open its device-type documentation in Reference, without a double-click timing requirement. Guidance SHALL explain both actions. These actions SHALL NOT save, execute, reset or mutate program or peripheral data.

#### Scenario: First click selects details
- **WHEN** a player clicks an unselected peripheral row
- **THEN** the Peripherals tab remains active and displays that peripheral's API name, type, discovery wire, power status and snapshot details
- **AND** the interface explains that another click opens documentation.

#### Scenario: Repeat click opens the matching topic
- **WHEN** a player clicks that selected peripheral row again, whether immediately or after a delay
- **THEN** Reference becomes active with the documentation for that peripheral's type selected and readable from the beginning
- **AND** the source draft, saved/active revisions, execution, shell values and peripheral data are unchanged.

#### Scenario: Select a different row
- **WHEN** a player clicks another peripheral after selecting one
- **THEN** the new row becomes selected and its details appear without opening Reference
- **AND** another click on the new selection opens that peripheral type's documentation.

#### Scenario: Read documentation for an unpowered peripheral
- **WHEN** an unpowered peripheral appears in the discovery inventory and the player selects then clicks it again
- **THEN** its documentation opens without invoking its service methods or requiring peripheral power.

### Requirement: Reliable contextual reference navigation
Contextual navigation SHALL reveal the requested device topic despite prior filters and keep visible controls consistent. Repeat-click selection SHALL distinguish identity and discovery wire, reset on wire changes or missing/unavailable inventory, and survive same-wire refreshes retaining the identity. Missing documentation SHALL report unavailable rather than display an unrelated topic. Stale or unauthorized GUI events SHALL remain rejected.

#### Scenario: Prior filters hide the requested documentation
- **WHEN** the player repeat-clicks a selected peripheral while an earlier Reference category or search excludes its topic
- **THEN** navigation clears the obstructing search, selects the Peripherals category and selects the matching topic
- **AND** the visible search/category controls agree with that state.

#### Scenario: Change discovery wire
- **WHEN** a player changes the Peripherals discovery wire, including when the same device name is reachable on both colors
- **THEN** the next row click selects identity/status on that wire and does not open documentation until a further click.

#### Scenario: Refresh removes or reorders rows
- **WHEN** a refreshed inventory reorders rows or omits the selected peripheral, or reports pending/error instead of an inventory
- **THEN** row indexes are not treated as peripheral identity, only current row widgets can act, and a missing/unavailable selection cannot trigger documentation navigation
- **AND** if the device later returns, its first click selects it rather than opening documentation immediately.

#### Scenario: An unchanged selection survives refresh
- **WHEN** a successful same-wire refresh still contains the selected peripheral identity
- **THEN** its repeat-click selection remains associated with that identity, not its former row index.

#### Scenario: Documentation mapping is unavailable
- **WHEN** a selected peripheral type has no in-game documentation mapping
- **THEN** the UI retains its details and reports that documentation is unavailable without displaying an unrelated Reference topic.

#### Scenario: Reject stale or foreign clicks
- **WHEN** a click references a destroyed/replaced row widget, another player's session or a computer the player cannot access
- **THEN** it does not change selection, navigate Reference or cause program/peripheral effects.
