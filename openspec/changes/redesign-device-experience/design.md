# Design

## Context

See `proposal.md` for motivation and `research.md` for pinned evidence. The implemented baseline is `cb300e62ebad6a4a9a38a0679f21e251009f1d16`; this plan does not modify that runtime.

The current electric-energy-interface bodies have no native circuit connector properties in Factorio 2.0.77. `prototypes/devices.lua` creates invisible constant-combinator role children with selection priority 60 over body priority 40; a single-role child occupies the body center. `scripts/network.lua` explicitly recognizes the child role, so simply hiding the helper breaks discovery/wiring. The existing GUI model already protects drafts and authority; the adapter unnecessarily displays every tool in one scroll pane. The art generator deliberately repeats the same computer model for every non-monitor kind.

Factory Planner is a design reference, not a dependency. Its pinned screenshot and `ui/base/main_dialog.lua`, `ui/main/title_bar.lua` and `ui/base/modal_dialog.lua` demonstrate native beveled frames, compact title controls, structured panels, contextual actions, drag handles and display-scale-aware sizing. Its inspected UI does not provide our proposed five-tab layout; those tabs are this redesign's information architecture.

## Goals / Non-Goals

Goals: make the physical object, wiring target, icon and UI describe the same device; make code editing the primary activity; make native removal feedback trustworthy; retain working backend semantics.

Non-goals: changing Lua API v1, executing a new language/VM, adding files or a shell, adding peripheral types/tiers, changing recipe balance/footprints, imposing a web UI framework, copying Factory Planner's whole GUI library, running broad client/stress matrices, releasing a new alpha or changing GitHub protections during planning.

## Decisions

### 1. Circuit-capable visible shell, private power carrier

Use a native circuit-capable visible shell for the main device/network endpoint, with a truly nonselectable, nonblueprintable private electric carrier for power where needed. A constant-combinator shell is the preferred first implementation because it has cardinal graphics, native connectors and an existing well-understood passive configuration. Its ordinary behavior must remain disabled/empty for Network; native combinator configuration must not be exposed. Keep existing watts, buffer accounting and active-service policy.

Logic and configurator retain distinct auxiliary role pads where the engine cannot represent all isolated connectors on one shell. Those pads are drawn into the device footprint, have device-specific role names, use real native connectors and cannot be mined or built independently. Network is the shell endpoint; Input/Output/Targets are separate owned endpoints. The normal body must remain easy to select, open, mark and mine. Do not mutate global selection flags based on one player's cursor: that would affect other players.

Keep `lifecycle.connector(rec, role, color)` as the service seam. Update the narrow physical ownership/registry mapping and network vertex resolution so a network endpoint owned by the body is valid without making every body role a traversal permission. A role comes from the binding, not an entity label. Keep exact entity ownership, force/surface validation and fail-closed proof checks.

Before widespread conversion, RD1 must run a bounded exact-engine probe of the chosen shell: connector selection, passive signals, private power drain, GUI suppression and two independent role pads. If the preferred prototype cannot satisfy these requirements, preserve the UX contract and report the concrete limitation rather than silently restoring generic NETWORK tiles. The required behavior is decided; this is a narrow engine feasibility check, not another open-ended design task.

Rejected: renaming the generic child alone (retains invisible target mismatch); making it unselectable without replacing wiring (breaks wires); joining roles on a shared native network (changes authority); adding a separate placeable network block (opposite of the requested experience).

### 2. One connector-layout source for artwork and behavior

RD1 owns the native socket layout and directional transform in `scripts/device-definitions.lua` (or a small existing shared metadata module), including actual red/green contact offsets, role pads and selection boxes. RD2 consumes it for sprites/contact sheets rather than inventing another offset map. Existing source has a concrete mismatch: helper positions are role centers while artwork badges sit toward a face edge; the palette in definitions also differs from the generator. Consolidate these facts, not a new generalized geometry framework.

Preserve footprints: computer/database/monitor 1×1, logic 3×1, configurator 2×1. The outer body owns deconstruction. Auxiliary pads are not extra inventory entities. No promise that every role can be a single native entity is made.

### 3. Native tabbed computer workspace

Use a native `tabbed-pane` inside a fixed, draggable window. Keep `scripts/ui/editor-model.lua` as the authority/draft/action layer; redesign the GUI adapter and style/localization layer, splitting tab construction into small modules only if useful. Native controls retain keyboard/clipboard behavior. The plan HTML is a review mockup, never shipped as the game's interface.

Window hierarchy:

    Computer title                 status     Focus  Close
    Editor | Console | Peripherals | Reference | Maintenance
    [active tab's own content, not a global scroll column]
    [Editor only: Validate   Save   Run/Apply   Stop]
    [compact saved/active/dirty status; contextual error if any]

Editor: no persistent sidebar, help prose, peripheral list, log pane or recovery list. A normal-sized editor should allocate at least 70% of the window's usable content height to source; focus mode targets at least 85%. These are design targets measured on supported layouts, not a reason to clip essential buttons at small sizes. Keep a single context-sensitive Run/Apply button. Do not add implicit Save-and-Run. Disabled actions explain why. An empty editor offers a small explicit template/example entry, never overwrites nonempty text.

Console: bounded output, diagnostic detail, explicit follow toggle and source-location navigation when the pinned native text-box API supports it. Do not promise a general terminal, REPL, or clear command that does not exist. A simple read-only buffer is sufficient; preserve native scroll when follow is off.

Peripherals: separate red/green filter, device rows with icon, meaningful type/name, powered/pending/disconnected state, explicit refresh and selected device details. Names remain opaque API IDs; friendly labels never replace authorization identity. Empty state explains how to wire the depicted sockets. Do not display invented successful discovery while traversal is pending.

Reference: categorized/searchable existing API help and examples, selectable text, explicit copy/insert actions only where native APIs support them. Insert refuses to overwrite dirty source; show review before replacement. No undocumented methods or clipboard promises.

Maintenance: current saved/active revision review, rebase/reload, former-active recovery, retained drafts, explicit forget and stopped-only Reset State. Dangerous actions receive a separate confirmation with the affected identity. Standalone recovery remains usable if the original computer is unavailable. All existing actions map to an explicit location in `api/compatibility.md`.

Source widget stays mounted across tab switches, focus toggles and routine status refreshes. Only the visible supporting tab performs its bounded presentation refresh. New nested event routes retain exact player/frame/token/identity checks; do not weaken ownership because the old eight-parent traversal limit no longer reaches the root. Tabs themselves require a handled native tab-change event.

Use Factorio-native title/button/tab/sunken panel styles and a verified monospace font. Adopt its restrained steel/charcoal with amber active-tab accents; use green/red with text/symbols for state. No decorative dashboard cards or all-caps diagnostic wall. Preserve a movable position, clamp on resolution/scale changes, offer a fit/focus toggle instead of promising unsupported native free-resize behavior. Test layout functions at 1280×720 and 1920×1080 with 100%/150% GUI scales; record minimum supported effective dimensions honestly. Native caret/selection readback is limited in 2.0.77, so avoid replacing text widgets instead of claiming unsupported caret restoration.

### 4. Five industrial silhouettes, not five computer textures

- Computer: low, chamfered operator console; dark inset sloped screen, clearly visible keyboard/control strip, cooling grille and network terminal block. Avoid a tall white cube whose top hides its function.
- Database: ribbed storage cabinet/cartridge bank with visible stacked modules and an activity rail. No screen or keyboard; distinct dense block silhouette within 1×1.
- Monitor: flat, thin, dark glass panel with a consistent metal bezel, small edge terminal and modular seams. Preserve the existing logical cell surface, tile pitch and two-unit bezel; do not turn it upright or change touch math for appearance.
- Logic handler: one continuous three-bay combinator-style instrument, with input studs, central processing section and output studs, directional arrows and different socket symbols. Never three computers side by side.
- Configurator: a continuous two-bay controller with service/dial elements and a separated factory terminal bank. Never two computers side by side.

Palette: weathered steel, graphite electronics, muted brass/copper terminals, restrained amber displays/status. Contrast and silhouette carry identity before color. Small symbols identify role; no giant letters as the only distinction. Lighting/shadow direction and pixel density must match nearby vanilla circuit devices. Original authored geometry/textures are preferred. Approved Greg Flavored assets remain usable if genuinely helpful, but no requirement forces the rejected geometry into the redesign. Keep existing notices for retained inputs; no renewed speculative licensing gate.

RD2 supplies all five types, all four directions, icons and relevant status frames, editable sources and a reproducible export. Contact sheets show ordinary scale plus enlarged views and wired socket overlays. A deterministic export is required; a custom rasterizer is not. Use the simplest available art workflow that achieves quality instead of preserving the current generator merely because it is stdlib-only.

### 5. Monitor content below native world feedback

Confirmed code fact: backgrounds/cursors use filled `draw_rectangle` without a layer control; glyphs use `light-effect`. In the pinned API, rectangles only offer `draw_on_ground`, whereas sprites expose `render_layer`; `light-effect` is above `entity-info-icon`. That is a credible occlusion path, not a reproduced client diagnosis. Also check which logical entity actually receives the deconstruction order; a renderer-only patch would not fix a mis-targeted helper.

Prefer a tiny authored white sprite scaled/tinted for cells/panel/cursor so every display component has an explicit shared world-content layer below wire/selection/deconstruction feedback and above its panel body. Determine the usable concrete layer against the pinned engine and actual body art; do not invent a `render_layer` property on rectangles. Keep drawing budgets, visibility, retained model and cleanup ownership intact. If a narrow marked-tile presentation suppression is necessary, base it on authoritative mark/cancel state and reconcile on load; never clear cells, regroup on marking, or draw a fake permanent X instead of restoring native feedback.

RD4 covers mark/cancel, marked subset of an array, unpowered/powered, ongoing updates, actual removal and cold reload of marked tiles. User-owned native review proves the X visually; headless checks prove only state and object properties.

## Risks / Trade-offs

- Changing body prototype type can strand existing saves/wires → retain legacy prototypes for conversion, stage replacements and wire snapshots, prove upgrade from a real 0.1.1 fixture before dropping legacy support. Do not assume changing a prototype type under the same name is safe.
- Multi-role entities may still need native helper endpoints → make them device-specific integrated pads, with no standalone item/anonymous tile workflow; preserve per-player-independent selection.
- Attractive mockups can hide native GUI limits → implement only documented controls, keep text widgets mounted and let the user inspect the exact candidate in game.
- Sprite export or headless success does not establish appearance → review complete contact sheets/mockup pixels and list the small user client checklist honestly.
- The existing repository has no required checks, despite a PR-gated TC17 → do not add another publishing completion contract without an explicit authorized CI prerequisite. This campaign's five workers hand off code/docs/candidate only; orchestrator owns a later consolidated review PR and any separate release-policy decision. No worker is instructed to bypass the existing gate.

## Migration Plan

1. Preserve untouched alpha 0.1.1 save and artifact fixtures. Implement new physical carriers while old prototypes remain loadable.
2. In a permitted synchronized migration phase, snapshot existing logical identity, state and each actual role/color/target wire; stage replacement shell/power/pads without guest execution.
3. Publish the new ownership mapping only after native connection and power validation. Retain data and report conversion refusal on failure; invalidate obsolete GUI sessions safely while keeping player drafts.
4. Support old blueprint ghosts and tagged items through the same compatibility path. Remove old helpers only after successful handoff; no double drops or automatic startup replay.
5. Integrate art/UI/monitor changes and focused regression evidence, update player docs/OpenWiki and give the user the exact candidate plus a concise playtest checklist. Rollback means restoring the backed-up world and old mod version, not promising a destructive reverse migration.

## Approval and delivery boundary

All five cards are created blocked with no automatic time-based release. User approval of the plan is required before any implementation worker is made available. Initial approval is not native visual acceptance; user playtesting remains a separate later check. No new Mod Portal/GitHub release or default-branch merge is included without explicit authorization. Do not alter TC17, repeat its publication or expand this design into a general CI/agent-platform repair.
