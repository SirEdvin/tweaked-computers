# Spec Delta

## ADDED Requirements

### Requirement: Complete generated typed Reference
The in-game Reference SHALL present the complete public API information generated from the canonical Lua declaration library. Each method SHALL visibly separate its signatures, described parameters, ordered results and relevant behavior notes. Typed content SHALL extend the existing Reference rather than replace its authoring, safety or tutorial guidance.

#### Scenario: Read a complete method contract in game
- **WHEN** a player opens a method entry
- **THEN** its parameters, types, optionality, defaults, return positions, overloads, errors and applicable context restrictions are readable without leaving the game
- **AND** alias entries and shared guidance retain the existing separation and literal selection/copy behavior.

#### Scenario: Use the installed reference offline
- **WHEN** a player opens Reference without external documentation tools, an editor extension or internet access
- **THEN** the installed mod supplies its matching complete API reference
- **AND** browsing does not invoke guest code, service methods or source-comment parsing.

### Requirement: Named type and event discovery in Reference
Every public named type and event referenced by in-game API documentation SHALL be reachable through the existing topic selection or search interface. Its complete field types, descriptions, optionality and variants SHALL be available without requiring an external page or recursively expanding an unbounded structure.

#### Scenario: Inspect a nested configuration or event type
- **WHEN** a method or event names a public type and the player searches for that exact type
- **THEN** the matching type topic exposes its complete definition and identifies any further named types to inspect
- **AND** required versus optional fields, enum alternatives and variant-specific fields remain distinguishable.

#### Scenario: Search by contract details
- **WHEN** a player searches for a parameter, nested field, type name, failure code or example text
- **THEN** matching generated topics remain discoverable through the existing category/search controls
- **AND** contextual peripheral navigation still clears incompatible filters and selects the correct device-family topic.

### Requirement: Typed Reference preserves native interaction safety
Generated content SHALL retain native selectable prose, literal signatures/code, wrapped readable text and accessible navigation at supported display scales. Opening or filtering documentation SHALL preserve the draft, saved/active program, Console state and peripheral data. Ordinary updates SHALL not rebuild unchanged visible content solely because more documentation is available.

#### Scenario: Copy and resize generated content
- **WHEN** a player selects and copies a signature, type description or complete tutorial and changes the supported window size or GUI scale
- **THEN** copied bytes retain their literal content and code whitespace, prose does not require horizontal scrolling, and topic/close controls remain reachable
- **AND** unchanged content retains the existing widget/selection preservation behavior.

#### Scenario: Navigate with a dirty draft and live factory
- **WHEN** a player browses method/type topics, searches and opens contextual peripheral help while retaining a dirty draft or running program
- **THEN** no source save, activation, stop, reset, shell mutation or peripheral effect occurs
- **AND** returning to the Editor preserves its exact draft and the established ownership/focus protections.
