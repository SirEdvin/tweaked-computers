# recipe-searcher delta

## MODIFIED Requirements

### Requirement: Distinct physical Recipe Searcher
The mod SHALL provide a 1×1 Recipe Searcher requiring and consuming no electricity, with one Network endpoint supporting red and green wires. Its selectable body SHALL be the wire target, with distinct archive/scanner-style Foundry artwork, readable status and cardinal views. It MUST NOT expose item/fluid storage, crafting execution or a dedicated recipe-search GUI.

#### Scenario: Place and connect the device
- **WHEN** a player or robot places the device in any cardinal direction
- **THEN** its footprint, wire contacts and artwork agree, it has no power helper, and ordinary peripheral discovery recognizes type `recipe_searcher`.

### Requirement: Network and power authority
Every search SHALL use the existing same-force, same-surface, explicit-color Network authority and check the current bound identity. All methods SHALL require no electricity; missing electrical supply MUST NOT cause `E_UNPOWERED`. Stale methods SHALL fail closed after detach, replacement or scope changes. The device SHALL remain a passive network relay without signal read/write services.

#### Scenario: Power loss and restoration
- **WHEN** a connected searcher has no electrical supply, or surrounding supply disappears and returns
- **THEN** discovery, `getLimits()` and authorized searches remain usable without interruption, new research or replacement.

#### Scenario: Captured call after replacement
- **WHEN** a program retains a search method and the addressed block is removed or replaced
- **THEN** the old method fails with `E_UNREACHABLE` rather than addressing the replacement.

### Requirement: Shipped documentation and visual identity
The packaged feature SHALL include localized names, its query contract, discoverable help and a working guest example showing item/fluid searches, category refinement and `E_LIMIT` handling. Its original artwork SHALL have reproducible provenance. Verification SHALL distinguish actual client appearance and multiplayer behavior from headless or mocked evidence.

#### Scenario: Player uses the packaged feature
- **WHEN** the documented example is run from the tested archive against a wired searcher without requiring electrical supply
- **THEN** its documented methods and result fields work, and the package includes the referenced API contract and artwork.

#### Scenario: Native appearance review
- **WHEN** the block is inspected in the full client in each cardinal direction
- **THEN** its scanner/archive silhouette, icon, status and red/green contacts are legible beside the existing device family and vanilla machinery.
