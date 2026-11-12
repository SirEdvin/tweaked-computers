## MODIFIED Requirements

### Requirement: Attributable adapted artwork
The custom devices SHALL retain the Factorio-industrial visual family defined by `device-visual-identity`. Radar modems SHALL use its native-radar exception rather than replacing vanilla artwork. Original authored assets, committed renders of authored models and native Factorio asset references are preferred; retained approved Greg Flavored inputs SHALL retain pinned provenance and MIT notices. Runtime sprites SHALL match perspective, geometry and connectors. Unresolved provenance SHALL block only affected assets.

#### Scenario: Asset release audit
- **WHEN** a distributable archive is built
- **THEN** every shipped derived asset has identified inputs, hashes, transformation record and required notices
- **AND** the promotional preview image is not substituted for a verified entity sprite set.

#### Scenario: Native radar asset reuse
- **WHEN** the advanced radar reuses installed Factorio sprites, icons, shadows or sounds
- **THEN** the mod references their native asset paths and documents the prototype transformations without packaging Factorio distributions or extracted game assets.
