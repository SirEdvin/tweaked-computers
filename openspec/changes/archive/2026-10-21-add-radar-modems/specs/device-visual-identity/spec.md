# Spec Delta

## ADDED Requirements

### Requirement: Native radar visual exception
Radar modems SHALL retain the native radar visual language rather than adopting Service Rack shells. The ordinary radar SHALL retain its vanilla graphics, footprint, wire contacts, animation and native status presentation. The existing six-device Service Rack artwork and footprint contracts SHALL remain unchanged; radar integration SHALL NOT require authored shell/status sheets for vanilla radar.

#### Scenario: Compare vanilla appearance
- **WHEN** an ordinary radar is connected to a computer
- **THEN** it remains visually the same native radar with correctly attached wires and normal animation, without a separate generic network tile or replacement body.

### Requirement: Larger advanced radar presentation
The advanced radar SHALL use approximately 1.5 times the ordinary radar's linear visual scale, a 5×5 tile footprint and a recognizable advanced-tier item/research identity. Body, shadow, integration patch, selection/collision geometry and circuit connectors SHALL be adjusted coherently. Native animation and placement feedback SHALL remain usable on planets and platforms.

#### Scenario: Compare both tiers in the native client
- **WHEN** ordinary and advanced radars are placed side by side at identical zoom
- **THEN** the advanced radar is recognizably larger, its occupied footprint and selection match, its animation and shadows are coherent, and both wire colors attach to visible contacts.

#### Scenario: Platform placement feedback
- **WHEN** an advanced-radar ghost is placed near occupied platform tiles
- **THEN** ghost, collision and selection feedback agree with its 5×5 footprint without hidden helper-space costs.

### Requirement: Reviewable native asset transformations
Radar asset reuse SHALL be documented through version-pinned native references and reproducible prototype transformations. Visual acceptance SHALL include actual client screenshots and animation inspection in base-only and Space Age configurations as applicable. Generated contact sheets, successful headless tests or a client startup alone SHALL NOT count as visual acceptance.

#### Scenario: Archive and visual audit
- **WHEN** the implementation is reviewed for release
- **THEN** the archive contains no copied Factorio distributions/assets, transformation provenance is available, and evidence shows unchanged ordinary radar plus scaled advanced radar, aligned wiring and normal animation.
