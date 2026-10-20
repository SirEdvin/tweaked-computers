# device-visual-identity Specification

## Purpose

Make each programmable device immediately distinguishable in Factorio's world and inventory, with coherent industrial materials and trustworthy visible connection points.

## Requirements

### Requirement: Five distinct industrial identities
The computer, database, monitor, logic handler and configurator SHALL each have a recognizable silhouette and functional detailing inspired by Factorio circuit equipment. Recolored computer copies, repeated computer cubes and letter badges alone MUST NOT constitute distinct designs. Existing 1×1, 1×1, 1×1, 3×1 and 2×1 footprints respectively SHALL remain unchanged.

#### Scenario: Identify the device family
- **WHEN** the five devices are viewed side by side at ordinary gameplay zoom without hover labels
- **THEN** computer, storage, display, signal processing and configuration roles are visually distinguishable by form, not solely by color or text.

### Requirement: Perspective and material coherence
World sprites SHALL use a coherent top-down oblique perspective, readable upper surfaces, controlled contrast, consistent lighting and grounded shadows appropriate beside vanilla combinators. Four directional views SHALL retain device identity and match collision/selection footprints. Oversized pale top faces MUST NOT conceal all functional cues.

#### Scenario: Rotate beside circuit machinery
- **WHEN** each device is placed in all cardinal orientations beside vanilla combinators
- **THEN** its silhouette, controls, socket positions and shadow read as one coherent device rather than a flat front-view icon or stretched duplicated blocks.

### Requirement: Artwork and interaction share connector placement
Visible red/green terminals and role symbols SHALL match the actual wire attachment and selection locations in every direction. The monitor's terminals SHALL remain on the bezel. Role differences SHALL use form/symbol/position as well as color, and network colors MUST NOT be mistaken for mandatory wire-color routing rules.

#### Scenario: Attach both wire colors
- **WHEN** the player attaches red and green wires to each permitted role
- **THEN** both wires terminate on their depicted contacts without floating in empty space, crossing an unrelated role or covering monitor content.

### Requirement: Coherent icons and status cues
Inventory/recipe icons SHALL depict the same device family as the world sprites and remain distinguishable at ordinary icon size. Off, unpowered, active and fault states SHALL have compact understandable cues without replacing native deconstruction markers or flooding the sprite with status text.

#### Scenario: Inspect inventory and factory
- **WHEN** the player matches an inventory item to a placed device and then changes its power/run state
- **THEN** the identity stays recognizable and status changes are visible without changing the device's apparent type.

### Requirement: Reviewable reproducible asset delivery
The artwork deliverable SHALL include editable sources, reproducible export instructions, required notices and a contact sheet covering every device, direction and relevant state. The contact sheet SHALL include ordinary-scale and enlarged views plus adjacent vanilla-reference scale context. Generated-image inspection MUST NOT be claimed as native-client rendering acceptance.

#### Scenario: Review an artwork handoff
- **WHEN** the art task is submitted for integration
- **THEN** the reviewer can inspect all five identities and socket alignments from a complete contact sheet and trace the shipped sprites to their sources without recreating an opaque manual workflow.

### Requirement: Selected Service Rack six-device family
The six devices SHALL adopt the selected Service Rack (AR2 candidate B) identity. Recipe Searcher SHALL retain its 1×1 footprint and follow five-device requirements. Cardinal bodies, item icons, shadows and status sheets SHALL match the preview; technology icons SHALL depict the selected computer and scanner. Adoption MUST NOT alter gameplay, research ownership, unlock effects, power, physical contacts/selection or monitor alpha/interior/touch geometry.

#### Scenario: Identify the selected six-device family
- **WHEN** all six devices appear beside vanilla machinery at ordinary zoom, in inventory and in their research entries
- **THEN** the folded desk, offset cartridge stack, flat bracketed monitor, rail instrument, open caliper and low scanner sled remain recognizable and share coherent materials and lighting.

#### Scenario: Reproduce the selected artwork
- **WHEN** the production generator runs with its pinned offline dependencies
- **THEN** all 176 pre-existing PNGs reproduce the approved B preview exactly, two new 256px technology icons are traceable to its selected bodies, and regenerated manifests record actual sources, output bytes and retained notices without an installed theme selector.
