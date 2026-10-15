# Proposal

## Why

The published alpha exposes connector helper entities as generic NETWORK targets, crowds computer authoring into one scrolling form, and gives different devices nearly identical computer-derived silhouettes. The user's playtest also reports missing monitor deconstruction crosses; a presentation-focused redesign is needed without sacrificing working programs, topology isolation or saved data.

## What Changes

- Make wiring and selection read as connections between actual devices, with visibly integrated red/green sockets and named, spatially separated roles on logic handlers and configurators. Internal helpers, if necessary, must not present themselves as extra generic network devices.
- Replace the computer window's information architecture with native Factorio tabs: Editor, Console, Peripherals, Reference and Maintenance. Editor opens first and dedicates its content to code, a compact action row and actionable diagnostics; add an explicit focus layout. Preserve every existing safe authoring/recovery action rather than hiding functionality permanently.
- Develop a distinct Factorio-industrial visual family inspired by combinators, circuit connectors, cabinets and display panels: a low control console, a storage cabinet, a modular flat monitor, a three-bay signal processor and a two-bay configuration controller. Redraw shape, perspective, materials, shadows and sockets instead of recoloring or repeating the same computer cube.
- Restore native monitor deconstruction/selection visibility over live graphics, including partial marked arrays, cancellation and robot removal. The reported X means the red deconstruction marker, explicitly confirmed by the user.
- Preserve the version-1 Lua APIs, same-color physical discovery, separate I/O/target roles, device footprints, durable drafts/data and existing blueprint/item behavior. Provide safe upgrade handling if physical connector ownership changes.
- Update player instructions and developer OpenWiki with the integrated changes. Deliver a reviewable implementation branch/PR and candidate for user playtesting; this planning request does not authorize another publication, main-branch merge, protection change or worker dispatch.
- Approval boundary: create dependency-linked Albina tasks already blocked. No task is released until the user validates this package and explicitly approves work.

## Capabilities

### New Capabilities

- `device-visual-identity`: distinguishable industrial silhouettes, coherent sprite/icon/status language and authored-asset provenance.

### Modified Capabilities

- `program-editor`: editor-first tabbed navigation, uncluttered focus layout, contextual controls and preserved recovery/security behavior.
- `peripheral-network`: player-facing integrated connectors and meaningful role identity, with existing topology/API contracts unchanged.
- `monitor-display`: readable native world selection/deconstruction overlays without destroying committed display state.
- `device-lifecycle`: coherent device selection/mining/blueprints and safe migration when changing connector carriers; replace the earlier mandatory computer-derived artwork direction with the approved industrial redesign.

The established capability paths above currently live in the unarchived `add-native-circuit-computers` change; `openspec list --specs --json` reports no canonical specs. Reuse these exact paths and explicit modified requirement text rather than creating duplicate editor/network capabilities or archiving the earlier work merely to plan this redesign.

## Impact

Primary touch points: `prototypes/devices.lua`, `scripts/device-definitions.lua`, `scripts/lifecycle.lua`, `scripts/registry.lua`, `scripts/blueprints.lua`, `scripts/network.lua`, `scripts/ui/editor.lua`, `scripts/ui/editor-model.lua`, `prototypes/editor.lua`, `scripts/rendering.lua`, `scripts/device-art.lua`, `assets/`, `control.lua`, locale/player docs and managed OpenWiki. Reuse the runtime/services and native GUI controls; no web UI runtime, new OS/filesystem, Lua API expansion, broad engine upgrade or Factory Planner dependency is proposed.

Baseline: implementation PR head `cb300e62ebad6a4a9a38a0679f21e251009f1d16`, including published alpha 0.1.1. Research is source/API inspection, not proof of the redesigned native-client experience. Existing TC17's required-CI administrative blocker is separate; do not silently weaken its contract or mark it complete here.
