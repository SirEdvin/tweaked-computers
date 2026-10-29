# device-visual-identity delta

## MODIFIED Requirements

### Requirement: Coherent icons and status cues
Inventory/recipe icons SHALL depict the same device family as the world sprites and remain distinguishable at ordinary icon size. Stopped, active and fault states SHALL have compact understandable cues without replacing native deconstruction markers or flooding the sprite with status text.

#### Scenario: Inspect inventory and factory
- **WHEN** the player matches an inventory item to a placed device and then changes its run/operational state
- **THEN** the identity stays recognizable and status changes are visible without changing the device's apparent type.

### Requirement: Selected Service Rack six-device family
The six devices SHALL adopt the selected Service Rack (AR2 candidate B) identity. Recipe Searcher SHALL retain its 1×1 footprint and follow five-device requirements. Cardinal bodies, item icons, shadows and status sheets SHALL match the preview; technology icons SHALL depict the selected computer and scanner. Adoption MUST NOT alter gameplay, research ownership, unlock effects, native-device power, physical contacts/selection or monitor alpha/interior/touch geometry.

#### Scenario: Identify the selected six-device family
- **WHEN** all six devices appear beside vanilla machinery at ordinary zoom, in inventory and in their research entries
- **THEN** the folded desk, offset cartridge stack, flat bracketed monitor, rail instrument, open caliper and low scanner sled remain recognizable and share coherent materials and lighting.

#### Scenario: Reproduce the selected artwork
- **WHEN** the production generator runs with its pinned offline dependencies
- **THEN** all 176 pre-existing PNGs reproduce the approved B preview exactly, two new 256px technology icons are traceable to its selected bodies, and regenerated manifests record actual sources, output bytes and retained notices without an installed theme selector.

## ADDED Requirements

### Requirement: Power-free status and demand-owned art updates
Custom-device world/status/UI presentation SHALL not show missing electricity as a fault or unavailable state. Status art SHALL update only for affected dirty identities or an actual due animation transition, without scanning all devices each tick. Native radar/speaker graphics, warnings and animation SHALL remain unchanged.

#### Scenario: Custom device outside electrical coverage
- **WHEN** each custom family is viewed in the native client without an electrical network
- **THEN** its intended artwork and contacts remain legible, no electrical warning or helper appears, and genuine stopped/fault/physical-invalid states remain distinguishable.

#### Scenario: Unchanged artwork
- **WHEN** devices retain the same operational state across ordinary ticks
- **THEN** the mod performs no per-device status discovery or redundant native sprite update; a later run/fault/lifecycle change updates only affected art.

#### Scenario: Native exception appearance
- **WHEN** a native radar or programmable speaker loses power
- **THEN** native visual feedback remains intact without adding a custom recurring power watcher.
