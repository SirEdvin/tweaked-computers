# Device Lifecycle Spec Delta

## MODIFIED Requirements

### Requirement: Pinned engine and optional expansion
The mod SHALL target Factorio 2.1.23 and operate with base alone or with Space Age enabled. Expansion materials/technology MUST NOT be required by its base recipes. Ordinary radar modems SHALL work without Space Age; the advanced radar entity, item, recipe and technology SHALL exist only with Space Age enabled. Signal and device quality identities SHALL remain correct in both configurations. Dashboard labels/buttons SHALL require neither Space Age nor the optional chart library.

#### Scenario: Base-only installation
- **WHEN** the packaged mod is loaded with base and no expansion
- **THEN** prototypes load, devices can be unlocked/crafted and all applicable APIs work without missing expansion references
- **AND** ordinary radar communication works while no advanced-radar entity, item, recipe or research entry exists.

#### Scenario: Expansion installation
- **WHEN** the packaged mod is loaded with Space Age
- **THEN** both radar tiers are available through their intended progression, with no dependency on a planet-specific science pack.

#### Scenario: Optional dashboard charts
- **WHEN** either supported content configuration enables or omits the compatible factorio-charts dependency
- **THEN** dashboards load in both cases and only their chart capability depends on that library.
